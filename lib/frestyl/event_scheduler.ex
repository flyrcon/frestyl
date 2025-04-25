# lib/frestyl/event_scheduler.ex
defmodule Frestyl.EventScheduler do
  @moduledoc """
  Scheduler for event-related tasks.
  """

  import Ecto.Query
  use GenServer
  require Logger
  alias Frestyl.{Events, Repo}
  alias Frestyl.Events.{Event, EventAttendee}
  alias Frestyl.EventNotifications

  @check_interval :timer.minutes(1)

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{})
  end

  @impl true
  def init(state) do
    schedule_check()
    {:ok, state}
  end

  @impl true
  def handle_info(:check_events, state) do
    Logger.info("Running scheduled event checks")

    process_due_events()
    send_reminders()

    schedule_check()
    {:noreply, state}
  end

  defp schedule_check do
    Process.send_after(self(), :check_events, @check_interval)
  end

  defp process_due_events do
    now = DateTime.utc_now()

    # Auto-start events that should be live
    Event
    |> Ecto.Query.where([e], e.status == :scheduled and e.starts_at <= ^now)
    |> Repo.all()
    |> Enum.each(fn event ->
      {:ok, updated_event} = Events.start_event(event)
      notify_event_started(updated_event)
    end)

    # Auto-end events that have passed their end time
    Event
    |> Ecto.Query.where([e], e.status == :live and not is_nil(e.ends_at) and e.ends_at <= ^now)
    |> Repo.all()
    |> Enum.each(fn event ->
      {:ok, _} = Events.end_event(event)
    end)
  end

  defp send_reminders do
    now = DateTime.utc_now()
    reminder_threshold = DateTime.add(now, 60 * 30, :second) # 30 minutes

    # Find events starting in the next 30 minutes
    Event
    |> Ecto.Query.where([e], e.status == :scheduled)
    |> Ecto.Query.where([e], e.starts_at > ^now and e.starts_at <= ^reminder_threshold)
    |> Repo.all()
    |> Enum.each(fn event ->
      send_event_reminders(event)
    end)
  end

  defp send_event_reminders(event) do
    attendees =
      EventAttendee
      |> Ecto.Query.where([a], a.event_id == ^event.id and a.status == :admitted)
      |> Ecto.Query.preload(:user)
      |> Repo.all()

    Enum.each(attendees, fn attendee ->
      EventNotifications.send_event_reminder(event, attendee)
    end)
  end

  defp notify_event_started(event) do
    attendees =
      EventAttendee
      |> Ecto.Query.where([a], a.event_id == ^event.id and a.status == :admitted)
      |> Ecto.Query.preload(:user)
      |> Repo.all()

    Enum.each(attendees, fn attendee ->
      EventNotifications.send_event_started_notification(event, attendee)
    end)

    # Also broadcast to connected clients
    Phoenix.PubSub.broadcast(Frestyl.PubSub, "event_updates", {:event_started, event})
  end
end
