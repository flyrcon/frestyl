# lib/frestyl_web/live/portfolio_live/enhanced_video_intro_component.ex
# Enhanced VideoIntroComponent with positioning controls and tier-based features

defmodule FrestylWeb.PortfolioLive.EnhancedVideoIntroComponent do
  use FrestylWeb, :live_component
  alias Frestyl.{Portfolios, Accounts}

  @impl true
  def mount(socket) do
    IO.puts("=== ENHANCED VIDEO INTRO COMPONENT MOUNTING ===")

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
      |> assign(:section_settings_visible, false)

    {:ok, socket}
  end

  @impl true
  def update(%{portfolio: portfolio, current_user: user} = assigns, socket) do
    # Get user subscription tier for quality settings
    user_tier = get_user_tier(user)

    # Check if video intro section already exists
    existing_video_section = get_existing_video_section(portfolio.id)

    # Get predefined positions for video placement
    available_positions = get_available_positions()
    current_position = get_current_video_position(existing_video_section)

    socket =
      socket
      |> assign(assigns)
      |> assign(:user_tier, user_tier)
      |> assign(:existing_video_section, existing_video_section)
      |> assign(:available_positions, available_positions)
      |> assign(:current_position, current_position)
      |> assign(:section_visible, get_section_visibility(existing_video_section))
      |> assign(:max_duration, get_max_duration_for_tier(user_tier))
      |> assign(:quality_info, get_quality_info_for_tier(user_tier))

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

  # ============================================================================
  # EVENT HANDLERS - CAMERA AND RECORDING
  # ============================================================================

  @impl true
  def handle_event("camera_ready", params, socket) do
    socket =
      socket
      |> assign(:camera_ready, true)
      |> assign(:camera_status, "ready")
      |> assign(:error_message, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("camera_error", params, socket) do
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

  defp get_user_tier(user) do
    cond do
      Map.has_key?(user, :subscription_tier) && user.subscription_tier ->
        user.subscription_tier
      Map.has_key?(user, :account) && user.account && Map.has_key?(user.account, :subscription_tier) ->
        user.account.subscription_tier
      true -> "free"
    end
  end

  defp get_max_duration_for_tier("free"), do: 60
  defp get_max_duration_for_tier("pro"), do: 120
  defp get_max_duration_for_tier("premium"), do: 180
  defp get_max_duration_for_tier(_), do: 60

  defp get_quality_info_for_tier("free") do
    %{resolution: "720p", bitrate: "1 Mbps", features: ["Basic recording"]}
  end
  defp get_quality_info_for_tier("pro") do
    %{resolution: "1080p", bitrate: "2.5 Mbps", features: ["HD recording", "File upload", "Extended duration"]}
  end
  defp get_quality_info_for_tier("premium") do
    %{resolution: "1080p", bitrate: "4 Mbps", features: ["HD recording", "File upload", "Extended duration", "Premium quality"]}
  end
  defp get_quality_info_for_tier(_), do: get_quality_info_for_tier("free")

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

  # ============================================================================
  # RENDER FUNCTIONS
  # ============================================================================

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-white rounded-xl shadow-2xl overflow-hidden max-w-5xl mx-auto">
      <!-- Enhanced Header with Position Controls -->
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
                <%= @quality_info.resolution %> • <%= @max_duration %>s max • <%= @user_tier |> String.capitalize() %> Tier
              </p>
            </div>
          </div>

          <div class="flex items-center space-x-2">
            <!-- Section Settings Toggle -->
            <%= if @existing_video_section do %>
              <button phx-click="toggle_section_settings" phx-target={@myself}
                      class={"text-white hover:text-purple-200 p-2 rounded-lg hover:bg-white hover:bg-opacity-10 transition-colors #{if @section_settings_visible, do: 'bg-white bg-opacity-20'}"}>
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"/>
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                </svg>
              </button>
            <% end %>

            <!-- Close Button -->
            <button phx-click="cancel_recording" phx-target={@myself}
                    class="text-white hover:text-purple-200 p-2 rounded-lg hover:bg-white hover:bg-opacity-10 transition-colors">
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>
        </div>

        <!-- Section Settings Panel -->
        <%= if @section_settings_visible && @existing_video_section do %>
          <div class="mt-4 p-4 bg-white bg-opacity-10 rounded-lg">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <!-- Position Control -->
              <div>
                <label class="block text-sm font-medium text-purple-100 mb-2">Video Position</label>
                <select phx-change="update_position" phx-target={@myself} name="position"
                        class="w-full px-3 py-2 bg-white bg-opacity-20 text-white rounded-lg border border-white border-opacity-30 focus:outline-none focus:ring-2 focus:ring-white focus:ring-opacity-50">
                  <%= for position <- @available_positions do %>
                    <option value={position.id} selected={@current_position == position.id}
                            class="text-gray-900">
                      <%= position.name %> - <%= position.description %>
                    </option>
                  <% end %>
                </select>
              </div>

              <!-- Visibility Toggle -->
              <div>
                <label class="block text-sm font-medium text-purple-100 mb-2">Visibility</label>
                <button phx-click="toggle_visibility" phx-target={@myself}
                        class={"w-full px-4 py-2 rounded-lg font-medium transition-colors #{if @section_visible, do: 'bg-green-600 hover:bg-green-700 text-white', else: 'bg-gray-600 hover:bg-gray-700 text-white'}"}>
                  <%= if @section_visible, do: "✅ Visible", else: "👁️ Hidden" %>
                </button>
              </div>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Main Content with Enhanced Hook Integration -->
      <div class="p-6"
           phx-hook="VideoCapture"
           id={"video-capture-#{@id}"}
           data-component-id={@id}
           data-recording-state={@recording_state}
           data-user-tier={@user_tier}
           phx-target={@myself}>

        <!-- Recording Mode Toggle for Pro Users -->
        <%= if @user_tier in ["pro", "premium"] do %>
          <div class="mb-6 flex justify-center">
            <div class="inline-flex rounded-lg bg-gray-100 p-1">
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
            <% :preview -> %>
              <%= render_preview_phase(assigns) %>
            <% :saving -> %>
              <%= render_saving_phase(assigns) %>
          <% end %>
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

  # ============================================================================
  # UTILITY FUNCTIONS
  # ============================================================================

  defp format_time(seconds) when is_integer(seconds) do
    minutes = div(seconds, 60)
    seconds = rem(seconds, 60)
    "#{String.pad_leading(to_string(minutes), 2, "0")}:#{String.pad_leading(to_string(seconds), 2, "0")}"
  end
  defp format_time(_), do: "00:00"

  defp find_position_name(position_id, available_positions) do
    case Enum.find(available_positions, &(&1.id == position_id)) do
      %{name: name} -> name
      _ -> "Hero Section"
    end
  end

  # Missing event handlers for completeness
  @impl true
  def handle_event("cancel_recording", _params, socket) do
    send(self(), {:close_video_intro_modal, %{}})
    {:noreply, socket}
  end

  @impl true
  def handle_event("stop_recording", _params, socket) do
    socket = assign(socket, :recording_state, :preview)
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
