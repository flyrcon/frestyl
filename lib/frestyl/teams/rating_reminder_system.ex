# Rating Reminder System
# File: lib/frestyl/teams/rating_reminder_system.ex

defmodule Frestyl.Teams.RatingReminderSystem do
  @moduledoc """
  Handles the progressive reminder system for team ratings.
  Escalates from gentle notifications to persistent modals to supervisor alerts.
  """

  use GenServer
  import Ecto.Query, warn: false
  alias Frestyl.Teams
  alias Frestyl.Teams.RatingReminder
  alias Phoenix.PubSub

  @check_interval :timer.hours(1) # Check every hour
  @escalation_thresholds %{
    level_1: :timer.hours(24),   # 24 hours - badge notification
    level_2: :timer.hours(48),   # 48 hours - modal popup
    level_3: :timer.hours(72),   # 72 hours - persistent modal
    level_4: :timer.hours(96)    # 96 hours - supervisor notification
  }

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    schedule_reminder_check()
    {:ok, state}
  end

  @impl true
  def handle_info(:check_reminders, state) do
    check_and_escalate_reminders()
    schedule_reminder_check()
    {:noreply, state}
  end

  @doc """
  Creates milestone-based reminders for a team.
  """
  def create_milestone_reminders(team_id, milestone) do
    team = Teams.get_team!(team_id)

    # Calculate due date based on milestone and project timeline
    due_date = calculate_milestone_due_date(team, milestone)

    Teams.create_rating_reminders(team_id, "milestone_rating", due_date)

    # Send initial gentle notification
    notify_team_members(team_id, "milestone_rating_available", %{
      milestone: milestone,
      due_date: due_date
    })
  end

  @doc """
  Creates pulse check reminders (weekly check-ins).
  """
  def create_pulse_check_reminders(team_id) do
    due_date = DateTime.add(DateTime.utc_now(), 7 * 24 * 60 * 60) # 1 week from now

    Teams.create_rating_reminders(team_id, "pulse_check", due_date)

    notify_team_members(team_id, "pulse_check_available", %{
      due_date: due_date
    })
  end

  @doc """
  Gets reminder UI state for a user.
  """
  def get_user_reminder_state(user_id) do
    reminders = Teams.get_pending_reminders(user_id)

    %{
      has_pending: length(reminders) > 0,
      escalation_level: get_highest_escalation_level(reminders),
      reminder_count: length(reminders),
      reminders: format_reminders_for_ui(reminders)
    }
  end

  # Private Functions

  defp schedule_reminder_check do
    Process.send_after(self(), :check_reminders, @check_interval)
  end

  defp check_and_escalate_reminders do
    now = DateTime.utc_now()

    # Get all pending reminders
    overdue_reminders = from(r in RatingReminder,
      where: r.status == "pending" and r.due_at < ^now,
      preload: [:team, :user]
    ) |> Frestyl.Repo.all()

    Enum.each(overdue_reminders, &process_overdue_reminder/1)
  end

  defp process_overdue_reminder(reminder) do
    overdue_duration = DateTime.diff(DateTime.utc_now(), reminder.due_at, :millisecond)
    new_escalation_level = calculate_escalation_level(overdue_duration)

    if new_escalation_level > reminder.escalation_level do
      update_reminder_escalation(reminder, new_escalation_level)
      send_escalated_notification(reminder, new_escalation_level)
    end
  end

  defp calculate_escalation_level(overdue_ms) do
    cond do
      overdue_ms >= @escalation_thresholds.level_4 -> 4
      overdue_ms >= @escalation_thresholds.level_3 -> 3
      overdue_ms >= @escalation_thresholds.level_2 -> 2
      overdue_ms >= @escalation_thresholds.level_1 -> 1
      true -> 0
    end
  end

  defp update_reminder_escalation(reminder, new_level) do
    reminder
    |> RatingReminder.changeset(%{
      escalation_level: new_level,
      last_reminded_at: DateTime.utc_now()
    })
    |> Frestyl.Repo.update()
  end

  defp send_escalated_notification(reminder, escalation_level) do
    case escalation_level do
      1 -> send_badge_notification(reminder)
      2 -> send_modal_notification(reminder)
      3 -> send_persistent_modal(reminder)
      4 -> send_supervisor_alert(reminder)
    end
  end

  defp send_badge_notification(reminder) do
    PubSub.broadcast(
      Frestyl.PubSub,
      "user:#{reminder.user_id}",
      {:rating_reminder, :badge, format_reminder_data(reminder)}
    )
  end

  defp send_modal_notification(reminder) do
    PubSub.broadcast(
      Frestyl.PubSub,
      "user:#{reminder.user_id}",
      {:rating_reminder, :modal, format_reminder_data(reminder)}
    )
  end

  defp send_persistent_modal(reminder) do
    PubSub.broadcast(
      Frestyl.PubSub,
      "user:#{reminder.user_id}",
      {:rating_reminder, :persistent_modal, format_reminder_data(reminder)}
    )
  end

  defp send_supervisor_alert(reminder) do
    # Notify supervisor about overdue team member
    if reminder.team.supervisor_id do
      PubSub.broadcast(
        Frestyl.PubSub,
        "supervisor:#{reminder.team.supervisor_id}",
        {:team_member_overdue, %{
          team_id: reminder.team_id,
          user_id: reminder.user_id,
          reminder_type: reminder.reminder_type,
          overdue_duration: DateTime.diff(DateTime.utc_now(), reminder.due_at, :hour)
        }}
      )
    end

    # Mark as escalated to supervisor
    reminder
    |> RatingReminder.changeset(%{status: "escalated"})
    |> Frestyl.Repo.update()
  end

  defp calculate_milestone_due_date(team, milestone) do
    # Calculate based on project timeline and milestone percentage
    case {team.due_date, milestone} do
      {nil, _} -> DateTime.add(DateTime.utc_now(), 7 * 24 * 60 * 60) # Default 1 week
      {due_date, "25%"} -> DateTime.add(due_date, -21 * 24 * 60 * 60) # 3 weeks before
      {due_date, "50%"} -> DateTime.add(due_date, -14 * 24 * 60 * 60) # 2 weeks before
      {due_date, "75%"} -> DateTime.add(due_date, -7 * 24 * 60 * 60)  # 1 week before
      {due_date, "final"} -> due_date
      _ -> DateTime.add(DateTime.utc_now(), 7 * 24 * 60 * 60)
    end
  end

  defp notify_team_members(team_id, notification_type, data) do
    team = Teams.get_team!(team_id)

    Enum.each(team.members, fn member ->
      PubSub.broadcast(
        Frestyl.PubSub,
        "user:#{member.id}",
        {notification_type, Map.put(data, :team_name, team.name)}
      )
    end)
  end

  defp get_highest_escalation_level(reminders) do
    reminders
    |> Enum.map(& &1.escalation_level)
    |> Enum.max(fn -> 0 end)
  end

  defp format_reminders_for_ui(reminders) do
    Enum.map(reminders, fn reminder ->
      %{
        id: reminder.id,
        team_name: reminder.team.name,
        reminder_type: reminder.reminder_type,
        due_date: reminder.due_at,
        escalation_level: reminder.escalation_level,
        overdue_hours: DateTime.diff(DateTime.utc_now(), reminder.due_at, :hour)
      }
    end)
  end

  defp format_reminder_data(reminder) do
    %{
      reminder_id: reminder.id,
      team_id: reminder.team_id,
      team_name: reminder.team.name,
      reminder_type: reminder.reminder_type,
      due_date: reminder.due_at,
      escalation_level: reminder.escalation_level
    }
  end
