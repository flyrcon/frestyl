# Vibe Rating Demo LiveView
# File: lib/frestyl_web/live/vibe_rating_demo_live.ex

defmodule FrestylWeb.VibeRatingDemoLive do
  use FrestylWeb, :live_view
  alias FrestylWeb.VibeRatingComponent

  @impl true
  def mount(_params, _session, socket) do
    # Set a default user for demo purposes if none exists
    current_user = case socket.assigns[:current_user] do
      nil -> %{id: 1, first_name: "Demo", last_name: "User", email: "demo@example.com"}
      user -> user
    end

    {:ok,
     socket
     |> assign(:current_user, current_user)
     |> assign(:submissions, [])
     |> assign(:demo_scenarios, get_demo_scenarios())}
  end

  @impl true
  def handle_info({:rating_submitted, rating_data}, socket) do
    submission = Map.merge(rating_data, %{
      timestamp: DateTime.utc_now(),
      id: System.unique_integer([:positive])
    })

    {:noreply,
     socket
     |> assign(:submissions, [submission | socket.assigns.submissions])
     |> put_flash(:info, "Rating submitted successfully!")}
  end

  @impl true
  def handle_event("clear_submissions", _params, socket) do
    {:noreply, assign(socket, :submissions, [])}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-8 bg-gray-100 min-h-screen">
      <div class="max-w-6xl mx-auto">
        <h1 class="text-3xl font-bold text-gray-900 mb-8 text-center">
          Vibe Rating System Demo
        </h1>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
          <!-- Rating Widget -->
          <div>
            <h2 class="text-xl font-semibold text-gray-900 mb-4">Try the Rating System</h2>

            <!-- Demo Scenarios -->
            <div class="mb-6 p-4 bg-blue-50 rounded-lg">
              <h3 class="font-medium text-blue-900 mb-2">Demo Scenarios:</h3>
              <div class="space-y-2 text-sm">
                <%= for scenario <- @demo_scenarios do %>
                  <div class="text-blue-800">
                    <strong><%= scenario.title %>:</strong> <%= scenario.description %>
                  </div>
                <% end %>
              </div>
            </div>

            <.live_component
              module={VibeRatingComponent}
              id="demo-rating"
              primary_dimension="Work Quality"
              secondary_dimension="Team Collaboration"
              rating_prompt="How would you rate Sarah's contribution to this project milestone?"
            />
          </div>

          <!-- Submissions History -->
          <div>
            <div class="bg-white rounded-xl shadow-lg p-6">
              <div class="flex items-center justify-between mb-4">
                <h3 class="text-lg font-semibold text-gray-900">
                  Rating Submissions (<%= length(@submissions) %>)
                </h3>
                <%= if length(@submissions) > 0 do %>
                  <button
                    phx-click="clear_submissions"
                    class="text-sm text-red-600 hover:text-red-700"
                  >
                    Clear All
                  </button>
                <% end %>
              </div>

              <div class="space-y-3 max-h-96 overflow-y-auto">
                <%= if length(@submissions) == 0 do %>
                  <p class="text-gray-500 text-center py-8">
                    Submit a rating to see results
                  </p>
                <% else %>
                  <%= for submission <- @submissions do %>
                    <div class="border border-gray-200 rounded-lg p-4">
                      <div class="flex items-center justify-between mb-2">
                        <span class="text-sm text-gray-600">
                          <%= Calendar.strftime(submission.timestamp, "%H:%M:%S") %>
                        </span>
                        <div
                          class="w-4 h-4 rounded-full border border-gray-300"
                          style={"background-color: #{submission.color}"}
                        />
                      </div>

                      <div class="grid grid-cols-2 gap-2 text-sm mb-2">
                        <div>
                          <span class="text-gray-600">Quality:</span>
                          <span class="font-medium ml-1">
                            <%= Float.round(submission.primary_score, 1) %>
                          </span>
                        </div>
                        <div>
                          <span class="text-gray-600">Collaboration:</span>
                          <span class="font-medium ml-1">
                            <%= Float.round(submission.secondary_score, 1) %>
                          </span>
                        </div>
                      </div>

                      <!-- Visual representation -->
                      <div class="mb-2">
                        <div class="w-full bg-gray-200 rounded-full h-2 mb-1">
                          <div
                            class="h-2 rounded-full transition-all duration-300"
                            style={"width: #{submission.primary_score}%; background-color: #{submission.color}"}
                          />
                        </div>
                        <div class="text-xs text-gray-500">
                          Quality: <%= get_quality_description(submission.primary_score) %>
                        </div>
                      </div>

                      <div class="mb-3">
                        <div class="w-full bg-gray-200 rounded-full h-2 mb-1">
                          <div
                            class="h-2 rounded-full bg-blue-500 transition-all duration-300"
                            style={"width: #{submission.secondary_score}%"}
                          />
                        </div>
                        <div class="text-xs text-gray-500">
                          Collaboration: <%= get_collaboration_description(submission.secondary_score) %>
                        </div>
                      </div>

                      <div class="text-xs text-gray-500">
                        Consideration time: <%= Float.round(submission.rating_session_duration / 1000, 1) %>s
                      </div>
                    </div>
                  <% end %>
                <% end %>
              </div>
            </div>

            <!-- Analytics Summary -->
            <%= if length(@submissions) > 0 do %>
              <div class="mt-6 bg-white rounded-xl shadow-lg p-6">
                <h3 class="text-lg font-semibold text-gray-900 mb-4">Analytics Summary</h3>

                <div class="grid grid-cols-2 gap-4">
                  <div class="text-center">
                    <div class="text-2xl font-bold text-gray-900">
                      <%= Float.round(get_average_quality(@submissions), 1) %>
                    </div>
                    <div class="text-sm text-gray-600">Avg Quality</div>
                  </div>

                  <div class="text-center">
                    <div class="text-2xl font-bold text-blue-600">
                      <%= Float.round(get_average_collaboration(@submissions), 1) %>
                    </div>
                    <div class="text-sm text-gray-600">Avg Collaboration</div>
                  </div>

                  <div class="text-center">
                    <div class="text-2xl font-bold text-green-600">
                      <%= Float.round(get_rating_consistency(@submissions), 1) %>%
                    </div>
                    <div class="text-sm text-gray-600">Consistency</div>
                  </div>

                  <div class="text-center">
                    <div class="text-2xl font-bold text-purple-600">
                      <%= Float.round(get_average_consideration_time(@submissions), 1) %>s
                    </div>
                    <div class="text-sm text-gray-600">Avg Time</div>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </div>

        <!-- System Benefits -->
        <div class="mt-12 bg-white rounded-xl shadow-lg p-8">
          <h2 class="text-2xl font-bold text-gray-900 mb-6 text-center">
            Why Vibe Rating Works Better
          </h2>

          <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
            <div class="text-center">
              <div class="w-16 h-16 bg-blue-100 rounded-full flex items-center justify-center mx-auto mb-4">
                <svg class="w-8 h-8 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
                </svg>
              </div>
              <h3 class="font-semibold text-gray-900 mb-2">Intuitive & Fast</h3>
              <p class="text-gray-600 text-sm">
                Color naturally conveys quality judgment. Single click/drag vs multiple form fields.
              </p>
            </div>

            <div class="text-center">
              <div class="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
                <svg class="w-8 h-8 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/>
                </svg>
              </div>
              <h3 class="font-semibold text-gray-900 mb-2">Rich Data</h3>
              <p class="text-gray-600 text-sm">
                100x100 grid = 10,000 positions vs 5-point scale. Captures nuanced feedback.
              </p>
            </div>

            <div class="text-center">
              <div class="w-16 h-16 bg-purple-100 rounded-full flex items-center justify-center mx-auto mb-4">
                <svg class="w-8 h-8 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 9l3 3-3 3m5 0h3M5 20h14a2 2 0 002-2V6a2 2 0 00-2-2H5a2 2 0 00-2 2v14a2 2 0 002 2z"/>
                </svg>
              </div>
              <h3 class="font-semibold text-gray-900 mb-2">Reduced Bias</h3>
              <p class="text-gray-600 text-sm">
                Less anchoring to specific numbers. Visual interface reduces cognitive load.
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions
  defp get_demo_scenarios do
    [
      %{
        title: "High Quality, Great Collaborator",
        description: "Click top-right (green area, high vertical) for excellent work + team player"
      },
      %{
        title: "Good Work, Poor Collaboration",
        description: "Click top-left (green area, low vertical) for quality work but difficult teammate"
      },
      %{
        title: "Needs Improvement",
        description: "Click bottom-left (red area) for work that needs significant improvement"
      }
    ]
  end

  defp get_quality_description(score) do
    cond do
      score >= 80 -> "Excellent work"
      score >= 60 -> "Good quality"
      score >= 40 -> "Average"
      score >= 20 -> "Below average"
      true -> "Needs improvement"
    end
  end

  defp get_collaboration_description(score) do
    cond do
      score >= 80 -> "Exceptional teammate"
      score >= 60 -> "Great collaborator"
      score >= 40 -> "Good team member"
      score >= 20 -> "Some collaboration issues"
      true -> "Difficult to work with"
    end
  end

  defp get_average_quality(submissions) do
    submissions
    |> Enum.map(& &1.primary_score)
    |> Enum.sum()
    |> Kernel./(length(submissions))
  end

  defp get_average_collaboration(submissions) do
    submissions
    |> Enum.map(& &1.secondary_score)
    |> Enum.sum()
    |> Kernel./(length(submissions))
  end

  defp get_rating_consistency(submissions) do
    if length(submissions) < 2 do
      100.0
    else
      quality_scores = Enum.map(submissions, & &1.primary_score)
      variance = calculate_variance(quality_scores)
      max_variance = 2500 # Max possible variance for 0-100 scale
      max(0, 100 - (variance / max_variance * 100))
    end
  end

  defp get_average_consideration_time(submissions) do
    submissions
    |> Enum.map(& &1.rating_session_duration)
    |> Enum.sum()
    |> Kernel./(length(submissions))
    |> Kernel./(1000)
  end

  defp calculate_variance(numbers) do
    mean = Enum.sum(numbers) / length(numbers)
    squared_diffs = Enum.map(numbers, &:math.pow(&1 - mean, 2))
    Enum.sum(squared_diffs) / length(squared_diffs)
  end
end
