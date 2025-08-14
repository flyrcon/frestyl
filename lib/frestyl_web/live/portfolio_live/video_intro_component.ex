defmodule FrestylWeb.PortfolioLive.VideoIntroComponent do
  @moduledoc """
  Clean, simplified video intro component for portfolio system.
  All countdown and timing logic handled by JavaScript hook.
  """
  use FrestylWeb, :live_component

  # ============================================================================
  # INITIALIZATION
  # ============================================================================

  @impl true
  def mount(socket) do
    socket =
      socket
      |> assign(:recording_state, :setup)
      |> assign(:camera_status, :initializing)
      |> assign(:camera_ready, false)
      |> assign(:countdown_display, nil)
      |> assign(:recording_duration, 0)
      |> assign(:video_blob, nil)
      |> assign(:error_message, nil)
      |> assign(:upload_progress, 0)
      |> assign(:max_duration, 120)
      |> assign(:aspect_ratio, "16:9")
      |> assign(:video_position, :about)
      |> assign(:upload_mode, false)

    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)
    {:ok, socket}
  end

  # ============================================================================
  # RENDER FUNCTIONS
  # ============================================================================

  @impl true
  def render(assigns) do
    ~H"""
    <div class="video-intro-component space-y-6">
      <!-- Header -->
      <div class="text-center">
        <h3 class="text-xl font-bold text-gray-900 mb-2">Video Introduction</h3>
        <p class="text-gray-600">
          Record a personal introduction for your portfolio
        </p>
      </div>

      <!-- Main Content Area -->
      <div class="bg-white rounded-xl border shadow-sm p-6">
        <%= case @recording_state do %>
          <% :setup -> %>
            <%= render_camera_setup(assigns) %>
          <% :countdown -> %>
            <%= render_countdown(assigns) %>
          <% :recording -> %>
            <%= render_recording(assigns) %>
          <% :preview -> %>
            <%= render_preview(assigns) %>
          <% :uploading -> %>
            <%= render_uploading(assigns) %>
          <% :complete -> %>
            <%= render_complete(assigns) %>
          <% _ -> %>
            <%= render_camera_setup(assigns) %>
        <% end %>
      </div>

      <!-- Upload Mode Toggle (Pro users) -->
      <%= if assigns[:user_tier] in ["pro", "premium"] do %>
        <div class="flex items-center justify-center">
          <label class="flex items-center space-x-3 text-sm">
            <input type="checkbox"
                   checked={@upload_mode}
                   phx-click="toggle_upload_mode"
                   phx-target={@myself}
                   class="w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500">
            <span class="text-gray-700">Upload video file instead</span>
          </label>
        </div>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # RENDER PHASES
  # ============================================================================

  defp render_camera_setup(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Camera Preview -->
      <div class="relative bg-gray-900 rounded-xl overflow-hidden" style={get_aspect_ratio_style(@aspect_ratio)}>
        <!-- Video Element -->
        <video
          id={"camera-preview-#{@id}"}
          class="w-full h-full object-cover"
          autoplay
          muted
          playsinline
          phx-hook="VideoCapture"
          data-component-id={@id}
          style="transform: scaleX(-1);">
        </video>

        <!-- Loading Overlay -->
        <%= if @camera_status == :initializing do %>
          <div class="absolute inset-0 flex items-center justify-center bg-gray-900 bg-opacity-90">
            <div class="text-center space-y-4">
              <div class="w-16 h-16 border-4 border-blue-500 border-t-transparent rounded-full animate-spin mx-auto"></div>
              <div class="text-white">
                <h4 class="font-medium mb-2">Initializing Camera...</h4>
                <p class="text-sm text-gray-300">Please allow camera access when prompted</p>
              </div>
            </div>
          </div>
        <% end %>

        <!-- Error Overlay -->
        <%= if @error_message do %>
          <div class="absolute inset-0 flex items-center justify-center bg-red-900 bg-opacity-90">
            <div class="text-center text-white max-w-sm">
              <svg class="w-16 h-16 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
              </svg>
              <h4 class="font-semibold mb-2">Camera Error</h4>
              <p class="text-sm mb-4"><%= @error_message %></p>
              <button phx-click="retry_camera" phx-target={@myself}
                      class="px-4 py-2 bg-white text-red-900 rounded-lg hover:bg-gray-100 transition-colors">
                Try Again
              </button>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Controls -->
      <%= if @camera_ready do %>
        <div class="text-center space-y-4">
          <button phx-click="start_countdown" phx-target={@myself}
                  class="px-8 py-3 bg-red-600 text-white rounded-xl hover:bg-red-700 transition-colors font-medium text-lg">
            <svg class="w-5 h-5 mr-2 inline" fill="currentColor" viewBox="0 0 20 20">
              <circle cx="10" cy="10" r="8"/>
            </svg>
            Start Recording
          </button>

          <p class="text-sm text-gray-600">
            Maximum duration: <%= @max_duration %> seconds
          </p>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_countdown(assigns) do
    ~H"""
    <div class="text-center">
      <div class="relative bg-black rounded-xl overflow-hidden" style={get_aspect_ratio_style(@aspect_ratio)}>
        <!-- Video Preview -->
        <video id={"camera-preview-#{@id}"} autoplay muted playsinline
               class="w-full h-full object-cover" style="transform: scaleX(-1);">
        </video>

        <!-- Countdown Overlay -->
        <div class="absolute inset-0 bg-black bg-opacity-60 flex items-center justify-center">
          <div class="text-center">
            <div class="text-9xl font-black text-white mb-6 animate-pulse drop-shadow-2xl">
              <%= @countdown_display || 3 %>
            </div>
            <p class="text-white text-2xl font-semibold mb-4">Get ready to record...</p>
            <div class="flex justify-center">
              <div class="animate-spin w-6 h-6 border-2 border-white border-t-transparent rounded-full"></div>
            </div>
          </div>
        </div>
      </div>

      <div class="mt-6">
        <button phx-click="cancel_countdown" phx-target={@myself}
                class="px-6 py-3 bg-gray-600 text-white rounded-lg hover:bg-gray-700 transition-colors">
          Cancel Recording
        </button>
      </div>
    </div>
    """
  end

  defp render_recording(assigns) do
    ~H"""
    <div class="text-center">
      <div class="relative bg-black rounded-xl overflow-hidden" style={get_aspect_ratio_style(@aspect_ratio)}>
        <!-- Video Preview -->
        <video id={"camera-preview-#{@id}"} autoplay muted playsinline
               class="w-full h-full object-cover" style="transform: scaleX(-1);">
        </video>

        <!-- Recording Indicator -->
        <div class="absolute top-4 left-4 flex items-center space-x-2">
          <div class="w-4 h-4 bg-red-500 rounded-full animate-pulse"></div>
          <span class="text-white font-medium">REC</span>
        </div>

        <!-- Recording Timer -->
        <div class="absolute top-4 right-4 bg-black bg-opacity-50 text-white px-3 py-1 rounded-lg text-sm font-mono">
          <%= format_time(@recording_duration) %>
        </div>
      </div>

      <div class="mt-6 space-y-4">
        <button phx-click="stop_recording" phx-target={@myself}
                class="px-8 py-3 bg-gray-600 text-white rounded-xl hover:bg-gray-700 transition-colors font-medium">
          <svg class="w-5 h-5 mr-2 inline" fill="currentColor" viewBox="0 0 20 20">
            <rect x="6" y="6" width="8" height="8"/>
          </svg>
          Stop Recording
        </button>

        <p class="text-sm text-gray-600">
          Recording in progress... Maximum duration: <%= @max_duration %> seconds
        </p>
      </div>
    </div>
    """
  end

  defp render_preview(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Video Preview -->
      <div class="relative bg-gray-900 rounded-xl overflow-hidden" style={get_aspect_ratio_style(@aspect_ratio)}>
        <video id="recorded-video-preview"
               class="w-full h-full object-cover"
               controls
               preload="metadata">
          <source src={@video_blob} type="video/webm">
          Your browser does not support the video tag.
        </video>
      </div>

      <!-- Preview Info -->
      <div class="text-center space-y-2">
        <h4 class="font-medium text-gray-900">Review Your Recording</h4>
        <p class="text-sm text-gray-600">
          Duration: <%= format_time(@recording_duration) %>
        </p>
      </div>

      <!-- Video Position Selection -->
      <div class="bg-gray-50 rounded-lg p-4">
        <h5 class="font-medium text-gray-900 mb-3">Where should this video appear?</h5>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
          <%= for position <- [:hero, :about, :footer] do %>
            <label class="flex items-center p-3 border border-gray-200 rounded-lg cursor-pointer hover:bg-white transition-colors">
              <input type="radio"
                     name="video_position"
                     value={position}
                     checked={@video_position == position}
                     phx-click="set_video_position"
                     phx-value-position={position}
                     phx-target={@myself}
                     class="w-4 h-4 text-blue-600 border-gray-300 focus:ring-blue-500">
              <div class="ml-3">
                <div class="font-medium text-sm"><%= format_position_name(position) %></div>
                <div class="text-xs text-gray-500"><%= get_position_description(position) %></div>
              </div>
            </label>
          <% end %>
        </div>
      </div>

      <!-- Action Buttons -->
      <div class="flex space-x-3 justify-center">
        <button phx-click="retake_video" phx-target={@myself}
                class="px-6 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors">
          Retake
        </button>

        <button phx-click="save_video" phx-target={@myself}
                class="px-8 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors font-medium">
          Save Video
        </button>
      </div>
    </div>
    """
  end

  defp render_uploading(assigns) do
    ~H"""
    <div class="text-center space-y-6">
      <div class="w-20 h-20 bg-blue-100 rounded-2xl flex items-center justify-center mx-auto">
        <svg class="w-10 h-10 text-blue-600 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
        </svg>
      </div>

      <div>
        <h4 class="text-lg font-semibold text-gray-900 mb-2">Saving Your Video</h4>
        <p class="text-gray-600 mb-6">Processing and integrating your video introduction...</p>

        <!-- Progress Bar -->
        <div class="max-w-md mx-auto">
          <div class="w-full bg-gray-200 rounded-full h-3">
            <div class="bg-blue-600 h-3 rounded-full transition-all duration-500"
                 style={"width: #{@upload_progress}%"}></div>
          </div>
          <p class="text-sm text-gray-500 mt-2"><%= @upload_progress %>% Complete</p>
        </div>
      </div>
    </div>
    """
  end

  defp render_complete(assigns) do
    ~H"""
    <div class="text-center space-y-6">
      <div class="w-20 h-20 bg-green-100 rounded-2xl flex items-center justify-center mx-auto">
        <svg class="w-10 h-10 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
        </svg>
      </div>

      <div>
        <h4 class="text-lg font-semibold text-gray-900 mb-2">Video Saved Successfully!</h4>
        <p class="text-gray-600 mb-6">Your video introduction has been added to your portfolio</p>

        <div class="space-y-3">
          <button phx-click="close_modal" phx-target={@myself}
                  class="w-full bg-green-600 text-white py-3 rounded-lg hover:bg-green-700 transition-colors">
            Continue Editing Portfolio
          </button>

          <button phx-click="record_another" phx-target={@myself}
                  class="w-full border border-gray-300 text-gray-700 py-3 rounded-lg hover:bg-gray-50 transition-colors">
            Record Another Video
          </button>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # EVENT HANDLERS
  # ============================================================================

  @impl true
  def handle_event("camera_ready", _params, socket) do
    IO.puts("📹 Camera ready")

    socket =
      socket
      |> assign(:camera_status, :ready)
      |> assign(:camera_ready, true)
      |> assign(:error_message, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("camera_error", %{"error" => error}, socket) do
    IO.puts("❌ Camera error: #{error}")

    socket =
      socket
      |> assign(:camera_status, :error)
      |> assign(:camera_ready, false)
      |> assign(:error_message, error)

    {:noreply, socket}
  end

  @impl true
  def handle_event("start_countdown", _params, socket) do
    IO.puts("🎬 Starting countdown")

    socket =
      socket
      |> assign(:recording_state, :countdown)
      |> assign(:countdown_display, 3)
      |> assign(:error_message, nil)

    # Send countdown start event to JavaScript hook
    socket = push_event(socket, "start_countdown", %{count: 3})

    {:noreply, socket}
  end

  @impl true
  def handle_event("countdown_tick", %{"count" => count}, socket) do
    IO.puts("🎬 Countdown tick: #{count}")

    socket = assign(socket, :countdown_display, count)
    {:noreply, socket}
  end

  @impl true
  def handle_event("recording_started", _params, socket) do
    IO.puts("🎬 Recording started")

    socket =
      socket
      |> assign(:recording_state, :recording)
      |> assign(:countdown_display, nil)
      |> assign(:recording_duration, 0)

    {:noreply, socket}
  end

  @impl true
  def handle_event("recording_tick", %{"duration" => duration}, socket) do
    socket = assign(socket, :recording_duration, duration)
    {:noreply, socket}
  end

  @impl true
  def handle_event("stop_recording", _params, socket) do
    IO.puts("⏹️ Stop recording")

    # Send stop recording event to JavaScript hook
    socket = push_event(socket, "stop_recording", %{})

    {:noreply, socket}
  end

  @impl true
  def handle_event("recording_complete", params, socket) do
    IO.puts("🎬 Recording complete")

    socket =
      socket
      |> assign(:recording_state, :preview)
      |> assign(:video_blob, params["videoUrl"])
      |> assign(:recording_duration, params["duration"] || 0)

    {:noreply, socket}
  end

  @impl true
  def handle_event("recording_error", %{"error" => error}, socket) do
    IO.puts("❌ Recording error: #{error}")

    socket =
      socket
      |> assign(:recording_state, :setup)
      |> assign(:error_message, "Recording failed: #{error}")
      |> assign(:recording_duration, 0)

    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel_countdown", _params, socket) do
    IO.puts("❌ Countdown cancelled")

    socket =
      socket
      |> assign(:recording_state, :setup)
      |> assign(:countdown_display, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("retry_camera", _params, socket) do
    IO.puts("🔄 Retrying camera")

    socket =
      socket
      |> assign(:camera_status, :initializing)
      |> assign(:camera_ready, false)
      |> assign(:error_message, nil)
      |> assign(:recording_state, :setup)

    # Send retry event to JavaScript hook
    socket = push_event(socket, "retry_camera", %{})

    {:noreply, socket}
  end

  @impl true
  def handle_event("set_video_position", %{"position" => position}, socket) do
    position_atom = String.to_existing_atom(position)
    socket = assign(socket, :video_position, position_atom)
    {:noreply, socket}
  end

  @impl true
  def handle_event("retake_video", _params, socket) do
    IO.puts("🔄 Retaking video")

    socket =
      socket
      |> assign(:recording_state, :setup)
      |> assign(:video_blob, nil)
      |> assign(:recording_duration, 0)
      |> assign(:countdown_display, nil)
      |> assign(:error_message, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("save_video", _params, socket) do
    IO.puts("💾 Saving video")

    socket =
      socket
      |> assign(:recording_state, :uploading)
      |> assign(:upload_progress, 0)

    # Start upload progress simulation
    send(self(), {:upload_progress, socket.assigns.id, 10})

    {:noreply, socket}
  end

  @impl true
  def handle_event("record_another", _params, socket) do
    socket =
      socket
      |> assign(:recording_state, :setup)
      |> assign(:video_blob, nil)
      |> assign(:recording_duration, 0)
      |> assign(:countdown_display, nil)
      |> assign(:upload_progress, 0)

    {:noreply, socket}
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    # Send close event to parent
    send(self(), {:close_video_intro_modal})
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_upload_mode", _params, socket) do
    if socket.assigns[:user_tier] in ["pro", "premium"] do
      upload_mode = !socket.assigns.upload_mode
      socket = assign(socket, :upload_mode, upload_mode)
      {:noreply, socket}
    else
      socket = put_flash(socket, :error, "Video upload is available for Pro users. Please upgrade your account.")
      {:noreply, socket}
    end
  end

  # ============================================================================
  # UPLOAD PROGRESS SIMULATION
  # ============================================================================

  @impl true
  def handle_info({:upload_progress, component_id, progress}, socket) do
    if socket.assigns.id == component_id && socket.assigns.recording_state == :uploading do
      socket = assign(socket, :upload_progress, progress)

      cond do
        progress >= 100 ->
          # Upload complete
          socket = assign(socket, :recording_state, :complete)
          {:noreply, socket}

        progress >= 90 ->
          # Final step
          send(self(), {:upload_progress, component_id, 100})
          {:noreply, socket}

        true ->
          # Continue progress
          next_progress = min(progress + Enum.random(5..15), 95)
          Process.send_after(self(), {:upload_progress, component_id, next_progress}, Enum.random(500..1500))
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  # Handle other messages
  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp get_aspect_ratio_style("16:9"), do: "aspect-ratio: 16/9;"
  defp get_aspect_ratio_style("4:3"), do: "aspect-ratio: 4/3;"
  defp get_aspect_ratio_style("1:1"), do: "aspect-ratio: 1/1;"
  defp get_aspect_ratio_style(_), do: "aspect-ratio: 16/9;"

  defp format_time(seconds) when is_integer(seconds) do
    minutes = div(seconds, 60)
    remaining_seconds = rem(seconds, 60)
    "#{String.pad_leading(to_string(minutes), 2, "0")}:#{String.pad_leading(to_string(remaining_seconds), 2, "0")}"
  end
  defp format_time(_), do: "00:00"

  defp format_position_name(:hero), do: "Hero Section"
  defp format_position_name(:about), do: "About Section"
  defp format_position_name(:footer), do: "Footer Section"
  defp format_position_name(_), do: "About Section"

  defp get_position_description(:hero), do: "Large video at the top of your portfolio"
  defp get_position_description(:about), do: "Personal introduction in your about section"
  defp get_position_description(:footer), do: "Closing video at the bottom of your portfolio"
  defp get_position_description(_), do: "Standard placement in your portfolio"

end
