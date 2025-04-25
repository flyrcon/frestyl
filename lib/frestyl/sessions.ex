defmodule Frestyl.Sessions do
  @moduledoc """
  The Sessions context handles collaborative sessions between users.
  """

  import Ecto.Query, warn: false
  alias Frestyl.Repo
  alias Frestyl.Sessions.Session

  @doc """
  Returns the list of sessions.
  """
  def list_sessions do
    Repo.all(Session)
  end

  @doc """
  Gets a single session.

  Raises `Ecto.NoResultsError` if the Session does not exist.
  """
  def get_session!(id), do: Repo.get!(Session, id)

  @doc """
  Gets a single session with preloaded associations.
  """
  def get_session_with_details!(id) do
    Repo.get!(Session, id)
    |> Repo.preload([:creator, :participants, :channels, :media_items])
  end

  @doc """
  Creates a session.
  """
  def create_session(attrs \\ %{}) do
    %Session{}
    |> Session.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a session.
  """
  def update_session(%Session{} = session, attrs) do
    session
    |> Session.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a session.
  """
  def delete_session(%Session{} = session) do
    Repo.delete(session)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking session changes.
  """
  def change_session(%Session{} = session, attrs \\ %{}) do
    Session.changeset(session, attrs)
  end

  @doc """
  Adds a participant to a session.
  """
  def add_participant(session_id, user_id) do
    query = from sp in "session_participants",
            where: sp.session_id == ^session_id and sp.user_id == ^user_id,
            select: count(sp.id)

    if Repo.one(query) == 0 do
      Repo.insert_all("session_participants", [
        %{
          session_id: session_id,
          user_id: user_id,
          inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
          updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
        }
      ])

      {:ok, get_session_with_details!(session_id)}
    else
      {:error, :already_added}
    end
  end

  @doc """
  Removes a participant from a session.
  """
  def remove_participant(session_id, user_id) do
    query = from sp in "session_participants",
            where: sp.session_id == ^session_id and sp.user_id == ^user_id

    Repo.delete_all(query)

    {:ok, get_session_with_details!(session_id)}
  end

  @doc """
  Lists upcoming sessions for a user.
  """
  def list_upcoming_sessions_for_user(user_id) do
    now = DateTime.utc_now()

    creator_query = from s in Session,
                   where: s.creator_id == ^user_id and s.start_time > ^now,
                   order_by: [asc: s.start_time]

    participant_query = from s in Session,
                       join: sp in "session_participants", on: sp.session_id == s.id,
                       where: sp.user_id == ^user_id and s.start_time > ^now,
                       order_by: [asc: s.start_time]

    creator_sessions = Repo.all(creator_query)
    participant_sessions = Repo.all(participant_query)

    (creator_sessions ++ participant_sessions)
    |> Enum.uniq_by(& &1.id)
    |> Enum.sort_by(& &1.start_time)
  end

  @doc """
  Lists active sessions for a user.
  """
  def list_active_sessions_for_user(user_id) do
    now = DateTime.utc_now()

    creator_query = from s in Session,
                   where: s.creator_id == ^user_id and s.start_time <= ^now and
                          (is_nil(s.end_time) or s.end_time >= ^now) and
                          s.status == :in_progress,
                   order_by: [asc: s.start_time]

    participant_query = from s in Session,
                       join: sp in "session_participants", on: sp.session_id == s.id,
                       where: sp.user_id == ^user_id and s.start_time <= ^now and
                              (is_nil(s.end_time) or s.end_time >= ^now) and
                              s.status == :in_progress,
                       order_by: [asc: s.start_time]

    creator_sessions = Repo.all(creator_query)
    participant_sessions = Repo.all(participant_query)

    (creator_sessions ++ participant_sessions)
    |> Enum.uniq_by(& &1.id)
    |> Enum.sort_by(& &1.start_time)
  end

  @doc """
  Starts a session, changing its status to in_progress.
  """
  def start_session(%Session{} = session) do
    update_session(session, %{status: :in_progress})
  end

  @doc """
  Ends a session, changing its status to completed.
  """
  def end_session(%Session{} = session) do
    update_session(session, %{status: :completed, end_time: DateTime.utc_now()})
  end
end