end

# Rating Reminder LiveView Component
# File: lib/frestyl_web/live/components/rating_reminder_component.ex

defmodule FrestylWeb.RatingReminderComponent do
  use FrestylWeb, :live_component
  alias Frestyl.Teams.RatingReminderSystem

  @impl true
  def update(assigns, socket) do
    reminder_state = RatingReminderSystem.get_user_reminder_state(assigns.current_user.id)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:reminder_state, reminder_state)
     |> assign(:show_modal, should_show_modal(reminder_state))
     |> assign(:modal_dismissible, modal_dismissible?(reminder_state))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="rating-reminders">
      <!-- Badge Notification -->
      <%= if @reminder_state.has_pending and @reminder_state.escalation_level >= 1 do %>
        <div class="fixed top-4 right-4 z-50">
          <div class="bg-yellow-100 border border-yellow-400 text-yellow-800 px-4 py-3 rounded-lg shadow-lg flex items-center space-x-3">
            <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd"/>
            </svg>
            <div>
              <p class="font-medium">Team Rating Due</p>
              <p class="text-sm"><%= @reminder_state.reminder_count %> pending ratings</p>
            </div>
            <button phx-click="show_rating_modal" phx-target={@myself}
                    class="text-yellow-600 hover:text-yellow-800">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
              </svg>
            </button>
          </div>
        </div>
      <% end %>

      <!-- Modal Notification -->
      <%= if @show_modal do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div class="bg-white rounded-xl p-6 w-full max-w-md mx-4 relative">
            <!-- Dismiss button (only if dismissible) -->
            <%= if @modal_dismissible do %>
              <button phx-click="dismiss_modal" phx-target={@myself}
                      class="absolute top-4 right-4 text-gray-400 hover:text-gray-600">
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                </svg>
              </button>
            <% end %>

            <div class="text-center">
              <!-- Icon -->
              <div class="w-16 h-16 bg-gradient-to-br from-yellow-400 to-orange-500 rounded-full flex items-center justify-center mx-auto mb-4">
                <svg class="w-8 h-8 text-white" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"/>
                </svg>
              </div>

              <!-- Content -->
              <h3 class="text-xl font-bold text-gray-900 mb-2">Team Rating Required</h3>

              <%= if @reminder_state.escalation_level >= 3 do %>
                <p class="text-red-600 font-medium mb-4">
                  ⚠️ This rating is significantly overdue and may affect your team's progress.
                </p>
              <% else %>
                <p class="text-gray-600 mb-4">
                  Your team is waiting for your feedback to continue collaborating effectively.
                </p>
              <% end %>

              <!-- Reminder List -->
              <div class="space-y-3 mb-6">
                <%= for reminder <- @reminder_state.reminders do %>
                  <div class="bg-gray-50 rounded-lg p-3 text-left">
                    <div class="flex justify-between items-start mb-2">
                      <h4 class="font-medium text-gray-900"><%= reminder.team_name %></h4>
                      <%= if reminder.overdue_hours > 0 do %>
                        <span class="text-xs text-red-600 bg-red-100 px-2 py-1 rounded">
                          <%= reminder.overdue_hours %>h overdue
                        </span>
                      <% end %>
                    </div>

                    <p class="text-sm text-gray-600 capitalize">
                      <%= String.replace(reminder.reminder_type, "_", " ") %>
                    </p>

                    <div class="mt-2">
                      <button phx-click="start_rating"
                              phx-value-reminder-id={reminder.id}
                              phx-target={@myself}
                              class="w-full px-3 py-2 bg-blue-600 text-white text-sm rounded-lg hover:bg-blue-700">
                        Start Rating Now
                      </button>
                    </div>
                  </div>
                <% end %>
              </div>

              <!-- Persistent modal warning -->
              <%= if @reminder_state.escalation_level >= 3 do %>
                <div class="bg-red-50 border border-red-200 rounded-lg p-3 mb-4">
                  <p class="text-sm text-red-800">
                    <strong>Notice:</strong> This modal will remain visible until you complete your ratings.
                    Your supervisor has been notified of the delay.
                  </p>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("show_rating_modal", _params, socket) do
    {:noreply, assign(socket, :show_modal, true)}
  end

  def handle_event("dismiss_modal", _params, socket) do
    if socket.assigns.modal_dismissible do
      {:noreply, assign(socket, :show_modal, false)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("start_rating", %{"reminder-id" => reminder_id}, socket) do
    # Navigate to rating interface
    send(self(), {:start_rating_session, reminder_id})
    {:noreply, assign(socket, :show_modal, false)}
  end

  defp should_show_modal(reminder_state) do
    reminder_state.has_pending and reminder_state.escalation_level >= 2
  end

  defp modal_dismissible?(reminder_state) do
    reminder_state.escalation_level < 3
  end
end
