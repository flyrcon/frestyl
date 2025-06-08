# lib/frestyl_web/live/portfolio_live/video_intro_component.ex - FIXED VERSION
defmodule FrestylWeb.PortfolioLive.VideoIntroComponent do
  use FrestylWeb, :live_component

  @impl true
  def mount(socket) do
    socket =
      socket
      |> assign(:recording_state, :setup)
      |> assign(:countdown_timer, 3)
      |> assign(:elapsed_time, 0)
      |> assign(:recorded_blob, nil)
      |> assign(:camera_ready, false)
      |> assign(:upload_progress, 0)
      |> assign(:error_message, nil)

    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  # FIXED: Handle timer messages properly
  @impl true
  def handle_info({:countdown_tick, component_id}, socket) do
    if socket.assigns.id == component_id and socket.assigns.recording_state == :countdown do
      new_timer = socket.assigns.countdown_timer - 1

      if new_timer > 0 do
        # Continue countdown
        Process.send_after(self(), {:countdown_tick, component_id}, 1000)
        socket = assign(socket, countdown_timer: new_timer)
        {:noreply, socket}
      else
        # Start recording
        socket =
          socket
          |> assign(recording_state: :recording, elapsed_time: 0, countdown_timer: 0)
          |> push_event("start_recording", %{})

        # Start recording timer
        Process.send_after(self(), {:recording_tick, component_id}, 1000)
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:recording_tick, component_id}, socket) do
    if socket.assigns.id == component_id and socket.assigns.recording_state == :recording do
      new_time = socket.assigns.elapsed_time + 1

      if new_time >= 60 do
        # Auto-stop at 60 seconds
        socket =
          socket
          |> assign(recording_state: :preview, elapsed_time: 60)
          |> push_event("stop_recording", %{})

        {:noreply, socket}
      else
        # Continue recording
        Process.send_after(self(), {:recording_tick, component_id}, 1000)
        socket = assign(socket, elapsed_time: new_time)
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  # Ignore other messages
  @impl true
  def handle_info(_, socket), do: {:noreply, socket}

  @impl true
  def handle_event("camera_ready", _params, socket) do
    {:noreply, assign(socket, camera_ready: true, error_message: nil)}
  end

  @impl true
  def handle_event("start_countdown", _params, socket) do
    if socket.assigns.camera_ready do
      socket =
        socket
        |> assign(recording_state: :countdown, countdown_timer: 3)
        |> push_event("prepare_recording", %{})

      # Start countdown timer
      Process.send_after(self(), {:countdown_tick, socket.assigns.id}, 1000)

      {:noreply, socket}
    else
      {:noreply, put_flash(socket, :error, "Camera not ready. Please allow camera access.")}
    end
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
      |> assign(recording_state: :setup, elapsed_time: 0, recorded_blob: nil, error_message: nil)
      |> push_event("retake_video", %{})

    {:noreply, socket}
  end

  @impl true
  def handle_event("save_video", _params, socket) do
    socket =
      socket
      |> assign(recording_state: :saving, upload_progress: 0)
      |> push_event("upload_video", %{})

    {:noreply, socket}
  end

  @impl true
  def handle_event("camera_error", %{"error" => error_name, "message" => message}, socket) do
    socket =
      socket
      |> assign(recording_state: :setup, camera_ready: false, error_message: message)
      |> put_flash(:error, "Camera Error: #{message}")

    {:noreply, socket}
  end

  @impl true
  def handle_event("hide_video_intro", _params, socket) do
    # Call the on_cancel callback if provided
    if socket.assigns[:on_cancel] do
      send(self(), {socket.assigns.on_cancel, %{}})
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("video_blob_ready", %{"blob_data" => blob_data, "mime_type" => mime_type, "file_size" => file_size}, socket) do
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

        case save_video_file(filename, video_data, socket.assigns.portfolio) do
          {:ok, file_info} ->
            # Success! Reset component and notify parent
            socket =
              socket
              |> assign(recording_state: :setup, elapsed_time: 0, countdown_timer: 3)
              |> put_flash(:info, "Video introduction saved successfully!")

            # Send completion event to parent LiveView
            send(self(), {:video_intro_complete, %{
              "media_file_id" => file_info.id,
              "file_path" => file_info.file_path
            }})

            {:noreply, socket}

          {:error, _error} ->
            socket =
              socket
              |> assign(recording_state: :preview)
              |> put_flash(:error, "Failed to save video. Please try again.")

            {:noreply, socket}
        end

      {:error, _decode_error} ->
        socket =
          socket
          |> assign(recording_state: :preview)
          |> put_flash(:error, "Invalid video data. Please try recording again.")

        {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-white rounded-xl shadow-2xl overflow-hidden"
         phx-hook="VideoCapture"
         id={"video-capture-#{@id}"}
         data-component-id={@id}>
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
          <button phx-click="hide_video_intro" phx-target={@myself} class="text-white hover:text-purple-200">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </button>
        </div>
      </div>

      <!-- Main Content -->
      <div class="p-6">
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

  # Setup Phase - IMPROVED
  defp render_setup_phase(assigns) do
    ~H"""
    <div class="text-center mb-8">
      <div class="w-24 h-24 mx-auto mb-6 bg-gradient-to-r from-purple-600 to-indigo-600 rounded-full flex items-center justify-center">
        <svg class="w-12 h-12 text-white" fill="currentColor" viewBox="0 0 20 20">
          <path d="M6.3 2.841A1.5 1.5 0 004 4.11V15.89a1.5 1.5 0 002.3 1.269l9.344-5.89a1.5 1.5 0 000-2.538L6.3 2.84z"/>
        </svg>
      </div>
      <h4 class="text-2xl font-bold text-gray-900 mb-4">Ready to record?</h4>
      <p class="text-gray-600 mb-8 max-w-2xl mx-auto leading-relaxed">
        Create a compelling 60-second introduction that showcases your personality and professional story.
      </p>
    </div>

    <!-- Camera Preview with Better Error Handling -->
    <div class="bg-black rounded-xl mb-6 flex items-center justify-center relative overflow-hidden"
         style="aspect-ratio: 16/9;">
      <video id="camera-preview"
            autoplay
            muted
            playsinline
            class="w-full h-full object-cover"
            style="transform: scaleX(-1);">
      </video>

      <%= if not @camera_ready do %>
        <div class="absolute inset-0 bg-black bg-opacity-75 flex items-center justify-center">
          <div class="text-center">
            <%= if @error_message do %>
              <svg class="w-16 h-16 text-red-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                      d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.732-.833-2.5 0L4.232 15.5c-.77.833.192 2.5 1.732 2.5z"/>
              </svg>
              <p class="text-white text-lg font-semibold mb-2">Camera Access Required</p>
              <p class="text-gray-300 text-sm mb-4"><%= @error_message %></p>
              <button phx-click="retake_video" phx-target={@myself}
                      class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700">
                Try Again
              </button>
            <% else %>
              <div class="animate-spin w-8 h-8 border-2 border-white border-t-transparent rounded-full mx-auto mb-4"></div>
              <p class="text-white">Accessing camera...</p>
              <p class="text-gray-300 text-sm mt-2">Please allow camera access when prompted</p>
            <% end %>
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
    """
  end

  # Other render functions remain the same...
  defp render_countdown_phase(assigns) do
    ~H"""
    <div class="text-center">
      <div class="bg-black rounded-xl mb-6 flex items-center justify-center relative overflow-hidden"
           style="aspect-ratio: 16/9;">
        <video id="camera-preview"
              autoplay
              muted
              playsinline
              class="w-full h-full object-cover"
              style="transform: scaleX(-1);">
        </video>

        <div class="absolute inset-0 bg-black bg-opacity-50 flex items-center justify-center">
          <div class="text-center">
            <div class="text-8xl font-bold text-white mb-4 animate-pulse">
              <%= @countdown_timer %>
            </div>
            <p class="text-white text-xl">Get ready...</p>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp render_recording_phase(assigns) do
    ~H"""
    <div class="text-center">
      <div class="bg-black rounded-xl mb-6 flex items-center justify-center relative overflow-hidden"
           style="aspect-ratio: 16/9;">
        <video id="camera-preview"
              autoplay
              muted
              playsinline
              class="w-full h-full object-cover"
              style="transform: scaleX(-1);">
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
          <div class="h-1 bg-gradient-to-r from-red-600 to-pink-600 transition-all duration-1000"
              style={"width: #{(@elapsed_time / 60) * 100}%"}></div>
        </div>
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
    """
  end

  defp render_preview_phase(assigns) do
    ~H"""
    <div class="text-center">
      <h4 class="text-2xl font-bold text-gray-900 mb-6">Review Your Introduction</h4>

      <div class="bg-black rounded-xl mb-6 flex items-center justify-center relative overflow-hidden"
           style="aspect-ratio: 16/9;">
        <video id="playback-video"
              controls
              playsinline
              class="w-full h-full object-cover">
        </video>

        <div id="video-loading" class="absolute inset-0 flex items-center justify-center text-white bg-black bg-opacity-50">
          <div class="text-center">
            <svg class="w-12 h-12 mx-auto mb-4 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
            </svg>
            <p class="text-lg">Loading preview...</p>
          </div>
        </div>
      </div>

      <!-- Actions -->
      <div class="flex justify-center space-x-4">
        <button phx-click="retake_video"
                phx-target={@myself}
                class="px-6 py-3 border border-gray-300 rounded-xl text-gray-700 font-semibold hover:bg-gray-50 transition-all">
          Retake Video
        </button>

        <button phx-click="save_video"
                phx-target={@myself}
                class="px-8 py-3 bg-gradient-to-r from-green-600 to-emerald-600 text-white font-bold rounded-xl hover:from-green-700 hover:to-emerald-700 transition-all">
          Save Introduction
        </button>
      </div>
    </div>
    """
  end

  defp render_saving_phase(assigns) do
    ~H"""
    <div class="text-center py-12">
      <div class="w-16 h-16 mx-auto mb-6 bg-gradient-to-r from-purple-600 to-indigo-600 rounded-full flex items-center justify-center animate-pulse">
        <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/>
        </svg>
      </div>
      <h4 class="text-2xl font-bold text-gray-900 mb-4">Saving Your Video</h4>
      <p class="text-gray-600 mb-6">Processing and saving your introduction...</p>
    </div>
    """
  end

  # Helper function to save video file
  defp save_video_file(filename, binary_data, portfolio) do
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

              # Return success response
              {:ok, %{
                id: System.unique_integer([:positive]),
                file_path: public_path,
                filename: filename,
                portfolio_id: portfolio.id
              }}

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

  # Helper function to format recording time
  defp format_time(seconds) do
    minutes = div(seconds, 60)
    secs = rem(seconds, 60)
    "#{minutes}:#{String.pad_leading(Integer.to_string(secs), 2, "0")}"
  end
end
