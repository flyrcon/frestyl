# lib/frestyl_web/live/portfolio_hub_live/enhanced_calendar_section_component.ex
defmodule FrestylWeb.PortfolioHubLive.EnhancedCalendarSectionComponent do
  use FrestylWeb, :live_component

  alias Frestyl.Calendar
  alias Frestyl.Features.TierManager

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_calendar_state()
     |> load_intelligent_calendar_data()}
  end

  @impl true
  def handle_event("change_view", %{"view" => view}, socket) do
    {:noreply, assign(socket, :calendar_view, view)}
  end

  @impl true
  def handle_event("change_filter", %{"filter" => filter}, socket) do
    socket = socket
    |> assign(:ownership_filter, filter)
    |> load_intelligent_calendar_data()

    {:noreply, socket}
  end

  @impl true
  def handle_event("accept_suggestion", %{"suggestion_id" => suggestion_id}, socket) do
    case Calendar.accept_suggestion(suggestion_id, socket.assigns.user.id) do
      {:ok, %{event: event}} ->
        socket = socket
        |> put_flash(:info, "Suggestion converted to calendar event!")
        |> load_intelligent_calendar_data()

        {:noreply, socket}

      {:error, _} ->
        socket = put_flash(socket, :error, "Failed to accept suggestion")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("dismiss_suggestion", %{"suggestion_id" => suggestion_id}, socket) do
    case Calendar.dismiss_suggestion(suggestion_id, socket.assigns.user.id) do
      {:ok, _} ->
        socket = socket
        |> put_flash(:info, "Suggestion dismissed")
        |> load_intelligent_calendar_data()

        {:noreply, socket}

      {:error, _} ->
        socket = put_flash(socket, :error, "Failed to dismiss suggestion")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("complete_event", %{"event_id" => event_id}, socket) do
    case Calendar.complete_event(event_id, socket.assigns.user.id) do
      {:ok, _event} ->
        socket = socket
        |> put_flash(:info, "Event completed! 🎉")
        |> load_intelligent_calendar_data()

        {:noreply, socket}

      {:error, _} ->
        socket = put_flash(socket, :error, "Failed to complete event")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("defer_event", %{"event_id" => event_id, "days" => days}, socket) do
    new_date = DateTime.add(DateTime.utc_now(), String.to_integer(days) * 24 * 60 * 60, :second)

    case Calendar.defer_event(event_id, socket.assigns.user.id, new_date, "User deferred") do
      {:ok, _event} ->
        socket = socket
        |> put_flash(:info, "Event rescheduled")
        |> load_intelligent_calendar_data()

        {:noreply, socket}

      {:error, _} ->
        socket = put_flash(socket, :error, "Failed to defer event")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("start_workflow", %{"event_id" => event_id}, socket) do
    case Calendar.start_workflow(event_id, socket.assigns.user.id) do
      {:ok, _workflow} ->
        socket = socket
        |> put_flash(:info, "Workflow started!")
        |> assign(:show_workflow_modal, true)
        |> assign(:active_workflow_event_id, event_id)

        {:noreply, socket}

      {:error, _} ->
        socket = put_flash(socket, :error, "Failed to start workflow")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("schedule_health_check", _params, socket) do
    Calendar.schedule_portfolio_health_check(socket.assigns.user.id)

    socket = socket
    |> put_flash(:info, "Portfolio health checks scheduled!")
    |> load_intelligent_calendar_data()

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_insights", _params, socket) do
    {:noreply, assign(socket, :show_insights, !socket.assigns.show_insights)}
  end

  defp assign_calendar_state(socket) do
    socket
    |> assign_new(:calendar_view, fn -> "week" end)
    |> assign_new(:ownership_filter, fn -> "all" end)
    |> assign_new(:show_insights, fn -> false end)
    |> assign_new(:show_workflow_modal, fn -> false end)
    |> assign_new(:active_workflow_event_id, fn -> nil end)
  end

  defp load_intelligent_calendar_data(socket) do
    user = socket.assigns.user
    account = socket.assigns.account

    # Get intelligent calendar data
    calendar_data = Calendar.get_intelligent_calendar_view(user, account)

    # Get calendar statistics and insights
    calendar_stats = Calendar.get_calendar_statistics(user.id, account)
    calendar_insights = Calendar.get_calendar_insights(user.id, account)

    # Get upcoming deadlines and overdue tasks
    upcoming_deadlines = Calendar.get_upcoming_deadlines(user.id, account, 7)
    overdue_tasks = Calendar.get_overdue_tasks(user.id, account)

    # Filter events based on ownership filter
    filtered_events = case socket.assigns.ownership_filter do
      "all" -> calendar_data.events
      filter -> Enum.filter(calendar_data.events, &(&1.ownership_type == filter))
    end

    socket
    |> assign(:calendar_data, calendar_data)
    |> assign(:calendar_events, filtered_events)
    |> assign(:calendar_stats, calendar_stats)
    |> assign(:calendar_insights, calendar_insights)
    |> assign(:upcoming_deadlines, upcoming_deadlines)
    |> assign(:overdue_tasks, overdue_tasks)
    |> assign(:suggestions, calendar_data.suggestions)
    |> assign(:health_summary, calendar_data.health_summary)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Enhanced Calendar Header -->
      <div class="bg-white rounded-xl p-6 shadow-sm border">
        <div class="flex items-center justify-between mb-4">
          <div>
            <h2 class="text-2xl font-bold text-gray-900">Content Calendar</h2>
            <p class="text-gray-600 mt-1">
              Your intelligent content strategy command center
            </p>
          </div>

          <div class="flex items-center space-x-3">
            <!-- Calendar Insights Toggle -->
            <button
              phx-click="toggle_insights"
              phx-target={@myself}
              class={[
                "inline-flex items-center px-3 py-2 rounded-lg text-sm font-medium transition-colors",
                if(@show_insights, do: "bg-blue-100 text-blue-700", else: "bg-gray-100 text-gray-600 hover:bg-gray-200")
              ]}>
              <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/>
              </svg>
              Insights
            </button>

            <!-- Schedule Health Check -->
            <button
              phx-click="schedule_health_check"
              phx-target={@myself}
              class="inline-flex items-center px-3 py-2 bg-green-100 text-green-700 rounded-lg text-sm font-medium hover:bg-green-200 transition-colors">
              <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z"/>
              </svg>
              Health Check
            </button>

            <!-- Full Calendar Link -->
            <.link navigate="/calendar"
                  class="inline-flex items-center px-4 py-2 bg-blue-600 text-white text-sm font-medium rounded-lg hover:bg-blue-700 transition-colors">
              <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"/>
              </svg>
              Full Calendar
            </.link>
          </div>
        </div>

        <!-- Calendar Controls -->
        <div class="flex items-center justify-between">
          <!-- View Toggle -->
          <div class="flex bg-gray-100 rounded-lg p-1">
            <%= for view <- ["day", "week", "month"] do %>
              <button
                phx-click="change_view"
                phx-value-view={view}
                phx-target={@myself}
                class={[
                  "px-3 py-1 text-sm font-medium rounded-md transition-colors",
                  if(@calendar_view == view, do: "bg-white text-gray-900 shadow-sm", else: "text-gray-500 hover:text-gray-700")
                ]}>
                <%= String.capitalize(view) %>
              </button>
            <% end %>
          </div>

          <!-- Ownership Filter -->
          <div class="flex items-center space-x-4">
            <span class="text-sm font-medium text-gray-700">Show:</span>
            <div class="flex bg-gray-100 rounded-lg p-1">
              <%= for {filter, label} <- [{"all", "All"}, {"mine", "My Content"}, {"participating", "Participating"}, {"fyi", "FYI"}, {"suggested", "Suggested"}] do %>
                <button
                  phx-click="change_filter"
                  phx-value-filter={filter}
                  phx-target={@myself}
                  class={[
                    "px-3 py-1 text-sm font-medium rounded-md transition-colors",
                    if(@ownership_filter == filter, do: "bg-white text-gray-900 shadow-sm", else: "text-gray-500 hover:text-gray-700")
                  ]}>
                  <%= label %>
                </button>
              <% end %>
            </div>
          </div>
        </div>
      </div>

      <!-- Calendar Insights Panel -->
      <%= if @show_insights do %>
        <div class="bg-white rounded-xl p-6 shadow-sm border">
          <h3 class="text-lg font-semibold text-gray-900 mb-4">📊 Calendar Insights</h3>

          <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
            <!-- Productivity Score -->
            <div class="bg-gradient-to-r from-blue-50 to-cyan-50 rounded-lg p-4">
              <div class="flex items-center justify-between">
                <div>
                  <p class="text-sm font-medium text-blue-600">Productivity Score</p>
                  <p class="text-2xl font-bold text-blue-900"><%= @calendar_insights.productivity_score %>%</p>
                </div>
                <div class="w-8 h-8 bg-blue-100 rounded-lg flex items-center justify-center">
                  <svg class="w-5 h-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6"/>
                  </svg>
                </div>
              </div>
            </div>

            <!-- Completion Rate -->
            <div class="bg-gradient-to-r from-green-50 to-emerald-50 rounded-lg p-4">
              <div class="flex items-center justify-between">
                <div>
                  <p class="text-sm font-medium text-green-600">Completion Rate</p>
                  <p class="text-2xl font-bold text-green-900"><%= @calendar_insights.completion_rate %>%</p>
                </div>
                <div class="w-8 h-8 bg-green-100 rounded-lg flex items-center justify-center">
                  <svg class="w-5 h-5 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
                  </svg>
                </div>
              </div>
            </div>

            <!-- Revenue Focus -->
            <div class="bg-gradient-to-r from-purple-50 to-pink-50 rounded-lg p-4">
              <div class="flex items-center justify-between">
                <div>
                  <p class="text-sm font-medium text-purple-600">Revenue Events</p>
                  <p class="text-2xl font-bold text-purple-900"><%= @calendar_insights.revenue_impact_analysis.total_revenue_events %></p>
                </div>
                <div class="w-8 h-8 bg-purple-100 rounded-lg flex items-center justify-center">
                  <svg class="w-5 h-5 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1"/>
                  </svg>
                </div>
              </div>
            </div>
          </div>

          <!-- Recommendations -->
          <%= if length(@calendar_insights.recommendations) > 0 do %>
            <div class="border-t pt-4">
              <h4 class="text-sm font-semibold text-gray-900 mb-3">💡 Recommendations</h4>
              <div class="space-y-2">
                <%= for rec <- @calendar_insights.recommendations do %>
                  <div class={[
                    "flex items-start space-x-3 p-3 rounded-lg border-l-4",
                    case rec.priority do
                      "high" -> "bg-red-50 border-red-400"
                      "medium" -> "bg-yellow-50 border-yellow-400"
                      _ -> "bg-blue-50 border-blue-400"
                    end
                  ]}>
                    <div class="flex-1">
                      <p class="text-sm font-medium text-gray-900"><%= rec.title %></p>
                      <p class="text-sm text-gray-600"><%= rec.description %></p>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>

      <!-- Quick Stats -->
      <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div class="bg-white rounded-xl p-4 shadow-sm border">
          <div class="flex items-center">
            <div class="p-2 bg-blue-100 rounded-lg">
              <svg class="w-5 h-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/>
              </svg>
            </div>
            <div class="ml-4">
              <p class="text-sm font-medium text-gray-600">Total Events</p>
              <p class="text-xl font-bold text-gray-900"><%= @calendar_stats.total_events %></p>
            </div>
          </div>
        </div>

        <div class="bg-white rounded-xl p-4 shadow-sm border">
          <div class="flex items-center">
            <div class="p-2 bg-green-100 rounded-lg">
              <svg class="w-5 h-5 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
              </svg>
            </div>
            <div class="ml-4">
              <p class="text-sm font-medium text-gray-600">Completed</p>
              <p class="text-xl font-bold text-gray-900"><%= @calendar_stats.completed_events %></p>
            </div>
          </div>
        </div>

        <div class="bg-white rounded-xl p-4 shadow-sm border">
          <div class="flex items-center">
            <div class={[
              "p-2 rounded-lg",
              if(@calendar_stats.overdue_events > 0, do: "bg-red-100", else: "bg-yellow-100")
            ]}>
              <svg class={[
                "w-5 h-5",
                if(@calendar_stats.overdue_events > 0, do: "text-red-600", else: "text-yellow-600")
              ]} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
              </svg>
            </div>
            <div class="ml-4">
              <p class="text-sm font-medium text-gray-600">Overdue</p>
              <p class={[
                "text-xl font-bold",
                if(@calendar_stats.overdue_events > 0, do: "text-red-900", else: "text-gray-900")
              ]}><%= @calendar_stats.overdue_events %></p>
            </div>
          </div>
        </div>

        <div class="bg-white rounded-xl p-4 shadow-sm border">
          <div class="flex items-center">
            <div class="p-2 bg-purple-100 rounded-lg">
              <svg class="w-5 h-5 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
              </svg>
            </div>
            <div class="ml-4">
              <p class="text-sm font-medium text-gray-600">High Priority</p>
              <p class="text-xl font-bold text-gray-900"><%= @calendar_stats.high_priority_events %></p>
            </div>
          </div>
        </div>
      </div>

      <!-- Smart Suggestions -->
      <%= if length(@suggestions) > 0 do %>
        <div class="bg-white rounded-xl shadow-sm border">
          <div class="p-6 border-b border-gray-200">
            <h3 class="text-lg font-semibold text-gray-900">💡 Smart Suggestions</h3>
            <p class="text-sm text-gray-600 mt-1">AI-powered recommendations to grow your portfolio</p>
          </div>
          <div class="divide-y divide-gray-200">
            <%= for suggestion <- Enum.take(@suggestions, 5) do %>
              <div class="p-6 hover:bg-gray-50 transition-colors">
                <div class="flex items-start justify-between">
                  <div class="flex items-start space-x-3">
                    <div class={[
                      "w-8 h-8 rounded-lg flex items-center justify-center text-lg",
                      "bg-#{Frestyl.Calendar.ContentSuggestion.get_color(suggestion.estimated_impact)}-100"
                    ]}>
                      <%= Frestyl.Calendar.ContentSuggestion.get_icon(suggestion.suggestion_type) %>
                    </div>
                    <div class="flex-1">
                      <h4 class="font-medium text-gray-900"><%= suggestion.title %></h4>
                      <p class="text-sm text-gray-600 mt-1"><%= suggestion.description %></p>
                      <div class="flex items-center space-x-4 mt-2">
                        <span class={[
                          "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium",
                          "bg-#{Frestyl.Calendar.ContentSuggestion.get_color(suggestion.estimated_impact)}-100",
                          "text-#{Frestyl.Calendar.ContentSuggestion.get_color(suggestion.estimated_impact)}-800"
                        ]}>
                          <%= String.capitalize(suggestion.estimated_impact) %> Impact
                        </span>
                        <%= if suggestion.estimated_time_minutes do %>
                          <span class="text-xs text-gray-500">
                            ⏱️ <%= suggestion.estimated_time_minutes %> min
                          </span>
                        <% end %>
                        <%= if suggestion.suggested_due_date do %>
                          <span class="text-xs text-gray-500">
                            📅 Due <%= Calendar.format_relative_time(suggestion.suggested_due_date) %>
                          </span>
                        <% end %>
                      </div>
                    </div>
                  </div>
                  <div class="flex items-center space-x-2">
                    <button
                      phx-click="accept_suggestion"
                      phx-value-suggestion_id={suggestion.id}
                      phx-target={@myself}
                      class="inline-flex items-center px-3 py-1.5 bg-blue-600 text-white text-sm font-medium rounded-lg hover:bg-blue-700 transition-colors">
                      Accept
                    </button>
                    <button
                      phx-click="dismiss_suggestion"
                      phx-value-suggestion_id={suggestion.id}
                      phx-target={@myself}
                      class="inline-flex items-center px-3 py-1.5 border border-gray-300 text-gray-700 text-sm font-medium rounded-lg hover:bg-gray-50 transition-colors">
                      Dismiss
                    </button>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>

      <!-- Priority Events -->
      <%= if length(@upcoming_deadlines) > 0 do %>
        <div class="bg-white rounded-xl shadow-sm border">
          <div class="p-6 border-b border-gray-200">
            <h3 class="text-lg font-semibold text-gray-900">⚡ Upcoming Deadlines</h3>
            <p class="text-sm text-gray-600 mt-1">High-priority events in the next 7 days</p>
          </div>
          <div class="divide-y divide-gray-200">
            <%= for event <- @upcoming_deadlines do %>
              <div class="p-6 hover:bg-gray-50 transition-colors">
                <.event_card event={event} target={@myself} />
              </div>
            <% end %>
          </div>
        </div>
      <% end %>

      <!-- Overdue Tasks -->
      <%= if length(@overdue_tasks) > 0 do %>
        <div class="bg-red-50 rounded-xl border border-red-200">
          <div class="p-6 border-b border-red-200">
            <h3 class="text-lg font-semibold text-red-900">🚨 Overdue Tasks</h3>
            <p class="text-sm text-red-600 mt-1">Tasks that need immediate attention</p>
          </div>
          <div class="divide-y divide-red-200">
            <%= for event <- @overdue_tasks do %>
              <div class="p-6 hover:bg-red-100 transition-colors">
                <.event_card event={event} target={@myself} urgent={true} />
              </div>
            <% end %>
          </div>
        </div>
      <% end %>

      <!-- Calendar View -->
      <div class="bg-white rounded-xl shadow-sm border">
        <div class="p-6">
          <%= case @calendar_view do %>
            <% "day" -> %>
              <.day_view events={@calendar_events} target={@myself} />
            <% "week" -> %>
              <.week_view events={@calendar_events} target={@myself} />
            <% "month" -> %>
              <.month_view events={@calendar_events} target={@myself} />
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Component helper functions
  defp event_card(assigns) do
    ~H"""
    <div class="flex items-start justify-between">
      <div class="flex items-start space-x-3">
        <!-- Event Type Icon & Priority -->
        <div class="relative">
          <div class={[
            "w-10 h-10 rounded-lg flex items-center justify-center",
            "bg-#{Frestyl.Calendar.Event.get_ownership_color(@event.ownership_type)}-100"
          ]}>
            <%= format_content_type_icon(@event.content_type) %>
          </div>
          <div class={[
            "absolute -top-1 -right-1 w-4 h-4 rounded-full flex items-center justify-center text-xs",
            "bg-#{Frestyl.Calendar.Event.get_priority_color(@event.priority_level)}-500 text-white"
          ]}>
            <%= Frestyl.Calendar.Event.get_priority_weight(@event.priority_level) %>
          </div>
        </div>

        <div class="flex-1">
          <div class="flex items-center space-x-2">
            <h4 class="font-medium text-gray-900"><%= @event.title %></h4>
            <%= if @event.auto_generated do %>
              <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-green-100 text-green-800">
                AI Suggested
              </span>
            <% end %>
          </div>

          <%= if @event.description do %>
            <p class="text-sm text-gray-600 mt-1"><%= @event.description %></p>
          <% end %>

          <div class="flex items-center space-x-4 mt-2">
            <span class="text-sm text-gray-500">
              <%= Frestyl.Calendar.Event.format_ownership_type(@event.ownership_type) %>
            </span>
            <%= if @event.estimated_time_minutes do %>
              <span class="text-sm text-gray-500">
                ⏱️ <%= @event.estimated_time_minutes %> min
              </span>
            <% end %>
            <%= if @event.revenue_impact && @event.revenue_impact != "none" do %>
              <span class={[
                "inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium",
                case @event.revenue_impact do
                  "critical" -> "bg-red-100 text-red-800"
                  "high" -> "bg-orange-100 text-orange-800"
                  "medium" -> "bg-yellow-100 text-yellow-800"
                  _ -> "bg-gray-100 text-gray-800"
                end
              ]}>
                💰 <%= String.capitalize(@event.revenue_impact) %>
              </span>
            <% end %>
            <span class={[
              "text-sm",
              if(assigns[:urgent], do: "text-red-600 font-medium", else: "text-gray-500")
            ]}>
              <%= format_event_time(@event) %>
            </span>
          </div>
        </div>
      </div>

      <!-- Event Actions -->
      <div class="flex items-center space-x-2">
        <%= if @event.workflow_template do %>
          <button
            phx-click="start_workflow"
            phx-value-event_id={@event.id}
            phx-target={@target}
            class="inline-flex items-center px-2 py-1 bg-purple-100 text-purple-700 text-xs font-medium rounded hover:bg-purple-200 transition-colors">
            <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
            </svg>
            Workflow
          </button>
        <% end %>

        <%= if @event.completion_status in ["pending", "in_progress"] do %>
          <button
            phx-click="complete_event"
            phx-value-event_id={@event.id}
            phx-target={@target}
            class="inline-flex items-center px-3 py-1 bg-green-600 text-white text-xs font-medium rounded hover:bg-green-700 transition-colors">
            ✓ Complete
          </button>

          <div class="relative" x-data="{ open: false }">
            <button
              @click="open = !open"
              class="inline-flex items-center px-2 py-1 border border-gray-300 text-gray-700 text-xs font-medium rounded hover:bg-gray-50 transition-colors">
              <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 5v.01M12 12v.01M12 19v.01M12 6a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2z"/>
              </svg>
            </button>

            <div
              x-show="open"
              @click.away="open = false"
              x-transition
              class="absolute right-0 mt-1 w-32 bg-white rounded-md shadow-lg border border-gray-200 z-10">
              <button
                phx-click="defer_event"
                phx-value-event_id={@event.id}
                phx-value-days="1"
                phx-target={@target}
                class="block w-full text-left px-3 py-2 text-xs text-gray-700 hover:bg-gray-100">
                Defer 1 day
              </button>
              <button
                phx-click="defer_event"
                phx-value-event_id={@event.id}
                phx-value-days="3"
                phx-target={@target}
                class="block w-full text-left px-3 py-2 text-xs text-gray-700 hover:bg-gray-100">
                Defer 3 days
              </button>
              <button
                phx-click="defer_event"
                phx-value-event_id={@event.id}
                phx-value-days="7"
                phx-target={@target}
                class="block w-full text-left px-3 py-2 text-xs text-gray-700 hover:bg-gray-100">
                Defer 1 week
              </button>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp day_view(assigns) do
    ~H"""
    <div class="space-y-4">
      <h3 class="text-lg font-semibold text-gray-900">
        Today's Focus • <%= Date.to_string(Date.utc_today()) %>
      </h3>

      <%= if Enum.empty?(@events) do %>
        <div class="text-center py-12">
          <div class="w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"/>
            </svg>
          </div>
          <h3 class="text-lg font-medium text-gray-900 mb-2">No events scheduled</h3>
          <p class="text-gray-600">Your calendar is clear for today!</p>
        </div>
      <% else %>
        <div class="space-y-3">
          <%= for event <- @events do %>
            <div class="border border-gray-200 rounded-lg p-4 hover:border-gray-300 transition-colors">
              <.event_card event={event} target={@target} />
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp week_view(assigns) do
    ~H"""
    <div class="space-y-4">
      <h3 class="text-lg font-semibold text-gray-900">This Week's Schedule</h3>

      <%= if Enum.empty?(@events) do %>
        <div class="text-center py-12">
          <div class="w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"/>
            </svg>
          </div>
          <h3 class="text-lg font-medium text-gray-900 mb-2">No events this week</h3>
          <p class="text-gray-600">Time to plan some portfolio improvements!</p>
        </div>
      <% else %>
        <!-- Group events by day -->
        <div class="space-y-6">
          <%= for {date, day_events} <- group_events_by_day(@events) do %>
            <div>
              <h4 class="text-sm font-semibold text-gray-900 mb-3">
                <%= format_date_header(date) %>
                <span class="text-gray-500 font-normal">• <%= length(day_events) %> events</span>
              </h4>
              <div class="space-y-3">
                <%= for event <- day_events do %>
                  <div class="border border-gray-200 rounded-lg p-4 hover:border-gray-300 transition-colors">
                    <.event_card event={event} target={@target} />
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp month_view(assigns) do
    ~H"""
    <div class="space-y-4">
      <h3 class="text-lg font-semibold text-gray-900">Monthly Overview</h3>

      <!-- Calendar Grid -->
      <div class="bg-white border border-gray-200 rounded-lg overflow-hidden">
        <!-- Calendar Header -->
        <div class="grid grid-cols-7 bg-gray-50 border-b border-gray-200">
          <%= for day <- ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"] do %>
            <div class="px-4 py-3 text-center text-sm font-medium text-gray-900">
              <%= day %>
            </div>
          <% end %>
        </div>

        <!-- Calendar Body -->
        <div class="grid grid-cols-7">
          <%= for {date, day_events} <- generate_calendar_grid(@events) do %>
            <div class="min-h-24 border-r border-b border-gray-200 p-2">
              <div class="text-sm font-medium text-gray-900 mb-1">
                <%= Calendar.strftime(date, "%d") %>
              </div>

              <%= if length(day_events) > 0 do %>
                <div class="space-y-1">
                  <%= for event <- Enum.take(day_events, 3) do %>
                    <div class={[
                      "text-xs px-2 py-1 rounded truncate",
                      "bg-#{Frestyl.Calendar.Event.get_ownership_color(event.ownership_type)}-100",
                      "text-#{Frestyl.Calendar.Event.get_ownership_color(event.ownership_type)}-800"
                    ]}>
                      <%= event.title %>
                    </div>
                  <% end %>

                  <%= if length(day_events) > 3 do %>
                    <div class="text-xs text-gray-500">
                      +<%= length(day_events) - 3 %> more
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Event Legend -->
      <div class="flex items-center justify-center space-x-6 text-sm">
        <%= for {type, color, label} <- [
          {"mine", "blue", "My Content"},
          {"participating", "purple", "Participating"},
          {"fyi", "gray", "FYI"},
          {"suggested", "green", "AI Suggested"}
        ] do %>
          <div class="flex items-center space-x-2">
            <div class={["w-3 h-3 rounded", "bg-#{color}-400"]}></div>
            <span class="text-gray-600"><%= label %></span>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Helper functions
  defp format_content_type_icon(content_type) do
    case content_type do
      "portfolio_update" -> "📝"
      "skill_showcase" -> "🎯"
      "project_addition" -> "🚀"
      "content_review" -> "👀"
      "client_work" -> "💼"
      "service_booking" -> "📅"
      "channel_broadcast" -> "📺"
      "collaboration" -> "🤝"
      "learning" -> "📚"
      "industry_event" -> "🌐"
      "revenue_review" -> "💰"
      _ -> "📋"
    end
  end

  defp format_event_time(event) do
    case event.starts_at do
      nil -> "No time set"
      start_time ->
        now = DateTime.utc_now()
        diff_days = DateTime.diff(start_time, now, :day)

        cond do
          diff_days < 0 -> "#{abs(diff_days)} days overdue"
          diff_days == 0 -> "Today at #{Calendar.strftime(start_time, "%I:%M %p")}"
          diff_days == 1 -> "Tomorrow at #{Calendar.strftime(start_time, "%I:%M %p")}"
          diff_days <= 7 -> "#{Calendar.strftime(start_time, "%A")} at #{Calendar.strftime(start_time, "%I:%M %p")}"
          true -> Calendar.strftime(start_time, "%b %d at %I:%M %p")
        end
    end
  end

  defp group_events_by_day(events) do
    events
    |> Enum.group_by(fn event ->
      case event.starts_at do
        nil -> Date.utc_today()
        datetime -> DateTime.to_date(datetime)
      end
    end)
    |> Enum.sort_by(fn {date, _events} -> date end)
  end

  defp format_date_header(date) do
    today = Date.utc_today()
    tomorrow = Date.add(today, 1)

    cond do
      Date.compare(date, today) == :eq -> "Today, #{Calendar.strftime(date, "%B %d")}"
      Date.compare(date, tomorrow) == :eq -> "Tomorrow, #{Calendar.strftime(date, "%B %d")}"
      true -> Calendar.strftime(date, "%A, %B %d")
    end
  end

  defp generate_calendar_grid(events) do
    # Get current month bounds
    today = Date.utc_today()
    start_of_month = Date.beginning_of_month(today)
    end_of_month = Date.end_of_month(today)

    # Get first day of calendar (might be from previous month)
    first_day_of_week = Date.day_of_week(start_of_month, :sunday)
    calendar_start = Date.add(start_of_month, -(first_day_of_week - 1))

    # Generate 42 days (6 weeks) for the calendar grid
    calendar_dates = for i <- 0..41 do
      Date.add(calendar_start, i)
    end

    # Group events by date
    events_by_date = Enum.group_by(events, fn event ->
      case event.starts_at do
        nil -> nil
        datetime -> DateTime.to_date(datetime)
      end
    end)

    # Create grid with events
    Enum.map(calendar_dates, fn date ->
      day_events = Map.get(events_by_date, date, [])
      {date, day_events}
    end)
  end

  # Workflow Modal Component
  defp workflow_modal(assigns) do
    ~H"""
    <%= if @show_workflow_modal do %>
      <div class="fixed inset-0 z-50 overflow-y-auto">
        <div class="flex items-center justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
          <!-- Background overlay -->
          <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity"
               phx-click="close_workflow_modal"
               phx-target={@myself}></div>

          <!-- Modal panel -->
          <div class="inline-block align-bottom bg-white rounded-lg text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-lg sm:w-full">
            <div class="bg-white px-4 pt-5 pb-4 sm:p-6 sm:pb-4">
              <div class="sm:flex sm:items-start">
                <div class="mx-auto flex-shrink-0 flex items-center justify-center h-12 w-12 rounded-full bg-purple-100 sm:mx-0 sm:h-10 sm:w-10">
                  <svg class="h-6 w-6 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
                  </svg>
                </div>
                <div class="mt-3 text-center sm:mt-0 sm:ml-4 sm:text-left">
                  <h3 class="text-lg leading-6 font-medium text-gray-900">
                    Start Workflow
                  </h3>
                  <div class="mt-2">
                    <p class="text-sm text-gray-500">
                      This will guide you through a step-by-step process to complete this task efficiently.
                    </p>

                    <!-- Workflow Preview -->
                    <div class="mt-4 bg-gray-50 rounded-lg p-4">
                      <h4 class="text-sm font-medium text-gray-900 mb-2">Workflow Steps:</h4>
                      <ol class="text-sm text-gray-600 space-y-1">
                        <li>1. Review current content</li>
                        <li>2. Identify areas for improvement</li>
                        <li>3. Make necessary updates</li>
                        <li>4. Review and publish changes</li>
                        <li>5. Schedule follow-up tasks</li>
                      </ol>
                      <p class="text-xs text-gray-500 mt-2">
                        Estimated time: 25-30 minutes
                      </p>
                    </div>
                  </div>
                </div>
              </div>
            </div>
            <div class="bg-gray-50 px-4 py-3 sm:px-6 sm:flex sm:flex-row-reverse">
              <button
                phx-click="confirm_start_workflow"
                phx-target={@myself}
                class="w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 bg-purple-600 text-base font-medium text-white hover:bg-purple-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-purple-500 sm:ml-3 sm:w-auto sm:text-sm">
                Start Workflow
              </button>
              <button
                phx-click="close_workflow_modal"
                phx-target={@myself}
                class="mt-3 w-full inline-flex justify-center rounded-md border border-gray-300 shadow-sm px-4 py-2 bg-white text-base font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 sm:mt-0 sm:ml-3 sm:w-auto sm:text-sm">
                Cancel
              </button>
            </div>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  # Additional event handlers for workflow modal
  @impl true
  def handle_event("close_workflow_modal", _params, socket) do
    {:noreply, assign(socket, :show_workflow_modal, false)}
  end

  @impl true
  def handle_event("confirm_start_workflow", _params, socket) do
    event_id = socket.assigns.active_workflow_event_id

    case Calendar.start_workflow(event_id, socket.assigns.user.id) do
      {:ok, _workflow} ->
        # Redirect to workflow interface or update UI
        socket = socket
        |> put_flash(:info, "Workflow started! Follow the steps to complete your task.")
        |> assign(:show_workflow_modal, false)
        |> assign(:active_workflow_event_id, nil)

        {:noreply, socket}

      {:error, _} ->
        socket = socket
        |> put_flash(:error, "Failed to start workflow")
        |> assign(:show_workflow_modal, false)

        {:noreply, socket}
    end
  end

  # Calendar utility functions for date formatting
  defp format_time_12h(datetime) do
    datetime
    |> Calendar.strftime("%I:%M %p")
    |> String.downcase()
  end

  defp is_current_month?(date) do
    today = Date.utc_today()
    Date.beginning_of_month(date) == Date.beginning_of_month(today)
  end

  defp get_week_start(date) do
    days_from_monday = Date.day_of_week(date, :monday) - 1
    Date.add(date, -days_from_monday)
  end

  defp get_week_end(week_start) do
    Date.add(week_start, 6)
  end

  # Quick action helpers
  defp quick_action_buttons(assigns) do
    ~H"""
    <div class="flex items-center space-x-2">
      <!-- Quick Complete -->
      <%= if @event.completion_status in ["pending", "in_progress"] do %>
        <button
          phx-click="complete_event"
          phx-value-event_id={@event.id}
          phx-target={@target}
          title="Mark as complete"
          class="p-1.5 text-green-600 hover:bg-green-100 rounded transition-colors">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
          </svg>
        </button>
      <% end %>

      <!-- Quick Defer -->
      <%= if @event.completion_status in ["pending", "in_progress"] do %>
        <div class="relative" x-data="{ open: false }">
          <button
            @click="open = !open"
            title="Defer event"
            class="p-1.5 text-yellow-600 hover:bg-yellow-100 rounded transition-colors">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
            </svg>
          </button>

          <div
            x-show="open"
            @click.away="open = false"
            x-transition
            class="absolute right-0 mt-1 w-28 bg-white rounded-md shadow-lg border border-gray-200 z-10">
            <button
              phx-click="defer_event"
              phx-value-event_id={@event.id}
              phx-value-days="1"
              phx-target={@target}
              class="block w-full text-left px-2 py-1 text-xs text-gray-700 hover:bg-gray-100">
              +1 day
            </button>
            <button
              phx-click="defer_event"
              phx-value-event_id={@event.id}
              phx-value-days="3"
              phx-target={@target}
              class="block w-full text-left px-2 py-1 text-xs text-gray-700 hover:bg-gray-100">
              +3 days
            </button>
            <button
              phx-click="defer_event"
              phx-value-event_id={@event.id}
              phx-value-days="7"
              phx-target={@target}
              class="block w-full text-left px-2 py-1 text-xs text-gray-700 hover:bg-gray-100">
              +1 week
            </button>
          </div>
        </div>
      <% end %>

      <!-- Workflow Button -->
      <%= if @event.workflow_template do %>
        <button
          phx-click="start_workflow"
          phx-value-event_id={@event.id}
          phx-target={@target}
          title="Start guided workflow"
          class="p-1.5 text-purple-600 hover:bg-purple-100 rounded transition-colors">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
          </svg>
        </button>
      <% end %>
    </div>
    """
  end

  # Final helper functions for formatting and display
  defp get_event_urgency_class(event) do
    cond do
      event.priority_level == "critical" and is_overdue_event?(event) -> "border-l-4 border-red-500 bg-red-50"
      event.priority_level in ["critical", "high"] -> "border-l-4 border-orange-400 bg-orange-50"
      event.revenue_impact in ["critical", "high"] -> "border-l-4 border-green-400 bg-green-50"
      event.auto_generated -> "border-l-4 border-blue-400 bg-blue-50"
      true -> "border-l-4 border-gray-300 bg-white"
    end
  end

  defp is_overdue_event?(event) do
    case event.starts_at do
      nil -> false
      start_time -> DateTime.compare(DateTime.utc_now(), start_time) == :gt
    end
  end

  defp get_completion_percentage(events) do
    if Enum.empty?(events) do
      0
    else
      completed = Enum.count(events, &(&1.completion_status == "completed"))
      (completed / length(events) * 100) |> round()
    end
  end

  defp format_duration_estimate(minutes) when is_integer(minutes) do
    cond do
      minutes < 60 -> "#{minutes}m"
      minutes < 480 -> "#{Float.round(minutes / 60, 1)}h"
      true -> "#{Float.round(minutes / 60 / 8, 1)}d"
    end
  end
  defp format_duration_estimate(_), do: "Unknown"

  defp get_next_action_suggestion(event) do
    case {event.content_type, event.completion_status} do
      {"portfolio_update", "pending"} -> "Review portfolio sections that need updating"
      {"skill_showcase", "pending"} -> "Gather examples of your work with this skill"
      {"project_addition", "pending"} -> "Collect project details and screenshots"
      {"testimonial_request", "pending"} -> "Draft personalized request messages"
      {"revenue_review", "pending"} -> "Analyze current pricing and market rates"
      {_, "in_progress"} -> "Continue with current workflow step"
      {_, "completed"} -> "Task completed successfully"
      _ -> "Click to view details and start working"
    end
  end

  # Smart calendar helpers
  defp should_highlight_event?(event) do
    event.priority_level in ["critical", "high"] or
    event.revenue_impact in ["critical", "high"] or
    is_due_soon?(event)
  end

  defp is_due_soon?(event) do
    case event.starts_at do
      nil -> false
      start_time ->
        hours_until = DateTime.diff(start_time, DateTime.utc_now(), :hour)
        hours_until <= 24 and hours_until >= 0
    end
  end

  defp get_smart_insights_for_events(events) do
    total_events = length(events)
    high_priority = Enum.count(events, &(&1.priority_level in ["critical", "high"]))
    revenue_events = Enum.count(events, &(&1.revenue_impact in ["critical", "high", "medium"]))
    overdue = Enum.count(events, &is_overdue_event?/1)

    insights = []

    insights = if high_priority > total_events * 0.3 do
      ["You have many high-priority items. Consider delegating or rescheduling some tasks." | insights]
    else
      insights
    end

    insights = if overdue > 0 do
      ["#{overdue} overdue tasks need immediate attention." | insights]
    else
      insights
    end

    insights = if revenue_events > 0 do
      ["#{revenue_events} revenue-generating opportunities are scheduled." | insights]
    else
      insights
    end

    if Enum.empty?(insights) do
      ["Your calendar looks well-balanced! Keep up the great work."]
    else
      insights
    end
  end

  # Performance helpers
  defp batch_load_event_data(events) do
    # In a real implementation, this would batch load related data
    # to avoid N+1 queries
    events
  end

  defp cache_calendar_view(user_id, view_data) do
    # Cache the processed calendar view for performance
    # In a real implementation, this would use Redis or ETS
    view_data
  end
end
