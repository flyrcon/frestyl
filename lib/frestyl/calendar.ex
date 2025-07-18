# lib/frestyl/calendar.ex - Calendar Context (Updated for bigint foreign keys)
defmodule Frestyl.Calendar do
  @moduledoc """
  Calendar context for managing events, integrations, and views.
  """

  import Ecto.Query, warn: false
  alias Frestyl.Repo
  alias Frestyl.Calendar.{Event, EventAttendee, Integration, View}
  alias Frestyl.Features.TierManager

  # ============================================================================
  # EVENT MANAGEMENT
  # ============================================================================

  @doc """
  Gets events visible to a user based on their tier and channel memberships
  """
  def get_user_visible_events(user, account, opts \\ []) do
    start_date = Keyword.get(opts, :start_date, Date.utc_today())
    end_date = Keyword.get(opts, :end_date, Date.add(start_date, 30))
    event_types = Keyword.get(opts, :event_types, :all)

    user_tier = TierManager.get_user_tier(user)

    base_query = from e in Event,
      where: e.starts_at >= ^DateTime.new!(start_date, ~T[00:00:00]) and
             e.starts_at <= ^DateTime.new!(end_date, ~T[23:59:59]),
      order_by: [asc: e.starts_at],
      preload: [:creator, :attendees]

    case user_tier do
      "personal" ->
        # Free tier: Only channel events they belong to + own events
        channel_ids = get_user_channel_ids(user.id)

        from e in base_query,
          where: (e.channel_id in ^channel_ids and e.visibility in ["channel", "public"]) or
                 e.creator_id == ^user.id

      "creator" ->
        # Creator: Own events + channel events + limited cross-account visibility
        channel_ids = get_user_channel_ids(user.id)

        from e in base_query,
          where: e.creator_id == ^user.id or
                 e.account_id == ^account.id or
                 (e.channel_id in ^channel_ids and e.visibility in ["channel", "public"]) or
                 e.visibility == "public"

      tier when tier in ["professional", "enterprise"] ->
        # Professional+: Full visibility within account + public events
        from e in base_query,
          where: e.account_id == ^account.id or
                 e.visibility == "public" or
                 e.creator_id == ^user.id
    end
    |> filter_by_event_types(event_types)
    |> Repo.all()
  end

  defp filter_by_event_types(query, :all), do: query
  defp filter_by_event_types(query, types) when is_list(types) do
    from e in query, where: e.event_type in ^types
  end

  @doc """
  Creates a calendar event
  """
  def create_event(attrs, creator, account) do
    %Event{}
    |> Event.changeset(Map.merge(attrs, %{
      "creator_id" => creator.id,
      "account_id" => account.id
    }))
    |> Repo.insert()
    |> case do
      {:ok, event} ->
        # Auto-add creator as organizer
        add_attendee(event, %{
          user_id: creator.id,
          role: "organizer",
          status: "accepted"
        })
        {:ok, event}
      error -> error
    end
  end

  @doc """
  Updates a calendar event (with permission check)
  """
  def update_event(event, attrs, user) do
    if can_edit_event?(event, user) do
      event
      |> Event.changeset(attrs)
      |> Repo.update()
    else
      {:error, :unauthorized}
    end
  end

  @doc """
  Deletes a calendar event (with permission check)
  """
  def delete_event(event, user) do
    if can_delete_event?(event, user) do
      Repo.delete(event)
    else
      {:error, :unauthorized}
    end
  end

  # ============================================================================
  # ATTENDEE MANAGEMENT
  # ============================================================================

  def add_attendee(event, attrs) do
    %EventAttendee{}
    |> EventAttendee.changeset(Map.put(attrs, :event_id, event.id))
    |> Repo.insert()
  end

  def update_attendee_status(event_id, user_id, status) do
    from(a in EventAttendee,
      where: a.event_id == ^event_id and a.user_id == ^user_id
    )
    |> Repo.update_all(set: [status: status, updated_at: DateTime.utc_now()])
  end

  # ============================================================================
  # CALENDAR INTEGRATIONS
  # ============================================================================

  def create_integration(attrs, user, account) do
    %Integration{}
    |> Integration.changeset(Map.merge(attrs, %{
      user_id: user.id,
      account_id: account.id
    }))
    |> Repo.insert()
  end

  def get_user_integrations(user_id) do
    from(i in Integration,
      where: i.user_id == ^user_id and i.sync_enabled == true,
      order_by: [desc: i.is_primary, asc: i.inserted_at]
    )
    |> Repo.all()
  end

  def get_user_integration(user_id, integration_id) do
    from(i in Integration,
      where: i.user_id == ^user_id and i.id == ^integration_id
    )
    |> Repo.one()
  end

  def sync_external_calendar(integration) do
    case integration.provider do
      "google" -> sync_google_calendar(integration)
      "outlook" -> sync_outlook_calendar(integration)
      _ -> {:error, :unsupported_provider}
    end
  end

  def sync_user_calendars(user_id) do
    integrations = get_user_integrations(user_id)

    # Spawn sync tasks for all integrations
    Enum.each(integrations, fn integration ->
      Task.start(fn -> sync_external_calendar(integration) end)
    end)

    :ok
  end

  # ============================================================================
  # CALENDAR VIEWS
  # ============================================================================

  def create_or_update_view(attrs, user, account) do
    case Repo.get_by(View, user_id: user.id, name: attrs.name) do
      nil ->
        %View{}
        |> View.changeset(Map.merge(attrs, %{
          user_id: user.id,
          account_id: account.id
        }))
        |> Repo.insert()

      existing_view ->
        existing_view
        |> View.changeset(attrs)
        |> Repo.update()
    end
  end

  def get_user_views(user_id) do
    from(v in View,
      where: v.user_id == ^user_id,
      order_by: [desc: v.default_view, asc: v.name]
    )
    |> Repo.all()
  end

  # ============================================================================
  # PRIVATE HELPERS
  # ============================================================================

  defp get_user_channel_ids(user_id) do
    # This would integrate with your existing channel membership system
    # For now, returning empty list - replace with actual channel query
    # Example: Channels.list_user_channel_ids(user_id)
    []
  end

  defp can_edit_event?(event, user) do
    event.creator_id == user.id or
    is_event_organizer?(event, user) or
    has_account_admin_access?(event.account_id, user)
  end

  defp can_delete_event?(event, user) do
    event.creator_id == user.id or
    has_account_admin_access?(event.account_id, user)
  end

  defp is_event_organizer?(event, user) do
    from(a in EventAttendee,
      where: a.event_id == ^event.id and
             a.user_id == ^user.id and
             a.role == "organizer"
    )
    |> Repo.exists?()
  end

  defp has_account_admin_access?(_account_id, _user) do
    # Implement account admin check based on your existing system
    false
  end

  # External calendar sync functions (placeholder implementations)
  defp sync_google_calendar(integration) do
    # Implement Google Calendar API sync
    {:ok, integration}
  end

  defp sync_outlook_calendar(integration) do
    # Implement Outlook Calendar API sync
    {:ok, integration}
  end
end
