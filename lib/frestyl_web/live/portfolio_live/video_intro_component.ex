# lib/frestyl_web/live/portfolio_live/video_intro_component.ex - CRITICAL FIXES FOR VIDEO INTRO

defmodule FrestylWeb.PortfolioLive.VideoIntroComponent do
  use FrestylWeb, :live_component

  alias Frestyl.Portfolios.PortfolioTemplates


  @impl true
  def mount(socket) do
    IO.puts("=== VIDEO INTRO COMPONENT MOUNTING ===")
    IO.puts("Component ID: #{socket.assigns[:id] || "NO ID"}")

    header_config = %{
      header_config: %{
        video_style: "professional",
        show_social: true,
        show_metrics: false
      }
    }

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
      |> assign(:video_style_classes, Helpers.get_video_style_classes_safe())
      |> assign(:header_layout, header_config["layout"] || "centered")

    IO.puts("=== COMPONENT MOUNTED WITH ASSIGNS ===")
    {:ok, socket}
  end

  # ============================================================================
  # FIXED: Proper Event Handlers with Parent Communication
  # ============================================================================

  # FIXED: Cancel recording - properly notify parent
  @impl true
  def handle_event("cancel_recording", _params, socket) do
    IO.puts("=== CANCEL RECORDING IN COMPONENT ===")

    # Clean up any active recording
    cleanup_recording_state(socket)

    # Notify parent to close modal
    send(self(), {:close_video_intro_modal, %{}})

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
        IO.puts("SUCCESS: Starting countdown - setting state to :countdown")

        socket =
          socket
          |> assign(:recording_state, :countdown)
          |> assign(:countdown_timer, 3)
          |> assign(:countdown_value, 3)
          |> assign(:error_message, nil)

        # Push event to JavaScript hook to start countdown
        socket = push_event(socket, "start_countdown", %{})

        {:noreply, socket}
    end
  end

  # Camera ready event
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

  # Camera error event
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

  # Recording progress from JavaScript
  @impl true
  def handle_event("recording_progress", %{"elapsed" => elapsed}, socket) do
    IO.puts("=== RECORDING PROGRESS: #{elapsed}s ===")
    socket = assign(socket, :elapsed_time, elapsed)
    {:noreply, socket}
  end

  # Countdown updates from JavaScript
  @impl true
  def handle_event("countdown_update", %{"count" => count}, socket) do
    IO.puts("=== COUNTDOWN UPDATE: #{count} ===")

    socket = if count == 0 do
      socket
      |> assign(:recording_state, :recording)
      |> assign(:countdown_value, 0)
      |> assign(:elapsed_time, 0)
    else
      assign(socket, :countdown_value, count)
    end

    {:noreply, socket}
  end

  # Recording errors from JavaScript
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

  # Stop recording
  @impl true
  def handle_event("stop_recording", _params, socket) do
    IO.puts("=== STOP RECORDING IN COMPONENT ===")
    socket = assign(socket, :recording_state, :preview)
    {:noreply, socket}
  end

  # Retake video
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

  # Save video
  @impl true
  def handle_event("save_video", _params, socket) do
    IO.puts("=== SAVE VIDEO IN COMPONENT ===")

    socket =
      socket
      |> assign(:recording_state, :saving)
      |> assign(:upload_progress, 0)

    # Tell JavaScript to send the video blob
    socket = push_event(socket, "save_video", %{})

    {:noreply, socket}
  end

  # CRITICAL: Video blob ready - main upload handler
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

  # ============================================================================
  # FIXED: Video Upload Processing
  # ============================================================================

  defp handle_video_upload(socket, blob_data, mime_type, file_size, duration) do
    IO.puts("=== STARTING VIDEO UPLOAD ===")
    IO.puts("Blob data length: #{String.length(blob_data)}")
    IO.puts("MIME type: #{mime_type}")
    IO.puts("File size: #{file_size}")
    IO.puts("Duration: #{duration}")

    # Update progress
    socket = assign(socket, upload_progress: 25)

    case Base.decode64(blob_data) do
      {:ok, video_data} ->
        IO.puts("✅ Base64 decode successful, video data size: #{byte_size(video_data)}")
        socket = assign(socket, upload_progress: 50)

        # Validate file size (max 50MB)
        max_size = 50 * 1024 * 1024

        if file_size > max_size do
          IO.puts("❌ File too large: #{file_size} > #{max_size}")
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

          IO.puts("📁 Saving as: #{filename}")
          socket = assign(socket, upload_progress: 75)

          case save_video_file(filename, video_data, socket.assigns.portfolio, duration) do
            {:ok, saved_file_info} ->
              IO.puts("✅ Video saved successfully!")
              socket = assign(socket, upload_progress: 100)

              # Create video intro section in portfolio
              case create_portfolio_video_section(socket.assigns.portfolio, saved_file_info.file_path, saved_file_info.filename, duration) do
                {:ok, section_info} ->
                  IO.puts("✅ Video section created successfully!")

                  # Reset component state
                  socket =
                    socket
                    |> assign(
                      recording_state: :setup,
                      elapsed_time: 0,
                      countdown_timer: 3,
                      upload_progress: 0
                    )
                    |> put_flash(:info, "Video introduction saved successfully!")

                  # CRITICAL: Notify parent LiveView about completion
                  send(self(), {:video_intro_complete, %{
                    "section_id" => section_info.id,
                    "video_path" => saved_file_info.file_path,
                    "filename" => saved_file_info.filename,
                    "duration" => duration,
                    "portfolio_id" => socket.assigns.portfolio.id
                  }})

                  {:noreply, socket}

                {:error, section_error} ->
                  IO.puts("❌ Section creation failed: #{section_error}")
                  socket =
                    socket
                    |> assign(recording_state: :preview, upload_progress: 0)
                    |> put_flash(:error, "Failed to save video to portfolio: #{section_error}")

                  {:noreply, socket}
              end

            {:error, save_error} ->
              IO.puts("❌ Save failed: #{save_error}")
              socket =
                socket
                |> assign(recording_state: :preview, upload_progress: 0)
                |> put_flash(:error, "Failed to save video: #{save_error}")

              {:noreply, socket}
          end
        end

      {:error, decode_error} ->
        IO.puts("❌ Base64 decode failed: #{inspect(decode_error)}")
        socket =
          socket
          |> assign(recording_state: :preview, upload_progress: 0)
          |> put_flash(:error, "Invalid video data. Please try recording again.")

        {:noreply, socket}
    end
  end

  # ============================================================================
  # FIXED: File Saving and Portfolio Section Creation
  # ============================================================================

  defp save_video_file(filename, video_data, portfolio, duration) do
    try do
      # Create upload directory if it doesn't exist
      upload_dir = Path.join(["priv", "static", "uploads", "videos"])
      File.mkdir_p!(upload_dir)

      file_path = Path.join(upload_dir, filename)

      # Write the video data
      case File.write(file_path, video_data) do
        :ok ->
          # Return success with file info
          {:ok, %{
            id: :crypto.strong_rand_bytes(16) |> Base.encode16(),
            file_path: file_path,
            filename: filename,
            file_size: byte_size(video_data),
            duration: duration
          }}

        {:error, reason} ->
          {:error, "Failed to write file: #{reason}"}
      end
    rescue
      error ->
        {:error, "File save error: #{Exception.message(error)}"}
    end
  end

    @impl true
  def update(%{theme: theme} = assigns, socket) do
    # Update header config based on theme
    header_config = %{
      header_config: %{
        video_style: get_video_style_for_theme(theme),
        show_social: true,
        show_metrics: false
      }
    }

    socket = socket
    |> assign(assigns)
    |> assign(:header_config, header_config)
    |> update_video_style_classes(header_config)

    {:ok, socket}
  end

  defp update_video_style_classes(socket, header_config) do
    video_style_classes = PortfolioTemplates.get_video_style_classes(header_config)
    assign(socket, :video_style_classes, video_style_classes)
  end

    @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  defp get_video_style_for_theme(theme) do
    case theme do
      "executive" -> "professional"
      "professional_executive" -> "executive"
      "creative_artistic" -> "artistic"
      "creative_designer" -> "showcase"
      "technical_developer" -> "terminal"
      "technical_engineer" -> "technical"
      "minimalist_clean" -> "minimal"
      "minimalist_elegant" -> "elegant"
      _ -> "professional"
    end
  end

  defp get_safe_header_config do
    # Provide a safe default header config
    %{
      header_config: %{
        video_style: "professional",
        show_social: true,
        show_metrics: false
      }
    }
  end

  # Create or update video intro section in portfolio
  defp create_portfolio_video_section(portfolio, video_path, filename, duration) do
    try do
      # Get existing sections to determine position
      existing_sections = Frestyl.Portfolios.list_portfolio_sections(portfolio.id)

      # Check for existing video intro section
      video_section = Enum.find(existing_sections, fn section ->
        section.title == "Video Introduction" or
        (section.content && Map.get(section.content, "video_type") == "introduction")
      end)

      # Convert absolute path to web-accessible path
      web_path = convert_to_web_path(video_path)

      section_attrs = %{
        portfolio_id: portfolio.id,
        title: "Video Introduction",
        section_type: "media_showcase",
        content: %{
          "title" => "Personal Introduction",
          "description" => "A personal video introduction showcasing my background and expertise.",
          "video_url" => web_path,
          "video_filename" => filename,
          "video_type" => "introduction",
          "duration" => duration,
          "auto_play" => false,
          "show_controls" => true,
          "created_at" => DateTime.utc_now() |> DateTime.to_iso8601()
        },
        visible: true
      }

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

  # Helper to convert file path to web-accessible path
  defp convert_to_web_path(file_path) do
    # Convert from "priv/static/uploads/videos/filename.webm"
    # to "/uploads/videos/filename.webm"
    case String.split(file_path, "static", parts: 2) do
      [_prefix, suffix] -> suffix
      _ ->
        # Fallback: extract just the filename and assume uploads/videos structure
        filename = Path.basename(file_path)
        "/uploads/videos/#{filename}"
    end
  end

  # Helper to increment positions of existing sections
  defp increment_existing_positions(portfolio_id) do
    sections = Frestyl.Portfolios.list_portfolio_sections(portfolio_id)

    Enum.each(sections, fn section ->
      Frestyl.Portfolios.update_section(section, %{position: section.position + 1})
    end)
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

  # Helper function to format recording time
  defp format_time(seconds) do
    minutes = div(seconds, 60)
    secs = rem(seconds, 60)
    "#{minutes}:#{String.pad_leading(Integer.to_string(secs), 2, "0")}"
  end

  # Helper to clean up recording state
  defp cleanup_recording_state(socket) do
    socket
    |> assign(:recording_state, :setup)
    |> assign(:elapsed_time, 0)
    |> assign(:countdown_timer, 3)
    |> assign(:countdown_value, 3)
    |> assign(:recorded_blob, nil)
    |> assign(:error_message, nil)
    |> assign(:upload_progress, 0)
  end

  # ============================================================================
  # UPDATE HANDLERS - Handle events forwarded from parent
  # ============================================================================

  @impl true
  def update(%{countdown_update_params: params}, socket) do
    case handle_event("countdown_update", params, socket) do
      {:noreply, updated_socket} -> {:ok, updated_socket}
      other -> other
    end
  end

  @impl true
  def update(%{recording_progress_params: params}, socket) do
    case handle_event("recording_progress", params, socket) do
      {:noreply, updated_socket} -> {:ok, updated_socket}
      other -> other
    end
  end

  @impl true
  def update(%{recording_error_params: params}, socket) do
    case handle_event("recording_error", params, socket) do
      {:noreply, updated_socket} -> {:ok, updated_socket}
      other -> other
    end
  end

  @impl true
  def update(%{camera_ready_params: params}, socket) do
    case handle_event("camera_ready", params, socket) do
      {:noreply, updated_socket} -> {:ok, updated_socket}
      other -> other
    end
  end

  @impl true
  def update(%{camera_error_params: params}, socket) do
    case handle_event("camera_error", params, socket) do
      {:noreply, updated_socket} -> {:ok, updated_socket}
      other -> other
    end
  end

  @impl true
  def update(%{video_blob_params: params}, socket) do
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

  # Timer messages - should be handled by component
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

  # Ignore other messages
  @impl true
  def handle_info(_, socket), do: {:noreply, socket}

  # ============================================================================
  # RENDER FUNCTIONS
  # ============================================================================

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
           data-component-id={@id}
           data-recording-state={@recording_state}
           phx-target={@myself}>

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

  # Setup Phase with better status indicators
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

  # Countdown Phase
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

  # Recording Phase
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

  # Preview Phase
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

  # Saving Phase
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

  defp get_video_style_classes_safe() do
    "rounded-xl border border-gray-200 shadow-lg"  # Safe default
  end
end
