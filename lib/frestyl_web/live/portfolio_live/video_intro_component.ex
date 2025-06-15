# lib/frestyl_web/live/portfolio_live/video_intro_component.ex - COMPLETELY FIXED VERSION

defmodule FrestylWeb.PortfolioLive.VideoIntroComponent do
  use FrestylWeb, :live_component

  @impl true
  def mount(socket) do
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

    {:ok, socket}
  end

  @impl true
  def handle_event("debug_countdown_tick", _params, socket) do
    IO.puts("=== MANUAL DEBUG COUNTDOWN TICK ===")
    IO.puts("Current state: #{socket.assigns.recording_state}")
    IO.puts("Current timer: #{socket.assigns.countdown_timer}")

    # Manually trigger countdown logic
    if socket.assigns.recording_state == :countdown do
      new_timer = socket.assigns.countdown_timer - 1

      if new_timer > 0 do
        socket = assign(socket, countdown_timer: new_timer)
        {:noreply, socket}
      else
        # Start recording
        socket =
          socket
          |> assign(recording_state: :recording, elapsed_time: 0, countdown_timer: 0)
          |> push_event("start_recording", %{})

        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

    # NEW: Handle the 'countdown_update' event from the JavaScript hook
    @impl true
    def handle_event("countdown_update", %{"count" => count}, socket) do
      IO.puts("=== COUNTDOWN UPDATE IN COMPONENT: #{count} ===")

      socket = assign(socket, :countdown_value, count)

      # When countdown reaches 0, start recording
      if count == 0 do
        IO.puts("COUNTDOWN FINISHED - STARTING RECORDING")

        socket =
          socket
          |> assign(:recording_state, :recording)
          |> assign(:elapsed_time, 0)
          |> assign(:countdown_value, 0)

        # Start recording timer
        Process.send_after(self(), {:recording_tick, socket.assigns.id}, 1000)

        {:noreply, socket}
      else
        {:noreply, socket}
      end
    end

    # FIXED: Handle recording progress from JavaScript
    @impl true
    def handle_event("recording_progress", %{"elapsed" => elapsed}, socket) do
      IO.puts("=== RECORDING PROGRESS: #{elapsed}s ===")

      socket = assign(socket, :elapsed_time, elapsed)
      {:noreply, socket}
    end

    # FIXED: Handle recording errors from JavaScript
    @impl true
    def handle_event("recording_error", params, socket) do
      IO.puts("=== RECORDING ERROR IN COMPONENT ===")
      IO.inspect(params, label: "Error params")

      error_message = Map.get(params, "message", "Recording failed")

      socket =
        socket
        |> assign(:recording_state, :setup)
        |> assign(:error_message, error_message)
        |> assign(:elapsed_time, 0)

      {:noreply, socket}
    end

    # FIXED: Start countdown event
    @impl true
    def handle_event("start_countdown", _params, socket) do
      IO.puts("=== START COUNTDOWN EVENT IN COMPONENT ===")
      IO.puts("Camera ready: #{socket.assigns.camera_ready}")
      IO.puts("Camera status: #{socket.assigns.camera_status}")

      cond do
        not socket.assigns.camera_ready ->
          IO.puts("ERROR: Camera not ready")
          socket = put_flash(socket, :error, "Camera not ready. Please allow camera access.")
          {:noreply, socket}

        socket.assigns.camera_status != "ready" ->
          IO.puts("ERROR: Camera status not ready: #{socket.assigns.camera_status}")
          socket = put_flash(socket, :error, "Camera is still initializing. Please wait.")
          {:noreply, socket}

        true ->
          IO.puts("SUCCESS: Starting countdown")

          socket =
            socket
            |> assign(:recording_state, :countdown)
            |> assign(:countdown_timer, 3)
            |> assign(:countdown_value, 3)
            |> assign(:error_message, nil)

          # The JavaScript hook will handle the actual countdown
          # We just set the state here
          {:noreply, socket}
      end
    end

    # FIXED: Camera ready event
    @impl true
    def handle_event("camera_ready", params, socket) do
      IO.puts("=== CAMERA READY IN COMPONENT ===")
      IO.inspect(params, label: "Camera params")

      video_tracks = Map.get(params, "videoTracks", 0)
      audio_tracks = Map.get(params, "audioTracks", 0)

      socket =
        socket
        |> assign(:camera_ready, true)
        |> assign(:camera_status, "ready")
        |> assign(:error_message, nil)

      IO.puts("Camera ready state set in component")
      {:noreply, socket}
    end

    # FIXED: Camera error event
    @impl true
    def handle_event("camera_error", params, socket) do
      IO.puts("=== CAMERA ERROR IN COMPONENT ===")
      IO.inspect(params, label: "Error params")

      error_message = Map.get(params, "message", "Camera error")
      error_type = Map.get(params, "error", "unknown")

      camera_status = case error_type do
        "NotAllowedError" -> "permission_denied"
        "NotFoundError" -> "no_camera"
        "NotReadableError" -> "camera_busy"
        _ -> "error"
      end

      socket =
        socket
        |> assign(:camera_ready, false)
        |> assign(:camera_status, camera_status)
        |> assign(:error_message, error_message)

      {:noreply, socket}
    end

    # FIXED: Stop recording
    @impl true
    def handle_event("stop_recording", _params, socket) do
      IO.puts("=== STOP RECORDING IN COMPONENT ===")

      socket = assign(socket, :recording_state, :preview)
      {:noreply, socket}
    end

    # FIXED: Retake video
    @impl true
    def handle_event("retake_video", _params, socket) do
      IO.puts("=== RETAKE VIDEO IN COMPONENT ===")

      socket =
        socket
        |> assign(:recording_state, :setup)
        |> assign(:elapsed_time, 0)
        |> assign(:countdown_timer, 3)
        |> assign(:countdown_value, 3)
        |> assign(:recorded_blob, nil)
        |> assign(:error_message, nil)
        |> assign(:upload_progress, 0)

      {:noreply, socket}
    end

    # FIXED: Save video
  @impl true
  def handle_event("save_video", _params, socket) do
    IO.puts("=== SAVE VIDEO IN COMPONENT ===")

    socket =
      socket
      |> assign(:recording_state, :saving)
      |> assign(:upload_progress, 0)

    {:noreply, socket}
  end

    # FIXED: Cancel recording
    @impl true
    def handle_event("cancel_recording", _params, socket) do
      IO.puts("=== CANCEL RECORDING IN COMPONENT ===")

      # Send close event to parent
      send(self(), {:close_video_modal, %{}})
      {:noreply, socket}
    end

    # FIXED: Video blob ready
    @impl true
    def handle_event("video_blob_ready", params, socket) do
      IO.puts("=== VIDEO BLOB READY IN COMPONENT ===")
      IO.inspect(Map.keys(params), label: "Blob params keys")

      case params do
        %{
          "blob_data" => blob_data,
          "mime_type" => mime_type,
          "file_size" => file_size,
          "duration" => duration
        } when is_binary(blob_data) ->
          handle_video_upload(socket, blob_data, mime_type, file_size, duration)

        %{"success" => false, "error" => error} ->
          socket =
            socket
            |> assign(:recording_state, :preview)
            |> assign(:upload_progress, 0)
            |> put_flash(:error, "Upload failed: #{error}")

          {:noreply, socket}

        _ ->
          socket =
            socket
            |> assign(:recording_state, :preview)
            |> assign(:upload_progress, 0)
            |> put_flash(:error, "Invalid video data received")

          {:noreply, socket}
      end
    end

    # FIXED: Handle recording timer
    @impl true
    def handle_info({:recording_tick, component_id}, socket) do
      if socket.assigns.id == component_id and socket.assigns.recording_state == :recording do
        new_time = socket.assigns.elapsed_time + 1

        if new_time >= 60 do
          # Auto-stop at 60 seconds
          socket =
            socket
            |> assign(:recording_state, :preview)
            |> assign(:elapsed_time, 60)

          {:noreply, socket}
        else
          # Continue recording
          Process.send_after(self(), {:recording_tick, component_id}, 1000)
          socket = assign(socket, :elapsed_time, new_time)
          {:noreply, socket}
        end
      else
        {:noreply, socket}
      end
    end

    @impl true
    def update(%{video_blob_params: params}, socket) do
      IO.puts("=== UPDATE VIDEO BLOB FROM PARENT ===")

      case handle_event("video_blob_ready", params, socket) do
        {:noreply, updated_socket} -> {:ok, updated_socket}
        other -> other
      end
    end

    # Standard update function
    @impl true
    def update(assigns, socket) do
      IO.puts("=== COMPONENT UPDATE ===")
      IO.inspect(Map.keys(assigns), label: "Update keys")

      socket = assign(socket, assigns)
      {:ok, socket}
    end

  # Ignore other messages
  @impl true
  def handle_info(_, socket), do: {:noreply, socket}

  defp handle_video_blob_data(socket, params) do
    case params do
      %{
        "blob_data" => blob_data,
        "mime_type" => mime_type,
        "file_size" => file_size,
        "duration" => duration
      } when is_binary(blob_data) ->
        handle_video_upload(socket, blob_data, mime_type, file_size, duration)

      %{"success" => false, "error" => error} ->
        socket =
          socket
          |> assign(recording_state: :preview, upload_progress: 0)
          |> put_flash(:error, "Upload failed: #{error}")

        {:noreply, socket}

      _ ->
        socket =
          socket
          |> assign(recording_state: :preview, upload_progress: 0)
          |> put_flash(:error, "Invalid video data received")

        {:noreply, socket}
    end
  end

  # ADD: Debug function to check component state
  def debug_component_state(socket) do
    IO.puts("=== COMPONENT STATE DEBUG ===")
    IO.puts("Component ID: #{socket.assigns.id}")
    IO.puts("Recording State: #{socket.assigns.recording_state}")
    IO.puts("Camera Ready: #{socket.assigns.camera_ready}")
    IO.puts("Camera Status: #{socket.assigns.camera_status}")
    IO.puts("Countdown Timer: #{socket.assigns.countdown_timer}")
    IO.puts("Elapsed Time: #{socket.assigns.elapsed_time}")
    IO.puts("Self PID: #{inspect(self())}")
    IO.puts("========================")
  end

  # FIXED: Improved save video with progress tracking
  @impl true
  def handle_info({:process_video_blob, params}, socket) do
    case handle_event("video_blob_ready", params, socket) do
      {:noreply, updated_socket} -> {:noreply, updated_socket}
      other -> other
    end
  end

  # FIXED: Robust video upload handling with file validation
  defp handle_video_upload(socket, blob_data, mime_type, file_size, duration) do
    # Update progress
    socket = assign(socket, upload_progress: 25)

    case Base.decode64(blob_data) do
      {:ok, video_data} ->
        socket = assign(socket, upload_progress: 50)

        # Validate file size (max 50MB)
        max_size = 50 * 1024 * 1024

        if file_size > max_size do
          socket =
            socket
            |> assign(recording_state: :preview, upload_progress: 0)
            |> put_flash(:error, "Video file too large. Maximum size is 50MB.")

          {:noreply, socket}
        else
          # Generate filename with timestamp and proper extension
          timestamp = DateTime.utc_now() |> DateTime.to_unix()
          extension = get_file_extension(mime_type)
          filename = "portfolio_intro_#{socket.assigns.portfolio.id}_#{timestamp}#{extension}"

          socket = assign(socket, upload_progress: 75)

          case save_video_file(filename, video_data, socket.assigns.portfolio, duration) do
            {:ok, file_info} ->
              socket = assign(socket, upload_progress: 100)

              # Success! Reset component and notify parent
              socket =
                socket
                |> assign(
                  recording_state: :setup,
                  elapsed_time: 0,
                  countdown_timer: 3,
                  upload_progress: 0
                )
                |> put_flash(:info, "Video introduction saved successfully!")

              # Send completion event to parent LiveView
              send(self(), {:video_intro_complete, %{
                "media_file_id" => file_info.id,
                "file_path" => file_info.file_path,
                "filename" => filename,
                "duration" => duration
              }})

              {:noreply, socket}

            {:error, error} ->
              socket =
                socket
                |> assign(recording_state: :preview, upload_progress: 0)
                |> put_flash(:error, "Failed to save video: #{error}")

              {:noreply, socket}
          end
        end

      {:error, _decode_error} ->
        socket =
          socket
          |> assign(recording_state: :preview, upload_progress: 0)
          |> put_flash(:error, "Invalid video data. Please try recording again.")

        {:noreply, socket}
    end
  end

  # Helper to get proper file extension
  defp get_file_extension(mime_type) do
    case mime_type do
      "video/webm" -> ".webm"
      "video/mp4" -> ".mp4"
      "video/quicktime" -> ".mov"
      _ -> ".webm"  # Default fallback
    end
  end

  @impl true
  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-white rounded-xl shadow-2xl overflow-hidden max-w-4xl mx-auto">
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
              <p class="text-purple-100 text-sm">Record a 60-second introduction for "<%= @portfolio.title %>"</p>
            </div>
          </div>

          <!-- Close Button -->
          <button phx-click="cancel_recording" phx-target={@myself}
                  class="text-white hover:text-purple-200 p-2 rounded-lg hover:bg-white hover:bg-opacity-10 transition-colors"
                  aria-label="Close">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </button>
        </div>
      </div>

      <!-- Main Content with proper hook integration -->
      <div class="p-6"
           phx-hook="VideoCapture"
           id={"video-capture-#{@id}"}
           data-component-id={@id}>

        <%= case @recording_state do %>
          <% :setup -> %>
            <%= render_setup_phase(assigns) %>

          <% :countdown -> %>
            <%= render_countdown_phase(assigns) %>

          <% :recording -> %>
            <%= render_recording_phase(assigns) %>

          <% :preview -> %>
            <%= render_preview_phase(assigns) %>

          <% :saving -> %>
            <%= render_saving_phase(assigns) %>
        <% end %>
      </div>
    </div>
    """
  end

  # FIXED: Setup Phase with better status indicators
  defp render_setup_phase(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Instructions -->
      <div class="text-center">
        <div class="w-12 h-12 mx-auto mb-4 bg-gradient-to-r from-purple-600 to-indigo-600 rounded-full flex items-center justify-center">
          <svg class="w-6 h-6 text-white" fill="currentColor" viewBox="0 0 20 20">
            <path d="M6.3 2.841A1.5 1.5 0 004 4.11V15.89a1.5 1.5 0 002.3 1.269l9.344-5.89a1.5 1.5 0 000-2.538L6.3 2.84z"/>
          </svg>
        </div>
        <h4 class="text-2xl font-bold text-gray-900 mb-3">Ready to record?</h4>
        <p class="text-gray-600 mb-6 max-w-2xl mx-auto leading-relaxed">
          Create a compelling 60-second introduction that showcases your personality and professional story.
        </p>
      </div>

      <!-- Camera Preview with Status -->
      <div class="relative bg-black rounded-xl overflow-hidden" style="aspect-ratio: 16/9;">
        <video id="camera-preview"
               autoplay
               muted
               playsinline
               class="w-full h-full object-cover"
               style="transform: scaleX(-1);">
        </video>

        <!-- Camera Status Overlay -->
        <%= if not @camera_ready do %>
          <div class="absolute inset-0 bg-black bg-opacity-75 flex items-center justify-center">
            <div class="text-center max-w-sm">
              <%= case @camera_status do %>
                <% "initializing" -> %>
                  <div class="animate-spin w-8 h-8 border-2 border-white border-t-transparent rounded-full mx-auto mb-4"></div>
                  <p class="text-white text-lg font-semibold mb-2">Initializing Camera</p>
                  <p class="text-gray-300 text-sm">Please allow camera access when prompted</p>

                <% "permission_denied" -> %>
                  <svg class="w-16 h-16 text-red-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728L5.636 5.636m12.728 12.728L18.364 5.636"/>
                  </svg>
                  <p class="text-white text-lg font-semibold mb-2">Camera Access Denied</p>
                  <p class="text-gray-300 text-sm mb-4">Please allow camera access and refresh the page</p>
                  <button phx-click="retake_video" phx-target={@myself}
                          class="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700">
                    Try Again
                  </button>

                <% "no_camera" -> %>
                  <svg class="w-16 h-16 text-yellow-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
                  </svg>
                  <p class="text-white text-lg font-semibold mb-2">No Camera Found</p>
                  <p class="text-gray-300 text-sm mb-4">Please connect a camera and try again</p>
                  <button phx-click="retake_video" phx-target={@myself}
                          class="px-4 py-2 bg-yellow-600 text-white rounded-lg hover:bg-yellow-700">
                    Retry
                  </button>

                <% "camera_busy" -> %>
                  <svg class="w-16 h-16 text-orange-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.732-.833-2.5 0L4.232 15.5c-.77.833.192 2.5 1.732 2.5z"/>
                  </svg>
                  <p class="text-white text-lg font-semibold mb-2">Camera In Use</p>
                  <p class="text-gray-300 text-sm mb-4">Camera is being used by another application</p>
                  <button phx-click="retake_video" phx-target={@myself}
                          class="px-4 py-2 bg-orange-600 text-white rounded-lg hover:bg-orange-700">
                    Try Again
                  </button>

                <% _ -> %>
                  <svg class="w-16 h-16 text-red-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
                  </svg>
                  <p class="text-white text-lg font-semibold mb-2">Camera Error</p>
                  <p class="text-gray-300 text-sm mb-4"><%= @error_message || "Unknown camera error" %></p>
                  <button phx-click="retake_video" phx-target={@myself}
                          class="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700">
                    Try Again
                  </button>
              <% end %>
            </div>
          </div>
        <% end %>

        <!-- Camera Ready Indicator -->
        <%= if @camera_ready do %>
          <div class="absolute top-4 right-4 flex items-center bg-green-500 bg-opacity-90 rounded-full px-3 py-1">
            <div class="w-2 h-2 bg-white rounded-full mr-2"></div>
            <span class="text-white text-sm font-medium">Camera Ready</span>
          </div>
        <% end %>
      </div>

      <!-- Controls -->
      <div class="flex justify-center space-x-4">
        <button phx-click="start_countdown"
                phx-target={@myself}
                disabled={not @camera_ready}
                class="px-8 py-4 bg-gradient-to-r from-red-600 to-pink-600 text-white font-bold rounded-xl hover:from-red-700 hover:to-pink-700 transition-all disabled:opacity-50 disabled:cursor-not-allowed flex items-center shadow-lg">
          <svg class="w-5 h-5 mr-2" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM9.555 7.168A1 1 0 008 8v4a1 1 0 001.555.832l3-2a1 1 0 000-1.664l-3-2z" clip-rule="evenodd"/>
          </svg>
          Start Recording
        </button>

        <button phx-click="cancel_recording" phx-target={@myself}
                class="px-8 py-4 bg-gray-100 text-gray-700 font-bold rounded-xl hover:bg-gray-200 transition-all flex items-center shadow-lg">
          <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
          </svg>
          Cancel
        </button>
      </div>
    </div>
    """
  end

  # FIXED: Countdown Phase with debug info
  defp render_countdown_phase(assigns) do
    ~H"""
    <div class="text-center">
      <div class="relative bg-black rounded-xl overflow-hidden" style="aspect-ratio: 16/9;">
        <video id="camera-preview"
              autoplay
              muted
              playsinline
              class="w-full h-full object-cover"
              style="transform: scaleX(-1);">
        </video>

        <div class="absolute inset-0 bg-black bg-opacity-60 flex items-center justify-center">
          <div class="text-center">
            <div class="text-9xl font-black text-white mb-6 animate-pulse drop-shadow-2xl">
              <%= @countdown_value %>
            </div>
            <p class="text-white text-2xl font-semibold mb-4">Get ready to record...</p>
            <div class="flex justify-center">
              <div class="animate-spin w-6 h-6 border-2 border-white border-t-transparent rounded-full"></div>
            </div>
          </div>
        </div>
      </div>

      <!-- Cancel option during countdown -->
      <div class="mt-6">
        <button phx-click="cancel_recording" phx-target={@myself}
                class="px-6 py-3 bg-gray-600 text-white rounded-lg hover:bg-gray-700 transition-colors">
          Cancel Recording
        </button>
      </div>
    </div>
    """
  end

  # FIXED: Recording Phase with enhanced UI
  defp render_recording_phase(assigns) do
    ~H"""
    <div class="text-center">
      <div class="relative bg-black rounded-xl overflow-hidden" style="aspect-ratio: 16/9;">
        <video id="camera-preview"
               autoplay
               muted
               playsinline
               class="w-full h-full object-cover"
               style="transform: scaleX(-1);">
        </video>

        <!-- Recording Indicator -->
        <div class="absolute top-4 left-4 flex items-center bg-red-600 rounded-full px-4 py-2 shadow-lg">
          <div class="w-3 h-3 bg-white rounded-full mr-2 animate-pulse"></div>
          <span class="text-white font-bold text-sm">RECORDING</span>
        </div>

        <!-- Timer Display -->
        <div class="absolute top-4 right-4 bg-black bg-opacity-70 rounded-full px-4 py-2">
          <span class="text-white font-mono font-bold text-lg">
            <%= format_time(@elapsed_time) %> / 1:00
          </span>
        </div>

        <!-- Progress Bar -->
        <div class="absolute bottom-0 left-0 right-0 bg-black bg-opacity-40">
          <div class="h-2 bg-gradient-to-r from-red-600 to-pink-600 transition-all duration-1000"
               style={"width: #{(@elapsed_time / 60) * 100}%"}></div>
        </div>

        <!-- Recording Instructions -->
        <div class="absolute bottom-4 left-4 right-4">
          <div class="bg-black bg-opacity-70 rounded-lg p-3">
            <p class="text-white text-sm text-center">
              <%= cond do %>
                <% @elapsed_time < 10 -> %>
                  👋 Introduce yourself and your background
                <% @elapsed_time < 30 -> %>
                  💼 Share your professional expertise
                <% @elapsed_time < 50 -> %>
                  🎯 Mention your goals and interests
                <% true -> %>
                  ✨ Wrap up with a call to action
              <% end %>
            </p>
          </div>
        </div>
      </div>

      <!-- Stop Recording Button -->
      <div class="mt-6">
        <button phx-click="stop_recording"
                phx-target={@myself}
                class="px-8 py-4 bg-gradient-to-r from-gray-600 to-gray-800 text-white font-bold rounded-xl hover:from-gray-700 hover:to-gray-900 transition-all flex items-center mx-auto shadow-lg">
          <svg class="w-5 h-5 mr-2" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8 7a1 1 0 012 0v6a1 1 0 11-2 0V7zm4 0a1 1 0 012 0v6a1 1 0 11-2 0V7z" clip-rule="evenodd"/>
          </svg>
          Stop Recording
        </button>
      </div>
    </div>
    """
  end

  # FIXED: Preview Phase with better playback controls
  defp render_preview_phase(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="text-center">
        <h4 class="text-2xl font-bold text-gray-900 mb-3">Review Your Introduction</h4>
        <p class="text-gray-600 mb-6">Watch your recording and decide if you'd like to save it or record again</p>
      </div>

      <div class="relative bg-black rounded-xl overflow-hidden" style="aspect-ratio: 16/9;">
        <video id="playback-video"
               controls
               playsinline
               class="w-full h-full object-cover">
        </video>

        <div id="video-loading" class="absolute inset-0 flex items-center justify-center text-white bg-black bg-opacity-75">
          <div class="text-center">
            <div class="animate-spin w-12 h-12 border-2 border-white border-t-transparent rounded-full mx-auto mb-4"></div>
            <p class="text-lg font-semibold">Loading preview...</p>
            <p class="text-sm text-gray-300 mt-2">Processing your recording</p>
          </div>
        </div>

        <!-- Video Info Overlay -->
        <div class="absolute bottom-4 left-4 right-4">
          <div class="bg-black bg-opacity-70 rounded-lg p-3">
            <div class="flex items-center justify-between text-white text-sm">
              <span>Duration: <%= format_time(@elapsed_time) %></span>
              <span>Ready to save</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Action Buttons -->
      <div class="flex flex-col sm:flex-row justify-center gap-4">
        <button phx-click="retake_video"
                phx-target={@myself}
                class="px-6 py-3 border-2 border-gray-300 rounded-xl text-gray-700 font-semibold hover:bg-gray-50 transition-all flex items-center justify-center">
          <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
          </svg>
          Record Again
        </button>

        <button phx-click="save_video"
                phx-target={@myself}
                class="px-8 py-3 bg-gradient-to-r from-green-600 to-emerald-600 text-white font-bold rounded-xl hover:from-green-700 hover:to-emerald-700 transition-all flex items-center justify-center shadow-lg">
          <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
          </svg>
          Save Introduction
        </button>

        <button phx-click="cancel_recording" phx-target={@myself}
                class="px-6 py-3 bg-gray-600 text-white rounded-xl hover:bg-gray-700 transition-all flex items-center justify-center">
          <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
          </svg>
          Cancel
        </button>
      </div>
    </div>
    """
  end

  # FIXED: Saving Phase with progress indicator
  defp render_saving_phase(assigns) do
    ~H"""
    <div class="text-center py-12">
      <div class="max-w-md mx-auto">
        <!-- Animated Icon -->
        <div class="w-20 h-20 mx-auto mb-6 bg-gradient-to-r from-purple-600 to-indigo-600 rounded-full flex items-center justify-center">
          <svg class="w-10 h-10 text-white animate-bounce" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/>
          </svg>
        </div>

        <h4 class="text-2xl font-bold text-gray-900 mb-4">Saving Your Video</h4>
        <p class="text-gray-600 mb-8">Processing and saving your introduction to your portfolio...</p>

        <!-- Progress Bar -->
        <div class="w-full bg-gray-200 rounded-full h-3 mb-4">
          <div class="bg-gradient-to-r from-purple-600 to-indigo-600 h-3 rounded-full transition-all duration-500"
               style={"width: #{@upload_progress}%"}></div>
        </div>

        <!-- Progress Text -->
        <p class="text-sm text-gray-500">
          <%= cond do %>
            <% @upload_progress < 25 -> %>
              Preparing video data...
            <% @upload_progress < 50 -> %>
              Validating file...
            <% @upload_progress < 75 -> %>
              Uploading to server...
            <% @upload_progress < 100 -> %>
              Finalizing...
            <% true -> %>
              Complete!
          <% end %>
          (<%= @upload_progress %>%)
        </p>
      </div>
    </div>
    """
  end

    defp format_time(seconds) do
    minutes = div(seconds, 60)
    secs = rem(seconds, 60)
    "#{minutes}:#{String.pad_leading(Integer.to_string(secs), 2, "0")}"
  end

  # Add all the video processing helper functions here
  defp handle_video_upload(socket, blob_data, mime_type, file_size, duration) do
    # Progress tracking
    socket = assign(socket, upload_progress: 10)

    with {:ok, video_data} <- decode_video_data(blob_data),
        {:ok, _} <- validate_video_file(mime_type, file_size, video_data),
        {:ok, filename} <- generate_secure_filename(mime_type, socket.assigns.portfolio.id),
        socket <- assign(socket, upload_progress: 60),
        {:ok, file_info} <- save_video_safely(filename, video_data, socket.assigns.portfolio, duration),
        socket <- assign(socket, upload_progress: 100) do

      # Success flow
      socket = socket
        |> assign(recording_state: :setup, upload_progress: 0)
        |> put_flash(:info, "Video introduction saved successfully!")

      # Notify parent component
      send(self(), {:video_intro_complete, file_info})
      {:noreply, socket}
    else
      {:error, reason} ->
        socket = socket
          |> assign(recording_state: :preview, upload_progress: 0)
          |> put_flash(:error, get_user_friendly_error(reason))

        {:noreply, socket}
    end
  end

  # Add other helper functions you need here...
  defp decode_video_data(blob_data) do
    case Base.decode64(blob_data) do
      {:ok, data} when byte_size(data) > 0 -> {:ok, data}
      {:ok, _} -> {:error, "Empty video file"}
      :error -> {:error, "Invalid video data format"}
    end
  end

  defp validate_video_file(mime_type, file_size, video_data) do
    allowed_types = ["video/webm", "video/mp4", "video/quicktime"]
    max_size = 50 * 1024 * 1024  # 50MB

    cond do
      mime_type not in allowed_types ->
        {:error, "unsupported_format"}
      file_size > max_size ->
        {:error, "file_too_large"}
      byte_size(video_data) != file_size ->
        {:error, "file_corruption"}
      byte_size(video_data) < 1000 ->
        {:error, "file_too_small"}
      true ->
        {:ok, :valid}
    end
  end

  defp generate_secure_filename(mime_type, portfolio_id) do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    random_suffix = :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
    extension = get_secure_extension(mime_type)
    filename = "portfolio_intro_#{portfolio_id}_#{timestamp}_#{random_suffix}#{extension}"
    {:ok, filename}
  end

  defp get_secure_extension(mime_type) do
    case mime_type do
      "video/webm" -> ".webm"
      "video/mp4" -> ".mp4"
      "video/quicktime" -> ".mov"
      _ -> ".webm"
    end
  end

  defp save_video_safely(filename, video_data, portfolio, duration) do
    upload_dir = ensure_upload_directory()
    temp_path = Path.join(upload_dir, "temp_#{filename}")
    final_path = Path.join(upload_dir, filename)

    try do
      case File.write(temp_path, video_data) do
        :ok ->
          case File.rename(temp_path, final_path) do
            :ok ->
              public_path = "/uploads/videos/#{filename}"
              create_portfolio_video_section(portfolio, public_path, filename, duration)
            {:error, reason} ->
              File.rm(temp_path)
              {:error, "File save failed: #{reason}"}
          end
        {:error, reason} ->
          {:error, "Write failed: #{reason}"}
      end
    rescue
      error ->
        File.rm(temp_path)
        {:error, "Save operation failed: #{Exception.message(error)}"}
    end
  end

  defp ensure_upload_directory() do
    upload_dir = Path.join([
      Application.app_dir(:frestyl, "priv"),
      "static",
      "uploads",
      "videos"
    ])

    case File.mkdir_p(upload_dir) do
      :ok -> upload_dir
      {:error, reason} ->
        raise "Cannot create upload directory: #{reason}"
    end
  end

  defp get_user_friendly_error(error_reason) do
    case error_reason do
      "unsupported_format" ->
        "Video format not supported. Please use WebM, MP4, or MOV format."
      "file_too_large" ->
        "Video file is too large. Maximum size is 50MB. Try recording a shorter video."
      "file_corruption" ->
        "Video file appears to be corrupted. Please try recording again."
      "file_too_small" ->
        "Video file is too small. Please ensure you recorded a proper video."
      _ ->
        "Failed to save video. Please try recording again."
    end
  end

  defp create_portfolio_video_section(portfolio, video_path, filename, duration) do
    try do
      existing_sections = Frestyl.Portfolios.list_portfolio_sections(portfolio.id)

      video_section = Enum.find(existing_sections, fn section ->
        section.title == "Video Introduction" or
        (section.content && Map.get(section.content, "video_type") == "introduction")
      end)

      section_attrs = build_video_section_attrs(portfolio, video_path, filename, duration)

      case video_section do
        nil ->
          increment_existing_positions(portfolio.id)
          section_attrs = Map.put(section_attrs, :position, 1)

          case Frestyl.Portfolios.create_section(section_attrs) do
            {:ok, section} ->
              {:ok, %{
                id: section.id,
                portfolio_id: portfolio.id,
                file_path: video_path,
                filename: filename,
                duration: duration
              }}
            {:error, changeset} ->
              {:error, "Section creation failed: #{inspect(changeset.errors)}"}
          end

        existing_section ->
          updated_content = Map.merge(existing_section.content || %{}, section_attrs.content)

          case Frestyl.Portfolios.update_section(existing_section, %{content: updated_content}) do
            {:ok, section} ->
              {:ok, %{
                id: section.id,
                portfolio_id: portfolio.id,
                file_path: video_path,
                filename: filename,
                duration: duration
              }}
            {:error, changeset} ->
              {:error, "Section update failed: #{inspect(changeset.errors)}"}
          end
      end
    rescue
      error ->
        {:error, "Database operation failed: #{Exception.message(error)}"}
    end
  end

  defp build_video_section_attrs(portfolio, video_path, filename, duration) do
    %{
      portfolio_id: portfolio.id,
      title: "Video Introduction",
      section_type: :media_showcase,
      content: %{
        "title" => "Personal Introduction",
        "description" => "A personal video introduction showcasing my background and expertise.",
        "video_url" => video_path,
        "video_filename" => filename,
        "video_type" => "introduction",
        "duration" => duration,
        "auto_play" => false,
        "show_controls" => true,
        "thumbnail_generated" => false,
        "created_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "file_size" => nil
      },
      visible: true
    }
  end

  defp increment_existing_positions(portfolio_id) do
    try do
      sections = Frestyl.Portfolios.list_portfolio_sections(portfolio_id)

      Enum.each(sections, fn section ->
        Frestyl.Portfolios.update_section(section, %{position: section.position + 1})
      end)
    rescue
      error ->
        IO.puts("Warning: Could not increment section positions: #{Exception.message(error)}")
    end
  end

  # FIXED: Helper function to save video file with better error handling
  defp save_video_file(filename, binary_data, portfolio, duration) do
    try do
      # Ensure upload directory exists
      upload_dir = Path.join([Application.app_dir(:frestyl, "priv"), "static", "uploads", "videos"])

      case File.mkdir_p(upload_dir) do
        :ok ->
          # Save file to uploads directory
          file_path = Path.join(upload_dir, filename)

          case File.write(file_path, binary_data) do
            :ok ->
              # Create public path for serving
              public_path = "/uploads/videos/#{filename}"

              # Get file size
              file_size = byte_size(binary_data)

              # Create or update video intro section in portfolio
              case create_or_update_video_intro_section(portfolio, public_path, filename, duration) do
                {:ok, section} ->
                  {:ok, %{
                    id: section.id,
                    file_path: public_path,
                    filename: filename,
                    portfolio_id: portfolio.id,
                    section_id: section.id,
                    file_size: file_size,
                    duration: duration
                  }}

                {:error, reason} ->
                  # File was saved but section creation failed - clean up
                  File.rm(file_path)
                  {:error, "Failed to create portfolio section: #{inspect(reason)}"}
              end

            {:error, reason} ->
              {:error, "File write failed: #{inspect(reason)}"}
          end

        {:error, reason} ->
          {:error, "Directory creation failed: #{inspect(reason)}"}
      end

    rescue
      error ->
        {:error, "Upload failed: #{Exception.message(error)}"}
    end
  end

  # FIXED: Enhanced section creation with better metadata
  defp create_or_update_video_intro_section(portfolio, video_path, filename, duration) do
    # Check if there's already a video intro section
    existing_sections = Frestyl.Portfolios.list_portfolio_sections(portfolio.id)

    video_intro_section = Enum.find(existing_sections, fn section ->
      section.title == "Video Introduction" ||
      (section.content && Map.get(section.content, "video_type") == "introduction")
    end)

    section_attrs = %{
      portfolio_id: portfolio.id,
      title: "Video Introduction",
      section_type: :media_showcase,
      content: %{
        "title" => "Personal Introduction",
        "description" => "A brief video introduction showcasing my personality and professional background.",
        "video_url" => video_path,
        "video_filename" => filename,
        "video_type" => "introduction",
        "duration" => duration,
        "auto_play" => false,
        "show_controls" => true,
        "created_at" => DateTime.utc_now() |> DateTime.to_iso8601()
      },
      visible: true
    }

    case video_intro_section do
      nil ->
        # Create new section at the top (position 1)
        # First, increment position of all existing sections
        increment_section_positions(portfolio.id)

        # Create new section at position 1
        section_attrs = Map.put(section_attrs, :position, 1)
        Frestyl.Portfolios.create_section(section_attrs)

      existing_section ->
        # Update existing section with new video
        updated_content = Map.merge(existing_section.content || %{}, section_attrs.content)
        Frestyl.Portfolios.update_section(existing_section, %{content: updated_content})
    end
  end

  # Helper to increment positions of existing sections
  defp increment_section_positions(portfolio_id) do
    sections = Frestyl.Portfolios.list_portfolio_sections(portfolio_id)

    Enum.each(sections, fn section ->
      Frestyl.Portfolios.update_section(section, %{position: section.position + 1})
    end)
  end

  # Helper function to format recording time
  defp format_time(seconds) do
    minutes = div(seconds, 60)
    secs = rem(seconds, 60)
    "#{minutes}:#{String.pad_leading(Integer.to_string(secs), 2, "0")}"
  end

  defp handle_video_upload(socket, blob_data, mime_type, file_size, duration) do
    # Progress tracking
    socket = assign(socket, upload_progress: 10)

    with {:ok, video_data} <- decode_video_data(blob_data),
        {:ok, _} <- validate_video_file(mime_type, file_size, video_data),
        {:ok, filename} <- generate_secure_filename(mime_type, socket.assigns.portfolio.id),
        socket <- assign(socket, upload_progress: 60),
        {:ok, file_info} <- save_video_safely(filename, video_data, socket.assigns.portfolio, duration),
        socket <- assign(socket, upload_progress: 100) do

      # Success flow
      socket = socket
        |> assign(recording_state: :setup, upload_progress: 0)
        |> put_flash(:info, "Video introduction saved successfully!")

      # Notify parent component
      send(self(), {:video_intro_complete, file_info})
      {:noreply, socket}
    else
      {:error, reason} ->
        socket = socket
          |> assign(recording_state: :preview, upload_progress: 0)
          |> put_flash(:error, get_user_friendly_error(reason))

        {:noreply, socket}
    end
  end

  # ENHANCED: Secure video data decoding
  defp decode_video_data(blob_data) do
    case Base.decode64(blob_data) do
      {:ok, data} when byte_size(data) > 0 -> {:ok, data}
      {:ok, _} -> {:error, "Empty video file"}
      :error -> {:error, "Invalid video data format"}
    end
  end

  # ENHANCED: Comprehensive video validation
  defp validate_video_file(mime_type, file_size, video_data) do
    allowed_types = ["video/webm", "video/mp4", "video/quicktime"]
    max_size = 50 * 1024 * 1024  # 50MB

    cond do
      mime_type not in allowed_types ->
        {:error, "unsupported_format"}

      file_size > max_size ->
        {:error, "file_too_large"}

      byte_size(video_data) != file_size ->
        {:error, "file_corruption"}

      byte_size(video_data) < 1000 ->  # Less than 1KB is suspicious
        {:error, "file_too_small"}

      true ->
        {:ok, :valid}
    end
  end

  # ENHANCED: Secure filename generation
  defp generate_secure_filename(mime_type, portfolio_id) do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    random_suffix = :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
    extension = get_secure_extension(mime_type)

    # Ensure filename is safe and unique
    filename = "portfolio_intro_#{portfolio_id}_#{timestamp}_#{random_suffix}#{extension}"
    {:ok, filename}
  end

  defp get_secure_extension(mime_type) do
    case mime_type do
      "video/webm" -> ".webm"
      "video/mp4" -> ".mp4"
      "video/quicktime" -> ".mov"
      _ -> ".webm"  # Safe default
    end
  end

  def handle_event("save_video", _params, socket) do
    IO.puts("=== SAVE VIDEO IN COMPONENT ===")

    socket =
      socket
      |> assign(:recording_state, :saving)
      |> assign(:upload_progress, 0)

    {:noreply, socket}
  end

  # ENHANCED: Safe file operations with atomic writes
  defp save_video_safely(filename, video_data, portfolio, duration) do
    upload_dir = ensure_upload_directory()
    temp_path = Path.join(upload_dir, "temp_#{filename}")
    final_path = Path.join(upload_dir, filename)

    try do
      # Atomic write: write to temp file first, then rename
      case File.write(temp_path, video_data) do
        :ok ->
          case File.rename(temp_path, final_path) do
            :ok ->
              public_path = "/uploads/videos/#{filename}"
              create_portfolio_video_section(portfolio, public_path, filename, duration)

            {:error, reason} ->
              File.rm(temp_path)  # Cleanup
              {:error, "File save failed: #{reason}"}
          end

        {:error, reason} ->
          {:error, "Write failed: #{reason}"}
      end
    rescue
      error ->
        # Cleanup on any error
        File.rm(temp_path)
        {:error, "Save operation failed: #{Exception.message(error)}"}
    end
  end

  defp ensure_upload_directory() do
    upload_dir = Path.join([
      Application.app_dir(:frestyl, "priv"),
      "static",
      "uploads",
      "videos"
    ])

    case File.mkdir_p(upload_dir) do
      :ok -> upload_dir
      {:error, reason} ->
        raise "Cannot create upload directory: #{reason}"
    end
  end

  # ENHANCED: Better error messages for users
  defp get_user_friendly_error(error_reason) do
    case error_reason do
      "unsupported_format" ->
        "Video format not supported. Please use WebM, MP4, or MOV format."

      "file_too_large" ->
        "Video file is too large. Maximum size is 50MB. Try recording a shorter video."

      "file_corruption" ->
        "Video file appears to be corrupted. Please try recording again."

      "file_too_small" ->
        "Video file is too small. Please ensure you recorded a proper video."

      "Write failed: " <> reason ->
        "Failed to save video: #{reason}. Please try again."

      "File save failed: " <> reason ->
        "Could not save video file: #{reason}. Please try again."

      _ ->
        "Failed to save video. Please try recording again."
    end
  end

  # ENHANCED: Better portfolio section creation
  defp create_portfolio_video_section(portfolio, video_path, filename, duration) do
    try do
      # Get existing sections to determine position
      existing_sections = Frestyl.Portfolios.list_portfolio_sections(portfolio.id)

      # Check for existing video intro section
      video_section = Enum.find(existing_sections, fn section ->
        section.title == "Video Introduction" or
        (section.content && Map.get(section.content, "video_type") == "introduction")
      end)

      section_attrs = build_video_section_attrs(portfolio, video_path, filename, duration)

      case video_section do
        nil ->
          # Create new section at the top
          increment_existing_positions(portfolio.id)
          section_attrs = Map.put(section_attrs, :position, 1)

          case Frestyl.Portfolios.create_section(section_attrs) do
            {:ok, section} ->
              {:ok, %{
                id: section.id,
                portfolio_id: portfolio.id,
                file_path: video_path,
                filename: filename,
                duration: duration
              }}
            {:error, changeset} ->
              {:error, "Section creation failed: #{inspect(changeset.errors)}"}
          end

        existing_section ->
          # Update existing section
          updated_content = Map.merge(existing_section.content || %{}, section_attrs.content)

          case Frestyl.Portfolios.update_section(existing_section, %{content: updated_content}) do
            {:ok, section} ->
              {:ok, %{
                id: section.id,
                portfolio_id: portfolio.id,
                file_path: video_path,
                filename: filename,
                duration: duration
              }}
            {:error, changeset} ->
              {:error, "Section update failed: #{inspect(changeset.errors)}"}
          end
      end
    rescue
      error ->
        {:error, "Database operation failed: #{Exception.message(error)}"}
    end
  end

  defp build_video_section_attrs(portfolio, video_path, filename, duration) do
    %{
      portfolio_id: portfolio.id,
      title: "Video Introduction",
      section_type: :media_showcase,
      content: %{
        "title" => "Personal Introduction",
        "description" => "A personal video introduction showcasing my background and expertise.",
        "video_url" => video_path,
        "video_filename" => filename,
        "video_type" => "introduction",
        "duration" => duration,
        "auto_play" => false,
        "show_controls" => true,
        "thumbnail_generated" => false,
        "created_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "file_size" => nil  # Will be set if needed
      },
      visible: true
    }
  end

  defp increment_existing_positions(portfolio_id) do
    try do
      sections = Frestyl.Portfolios.list_portfolio_sections(portfolio_id)

      Enum.each(sections, fn section ->
        Frestyl.Portfolios.update_section(section, %{position: section.position + 1})
      end)
    rescue
      error ->
        # Log error but don't fail the entire operation
        IO.puts("Warning: Could not increment section positions: #{Exception.message(error)}")
    end
  end
end
