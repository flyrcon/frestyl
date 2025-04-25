# lib/frestyl/events.ex
defmodule Frestyl.Events do
  @moduledoc """
  The Events context.
  """

  import Ecto.Query, warn: false
  alias Frestyl.Repo

  alias Frestyl.Events.Event
  alias Frestyl.Events.EventAttendee
  alias Frestyl.Events.EventInvitation
  alias Frestyl.Events.Vote
  alias Frestyl.Accounts.User

  #
  # Event Management
  #

  @doc """
  Returns the list of events.
  """
  def list_events do
    Repo.all(Event)
  end

  @doc """
  Returns a list of upcoming events.
  """
  def list_upcoming_events do
    now = DateTime.utc_now()

    Event
    |> where([e], e.starts_at > ^now)
    |> where([e], e.status in [:scheduled, :live])
    |> order_by([e], asc: e.starts_at)
    |> Repo.all()
  end

  @doc """
  Gets a single event.
  """
  def get_event!(id), do: Repo.get!(Event, id)

  @doc """
  Gets a single event with preloaded associations.
  """
  def get_event_full!(id) do
    Event
    |> Repo.get!(id)
    |> Repo.preload([:host, :session, :attendees])
  end

  @doc """
  Creates a event.
  """
  def create_event(attrs \\ %{}, user) do
    %Event{}
    |> Event.changeset(Map.put(attrs, "host_id", user.id))
    |> Repo.insert()
  end

  @doc """
  Updates a event.
  """
  def update_event(%Event{} = event, attrs) do
    event
    |> Event.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Starts an event (changes status to "live").
  """
  def start_event(%Event{} = event) do
    update_event(event, %{status: :live})
  end

  @doc """
  Ends an event (changes status to "completed").
  """
  def end_event(%Event{} = event) do
    update_event(event, %{status: :completed})
  end

  @doc """
  Cancels an event (changes status to "cancelled").
  """
  def cancel_event(%Event{} = event) do
    update_event(event, %{status: :cancelled})
  end

  @doc """
  Deletes a event.
  """
  def delete_event(%Event{} = event) do
    Repo.delete(event)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking event changes.
  """
  def change_event(%Event{} = event, attrs \\ %{}) do
    Event.changeset(event, attrs)
  end

  @doc """
  Returns true if user is the host of the event.
  """
  def is_host?(%Event{} = event, %User{} = user) do
    event.host_id == user.id
  end

  #
  # Attendee Management
  #

  @doc """
  Registers a user for an event.
  """
  def register_for_event(%Event{} = event, %User{} = user) do
    attrs = %{
      event_id: event.id,
      user_id: user.id,
      status: get_initial_attendee_status(event)
    }

    %EventAttendee{}
    |> EventAttendee.changeset(attrs)
    |> Repo.insert()
  end

  defp get_initial_attendee_status(%Event{admission_type: :open}), do: :registered
  defp get_initial_attendee_status(%Event{admission_type: :paid}), do: :waiting
  defp get_initial_attendee_status(%Event{admission_type: :lottery}), do: :waiting
  defp get_initial_attendee_status(%Event{admission_type: :invite_only}), do: :waiting

  @doc """
  Updates an event attendee.
  """
  def update_attendee(%EventAttendee{} = attendee, attrs) do
    attendee
    |> EventAttendee.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Gets a single event attendee.
  """
  def get_attendee!(attendee_id), do: Repo.get!(EventAttendee, attendee_id)

  @doc """
  Gets an attendee by event and user.
  """
  def get_attendee_by_event_and_user(event_id, user_id) do
    Repo.get_by(EventAttendee, event_id: event_id, user_id: user_id)
  end

  @doc """
  Lists all attendees for an event.
  """
  def list_attendees(%Event{} = event) do
    EventAttendee
    |> where([a], a.event_id == ^event.id)
    |> preload(:user)
    |> Repo.all()
  end

  @doc """
  Admits an attendee to an event.
  """
  def admit_attendee(%EventAttendee{} = attendee) do
    update_attendee(attendee, %{status: :admitted})
  end

  @doc """
  Rejects an attendee from an event.
  """
  def reject_attendee(%EventAttendee{} = attendee) do
    update_attendee(attendee, %{status: :rejected})
  end

  @doc """
  Records when an attendee joins an event.
  """
  def join_event(%EventAttendee{} = attendee) do
    update_attendee(attendee, %{joined_at: DateTime.utc_now()})
  end

  @doc """
  Records when an attendee leaves an event.
  """
  def leave_event(%EventAttendee{} = attendee) do
    update_attendee(attendee, %{left_at: DateTime.utc_now()})
  end

  @doc """
  Updates payment status for an attendee.
  """
  def update_payment_status(%EventAttendee{} = attendee, status, amount \\ nil) do
    attrs = %{payment_status: status}

    attrs = if amount, do: Map.put(attrs, :payment_amount_in_cents, amount), else: attrs

    update_attendee(attendee, attrs)
  end

  @doc """
  Assigns lottery positions to waiting attendees.
  """
  def run_admission_lottery(%Event{admission_type: :lottery} = event) do
    # Get all waiting attendees
    attendees =
      EventAttendee
      |> where([a], a.event_id == ^event.id)
      |> where([a], a.status == :waiting)
      |> Repo.all()

    # Shuffle and assign positions
    attendees
    |> Enum.shuffle()
    |> Enum.with_index(1)
    |> Enum.each(fn {attendee, position} ->
      update_attendee(attendee, %{lottery_position: position})
    end)

    # Admit attendees based on max capacity
    if event.max_attendees do
      EventAttendee
      |> where([a], a.event_id == ^event.id)
      |> where([a], a.status == :waiting)
      |> where([a], a.lottery_position <= ^event.max_attendees)
      |> Repo.all()
      |> Enum.each(&admit_attendee/1)
    end

    :ok
  end

  #
  # Invitation Management
  #

  @doc """
  Creates an invitation for an event.
  """
  def create_invitation(%Event{} = event, email, invitee_id \\ nil) do
    attrs = %{
      event_id: event.id,
      email: email,
      invitee_id: invitee_id
    }

    %EventInvitation{}
    |> EventInvitation.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets an invitation by token.
  """
  def get_invitation_by_token(token) do
    Repo.get_by(EventInvitation, token: token)
  end

  @doc """
  Accepts an invitation.
  """
  def accept_invitation(%EventInvitation{} = invitation, user_id) do
    # Update invitation status
    {:ok, invitation} =
      invitation
      |> Ecto.Changeset.change(%{status: :accepted, invitee_id: user_id})
      |> Repo.update()

    # Create or update attendee record
    attendee = get_attendee_by_event_and_user(invitation.event_id, user_id) ||
               %EventAttendee{event_id: invitation.event_id, user_id: user_id}

    EventAttendee.changeset(attendee, %{status: :registered})
    |> Repo.insert_or_update()
  end

  @doc """
  Declines an invitation.
  """
  def decline_invitation(%EventInvitation{} = invitation) do
    invitation
    |> Ecto.Changeset.change(%{status: :declined})
    |> Repo.update()
  end

  #
  # Voting System
  #

  @doc """
  Cast a vote during an event.
  """
  def cast_vote(%Event{} = event, %User{} = voter, %User{} = creator, score, comment \\ nil) do
    attrs = %{
      event_id: event.id,
      voter_id: voter.id,
      creator_id: creator.id,
      score: score,
      comment: comment
    }

    # Check if vote already exists
    case Repo.get_by(Vote, event_id: event.id, voter_id: voter.id, creator_id: creator.id) do
      nil ->
        %Vote{}
        |> Vote.changeset(attrs)
        |> Repo.insert()
      existing_vote ->
        existing_vote
        |> Vote.changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Get all votes for a creator in an event.
  """
  def get_votes_for_creator(%Event{} = event, %User{} = creator) do
    Vote
    |> where([v], v.event_id == ^event.id)
    |> where([v], v.creator_id == ^creator.id)
    |> preload(:voter)
    |> Repo.all()
  end

  @doc """
  Calculate average score for a creator in an event.
  """
  def get_average_score(%Event{} = event, %User{} = creator) do
    query = from v in Vote,
            where: v.event_id == ^event.id and v.creator_id == ^creator.id,
            select: avg(v.score)

    Repo.one(query) || 0.0
  end

  @doc """
  Get event results with creator scores.
  """
  def get_event_results(%Event{} = event) do
    # First, get all creators who received votes
    creator_query = from v in Vote,
                    where: v.event_id == ^event.id,
                    distinct: v.creator_id,
                    select: v.creator_id

    creator_ids = Repo.all(creator_query)

    # Then, for each creator, calculate their average score
    Enum.map(creator_ids, fn creator_id ->
      creator = Repo.get!(User, creator_id)
      avg_score = get_average_score(event, creator)

      %{
        creator: creator,
        average_score: avg_score,
        votes_count: Repo.count(from v in Vote, where: v.event_id == ^event.id and v.creator_id == ^creator_id)
      }
    end)
    |> Enum.sort_by(fn %{average_score: score} -> score end, :desc)
  end
end
