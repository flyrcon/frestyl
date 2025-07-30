# lib/frestyl_web/live/portfolio_live/enhanced_video_intro_component.ex
# Enhanced VideoIntroComponent with positioning controls and tier-based features

defmodule FrestylWeb.PortfolioLive.EnhancedVideoIntroComponent do
  use FrestylWeb, :live_component
  alias Frestyl.{Portfolios, Accounts}
  alias Frestyl.Features.TierManager

  @impl true
  def mount(socket) do
    {:ok,
    socket
    |> assign(:recording_state, :setup)
    |> assign(:countdown, 0)
    |> assign(:recording_time, 0)
    |> assign(:camera_ready, false)
    |> assign(:video_blob, nil)
    |> assign(:camera_error, nil)
    |> assign(:is_saving, false)
    |> assign(:upload_progress, 0)
    |> assign(:processing_video, false)
    |> assign(:video_constraints, %{
        "video" => %{
          "width" => %{"ideal" => 1280},
          "height" => %{"ideal" => 720},
          "frameRate" => %{"ideal" => 30}
        },
        "audio" => true
      })
    |> assign(:show_menu, false)  # Add menu state
    |> assign(:menu_loading, false)}  # Add loading state
  end


  @impl true
  def update(assigns, socket) do
    socket = socket
    |> assign(assigns)
    |> assign(:recording_state, :idle)
    |> assign(:countdown, nil)
    |> assign(:recording_duration, 0)
    |> assign(:camera_status, :initializing)
    |> assign(:error_message, nil)

    {:ok, socket}
  end

  # ============================================================================
  # EVENT HANDLERS - SECTION MANAGEMENT
  # ============================================================================

  @impl true
  def handle_event("toggle_section_settings", _params, socket) do
    visible = !socket.assigns.section_settings_visible
    {:noreply, assign(socket, :section_settings_visible, visible)}
  end

  @impl true
  def handle_event("update_position", %{"position" => position}, socket) do
    case update_video_section_position(socket.assigns.existing_video_section, position) do
      {:ok, updated_section} ->
        socket =
          socket
          |> assign(:existing_video_section, updated_section)
          |> assign(:current_position, position)
          |> put_flash(:info, "Video position updated successfully")

        # Notify parent to refresh sections
        send(self(), {:refresh_portfolio_sections, %{}})

        {:noreply, socket}

      {:error, reason} ->
        socket = put_flash(socket, :error, "Failed to update position: #{reason}")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_visibility", _params, socket) do
    current_visibility = socket.assigns.section_visible
    new_visibility = !current_visibility

    case update_video_section_visibility(socket.assigns.existing_video_section, new_visibility) do
      {:ok, updated_section} ->
        socket =
          socket
          |> assign(:existing_video_section, updated_section)
          |> assign(:section_visible, new_visibility)
          |> put_flash(:info, if(new_visibility, do: "Video is now visible", else: "Video is now hidden"))

        # Notify parent to refresh sections
        send(self(), {:refresh_portfolio_sections, %{}})

        {:noreply, socket}

      {:error, reason} ->
        socket = put_flash(socket, :error, "Failed to update visibility: #{reason}")
        {:noreply, socket}
    end
  end

  # ============================================================================
  # EVENT HANDLERS - RECORDING CONTROLS
  # ============================================================================

    @impl true
  def handle_event("camera_initialized", _params, socket) do
    IO.puts("📹 Camera initialized successfully")

    socket = socket
    |> assign(:camera_status, :ready)
    |> assign(:error_message, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("camera_error", %{"error" => error}, socket) do
    IO.puts("❌ Camera error: #{error}")

    socket = socket
    |> assign(:camera_status, :error)
    |> assign(:error_message, "Camera access failed: #{error}")

    {:noreply, socket}
  end

  @impl true
  def handle_event("start_countdown", _params, socket) do
    if socket.assigns.camera_status == :ready do
      IO.puts("⏰ Starting countdown...")

      # Start the countdown process
      socket = socket
      |> assign(:recording_state, :countdown)
      |> assign(:countdown, 3)

      # Send countdown update event to hook
      send(self(), {:countdown_tick, socket.assigns.id})

      {:noreply, socket}
    else
      {:noreply, put_flash(socket, :error, "Camera not ready")}
    end
  end

  @impl true
  def handle_event("cancel_countdown", _params, socket) do
    IO.puts("❌ Countdown cancelled")

    socket = socket
    |> assign(:recording_state, :idle)
    |> assign(:countdown, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("countdown_complete", _params, socket) do
    IO.puts("🎬 Countdown complete, starting recording")

    socket = socket
    |> assign(:recording_state, :recording)
    |> assign(:countdown, nil)
    |> assign(:recording_duration, 0)

    # Send recording start event to hook
    send(self(), {:start_recording, socket.assigns.id})

    {:noreply, socket}
  end

  @impl true
  def handle_event("stop_recording", _params, socket) do
    IO.puts("⏹️ Stopping recording")

    socket = socket
    |> assign(:recording_state, :idle)
    |> assign(:recording_duration, 0)

    # Send stop recording event to hook
    send(self(), {:stop_recording, socket.assigns.id})

    {:noreply, socket}
  end

  @impl true
  def handle_event("recording_update", %{"duration" => duration}, socket) do
    socket = assign(socket, :recording_duration, duration)
    {:noreply, socket}
  end

  # Handle countdown tick messages
  @impl true
  def handle_info({:countdown_tick, component_id}, socket) do
    if socket.assigns.id == component_id && socket.assigns.recording_state == :countdown do
      current_countdown = socket.assigns.countdown

      if current_countdown > 1 do
        # Continue countdown
        socket = assign(socket, :countdown, current_countdown - 1)
        Process.send_after(self(), {:countdown_tick, component_id}, 1000)
        {:noreply, socket}
      else
        # Countdown finished, start recording
        handle_event("countdown_complete", %{}, socket)
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:start_recording, component_id}, socket) do
    if socket.assigns.id == component_id do
      # Push event to JavaScript hook to start recording
      send_update_after(self(), __MODULE__, %{id: socket.assigns.id}, 0)
      {:noreply, push_event(socket, "start-recording", %{component_id: component_id})}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:stop_recording, component_id}, socket) do
    if socket.assigns.id == component_id do
      # Push event to JavaScript hook to stop recording
      {:noreply, push_event(socket, "stop-recording", %{component_id: component_id})}
    else
      {:noreply, socket}
    end
  end

  # Helper function to format recording duration
  defp format_duration(seconds) when is_integer(seconds) do
    minutes = div(seconds, 60)
    remaining_seconds = rem(seconds, 60)
    "#{String.pad_leading(to_string(minutes), 2, "0")}:#{String.pad_leading(to_string(remaining_seconds), 2, "0")}"
  end
  defp format_duration(_), do: "00:00"
