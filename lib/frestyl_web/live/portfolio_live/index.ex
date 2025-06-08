# lib/frestyl_web/live/portfolio_live/index.ex - Enhanced version
defmodule FrestylWeb.PortfolioLive.Index do
  use FrestylWeb, :live_view

  alias Frestyl.Portfolios
  alias Frestyl.Portfolios.PortfolioTemplates
  alias Frestyl.Accounts
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
          %{views: 0, shares: 0, feedback: 0, last_view: nil}
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

    {:ok, socket}
  end

  # Additional helper function for safe stat access
  defp safe_get_stat(portfolio_id, stat_key, portfolio_stats) do
    case Map.get(portfolio_stats, portfolio_id) do
      nil -> 0
      stats -> Map.get(stats, stat_key, 0)
    end
  end

  # Helper for portfolio status badges
  defp portfolio_status_badge(portfolio) do
    case portfolio.visibility do
      :public -> {"bg-green-100 text-green-800", "🌍 Public"}
      :link_only -> {"bg-blue-100 text-blue-800", "🔗 Link Only"}
      :private -> {"bg-gray-100 text-gray-800", "🔒 Private"}
    end
  end

  # Helper for date formatting
  defp format_date(datetime) when is_nil(datetime), do: "Never"
  defp format_date(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y")
  end

  # Helper for number formatting
  defp format_number(num) when num >= 1000 do
    "#{Float.round(num / 1000, 1)}k"
  end
  defp format_number(num), do: to_string(num)

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

  # Helper for portfolio URL
  defp portfolio_url(portfolio) do
    "#{FrestylWeb.Endpoint.url()}/p/#{portfolio.slug}"
  end

  # Helper for collaboration URL
  defp portfolio_collaboration_url(token) do
    "#{FrestylWeb.Endpoint.url()}/p/#{token}?collaboration=true"
  end

  # Helper to check if portfolio has intro video
  defp has_intro_video?(portfolio) do
    Map.get(portfolio, :intro_video_id) != nil
  end

  @impl true
  def handle_event("show_create_modal", _params, socket) do
    if socket.assigns.can_create do
      {:noreply, assign(socket, show_create_modal: true)}
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

  @impl true
  def handle_event("select_template", %{"template" => template}, socket) do
    if template in socket.assigns.available_templates do
      {:noreply, assign(socket, selected_template: template)}
    else
      {:noreply, socket}
    end
  end

# In index.ex, fix the create_portfolio handler:

  @impl true
  def handle_event("create_portfolio", %{"title" => title}, socket) do
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
        |> put_flash(:info, "Portfolio created successfully!")
        |> push_navigate(to: "/portfolios/#{portfolio.id}/edit")}

      {:error, changeset} ->
        errors = changeset.errors |> Enum.map(fn {field, {msg, _}} -> "#{field} #{msg}" end) |> Enum.join(", ")
        {:noreply, put_flash(socket, :error, "Failed to create portfolio: #{errors}")}
    end
  end

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

  # Video intro events (keeping existing functionality)
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

  @impl true
  def handle_info({"hide_video_intro", _params}, socket) do
    {:noreply, assign(socket, :show_video_intro_modal, false)}
  end

  # Also add the video intro complete handler:
  @impl true
  def handle_info({:video_intro_complete, %{"media_file_id" => media_file_id, "file_path" => file_path}}, socket) do
    {:noreply,
    socket
    |> assign(:show_video_intro_modal, false)
    |> put_flash(:info, "Video introduction saved successfully!")}
  end

  # Add the hide_video_intro event handler:
  @impl true
  def handle_event("hide_video_intro", _params, socket) do
    {:noreply, assign(socket, :show_video_intro_modal, false)}
  end

  # Keep existing video event handlers...
  @impl true
  def handle_info({:video_intro_complete, %{"media_file_id" => media_file_id, "file_path" => file_path}}, socket) do
    {:noreply,
     socket
     |> assign(show_video_intro: false)
     |> put_flash(:info, "Video introduction saved! You can now view it in your portfolio.")}
  end

  # Helper functions
  defp portfolio_url(portfolio) do
    "#{FrestylWeb.Endpoint.url()}/p/#{portfolio.slug}"
  end

  defp portfolio_collaboration_url(token) do
    "#{FrestylWeb.Endpoint.url()}/p/#{token}?collaboration=true"
  end

  defp has_intro_video?(portfolio) do
    Map.get(portfolio, :intro_video_id) != nil
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y")
  end

  defp format_number(num) when num >= 1000 do
    "#{Float.round(num / 1000, 1)}k"
  end
  defp format_number(num), do: to_string(num)

  defp get_growth_percentage(current, previous) when previous > 0 do
    growth = ((current - previous) / previous) * 100
    Float.round(growth, 1)
  end
  defp get_growth_percentage(_, _), do: 0

  defp growth_class(percentage) when percentage > 0, do: "text-green-600"
  defp growth_class(percentage) when percentage < 0, do: "text-red-600"
  defp growth_class(_), do: "text-gray-500"

  defp template_preview_gradient(template_name) do
    case template_name do
      "executive" -> "from-slate-800 to-slate-900"
      "developer" -> "from-indigo-600 to-purple-600"
      "designer" -> "from-pink-500 to-rose-500"
      "consultant" -> "from-blue-600 to-cyan-600"
      "academic" -> "from-emerald-600 to-teal-600"
      _ -> "from-gray-600 to-gray-800"
    end
  end

  defp get_portfolio_stats(portfolio) do
    # Return default stats if portfolio_stats not loaded
    %{
      views: 0,
      shares: 0,
      feedback: 0,
      last_view: nil
    }
  end

    # Helper function to get portfolio statistics
  defp get_portfolio_stats(portfolio) do
    case Map.get(@portfolio_stats || %{}, portfolio.id) do
      nil ->
        # Return default stats if not loaded
        %{
          views: 0,
          shares: 0,
          feedback: 0,
          last_view: nil
        }
      stats -> stats
    end
  end

  # Helper function for template preview gradient classes
  defp template_preview(template_key) do
    templates = %{
      "executive" => %{
        color: "from-slate-800 to-slate-900",
        icon: "💼",
        name: "Executive",
        description: "Professional corporate leadership style"
      },
      "developer" => %{
        color: "from-indigo-600 to-purple-600",
        icon: "⚡",
        name: "Developer",
        description: "Code-focused tech professional layout"
      },
      "designer" => %{
        color: "from-pink-500 to-rose-500",
        icon: "🎨",
        name: "Designer",
        description: "Creative visual showcase design"
      },
      "consultant" => %{
        color: "from-blue-600 to-cyan-600",
        icon: "📊",
        name: "Consultant",
        description: "Strategic business advisory style"
      },
      "academic" => %{
        color: "from-emerald-600 to-teal-600",
        icon: "🎓",
        name: "Academic",
        description: "Research and education focused"
      },
      "artist" => %{
        color: "from-violet-600 to-purple-600",
        icon: "🎭",
        name: "Artist",
        description: "Creative portfolio with gallery focus"
      },
      "entrepreneur" => %{
        color: "from-orange-600 to-red-600",
        icon: "🚀",
        name: "Entrepreneur",
        description: "Startup founder and business builder"
      },
      "freelancer" => %{
        color: "from-green-600 to-emerald-600",
        icon: "💡",
        name: "Freelancer",
        description: "Independent contractor showcase"
      },
      "photographer" => %{
        color: "from-gray-800 to-black",
        icon: "📸",
        name: "Photographer",
        description: "Visual storytelling and image gallery"
      },
      "writer" => %{
        color: "from-amber-600 to-orange-600",
        icon: "✍️",
        name: "Writer",
        description: "Content creator and storyteller"
      },
      "marketing" => %{
        color: "from-fuchsia-600 to-pink-600",
        icon: "📈",
        name: "Marketing Pro",
        description: "Brand and campaign specialist"
      },
      "healthcare" => %{
        color: "from-blue-500 to-blue-700",
        icon: "🏥",
        name: "Healthcare",
        description: "Medical and wellness professional"
      },
      "minimalist" => %{
        color: "from-gray-600 to-gray-800",
        icon: "📋",
        name: "Minimalist",
        description: "Clean and simple design"
      },
      "creative" => %{
        color: "from-purple-600 to-pink-600",
        icon: "🎨",
        name: "Creative",
        description: "Bold and artistic layout"
      },
      "corporate" => %{
        color: "from-blue-600 to-indigo-600",
        icon: "💼",
        name: "Corporate",
        description: "Professional business style"
      }
    }

    Map.get(templates, template_key, %{
      gradient: "from-gray-600 to-gray-800",
      icon: "📄",
      name: "Default",
      description: "Standard portfolio layout"
    })
  end

end
