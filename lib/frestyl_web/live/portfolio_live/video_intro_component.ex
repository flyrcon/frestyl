# lib/frestyl_web/live/portfolio_live/video_intro_component.ex
defmodule FrestylWeb.PortfolioLive.VideoIntroComponent do
  use FrestylWeb, :live_component

  alias Frestyl.Media

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-white" phx-hook="VideoCapture" id={"video-capture-#{@id}"}>
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
              <h3 class="text-xl font-black text-white">Video Introduction</h3>
              <p class="text-purple-100 text-sm">Record a 60-second introduction for "<%= @portfolio.title %>"</p>
            </div>
          </div>
          <button phx-click={@on_cancel} phx-target={@myself} class="text-white hover:text-purple-200">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </button>
        </div>
      </div>

      <!-- Main Content -->
      <!-- FIXED HEEx Template Case Statement -->
      <!-- Replace your existing case statement with this corrected version -->

      <div class="p-6">
        <%= case @recording_state do %>
          <% :setup -> %>
            <!-- Setup Phase -->
            <div class="text-center mb-8">
              <div class="w-24 h-24 mx-auto mb-6 bg-gradient-to-r from-purple-600 to-indigo-600 rounded-full flex items-center justify-center">
                <svg class="w-12 h-12 text-white" fill="currentColor" viewBox="0 0 20 20">
                  <path d="M6.3 2.841A1.5 1.5 0 004 4.11V15.89a1.5 1.5 0 002.3 1.269l9.344-5.89a1.5 1.5 0 000-2.538L6.3 2.84z"/>
                </svg>
              </div>
              <h4 class="text-2xl font-black text-gray-900 mb-4">Ready to record?</h4>
              <p class="text-gray-600 mb-8 max-w-2xl mx-auto leading-relaxed">
                Create a compelling 60-second introduction that showcases your personality and professional story.
                This video will be the first thing visitors see on your portfolio.
              </p>
            </div>

            <!-- Tips -->
            <div class="bg-gray-50 rounded-xl p-6 mb-8">
              <h5 class="font-bold text-gray-900 mb-4 flex items-center">
                <svg class="w-5 h-5 mr-2 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"/>
                </svg>
                Recording Tips
              </h5>
              <div class="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
                <div class="flex items-start">
                  <div class="w-2 h-2 bg-purple-600 rounded-full mt-2 mr-3 flex-shrink-0"></div>
                  <span class="text-gray-700">Introduce yourself and your profession</span>
                </div>
                <div class="flex items-start">
                  <div class="w-2 h-2 bg-purple-600 rounded-full mt-2 mr-3 flex-shrink-0"></div>
                  <span class="text-gray-700">Mention 2-3 key skills or achievements</span>
                </div>
                <div class="flex items-start">
                  <div class="w-2 h-2 bg-purple-600 rounded-full mt-2 mr-3 flex-shrink-0"></div>
                  <span class="text-gray-700">Keep good eye contact with the camera</span>
                </div>
                <div class="flex items-start">
                  <div class="w-2 h-2 bg-purple-600 rounded-full mt-2 mr-3 flex-shrink-0"></div>
                  <span class="text-gray-700">Speak clearly and at a comfortable pace</span>
                </div>
              </div>
            </div>

            <!-- Camera Preview -->
            <div class="bg-black rounded-xl aspect-video mb-6 flex items-center justify-center relative overflow-hidden">
              <video id="camera-preview"
                    autoplay
                    muted
                    playsinline
                    class="w-full h-full object-cover">
              </video>

              <%= if not @camera_ready do %>
                <div class="absolute inset-0 bg-black bg-opacity-50 flex items-center justify-center">
                  <div class="text-center">
                    <div class="animate-spin w-8 h-8 border-2 border-white border-t-transparent rounded-full mx-auto mb-4"></div>
                    <p class="text-white">Accessing camera...</p>
                  </div>
                </div>
              <% end %>
            </div>

            <!-- Controls -->
            <div class="flex justify-center space-x-4">
              <button phx-click="start_countdown"
                      phx-target={@myself}
                      disabled={not @camera_ready}
                      class="px-8 py-4 bg-gradient-to-r from-red-600 to-pink-600 text-white font-bold rounded-xl hover:from-red-700 hover:to-pink-700 transition-all disabled:opacity-50 disabled:cursor-not-allowed flex items-center">
                <svg class="w-5 h-5 mr-2" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM9.555 7.168A1 1 0 008 8v4a1 1 0 001.555.832l3-2a1 1 0 000-1.664l-3-2z" clip-rule="evenodd"/>
                </svg>
                Start Recording
              </button>
            </div>

          <% :countdown -> %>
            <!-- Countdown Phase -->
            <div class="text-center">
              <div class="bg-black rounded-xl aspect-video mb-6 flex items-center justify-center relative overflow-hidden">
                <video id="camera-preview"
                      autoplay
                      muted
                      playsinline
                      class="w-full h-full object-cover">
                </video>

                <div class="absolute inset-0 bg-black bg-opacity-50 flex items-center justify-center">
                  <div class="text-center">
                    <div class="text-8xl font-black text-white mb-4 animate-pulse">
                      <%= @countdown_timer %>
                    </div>
                    <p class="text-white text-xl">Get ready...</p>
                  </div>
                </div>

                <!-- Debug overlay -->
                <div class="absolute top-4 left-4 bg-black bg-opacity-60 rounded px-3 py-2 text-white text-sm font-mono">
                  State: <%= @recording_state %> | Timer: <%= @countdown_timer %>
                </div>
              </div>
            </div>

          <% :recording -> %>
            <!-- Recording Phase -->
            <div class="text-center">
              <div class="bg-black rounded-xl aspect-video mb-6 flex items-center justify-center relative overflow-hidden">
                <video id="camera-preview"
                      autoplay
                      muted
                      playsinline
                      class="w-full h-full object-cover">
                </video>

                <!-- Recording Indicator -->
                <div class="absolute top-4 left-4 flex items-center bg-red-600 rounded-full px-3 py-2">
                  <div class="w-3 h-3 bg-white rounded-full mr-2 animate-pulse"></div>
                  <span class="text-white font-bold text-sm">REC</span>
                </div>

                <!-- Timer -->
                <div class="absolute top-4 right-4 bg-black bg-opacity-60 rounded-full px-4 py-2">
                  <span class="text-white font-mono font-bold">
                    <%= format_time(@elapsed_time) %> / 1:00
                  </span>
                </div>

                <!-- Progress Bar -->
                <div class="absolute bottom-0 left-0 right-0 bg-black bg-opacity-30">
                  <div class="h-1 bg-gradient-to-r from-red-600 to-pink-600"
                      style={"width: #{(@elapsed_time / 60) * 100}%"}></div>
                </div>

                <!-- Time Warning -->
                <%= if @elapsed_time > 50 do %>
                  <div class="absolute bottom-4 left-1/2 transform -translate-x-1/2 bg-yellow-500 text-black px-4 py-2 rounded-full font-bold text-sm animate-bounce">
                    <%= 60 - @elapsed_time %> seconds left!
                  </div>
                <% end %>
              </div>

              <!-- Stop Recording Button -->
              <button phx-click="stop_recording"
                      phx-target={@myself}
                      class="px-8 py-4 bg-gradient-to-r from-gray-600 to-gray-800 text-white font-bold rounded-xl hover:from-gray-700 hover:to-gray-900 transition-all flex items-center mx-auto">
                <svg class="w-5 h-5 mr-2" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8 7a1 1 0 012 0v6a1 1 0 11-2 0V7zm4 0a1 1 0 012 0v6a1 1 0 11-2 0V7z" clip-rule="evenodd"/>
                </svg>
                Stop Recording
              </button>
            </div>

          <% :preview -> %>
            <!-- Preview Phase -->
            <div class="text-center">
              <h4 class="text-2xl font-black text-gray-900 mb-6">Review Your Introduction</h4>

              <div class="bg-black rounded-xl aspect-video mb-6 flex items-center justify-center relative overflow-hidden">
                <!-- Video Element -->
                <video id="playback-video"
                      controls
                      playsinline
                      class="w-full h-full object-cover"
                      style="display: block;">
                </video>

                <!-- Loading Overlay -->
                <div id="video-loading" class="absolute inset-0 flex items-center justify-center text-white bg-black bg-opacity-50">
                  <div class="text-center">
                    <svg class="w-12 h-12 mx-auto mb-4 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
                    </svg>
                    <p class="text-lg">Loading preview...</p>
                    <p class="text-sm text-gray-300 mt-2">Preparing your recorded video</p>
                  </div>
                </div>

                <!-- Debug Info -->
                <div class="absolute top-4 left-4 bg-black bg-opacity-60 rounded px-3 py-2 text-white text-sm font-mono">
                  Preview Mode | Chunks: Loading...
                </div>
              </div>

              <!-- Actions -->
              <div class="flex justify-center space-x-4">
                <button phx-click="retake_video"
                        phx-target={@myself}
                        class="px-6 py-3 border border-gray-300 rounded-xl text-gray-700 font-semibold hover:bg-gray-50 transition-all flex items-center">
                  <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
                  </svg>
                  Retake Video
                </button>

                <button phx-click="save_video"
                        phx-target={@myself}
                        class="px-8 py-3 bg-gradient-to-r from-green-600 to-emerald-600 text-white font-bold rounded-xl hover:from-green-700 hover:to-emerald-700 transition-all flex items-center">
                  <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                  </svg>
                  Save Introduction
                </button>
              </div>

              <!-- Debug Controls for Preview -->
              <div class="mt-6 p-4 bg-gray-100 rounded-lg">
                <h6 class="font-bold text-gray-800 mb-3">Preview Debug</h6>

                <div class="text-sm text-gray-600 mb-3">
                  <div>State: <strong><%= @recording_state %></strong></div>
                  <div>Video Element: <span id="video-status">Checking...</span></div>
                </div>

                <div class="flex gap-2">
                  <button onclick="window.debugVideo.checkPreviewVideo()"
                          class="px-3 py-1 bg-purple-600 text-white text-xs rounded hover:bg-purple-700">
                    Check Video
                  </button>

                  <button onclick="window.debugVideo.forceHideLoading()"
                          class="px-3 py-1 bg-red-600 text-white text-xs rounded hover:bg-red-700">
                    Hide Loading
                  </button>
                </div>
              </div>
            </div>

          <% :saving -> %>
            <!-- Saving Phase -->
            <div class="text-center py-12">
              <div class="w-16 h-16 mx-auto mb-6 bg-gradient-to-r from-purple-600 to-indigo-600 rounded-full flex items-center justify-center animate-pulse">
                <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/>
                </svg>
              </div>
              <h4 class="text-2xl font-black text-gray-900 mb-4">Saving Your Video</h4>
              <p class="text-gray-600">Processing and uploading your introduction...</p>

              <!-- Progress Bar -->
              <div class="w-full max-w-md mx-auto mt-6 bg-gray-200 rounded-full h-2">
                <div class="bg-gradient-to-r from-purple-600 to-indigo-600 h-2 rounded-full animate-pulse" style="width: 75%"></div>
              </div>
            </div>
        <% end %>
      </div>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    IO.inspect(assigns, label: "UPDATE_RECEIVED")

    # Handle timer tick actions
    cond do
      Map.has_key?(assigns, :action) and assigns.action == :countdown_tick ->
        IO.inspect("Processing countdown tick", label: "COUNTDOWN_ACTION")
        process_countdown_tick(socket, assigns)

      Map.has_key?(assigns, :action) and assigns.action == :recording_tick ->
        IO.inspect("Processing recording tick", label: "RECORDING_ACTION")
        process_recording_tick(socket, assigns)

      true ->
        IO.inspect("Normal update", label: "NORMAL_UPDATE")
        # Normal component update
        {:ok,
        socket
        |> assign(assigns)
        |> assign_new(:recording_state, fn -> :setup end)
        |> assign_new(:camera_ready, fn -> false end)
        |> assign_new(:countdown_timer, fn -> 3 end)
        |> assign_new(:elapsed_time, fn -> 0 end)
        |> assign_new(:recorded_blob, fn -> nil end)}
    end
  end

  @impl true
  def handle_event("camera_ready", params, socket) do
    IO.inspect(params, label: "CAMERA READY EVENT")
    {:noreply, assign(socket, camera_ready: true)}
  end

  @impl true
  def handle_event("stop_recording", _params, socket) do
    socket =
      socket
      |> assign(recording_state: :preview)
      |> push_event("stop_recording", %{})

    {:noreply, socket}
  end

  @impl true
  def handle_event("retake_video", _params, socket) do
    socket =
      socket
      |> assign(recording_state: :setup, elapsed_time: 0, recorded_blob: nil)
      |> push_event("retake_video", %{})

    {:noreply, socket}
  end

  @impl true
  def handle_event("save_video", _params, socket) do
    socket =
      socket
      |> assign(recording_state: :saving)
      |> push_event("upload_video", %{})

    {:noreply, socket}
  end

  @impl true
  def handle_event("camera_error", %{"error" => error_name, "message" => message}, socket) do
    socket =
      socket
      |> assign(recording_state: :setup, camera_ready: false)
      |> put_flash(:error, message)

    {:noreply, socket}
  end

  @impl true
  def handle_event("video_blob_ready", %{"blob_data" => blob_data, "mime_type" => mime_type, "file_size" => file_size}, socket) do
    IO.inspect("Received video blob: #{byte_size(blob_data)} base64 chars, #{mime_type}, #{file_size} bytes")

    case Base.decode64(blob_data) do
      {:ok, video_data} ->
        # Generate filename with timestamp
        timestamp = DateTime.utc_now() |> DateTime.to_unix()
        extension = case mime_type do
          "video/webm" -> ".webm"
          "video/mp4" -> ".mp4"
          _ -> ".webm"
        end
        filename = "portfolio_intro_#{socket.assigns.portfolio.id}_#{timestamp}#{extension}"

        media_attrs = %{
          filename: filename,
          original_filename: filename,
          content_type: mime_type,
          file_size: file_size,
          media_type: "video",
          title: "Portfolio Introduction - #{socket.assigns.portfolio.title}",
          description: "Video introduction for portfolio"
        }

        case create_media_file(media_attrs, video_data) do
          {:ok, media_file} ->
            IO.inspect(media_file, label: "Video saved successfully")

            # Send completion event to parent LiveView
            send(self(), {:video_intro_complete, %{"media_file_id" => media_file.id, "file_path" => media_file.file_path}})

            # Close the component
            socket =
              socket
              |> put_flash(:info, "Video introduction saved successfully!")

            # Call the on_complete callback if provided
            if socket.assigns[:on_complete] do
              send(self(), {socket.assigns.on_complete, %{"media_file_id" => media_file.id}})
            end

            {:noreply, socket}

          {:error, error} ->
            IO.inspect(error, label: "Video save failed")

            socket =
              socket
              |> assign(recording_state: :preview)
              |> put_flash(:error, "Failed to save video. Please try again.")

            {:noreply, socket}
        end

      {:error, decode_error} ->
        IO.inspect(decode_error, label: "Base64 decode failed")

        socket =
          socket
          |> assign(recording_state: :preview)
          |> put_flash(:error, "Invalid video data. Please try recording again.")

        {:noreply, socket}
    end
  end

  defp process_countdown_tick(socket, _assigns) do
    IO.inspect("=== PROCESSING COUNTDOWN TICK ===", label: "COUNTDOWN")
    IO.inspect("Current state: #{socket.assigns.recording_state}", label: "STATE")
    IO.inspect("Current timer: #{socket.assigns.countdown_timer}", label: "TIMER")

    if socket.assigns.recording_state == :countdown do
      new_timer = socket.assigns.countdown_timer - 1
      IO.inspect("Decreasing timer: #{socket.assigns.countdown_timer} -> #{new_timer}", label: "COUNTDOWN")

      if new_timer > 0 do
        # Continue countdown
        Process.send_after(self(), {:countdown_tick, socket.assigns.id}, 1000)

        socket = assign(socket, countdown_timer: new_timer)
        IO.inspect("Updated countdown timer to: #{new_timer}", label: "COUNTDOWN_UPDATE")

        {:ok, socket}
      else
        # Start recording
        IO.inspect("Countdown complete - starting recording", label: "COUNTDOWN_COMPLETE")

        socket =
          socket
          |> assign(recording_state: :recording, elapsed_time: 0, countdown_timer: 0)
          |> push_event("start_recording", %{})

        # Start recording timer
        Process.send_after(self(), {:recording_tick, socket.assigns.id}, 1000)

        {:ok, socket}
      end
    else
      IO.inspect("Ignoring countdown tick - wrong state: #{socket.assigns.recording_state}", label: "COUNTDOWN_IGNORE")
      {:ok, socket}
    end
  end

  defp process_recording_tick(socket, _assigns) do
    IO.inspect("=== PROCESSING RECORDING TICK ===", label: "RECORDING")
    IO.inspect("Current time: #{socket.assigns.elapsed_time}", label: "TIME")

    if socket.assigns.recording_state == :recording do
      new_time = socket.assigns.elapsed_time + 1
      IO.inspect("Increasing time: #{socket.assigns.elapsed_time} -> #{new_time}", label: "RECORDING")

      if new_time >= 60 do
        # Auto-stop at 60 seconds
        IO.inspect("Recording complete - auto-stopping", label: "RECORDING_COMPLETE")

        socket =
          socket
          |> assign(recording_state: :preview, elapsed_time: 60)
          |> push_event("stop_recording", %{})

        {:ok, socket}
      else
        # Continue recording
        Process.send_after(self(), {:recording_tick, socket.assigns.id}, 1000)

        socket = assign(socket, elapsed_time: new_time)
        IO.inspect("Updated recording time to: #{new_time}", label: "RECORDING_UPDATE")

        {:ok, socket}
      end
    else
      IO.inspect("Ignoring recording tick - wrong state: #{socket.assigns.recording_state}", label: "RECORDING_IGNORE")
      {:ok, socket}
    end
  end

  # 4. ENHANCED DEBUG EVENT HANDLERS
  @impl true
  def handle_event("debug_countdown", _params, socket) do
    IO.inspect("=== MANUAL COUNTDOWN TEST ===", label: "DEBUG")

    socket =
      socket
      |> assign(recording_state: :countdown, countdown_timer: 3)

    # Force immediate first tick to test the mechanism
    send_update(__MODULE__,
      id: socket.assigns.id,
      action: :countdown_tick,
      force_update: System.unique_integer()
    )

    {:noreply, socket}
  end

  @impl true
  def handle_event("debug_state", _params, socket) do
    IO.inspect("=== COMPONENT STATE DEBUG ===", label: "DEBUG")
    IO.inspect(socket.assigns, label: "ALL_ASSIGNS")

    {:noreply, put_flash(socket, :info, "State logged to console - check terminal")}
  end



  # Helper function for creating media files
  defp create_media_file(attrs, binary_data) do
    try do
      # Ensure upload directory exists
      upload_dir = Path.join([Application.app_dir(:frestyl, "priv"), "static", "uploads", "videos"])
      File.mkdir_p!(upload_dir)

      # Save file to uploads directory
      file_path = Path.join(upload_dir, attrs.filename)
      File.write!(file_path, binary_data)

      # Create public path for serving
      public_path = "/uploads/videos/#{attrs.filename}"

      # Create media record - adapt this to your actual Media module
      media_attrs = %{
        filename: attrs.filename,
        original_filename: attrs.original_filename,
        content_type: attrs.content_type,
        file_size: attrs.file_size,
        file_path: public_path,
        media_type: attrs.media_type,
        title: attrs.title,
        description: attrs.description
      }

      # Return success - replace with actual media creation call
      {:ok, %{
        id: System.unique_integer([:positive]),
        file_path: public_path,
        filename: attrs.filename,
        content_type: attrs.content_type,
        file_size: attrs.file_size
      }}

    rescue
      error ->
        IO.inspect(error, label: "Video upload error")
        {:error, %{errors: [file: {"Upload failed: #{inspect(error)}", []}]}}
    end
  end

  # Helper function to upload video file
  defp upload_video_file(socket, video_data, mime_type, file_size) do
    # Generate filename
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    extension = case mime_type do
      "video/webm" -> ".webm"
      "video/mp4" -> ".mp4"
      _ -> ".webm"
    end
    filename = "portfolio_intro_#{socket.assigns.portfolio.id}_#{timestamp}#{extension}"

    # Create media attributes
    media_attrs = %{
      filename: filename,
      original_filename: filename,
      content_type: mime_type,
      file_size: file_size,
      media_type: "video",
      user_id: socket.assigns.current_user.id,
      title: "Portfolio Introduction - #{socket.assigns.portfolio.title}",
      description: "Video introduction for portfolio"
    }

    # Save to file system (adjust path as needed)
    upload_dir = Application.app_dir(:frestyl, "priv/static/uploads/videos")

    case File.mkdir_p(upload_dir) do
      :ok ->
        file_path = Path.join(upload_dir, filename)

        case File.write(file_path, video_data) do
          :ok ->
            # Create database record - replace this with your actual Media module call
            public_path = "/uploads/videos/#{filename}"
            final_attrs = Map.put(media_attrs, :file_path, public_path)

            # This should call your actual Media module
            # Media.create_media_file(final_attrs)
            # For now, creating a mock response:
            {:ok, %{id: "video_#{timestamp}", file_path: public_path}}

          {:error, reason} ->
            {:error, "File write failed: #{inspect(reason)}"}
        end

      {:error, reason} ->
        {:error, "Directory creation failed: #{inspect(reason)}"}
    end
  end

  @impl true
  def handle_info(msg, socket) do
    IO.inspect(msg, label: "UNHANDLED MESSAGE")
    {:noreply, socket}
  end

  @impl true
  def handle_event("start_countdown", _params, socket) do
    IO.inspect("=== START COUNTDOWN EVENT ===", label: "EVENT")
    IO.inspect("Current state: #{socket.assigns.recording_state}", label: "CURRENT_STATE")
    IO.inspect("Camera ready: #{socket.assigns.camera_ready}", label: "CAMERA_READY")

    if socket.assigns.camera_ready do
      socket =
        socket
        |> assign(recording_state: :countdown, countdown_timer: 3)
        |> push_event("start_countdown", %{})

      # Start countdown timer
      component_id = socket.assigns.id
      IO.inspect("Starting countdown for component: #{component_id}", label: "STARTING_TIMER")
      Process.send_after(self(), {:countdown_tick, component_id}, 1000)

      {:noreply, socket}
    else
      IO.inspect("Cannot start countdown - camera not ready", label: "ERROR")
      {:noreply, put_flash(socket, :error, "Camera not ready")}
    end
  end

  @impl true
  def handle_event("debug_countdown", _params, socket) do
    IO.inspect("=== MANUAL COUNTDOWN TEST ===", label: "DEBUG")

    socket =
      socket
      |> assign(recording_state: :countdown, countdown_timer: 3)

    Process.send_after(self(), {:countdown_tick, socket.assigns.id}, 1000)

    {:noreply, socket}
  end

  @impl true
  def handle_event("debug_state", _params, socket) do
    IO.inspect("=== COMPONENT STATE DEBUG ===", label: "DEBUG")
    IO.inspect(socket.assigns, label: "ALL_ASSIGNS")

    {:noreply, put_flash(socket, :info, "State logged to console - check terminal")}
  end

  @impl true
  def update(%{action: :countdown_tick} = assigns, socket) do
    IO.inspect("Processing countdown tick in component", label: "COUNTDOWN_TICK")

    if socket.assigns.recording_state == :countdown do
      new_timer = socket.assigns.countdown_timer - 1
      IO.inspect("Countdown decreasing: #{socket.assigns.countdown_timer} -> #{new_timer}", label: "COUNTDOWN")

      if new_timer > 0 do
        # Continue countdown
        Process.send_after(self(), {:countdown_tick, socket.assigns.id}, 1000)

        socket = assign(socket, countdown_timer: new_timer)
        IO.inspect("Updated countdown timer to: #{new_timer}", label: "COUNTDOWN_UPDATE")

        {:ok, socket}
      else
        # Start recording
        IO.inspect("Countdown complete - starting recording", label: "COUNTDOWN_COMPLETE")

        socket =
          socket
          |> assign(recording_state: :recording, elapsed_time: 0, countdown_timer: 0)
          |> push_event("start_recording", %{})

        # Start recording timer
        Process.send_after(self(), {:recording_tick, socket.assigns.id}, 1000)

        {:ok, socket}
      end
    else
      IO.inspect("Ignoring countdown tick - wrong state: #{socket.assigns.recording_state}", label: "COUNTDOWN_IGNORE")
      {:ok, socket}
    end
  end

  @impl true
  def update(%{action: :recording_tick} = assigns, socket) do
    IO.inspect("Processing recording tick in component", label: "RECORDING_TICK")

    if socket.assigns.recording_state == :recording do
      new_time = socket.assigns.elapsed_time + 1
      IO.inspect("Recording time: #{socket.assigns.elapsed_time} -> #{new_time}", label: "RECORDING")

      if new_time >= 60 do
        # Auto-stop at 60 seconds
        IO.inspect("Recording complete - auto-stopping", label: "RECORDING_COMPLETE")

        socket =
          socket
          |> assign(recording_state: :preview, elapsed_time: 60)
          |> push_event("stop_recording", %{})

        {:ok, socket}
      else
        # Continue recording
        Process.send_after(self(), {:recording_tick, socket.assigns.id}, 1000)

        socket = assign(socket, elapsed_time: new_time)
        IO.inspect("Updated recording time to: #{new_time}", label: "RECORDING_UPDATE")

        {:ok, socket}
      end
    else
      IO.inspect("Ignoring recording tick - wrong state: #{socket.assigns.recording_state}", label: "RECORDING_IGNORE")
      {:ok, socket}
    end
  end

  @impl true
  def handle_event("hide_video_intro", _params, socket) do
    IO.inspect("Hide video intro requested", label: "CLOSE_VIDEO")

    # Call the on_cancel callback if provided
    if socket.assigns[:on_cancel] do
      send(self(), {socket.assigns.on_cancel, %{}})
    end

    {:noreply, socket}
  end

  @impl true
  def update(assigns, socket) when not is_map_key(assigns, :action) do
    IO.inspect(assigns, label: "NORMAL_UPDATE")

    {:ok,
    socket
    |> assign(assigns)
    |> assign_new(:recording_state, fn -> :setup end)
    |> assign_new(:camera_ready, fn -> false end)
    |> assign_new(:countdown_timer, fn -> 3 end)
    |> assign_new(:elapsed_time, fn -> 0 end)
    |> assign_new(:recorded_blob, fn -> nil end)}
  end

  # Fix the camera_ready handler to ensure it updates the state properly
  @impl true
  def handle_event("camera_ready", params, socket) do
    IO.inspect(params, label: "CAMERA READY EVENT")
    {:noreply, assign(socket, camera_ready: true)}
  end

  # Add better debugging to the update function
  @impl true
  def update(assigns, socket) when not is_map_key(assigns, :countdown_tick) and not is_map_key(assigns, :recording_tick) do
    IO.inspect(assigns, label: "NORMAL COMPONENT UPDATE")

    {:ok,
    socket
    |> assign(assigns)
    |> assign_new(:recording_state, fn -> :setup end)
    |> assign_new(:camera_ready, fn -> false end)
    |> assign_new(:countdown_timer, fn -> 3 end)
    |> assign_new(:elapsed_time, fn -> 0 end)
    |> assign_new(:recorded_blob, fn -> nil end)}
  end


  defp format_time(seconds) do
    minutes = div(seconds, 60)
    secs = rem(seconds, 60)
    "#{minutes}:#{String.pad_leading(Integer.to_string(secs), 2, "0")}"
  end

    @impl true
  def handle_event("save_video", _params, socket) do
    socket =
      socket
      |> assign(recording_state: :saving)
      |> push_event("upload_video", %{})

    {:noreply, socket}
  end

  @impl true
  def handle_event("video_blob_ready", %{"blob_data" => blob_data, "mime_type" => mime_type, "file_size" => file_size}, socket) do
    IO.inspect("=== VIDEO BLOB RECEIVED ===", label: "VIDEO_UPLOAD")
    IO.inspect("Base64 length: #{String.length(blob_data)}", label: "BLOB_SIZE")
    IO.inspect("MIME type: #{mime_type}", label: "MIME_TYPE")
    IO.inspect("File size: #{file_size} bytes", label: "FILE_SIZE")

    try do
      case Base.decode64(blob_data) do
        {:ok, video_data} ->
          IO.inspect("Base64 decoded successfully, #{byte_size(video_data)} bytes", label: "DECODE_SUCCESS")

          # Generate filename with timestamp
          timestamp = DateTime.utc_now() |> DateTime.to_unix()
          extension = case mime_type do
            "video/webm" -> ".webm"
            "video/mp4" -> ".mp4"
            _ -> ".webm"
          end
          filename = "portfolio_intro_#{socket.assigns.portfolio.id}_#{timestamp}#{extension}"

          IO.inspect("Generated filename: #{filename}", label: "FILENAME")

          media_attrs = %{
            filename: filename,
            original_filename: filename,
            content_type: mime_type,
            file_size: file_size,
            media_type: "video",
            title: "Portfolio Introduction - #{socket.assigns.portfolio.title}",
            description: "Video introduction for portfolio"
          }

          case create_media_file(media_attrs, video_data) do
            {:ok, media_file} ->
              IO.inspect("Video saved successfully!", label: "SAVE_SUCCESS")
              IO.inspect(media_file, label: "MEDIA_FILE")

              # Success! Reset component and notify parent
              socket =
                socket
                |> assign(recording_state: :setup, elapsed_time: 0, countdown_timer: 3)  # Reset completely
                |> put_flash(:info, "Video introduction saved successfully!")

              # Send completion event to parent LiveView to close the component
              if socket.assigns[:on_complete] do
                send(self(), {socket.assigns.on_complete, %{
                  "media_file_id" => media_file.id,
                  "file_path" => media_file.file_path
                }})
              end

              {:noreply, socket}

            {:error, error} ->
              IO.inspect(error, label: "SAVE_ERROR")

              socket =
                socket
                |> assign(recording_state: :preview)  # Go back to preview
                |> put_flash(:error, "Failed to save video. Please try again.")

              {:noreply, socket}
          end

        {:error, decode_error} ->
          IO.inspect(decode_error, label: "DECODE_ERROR")

          socket =
            socket
            |> assign(recording_state: :preview)  # Go back to preview
            |> put_flash(:error, "Invalid video data. Please try recording again.")

          {:noreply, socket}
      end
    rescue
      exception ->
        IO.inspect(exception, label: "UPLOAD_EXCEPTION")

        socket =
          socket
          |> assign(recording_state: :preview)  # Go back to preview
          |> put_flash(:error, "Upload failed: #{Exception.message(exception)}")

        {:noreply, socket}
    end
  end

  # Helper function to create media file - adapt this to your Media module
  defp create_media_file(attrs, binary_data) do
    IO.inspect("=== CREATING MEDIA FILE ===", label: "MEDIA_CREATE")
    IO.inspect(attrs, label: "MEDIA_ATTRS")

    try do
      # Ensure upload directory exists
      upload_dir = Path.join([Application.app_dir(:frestyl, "priv"), "static", "uploads", "videos"])
      IO.inspect("Upload directory: #{upload_dir}", label: "UPLOAD_DIR")

      case File.mkdir_p(upload_dir) do
        :ok ->
          IO.inspect("Directory created/verified", label: "DIR_OK")

          # Save file to uploads directory
          file_path = Path.join(upload_dir, attrs.filename)
          IO.inspect("Writing to: #{file_path}", label: "FILE_PATH")

          case File.write(file_path, binary_data) do
            :ok ->
              IO.inspect("File written successfully", label: "FILE_OK")

              # Verify file was written
              case File.stat(file_path) do
                {:ok, %{size: size}} ->
                  IO.inspect("File verified, size: #{size} bytes", label: "FILE_VERIFIED")

                  # Create public path for serving
                  public_path = "/uploads/videos/#{attrs.filename}"

                  # Return success response
                  {:ok, %{
                    id: System.unique_integer([:positive]),
                    file_path: public_path,
                    filename: attrs.filename,
                    content_type: attrs.content_type,
                    file_size: attrs.file_size,
                    title: attrs.title
                  }}

                {:error, reason} ->
                  IO.inspect("File verification failed: #{inspect(reason)}", label: "FILE_VERIFY_ERROR")
                  {:error, %{errors: [file: {"File verification failed", []}]}}
              end

            {:error, reason} ->
              IO.inspect("File write failed: #{inspect(reason)}", label: "FILE_WRITE_ERROR")
              {:error, %{errors: [file: {"File write failed: #{inspect(reason)}", []}]}}
          end

        {:error, reason} ->
          IO.inspect("Directory creation failed: #{inspect(reason)}", label: "DIR_ERROR")
          {:error, %{errors: [directory: {"Directory creation failed: #{inspect(reason)}", []}]}}
      end

    rescue
      error ->
        IO.inspect(error, label: "MEDIA_CREATE_EXCEPTION")
        {:error, %{errors: [file: {"Upload failed: #{Exception.message(error)}", []}]}}
    end
  end

  # Also update your handle_event for better error handling:
  @impl true
  def handle_event("video_blob_ready", %{"blob_data" => blob_data, "mime_type" => mime_type, "file_size" => file_size}, socket) do
    IO.inspect("Received video blob: #{byte_size(blob_data)} base64 chars, #{mime_type}, #{file_size} bytes")

    case Base.decode64(blob_data) do
      {:ok, video_data} ->
        # Generate filename with timestamp
        timestamp = DateTime.utc_now() |> DateTime.to_unix()
        extension = case mime_type do
          "video/webm" -> ".webm"
          "video/mp4" -> ".mp4"
          _ -> ".webm"
        end
        filename = "portfolio_intro_#{socket.assigns.portfolio.id}_#{timestamp}#{extension}"

        media_attrs = %{
          filename: filename,
          original_filename: filename,
          content_type: mime_type,
          file_size: file_size,
          media_type: "video",
          title: "Portfolio Introduction - #{socket.assigns.portfolio.title}",
          description: "Video introduction for portfolio"
        }

        case create_media_file(media_attrs, video_data) do
          {:ok, media_file} ->
            IO.inspect(media_file, label: "Video saved successfully")

            # Send completion event to parent LiveView
            send(self(), {:video_intro_complete, %{"media_file_id" => media_file.id, "file_path" => media_file.file_path}})

            # Close the component
            socket =
              socket
              |> put_flash(:info, "Video introduction saved successfully!")

            # Call the on_complete callback if provided
            if socket.assigns[:on_complete] do
              send(self(), {socket.assigns.on_complete, %{"media_file_id" => media_file.id}})
            end

            {:noreply, socket}

          {:error, error} ->
            IO.inspect(error, label: "Video save failed")

            socket =
              socket
              |> assign(recording_state: :preview)
              |> put_flash(:error, "Failed to save video. Please try again.")

            {:noreply, socket}
        end

      {:error, decode_error} ->
        IO.inspect(decode_error, label: "Base64 decode failed")

        socket =
          socket
          |> assign(recording_state: :preview)
          |> put_flash(:error, "Invalid video data. Please try recording again.")

        {:noreply, socket}
    end
  end
end
