defmodule FrestylWeb.PortfolioLive.Index do
  use FrestylWeb, :live_view

  alias Frestyl.Portfolios
  alias Frestyl.Portfolios.PortfolioTemplates
  alias Frestyl.Accounts
  alias FrestylWeb.PortfolioLive.VideoIntroComponent
  alias Frestyl.{Portfolios, Accounts}
  import FrestylWeb.Navigation, only: [nav: 1]


  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    IO.puts("🔍 INDEX MOUNT: Starting mount for user: #{user.id}")

    # Debug portfolio loading
    portfolios = try do
      result = Portfolios.list_user_portfolios(user.id)
      IO.puts("🔍 INDEX MOUNT: Portfolios loaded: #{length(result)}")
      Enum.each(result, fn p ->
        IO.puts("  - Portfolio: #{p.id} - #{p.title} - #{p.slug}")
      end)
      result
    rescue
      e ->
        IO.puts("❌ INDEX MOUNT: Portfolio loading failed: #{inspect(e)}")
        []
    end

    # Debug limits loading
    limits = try do
      result = Portfolios.get_portfolio_limits(user)
      IO.puts("🔍 INDEX MOUNT: Limits loaded: #{inspect(result)}")
      result
    rescue
      e ->
        IO.puts("❌ INDEX MOUNT: Limits loading failed: #{inspect(e)}")
        %{max_portfolios: 2, max_media_size_mb: 50}
    end

    # Debug can_create loading
    can_create = try do
      result = Portfolios.can_create_portfolio?(user)
      IO.puts("🔍 INDEX MOUNT: Can create: #{result}")
      result
    rescue
      e ->
        IO.puts("❌ INDEX MOUNT: Can create check failed: #{inspect(e)}")
        false
    end

    # Debug available templates
    available_templates = try do
      result = Frestyl.Portfolios.PortfolioTemplates.available_templates()
      IO.puts("🔍 INDEX MOUNT: Templates loaded: #{map_size(result)}")
      result
    rescue
      e ->
        IO.puts("❌ INDEX MOUNT: Template loading failed: #{inspect(e)}")
        %{}
    end

    # Debug overview loading
    overview = try do
      result = Portfolios.get_user_portfolio_overview(user.id)
      IO.puts("🔍 INDEX MOUNT: Overview loaded: #{inspect(result)}")
      result
    rescue
      e ->
        IO.puts("❌ INDEX MOUNT: Overview loading failed: #{inspect(e)}")
        %{total_visits: 0, total_portfolios: length(portfolios), total_shares: 0}
    end

    # Debug portfolio stats loading
    portfolio_stats = try do
      result = Enum.map(portfolios, fn portfolio ->
        stats = try do
          Portfolios.get_portfolio_analytics(portfolio.id, user.id)
        rescue
          _ ->
            %{total_visits: 0, unique_visitors: 0, last_visit: nil}
        end
        {portfolio.id, stats}
      end) |> Enum.into(%{})
      IO.puts("🔍 INDEX MOUNT: Portfolio stats loaded for #{map_size(result)} portfolios")
      result
    rescue
      e ->
        IO.puts("❌ INDEX MOUNT: Portfolio stats loading failed: #{inspect(e)}")
        %{}
    end

    socket =
      socket
      |> assign(:page_title, "Portfolio Dashboard")
      |> assign(:portfolios, portfolios)
      |> assign(:limits, limits)
      |> assign(:can_create, can_create)
      |> assign(:overview, overview)
      |> assign(:portfolio_stats, portfolio_stats)
      |> assign(:show_create_modal, false)
      |> assign(:selected_template, "professional_executive")  # Set default
      |> assign(:available_templates, available_templates)
      |> assign(:show_video_intro_modal, false)
      |> assign(:current_portfolio_for_video, nil)
      |> assign(:show_share_modal, false)
      |> assign(:selected_portfolio_for_share, nil)
      |> assign(:show_collaboration_modal, false)
      |> assign(:selected_portfolio_for_collab, nil)

    IO.puts("🔍 INDEX MOUNT: Final assigns:")
    IO.puts("  - portfolios: #{length(socket.assigns.portfolios)}")
    IO.puts("  - can_create: #{socket.assigns.can_create}")
    IO.puts("  - limits: #{inspect(socket.assigns.limits)}")

    {:ok, socket}
  end

  defp get_current_account(socket, accounts) do
    # Check for account switching parameter
    account_id = get_connect_params(socket)["account_id"]

    if account_id do
      Enum.find(accounts, &(&1.id == String.to_integer(account_id)))
    else
      List.first(accounts)  # Default to first account
    end
  end

  defp get_account_limits(nil), do: %{max_portfolios: 0}
  defp get_account_limits(account) do
    # TODO: Implement proper limits based on subscription tier
    %{
      max_portfolios: case account.subscription_tier do
        :personal -> 3
        :creator -> 25
        :professional -> :unlimited
        :enterprise -> :unlimited
      end
    }
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

  def handle_event("create_portfolio", %{"title" => title}, socket) do
    user = socket.assigns.current_user

    # 🔥 FIX: Check portfolio limits FIRST
    limits = Portfolios.get_portfolio_limits(user)
    current_count = length(Portfolios.list_user_portfolios(user.id))

    case check_portfolio_creation_limit(limits, current_count) do
      :allowed ->
        # Proceed with existing creation logic...
        case validate_portfolio_title(title) do
          {:ok, validated_title} ->
            # Complete portfolio creation code
            selected_template = socket.assigns.selected_template || "professional_executive"

            # Map complex template names to valid database enum values
            theme = map_template_to_valid_theme(selected_template)

            # Generate slug from title
            base_slug = validated_title
              |> String.downcase()
              |> String.replace(~r/[^a-z0-9\s-]/, "")
              |> String.replace(~r/\s+/, "-")
              |> String.slice(0, 50)

            slug = if String.length(base_slug) < 5 do
              "#{base_slug}-portfolio"
            else
              base_slug
            end

            # Get template config
            template_config = try do
              PortfolioTemplates.get_template_config(selected_template)
            rescue
              _ ->
                %{
                  "layout" => "dashboard",
                  "primary_color" => "#3b82f6",
                  "secondary_color" => "#64748b",
                  "accent_color" => "#f59e0b"
                }
            end

            portfolio_attrs = %{
              title: validated_title,
              slug: slug,
              theme: theme,
              customization: template_config,
              visibility: :private
            }

            case Portfolios.create_portfolio(user, portfolio_attrs) do
              {:ok, portfolio} ->
                # Refresh data
                portfolios = Portfolios.list_user_portfolios(user.id)
                can_create = Portfolios.can_create_portfolio?(user)

                overview = try do
                  Portfolios.get_user_portfolio_overview(user.id)
                rescue
                  _ -> %{total_visits: 0, total_portfolios: length(portfolios), total_shares: 0}
                end

                portfolio_stats = Enum.map(portfolios, fn portfolio ->
                  stats = try do
                    Portfolios.get_portfolio_analytics(portfolio.id, user.id)
                  rescue
                    _ -> %{total_visits: 0, unique_visitors: 0, last_visit: nil}
                  end
                  {portfolio.id, stats}
                end) |> Enum.into(%{})

                {:noreply,
                socket
                |> assign(:portfolios, portfolios)
                |> assign(:can_create, can_create)
                |> assign(:overview, overview)
                |> assign(:portfolio_stats, portfolio_stats)
                |> assign(:show_create_modal, false)
                |> assign(:selected_template, nil)
                |> put_flash(:info, "Portfolio '#{portfolio.title}' created successfully!")
                |> push_navigate(to: "/portfolios/#{portfolio.id}/edit")}

              {:error, %Ecto.Changeset{} = changeset} ->
                errors = changeset.errors
                  |> Enum.map(fn {field, {msg, _}} -> "#{field} #{msg}" end)
                  |> Enum.join(", ")

                {:noreply, put_flash(socket, :error, "Failed to create portfolio: #{errors}")}

              {:error, reason} ->
                {:noreply, put_flash(socket, :error, "Failed to create portfolio: #{inspect(reason)}")}
            end

          {:error, message} ->
            {:noreply, put_flash(socket, :error, message)}
        end

      {:blocked, reason} ->
        # Show upgrade prompt instead of creating
        {:noreply, socket
        |> assign(:show_upgrade_modal, true)
        |> assign(:upgrade_reason, reason)
        |> put_flash(:warning, reason)}
    end
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
    # Fix: Handle both map and list formats for available_templates
    available_template_keys = case socket.assigns.available_templates do
      templates when is_map(templates) ->
        Map.keys(templates)
      templates when is_list(templates) ->
        Enum.map(templates, fn {key, _config} -> key end)
      _ ->
        []
    end

    if template in available_template_keys do
      {:noreply, assign(socket, selected_template: template)}
    else
      {:noreply, socket}
    end
  end

    # CRITICAL: Add missing video event handlers
  @impl true
  def handle_event("camera_ready", params, socket) do
    if socket.assigns[:show_video_intro_modal] && socket.assigns[:current_portfolio_for_video] do
      send_update(FrestylWeb.PortfolioLive.VideoIntroComponent,
        id: "video-intro-#{socket.assigns.current_portfolio_for_video.id}",
        camera_ready_params: params
      )
    end
    {:noreply, socket}
  end

  @impl true
  def handle_event("camera_error", params, socket) do
    if socket.assigns[:show_video_intro_modal] && socket.assigns[:current_portfolio_for_video] do
      send_update(FrestylWeb.PortfolioLive.VideoIntroComponent,
        id: "video-intro-#{socket.assigns.current_portfolio_for_video.id}",
        camera_error_params: params
      )
    end
    {:noreply, socket}
  end

  @impl true
  def handle_event("countdown_update", params, socket) do
    if socket.assigns[:show_video_intro_modal] && socket.assigns[:current_portfolio_for_video] do
      send_update(FrestylWeb.PortfolioLive.VideoIntroComponent,
        id: "video-intro-#{socket.assigns.current_portfolio_for_video.id}",
        countdown_update_params: params
      )
    end
    {:noreply, socket}
  end

  @impl true
  def handle_event("recording_progress", params, socket) do
    if socket.assigns[:show_video_intro_modal] && socket.assigns[:current_portfolio_for_video] do
      send_update(FrestylWeb.PortfolioLive.VideoIntroComponent,
        id: "video-intro-#{socket.assigns.current_portfolio_for_video.id}",
        recording_progress_params: params
      )
    end
    {:noreply, socket}
  end

  @impl true
  def handle_event("recording_error", params, socket) do
    if socket.assigns[:show_video_intro_modal] && socket.assigns[:current_portfolio_for_video] do
      send_update(FrestylWeb.PortfolioLive.VideoIntroComponent,
        id: "video-intro-#{socket.assigns.current_portfolio_for_video.id}",
        recording_error_params: params
      )
    end
    {:noreply, socket}
  end

  @impl true
  def handle_event("video_blob_ready", params, socket) do
    if socket.assigns[:show_video_intro_modal] && socket.assigns[:current_portfolio_for_video] do
      send_update(FrestylWeb.PortfolioLive.VideoIntroComponent,
        id: "video-intro-#{socket.assigns.current_portfolio_for_video.id}",
        video_blob_params: params
      )
    end
    {:noreply, socket}
  end

  @impl true
  def handle_event("recording_progress", params, socket) do
    IO.puts("=== RECORDING PROGRESS IN PARENT LIVEVIEW ===")
    IO.inspect(params, label: "Recording progress params")

    # Forward the recording progress to the video intro component
    if socket.assigns[:show_video_intro_modal] && socket.assigns[:current_portfolio_for_video] do
      component_id = "video-intro-#{socket.assigns.current_portfolio_for_video.id}"

      send_update(FrestylWeb.PortfolioLive.VideoIntroComponent,
        id: component_id,
        recording_progress_params: params
      )
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("recording_error", params, socket) do
    IO.puts("=== RECORDING ERROR IN PARENT LIVEVIEW ===")
    IO.inspect(params, label: "Recording error params")

    # Forward the recording error to the video intro component
    if socket.assigns[:show_video_intro_modal] && socket.assigns[:current_portfolio_for_video] do
      component_id = "video-intro-#{socket.assigns.current_portfolio_for_video.id}"

      send_update(FrestylWeb.PortfolioLive.VideoIntroComponent,
        id: component_id,
        recording_error_params: params
      )
    end

    {:noreply, socket}
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

  def handle_event("create_portfolio", %{"title" => title}, socket) do
    IO.puts("🔍 CREATE: Starting portfolio creation with title: #{title}")

    case validate_portfolio_title(title) do
      {:ok, validated_title} ->
        user = socket.assigns.current_user
        selected_template = socket.assigns.selected_template || "professional_executive"

        IO.puts("🔍 CREATE: Selected template: #{selected_template}")

        # Map complex template names to valid database enum values
        theme = map_template_to_valid_theme(selected_template)
        IO.puts("🔍 CREATE: Mapped theme: #{theme}")

        # Generate slug from title - ensure minimum 5 characters
        base_slug = validated_title
          |> String.downcase()
          |> String.replace(~r/[^a-z0-9\s-]/, "")
          |> String.replace(~r/\s+/, "-")
          |> String.slice(0, 50)

        # Ensure slug is at least 5 characters
        slug = if String.length(base_slug) < 5 do
          "#{base_slug}-portfolio"
        else
          base_slug
        end

        IO.puts("🔍 CREATE: Generated slug: #{slug}")

        # Get template config using the original selected template (for styling)
        template_config = try do
          PortfolioTemplates.get_template_config(selected_template)
        rescue
          e ->
            IO.puts("⚠️ CREATE: Template config failed for #{selected_template}: #{inspect(e)}")
            # Fallback config
            %{
              "layout" => "dashboard",
              "primary_color" => "#3b82f6",
              "secondary_color" => "#64748b",
              "accent_color" => "#f59e0b"
            }
        end

        IO.puts("🔍 CREATE: Template config: #{inspect(template_config)}")

        portfolio_attrs = %{
          title: validated_title,
          slug: slug,
          theme: theme,  # Use the mapped valid theme
          customization: template_config,
          visibility: :private
        }

        IO.puts("🔍 CREATE: Portfolio attrs: #{inspect(portfolio_attrs)}")

        case Portfolios.create_portfolio(user.id, portfolio_attrs) do
          {:ok, portfolio} ->
            IO.puts("✅ CREATE: Portfolio created successfully with ID: #{portfolio.id}")

            # Refresh ALL data that the index page depends on
            portfolios = Portfolios.list_user_portfolios(user.id)
            can_create = Portfolios.can_create_portfolio?(user)

            # Refresh dashboard analytics
            overview = try do
              Portfolios.get_user_portfolio_overview(user.id)
            rescue
              _ -> %{total_visits: 0, total_portfolios: length(portfolios), total_shares: 0}
            end

            # Refresh individual portfolio stats (including the new one)
            portfolio_stats = Enum.map(portfolios, fn portfolio ->
              stats = try do
                Portfolios.get_portfolio_analytics(portfolio.id, user.id)
              rescue
                _ ->
                  %{total_visits: 0, unique_visitors: 0, last_visit: nil}
              end
              {portfolio.id, stats}
            end) |> Enum.into(%{})

            {:noreply,
            socket
            |> assign(:portfolios, portfolios)
            |> assign(:can_create, can_create)
            |> assign(:overview, overview)
            |> assign(:portfolio_stats, portfolio_stats)
            |> assign(:show_create_modal, false)
            |> assign(:selected_template, nil)
            |> debug_socket_assigns()
            |> put_flash(:info, "Portfolio '#{portfolio.title}' created successfully!")
            |> push_navigate(to: "/portfolios/#{portfolio.id}/edit")}

          {:error, %Ecto.Changeset{} = changeset} ->
            IO.puts("❌ CREATE: Changeset errors: #{inspect(changeset.errors)}")

            errors = changeset.errors
              |> Enum.map(fn {field, {msg, _}} -> "#{field} #{msg}" end)
              |> Enum.join(", ")

            {:noreply, put_flash(socket, :error, "Failed to create portfolio: #{errors}")}

          {:error, reason} ->
            IO.puts("❌ CREATE: Other error: #{inspect(reason)}")
            {:noreply, put_flash(socket, :error, "Failed to create portfolio: #{inspect(reason)}")}
        end

      {:error, message} ->
        {:noreply, put_flash(socket, :error, message)}
    end
  end

  def handle_params(%{"dashboard" => true}, _url, socket) do
    # Handle dashboard-specific logic here
    {:noreply, assign(socket, :view_mode, :dashboard)}
  end

  def handle_params(_params, _url, socket) do
    {:noreply, assign(socket, :view_mode, :index)}
  end

  def debug_portfolio_creation(user_id, attrs) do
    IO.puts("🔍 DEBUG: Creating portfolio for user #{user_id}")
    IO.puts("🔍 DEBUG: Attrs: #{inspect(attrs)}")

    try do
      result = Portfolios.create_portfolio(user_id, attrs)
      IO.puts("🔍 DEBUG: Result: #{inspect(result)}")
      result
    rescue
      e ->
        IO.puts("🔍 DEBUG: Exception: #{inspect(e)}")
        {:error, e}
    end
  end

  def debug_socket_assigns(socket) do
    required_assigns = [
      :portfolios, :limits, :can_create, :overview, :portfolio_stats,
      :show_create_modal, :selected_template, :available_templates,
      :show_video_intro_modal, :current_portfolio_for_video,
      :show_share_modal, :selected_portfolio_for_share,
      :show_collaboration_modal, :selected_portfolio_for_collab
    ]

    missing = Enum.filter(required_assigns, fn assign ->
      not Map.has_key?(socket.assigns, assign)
    end)

    if length(missing) > 0 do
      IO.puts("❌ Missing assigns: #{inspect(missing)}")
    else
      IO.puts("✅ All required assigns present")
    end

    socket
  end


  def handle_event("create_new_story", _params, socket) do
    account = socket.assigns.current_account

    case Frestyl.Features.FeatureGate.can_access_feature?(account, :create_story) do
      true ->
        {:noreply, push_navigate(socket, to: ~p"/portfolios/new")}

      false ->
        suggestion = Frestyl.Features.FeatureGate.get_upgrade_suggestion(account, :create_story)

        socket = socket
        |> assign(:show_upgrade_modal, true)
        |> assign(:upgrade_suggestion, suggestion)

        {:noreply, socket}
    end
  end

  def handle_event("invite_collaborator", %{"story_id" => story_id}, socket) do
    account = socket.assigns.current_account

    case Frestyl.Features.FeatureGate.can_access_feature?(account, {:collaborator_invite, 1}) do
      true ->
        # Proceed with collaboration
        {:noreply, assign(socket, :show_collaboration_modal, true)}

      false ->
        suggestion = Frestyl.Features.FeatureGate.get_upgrade_suggestion(account, :real_time_collaboration)

        socket = socket
        |> assign(:show_upgrade_modal, true)
        |> assign(:upgrade_suggestion, suggestion)

        {:noreply, socket}
    end
  end

  def handle_info(:close_upgrade_modal, socket) do
    {:noreply, assign(socket, :show_upgrade_modal, false)}
  end

  def handle_info({:start_upgrade, tier}, socket) do
    # Redirect to billing/upgrade page
    {:noreply, push_navigate(socket, to: ~p"/account/upgrade?tier=#{tier}")}
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
          # Refresh ALL index data after deletion
          user = socket.assigns.current_user
          portfolios = Portfolios.list_user_portfolios(user.id)
          can_create = Portfolios.can_create_portfolio?(user)
          overview = Portfolios.get_user_portfolio_overview(user.id)

          # Update portfolio stats (excluding the deleted one)
          portfolio_stats = Enum.map(portfolios, fn portfolio ->
            stats = try do
              Portfolios.get_portfolio_analytics(portfolio.id, user.id)
            rescue
              _ ->
                %{total_visits: 0, unique_visitors: 0, last_visit: nil}
            end
            {portfolio.id, stats}
          end) |> Enum.into(%{})

          {:noreply,
          socket
          |> assign(:portfolios, portfolios)
          |> assign(:can_create, can_create)
          |> assign(:overview, overview)
          |> assign(:portfolio_stats, portfolio_stats)
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

  # Account switching
  def handle_info({:switch_account, account_id}, socket) do
    account = Enum.find(socket.assigns.accounts, &(&1.id == account_id))

    if account do
      # Update URL to include account parameter
      new_path = ~p"/portfolios?account_id=#{account.id}"

      socket = socket
      |> assign(:current_account, account)
      |> push_patch(to: new_path)

      {:noreply, socket}
    else
      {:noreply, put_flash(socket, :error, "Account not found")}
    end
  end

  def handle_info(:show_create_account_modal, socket) do
    {:noreply, assign(socket, :show_create_account_modal, true)}
  end

  @impl true
  def handle_info({:close_video_intro_modal}, socket) do
    {:noreply, assign(socket, :show_video_intro_modal, false)}
  end

  @impl true
  def handle_info({:video_intro_complete, video_section}, socket) do
    socket =
      socket
      |> assign(:show_video_intro_modal, false)
      |> put_flash(:info, "Video introduction created successfully!")

    {:noreply, socket}
  end

  # ADD THESE MISSING HANDLERS
  @impl true
  def handle_event("hide_video_intro", _params, socket) do
    {:noreply, assign(socket, show_video_intro_modal: false, current_portfolio_for_video: nil)}
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

  defp map_template_to_valid_theme(template) do
    case template do
      # Minimalist templates
      "minimalist_clean" -> "minimalist"
      "minimalist_elegant" -> "minimalist"

      # Professional templates
      "professional_corporate" -> "corporate"
      "professional_executive" -> "executive"

      # Creative templates
      "creative_artistic" -> "creative"
      "creative_designer" -> "designer"

      # Technical templates
      "technical_developer" -> "developer"
      "technical_engineer" -> "developer"

      # Legacy/direct mappings
      "creative" -> "creative"
      "corporate" -> "corporate"
      "minimalist" -> "minimalist"
      "executive" -> "executive"
      "developer" -> "developer"
      "designer" -> "designer"
      "consultant" -> "consultant"
      "academic" -> "academic"
      "artist" -> "artist"
      "entrepreneur" -> "entrepreneur"
      "freelancer" -> "freelancer"
      "photographer" -> "photographer"
      "writer" -> "writer"
      "marketing" -> "marketing"
      "healthcare" -> "healthcare"

      # Default fallback
      _ -> "executive"
    end
  end

  # Also add validation for the title to ensure slug will be long enough:
  # Add this validation before creating the portfolio:

  defp validate_portfolio_title(title) do
    title = String.trim(title)

    cond do
      title == "" ->
        {:error, "Portfolio title cannot be empty"}

      String.length(title) < 3 ->
        {:error, "Portfolio title must be at least 3 characters long"}

      String.length(title) > 100 ->
        {:error, "Portfolio title must be less than 100 characters"}

      true ->
        {:ok, title}
    end
  end

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
    # Check if portfolio has a video intro section
    sections = Frestyl.Portfolios.list_portfolio_sections(portfolio.id)

    Enum.any?(sections, fn section ->
      section.title == "Video Introduction" ||
      (section.content && Map.get(section.content, "video_type") == "introduction")
    end)
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

  defp check_portfolio_creation_limit(limits, current_count) do
    case limits.max_portfolios do
      -1 -> :allowed  # Unlimited
      max_count when current_count >= max_count ->
        {:blocked, "You've reached your portfolio limit (#{max_count}). Upgrade to create more portfolios."}
      _ -> :allowed
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

            <!-- Streaming -->
            <div class="group bg-gradient-to-br from-red-600 to-pink-600 rounded-xl shadow-md hover:shadow-xl transition-all duration-300 transform hover:-translate-y-1 overflow-hidden">
              <div class="h-full flex items-center justify-center p-12 text-center">
                <div>
                  <div class="w-16 h-16 mx-auto mb-6 bg-white bg-opacity-20 rounded-full flex items-center justify-center">
                    <svg class="h-8 w-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
                    </svg>
                  </div>
                  <h3 class="text-xl font-black text-white mb-2">Live Streaming</h3>
                  <p class="text-red-100 text-sm mb-4">Stream your presentations and connect with audiences</p>
                  <.link navigate="/streaming"
                        class="inline-flex items-center px-4 py-2 bg-white text-red-600 font-bold text-sm rounded-lg hover:bg-gray-50 transition-all">
                    Start Streaming
                  </.link>
                </div>
              </div>
            </div>

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
              <%= if @normalized_tier == "personal" do %>
                <div class="bg-gradient-to-r from-purple-600 to-indigo-600 rounded-xl p-8 text-center">
                  <h3 class="text-2xl font-black text-white mb-4">Ready to go upgrade?</h3>
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
                id={"video-intro-index-#{@current_portfolio_for_video.id}"}
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
