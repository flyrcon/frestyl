# lib/frestyl_web/live/portfolio_live/index.ex
defmodule FrestylWeb.PortfolioLive.Index do
  use FrestylWeb, :live_view

  alias Frestyl.Portfolios
  alias Frestyl.Accounts
  import FrestylWeb.Navigation, only: [nav: 1]

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    portfolios = Portfolios.list_user_portfolios(user.id)
    limits = Portfolios.get_portfolio_limits(user)
    can_create = Portfolios.can_create_portfolio?(user)

    socket =
      socket
      |> assign(:page_title, "My Portfolios")
      |> assign(:portfolios, portfolios)
      |> assign(:limits, limits)
      |> assign(:can_create, can_create)
      |> assign(:show_create_modal, false)
      |> assign(:selected_template, nil)
      |> assign(:show_video_intro_modal, false)
      |> assign(:current_portfolio_for_video, nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("show_create_modal", _params, socket) do
    if socket.assigns.can_create do
      {:noreply, assign(socket, show_create_modal: true)}
    else
      {:noreply,
       socket
       |> put_flash(:error, "You've reached your portfolio limit. Upgrade to create more portfolios.")
       |> push_navigate(to: "/account/subscription")}
    end
  end

  @impl true
  def handle_event("hide_create_modal", _params, socket) do
    {:noreply, assign(socket, show_create_modal: false, selected_template: nil)}
  end

  @impl true
  def handle_event("select_template", %{"template" => template}, socket) do
    {:noreply, assign(socket, selected_template: template)}
  end

  @impl true
  def handle_event("create_portfolio", %{"title" => title}, socket) do
    user = socket.assigns.current_user
    template = socket.assigns.selected_template || "minimalist"

    portfolio_attrs = %{
      title: title,
      theme: template
    }

    case Portfolios.create_default_portfolio(user.id, portfolio_attrs) do
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

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create portfolio.")}
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

          {:noreply,
           socket
           |> assign(:portfolios, portfolios)
           |> assign(:can_create, can_create)
           |> put_flash(:info, "Portfolio deleted successfully.")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete portfolio.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Unauthorized action.")}
    end
  end

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
  def handle_event("hide_video_intro", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_video_intro_modal, false)
     |> assign(:current_portfolio_for_video, nil)}
  end

  @impl true
  def handle_event("video_intro_complete", %{"media_file_id" => media_file_id}, socket) do
    portfolio = socket.assigns.current_portfolio_for_video

    case Portfolios.update_portfolio(portfolio, %{intro_video_id: media_file_id}) do
      {:ok, updated_portfolio} ->
        # Refresh portfolios list
        portfolios = Portfolios.list_user_portfolios(socket.assigns.current_user.id)

        {:noreply,
         socket
         |> assign(:portfolios, portfolios)
         |> assign(:show_video_intro_modal, false)
         |> assign(:current_portfolio_for_video, nil)
         |> put_flash(:info, "Video introduction added successfully!")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add video introduction.")}
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

  # Helper functions
  defp get_portfolio_stats(portfolio) do
    # This would integrate with your analytics system
    %{
      views: Enum.random(10..500),
      shares: Enum.random(1..25),
      last_updated: portfolio.updated_at
    }
  end

  defp template_preview(template) do
    case template do
      "minimalist" -> %{
        name: "Minimalist",
        description: "Clean, text-focused design",
        color: "from-gray-600 to-gray-800",
        icon: "📄"
      }
      "creative" -> %{
        name: "Creative",
        description: "Visual-first with bold colors",
        color: "from-purple-600 to-pink-600",
        icon: "🎨"
      }
      "corporate" -> %{
        name: "Corporate",
        description: "Professional business layout",
        color: "from-blue-600 to-indigo-600",
        icon: "💼"
      }
    end
  end

  defp portfolio_url(portfolio) do
    "#{FrestylWeb.Endpoint.url()}/p/#{portfolio.slug}"
  end

  defp has_intro_video?(portfolio) do
    Map.get(portfolio, :intro_video_id) != nil
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y")
  end
end
