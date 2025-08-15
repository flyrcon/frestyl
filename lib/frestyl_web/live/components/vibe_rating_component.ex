# Vibe Rating LiveView Component
# File: lib/frestyl_web/live/components/vibe_rating_component.ex

defmodule FrestylWeb.VibeRatingComponent do
  use FrestylWeb, :live_component

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:rating, %{x: 50, y: 50})
     |> assign(:is_dragging, false)
     |> assign(:rating_start_time, System.monotonic_time(:millisecond))
     |> assign(:submitted, false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="vibe-rating-widget bg-white rounded-xl shadow-lg p-6 max-w-md mx-auto">
      <%= if @submitted do %>
        <!-- Success State -->
        <div class="text-center py-8">
          <div class="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <svg class="w-8 h-8 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
            </svg>
          </div>
          <h3 class="text-lg font-semibold text-gray-900 mb-2">Rating Submitted!</h3>
          <p class="text-gray-600">Thank you for your feedback!</p>
        </div>
      <% else %>
        <!-- Header -->
        <div class="mb-6">
          <h3 class="text-lg font-semibold text-gray-900 mb-2">Team Member Rating</h3>
          <p class="text-sm text-gray-600">
            <%= @rating_prompt || "How would you rate this team member's contribution?" %>
          </p>
        </div>

        <!-- Rating Canvas -->
        <div class="mb-6">
          <div class="relative">
            <!-- Canvas Background with Gradient -->
            <div
              id={"rating-canvas-#{@id}"}
              phx-click="canvas_click"
              phx-target={@myself}
              class="w-full h-48 rounded-lg border-2 border-gray-200 cursor-crosshair relative overflow-hidden"
              style={"background: linear-gradient(to right,
                #ef4444 0%,
                #f97316 25%,
                #eab308 50%,
                #84cc16 75%,
                #22c55e 100%),
                linear-gradient(to bottom,
                rgba(255,255,255,0.8) 0%,
                rgba(255,255,255,0.2) 50%,
                rgba(0,0,0,0.1) 100%)"}
            >
              <!-- Rating Position Indicator -->
              <div
                class="absolute w-4 h-4 bg-white rounded-full border-2 border-gray-800 shadow-lg pointer-events-none transform -translate-x-2 -translate-y-2"
                style={"left: #{@rating.x}%; top: #{100 - @rating.y}%"}
              />
            </div>

            <!-- Axis Labels -->
            <div class="flex justify-between text-xs text-gray-500 mt-2">
              <span>Poor</span>
              <span class="font-medium"><%= @primary_dimension || "Quality" %></span>
              <span>Excellent</span>
            </div>

            <!-- Y-axis label (corrected direction) -->
            <div class="absolute right-0 top-0 h-48 flex flex-col justify-between items-end text-xs text-gray-500 pr-2 pt-2 pb-2">
              <span>High</span>
              <span class="font-medium transform rotate-90 origin-center whitespace-nowrap">
                <%= @secondary_dimension || "Collaboration" %>
              </span>
              <span>Low</span>
            </div>
          </div>
        </div>

        <!-- Current Rating Display -->
        <div class="mb-6 p-4 bg-gray-50 rounded-lg">
          <div class="grid grid-cols-2 gap-4">
            <div>
              <div class="text-sm text-gray-600"><%= @primary_dimension || "Quality" %></div>
              <div class="font-semibold" style={"color: #{get_color_from_position(@rating.x)}"}>
                <%= get_rating_label(@rating.x) %>
              </div>
              <div class="text-xs text-gray-500"><%= round(@rating.x) %>/100</div>
            </div>

            <div>
              <div class="text-sm text-gray-600"><%= @secondary_dimension || "Collaboration" %></div>
              <div class="font-semibold text-gray-700">
                <%= get_secondary_label(@rating.y) %>
              </div>
              <div class="text-xs text-gray-500"><%= round(@rating.y) %>/100</div>
            </div>
          </div>
        </div>

        <!-- Action Buttons -->
        <div class="flex space-x-3">
          <button
            phx-click="reset_rating"
            phx-target={@myself}
            class="flex-1 px-4 py-2 text-gray-600 border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
          >
            Reset
          </button>

          <button
            phx-click="submit_rating"
            phx-target={@myself}
            class="flex-1 px-4 py-2 text-white rounded-lg transition-all hover:scale-105 font-medium"
            style={"background-color: #{get_color_from_position(@rating.x)}; box-shadow: 0 4px 12px #{get_color_from_position(@rating.x)}30"}
          >
            Submit Rating
          </button>
        </div>

        <!-- Helper Text -->
        <div class="mt-4 text-xs text-gray-500 text-center">
          Click on the gradient to position your rating
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("canvas_click", %{"offsetX" => x, "offsetY" => y}, socket) when is_number(x) and is_number(y) do
    # Direct coordinates as numbers
    canvas_width = 300
    canvas_height = 192

    rating_x = (x / canvas_width) * 100
    rating_y = 100 - (y / canvas_height) * 100

    new_rating = %{
      x: max(0, min(100, rating_x)),
      y: max(0, min(100, rating_y))
    }

    {:noreply, assign(socket, :rating, new_rating)}
  end

  def handle_event("canvas_click", %{"offsetX" => x_str, "offsetY" => y_str}, socket) when is_binary(x_str) and is_binary(y_str) do
    # Convert string coordinates to numbers
    {x, _} = Float.parse(x_str)
    {y, _} = Float.parse(y_str)

    handle_event("canvas_click", %{"offsetX" => x, "offsetY" => y}, socket)
  end

  def handle_event("canvas_click", params, socket) do
    # Debug fallback - let's see what we're getting
    IO.inspect(params, label: "Canvas click params")

    # Try to extract coordinates in any format
    x = case params do
      %{"offsetX" => x} when is_number(x) -> x
      %{"offsetX" => x_str} when is_binary(x_str) ->
        case Float.parse(x_str) do
          {x, _} -> x
          _ -> 150.0
        end
      %{"layerX" => x} when is_number(x) -> x
      %{"clientX" => client_x} -> client_x - 50  # Rough offset estimate
      _ -> 150.0  # Default to center
    end

    y = case params do
      %{"offsetY" => y} when is_number(y) -> y
      %{"offsetY" => y_str} when is_binary(y_str) ->
        case Float.parse(y_str) do
          {y, _} -> y
          _ -> 96.0
        end
      %{"layerY" => y} when is_number(y) -> y
      %{"clientY" => client_y} -> client_y - 50  # Rough offset estimate
      _ -> 96.0  # Default to center
    end

    # Now call with extracted coordinates
    handle_event("canvas_click", %{"offsetX" => x, "offsetY" => y}, socket)
  end

  def handle_event("canvas_drag", params, socket) do
    if socket.assigns.is_dragging do
      handle_event("canvas_click", params, socket)
    else
      {:noreply, socket}
    end
  end

  def handle_event("canvas_mouseup", _params, socket) do
    {:noreply, assign(socket, :is_dragging, false)}
  end

  def handle_event("reset_rating", _params, socket) do
    {:noreply, assign(socket, :rating, %{x: 50, y: 50})}
  end

  def handle_event("submit_rating", _params, socket) do
    duration = System.monotonic_time(:millisecond) - socket.assigns.rating_start_time

    rating_data = %{
      primary_score: socket.assigns.rating.x,
      secondary_score: socket.assigns.rating.y,
      rating_coordinates: socket.assigns.rating,
      rating_session_duration: duration,
      color: get_color_from_position(socket.assigns.rating.x)
    }

    # Send rating data to parent component
    send(self(), {:rating_submitted, rating_data})

    {:noreply, assign(socket, :submitted, true)}
  end

  # Helper functions for rating labels and colors
  defp get_color_from_position(x) do
    # Create smooth red to green gradient
    hue = (x / 100.0) * 120 # 0 = red (0°), 120 = green (120°)
    "hsl(#{hue}, 75%, 50%)"
  end

  defp get_rating_label(score) do
    cond do
      score <= 20 -> "Poor"
      score <= 40 -> "Below Average"
      score <= 60 -> "Average"
      score <= 80 -> "Good"
      true -> "Excellent"
    end
  end

  defp get_secondary_label(score) do
    cond do
      score <= 25 -> "Low"
      score <= 50 -> "Moderate"
      score <= 75 -> "High"
      true -> "Exceptional"
    end
  end
end
