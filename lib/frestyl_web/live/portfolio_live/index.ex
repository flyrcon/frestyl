defmodule FrestylWeb.PortfolioLive.Index do
  use FrestylWeb, :live_view

  alias Frestyl.Portfolios
  alias Frestyl.Portfolios.PortfolioTemplates
  alias Frestyl.Accounts
  alias FrestylWeb.PortfolioLive.VideoIntroComponent
  import FrestylWeb.Navigation, only: [nav: 1]


  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    portfolios = Portfolios.list_user_portfolios(user.id)
    limits = Portfolios.get_portfolio_limits(user)
    can_create = Portfolios.can_create_portfolio?(user)
    available_templates = Frestyl.Portfolios.PortfolioTemplates.available_templates()

    # Get dashboard analytics
    overview = Portfolios.get_user_portfolio_overview(user.id)

    # Get individual portfolio stats safely
    portfolio_stats = Enum.map(portfolios, fn portfolio ->
      stats = try do
        Portfolios.get_portfolio_analytics(portfolio.id, user.id)
      rescue
        _ ->
          %{total_visits: 0, unique_visitors: 0, last_visit: nil}
      end
      {portfolio.id, stats}
    end) |> Enum.into(%{})

    socket =
      socket
      |> assign(:page_title, "Portfolio Dashboard")
      |> assign(:portfolios, portfolios)
      |> assign(:limits, limits)
      |> assign(:can_create, can_create)
      |> assign(:overview, overview)
      |> assign(:portfolio_stats, portfolio_stats)
      |> assign(:show_create_modal, false)
      |> assign(:selected_template, nil)
      |> assign(:available_templates, available_templates)
      |> assign(:show_video_intro_modal, false)
      |> assign(:current_portfolio_for_video, nil)
      |> assign(:show_share_modal, false)
      |> assign(:selected_portfolio_for_share, nil)
      |> assign(:show_collaboration_modal, false)
      |> assign(:selected_portfolio_for_collab, nil)

    {:ok, socket}
  end

  # Additional helper function for safe stat access
  defp safe_get_stat(portfolio_id, stat_key, portfolio_stats) do
    case Map.get(portfolio_stats, portfolio_id) do
      nil -> 0
      stats -> Map.get(stats, stat_key, 0)
    end
  end

  # Helper for growth percentage calculation
  defp get_growth_percentage(current, previous) when previous > 0 do
    growth = ((current - previous) / previous) * 100
    Float.round(growth, 1)
  end
  defp get_growth_percentage(_, _), do: 0

  # Helper for growth styling
  defp growth_class(percentage) when percentage > 0, do: "text-green-600"
  defp growth_class(percentage) when percentage < 0, do: "text-red-600"
  defp growth_class(_), do: "text-gray-500"

  # Helper for collaboration URL
  defp portfolio_collaboration_url(token) do
    "#{FrestylWeb.Endpoint.url()}/p/#{token}?collaboration=true"
  end

  # Create Portfolio modal handlers
  @impl true
  def handle_event("show_create_modal", _params, socket) do
    if socket.assigns.can_create do
      {:noreply, assign(socket, show_create_modal: true, selected_template: "executive")}
    else
      {:noreply,
       socket
       |> put_flash(:error, "You've reached your portfolio limit of #{socket.assigns.limits.max_portfolios}. Upgrade to create more portfolios.")
       |> push_navigate(to: "/account/subscription")}
    end
  end

  @impl true
  def handle_event("hide_create_modal", _params, socket) do
    {:noreply, assign(socket, show_create_modal: false, selected_template: nil)}
  end

  # Prevent modal from closing when clicking inside
  @impl true
  def handle_event("prevent_close", _params, socket) do
    {:noreply, socket}
  end

  # Template selection handler
  @impl true
  def handle_event("select_template", %{"template" => template}, socket) do
    available_template_keys = Map.keys(socket.assigns.available_templates)

    if template in available_template_keys do
      {:noreply, assign(socket, selected_template: template)}
    else
      {:noreply, socket}
    end
  end

  # Collaboration handlers
  @impl true
  def handle_event("show_collaboration_modal", %{"portfolio_id" => portfolio_id}, socket) do
    portfolio = Portfolios.get_portfolio!(portfolio_id)

    if portfolio.user_id == socket.assigns.current_user.id do
      {:noreply,
       socket
       |> assign(:show_collaboration_modal, true)
       |> assign(:selected_portfolio_for_collab, portfolio)}
    else
      {:noreply, put_flash(socket, :error, "Unauthorized action.")}
    end
  end

  @impl true
  def handle_event("hide_collaboration_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_collaboration_modal, false)
     |> assign(:selected_portfolio_for_collab, nil)}
  end

  @impl true
  def handle_event("create_collaboration_link", %{"message" => message}, socket) do
    portfolio = socket.assigns.selected_portfolio_for_collab

    share_attrs = %{
      portfolio_id: portfolio.id,
      name: "#{socket.assigns.current_user.name || "User"} - Help Request",
      message: message,
      collaboration_type: "feedback_request",
      expires_at: DateTime.utc_now() |> DateTime.add(30, :day) # 30 days
    }

    case Portfolios.create_share(share_attrs) do
      {:ok, share} ->
        collaboration_url = portfolio_collaboration_url(share.token)

        {:noreply,
         socket
         |> assign(:show_collaboration_modal, false)
         |> assign(:selected_portfolio_for_collab, nil)
         |> put_flash(:info, "Collaboration link created! Share this link: #{collaboration_url}")
         |> push_event("copy_to_clipboard", %{text: collaboration_url})}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create collaboration link.")}
    end
  end

  # Create portfolio handler
  @impl true
  def handle_event("create_portfolio", %{"title" => title}, socket) do
    if String.trim(title) == "" do
      {:noreply, put_flash(socket, :error, "Portfolio title cannot be empty")}
    else
      user = socket.assigns.current_user
      template = socket.assigns.selected_template || "executive"

      # Generate slug from title
      slug = title
        |> String.downcase()
        |> String.replace(~r/[^a-z0-9\s-]/, "")
        |> String.replace(~r/\s+/, "-")
        |> String.slice(0, 50)

      portfolio_attrs = %{
        title: title,
        slug: slug,
        theme: template,
        customization: PortfolioTemplates.get_template_config(template),
        visibility: :private
      }

      case Portfolios.create_portfolio(user.id, portfolio_attrs) do
        {:ok, portfolio} ->
          portfolios = Portfolios.list_user_portfolios(user.id)
          can_create = Portfolios.can_create_portfolio?(user)

          {:noreply,
          socket
          |> assign(:portfolios, portfolios)
          |> assign(:can_create, can_create)
          |> assign(:show_create_modal, false)
          |> assign(:selected_template, nil)
          |> put_flash(:info, "Portfolio '#{portfolio.title}' created successfully!")
          |> push_navigate(to: "/portfolios/#{portfolio.id}/edit")}

        {:error, changeset} ->
          errors = changeset.errors |> Enum.map(fn {field, {msg, _}} -> "#{field} #{msg}" end) |> Enum.join(", ")
          {:noreply, put_flash(socket, :error, "Failed to create portfolio: #{errors}")}
      end
    end
  end

  # Share link handlers
  @impl true
  def handle_event("show_share_modal", %{"portfolio_id" => portfolio_id}, socket) do
    portfolio = Portfolios.get_portfolio!(portfolio_id)

    if portfolio.user_id == socket.assigns.current_user.id do
      {:noreply,
       socket
       |> assign(:show_share_modal, true)
       |> assign(:selected_portfolio_for_share, portfolio)}
    else
      {:noreply, put_flash(socket, :error, "Unauthorized action.")}
    end
  end

  @impl true
  def handle_event("hide_share_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_share_modal, false)
     |> assign(:selected_portfolio_for_share, nil)}
  end

  @impl true
  def handle_event("copy_share_link", %{"portfolio_id" => portfolio_id}, socket) do
    portfolio = Portfolios.get_portfolio!(portfolio_id)

    if portfolio.user_id == socket.assigns.current_user.id do
      share_url = "#{FrestylWeb.Endpoint.url()}/p/#{portfolio.slug}"

      {:noreply,
       socket
       |> assign(:show_share_modal, false)
       |> assign(:selected_portfolio_for_share, nil)
       |> put_flash(:info, "Share link copied to clipboard!")
       |> push_event("copy_to_clipboard", %{text: share_url})}
    else
      {:noreply, put_flash(socket, :error, "Unauthorized action.")}
    end
  end

  # Portfolio management handlers
  @impl true
  def handle_event("delete_portfolio", %{"id" => id}, socket) do
    portfolio = Portfolios.get_portfolio!(id)

    if portfolio.user_id == socket.assigns.current_user.id do
      case Portfolios.delete_portfolio(portfolio) do
        {:ok, _} ->
          portfolios = Portfolios.list_user_portfolios(socket.assigns.current_user.id)
          can_create = Portfolios.can_create_portfolio?(socket.assigns.current_user)
          overview = Portfolios.get_user_portfolio_overview(socket.assigns.current_user.id)

          {:noreply,
           socket
           |> assign(:portfolios, portfolios)
           |> assign(:can_create, can_create)
           |> assign(:overview, overview)
           |> put_flash(:info, "Portfolio deleted successfully.")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete portfolio.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Unauthorized action.")}
    end
  end

  @impl true
  def handle_event("toggle_discovery", %{"portfolio_id" => portfolio_id}, socket) do
    portfolio = Portfolios.get_portfolio!(portfolio_id)

    if portfolio.user_id == socket.assigns.current_user.id do
      new_visibility = case portfolio.visibility do
        :public -> :link_only
        _ -> :public
      end

      case Portfolios.update_portfolio(portfolio, %{visibility: new_visibility}) do
        {:ok, _} ->
          portfolios = Portfolios.list_user_portfolios(socket.assigns.current_user.id)

          flash_message = if new_visibility == :public do
            "Portfolio is now discoverable on Frestyl"
          else
            "Portfolio is now private (link-only access)"
          end

          {:noreply,
           socket
           |> assign(:portfolios, portfolios)
           |> put_flash(:info, flash_message)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to update visibility.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Unauthorized action.")}
    end
  end

  # Video intro events
  @impl true
  def handle_event("show_video_intro", %{"portfolio_id" => portfolio_id}, socket) do
    portfolio = Portfolios.get_portfolio!(portfolio_id)

    if portfolio.user_id == socket.assigns.current_user.id do
      {:noreply,
       socket
       |> assign(:show_video_intro_modal, true)
       |> assign(:current_portfolio_for_video, portfolio)}
    else
      {:noreply, put_flash(socket, :error, "Unauthorized action.")}
    end
  end

  # Video intro event handlers
  @impl true
  def handle_info({:close_video_modal, _}, socket) do
    {:noreply, assign(socket, show_video_intro_modal: false, current_portfolio_for_video: nil)}
  end

  @impl true
  def handle_info({:video_intro_complete, data}, socket) do
    {:noreply,
    socket
    |> assign(:show_video_intro_modal, false)
    |> assign(:current_portfolio_for_video, nil)
    |> put_flash(:info, "Video introduction saved successfully!")}
  end

  # FIXED: Handle string-based messages from component
  @impl true
  def handle_info({"hide_video_intro", _params}, socket) do
    {:noreply, assign(socket, show_video_intro_modal: false, current_portfolio_for_video: nil)}
  end

  @impl true
  def handle_info({"video_intro_complete", data}, socket) do
    {:noreply,
    socket
    |> assign(:show_video_intro_modal, false)
    |> assign(:current_portfolio_for_video, nil)
    |> put_flash(:info, "Video introduction saved successfully!")}
  end

  # FIXED: Timer messages (these should be handled by component, but add safety)
  @impl true
  def handle_info({:countdown_tick, _component_id}, socket) do
    # Component handles its own timers, just ignore
    {:noreply, socket}
  end

  @impl true
  def handle_info({:recording_tick, _component_id}, socket) do
    # Component handles its own timers, just ignore
    {:noreply, socket}
  end

  # Catch-all for any other unhandled messages
  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  # Forward camera events to the component
  @impl true
  def handle_event("camera_ready", params, socket) do
    if socket.assigns.show_video_intro_modal do
      send_update(FrestylWeb.PortfolioLive.VideoIntroComponent,
        id: "video-intro-#{socket.assigns.current_portfolio_for_video.id}",
        camera_ready: true)  # <- FIXED: Just pass true, not the params Map
    end
    {:noreply, socket}
  end

  @impl true
  def handle_event("camera_error", params, socket) do
    if socket.assigns.show_video_intro_modal do
      send_update(FrestylWeb.PortfolioLive.VideoIntroComponent,
        id: "video-intro-#{socket.assigns.current_portfolio_for_video.id}",
        camera_error: params)  # This is OK since we handle Maps in camera_error
    end
    {:noreply, socket}
  end

  @impl true
  def handle_event("start_countdown", _params, socket) do
    if socket.assigns.camera_ready do
      {:noreply, assign(socket, video_recording_state: :countdown, video_countdown: 3)}
    else
      {:noreply, put_flash(socket, :error, "Camera not ready. Please allow camera access.")}
    end
  end

  @impl true
  def handle_event("stop_recording", _params, socket) do
    {:noreply, assign(socket, video_recording_state: :preview)}
  end

  @impl true
  def handle_event("retake_video", _params, socket) do
    {:noreply, assign(socket, video_recording_state: :setup, video_elapsed_time: 0, video_error: nil)}
  end

  @impl true
  def handle_event("save_video", _params, socket) do
    {:noreply, assign(socket, video_recording_state: :saving)}
  end

  @impl true
  def handle_event("video_saved", %{"success" => true}, socket) do
    {:noreply,
    socket
    |> assign(:show_video_intro_modal, false)
    |> assign(:video_recording_state, :setup)
    |> assign(:video_elapsed_time, 0)
    |> put_flash(:info, "Video introduction saved successfully!")}
  end

  @impl true
  def handle_event("video_saved", %{"success" => false, "error" => error}, socket) do
    {:noreply,
    socket
    |> assign(:video_recording_state, :preview)
    |> put_flash(:error, "Failed to save video: #{error}")}
  end

  # Helper functions for the template:
  defp format_video_time(seconds) do
    minutes = div(seconds, 60)
    secs = rem(seconds, 60)
    "#{minutes}:#{String.pad_leading(Integer.to_string(secs), 2, "0")}"
  end

  # Helper functions
  defp portfolio_url(portfolio) do
    "#{FrestylWeb.Endpoint.url()}/p/#{portfolio.slug}"
  end

  defp has_intro_video?(portfolio) do
    Map.get(portfolio, :intro_video_id) != nil
  end

  defp format_date(datetime) when is_nil(datetime), do: "Never"
  defp format_date(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y")
  end

  defp format_number(num) when num >= 1000 do
    "#{Float.round(num / 1000, 1)}k"
  end
  defp format_number(num), do: to_string(num)

  defp portfolio_status_badge(portfolio) do
    case portfolio.visibility do
      :public -> {"bg-green-100 text-green-800", "🌍 Public"}
      :link_only -> {"bg-blue-100 text-blue-800", "🔗 Link Only"}
      :private -> {"bg-gray-100 text-gray-800", "🔒 Private"}
    end
  end

  # Helper function to get portfolio stats
  defp get_portfolio_stats(portfolio) do
    # This should return stats from your analytics system
    # For now, returning default values
    %{views: 0, shares: 0}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-gray-50 via-white to-purple-50">
      <!-- Navigation -->
      <header class="bg-white shadow-sm border-b border-gray-200 fixed top-0 left-0 right-0 z-40">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <.nav current_user={@current_user} active_tab={:portfolios} />
        </div>
      </header>

      <!-- Main Content -->
      <div class="pt-16 min-h-screen">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">

          <!-- Hero Section -->
          <div class="bg-white rounded-xl p-8 lg:p-12 shadow-md mb-8 relative overflow-hidden">
            <!-- Background pattern -->
            <div class="absolute inset-0 bg-gradient-to-r from-pink-50 to-purple-50 opacity-50"></div>
            <div class="h-1 bg-gradient-to-r from-pink-600 to-purple-600 rounded-full mb-8 relative z-10"></div>

            <div class="flex flex-col lg:flex-row lg:items-center lg:justify-between relative z-10">
              <div class="mb-6 lg:mb-0">
                <h1 class="text-4xl lg:text-5xl font-black text-gray-900 mb-4">
                  <span class="bg-gradient-to-r from-pink-600 via-purple-600 to-indigo-600 bg-clip-text text-transparent">
                    Your Professional Story
                  </span>
                </h1>
                <p class="text-gray-600 text-lg font-medium leading-relaxed max-w-2xl">
                  Create dynamic portfolios that go beyond traditional resumes. Show your work, tell your story, and connect with opportunities.
                </p>
              </div>

              <!-- Quick Stats -->
              <div class="grid grid-cols-2 gap-4 lg:gap-6">
                <div class="text-center">
                  <div class="text-2xl font-black text-pink-600"><%= length(@portfolios) %></div>
                  <div class="text-sm text-gray-600 font-medium">Portfolios</div>
                </div>
                <div class="text-center">
                  <div class="text-2xl font-black text-purple-600">
                    <%= @portfolios |> Enum.map(fn portfolio -> safe_get_stat(portfolio.id, :total_visits, @portfolio_stats) end) |> Enum.sum() %>
                  </div>
                  <div class="text-sm text-gray-600 font-medium">Total Views</div>
                </div>
              </div>
            </div>
          </div>

          <!-- Portfolio Grid -->
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8 mb-8">
            <!-- Existing Portfolios -->
            <%= for portfolio <- @portfolios do %>
              <div class="bg-white rounded-xl shadow-md hover:shadow-xl transition-all duration-300 transform hover:-translate-y-1 overflow-hidden">
                <!-- Portfolio Header -->
                <div class="h-2 bg-gradient-to-r from-purple-500 to-pink-500"></div>

                <div class="p-6">
                  <div class="flex items-start justify-between mb-4">
                    <div class="flex-1">
                      <h3 class="text-xl font-bold text-gray-900 mb-2"><%= portfolio.title %></h3>
                      <div class="flex items-center space-x-2 mb-3">
                        <% {badge_class, badge_text} = portfolio_status_badge(portfolio) %>
                        <span class={"px-2 py-1 rounded-full text-xs font-medium #{badge_class}"}>
                          <%= badge_text %>
                        </span>
                      </div>
                    </div>

                    <!-- Action Menu -->
                    <div class="flex items-center space-x-1">
                      <!-- Video Intro Button -->
                      <%= if has_intro_video?(portfolio) do %>
                        <button phx-click="show_video_intro" phx-value-portfolio_id={portfolio.id}
                                class="p-2 text-green-600 hover:bg-green-50 rounded-lg transition-colors"
                                title="Edit Video Introduction">
                          <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                            <path d="M6.3 2.841A1.5 1.5 0 004 4.11V15.89a1.5 1.5 0 002.3 1.269l9.344-5.89a1.5 1.5 0 000-2.538L6.3 2.84z"/>
                          </svg>
                        </button>
                      <% else %>
                        <button phx-click="show_video_intro" phx-value-portfolio_id={portfolio.id}
                                class="p-2 text-orange-600 hover:bg-orange-50 rounded-lg transition-colors"
                                title="Add Video Introduction">
                          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
                          </svg>
                        </button>
                      <% end %>

                      <!-- Visibility Toggle Button -->
                      <button phx-click="toggle_discovery" phx-value-portfolio_id={portfolio.id}
                              class={[
                                "p-2 rounded-lg transition-colors",
                                if portfolio.visibility == :public do
                                  "text-green-600 hover:bg-green-50"
                                else
                                  "text-gray-600 hover:bg-gray-50"
                                end
                              ]}
                              title={if portfolio.visibility == :public, do: "Hide from Discovery", else: "Make Discoverable"}>
                        <%= if portfolio.visibility == :public do %>
                          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
                          </svg>
                        <% else %>
                          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.878 9.878L3 3m6.878 6.878L21 21"/>
                          </svg>
                        <% end %>
                      </button>

                      <!-- Share Button -->
                      <button phx-click="show_share_modal" phx-value-portfolio_id={portfolio.id}
                              class="p-2 text-blue-600 hover:bg-blue-50 rounded-lg transition-colors"
                              title="Share Portfolio">
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.684 13.342C8.886 12.938 9 12.482 9 12c0-.482-.114-.938-.316-1.342m0 2.684a3 3 0 110-2.684m0 2.684l6.632 3.316m-6.632-6l6.632-3.316m0 0a3 3 0 105.367-2.684 3 3 0 00-5.367 2.684zm0 9.316a3 3 0 105.367 2.684 3 3 0 00-5.367-2.684z"/>
                        </svg>
                      </button>

                      <!-- Collaboration Button -->
                      <button phx-click="show_collaboration_modal" phx-value-portfolio_id={portfolio.id}
                              class="p-2 text-purple-600 hover:bg-purple-50 rounded-lg transition-colors"
                              title="Get Feedback">
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 8h2a2 2 0 012 2v6a2 2 0 01-2 2h-2v4l-4-4H9a2 2 0 01-2-2v-6a2 2 0 012-2h8z"/>
                        </svg>
                      </button>

                      <!-- Delete Button -->
                      <button phx-click="delete_portfolio" phx-value-id={portfolio.id}
                              data-confirm="Are you sure you want to delete this portfolio?"
                              class="p-2 text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                              title="Delete Portfolio">
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
                        </svg>
                      </button>
                    </div>
                  </div>

                  <!-- Portfolio Actions -->
                  <div class="space-y-3">
                    <.link href={"/portfolios/#{portfolio.id}/edit"}
                          class="w-full inline-flex items-center justify-center px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors">
                      <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
                      </svg>
                      Edit Portfolio
                    </.link>

                    <.link href={"/p/#{portfolio.slug}"} target="_blank"
                          class="w-full inline-flex items-center justify-center px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors">
                      <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/>
                      </svg>
                      View Live
                    </.link>
                  </div>

                  <!-- Portfolio Stats -->
                  <%= if stats = Map.get(@portfolio_stats, portfolio.id) do %>
                    <div class="mt-4 pt-4 border-t border-gray-200">
                      <div class="grid grid-cols-3 gap-4 text-center">
                        <div>
                          <div class="text-lg font-bold text-blue-600"><%= format_number(Map.get(stats, :total_visits, 0)) %></div>
                          <div class="text-xs text-gray-500">Views</div>
                        </div>
                        <div>
                          <div class="text-lg font-bold text-green-600"><%= format_number(Map.get(stats, :unique_visitors, 0)) %></div>
                          <div class="text-xs text-gray-500">Visitors</div>
                        </div>
                        <div>
                          <div class="text-lg font-bold text-purple-600">0</div>
                          <div class="text-xs text-gray-500">Feedback</div>
                        </div>
                      </div>
                      <%= if last_visit = Map.get(stats, :last_visit) do %>
                        <div class="mt-2 text-center">
                          <p class="text-xs text-gray-500">Last visit: <%= format_date(last_visit) %></p>
                        </div>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>

            <!-- Create New Portfolio Card -->
            <%= if @can_create do %>
              <div class="group bg-white rounded-xl shadow-md hover:shadow-xl transition-all duration-300 transform hover:-translate-y-1 overflow-hidden border-2 border-dashed border-gray-300 hover:border-pink-400 cursor-pointer"
                   phx-click="show_create_modal">
                <div class="h-1 bg-gradient-to-r from-yellow-500 to-orange-500 rounded-t-xl"></div>

                <div class="h-full flex items-center justify-center p-12">
                  <div class="text-center">
                    <div class="w-16 h-16 mx-auto mb-6 bg-gradient-to-r from-yellow-500 to-orange-500 rounded-full flex items-center justify-center group-hover:scale-110 transition-transform duration-300">
                      <svg class="h-8 w-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
                      </svg>
                    </div>
                    <h3 class="text-xl font-black text-gray-900 mb-2">Create New Portfolio</h3>
                    <p class="text-gray-600 text-sm">Start showcasing your professional story</p>
                  </div>
                </div>
              </div>
            <% else %>
              <!-- Upgrade Prompt Card -->
              <div class="group bg-gradient-to-br from-purple-600 to-indigo-600 rounded-xl shadow-md hover:shadow-xl transition-all duration-300 transform hover:-translate-y-1 overflow-hidden">
                <div class="h-full flex items-center justify-center p-12 text-center">
                  <div>
                    <div class="w-16 h-16 mx-auto mb-6 bg-white bg-opacity-20 rounded-full flex items-center justify-center">
                      <svg class="h-8 w-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
                      </svg>
                    </div>
                    <h3 class="text-xl font-black text-white mb-2">Upgrade Your Plan</h3>
                    <p class="text-purple-100 text-sm mb-4">Create more portfolios and unlock premium features</p>
                    <.link navigate="/account/subscription"
                          class="inline-flex items-center px-4 py-2 bg-white text-purple-600 font-bold text-sm rounded-lg hover:bg-gray-50 transition-all">
                      Upgrade Now
                    </.link>
                  </div>
                </div>
              </div>
            <% end %>
          </div>

          <!-- Plan Information -->
          <div class="bg-white rounded-xl shadow-md overflow-hidden">
            <div class="h-1 bg-gradient-to-r from-pink-600 to-purple-600 rounded-t-xl"></div>

            <div class="p-8 lg:p-12">
              <h2 class="text-3xl font-black text-gray-900 mb-8">Portfolio Plan</h2>

              <div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
                <!-- Portfolios Limit -->
                <div class="bg-gradient-to-br from-pink-50 to-purple-50 rounded-xl p-6 border border-pink-200">
                  <div class="flex items-center mb-4">
                    <div class="w-12 h-12 bg-gradient-to-r from-pink-600 to-purple-600 rounded-xl flex items-center justify-center mr-4">
                      <svg class="h-6 w-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>
                      </svg>
                    </div>
                    <h3 class="text-lg font-bold text-gray-900">Portfolios</h3>
                  </div>
                  <p class="text-2xl font-black text-pink-600 mb-2">
                    <%= length(@portfolios) %> / <%= if @limits.max_portfolios == -1, do: "∞", else: @limits.max_portfolios %>
                  </p>
                  <p class="text-sm text-gray-600">Active portfolios</p>
                </div>

                <!-- File Storage -->
                <div class="bg-gradient-to-br from-cyan-50 to-blue-50 rounded-xl p-6 border border-cyan-200">
                  <div class="flex items-center mb-4">
                    <div class="w-12 h-12 bg-gradient-to-r from-cyan-600 to-blue-600 rounded-xl flex items-center justify-center mr-4">
                      <svg class="h-6 w-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
                      </svg>
                    </div>
                    <h3 class="text-lg font-bold text-gray-900">File Storage</h3>
                  </div>
                  <p class="text-2xl font-black text-cyan-600 mb-2"><%= @limits.max_media_size_mb %>MB</p>
                  <p class="text-sm text-gray-600">Per upload limit</p>
                </div>

                <!-- Video Introductions -->
                <div class="bg-gradient-to-br from-green-50 to-emerald-50 rounded-xl p-6 border border-green-200">
                  <div class="flex items-center mb-4">
                    <div class="w-12 h-12 bg-gradient-to-r from-green-600 to-emerald-600 rounded-xl flex items-center justify-center mr-4">
                      <svg class="h-6 w-6 text-white" fill="currentColor" viewBox="0 0 20 20">
                        <path d="M6.3 2.841A1.5 1.5 0 004 4.11V15.89a1.5 1.5 0 002.3 1.269l9.344-5.89a1.5 1.5 0 000-2.538L6.3 2.84z"/>
                      </svg>
                    </div>
                    <h3 class="text-lg font-bold text-gray-900">Video Intros</h3>
                  </div>
                  <p class="text-2xl font-black text-green-600 mb-2">
                    <%= @portfolios |> Enum.count(&has_intro_video?/1) %>
                  </p>
                  <p class="text-sm text-gray-600">Portfolios with video</p>
                </div>

                <!-- ATS Optimization -->
                <div class="bg-gradient-to-br from-yellow-50 to-orange-50 rounded-xl p-6 border border-yellow-200">
                  <div class="flex items-center mb-4">
                    <div class="w-12 h-12 bg-gradient-to-r from-yellow-500 to-orange-500 rounded-xl flex items-center justify-center mr-4">
                      <svg class="h-6 w-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"/>
                      </svg>
                    </div>
                    <h3 class="text-lg font-bold text-gray-900">ATS Optimization</h3>
                  </div>
                  <p class="text-lg font-black text-yellow-600 mb-2">
                    <%= if @limits.ats_optimization, do: "✓ Available", else: "Upgrade Required" %>
                  </p>
                  <p class="text-sm text-gray-600">Resume optimization</p>
                </div>
              </div>

              <!-- Feature Comparison -->
              <%= if @current_user.subscription_tier == "free" do %>
                <div class="bg-gradient-to-r from-purple-600 to-indigo-600 rounded-xl p-8 text-center">
                  <h3 class="text-2xl font-black text-white mb-4">Ready to go Pro?</h3>
                  <p class="text-purple-100 mb-6 text-lg font-medium">Unlock unlimited portfolios, custom domains, and advanced analytics.</p>

                  <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6 text-left">
                    <div class="bg-white bg-opacity-10 rounded-lg p-4">
                      <div class="text-white font-bold mb-2">✨ Unlimited Portfolios</div>
                      <div class="text-purple-100 text-sm">Create as many portfolios as you need</div>
                    </div>
                    <div class="bg-white bg-opacity-10 rounded-lg p-4">
                      <div class="text-white font-bold mb-2">🌐 Custom Domains</div>
                      <div class="text-purple-100 text-sm">Use your own domain for portfolios</div>
                    </div>
                    <div class="bg-white bg-opacity-10 rounded-lg p-4">
                      <div class="text-white font-bold mb-2">📊 Advanced Analytics</div>
                      <div class="text-purple-100 text-sm">Detailed insights and visitor tracking</div>
                    </div>
                  </div>

                  <.link navigate="/account/subscription"
                        class="inline-flex items-center px-8 py-4 border border-transparent shadow-sm text-lg font-bold rounded-xl text-purple-600 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-white transition-all duration-300 transform hover:scale-105">
                    <svg class="h-5 w-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
                    </svg>
                    Upgrade Plan
                  </.link>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>

      <!-- Create Portfolio Modal -->
      <%= if @show_create_modal do %>
        <div class="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50"
             phx-click="hide_create_modal"
             id="create-portfolio-modal">
          <div class="bg-white rounded-xl shadow-2xl max-w-4xl w-full mx-4 max-h-[90vh] overflow-y-auto"
               phx-click="prevent_close">

            <!-- Modal Header -->
            <div class="bg-gradient-to-r from-purple-600 to-pink-600 px-6 py-4 rounded-t-xl">
              <div class="flex items-center justify-between">
                <h3 class="text-xl font-bold text-white">Create New Portfolio</h3>
                <button phx-click="hide_create_modal"
                        class="text-white hover:text-gray-200 transition-colors">
                  <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                  </svg>
                </button>
              </div>
            </div>

            <!-- Modal Content -->
            <div class="p-6">
              <!-- Template Selection -->
              <div class="mb-8">
                <h4 class="text-lg font-semibold text-gray-900 mb-4">Choose Your Template *</h4>
                <%= if is_nil(@selected_template) do %>
                  <div class="text-red-600 text-sm mb-2">Please select a template to continue</div>
                <% end %>
                <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                  <%= for {template_key, template_info} <- @available_templates do %>
                    <label class="relative cursor-pointer group">
                      <input type="radio"
                             name="template_selection"
                             value={template_key}
                             checked={@selected_template == template_key}
                             phx-click="select_template"
                             phx-value-template={template_key}
                             class="sr-only" />

                      <div class={[
                        "border-2 rounded-lg p-4 transition-all duration-200",
                        if(@selected_template == template_key,
                           do: "border-purple-500 bg-purple-50",
                           else: "border-gray-200 hover:border-purple-300")
                      ]}>
                        <div class={[
                          "h-20 rounded-lg mb-3 bg-gradient-to-br flex items-center justify-center",
                          Map.get(template_info, :preview_color, "from-gray-400 to-gray-600")
                        ]}>
                          <span class="text-2xl">
                            <%= Map.get(template_info, :icon, "📄") %>
                          </span>
                        </div>

                        <h5 class="font-semibold text-gray-900 mb-1">
                          <%= Map.get(template_info, :name, String.capitalize(template_key)) %>
                        </h5>
                        <p class="text-sm text-gray-600">
                          <%= Map.get(template_info, :description, "Professional template") %>
                        </p>

                        <%= if @selected_template == template_key do %>
                          <div class="absolute top-2 right-2 w-6 h-6 bg-purple-500 rounded-full flex items-center justify-center">
                            <svg class="w-4 h-4 text-white" fill="currentColor" viewBox="0 0 20 20">
                              <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
                            </svg>
                          </div>
                        <% end %>
                      </div>
                    </label>
                  <% end %>
                </div>
              </div>

              <!-- Portfolio Title -->
              <form phx-submit="create_portfolio" class="space-y-6">
                <div>
                  <label class="block text-sm font-semibold text-gray-700 mb-2">
                    Portfolio Title *
                  </label>
                  <input type="text"
                         name="title"
                         placeholder="My Professional Portfolio"
                         required
                         minlength="3"
                         maxlength="100"
                         class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500" />
                  <p class="text-sm text-gray-500 mt-1">Give your portfolio a descriptive title (3-100 characters)</p>
                </div>

                <!-- Action Buttons -->
                <div class="flex justify-end space-x-4 pt-4">
                  <button type="button"
                          phx-click="hide_create_modal"
                          class="px-6 py-3 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors">
                    Cancel
                  </button>
                  <button type="submit"
                          disabled={is_nil(@selected_template)}
                          class="px-6 py-3 bg-purple-600 text-white rounded-lg hover:bg-purple-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors">
                    Create Portfolio
                  </button>
                </div>
              </form>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Share Modal -->
      <%= if @show_share_modal and @selected_portfolio_for_share do %>
        <div class="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50"
             phx-click="hide_share_modal"
             id="share-portfolio-modal">
          <div class="bg-white rounded-xl shadow-2xl max-w-md w-full mx-4"
               phx-click="prevent_close">

            <!-- Modal Header -->
            <div class="bg-gradient-to-r from-blue-600 to-cyan-600 px-6 py-4 rounded-t-xl">
              <div class="flex items-center justify-between">
                <h3 class="text-xl font-bold text-white">Share Portfolio</h3>
                <button phx-click="hide_share_modal"
                        class="text-white hover:text-gray-200 transition-colors">
                  <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                  </svg>
                </button>
              </div>
            </div>

            <!-- Modal Content -->
            <div class="p-6">
              <div class="text-center mb-6">
                <h4 class="text-lg font-semibold text-gray-900 mb-2">
                  <%= @selected_portfolio_for_share.title %>
                </h4>
                <p class="text-gray-600">Share this portfolio with others</p>
              </div>

              <!-- Share URL -->
              <div class="bg-gray-50 rounded-lg p-4 mb-6">
                <label class="block text-sm font-semibold text-gray-700 mb-2">
                  Portfolio URL
                </label>
                <div class="flex items-center space-x-2">
                  <input type="text"
                         value={portfolio_url(@selected_portfolio_for_share)}
                         readonly
                         id="share-url-input"
                         class="flex-1 px-3 py-2 bg-white border border-gray-300 rounded text-sm" />
                  <button phx-click="copy_share_link"
                          phx-value-portfolio_id={@selected_portfolio_for_share.id}
                          class="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 transition-colors">
                    Copy
                  </button>
                </div>
              </div>

              <!-- Social Share Buttons -->
              <div class="space-y-3">
                <h5 class="text-sm font-semibold text-gray-700">Share on social media</h5>
                <div class="grid grid-cols-2 gap-3">
                  <a href={"https://twitter.com/intent/tweet?url=#{URI.encode(portfolio_url(@selected_portfolio_for_share))}&text=Check out my portfolio!"}
                     target="_blank"
                     class="flex items-center justify-center px-4 py-2 bg-blue-400 text-white rounded-lg hover:bg-blue-500 transition-colors">
                    <svg class="w-4 h-4 mr-2" fill="currentColor" viewBox="0 0 24 24">
                      <path d="M23.953 4.57a10 10 0 01-2.825.775 4.958 4.958 0 002.163-2.723c-.951.555-2.005.959-3.127 1.184a4.92 4.92 0 00-8.384 4.482C7.69 8.095 4.067 6.13 1.64 3.162a4.822 4.822 0 00-.666 2.475c0 1.71.87 3.213 2.188 4.096a4.904 4.904 0 01-2.228-.616v.06a4.923 4.923 0 003.946 4.827 4.996 4.996 0 01-2.212.085 4.936 4.936 0 004.604 3.417 9.867 9.867 0 01-6.102 2.105c-.39 0-.779-.023-1.17-.067a13.995 13.995 0 007.557 2.209c9.053 0 13.998-7.496 13.998-13.985 0-.21 0-.42-.015-.63A9.935 9.935 0 0024 4.59z"/>
                    </svg>
                    Twitter
                  </a>

                  <a href={"https://www.linkedin.com/sharing/share-offsite/?url=#{URI.encode(portfolio_url(@selected_portfolio_for_share))}"}
                     target="_blank"
                     class="flex items-center justify-center px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors">
                    <svg class="w-4 h-4 mr-2" fill="currentColor" viewBox="0 0 24 24">
                      <path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433c-1.144 0-2.063-.926-2.063-2.065 0-1.138.92-2.063 2.063-2.063 1.14 0 2.064.925 2.064 2.063 0 1.139-.925 2.065-2.064 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z"/>
                    </svg>
                    LinkedIn
                  </a>
                </div>
              </div>

              <!-- Close Button -->
              <div class="mt-6 pt-4 border-t border-gray-200">
                <button phx-click="hide_share_modal"
                        class="w-full px-4 py-2 bg-gray-600 text-white rounded-lg hover:bg-gray-700 transition-colors">
                  Close
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Collaboration Modal -->
      <%= if @show_collaboration_modal and @selected_portfolio_for_collab do %>
        <div class="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50"
             phx-click="hide_collaboration_modal"
             id="collaboration-modal">
          <div class="bg-white rounded-xl shadow-2xl max-w-md w-full mx-4"
               phx-click="prevent_close">

            <!-- Modal Header -->
            <div class="bg-gradient-to-r from-purple-600 to-indigo-600 px-6 py-4 rounded-t-xl">
              <div class="flex items-center justify-between">
                <h3 class="text-xl font-bold text-white">Get Feedback</h3>
                <button phx-click="hide_collaboration_modal"
                        class="text-white hover:text-gray-200 transition-colors">
                  <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                  </svg>
                </button>
              </div>
            </div>

            <!-- Modal Content -->
            <div class="p-6">
              <div class="text-center mb-6">
                <h4 class="text-lg font-semibold text-gray-900 mb-2">
                  <%= @selected_portfolio_for_collab.title %>
                </h4>
                <p class="text-gray-600">Create a collaboration link to get feedback on your portfolio</p>
              </div>

              <!-- Collaboration Form -->
              <form phx-submit="create_collaboration_link" class="space-y-4">
                <div>
                  <label class="block text-sm font-semibold text-gray-700 mb-2">
                    Message (optional)
                  </label>
                  <textarea name="message"
                           placeholder="Hi! I'd love your feedback on my portfolio. Please share any thoughts you have!"
                           rows="3"
                           class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500"></textarea>
                  <p class="text-xs text-gray-500 mt-1">This message will be shown to people who access your portfolio via the collaboration link</p>
                </div>

                <!-- Action Buttons -->
                <div class="flex justify-end space-x-3 pt-4">
                  <button type="button"
                          phx-click="hide_collaboration_modal"
                          class="px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors">
                    Cancel
                  </button>
                  <button type="submit"
                          class="px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors">
                    Create Link
                  </button>
                </div>
              </form>

              <!-- Info Box -->
              <div class="mt-4 p-3 bg-purple-50 rounded-lg">
                <div class="flex items-start">
                  <svg class="w-5 h-5 text-purple-600 mt-0.5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
                  </svg>
                  <div>
                    <p class="text-sm text-purple-800 font-medium">About collaboration links:</p>
                    <p class="text-xs text-purple-600 mt-1">The link will expire in 30 days and allows others to view your portfolio and leave feedback comments.</p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Video Intro Modal -->
      <%= if @show_video_intro_modal and @current_portfolio_for_video do %>
        <div class="fixed inset-0 z-50 overflow-y-auto" aria-labelledby="modal-title" role="dialog" aria-modal="true">
          <div class="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
            <!-- Background overlay -->
            <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity"
                phx-click="hide_video_intro"
                aria-hidden="true"></div>

            <!-- This element is to trick the browser into centering the modal contents. -->
            <span class="hidden sm:inline-block sm:align-middle sm:h-screen" aria-hidden="true">&#8203;</span>

            <!-- Modal panel -->
            <div class="relative inline-block align-bottom bg-white rounded-lg px-4 pt-5 pb-4 text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-4xl sm:w-full sm:p-6"
                phx-click-away="hide_video_intro"
                phx-window-keydown="hide_video_intro"
                phx-key="escape">

              <!-- Video Intro Component -->
              <.live_component
                module={FrestylWeb.PortfolioLive.VideoIntroComponent}
                id={"video-intro-#{@current_portfolio_for_video.id}"}
                portfolio={@current_portfolio_for_video}
                current_user={@current_user}
                on_cancel="hide_video_intro"
                on_complete="video_intro_complete" />

            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
