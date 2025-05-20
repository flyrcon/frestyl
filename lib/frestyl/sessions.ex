# lib/frestyl/sessions.ex
defmodule Frestyl.Sessions do
  @moduledoc """
  The Sessions context.
  """

  import Ecto.Query, warn: false
  alias Frestyl.Repo

  alias Frestyl.Sessions.Session
  alias Frestyl.Sessions.SessionParticipant
  alias Frestyl.Sessions.Message
  alias Frestyl.Sessions.Invitation
  alias Frestyl.Accounts.User


  @doc """
  Gets a single session.
  """
  def get_session(id) do
    Repo.get(Session, id)
  end

  @doc """
  Gets a single session with preloaded associations.
  """
  def get_session_with_details!(id) do
    Session
    |> Repo.get!(id)
    |> Repo.preload([:creator, :host, :channel, session_participants: [:user]])
  end

  @doc """
  Creates a new collaborative session.
  """
  def create_session(attrs \\ %{}) do
    %Session{}
    |> Session.collaboration_changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, session} ->
        # Automatically add creator as a participant
        add_participant(session.id, session.creator_id, "owner")
        {:ok, session}
      error -> error
    end
  end

  @doc """
  Creates a new broadcast session.
  """
  def create_broadcast(params) do
    # Extract params with string/atom key handling
    channel_id = params[:channel_id] || params["channel_id"]
    creator_id = params[:creator_id] || params["creator_id"]
    host_id = params[:host_id] || params["host_id"] || creator_id
    title = params[:title] || params["title"] || "Untitled Broadcast"
    description = params[:description] || params["description"]
    is_public = params[:is_public] || params["is_public"] || false
    broadcast_type = params[:broadcast_type] || params["broadcast_type"] || "standard"
    waiting_room_enabled = params[:waiting_room_enabled] || params["waiting_room_enabled"] || false
    scheduled_for = params[:scheduled_for] || params["scheduled_for"]
    current_user = params[:current_user] || params["current_user"]

    # Handle timezone conversion if needed
    scheduled_time = if scheduled_for && current_user && current_user.timezone do
      # Convert from user timezone to UTC for storage
      case Frestyl.Timezone.naive_to_utc(scheduled_for, current_user.timezone) do
        {:ok, utc_time} -> utc_time
        _ -> scheduled_for  # Fall back to original time if conversion fails
      end
    else
      scheduled_for
    end

    # Determine initial status
    status = if scheduled_time && DateTime.compare(scheduled_time, DateTime.utc_now()) == :gt do
      "scheduled"  # Future event
    else
      "active"     # Immediate or past event
    end

    # Create broadcast session
    %Session{}
    |> Session.broadcast_changeset(%{
      channel_id: channel_id,
      creator_id: creator_id,
      host_id: host_id,
      title: title,
      description: description,
      is_public: is_public,
      status: status,
      broadcast_type: broadcast_type,
      waiting_room_enabled: waiting_room_enabled,
      scheduled_for: scheduled_time,
      session_type: "broadcast",  # Mark as a broadcast session
      waiting_room_open_time: calculate_waiting_room_time(scheduled_time, waiting_room_enabled)
    })
    |> Repo.insert()
    |> broadcast_session_change(:broadcast_created)  # Broadcast the change to subscribers
  end

  # Helper to calculate when the waiting room should open
  defp calculate_waiting_room_time(nil, _), do: nil
  defp calculate_waiting_room_time(scheduled_time, false), do: nil
  defp calculate_waiting_room_time(scheduled_time, true) do
    # Open waiting room 30 minutes before the scheduled time
    DateTime.add(scheduled_time, -30 * 60, :second)
  end

  # Broadcast changes to subscribers
  defp broadcast_session_change({:ok, session} = result, event) do
    # Get topic based on channel
    topic = "channel:#{session.channel_id}:sessions"

    # Broadcast the event with the session
    Phoenix.PubSub.broadcast(Frestyl.PubSub, topic, {event, session})

    # Return the original result
    result
  end
  defp broadcast_session_change(error, _), do: error

  @doc """
  Updates a session.
  """
  def update_session(%Session{} = session, attrs) do
    session
    |> Session.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Ends a session.
  """
  def end_session(%Session{} = session) do
    session
    |> Session.end_session_changeset()
    |> Repo.update()
  end

  @doc """
  Lists active sessions for a channel.
  """
  def list_active_broadcasts_for_channel(channel_id) do
    now = DateTime.utc_now()

    from(s in Session,
      where: s.channel_id == ^channel_id and
            not is_nil(s.broadcast_type) and
            s.status == "active" and
            (is_nil(s.ended_at) or s.ended_at > ^now),
      order_by: [desc: s.inserted_at])
    |> Repo.all()
  end

  @doc """
  Returns a list of active sessions for a specific channel.
  """
  def list_active_sessions_for_channel(channel_id) do
    now = DateTime.utc_now()

    from(s in Session,
      where: s.channel_id == ^channel_id and
            s.status == "active" and
            (is_nil(s.broadcast_type)) and  # Normal sessions, not broadcasts
            (is_nil(s.ended_at) or s.ended_at > ^now),
      order_by: [desc: s.inserted_at])
    |> Repo.all()
  end

  @doc """
  Deletes a session.
  """
  def delete_session(%Session{} = session) do
    Repo.delete(session)
  end

  @doc """
  Gets a single session.
  """
  def get_session(id) when is_binary(id) do
    {int_id, _} = Integer.parse(id)
    get_session(int_id)
  end

  def get_session(id) when is_integer(id) do
    Repo.get(Session, id)
  end

  @doc """
  Lists upcoming broadcasts for a channel.
  """
  def list_upcoming_broadcasts_for_channel(channel_id) do
    now = DateTime.utc_now()

    query = from s in Session,
      where: s.channel_id == ^channel_id and s.status == "scheduled" and s.scheduled_for > ^now and not is_nil(s.broadcast_type),
      select_merge: %{
        registered_count: fragment("(SELECT COUNT(*) FROM session_participants WHERE session_id = ?)", s.id),
        host_name: fragment("(SELECT username FROM users WHERE id = ?)", s.host_id)
      },
      order_by: [asc: s.scheduled_for]

    Repo.all(query)
  end

  @doc """
  Lists past sessions for a channel.
  """
  def list_past_sessions_for_channel(channel_id) do
    query = from s in Session,
      where: s.channel_id == ^channel_id and s.status == "ended",
      select_merge: %{
        participants_count: fragment("(SELECT COUNT(*) FROM session_participants WHERE session_id = ?)", s.id),
        creator_name: fragment("(SELECT username FROM users WHERE id = ?)", s.creator_id),
        host_name: fragment("(SELECT username FROM users WHERE id = ?)", s.host_id)
      },
      order_by: [desc: s.ended_at]

    Repo.all(query)
  end

  @doc """
  Adds a participant to a session.
  """
  def add_participant(session_id, user_id, role \\ "participant") do
    %SessionParticipant{}
    |> SessionParticipant.changeset(%{
      session_id: session_id,
      user_id: user_id,
      role: role
    })
    |> Repo.insert(on_conflict: :nothing)
  end

  @doc """
  Removes a participant from a session.
  """
  def remove_participant(session_id, user_id) do
    from(p in SessionParticipant, where: p.session_id == ^session_id and p.user_id == ^user_id)
    |> Repo.delete_all()
  end

  @doc """
  Checks if a user is a participant in a session.
  """
  def is_session_participant?(session_id, user_id) do
    from(p in SessionParticipant,
      where: p.session_id == ^session_id and p.user_id == ^user_id,
      select: count(p.id) > 0
    )
    |> Repo.one()
  end

  @doc """
  Checks if a user is a moderator in a session.
  """
  def is_session_moderator?(session_id, user_id) do
    from(p in SessionParticipant,
      where: p.session_id == ^session_id and p.user_id == ^user_id and p.role in ["owner", "moderator", "host"],
      select: count(p.id) > 0
    )
    |> Repo.one()
  end

  @doc """
  Joins a user to a session.
  """
  def join_session(session_id, user_id) do
    # Check if the session exists and is active
    session = get_session(session_id)

    if is_nil(session) do
      {:error, "Session not found"}
    else
      case session.status do
        "ended" ->
          {:error, "Session has ended"}

        "cancelled" ->
          {:error, "Session has been cancelled"}

        "scheduled" ->
          if not is_nil(session.broadcast_type) do
            # For broadcasts, users can register before the event
            add_participant(session_id, user_id)
          else
            # Regular sessions shouldn't be joinable when scheduled
            {:error, "Session hasn't started yet"}
          end

        "active" ->
          # Check if the session has a maximum number of participants
          if not is_nil(session.max_participants) do
            participant_count =
              from(p in SessionParticipant, where: p.session_id == ^session_id, select: count(p.id))
              |> Repo.one()

            if participant_count >= session.max_participants do
              {:error, "Session is at maximum capacity"}
            else
              add_participant(session_id, user_id)
            end
          else
            add_participant(session_id, user_id)
          end
      end
    end
  end

  def end_session(session_id, user_id) do
    session = get_session(session_id)

    # Check if user has permission to end the session
    if session && (session.creator_id == user_id || session.host_id == user_id) do
      update_session(session, %{
        status: "ended",
        ended_at: DateTime.utc_now()
      })
    else
      {:error, "Not authorized to end this session"}
    end
  end

  @doc """
  Creates a message in a session.
  """
  def create_message(attrs \\ %{}) do
    %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Lists recent messages for a session.
  """
  def list_session_messages(session_id, limit \\ 100) do
    query = from m in Message,
      join: u in User, on: m.user_id == u.id,
      where: m.session_id == ^session_id,
      order_by: [asc: m.inserted_at],
      limit: ^limit,
      select: %{
        id: m.id,
        content: m.content,
        user_id: m.user_id,
        username: u.username,
        avatar_url: u.avatar_url,
        inserted_at: m.inserted_at
      }

    Repo.all(query)
  end

  @doc """
  Lists recent messages for a session.
  """
  def list_recent_messages(session_id, limit \\ 50) do
    query = from m in Message,
      join: u in User, on: m.user_id == u.id,
      where: m.session_id == ^session_id,
      order_by: [desc: m.inserted_at],
      limit: ^limit,
      select: %{
        id: m.id,
        content: m.content,
        user_id: m.user_id,
        username: u.username,
        avatar_url: u.avatar_url,
        inserted_at: m.inserted_at
      }

    Repo.all(query) |> Enum.reverse()
  end

  @doc """
  Gets a single session with minimal details to avoid schema issues.
  """
  def get_session_with_basic_details!(id) do
    session = Session
      |> Repo.get!(id)
      |> Repo.preload([:creator, :host, :channel])

    # If no host is set, use creator as host
    host = session.host || session.creator

    %{session | host: host}
  end

  @doc """
  Simplified function to get session without participant details
  """
  def get_session_for_broadcast!(id) do
    Session
    |> Repo.get!(id)
    |> Repo.preload([:creator, :host, :channel])
  end

  @doc """
  Simplified participant count (returns 1 for now)
  """
  def get_simple_participants_count(_session_id) do
    1
  end

  @doc """
  Check if user can access broadcast (simplified - always true for now)
  """
  def can_access_broadcast?(_session_id, _user_id) do
    true
  end

  @doc """
  Add participant (simplified - no-op for now)
  """
  def add_simple_participant(_session_id, _user_id, _role \\ "participant") do
    {:ok, nil}
  end

  @doc """
  Invites a user to a session.
  """
  def invite_user_to_session(session_id, email, role, inviter) do
    # Check if user exists
    user = Frestyl.Accounts.get_user_by_email(email)

    # Get the session
    session = get_session(session_id)

    if is_nil(session) do
      {:error, "Session not found"}
    else
      invitation_params = %{
        session_id: session_id,
        email: email,
        role: role,
        inviter_id: inviter.id,
        token: generate_invitation_token()
      }

      # If user exists, associate the invitation
      invitation_params = if user do
        Map.put(invitation_params, :user_id, user.id)
      else
        invitation_params
      end

      # Insert the invitation
      %Invitation{}
      |> Invitation.changeset(invitation_params)
      |> Repo.insert()
      |> case do
        {:ok, invitation} ->
          # Send email notification
          if user do
            # User already exists - send email with joining instructions
            Frestyl.Notifications.send_session_invitation(invitation, session, inviter)
          else
            # New user - send invitation to sign up
            Frestyl.Notifications.send_invite_and_session_invitation(invitation, session, inviter)
          end

          {:ok, invitation}

        error -> error
      end
    end
  end

  @doc """
  Checks if a user is invited to a session.
  """
  def is_user_invited?(session_id, user_id) do
    from(i in Invitation,
      where: i.session_id == ^session_id and i.user_id == ^user_id and not i.accepted,
      select: count(i.id) > 0
    )
    |> Repo.one()
  end

  @doc """
  Accepts a session invitation.
  """
  def accept_invitation(token) do
    invitation =
      from(i in Invitation, where: i.token == ^token and not i.accepted)
      |> Repo.one()

    if invitation do
      # Mark invitation as accepted
      invitation
      |> Invitation.accept_changeset()
      |> Repo.update()
      |> case do
        {:ok, updated_invitation} ->
          # Add user as participant
          if updated_invitation.user_id do
            add_participant(
              updated_invitation.session_id,
              updated_invitation.user_id,
              updated_invitation.role
            )
          end

          {:ok, updated_invitation}

        error -> error
      end
    else
      {:error, "Invalid or already used invitation"}
    end
  end

  @doc """
  Gets or initializes workspace state for a session.
  """
  def get_workspace_state(session_id) do
    session = get_session(session_id)

    if session do
      session.workspace_state
    else
      nil
    end
  end

  @doc """
  Saves workspace state for a session.
  """
  def save_workspace_state(session_id, workspace_state) do
    session = get_session(session_id)

    if session do
      session
      |> Session.workspace_state_changeset(workspace_state)
      |> Repo.update()
    else
      {:error, "Session not found"}
    end
  end

  # Private helpers

  defp generate_invitation_token do
    :crypto.strong_rand_bytes(24)
    |> Base.url_encode64(padding: false)
  end

  @doc """
  Lists participants for a session with user details.
  """
  def list_session_participants(session_id) do
    query = from sp in SessionParticipant,
      join: u in User, on: sp.user_id == u.id,
      where: sp.session_id == ^session_id,
      select: %{
        id: sp.id,
        user_id: sp.user_id,
        role: sp.role,
        joined_at: sp.inserted_at,
        left_at: sp.updated_at,
        user: %{
          id: u.id,
          username: u.username,
          name: u.name,
          avatar_url: u.avatar_url
        }
      },
      order_by: [asc: sp.inserted_at]

    Repo.all(query)
  end

  @doc """
  Gets a participant by their ID.
  """
  def get_participant!(id) do
    SessionParticipant
    |> Repo.get!(id)
    |> Repo.preload(:user)
  end

  @doc """
  Gets participants count for a session.
  """
  def get_participants_count(session_id) do
    from(sp in SessionParticipant, where: sp.session_id == ^session_id, select: count(sp.id))
    |> Repo.one()
  end

  @doc """
  Checks if the waiting room is open for a broadcast.
  """
  def waiting_room_open?(session) do
    if session.waiting_room_enabled && session.waiting_room_open_time do
      now = DateTime.utc_now()
      DateTime.compare(now, session.waiting_room_open_time) in [:eq, :gt]
    else
      false
    end
  end

  @doc """
  Checks if a broadcast is live (active).
  """
  def broadcast_live?(session) do
    session.status == "active" && session.broadcast_type != nil
  end

  @doc """
  Updates the participant role.
  """
  def update_participant_role(session_id, user_id, new_role) do
    participant = Repo.get_by!(SessionParticipant, session_id: session_id, user_id: user_id)

    participant
    |> SessionParticipant.changeset(%{role: new_role})
    |> Repo.update()
  end

  @doc """
  Records when a participant joins the active session.
  """
  def mark_participant_joined(session_id, user_id) do
    participant = Repo.get_by!(SessionParticipant, session_id: session_id, user_id: user_id)

    participant
    |> SessionParticipant.changeset(%{joined_at: DateTime.utc_now()})
    |> Repo.update()
  end

  @doc """
  Records when a participant leaves the active session.
  """
  def mark_participant_left(session_id, user_id) do
    participant = Repo.get_by!(SessionParticipant, session_id: session_id, user_id: user_id)

    participant
    |> SessionParticipant.changeset(%{left_at: DateTime.utc_now()})
    |> Repo.update()
  end

  @doc """
  Start a broadcast (change status from scheduled to active).
  """
  def start_broadcast(session) do
    session
    |> Session.changeset(%{
      status: "active",
      started_at: DateTime.utc_now()
    })
    |> Repo.update()
  end

  @doc """
  Gets current broadcast statistics.
  """
  def get_broadcast_stats(session_id) do
    participants = list_session_participants(session_id)

    %{
      total: length(participants),
      waiting: Enum.count(participants, &is_nil(&1.joined_at)),
      active: Enum.count(participants, &(!is_nil(&1.joined_at) && is_nil(&1.left_at))),
      left: Enum.count(participants, &!is_nil(&1.left_at))
    }
  end

  @doc """
  Creates or updates broadcast settings.
  """
  def update_broadcast_settings(session, settings) do
    session
    |> Session.changeset(settings)
    |> Repo.update()
  end
end