######

    @impl true
  def handle_event("toggle_upload_mode", _params, socket) do
    if socket.assigns.user_tier in ["pro", "premium"] do
      upload_mode = !socket.assigns.upload_mode
      socket = assign(socket, :upload_mode, upload_mode)
      {:noreply, socket}
    else
      socket = put_flash(socket, :error, "Video upload is available for Pro users. Please upgrade your account.")
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("start_countdown", _params, socket) do
    cond do
      not socket.assigns.camera_ready ->
        socket = put_flash(socket, :error, "Camera not ready. Please allow camera access.")
        {:noreply, socket}

      socket.assigns.camera_status != "ready" ->
        socket = put_flash(socket, :error, "Camera is still initializing. Please wait.")
        {:noreply, socket}

      true ->
        socket =
          socket
          |> assign(:recording_state, :countdown)
          |> assign(:countdown_timer, 3)
          |> assign(:countdown_value, 3)
          |> assign(:error_message, nil)

        socket = push_event(socket, "start_countdown", %{})
        {:noreply, socket}
    end
  end

  @impl true
  def update(%{camera_status: :ready} = _assigns, socket) do
    IO.puts("🔥 Video component: Camera ready, transitioning to ready state")
    {:ok, socket
    |> assign(:camera_ready, true)
    |> assign(:recording_state, :ready)}
  end

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  # ============================================================================
  # EVENT HANDLERS - CAMERA AND RECORDING
  # ============================================================================

  @impl true
  def handle_event("camera_ready", params, socket) do
    component_id = "video-intro-recorder-modal-#{socket.assigns.portfolio.id}"
    IO.puts("🔥 Camera ready for component: #{component_id}")

    # Forward to the video component with correct ID
    send_update(FrestylWeb.PortfolioLive.EnhancedVideoIntroComponent,
      id: component_id,
      camera_status: :ready)

    {:noreply, socket}
  end

  @impl true
  def handle_event("camera_error", params, socket) do
    component_id = "video-intro-recorder-modal-#{socket.assigns.portfolio.id}"
    error = Map.get(params, "error", "Unknown camera error")
    IO.puts("❌ Camera error for component #{component_id}: #{error}")

    # Forward to the video component with correct ID
    send_update(FrestylWeb.PortfolioLive.EnhancedVideoIntroComponent,
      id: component_id,
      camera_status: :error,
      error_message: error)

    {:noreply, socket
    |> put_flash(:error, "Camera access failed: #{error}")}
  end

  @impl true
  def handle_event("start_recording", _params, socket) do
    IO.puts("🔥 Starting video recording")
    {:noreply, assign(socket, :recording_state, :recording)}
  end

  @impl true
  def handle_event("stop_recording", _params, socket) do
    IO.puts("🔥 Stopping video recording")
    {:noreply, assign(socket, :recording_state, :processing)}
  end

  @impl true
  def handle_event("recording_progress", %{"elapsed" => elapsed}, socket) do
    socket = assign(socket, :elapsed_time, elapsed)
    {:noreply, socket}
  end

  @impl true
  def handle_event("countdown_update", %{"count" => count}, socket) do
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

  @impl true
  def handle_event("video_blob_ready", params, socket) do
    case params do
      %{
        "blob_data" => blob_data,
        "mime_type" => mime_type,
        "file_size" => file_size,
        "duration" => duration,
        "user_tier" => user_tier
      } when is_binary(blob_data) ->

        # Include quality and tier information
        upload_type = Map.get(params, "upload_type", "recording")
        quality = Map.get(params, "quality", "720p")

        handle_video_upload(socket, blob_data, mime_type, file_size, duration, %{
          user_tier: user_tier,
          quality: quality,
          upload_type: upload_type,
          filename: Map.get(params, "filename")
        })

      %{"success" => false, "error" => error} ->
        socket =
          socket
          |> assign(:recording_state, :setup)
          |> assign(:upload_progress, 0)
          |> put_flash(:error, "Recording failed: #{error}")

        {:noreply, socket}

      _ ->
        socket =
          socket
          |> assign(:recording_state, :setup)
          |> assign(:upload_progress, 0)
          |> put_flash(:error, "Invalid video data received")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_menu", _params, socket) do
    {:noreply, assign(socket, :show_menu, not socket.assigns.show_menu)}
  end

  @impl true
  def handle_event("close_menu", _params, socket) do
    {:noreply, assign(socket, :show_menu, false)}
  end

  @impl true
  def handle_event("test_camera", _params, socket) do
    {:noreply,
    socket
    |> assign(:menu_loading, true)
    |> assign(:show_menu, false)
    |> push_event("test-camera", %{})}
  end

  @impl true
  def handle_event("retry_camera", _params, socket) do
    {:noreply,
    socket
    |> assign(:camera_error, nil)
    |> assign(:camera_ready, false)
    |> assign(:processing_video, true)
    |> push_event("initialize-camera", socket.assigns.video_constraints)}
  end

  @impl true
  def handle_event("reset_recording", _params, socket) do
    {:noreply,
    socket
    |> assign(:recording_state, :setup)
    |> assign(:video_blob, nil)
    |> assign(:recording_time, 0)
    |> assign(:countdown, 0)
    |> assign(:show_menu, false)
    |> push_event("reset-camera", %{})}
  end

  # ============================================================================
  # VIDEO UPLOAD PROCESSING
  # ============================================================================

  defp handle_video_upload(socket, blob_data, mime_type, file_size, duration, metadata) do
    case Base.decode64(blob_data) do
      {:ok, video_data} ->
        portfolio = socket.assigns.portfolio
        user_tier = metadata.user_tier

        # Generate filename with tier and quality info
        timestamp = System.system_time(:second)
        quality_suffix = metadata.quality || "720p"
        filename = case metadata.upload_type do
          "file_upload" ->
            original_name = metadata.filename || "uploaded_video"
            "#{Path.rootname(original_name)}_#{portfolio.id}_#{timestamp}_#{quality_suffix}#{Path.extname(original_name)}"
          _ ->
            "portfolio_intro_#{portfolio.id}_#{timestamp}_#{quality_suffix}.webm"
        end

        case save_video_file(filename, video_data, portfolio, duration, metadata) do
          {:ok, saved_file_info} ->
            position = socket.assigns.current_position || "hero"

            case create_or_update_video_section(portfolio, saved_file_info, duration, position, metadata) do
              {:ok, section_info} ->
                socket =
                  socket
                  |> assign(:recording_state, :setup)
                  |> assign(:elapsed_time, 0)
                  |> assign(:upload_progress, 0)
                  |> assign(:existing_video_section, section_info)
                  |> put_flash(:info, "Video saved successfully!")

                # Notify parent about completion
                send(self(), {:video_intro_complete, %{
                  "section_id" => section_info.id,
                  "video_path" => saved_file_info.file_path,
                  "filename" => saved_file_info.filename,
                  "duration" => duration,
                  "quality" => metadata.quality,
                  "user_tier" => user_tier,
                  "portfolio_id" => portfolio.id
                }})

                {:noreply, socket}

              {:error, section_error} ->
                socket =
                  socket
                  |> assign(:recording_state, :preview)
                  |> assign(:upload_progress, 0)
                  |> put_flash(:error, "Failed to save video to portfolio: #{section_error}")

                {:noreply, socket}
            end

          {:error, save_error} ->
            socket =
              socket
              |> assign(:recording_state, :preview)
              |> assign(:upload_progress, 0)
              |> put_flash(:error, "Failed to save video: #{save_error}")

            {:noreply, socket}
        end

      {:error, _decode_error} ->
        socket =
          socket
          |> assign(:recording_state, :preview)
          |> assign(:upload_progress, 0)
          |> put_flash(:error, "Invalid video data. Please try recording again.")

        {:noreply, socket}
    end
  end

  # ============================================================================
  # SECTION MANAGEMENT HELPERS
  # ============================================================================

  defp get_existing_video_section(portfolio_id) do
    Portfolios.list_portfolio_sections(portfolio_id)
    |> Enum.find(fn section ->
      section.section_type == :media_showcase and
      Map.get(section.content || %{}, "video_type") == "introduction"
    end)
  end

  defp get_available_positions do
    [
      %{id: "hero", name: "Hero Section", description: "Top of portfolio (most prominent)"},
      %{id: "sidebar", name: "Sidebar", description: "Side panel placement"},
      %{id: "about", name: "About Section", description: "Within about/intro content"},
      %{id: "footer", name: "Footer", description: "Bottom of portfolio"}
    ]
  end

  defp get_current_video_position(nil), do: "hero"
  defp get_current_video_position(section) do
    Map.get(section.content || %{}, "position", "hero")
  end

  defp get_section_visibility(nil), do: true
  defp get_section_visibility(section) do
    Map.get(section.content || %{}, "visible", true)
  end

  defp update_video_section_position(nil, _position), do: {:error, "No video section found"}
  defp update_video_section_position(section, position) do
    updated_content = Map.put(section.content || %{}, "position", position)
    Portfolios.update_section(section, %{content: updated_content})
  end

  defp update_video_section_visibility(nil, _visibility), do: {:error, "No video section found"}
  defp update_video_section_visibility(section, visibility) do
    updated_content = Map.put(section.content || %{}, "visible", visibility)
    # Also update the section's visible field for compatibility
    Portfolios.update_section(section, %{content: updated_content, visible: visibility})
  end

  # ============================================================================
  # TIER-BASED SETTINGS
  # ============================================================================

  defp get_user_subscription_tier(user) do
    TierManager.get_user_tier(user)
  end

  defp get_max_duration_for_tier(tier) do
    normalized = TierManager.normalize_tier(tier)
    limits = TierManager.get_tier_limits(normalized)

    # Convert video recording minutes to seconds
    case limits.video_recording_minutes do
      :unlimited -> 600  # 10 minutes default for unlimited
      minutes when is_integer(minutes) -> minutes * 60
      _ -> 60  # 1 minute fallback
    end
  end

  defp get_quality_info_for_tier(tier) do
    normalized = TierManager.normalize_tier(tier)

    case normalized do
      "personal" ->
        %{resolution: "720p", bitrate: "1 Mbps", features: ["Basic recording"]}
      "creator" ->
        %{resolution: "1080p", bitrate: "2.5 Mbps", features: ["HD recording", "File upload", "Extended duration"]}
      "professional" ->
        %{resolution: "1080p", bitrate: "4 Mbps", features: ["HD recording", "File upload", "Extended duration", "Premium quality"]}
      "enterprise" ->
        %{resolution: "4K", bitrate: "8 Mbps", features: ["4K recording", "File upload", "Unlimited duration", "Enterprise quality"]}
      _ ->
        get_quality_info_for_tier("personal")
    end
  end

  # ============================================================================
  # FILE SAVING AND SECTION CREATION
  # ============================================================================

  defp save_video_file(filename, video_data, portfolio, duration, metadata) do
    try do
      upload_dir = Path.join(["priv", "static", "uploads", "videos"])
      File.mkdir_p!(upload_dir)

      file_path = Path.join(upload_dir, filename)

      case File.write(file_path, video_data) do
        :ok ->
          {:ok, %{
            id: :crypto.strong_rand_bytes(16) |> Base.encode16(),
            file_path: file_path,
            filename: filename,
            file_size: byte_size(video_data),
            duration: duration,
            quality: metadata.quality || "720p",
            user_tier: metadata.user_tier,
            upload_type: metadata.upload_type || "recording"
          }}

        {:error, reason} ->
          {:error, "Failed to write file: #{reason}"}
      end
    rescue
      error ->
        {:error, "File save error: #{Exception.message(error)}"}
    end
  end

  defp create_or_update_video_section(portfolio, video_info, duration, position, metadata) do
    try do
      existing_sections = Portfolios.list_portfolio_sections(portfolio.id)

      # Find existing video intro section
      video_section = Enum.find(existing_sections, fn section ->
        section.section_type == :media_showcase and
        Map.get(section.content || %{}, "video_type") == "introduction"
      end)

      web_path = convert_to_web_path(video_info.file_path)

      # Enhanced content with positioning and metadata
      section_content = %{
        "title" => "Personal Introduction",
        "description" => "A personal video introduction showcasing my background and expertise.",
        "video_url" => web_path,
        "video_filename" => video_info.filename,
        "video_type" => "introduction",
        "duration" => duration,
        "file_size" => video_info.file_size,
        "quality" => video_info.quality,
        "user_tier" => video_info.user_tier,
        "upload_type" => video_info.upload_type,
        "position" => position,
        "visible" => true,
        "created_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "updated_at" => DateTime.utc_now() |> DateTime.to_iso8601()
      }

      section_attrs = if video_section do
        # Update existing section
        %{
          content: Map.merge(video_section.content || %{}, section_content),
          updated_at: DateTime.utc_now()
        }
      else
        # Create new section with position-based ordering
        position_order = get_position_order(position)

        %{
          portfolio_id: portfolio.id,
          title: "Video Introduction",
          section_type: :media_showcase,
          content: section_content,
          position: position_order,
          visible: true
        }
      end

      if video_section do
        Portfolios.update_section(video_section, section_attrs)
      else
        Portfolios.create_section(section_attrs)
      end

    rescue
      error ->
        {:error, "Section creation failed: #{Exception.message(error)}"}
    end
  end

  defp get_position_order("hero"), do: 0
  defp get_position_order("about"), do: 1
  defp get_position_order("sidebar"), do: 999
  defp get_position_order("footer"), do: 1000
  defp get_position_order(_), do: 0

  defp convert_to_web_path(file_path) do
    try do
      if String.contains?(file_path, "priv/static") do
        file_path
        |> String.replace("priv/static", "")
        |> String.trim_leading("/")
        |> then(&("/#{&1}"))
      else
        "/uploads/videos/#{Path.basename(file_path)}"
      end
    rescue
      _ -> "/uploads/videos/#{Path.basename(file_path)}"
    end
  end

  defp format_recording_time(duration_seconds) when is_integer(duration_seconds) do
    minutes = div(duration_seconds, 60)
    seconds = rem(duration_seconds, 60)
    "#{String.pad_leading(to_string(minutes), 2, "0")}:#{String.pad_leading(to_string(seconds), 2, "0")}"
  end

  defp format_recording_time(_), do: "00:00"

  # ============================================================================
  # RENDER FUNCTIONS
  # ============================================================================

  @impl true
  def render(assigns) do
    ~H"""
    <div class="video-intro-component" id={"video-intro-#{@id}"}>
      <!-- Camera Preview -->
      <div class="camera-container mb-4">
        <video id={"camera-preview-#{@id}"}
               class="camera-preview w-full h-64 bg-gray-900 rounded-lg object-cover"
               muted
               playsinline
               phx-hook="VideoCapture"
               data-component-id={@id}>
        </video>

        <!-- Camera Status Overlay -->
        <div class="camera-status-overlay absolute inset-0 flex items-center justify-center"
             style={"display: #{if @camera_status == :ready, do: "none", else: "flex"}"}>
          <%= case @camera_status do %>
            <% :initializing -> %>
              <div class="text-center text-white">
                <svg class="animate-spin w-8 h-8 mx-auto mb-2" fill="none" viewBox="0 0 24 24">
                  <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                  <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                </svg>
                <p>Initializing camera...</p>
              </div>
            <% :error -> %>
              <div class="text-center text-red-300">
                <svg class="w-8 h-8 mx-auto mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z"/>
                </svg>
                <p>Camera access denied</p>
                <p class="text-sm">Please allow camera access and refresh</p>
              </div>
          <% end %>
        </div>
      </div>

      <!-- Recording Controls -->
      <div class="recording-controls flex flex-col items-center space-y-4">
        <!-- Countdown Display -->
        <%= if @countdown && @countdown > 0 do %>
          <div class="countdown-display">
            <div class="text-6xl font-bold text-blue-600 animate-pulse">
              <%= @countdown %>
            </div>
            <p class="text-gray-600">Get ready...</p>
          </div>
        <% end %>

        <!-- Recording Duration -->
        <%= if @recording_state == :recording do %>
          <div class="recording-duration flex items-center space-x-2 text-red-600">
            <div class="recording-dot w-3 h-3 bg-red-600 rounded-full animate-pulse"></div>
            <span class="font-mono">
              <%= format_duration(@recording_duration) %>
            </span>
          </div>
        <% end %>

        <!-- Control Buttons -->
        <div class="control-buttons flex space-x-4">
          <%= case @recording_state do %>
            <% :idle -> %>
              <button phx-click="start_countdown"
                      phx-target={@myself}
                      disabled={@camera_status != :ready}
                      class="px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors">
                <svg class="w-5 h-5 inline mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
                </svg>
                Start Recording
              </button>

            <% :countdown -> %>
              <button phx-click="cancel_countdown"
                      phx-target={@myself}
                      class="px-6 py-3 bg-gray-600 text-white rounded-lg hover:bg-gray-700 transition-colors">
                Cancel
              </button>

            <% :recording -> %>
              <button phx-click="stop_recording"
                      phx-target={@myself}
                      class="px-6 py-3 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors">
                <svg class="w-5 h-5 inline mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 10a1 1 0 011-1h4a1 1 0 011 1v4a1 1 0 01-1 1h-4a1 1 0 01-1-1v-4z"/>
                </svg>
                Stop Recording
              </button>
          <% end %>
        </div>

        <!-- Error Message -->
        <%= if @error_message do %>
          <div class="error-message bg-red-50 border border-red-200 rounded-lg p-3 text-red-800 text-sm">
            <%= @error_message %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end


  # ============================================================================
  # RENDER PHASE FUNCTIONS
  # ============================================================================

  defp render_upload_mode(assigns) do
    ~H"""
    <div class="space-y-6 text-center">
      <div class="w-16 h-16 mx-auto mb-4 bg-gradient-to-r from-blue-600 to-purple-600 rounded-full flex items-center justify-center">
        <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/>
        </svg>
      </div>

      <h4 class="text-2xl font-bold text-gray-900 mb-3">Upload Your Video</h4>
      <p class="text-gray-600 mb-6 max-w-2xl mx-auto leading-relaxed">
        Upload a pre-recorded introduction video. Supported formats: MP4, WebM, MOV.
        Maximum duration: <%= @max_duration %> seconds.
      </p>

      <!-- Upload Button -->
      <button phx-click="upload_video" phx-target={@myself}
              class="inline-flex items-center px-8 py-4 bg-blue-600 text-white text-lg font-semibold rounded-xl hover:bg-blue-700 transition-colors shadow-lg">
        <svg class="w-6 h-6 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/>
        </svg>
        Choose Video File
      </button>

      <!-- Upload Restrictions -->
      <div class="text-sm text-gray-500 space-y-1">
        <p>• Maximum file size: <%= if @user_tier == "premium", do: "100MB", else: "50MB" %></p>
        <p>• Maximum duration: <%= @max_duration %> seconds</p>
        <p>• Quality: <%= @quality_info.resolution %> recommended</p>
      </div>
    </div>
    """
  end

  defp render_setup_phase(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Enhanced Instructions with Tier Info -->
      <div class="text-center">
        <div class="w-12 h-12 mx-auto mb-4 bg-gradient-to-r from-purple-600 to-indigo-600 rounded-full flex items-center justify-center">
          <svg class="w-6 h-6 text-white" fill="currentColor" viewBox="0 0 20 20">
            <path d="M6.3 2.841A1.5 1.5 0 004 4.11V15.89a1.5 1.5 0 002.3 1.269l9.344-5.89a1.5 1.5 0 000-2.538L6.3 2.84z"/>
          </svg>
        </div>
        <h4 class="text-2xl font-bold text-gray-900 mb-3">Ready to record?</h4>
        <p class="text-gray-600 mb-4 max-w-2xl mx-auto leading-relaxed">
          Create a compelling <%= @max_duration %>-second introduction that showcases your personality and professional story.
        </p>

        <!-- Quality Badge -->
        <div class="inline-flex items-center px-3 py-1 bg-purple-100 text-purple-800 text-sm font-medium rounded-full mb-6">
          🎥 Recording in <%= @quality_info.resolution %> • <%= @quality_info.bitrate %>
        </div>
      </div>

      <!-- Camera Preview with Enhanced Status -->
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
                <% "permission_denied" -> %>
                  <svg class="w-16 h-16 text-red-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728L5.636 5.636m12.728 12.728L18.364 5.636"/>
                  </svg>
                  <p class="text-white text-lg font-semibold mb-2">Camera Access Denied</p>
                  <p class="text-gray-300 text-sm mb-4">Please allow camera access and refresh the page</p>
                <% _ -> %>
                  <svg class="w-16 h-16 text-red-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
                  </svg>
                  <p class="text-white text-lg font-semibold mb-2">Camera Error</p>
                  <p class="text-gray-300 text-sm"><%= @error_message || "Please check your camera connection" %></p>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Enhanced Controls -->
      <div class="flex flex-col sm:flex-row items-center justify-center space-y-4 sm:space-y-0 sm:space-x-4">
        <button phx-click="start_countdown" phx-target={@myself}
                disabled={not @camera_ready}
                class={"px-8 py-4 text-lg font-semibold rounded-xl transition-all duration-200 #{if @camera_ready, do: 'bg-red-600 hover:bg-red-700 text-white shadow-lg hover:shadow-xl', else: 'bg-gray-300 text-gray-500 cursor-not-allowed'}"}>
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

        <button phx-click="cancel_recording" phx-target={@myself}
                class="px-6 py-3 bg-gray-600 text-white rounded-lg hover:bg-gray-700 transition-colors">
          Cancel
        </button>
      </div>
    </div>
    """
  end

  # Continue with other render functions...
  defp render_countdown_phase(assigns) do
    ~H"""
    <div class="text-center">
      <div class="relative bg-black rounded-xl overflow-hidden" style="aspect-ratio: 16/9;">
        <video id="camera-preview" autoplay muted playsinline
               class="w-full h-full object-cover" style="transform: scaleX(-1);">
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

      <div class="mt-6">
        <button phx-click="cancel_recording" phx-target={@myself}
                class="px-6 py-3 bg-gray-600 text-white rounded-lg hover:bg-gray-700 transition-colors">
          Cancel Recording
        </button>
      </div>
    </div>
    """
  end

  defp render_recording_phase(assigns) do
    ~H"""
    <div class="text-center">
      <div class="relative bg-black rounded-xl overflow-hidden" style="aspect-ratio: 16/9;">
        <video id="camera-preview" autoplay muted playsinline
               class="w-full h-full object-cover" style="transform: scaleX(-1);">
        </video>

        <!-- Recording Indicator -->
        <div class="absolute top-4 left-4 flex items-center bg-red-600 rounded-full px-4 py-2 shadow-lg">
          <div class="w-3 h-3 bg-white rounded-full mr-2 animate-pulse"></div>
          <span class="text-white font-bold text-sm">RECORDING</span>
        </div>

        <!-- Timer Display -->
        <div class="absolute top-4 right-4 bg-black bg-opacity-70 rounded-full px-4 py-2">
          <span class="text-white font-mono font-bold text-lg">
            <%= format_time(@elapsed_time) %> / <%= format_time(@max_duration) %>
          </span>
        </div>

        <!-- Progress Bar -->
        <div class="absolute bottom-4 left-4 right-4">
          <div class="w-full bg-black bg-opacity-50 rounded-full h-2">
            <div class="bg-red-600 h-2 rounded-full transition-all duration-1000"
                 style={"width: #{min(100, (@elapsed_time / @max_duration) * 100)}%"}></div>
          </div>
        </div>
      </div>

      <div class="mt-6">
        <button phx-click="stop_recording" phx-target={@myself}
                class="px-8 py-4 bg-red-600 text-white text-lg font-semibold rounded-xl hover:bg-red-700 transition-colors shadow-lg">
          <svg class="w-6 h-6 inline mr-2" fill="currentColor" viewBox="0 0 20 20">
            <rect x="6" y="6" width="8" height="8"/>
          </svg>
          Stop Recording
        </button>
      </div>
    </div>
    """
  end

  defp render_preview_phase(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="text-center">
        <h4 class="text-2xl font-bold text-gray-900 mb-4">Review Your Video</h4>
      </div>

      <!-- Video Preview -->
      <div class="relative bg-black rounded-xl overflow-hidden" style="aspect-ratio: 16/9;">
        <video id="video-preview" controls preload="metadata"
               class="w-full h-full object-cover">
          Your browser does not support the video tag.
        </video>
      </div>

      <!-- Video Info -->
      <div class="text-center text-sm text-gray-600 space-y-1">
        <p>Duration: <%= format_time(@elapsed_time) %></p>
        <p>Quality: <%= @quality_info.resolution %></p>
        <p>Position: <%= find_position_name(@current_position, @available_positions) %></p>
      </div>

      <!-- Action Buttons -->
      <div class="flex flex-col sm:flex-row items-center justify-center space-y-4 sm:space-y-0 sm:space-x-4">
        <button phx-click="save_video" phx-target={@myself}
                class="px-8 py-4 bg-green-600 text-white text-lg font-semibold rounded-xl hover:bg-green-700 transition-colors shadow-lg">
          <svg class="w-6 h-6 inline mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-3m-1 4l-3 3m0 0l-3-3m3 3V4"/>
          </svg>
          Save Video
        </button>

        <button phx-click="retake_video" phx-target={@myself}
                class="px-6 py-3 bg-gray-600 text-white rounded-lg hover:bg-gray-700 transition-colors">
          <svg class="w-5 h-5 inline mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
          </svg>
          Record Again
        </button>
      </div>
    </div>
    """
  end

  defp render_saving_phase(assigns) do
    ~H"""
    <div class="space-y-6 text-center">
      <div class="w-16 h-16 mx-auto mb-4 bg-gradient-to-r from-green-600 to-blue-600 rounded-full flex items-center justify-center">
        <svg class="w-8 h-8 text-white animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
        </svg>
      </div>

      <h4 class="text-2xl font-bold text-gray-900 mb-3">Saving Your Video...</h4>
      <p class="text-gray-600 mb-6">
        Processing your <%= @quality_info.resolution %> video and adding it to your portfolio.
      </p>

      <!-- Progress Bar -->
      <div class="max-w-md mx-auto">
        <div class="w-full bg-gray-200 rounded-full h-3">
          <div class="bg-green-600 h-3 rounded-full transition-all duration-500"
               style={"width: #{@upload_progress}%"}></div>
        </div>
        <p class="text-sm text-gray-500 mt-2"><%= @upload_progress %>% Complete</p>
      </div>
    </div>
    """
  end

  defp render_camera_setup(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Camera Preview Area with Loading State -->
      <div class="relative bg-gray-900 rounded-xl overflow-hidden" style="aspect-ratio: 16/9;">
        <!-- Loading Overlay -->
        <%= if not @camera_ready do %>
          <div class="absolute inset-0 flex items-center justify-center bg-gray-900 z-10">
            <div class="text-center space-y-4">
              <div class="w-16 h-16 border-4 border-purple-500 border-t-transparent rounded-full animate-spin mx-auto"></div>
              <div class="text-white">
                <h4 class="font-medium mb-2">Initializing Camera...</h4>
                <p class="text-sm text-gray-300">Please allow camera access when prompted</p>
              </div>
            </div>
          </div>
        <% end %>

        <!-- FIXED: Video Element with proper hook registration -->
        <video
              id={"camera-preview-#{@id}"}
              class="w-full h-full object-cover"
              autoplay
              muted
              playsinline
              phx-hook="VideoCapture"
              data-component-id={@id}
              data-portfolio-id={@portfolio.id}>
        </video>

        <!-- Camera Error State -->
        <%= if @camera_error do %>
          <div class="absolute inset-0 flex items-center justify-center bg-red-900 bg-opacity-90 z-20">
            <div class="text-center space-y-4 text-white">
              <svg class="w-16 h-16 mx-auto text-red-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
              </svg>
              <div>
                <h4 class="font-medium mb-2">Camera Access Error</h4>
                <p class="text-sm text-red-200 mb-4"><%= @camera_error %></p>
                <button phx-click="retry_camera" phx-target={@myself}
                        class="bg-red-600 hover:bg-red-700 text-white px-4 py-2 rounded-lg transition-colors">
                  Try Again
                </button>
              </div>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Enhanced Controls with Loading States -->
      <div class="flex items-center justify-between">
        <div class="space-y-2">
          <h4 class="font-medium text-gray-900">Ready to record?</h4>
          <p class="text-sm text-gray-600">Position yourself in the frame and click start when ready</p>
        </div>

        <button phx-click="start_recording" phx-target={@myself}
                disabled={not @camera_ready or @processing_video}
                class="px-6 py-3 bg-red-600 text-white rounded-xl font-medium hover:bg-red-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center space-x-2">
          <%= if @processing_video do %>
            <svg class="w-5 h-5 animate-spin" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            <span>Preparing...</span>
          <% else %>
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
            </svg>
            <span>Start Recording</span>
          <% end %>
        </button>
      </div>

      <!-- Recording Tips -->
      <div class="bg-blue-50 border border-blue-200 rounded-lg p-4">
        <h5 class="font-medium text-blue-900 mb-2">📹 Recording Tips:</h5>
        <ul class="text-sm text-blue-800 space-y-1">
          <li>• Ensure good lighting on your face</li>
          <li>• Speak clearly and at a normal pace</li>
          <li>• Keep your introduction to 30-90 seconds</li>
          <li>• Look directly at the camera</li>
        </ul>
      </div>
    </div>
    """
  end

  defp render_countdown(assigns) do
    ~H"""
    <div class="text-center space-y-8">
      <div class="relative">
        <!-- Camera Preview -->
        <video id="camera-preview"
              class="w-full h-auto rounded-xl bg-gray-900"
              autoplay
              muted
              playsinline
              style="aspect-ratio: 16/9;">
        </video>

        <!-- Countdown Overlay -->
        <div class="absolute inset-0 flex items-center justify-center bg-black bg-opacity-50 rounded-xl">
          <div class="text-center">
            <div class="text-8xl font-bold text-white mb-4 animate-pulse">
              <%= @countdown %>
            </div>
            <p class="text-white text-xl">Get ready to record!</p>
          </div>
        </div>
      </div>

      <div class="flex justify-center">
        <button phx-click="cancel_recording" phx-target={@myself}
                class="px-6 py-3 bg-gray-600 text-white rounded-xl hover:bg-gray-700 transition-colors">
          Cancel
        </button>
      </div>
    </div>
    """
  end

  defp render_recording_interface(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Recording Preview -->
      <div class="relative bg-gray-900 rounded-xl overflow-hidden" style="aspect-ratio: 16/9;">
        <video
          id={"camera-preview-#{@id}"}
          class="w-full h-full object-cover"
          autoplay
          muted
          playsinline
          phx-hook="VideoCapture"
          data-component-id={@id}>
        </video>

        <!-- Recording Indicator -->
        <%= if @recording_state == :recording do %>
        <div class="absolute top-4 left-4 flex items-center space-x-2">
          <div class="w-4 h-4 bg-red-500 rounded-full animate-pulse"></div>
          <span class="text-white font-medium">REC</span>
        </div>
        <% end %>

        <!-- Recording Timer -->
        <%= if @recording_state in [:recording, :paused] do %>
          <div class="absolute top-4 right-4 bg-black bg-opacity-50 text-white px-3 py-1 rounded-lg text-sm font-mono">
            <%= format_recording_time(@recording_duration) %>
          </div>
        <% end %>

        <!-- Progress Bar -->
        <div class="absolute bottom-0 left-0 right-0 h-2 bg-black bg-opacity-30">
          <div class="h-full bg-red-500 transition-all duration-1000"
              style={"width: #{(@recording_time / @max_duration) * 100}%"}></div>
        </div>
      </div>

      <!-- Recording Controls -->
      <div class="flex items-center justify-center space-x-4">
        <%= if @recording_state == :ready do %>
          <button
            phx-click="start_recording"
            phx-target={@myself}
            class="bg-red-600 hover:bg-red-700 text-white px-6 py-3 rounded-lg font-medium transition-colors">
            <svg class="w-5 h-5 mr-2 inline" fill="currentColor" viewBox="0 0 20 20">
              <circle cx="10" cy="10" r="8"/>
            </svg>
            Start Recording
          </button>
        <% else %>
          <button
            phx-click="stop_recording"
            phx-target={@myself}
            class="bg-gray-600 hover:bg-gray-700 text-white px-6 py-3 rounded-lg font-medium transition-colors">
            <svg class="w-5 h-5 mr-2 inline" fill="currentColor" viewBox="0 0 20 20">
              <rect x="6" y="6" width="8" height="8"/>
            </svg>
            Stop Recording
          </button>
        <% end %>

        <button
          phx-click="close_modal"
          phx-target={@myself}
          class="bg-gray-300 hover:bg-gray-400 text-gray-700 px-6 py-3 rounded-lg font-medium transition-colors">
          Cancel
        </button>
      </div>

      <!-- Recording Info -->
      <div class="text-center text-sm text-gray-600">
        <p>Recording in progress... Speak clearly and look at the camera</p>
        <p>Maximum duration: <%= @max_duration %> seconds</p>
      </div>
    </div>
    """
  end

  defp render_preview(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Video Preview -->
      <div class="relative bg-gray-900 rounded-xl overflow-hidden" style="aspect-ratio: 16/9;">
        <video id="recorded-video"
              class="w-full h-full object-cover"
              controls
              preload="metadata">
          <source src={@video_blob} type="video/webm">
          Your browser does not support the video tag.
        </video>
      </div>

      <!-- Preview Controls -->
      <div class="flex items-center justify-between">
        <div class="space-y-1">
          <h4 class="font-medium text-gray-900">Review Your Recording</h4>
          <p class="text-sm text-gray-600">
            Duration: <%= format_time(@recording_time) %> •
            Quality: <%= @quality_info.resolution %>
          </p>
        </div>

        <div class="flex space-x-3">
          <button phx-click="retake_video" phx-target={@myself}
                  class="px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors">
            Retake
          </button>

          <button phx-click="save_video" phx-target={@myself}
                  disabled={@is_saving}
                  class="px-6 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors disabled:opacity-50 flex items-center space-x-2">
            <%= if @is_saving do %>
              <svg class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path>
              </svg>
              <span>Saving...</span>
            <% else %>
              <span>Save Video</span>
            <% end %>
          </button>
        </div>
      </div>

      <!-- Video Positioning Options -->
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
                    class="mr-3">
              <div>
                <p class="font-medium text-sm"><%= format_position_name(position) %></p>
                <p class="text-xs text-gray-600"><%= get_position_description(position) %></p>
              </div>
            </label>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp render_saving_state(assigns) do
    ~H"""
    <div class="text-center space-y-6">
      <div class="w-20 h-20 bg-green-100 rounded-2xl flex items-center justify-center mx-auto">
        <svg class="w-10 h-10 text-green-600 animate-pulse" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/>
        </svg>
      </div>

      <div>
        <h4 class="text-lg font-semibold text-gray-900 mb-2">Saving Your Video...</h4>

        <!-- Enhanced Progress Bar -->
        <div class="w-full bg-gray-200 rounded-full h-3 mb-4">
          <div class="bg-green-600 h-3 rounded-full transition-all duration-500"
              style={"width: #{@upload_progress}%"}></div>
        </div>

        <div class="space-y-2 text-sm text-gray-600">
          <p class={if @upload_progress >= 25, do: "text-green-600 font-medium", else: ""}>
            ✓ Processing video file...
          </p>
          <p class={if @upload_progress >= 50, do: "text-green-600 font-medium", else: ""}>
            ✓ Uploading to server...
          </p>
          <p class={if @upload_progress >= 75, do: "text-green-600 font-medium", else: ""}>
            ✓ Creating portfolio section...
          </p>
          <p class={if @upload_progress >= 100, do: "text-green-600 font-medium", else: ""}>
            ✓ Finalizing integration...
          </p>
        </div>

        <p class="text-xs text-gray-500 mt-4">This may take up to 30 seconds</p>
      </div>
    </div>
    """
  end

  defp render_completion(assigns) do
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

      <!-- Success Message -->
      <div class="bg-green-50 border border-green-200 rounded-lg p-4 text-left">
        <h5 class="font-medium text-green-800 mb-2">What's Next?</h5>
        <ul class="text-sm text-green-700 space-y-1">
          <li>• Your video will appear in the <%= format_position_name(@video_position || :about) %> section</li>
          <li>• You can preview your portfolio to see how it looks</li>
          <li>• Edit the video position anytime in section settings</li>
          <li>• Record additional videos for different sections</li>
        </ul>
      </div>
    </div>
    """
  end

  defp render_error_state(assigns) do
    ~H"""
    <div class="text-center space-y-6">
      <div class="w-20 h-20 bg-red-100 rounded-2xl flex items-center justify-center mx-auto">
        <svg class="w-10 h-10 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
        </svg>
      </div>

      <div>
        <h4 class="text-lg font-semibold text-gray-900 mb-2">Recording Failed</h4>
        <p class="text-gray-600 mb-6"><%= @camera_error || "An unexpected error occurred" %></p>

        <div class="space-y-3">
          <button phx-click="retry_recording" phx-target={@myself}
                  class="w-full bg-blue-600 text-white py-3 rounded-lg hover:bg-blue-700 transition-colors">
            Try Again
          </button>

          <button phx-click="close_modal" phx-target={@myself}
                  class="w-full border border-gray-300 text-gray-700 py-3 rounded-lg hover:bg-gray-50 transition-colors">
            Cancel
          </button>
        </div>
      </div>

      <!-- Troubleshooting Tips -->
      <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4 text-left">
        <h5 class="font-medium text-yellow-800 mb-2">Troubleshooting:</h5>
        <ul class="text-sm text-yellow-700 space-y-1">
          <li>• Ensure your camera is not being used by another application</li>
          <li>• Check that you've granted camera permissions to your browser</li>
          <li>• Try refreshing the page and trying again</li>
          <li>• Make sure you have a stable internet connection</li>
        </ul>
      </div>
    </div>
    """
  end


  # ============================================================================
  # UTILITY FUNCTIONS
  # ============================================================================

  defp format_time(seconds) when is_integer(seconds) do
    minutes = div(seconds, 60)
    remaining_seconds = rem(seconds, 60)
    "#{String.pad_leading(to_string(minutes), 2, "0")}:#{String.pad_leading(to_string(remaining_seconds), 2, "0")}"
  end

  defp format_time(_), do: "00:00"

  defp find_position_name(position_id, available_positions) do
    case Enum.find(available_positions, &(&1.id == position_id)) do
      %{name: name} -> name
      _ -> "Hero Section"
    end
  end

  defp format_position_name(:hero), do: "Hero Section"
  defp format_position_name(:about), do: "About Section"
  defp format_position_name(:footer), do: "Footer Section"
  defp format_position_name(_), do: "About Section"

  defp get_position_description(:hero), do: "Large video at the top of your portfolio"
  defp get_position_description(:about), do: "Personal introduction in your about section"
  defp get_position_description(:footer), do: "Closing video at the bottom of your portfolio"
  defp get_position_description(_), do: "Standard placement in your portfolio"

  # Missing event handlers for completeness
  @impl true
  def handle_event("cancel_recording", _params, socket) do
    send(self(), {:close_video_intro_modal, %{}})
    {:noreply, socket}
  end

  @impl true
  def handle_event("retake_video", _params, socket) do
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

  @impl true
  def handle_event("save_video", _params, socket) do
    socket =
      socket
      |> assign(:recording_state, :saving)
      |> assign(:upload_progress, 0)

    socket = push_event(socket, "save_video", %{})
    {:noreply, socket}
  end

  @impl true
  def handle_event("upload_video", _params, socket) do
    socket = push_event(socket, "upload_video", %{})
    {:noreply, socket}
  end
end
