# lib/frestyl_web/live/portfolio_live/video_intro_component.ex
# ============================================================================

defmodule FrestylWeb.PortfolioLive.VideoIntroComponent do
  use FrestylWeb, :live_component

  alias Frestyl.Portfolios
  alias Frestyl.Media

  # ============================================================================
  # COMPONENT LIFECYCLE
  # ============================================================================

  @impl true
  def mount(socket) do
    IO.puts("=== VIDEO INTRO COMPONENT MOUNTING ===")

    socket =
      socket
      |> assign(:recording_state, :setup)
      |> assign(:elapsed_time, 0)
      |> assign(:recorded_blob, nil)
      |> assign(:camera_ready, false)
      |> assign(:upload_progress, 0)
      |> assign(:error_message, nil)
      |> assign(:camera_status, "initializing")
      |> assign(:countdown_timer, 3)
      |> assign(:countdown_value, 3)
      |> assign(:upload_mode, false)
      |> assign(:max_duration, 60)
      |> assign(:supported_formats, ["video/mp4", "video/webm", "video/quicktime"])

    {:ok, socket}
  end

  @impl true
  def update(%{portfolio: portfolio, current_user: user} = assigns, socket) do
    # Get user tier for quality settings
    user_tier = get_user_subscription_tier(user)
    quality_settings = get_quality_settings_for_tier(user_tier)

    # Check for existing video intro section
    existing_video_section = get_existing_video_section(portfolio.id)

    socket =
      socket
      |> assign(assigns)
      |> assign(:user_tier, user_tier)
      |> assign(:quality_settings, quality_settings)
      |> assign(:existing_video_section, existing_video_section)

    {:ok, socket}
  end

  # ============================================================================
  # EVENT HANDLERS - Camera and Recording
  # ============================================================================

  @impl true
  def handle_event("initialize_camera", _params, socket) do
    IO.puts("=== INITIALIZE CAMERA ===")

    socket =
      socket
      |> assign(:camera_status, "requesting_permission")
      |> push_event("initialize_camera", %{
          constraints: socket.assigns.quality_settings.video_constraints,
          component_id: socket.assigns.id
        })

    {:noreply, socket}
  end

  @impl true
  def handle_event("camera_ready", %{"stream_active" => true}, socket) do
    IO.puts("=== CAMERA READY ===")

    socket =
      socket
      |> assign(:camera_ready, true)
      |> assign(:camera_status, "ready")
      |> assign(:error_message, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("camera_error", %{"error" => error_type, "message" => message}, socket) do
    IO.puts("=== CAMERA ERROR: #{error_type} ===")

    {status, user_message} = case error_type do
      "NotAllowedError" ->
        {"permission_denied", "Camera access denied. Please allow camera access and refresh."}
      "NotFoundError" ->
        {"no_camera", "No camera found. Please check your camera connection."}
      "NotReadableError" ->
        {"camera_busy", "Camera is being used by another application."}
      _ ->
        {"error", "Camera error: #{message}"}
    end

    socket =
      socket
      |> assign(:camera_ready, false)
      |> assign(:camera_status, status)
      |> assign(:error_message, user_message)

    {:noreply, socket}
  end

  @impl true
  def handle_event("start_countdown", _params, socket) do
    if socket.assigns.camera_ready do
      IO.puts("=== STARTING COUNTDOWN ===")

      socket =
        socket
        |> assign(:recording_state, :countdown)
        |> assign(:countdown_value, 3)
        |> push_event("start_countdown", %{component_id: socket.assigns.id})

      {:noreply, socket}
    else
      {:noreply, put_flash(socket, :error, "Camera not ready. Please allow camera access.")}
    end
  end

  @impl true
  def handle_event("countdown_update", %{"count" => count}, socket) do
    if count == 0 do
      # Start recording
      socket =
        socket
        |> assign(:recording_state, :recording)
        |> assign(:countdown_value, 0)
        |> assign(:elapsed_time, 0)
        |> push_event("start_recording", %{
            component_id: socket.assigns.id,
            max_duration: socket.assigns.max_duration,
            quality: socket.assigns.quality_settings
          })

      # Start timer for elapsed time
      send_recording_tick(socket.assigns.id)

      {:noreply, socket}
    else
      {:noreply, assign(socket, :countdown_value, count)}
    end
  end

  @impl true
  def handle_event("stop_recording", _params, socket) do
    IO.puts("=== STOP RECORDING ===")

    socket =
      socket
      |> assign(:recording_state, :processing)
      |> push_event("stop_recording", %{component_id: socket.assigns.id})

    {:noreply, socket}
  end

  @impl true
  def handle_event("recording_complete", %{"blob_data" => blob_data} = params, socket) do
    IO.puts("=== RECORDING COMPLETE ===")
    IO.puts("Blob size: #{byte_size(blob_data)} bytes")

    socket =
      socket
      |> assign(:recording_state, :preview)
      |> assign(:recorded_blob, blob_data)
      |> assign(:video_duration, Map.get(params, "duration", 0))
      |> assign(:video_size, byte_size(blob_data))

    {:noreply, socket}
  end

  @impl true
  def handle_event("retake_video", _params, socket) do
    IO.puts("=== RETAKE VIDEO ===")

    socket =
      socket
      |> assign(:recording_state, :setup)
      |> assign(:elapsed_time, 0)
      |> assign(:recorded_blob, nil)
      |> assign(:countdown_value, 3)
      |> assign(:error_message, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("save_video", _params, socket) do
    if socket.assigns.recorded_blob do
      IO.puts("=== SAVING VIDEO ===")

      socket = assign(socket, :recording_state, :saving)

      # Start async upload
      Task.start(fn ->
        upload_video_intro(socket.assigns.portfolio, socket.assigns.recorded_blob, socket.assigns.current_user)
      end)

      {:noreply, socket}
    else
      {:noreply, put_flash(socket, :error, "No video to save")}
    end
  end

  @impl true
  def handle_event("toggle_upload_mode", _params, socket) do
    socket = assign(socket, :upload_mode, !socket.assigns.upload_mode)
    {:noreply, socket}
  end

  @impl true
  def handle_event("file_upload", params, socket) do
    IO.puts("=== FILE UPLOAD ===")
    IO.inspect(Map.keys(params), label: "Upload params")

    case params do
      %{"file_data" => file_data, "file_name" => filename, "file_type" => file_type} ->
        if valid_video_format?(file_type) do
          socket =
            socket
            |> assign(:recording_state, :saving)
            |> assign(:upload_progress, 0)

          # Start async upload
          Task.start(fn ->
            upload_video_file(socket.assigns.portfolio, file_data, filename, file_type, socket.assigns.current_user)
          end)

          {:noreply, socket}
        else
          {:noreply, put_flash(socket, :error, "Unsupported file format. Please use MP4, WebM, or MOV.")}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Invalid file upload")}
    end
  end

  @impl true
  def handle_event("cancel_recording", _params, socket) do
    IO.puts("=== CANCEL RECORDING ===")

    # Clean up any active recording
    socket = push_event(socket, "cleanup_recording", %{component_id: socket.assigns.id})

    # Notify parent to close modal
    send(self(), {:close_video_intro_modal})

    {:noreply, socket}
  end

  # ============================================================================
  # TIMER HANDLING
  # ============================================================================

  @impl true
  def handle_info({:recording_tick, component_id}, socket) do
    if socket.assigns.id == component_id && socket.assigns.recording_state == :recording do
      new_time = socket.assigns.elapsed_time + 1

      if new_time >= socket.assigns.max_duration do
        # Auto-stop at max duration
        socket =
          socket
          |> assign(:elapsed_time, socket.assigns.max_duration)
          |> push_event("stop_recording", %{component_id: socket.assigns.id})
      else
        # Continue timer
        send_recording_tick(component_id)
        socket = assign(socket, :elapsed_time, new_time)
      end

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:upload_progress, progress}, socket) do
    {:noreply, assign(socket, :upload_progress, progress)}
  end

  @impl true
  def handle_info({:upload_complete, video_section}, socket) do
    IO.puts("=== UPLOAD COMPLETE ===")

    # Notify parent of success
    send(self(), {:video_intro_complete, video_section})

    socket =
      socket
      |> assign(:recording_state, :complete)
      |> assign(:upload_progress, 100)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:upload_error, error}, socket) do
    IO.puts("=== UPLOAD ERROR: #{error} ===")

    socket =
      socket
      |> assign(:recording_state, :preview)
      |> assign(:upload_progress, 0)
      |> put_flash(:error, "Upload failed: #{error}")

    {:noreply, socket}
  end

  # ============================================================================
  # RENDER FUNCTIONS
  # ============================================================================

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-white rounded-2xl shadow-2xl overflow-hidden max-w-5xl mx-auto">
      <!-- Header -->
      <div class="bg-gradient-to-r from-purple-600 to-indigo-600 px-6 py-4">
        <div class="flex items-center justify-between">
          <div class="flex items-center">
            <div class="w-10 h-10 bg-white bg-opacity-20 rounded-xl flex items-center justify-center mr-3">
              <svg class="w-5 h-5 text-white" fill="currentColor" viewBox="0 0 20 20">
                <path d="M6.3 2.841A1.5 1.5 0 004 4.11V15.89a1.5 1.5 0 002.3 1.269l9.344-5.89a1.5 1.5 0 000-2.538L6.3 2.84z"/>
              </svg>
            </div>
            <div>
              <h3 class="text-xl font-bold text-white">Video Introduction</h3>
              <p class="text-purple-100 text-sm">
                <%= @max_duration %>s max • <%= @quality_settings.resolution %> • <%= String.capitalize(@user_tier) %> Quality
              </p>
            </div>
          </div>

          <button phx-click="cancel_recording" phx-target={@myself}
                  class="text-white hover:text-purple-200 p-2 rounded-lg hover:bg-white hover:bg-opacity-10">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </button>
        </div>
      </div>

      <!-- Main Content -->
      <div class="p-6"
           phx-hook="VideoCapture"
           id={"video-capture-#{@id}"}
           data-component-id={@id}
           data-recording-state={@recording_state}
           phx-target={@myself}>

        <!-- Mode Toggle -->
        <%= if @recording_state == :setup do %>
          <div class="flex justify-center mb-6">
            <div class="bg-gray-100 rounded-lg p-1 flex">
              <button phx-click="toggle_upload_mode" phx-target={@myself}
                      class={"px-4 py-2 rounded-md text-sm font-medium transition-colors #{if not @upload_mode, do: 'bg-white text-gray-900 shadow', else: 'text-gray-500 hover:text-gray-900'}"}>
                📹 Record Video
              </button>
              <button phx-click="toggle_upload_mode" phx-target={@myself}
                      class={"px-4 py-2 rounded-md text-sm font-medium transition-colors #{if @upload_mode, do: 'bg-white text-gray-900 shadow', else: 'text-gray-500 hover:text-gray-900'}"}>
                📁 Upload Video
              </button>
            </div>
          </div>
        <% end %>

        <%= if @upload_mode do %>
          <%= render_upload_mode(assigns) %>
        <% else %>
          <%= case @recording_state do %>
            <% :setup -> %>
              <%= render_setup_phase(assigns) %>
            <% :countdown -> %>
              <%= render_countdown_phase(assigns) %>
            <% :recording -> %>
              <%= render_recording_phase(assigns) %>
            <% :processing -> %>
              <%= render_processing_phase(assigns) %>
            <% :preview -> %>
              <%= render_preview_phase(assigns) %>
            <% :saving -> %>
              <%= render_saving_phase(assigns) %>
            <% :complete -> %>
              <%= render_complete_phase(assigns) %>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  # ============================================================================
  # RENDER PHASE FUNCTIONS
  # ============================================================================

  defp render_setup_phase(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Instructions -->
      <div class="text-center">
        <div class="w-16 h-16 mx-auto mb-4 bg-gradient-to-r from-purple-600 to-indigo-600 rounded-full flex items-center justify-center">
          <svg class="w-8 h-8 text-white" fill="currentColor" viewBox="0 0 20 20">
            <path d="M6.3 2.841A1.5 1.5 0 004 4.11V15.89a1.5 1.5 0 002.3 1.269l9.344-5.89a1.5 1.5 0 000-2.538L6.3 2.84z"/>
          </svg>
        </div>
        <h4 class="text-2xl font-bold text-gray-900 mb-3">Ready to Record?</h4>
        <p class="text-gray-600 mb-6 max-w-2xl mx-auto leading-relaxed">
          Create a compelling <%= @max_duration %>-second introduction that showcases your personality and professional story.
        </p>
      </div>

      <!-- Camera Preview -->
      <div class="relative bg-black rounded-xl overflow-hidden" style="aspect-ratio: 16/9;">
        <video id="camera-preview" autoplay muted playsinline
               class="w-full h-full object-cover" style="transform: scaleX(-1);">
        </video>

        <%= if not @camera_ready do %>
          <div class="absolute inset-0 bg-black bg-opacity-75 flex items-center justify-center">
            <div class="text-center max-w-sm">
              <%= case @camera_status do %>
                <% "initializing" -> %>
                  <div class="animate-spin w-8 h-8 border-2 border-white border-t-transparent rounded-full mx-auto mb-4"></div>
                  <p class="text-white text-lg font-semibold mb-2">Initializing Camera</p>
                  <p class="text-gray-300 text-sm">Please allow camera access when prompted</p>
                  <button phx-click="initialize_camera" phx-target={@myself}
                          class="mt-4 bg-purple-600 text-white px-4 py-2 rounded-lg hover:bg-purple-700">
                    Initialize Camera
                  </button>
                <% "requesting_permission" -> %>
                  <div class="animate-pulse w-8 h-8 bg-purple-500 rounded-full mx-auto mb-4"></div>
                  <p class="text-white text-lg font-semibold mb-2">Requesting Permission</p>
                  <p class="text-gray-300 text-sm">Please allow camera access in the browser prompt</p>
                <% "permission_denied" -> %>
                  <svg class="w-16 h-16 text-red-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728L5.636 5.636m12.728 12.728L18.364 5.636"/>
                  </svg>
                  <p class="text-white text-lg font-semibold mb-2">Camera Access Denied</p>
                  <p class="text-gray-300 text-sm mb-4">Please allow camera access and try again</p>
                  <button phx-click="initialize_camera" phx-target={@myself}
                          class="bg-purple-600 text-white px-4 py-2 rounded-lg hover:bg-purple-700">
                    Try Again
                  </button>
                <% _ -> %>
                  <svg class="w-16 h-16 text-red-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
                  </svg>
                  <p class="text-white text-lg font-semibold mb-2">Camera Error</p>
                  <p class="text-gray-300 text-sm"><%= @error_message %></p>
                  <button phx-click="initialize_camera" phx-target={@myself}
                          class="mt-4 bg-purple-600 text-white px-4 py-2 rounded-lg hover:bg-purple-700">
                    Try Again
                  </button>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Recording Tips -->
      <div class="bg-blue-50 rounded-lg p-4">
        <h5 class="font-semibold text-blue-900 mb-2">💡 Recording Tips</h5>
        <ul class="text-sm text-blue-800 space-y-1">
          <li>• Ensure good lighting on your face</li>
          <li>• Speak clearly and maintain eye contact</li>
          <li>• Keep it conversational and authentic</li>
          <li>• Mention your key skills and experience</li>
        </ul>
      </div>

      <!-- Controls -->
      <div class="flex justify-center">
        <button phx-click="start_countdown" phx-target={@myself}
                disabled={not @camera_ready}
                class={"px-8 py-4 text-lg font-semibold rounded-xl transition-all duration-200 #{if @camera_ready, do: 'bg-red-600 hover:bg-red-700 text-white shadow-lg hover:shadow-xl transform hover:scale-105', else: 'bg-gray-300 text-gray-500 cursor-not-allowed'}"}>
          <%= if @camera_ready do %>
            <svg class="w-6 h-6 inline mr-2" fill="currentColor" viewBox="0 0 20 20">
              <circle cx="10" cy="10" r="3"/>
            </svg>
            Start Recording
          <% else %>
            <svg class="w-6 h-6 inline mr-2 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
            </svg>
            Preparing Camera...
          <% end %>
        </button>
      </div>
    </div>
    """
  end

  defp render_countdown_phase(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="text-center">
        <div class="w-32 h-32 mx-auto mb-6 bg-red-600 rounded-full flex items-center justify-center">
          <span class="text-6xl font-bold text-white"><%= @countdown_value %></span>
        </div>
        <h4 class="text-2xl font-bold text-gray-900 mb-2">Get Ready!</h4>
        <p class="text-gray-600">Recording will start in <%= @countdown_value %> seconds</p>
      </div>

      <!-- Camera Preview -->
      <div class="relative bg-black rounded-xl overflow-hidden" style="aspect-ratio: 16/9;">
        <video id="camera-preview" autoplay muted playsinline
               class="w-full h-full object-cover" style="transform: scaleX(-1);">
        </video>

        <!-- Countdown Overlay -->
        <div class="absolute inset-0 bg-black bg-opacity-30 flex items-center justify-center">
          <div class="text-8xl font-bold text-white animate-ping">
            <%= @countdown_value %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp render_recording_phase(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Recording Indicator -->
      <div class="text-center">
        <div class="flex items-center justify-center mb-4">
          <div class="w-4 h-4 bg-red-600 rounded-full animate-pulse mr-3"></div>
          <span class="text-xl font-semibold text-red-600">RECORDING</span>
        </div>

        <!-- Timer -->
        <div class="text-3xl font-bold text-gray-900 mb-2">
          <%= format_time(@elapsed_time) %> / <%= format_time(@max_duration) %>
        </div>

        <!-- Progress Bar -->
        <div class="w-64 mx-auto bg-gray-200 rounded-full h-2">
          <div class="bg-red-600 h-2 rounded-full transition-all duration-1000"
               style={"width: #{(@elapsed_time / @max_duration) * 100}%"}></div>
        </div>
      </div>

      <!-- Camera Preview -->
      <div class="relative bg-black rounded-xl overflow-hidden" style="aspect-ratio: 16/9;">
        <video id="camera-preview" autoplay muted playsinline
               class="w-full h-full object-cover" style="transform: scaleX(-1);">
        </video>

        <!-- Recording Border -->
        <div class="absolute inset-0 border-4 border-red-600 rounded-xl animate-pulse"></div>
      </div>

      <!-- Stop Button -->
      <div class="flex justify-center">
        <button phx-click="stop_recording" phx-target={@myself}
                class="px-8 py-4 bg-red-600 text-white text-lg font-semibold rounded-xl hover:bg-red-700 transition-all">
          <svg class="w-6 h-6 inline mr-2" fill="currentColor" viewBox="0 0 20 20">
            <rect x="6" y="6" width="8" height="8" rx="1"/>
          </svg>
          Stop Recording
        </button>
      </div>
    </div>
    """
  end

  defp render_processing_phase(assigns) do
    ~H"""
    <div class="text-center py-12">
      <div class="w-16 h-16 mx-auto mb-6">
        <svg class="animate-spin w-16 h-16 text-purple-600" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
      </div>
      <h4 class="text-2xl font-bold text-gray-900 mb-2">Processing Video</h4>
      <p class="text-gray-600">Please wait while we process your recording...</p>
    </div>
    """
  end

  defp render_preview_phase(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="text-center">
        <h4 class="text-2xl font-bold text-gray-900 mb-2">Review Your Video</h4>
        <p class="text-gray-600">Take a look at your introduction and decide if you'd like to keep it</p>
      </div>

      <!-- Video Preview -->
      <div class="relative bg-black rounded-xl overflow-hidden" style="aspect-ratio: 16/9;">
        <video id="preview-video" controls playsinline
               class="w-full h-full object-cover">
        </video>
      </div>

      <!-- Video Info -->
      <div class="bg-gray-50 rounded-lg p-4">
        <div class="grid grid-cols-2 gap-4 text-sm">
          <div>
            <span class="font-medium text-gray-700">Duration:</span>
            <span class="text-gray-900 ml-2"><%= format_time(@video_duration || @elapsed_time) %></span>
          </div>
          <div>
            <span class="font-medium text-gray-700">Size:</span>
            <span class="text-gray-900 ml-2"><%= format_file_size(@video_size || 0) %></span>
          </div>
        </div>
      </div>

      <!-- Action Buttons -->
      <div class="flex justify-center space-x-4">
        <button phx-click="retake_video" phx-target={@myself}
                class="px-6 py-3 bg-gray-600 text-white rounded-lg hover:bg-gray-700 transition-colors">
          🔄 Retake
        </button>
        <button phx-click="save_video" phx-target={@myself}
                class="px-8 py-3 bg-green-600 text-white rounded-lg font-semibold hover:bg-green-700 transition-colors">
          ✅ Save & Use This Video
        </button>
      </div>
    </div>
    """
  end

  defp render_saving_phase(assigns) do
    ~H"""
    <div class="text-center py-12">
      <div class="w-16 h-16 mx-auto mb-6">
        <svg class="animate-spin w-16 h-16 text-green-600" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
      </div>
      <h4 class="text-2xl font-bold text-gray-900 mb-2">Saving Video</h4>
      <p class="text-gray-600 mb-6">Uploading your video introduction...</p>

      <!-- Progress Bar -->
      <div class="w-64 mx-auto bg-gray-200 rounded-full h-3 mb-4">
        <div class="bg-green-600 h-3 rounded-full transition-all duration-300"
             style={"width: #{@upload_progress}%"}></div>
      </div>
      <p class="text-sm text-gray-500"><%= @upload_progress %>% complete</p>
    </div>
    """
  end

  defp render_complete_phase(assigns) do
    ~H"""
    <div class="text-center py-12">
      <div class="w-16 h-16 mx-auto mb-6 bg-green-100 rounded-full flex items-center justify-center">
        <svg class="w-8 h-8 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
        </svg>
      </div>
      <h4 class="text-2xl font-bold text-gray-900 mb-2">Video Saved Successfully!</h4>
      <p class="text-gray-600 mb-6">Your video introduction has been added to your portfolio</p>

      <button phx-click="cancel_recording" phx-target={@myself}
              class="px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors">
        Close
      </button>
    </div>
    """
  end

  defp render_upload_mode(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="text-center">
        <div class="w-16 h-16 mx-auto mb-4 bg-gradient-to-r from-blue-600 to-purple-600 rounded-full flex items-center justify-center">
          <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/>
          </svg>
        </div>
        <h4 class="text-2xl font-bold text-gray-900 mb-3">Upload Your Video</h4>
        <p class="text-gray-600 mb-6 max-w-2xl mx-auto leading-relaxed">
          Upload a pre-recorded introduction video. Maximum duration: <%= @max_duration %> seconds.
        </p>
      </div>

      <!-- File Drop Zone -->
      <div class="border-2 border-dashed border-gray-300 rounded-xl p-12 text-center hover:border-blue-400 transition-colors"
           phx-hook="FileUpload"
           id={"file-upload-#{@id}"}
           data-component-id={@id}
           phx-target={@myself}>

        <svg class="w-12 h-12 mx-auto mb-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M9 19l3 3m0 0l3-3m-3 3V10"/>
        </svg>

        <p class="text-lg font-medium text-gray-900 mb-2">Drop your video here</p>
        <p class="text-gray-600 mb-4">or click to browse files</p>

        <button type="button"
                class="bg-blue-600 text-white px-6 py-3 rounded-lg font-medium hover:bg-blue-700 transition-colors">
          Choose Video File
        </button>

        <p class="text-sm text-gray-500 mt-4">
          Supported formats: MP4, WebM, MOV • Max size: 50MB
        </p>
      </div>

      <!-- Upload Tips -->
      <div class="bg-amber-50 rounded-lg p-4">
        <h5 class="font-semibold text-amber-900 mb-2">📁 Upload Tips</h5>
        <ul class="text-sm text-amber-800 space-y-1">
          <li>• Keep video under <%= @max_duration %> seconds for best results</li>
          <li>• MP4 format works best for compatibility</li>
          <li>• Ensure good video and audio quality</li>
          <li>• File size should be under 50MB</li>
        </ul>
      </div>
    </div>
    """
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp get_user_subscription_tier(user) do
    case user do
      %{subscription_tier: tier} when is_binary(tier) -> tier
      %{subscription_tier: tier} when is_atom(tier) -> Atom.to_string(tier)
      _ -> "personal"
    end
  end

  defp get_quality_settings_for_tier(tier) do
    case tier do
      "premium" -> %{
        resolution: "1080p",
        video_constraints: %{
          width: 1920,
          height: 1080,
          frameRate: 30
        },
        audio_constraints: %{
          sampleRate: 44100,
          channelCount: 2
        }
      }
      "professional" -> %{
        resolution: "720p",
        video_constraints: %{
          width: 1280,
          height: 720,
          frameRate: 30
        },
        audio_constraints: %{
          sampleRate: 44100,
          channelCount: 2
        }
      }
      _ -> %{
        resolution: "480p",
        video_constraints: %{
          width: 640,
          height: 480,
          frameRate: 24
        },
        audio_constraints: %{
          sampleRate: 22050,
          channelCount: 1
        }
      }
    end
  end

  defp get_existing_video_section(portfolio_id) do
    try do
      Portfolios.get_video_intro_section(portfolio_id)
    rescue
      _ -> nil
    end
  end

  defp valid_video_format?(file_type) do
    file_type in ["video/mp4", "video/webm", "video/quicktime", "video/x-msvideo"]
  end

  defp format_time(seconds) when is_integer(seconds) do
    minutes = div(seconds, 60)
    remaining_seconds = rem(seconds, 60)
    "#{minutes}:#{String.pad_leading(to_string(remaining_seconds), 2, "0")}"
  end
  defp format_time(_), do: "0:00"

  defp format_file_size(bytes) when is_integer(bytes) do
    cond do
      bytes >= 1_048_576 -> "#{Float.round(bytes / 1_048_576, 1)} MB"
      bytes >= 1_024 -> "#{Float.round(bytes / 1_024, 1)} KB"
      true -> "#{bytes} bytes"
    end
  end
  defp format_file_size(_), do: "0 bytes"

  defp send_recording_tick(component_id) do
    Process.send_after(self(), {:recording_tick, component_id}, 1000)
  end

  # ============================================================================
  # VIDEO UPLOAD AND PROCESSING
  # ============================================================================

  defp upload_video_intro(portfolio, blob_data, user) do
    try do
      # Generate filename
      timestamp = DateTime.utc_now() |> DateTime.to_unix()
      filename = "portfolio_intro_#{portfolio.id}_#{timestamp}.webm"

      # Create upload directory
      upload_dir = Path.join([Application.app_dir(:frestyl, "priv"), "static", "uploads", "videos"])
      File.mkdir_p!(upload_dir)

      # Save file
      file_path = Path.join(upload_dir, filename)
      File.write!(file_path, blob_data)

      # Create or update video intro section
      video_url = "/uploads/videos/#{filename}"

      section_attrs = %{
        portfolio_id: portfolio.id,
        section_type: :video_intro,
        title: "Video Introduction",
        content: %{
          "video_url" => video_url,
          "duration" => 60,
          "file_size" => byte_size(blob_data),
          "mime_type" => "video/webm"
        },
        visible: true,
        position: 0
      }

      case Portfolios.create_or_update_video_intro_section(section_attrs) do
        {:ok, video_section} ->
          send(self(), {:upload_complete, video_section})
        {:error, reason} ->
          send(self(), {:upload_error, reason})
      end

    rescue
      error ->
        send(self(), {:upload_error, Exception.message(error)})
    end
  end

  defp upload_video_file(portfolio, file_data, filename, file_type, user) do
    try do
      # Validate file
      if byte_size(file_data) > 50_000_000 do
        send(self(), {:upload_error, "File too large (max 50MB)"})
        {:error, "File too large"}  # Replace 'return' with proper Elixir return
      else
        # Generate safe filename
        timestamp = DateTime.utc_now() |> DateTime.to_unix()
        extension = Path.extname(filename)
        safe_filename = "portfolio_intro_#{portfolio.id}_#{timestamp}#{extension}"

        # Create upload directory
        upload_dir = Path.join([Application.app_dir(:frestyl, "priv"), "static", "uploads", "videos"])
        File.mkdir_p!(upload_dir)

        # Save file
        file_path = Path.join(upload_dir, safe_filename)
        File.write!(file_path, file_data)

        # Create video intro section
        video_url = "/uploads/videos/#{safe_filename}"

        section_attrs = %{
          portfolio_id: portfolio.id,
          section_type: :video_intro,
          title: "Video Introduction",
          content: %{
            "video_url" => video_url,
            "original_filename" => filename,
            "file_size" => byte_size(file_data),
            "mime_type" => file_type
          },
          visible: true,
          position: 0
        }

        case Portfolios.create_or_update_video_intro_section(section_attrs) do
          {:ok, video_section} ->
            send(self(), {:upload_complete, video_section})
            {:ok, video_section}  # Return success tuple
          {:error, reason} ->
            send(self(), {:upload_error, reason})
            {:error, reason}  # Return error tuple
        end
      end
    rescue
      error ->
        send(self(), {:upload_error, Exception.message(error)})
        {:error, Exception.message(error)}  # Return error tuple
    end
  end
end
