# lib/frestyl/sessions.ex
defmodule Frestyl.Sessions do
  @moduledoc """
  The Sessions context.
  """
  require Logger

  import Ecto.Query, warn: false
  alias Frestyl.Repo

  alias Frestyl.Sessions.Session
  alias Frestyl.Sessions.SessionParticipant
  alias Frestyl.Sessions.Message
  alias Frestyl.Sessions.Invitation
  alias Frestyl.Accounts.User


  @doc """
  Gets a single session with preloaded associations.
  """
  def get_session_with_details!(id) do
    Repo.get!(Session, id)
    |> Repo.preload([:creator, :host, :channel, :session_participants])
  end

  @doc """
  Gets upcoming broadcasts with proper timezone handling
  """
  def get_upcoming_broadcasts(channel_id) do
    now = DateTime.utc_now()

    from(s in Session,
      where: s.channel_id == ^channel_id
        and s.session_type == "broadcast"
        and s.status == "scheduled"
        and (is_nil(s.scheduled_for) or s.scheduled_for > ^now),
      order_by: [asc: s.scheduled_for],
      preload: [:creator, :host, :participants]
    )
    |> Repo.all()
  end

  @doc """
  Create broadcast with proper timezone handling
  """
  def create_broadcast(attrs) do
    # Ensure broadcast-specific defaults
    broadcast_attrs = attrs
      |> Map.put("session_type", "broadcast")
      |> Map.put_new("visibility", "public")
      |> Map.put_new("allow_audience_participation", true)

    case create_session(broadcast_attrs) do
      {:ok, broadcast} ->
        # Additional broadcast setup if needed
        {:ok, broadcast}
      error -> error
    end
  end

  def create_studio_session(attrs) do
    %Session{}
    |> Session.studio_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a session specifically for story development with proper validation
  """
  def create_story_session(session_params, user) do
    # Ensure we have the required fields with proper values
    validated_params = session_params
    |> Map.put("session_type", "regular")  # Ensure valid enum value
    |> Map.put("creator_id", user.id)
    |> Map.put("host_id", user.id)  # User hosts their own story sessions
    |> Map.put("status", "active")
    |> Map.put("is_public", false)  # Story sessions are private by default
    |> ensure_required_session_fields()

    create_session(validated_params)
  end

  @doc """
  Ensure all required session fields are present with valid defaults
  """
  defp ensure_required_session_fields(params) do
    params
    |> Map.put_new("title", "Story Writing Session")
    |> Map.put_new("description", "Collaborative story writing session")
    |> Map.put_new("session_type", "regular")
    |> Map.put_new("status", "active")
    |> Map.put_new("is_public", false)
    |> Map.put_new("waiting_room_enabled", false)
    |> Map.put_new("max_participants", 10)
    |> Map.put_new("workspace_state", %{})
    |> validate_channel_exists()
  end

  @doc """
  Validate that the channel_id exists and user has access
  """
  defp validate_channel_exists(params) do
    case Map.get(params, "channel_id") do
      nil ->
        Map.put(params, "validation_error", "channel_id is required")
      channel_id ->
        # Check if channel exists (you might want to add this validation)
        case Frestyl.Channels.get_channel(channel_id) do
          nil -> Map.put(params, "validation_error", "Channel not found")
          _channel -> params
        end
    end
  end

  @doc """
  Alternative approach: Create session with better error handling
  """
  def create_session_with_fallback(session_params) do
    case create_session(session_params) do
      {:ok, session} -> {:ok, session}
      {:error, changeset} ->
        # Log the specific validation errors for debugging
        IO.inspect(changeset.errors, label: "Session creation validation errors")

        # Check if it's a missing channel issue
        if has_channel_error?(changeset) do
          {:error, :missing_channel}
        else
          {:error, changeset}
        end
    end
  end

  defp has_channel_error?(changeset) do
    changeset.errors
    |> Enum.any?(fn {field, _} -> field == :channel_id end)
  end

  # Helper function to ensure datetime is in UTC
  defp ensure_utc_datetime(params, key) do
    case Map.get(params, key) do
      nil -> params

      %DateTime{} = dt ->
        # Already DateTime, ensure it's in UTC
        case DateTime.shift_zone(dt, "UTC") do
          {:ok, utc_dt} -> Map.put(params, key, utc_dt)
          {:error, _} -> params
        end

      %NaiveDateTime{} = naive_dt ->
        # Convert NaiveDateTime to UTC DateTime
        utc_dt = DateTime.from_naive!(naive_dt, "Etc/UTC")
        Map.put(params, key, utc_dt)

      datetime_string when is_binary(datetime_string) ->
        case parse_datetime(datetime_string) do
          nil -> Map.delete(params, key)
          parsed_dt -> Map.put(params, key, parsed_dt)
        end

      _ -> Map.delete(params, key)
    end
  end

  # Enhanced datetime parser
  defp parse_datetime(nil), do: nil

  defp parse_datetime(datetime_string) when is_binary(datetime_string) do
    cond do
      # ISO8601 with timezone
      String.contains?(datetime_string, "T") and String.contains?(datetime_string, "Z") ->
        case DateTime.from_iso8601(datetime_string) do
          {:ok, datetime, _offset} -> datetime
          {:error, _} -> nil
        end

      # ISO8601 without timezone (assume UTC)
      String.contains?(datetime_string, "T") ->
        case DateTime.from_iso8601(datetime_string <> "Z") do
          {:ok, datetime, _offset} -> datetime
          {:error, _} ->
            # Try as naive datetime
            case NaiveDateTime.from_iso8601(datetime_string) do
              {:ok, naive_dt} -> DateTime.from_naive!(naive_dt, "Etc/UTC")
              {:error, _} -> nil
            end
        end

      true -> nil
    end
  end

  defp parse_datetime(%DateTime{} = datetime), do: datetime
  defp parse_datetime(_), do: nil

  @doc """
  Creates a new session - either collaborative or broadcast.
  """
  def create_session(attrs) do
    %Session{}
    |> Session.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, session} ->
        # Add creator as first participant with host role
        add_participant(session.id, attrs["creator_id"] || attrs[:creator_id], "host")

        # Broadcast session created event
        Phoenix.PubSub.broadcast(
          Frestyl.PubSub,
          "channel:#{session.channel_id}",
          {:session_created, session}
        )

        {:ok, session}
      error -> error
    end
  end

  @doc """
  Creates a changeset for session updates in the management interface.
  """
  def change_session(session, attrs \\ %{}) do
    Session.changeset(session, attrs)
  end

  @doc """
  Creates a changeset specifically for broadcast updates.
  """
  def change_broadcast(broadcast, attrs \\ %{}) do
    Session.broadcast_changeset(broadcast, attrs)
  end

  @doc """
  Lists sessions for a specific channel with filters.
  """
  def list_channel_sessions(channel_id, filters \\ %{}) do
    query = from s in Session,
      where: s.channel_id == ^channel_id

    query = case Map.get(filters, :session_type) do
      nil -> query
      type -> from s in query, where: s.session_type == ^type
    end

    query = case Map.get(filters, :status) do
      nil -> query
      status -> from s in query, where: s.status == ^status
    end

    Repo.all(query)
  end

    @doc """
    Gets broadcast stats with proper participant status calculation
    """
    def get_broadcast_stats(session_id) do
      participants_query = from p in SessionParticipant,
        where: p.session_id == ^session_id

      total = Repo.aggregate(participants_query, :count, :id)

      # Active: joined but not left
      active = from(p in participants_query,
        where: not is_nil(p.joined_at) and is_nil(p.left_at))
        |> Repo.aggregate(:count, :id)

      # Waiting: registered but not yet joined
      waiting = from(p in participants_query,
        where: is_nil(p.joined_at) and is_nil(p.left_at))
        |> Repo.aggregate(:count, :id)

      # Left: has left_at timestamp
      left = from(p in participants_query, where: not is_nil(p.left_at))
        |> Repo.aggregate(:count, :id)

      %{
        total: total,
        active: active,
        waiting: waiting,
        left: left
      }
    end


  @doc """
  Marks when a participant actually joins the live session (not just registers).
  """
  def mark_participant_joined(session_id, user_id) do
    case Repo.get_by(SessionParticipant, session_id: session_id, user_id: user_id) do
      nil ->
        {:error, "Participant not found"}
      participant ->
        participant
        |> SessionParticipant.changeset(%{joined_at: DateTime.utc_now()})
        |> Repo.update()
    end
  end

  @doc """
  Marks when a participant leaves the live session.
  """
  def mark_participant_left(session_id, user_id) do
    case Repo.get_by(SessionParticipant, session_id: session_id, user_id: user_id) do
      nil ->
        {:error, "Participant not found"}
      participant ->
        participant
        |> SessionParticipant.changeset(%{left_at: DateTime.utc_now()})
        |> Repo.update()
    end
  end

  @doc """
  Gets a single session participant
  """
  def get_session_participant(session_id, user_id) when is_binary(user_id) do
    get_session_participant(session_id, String.to_integer(user_id))
  end

  def get_session_participant(session_id, user_id) when is_integer(user_id) do
    Repo.get_by(SessionParticipant, session_id: session_id, user_id: user_id)
  end

  @doc """
  Removes a participant from a session
  """
  def remove_participant(session_id, user_id) when is_binary(user_id) do
    remove_participant(session_id, String.to_integer(user_id))
  end

  def remove_participant(session_id, user_id) when is_integer(user_id) do
    case get_session_participant(session_id, user_id) do
      nil ->
        {:error, :not_found}
      participant ->
        # Don't delete, just mark as left
        participant
        |> SessionParticipant.changeset(%{left_at: DateTime.utc_now()})
        |> Repo.update()
    end
  end

  @doc """
  Gets the participant count for a session.
  """
  def get_participants_count(session_id) do
    from(p in SessionParticipant, where: p.session_id == ^session_id)
    |> Repo.aggregate(:count, :id)
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
  Ends a session - single definition
  """
  def end_session(%Session{} = session) do
    session
    |> Session.changeset(%{
      status: "ended",
      ended_at: DateTime.truncate(DateTime.utc_now(), :second)
    })
    |> Repo.update()
  end

  @doc """
  Lists active sessions for a channel.
  """
  def list_active_broadcasts(channel_id) do
    from(s in Session,
      where: s.channel_id == ^channel_id
      and s.session_type == "broadcast"
      and s.status == "active",
      order_by: [desc: s.started_at],
      preload: [:host, :creator]
    )
    |> Repo.all()
  end

  def list_all_broadcasts_for_channel(channel_id) do
    from(s in Session,
      where: s.channel_id == ^channel_id and s.session_type == "broadcast",
      order_by: [desc: s.scheduled_for, desc: s.created_at],
      preload: [:creator, :host, :participants]
    )
    |> Repo.all()
  end

  @doc """
  Returns a list of active sessions for a specific channel.
  """
  def list_active_sessions_for_channel(channel_id) do
    now = DateTime.utc_now()

    # Option 1: Simple query without participants_count
    from(s in Session,
      where: s.channel_id == ^channel_id and
            s.status == "active" and
            (is_nil(s.broadcast_type)) and  # Normal sessions, not broadcasts
            (is_nil(s.ended_at) or s.ended_at > ^now),
      order_by: [desc: s.inserted_at])
    |> Repo.all()
  end

    @doc """
  Lists user sessions with options.
  """
  def list_user_sessions(user_id, opts \\ []) do
    _limit = Keyword.get(opts, :limit, 10)

    # For now, return empty list until you implement the schema
    []

    # When you have the schema, use this:
    # Session
    # |> where([s], s.created_by_id == ^user_id)
    # |> order_by([s], desc: s.inserted_at)
    # |> limit(^limit)
    # |> Repo.all()
  end

  @doc """
  Lists active user sessions.
  """
  def list_active_user_sessions(user_id) do
    # For now, return empty list
    []

    # When you have the schema:
    # Session
    # |> where([s], s.created_by_id == ^user_id and s.status == "active")
    # |> order_by([s], desc: s.inserted_at)
    # |> Repo.all()
  end

  @doc """
  Counts user sessions.
  """
  def count_user_sessions(user_id) do
    # For now, return 0
    0

    # When you have the schema:
    # Session
    # |> where([s], s.created_by_id == ^user_id)
    # |> Repo.aggregate(:count)
  end

  @doc """
  Deletes a session.
  """
  def delete_session(session_id) do
    # For now, return success
    {:ok, %{id: session_id}}

    # When you have the schema:
    # case Repo.get(Session, session_id) do
    #   nil -> {:error, :not_found}
    #   session -> Repo.delete(session)
    # end
  end

  defp generate_session_id do
    "session_" <> (:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower))
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
  Lists upcoming broadcasts for a channel with proper timezone consideration
  """
  def list_upcoming_broadcasts_for_channel(channel_id) do
    now_utc = DateTime.utc_now()

    from(s in Session,
      where: s.channel_id == ^channel_id
      and s.session_type == "broadcast"
      and s.status in ["scheduled", "active"]  # Include both scheduled and active
      and (s.scheduled_for > ^now_utc or s.status == "active"),  # Future or currently live
      order_by: [
        # Active broadcasts first
        fragment("CASE WHEN ? = 'active' THEN 0 ELSE 1 END", s.status),
        asc: s.scheduled_for
      ],
      preload: [:host, :creator, :channel]
    )
    |> Repo.all()
  end

  @doc """
  Lists past sessions for a channel.
  """
  def list_past_sessions_for_channel(channel_id) do
    # Return maps instead of trying to merge into struct
    query = from s in Session,
      where: s.channel_id == ^channel_id and s.status == "ended",
      select: %{
        id: s.id,
        title: s.title,
        description: s.description,
        status: s.status,
        ended_at: s.ended_at,
        creator_id: s.creator_id,
        host_id: s.host_id,
        participants_count: fragment("(SELECT COUNT(*) FROM session_participants WHERE session_id = ?)", s.id),
        creator_name: fragment("(SELECT username FROM users WHERE id = ?)", s.creator_id),
        host_name: fragment("(SELECT username FROM users WHERE id = ?)", s.host_id)
      },
      order_by: [desc: s.ended_at]

    Repo.all(query)
  end

  @doc """
  Enhanced add_participant that handles conflicts better
  """
  def add_participant(session_id, user_id, role \\ "participant") do
    try do
      case get_session_participant(session_id, user_id) do
        nil ->
          # Create new participant
          %SessionParticipant{}
          |> SessionParticipant.changeset(%{
            session_id: session_id,
            user_id: user_id,
            role: role
          })
          |> Repo.insert()

        existing_participant ->
          # Participant exists - check if they left and allow re-joining
          if existing_participant.left_at do
            existing_participant
            |> SessionParticipant.changeset(%{left_at: nil})
            |> Repo.update()
          else
            {:error, :participant_already_exists}
          end
      end
    rescue
      e -> {:error, {:database_error, e}}
    end
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
  Checks if a user is registered for a broadcast and hasn't left
  """
  def user_registered_for_broadcast?(broadcast_id, user_id) do
    from(p in SessionParticipant,
      where: p.session_id == ^broadcast_id and p.user_id == ^user_id
    )
    |> Repo.exists?()
  end

  def user_registered_for_broadcast?(user_id, broadcast_id) when is_binary(user_id) do
    case Integer.parse(user_id) do
      {int_id, ""} -> user_registered_for_broadcast?(int_id, broadcast_id)
      _ -> false
    end
  end

  def user_registered_for_broadcast?(_, _), do: false

  @doc """
  Joins a user to a session.
  """
  defp utc_now_truncated do
    DateTime.truncate(DateTime.utc_now(), :second)
  end

  @doc """
  Adds a user to a session as a participant
  """
  def join_session(session_id, user_id) do
    with session when not is_nil(session) <- get_session(session_id),
        true <- session.status == "active",
        {:ok, participant} <- add_participant(session_id, user_id, "participant") do

      # Broadcast join event
      Phoenix.PubSub.broadcast(
        Frestyl.PubSub,
        "session:#{session_id}",
        {:user_joined, user_id}
      )

      {:ok, participant}
    else
      nil -> {:error, :session_not_found}
      false -> {:error, :session_not_active}
      {:error, :participant_already_exists} -> {:error, :already_joined}
      error -> error
    end
  end

  @doc """
  Removes a user from a session
  """
  def leave_session(session_id, user_id) do
    case get_session_participant(session_id, user_id) do
      nil ->
        {:error, :not_found}

      participant ->
        participant
        |> SessionParticipant.changeset(%{
          left_at: DateTime.truncate(DateTime.utc_now(), :second)
        })
        |> Repo.update()
    end
  end

  @doc """
  Starts a broadcast - single definition
  """
  def start_broadcast(session) do
    with {:ok, updated_session} <- update_session(session, %{
      status: "active",
      started_at: DateTime.utc_now()
    }) do
      # Notify all registered participants
      notify_participants_broadcast_live(updated_session)
      {:ok, updated_session}
    end
  end

  def start_scheduled_broadcast(broadcast_id) do
    with broadcast when not is_nil(broadcast) <- get_session(broadcast_id),
        true <- broadcast.status == "scheduled",
        {:ok, updated_broadcast} <- update_session_status(broadcast, "active") do

      # Set started_at timestamp
      update_session(updated_broadcast, %{started_at: DateTime.utc_now()})
    else
      nil -> {:error, :broadcast_not_found}
      false -> {:error, :broadcast_not_scheduled}
      error -> error
    end
  end

  @doc """
  Ends an active broadcast.
  """
  def end_broadcast(broadcast_id) do
    with broadcast when not is_nil(broadcast) <- get_session(broadcast_id),
        true <- broadcast.status == "active",
        {:ok, updated_broadcast} <- update_session_status(broadcast, "ended") do

      # Set ended_at timestamp
      update_session(updated_broadcast, %{ended_at: DateTime.utc_now()})
    else
      nil -> {:error, :broadcast_not_found}
      false -> {:error, :broadcast_not_active}
      error -> error
    end
  end

  @doc """
  Lists sessions by type for a channel.
  """
  def list_sessions_by_type(channel_id, session_type) do
    from(s in Session,
      where: s.channel_id == ^channel_id and s.session_type == ^session_type,
      order_by: [desc: s.created_at],
      preload: [:creator, :participants]
    )
    |> Repo.all()
  end

  @doc """
  Gets session with full associations for studio use.
  """
  def get_session_for_studio(session_id) do
    from(s in Session,
      where: s.id == ^session_id,
      preload: [:creator, :host, :participants, :channel]
    )
    |> Repo.one()
  end

  # ============================================================================
  # CHANGE TRACKING FUNCTIONS
  # ============================================================================

  @doc """
  Validates broadcast scheduling constraints.
  """
  def validate_broadcast_schedule(attrs, user) do
    # Check if user can schedule broadcasts
    tier = Frestyl.Features.TierManager.get_account_tier(user)

    case Frestyl.Features.TierManager.feature_available?(tier, :broadcast_scheduling) do
      true ->
        # Additional validation for scheduled time, duration limits, etc.
        validate_schedule_timing(attrs, tier)
      false ->
        {:error, :tier_insufficient}
    end
  end

  defp validate_schedule_timing(attrs, tier) do
    limits = Frestyl.Features.TierManager.get_tier_limits(tier)
    max_duration = Map.get(limits, :max_broadcast_duration, 30)

    scheduled_for = attrs["scheduled_for"] || attrs[:scheduled_for]

    cond do
      is_nil(scheduled_for) ->
        {:ok, attrs}

      DateTime.compare(scheduled_for, DateTime.utc_now()) != :gt ->
        {:error, :must_be_future}

      max_duration != :unlimited and
      DateTime.diff(DateTime.add(scheduled_for, max_duration * 60), DateTime.utc_now()) < 0 ->
        {:error, :duration_exceeds_limit}

      true ->
        {:ok, attrs}
    end
  end

  defp notify_participants_broadcast_live(session) do
    # Get all registered participants
    participants = list_session_participants(session.id)

    # Broadcast to each participant
    Enum.each(participants, fn participant ->
      Phoenix.PubSub.broadcast(
        Frestyl.PubSub,
        "user:#{participant.user_id}",
        {:broadcast_live, session.id, session.title, session.channel_id}
      )
    end)

    # Also broadcast to the channel for real-time updates
    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "channel:#{session.channel_id}",
      {:broadcast_status_changed, session.id, "active"}
    )
  end

  # Handles live broadcasts
  def register_for_broadcast(broadcast_id, user_id) when is_integer(broadcast_id) and is_integer(user_id) do
    try do
      broadcast = get_session(broadcast_id)

      if is_nil(broadcast) do
        {:error, :broadcast_not_found}
      else
        case broadcast.status do
          "active" ->
            # Broadcast is already live
            case add_participant(broadcast_id, user_id, "participant") do
              {:ok, participant} ->
                # Mark as joined immediately since broadcast is live
                mark_participant_joined(broadcast_id, user_id)
                {:ok, :join_now, participant}
              error -> error
            end

          "scheduled" ->
            # Normal registration for future broadcast
            case add_participant(broadcast_id, user_id, "participant") do
              {:ok, participant} -> {:ok, :registered, participant}
              {:error, :participant_already_exists} -> {:error, :already_registered}
              error -> error
            end

          _ ->
            {:error, :broadcast_not_available}
        end
      end
    rescue
      e -> {:error, {:unexpected_error, e}}
    end
  end

  def register_for_broadcast(broadcast_id, user_id) when is_binary(broadcast_id) do
    case Integer.parse(broadcast_id) do
      {int_id, ""} -> register_for_broadcast(int_id, user_id)
      _ -> {:error, :invalid_broadcast_id}
    end
  end

  def register_for_broadcast(broadcast_id, user_id) when is_binary(user_id) do
    case Integer.parse(user_id) do
      {int_id, ""} -> register_for_broadcast(broadcast_id, int_id)
      _ -> {:error, :invalid_user_id}
    end
  end

  def get_user_registration(broadcast_id, user_id) do
    from(p in SessionParticipant,
      where: p.session_id == ^broadcast_id and p.user_id == ^user_id
    )
    |> Repo.one()
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
  Clears all messages for a session (for broadcast management)
  """
  def clear_session_messages(session_id) do
    from(m in Message, where: m.session_id == ^session_id)
    |> Repo.delete_all()
    |> case do
      {count, _} -> {:ok, count}
      error -> error
    end
  end

  @doc """
  Deletes a specific message (for moderation)
  """
  def delete_message(message_id) when is_binary(message_id) do
    delete_message(String.to_integer(message_id))
  end

  def delete_message(message_id) when is_integer(message_id) do
    case Repo.get(Message, message_id) do
      nil -> {:error, :not_found}
      message -> Repo.delete(message)
    end
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
  Gets session with participant count (returns a map, not a struct)
  """
  def get_session_with_participant_count(session_id) do
    from(s in Session,
      where: s.id == ^session_id,
      select: %{
        session: s,
        participants_count: fragment("(SELECT COUNT(*) FROM session_participants WHERE session_id = ?)", s.id)
      })
    |> Repo.one()
  end

  @doc """
  Lists active sessions with participant counts (returns maps, not structs)
  """
  def list_active_sessions_with_counts(channel_id) do
    now = DateTime.utc_now()

    from(s in Session,
      where: s.channel_id == ^channel_id and
            s.status == "active" and
            (is_nil(s.broadcast_type)) and  # Normal sessions, not broadcasts
            (is_nil(s.ended_at) or s.ended_at > ^now),
      select: %{
        id: s.id,
        title: s.title,
        description: s.description,
        status: s.status,
        creator_id: s.creator_id,
        host_id: s.host_id,
        inserted_at: s.inserted_at,
        participants_count: fragment("(SELECT COUNT(*) FROM session_participants WHERE session_id = ?)", s.id)
      },
      order_by: [desc: s.inserted_at])
    |> Repo.all()
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
      %{
        text: %{
          version: 0,
          content: "",
          pending_operations: [],
          cursors: %{},
          selection: nil
        },
        audio: %{
          version: 0,
          track_counter: 0,
          tracks: [],
          playing: false,
          recording: false,
          current_time: 0,
          selected_track: nil,
          zoom_level: 1.0
        },
        audio_settings: %{  # Add this
          buffer_size: 256,
          input_device: nil,
          output_device: nil,
          sample_rate: 44100,
          track_counter: 0
        },
        midi: %{
          version: 0,
          notes: [],
          current_instrument: "piano",
          grid_size: 16,
          octave: 4,
          selected_notes: []
        },
        visual: %{
          version: 0,
          color: "#4f46e5",
          tool: "brush",
          brush_size: 5,
          elements: [],
          selected_element: nil
        },
        ot_state: %{
          server_version: 0,
          acknowledged_ops: MapSet.new([]),
          local_version: 0,
          operation_queue: [],
          user_operations: %{}
        },
        pending_operations: [],
        ot_version: 0
      }
    else
      nil
    end
  end

  defp default_workspace_state do
    %{
      audio_settings: %{
        input_device: nil,
        output_device: nil,
        sample_rate: 44100,
        buffer_size: 256
      },
      video_settings: %{
        camera_device: nil,
        resolution: "720p",
        frame_rate: 30
      },
      screen_share: %{
        enabled: false,
        source: nil
      },
      participants: [],
      chat_enabled: true,
      recording_enabled: false
    }
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
  Updates a participant's role - single definition
  """
  def update_participant_role(session_id, user_id, new_role) when is_binary(user_id) do
    update_participant_role(session_id, String.to_integer(user_id), new_role)
  end

  def update_participant_role(session_id, user_id, new_role) when is_integer(user_id) do
    case get_session_participant(session_id, user_id) do
      nil ->
        {:error, :not_found}
      participant ->
        participant
        |> SessionParticipant.changeset(%{role: new_role})
        |> Repo.update()
    end
  end

  @doc """
  Gets participants count for a session.
  """
  def get_participants_count(session_id) do
    from(p in SessionParticipant,
      where: p.session_id == ^session_id,
      select: count(p.id)
    )
    |> Repo.one()
    |> case do
      nil -> 0
      count -> count
    end
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
  Lists all participants for a session
  """
  def list_session_participants(session_id) do
    from(sp in SessionParticipant,
      where: sp.session_id == ^session_id,
      preload: [:user],
      order_by: [desc: sp.joined_at]
    )
    |> Repo.all()
  end

  @doc """
  Creates or updates broadcast settings.
  """
  def update_broadcast_settings(session, settings) do
    session
    |> Session.changeset(settings)
    |> Repo.update()
  end

  @doc """
  Counts active sessions for a user (for tier limit checking).
  """
  def count_user_active_sessions(user_id) do
    from(s in Session,
      join: p in SessionParticipant, on: p.session_id == s.id,
      where: p.user_id == ^user_id and s.status == "active",
      select: count(s.id)
    )
    |> Repo.one()
    |> case do
      nil -> 0
      count -> count
    end
  end

  @doc """
  Lists active sessions for a channel.
  """
  def list_active_channel_sessions(channel_id) do
    from(s in Session,
      where: s.channel_id == ^channel_id and s.status == "active",
      order_by: [desc: s.updated_at],
      preload: [:creator, :participants]
    )
    |> Repo.all()
  end

  @doc """
  Gets live broadcasts for a channel.
  """
  def get_live_broadcasts(channel_id) do
    from(s in Session,
      where: s.channel_id == ^channel_id
        and s.session_type == "broadcast"
        and s.status == "active",
      order_by: [desc: s.started_at],
      preload: [:creator, :host, :participants]
    )
    |> Repo.all()
  end

  @doc """
  Updates session status and broadcasts the change.
  """
  def update_session_status(session, new_status) do
    case update_session(session, %{status: new_status}) do
      {:ok, updated_session} ->
        # Broadcast status change
        Phoenix.PubSub.broadcast(
          Frestyl.PubSub,
          "session:#{session.id}",
          {:status_changed, new_status}
        )

        Phoenix.PubSub.broadcast(
          Frestyl.PubSub,
          "channel:#{session.channel_id}",
          {:session_status_changed, session.id, new_status}
        )

        {:ok, updated_session}
      error -> error
    end
  end

end
