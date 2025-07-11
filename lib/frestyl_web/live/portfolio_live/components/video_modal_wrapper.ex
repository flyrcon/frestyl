# CREATE NEW FILE: lib/frestyl_web/live/portfolio_live/components/video_modal_wrapper.ex

defmodule FrestylWeb.PortfolioLive.Components.VideoModalWrapper do
  use FrestylWeb, :live_component
  alias FrestylWeb.PortfolioLive.EnhancedVideoIntroComponent
  alias Frestyl.Portfolios.VideoThumbnails

  @impl true
  def mount(socket) do
    {:ok, socket
    |> assign(:modal_state, :loading)
    |> assign(:existing_video, nil)
    |> assign(:thumbnail_url, nil)
    |> assign(:show_enhanced_component, false)}
  end

  @impl true
  def update(%{portfolio: portfolio, current_user: user, show: show} = assigns, socket) do
    if show do
      # Check for existing video intro section using your existing function
      existing_video_section = get_existing_video_section(portfolio.id)

      {modal_state, video_info, thumbnail_url} = if existing_video_section do
        # Extract video info from section
        content = existing_video_section.content || %{}
        video_info = %{
          section: existing_video_section,
          title: Map.get(content, "title", "Personal Introduction"),
          video_url: Map.get(content, "video_url"),
          duration: Map.get(content, "duration", 0),
          filename: Map.get(content, "video_filename"),
          created_at: Map.get(content, "created_at")
        }

        # Get thumbnail using your existing system
        thumbnail_url = get_video_thumbnail_url(content)

        {:has_video, video_info, thumbnail_url}
      else
        {:no_video, nil, nil}
      end

      {:ok, socket
      |> assign(assigns)
      |> assign(:modal_state, modal_state)
      |> assign(:existing_video, video_info)
      |> assign(:thumbnail_url, thumbnail_url)
      |> assign(:show_enhanced_component, false)}
    else
      {:ok, socket
      |> assign(assigns)
      |> assign(:show_enhanced_component, false)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%= if @show do %>
      <div class="fixed inset-0 z-50 overflow-y-auto" role="dialog" aria-modal="true">
        <!-- Backdrop -->
        <div class="fixed inset-0 bg-black bg-opacity-50 backdrop-blur-sm transition-opacity"
             phx-click="close_video_modal" phx-target={@myself}></div>

        <!-- Modal Container -->
        <div class="flex min-h-screen items-center justify-center p-4">
          <div class="relative w-full max-w-4xl mx-auto bg-white rounded-2xl shadow-2xl transform transition-all">

            <!-- Close Button -->
            <button
              phx-click="close_video_modal"
              phx-target={@myself}
              class="absolute top-4 right-4 z-10 p-2 text-gray-400 hover:text-gray-600 hover:bg-gray-100 rounded-full transition-colors">
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>

            <!-- Modal Content -->
            <%= if @show_enhanced_component do %>
              <!-- Show your existing EnhancedVideoIntroComponent -->
              <.live_component
                module={EnhancedVideoIntroComponent}
                id="video-intro-enhanced"
                portfolio={@portfolio}
                current_user={@current_user} />
            <% else %>
              <%= case @modal_state do %>
                <% :loading -> %>
                  <%= render_loading_state(assigns) %>
                <% :no_video -> %>
                  <%= render_no_video_state(assigns) %>
                <% :has_video -> %>
                  <%= render_has_video_state(assigns) %>
              <% end %>
            <% end %>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  # ============================================================================
  # RENDER STATE FUNCTIONS
  # ============================================================================

  defp render_loading_state(assigns) do
    ~H"""
    <div class="p-8 text-center">
      <div class="animate-spin w-8 h-8 border-4 border-purple-600 border-t-transparent rounded-full mx-auto mb-4"></div>
      <p class="text-gray-600">Loading video information...</p>
    </div>
    """
  end

  defp render_no_video_state(assigns) do
    ~H"""
    <div class="p-8 text-center space-y-6">
      <!-- Icon -->
      <div class="w-20 h-20 mx-auto bg-gradient-to-br from-purple-600 to-blue-600 rounded-full flex items-center justify-center">
        <svg class="w-10 h-10 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
        </svg>
      </div>

      <!-- Content -->
      <div>
        <h3 class="text-2xl font-bold text-gray-900 mb-2">Add Intro Video</h3>
        <p class="text-gray-600 max-w-md mx-auto">
          Create a personal video introduction to make your portfolio stand out.
          Record directly from your camera or upload an existing video.
        </p>
      </div>

      <!-- Action Buttons -->
      <div class="flex flex-col sm:flex-row gap-4 justify-center">
        <button
          phx-click="start_recording"
          phx-target={@myself}
          class="px-6 py-3 bg-purple-600 text-white rounded-xl font-semibold hover:bg-purple-700 transition-colors flex items-center justify-center space-x-2">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
          </svg>
          <span>Record New Video</span>
        </button>

        <button
          phx-click="upload_video"
          phx-target={@myself}
          class="px-6 py-3 bg-gray-100 text-gray-700 rounded-xl font-semibold hover:bg-gray-200 transition-colors flex items-center justify-center space-x-2">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/>
          </svg>
          <span>Upload Video</span>
        </button>
      </div>
    </div>
    """
  end

  defp render_has_video_state(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Video Preview Section -->
      <div class="p-6 border-b border-gray-200">
        <h3 class="text-xl font-bold text-gray-900 mb-4">Current Intro Video</h3>

        <div class="bg-black rounded-xl overflow-hidden" style="aspect-ratio: 16/9;">
          <%= if @existing_video.video_url do %>
            <!-- Video Player with Thumbnail -->
            <video
              class="w-full h-full object-cover cursor-pointer"
              poster={@thumbnail_url}
              controls
              preload="metadata"
              controlsList="nodownload">
              <source src={@existing_video.video_url} type="video/mp4" />
              <source src={@existing_video.video_url} type="video/webm" />
              <p class="text-white p-4 text-center">
                Your browser doesn't support video playback.
                <a href={@existing_video.video_url} class="underline text-blue-300">Download video</a>
              </p>
            </video>
          <% else %>
            <!-- Fallback thumbnail display -->
            <div class="w-full h-full bg-gray-800 flex items-center justify-center">
              <div class="text-center text-white">
                <svg class="w-16 h-16 mx-auto mb-2 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
                </svg>
                <p class="text-gray-300">Video preview unavailable</p>
              </div>
            </div>
          <% end %>
        </div>

        <!-- Video Info -->
        <div class="mt-4 grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
          <div>
            <span class="text-gray-500">Duration:</span>
            <span class="block font-medium"><%= format_duration(@existing_video.duration) %></span>
          </div>
          <div>
            <span class="text-gray-500">Filename:</span>
            <span class="block font-medium truncate"><%= @existing_video.filename || "Unknown" %></span>
          </div>
          <div>
            <span class="text-gray-500">Created:</span>
            <span class="block font-medium"><%= format_date(@existing_video.created_at) %></span>
          </div>
          <div>
            <span class="text-gray-500">Status:</span>
            <span class="block font-medium text-green-600">Active</span>
          </div>
        </div>
      </div>

      <!-- Action Buttons -->
      <div class="px-6 pb-6">
        <div class="flex flex-col sm:flex-row gap-4">
          <button
            phx-click="replace_video"
            phx-target={@myself}
            class="flex-1 px-6 py-3 bg-purple-600 text-white rounded-xl font-semibold hover:bg-purple-700 transition-colors flex items-center justify-center space-x-2">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
            </svg>
            <span>Replace Video</span>
          </button>

          <button
            phx-click="delete_video"
            phx-target={@myself}
            data-confirm="Are you sure you want to delete this intro video? This action cannot be undone."
            class="px-6 py-3 bg-red-600 text-white rounded-xl font-semibold hover:bg-red-700 transition-colors flex items-center justify-center space-x-2">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
            </svg>
            <span>Delete Video</span>
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
  def handle_event("close_video_modal", _params, socket) do
    send(self(), :close_video_modal)
    {:noreply, socket}
  end

  @impl true
  def handle_event("start_recording", _params, socket) do
    {:noreply, assign(socket, :show_enhanced_component, true)}
  end

  @impl true
  def handle_event("upload_video", _params, socket) do
    {:noreply, assign(socket, :show_enhanced_component, true)}
  end

  @impl true
  def handle_event("replace_video", _params, socket) do
    {:noreply, assign(socket, :show_enhanced_component, true)}
  end

  @impl true
  def handle_event("delete_video", _params, socket) do
    if socket.assigns.existing_video do
      case delete_existing_video_section(socket.assigns.existing_video.section) do
        {:ok, _} ->
          send(self(), {:video_deleted, socket.assigns.existing_video.section.id})
          send(self(), :close_video_modal)
          {:noreply, socket}

        {:error, reason} ->
          {:noreply, socket |> put_flash(:error, "Failed to delete video: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  # ============================================================================
  # HELPER FUNCTIONS (using your existing system)
  # ============================================================================

  defp get_existing_video_section(portfolio_id) do
    # Use your existing function from EnhancedVideoIntroComponent
    Frestyl.Portfolios.list_portfolio_sections(portfolio_id)
    |> Enum.find(fn section ->
      section.section_type == :media_showcase and
      Map.get(section.content || %{}, "video_type") == "introduction"
    end)
  end

  defp get_video_thumbnail_url(content) do
    case Map.get(content, "thumbnail") do
      %{"url" => url} -> url
      _ ->
        video_url = Map.get(content, "video_url")
        if video_url do
          # Use your existing thumbnail system
          VideoThumbnails.get_or_generate_thumbnail(content)
          |> case do
            %{url: url} -> url
            _ -> "/images/video-placeholder.jpg"
          end
        else
          "/images/video-placeholder.jpg"
        end
    end
  end

  defp delete_existing_video_section(section) do
    Frestyl.Portfolios.delete_section(section)
  end

  defp format_duration(duration) when is_number(duration) and duration > 0 do
    minutes = div(duration, 60)
    seconds = rem(duration, 60)
    "#{minutes}:#{String.pad_leading(to_string(seconds), 2, "0")}"
  end
  defp format_duration(_), do: "Unknown"

  defp format_date(nil), do: "Unknown"
  defp format_date(date_string) when is_binary(date_string) do
    case DateTime.from_iso8601(date_string) do
      {:ok, datetime, _} -> Calendar.strftime(datetime, "%b %d, %Y")
      _ -> "Unknown"
    end
  end
  defp format_date(_), do: "Unknown"
end
