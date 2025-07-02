# lib/frestyl_web/live/portfolio_live/show.ex
# COMPLETE WORKING VERSION

defmodule FrestylWeb.PortfolioLive.Show do
  use FrestylWeb, :live_view

  alias Frestyl.Portfolios
  alias Frestyl.Repo

  # Handle /portfolios/:id route
  @impl true
  def mount(params, _session, socket) do
    %{"id" => id} = params
    preview_mode = Map.get(params, "preview") == "true"

    try do
      portfolio = Portfolios.get_portfolio!(id)
      portfolio = Repo.preload(portfolio, :user)

      if can_view_portfolio?(portfolio, socket.assigns.current_user) do
        sections = load_portfolio_sections_safe(portfolio.id)

        # Handle preview customization
        customization = if preview_mode and Map.has_key?(params, "customization") do
          try do
            Jason.decode!(params["customization"])
          rescue
            _ -> portfolio.customization || %{}
          end
        else
          portfolio.customization || %{}
        end

        socket =
          socket
          |> assign(:page_title, portfolio.title)
          |> assign(:portfolio, portfolio)
          |> assign(:sections, sections)
          |> assign(:customization, customization)
          |> assign(:preview_mode, preview_mode)
          |> assign(:can_export, false)
          |> assign(:show_export_panel, false)
          |> assign(:export_processing, false)

        # Subscribe to preview updates if in preview mode
        if preview_mode do
          Phoenix.PubSub.subscribe(Frestyl.PubSub, "portfolio_preview:#{portfolio.id}")
        end

        {:ok, socket}
      else
        {:ok, socket
        |> put_flash(:error, "Access denied")
        |> redirect(to: "/")}
      end
    rescue
      Ecto.NoResultsError ->
        {:ok, socket
        |> put_flash(:error, "Portfolio not found")
        |> redirect(to: "/")}
    end
  end

  # Handle /p/:slug route (if you need it)
  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    case Portfolios.get_portfolio_by_slug_with_sections_simple(slug) do
      {:ok, portfolio} ->
        # Preload user if not already loaded
        portfolio = if Ecto.assoc_loaded?(portfolio.user) do
          portfolio
        else
          Repo.preload(portfolio, :user)
        end

        unless owns_portfolio?(portfolio, socket.assigns.current_user) do
          track_portfolio_visit_safe(portfolio, socket)
        end

        socket =
          socket
          |> assign(:page_title, portfolio.title)
          |> assign(:portfolio, portfolio)
          |> assign(:sections, portfolio.sections || [])
          |> assign(:can_export, false)
          |> assign(:show_export_panel, false)

        {:ok, socket}

      {:error, :not_found} ->
        {:ok, socket
        |> put_flash(:error, "Portfolio not found")
        |> redirect(to: "/")}
    end
  end

  # HELPER FUNCTIONS
  defp can_view_portfolio?(portfolio, user) do
    cond do
      portfolio.visibility == :public -> true
      portfolio.visibility == :link_only -> true
      user && portfolio.user_id == user.id -> true
      true -> false
    end
  end

  defp owns_portfolio?(portfolio, user) do
    user && portfolio.user_id == user.id
  end

  defp load_portfolio_sections_safe(portfolio_id) do
    try do
      Portfolios.list_portfolio_sections(portfolio_id)
    rescue
      _ -> []
    end
  end

  defp track_portfolio_visit_safe(portfolio, socket) do
    try do
      if socket.assigns[:current_user] do
        Portfolios.create_visit(%{
          portfolio_id: portfolio.id,
          user_id: socket.assigns.current_user.id,
          ip_address: "127.0.0.1"
        })
      end
    rescue
      _ -> :ok
    end
  end

  # EVENT HANDLERS (add basic ones if needed)
  @impl true
  def handle_event("toggle_export_panel", _params, socket) do
    {:noreply, assign(socket, :show_export_panel, !socket.assigns.show_export_panel)}
  end

  @impl true
  def handle_event("export_portfolio", %{"format" => format}, socket) do
    # Basic export handling - you can expand this
    {:noreply,
     socket
     |> assign(:export_processing, true)
     |> put_flash(:info, "Export started for #{format} format")}
  end

  # Add any other event handlers you need
  @impl true
  def handle_event(event, params, socket) do
    # Catch-all for unhandled events
    IO.puts("Unhandled event: #{event} with params: #{inspect(params)}")
    {:noreply, socket}
  end

  defp render_section_content_safe(section) do
    try do
      content = section.content || %{}

      # Simple content extraction
      description = get_simple_value(content, ["description", "summary", "content", "text", "main_content"])

      if description != "" do
        Phoenix.HTML.raw("<p>#{Phoenix.HTML.html_escape(description)}</p>")
      else
        Phoenix.HTML.raw("<p class=\"text-gray-400\">Section content...</p>")
      end
    rescue
      _ ->
        Phoenix.HTML.raw("<p class=\"text-gray-400\">Loading content...</p>")
    end
  end

  # Safe value extraction function
  defp get_simple_value(content, keys) when is_list(keys) do
    Enum.find_value(keys, "", fn key ->
      case Map.get(content, key) do
        nil -> nil
        "" -> nil
        {:safe, safe_content} when is_binary(safe_content) ->
          String.trim(safe_content)
        {:safe, safe_content} when is_list(safe_content) ->
          safe_content |> Enum.join("") |> String.trim()
        {:safe, safe_content} ->
          "#{safe_content}" |> String.trim()
        value when is_binary(value) ->
          String.trim(value)
        value ->
          "#{value}" |> String.trim()
      end
      |> case do
        "" -> nil
        result -> result
      end
    end)
  end

  def apply_customization_styles(customization) when is_map(customization) do
    primary_color = Map.get(customization, "primary_color", "#374151")
    accent_color = Map.get(customization, "accent_color", "#059669")
    secondary_color = Map.get(customization, "secondary_color", "#6b7280")
    layout = Map.get(customization, "layout", "minimal")

    """
    <style>
      :root {
        --primary-color: #{primary_color};
        --accent-color: #{accent_color};
        --secondary-color: #{secondary_color};
      }

      .portfolio-container {
        #{get_layout_styles(layout)}
      }

      .portfolio-primary { color: var(--primary-color) !important; }
      .portfolio-accent { color: var(--accent-color) !important; }
      .portfolio-secondary { color: var(--secondary-color) !important; }

      .bg-portfolio-primary { background-color: var(--primary-color) !important; }
      .bg-portfolio-accent { background-color: var(--accent-color) !important; }
      .bg-portfolio-secondary { background-color: var(--secondary-color) !important; }
    </style>
    """
  end

  def apply_customization_styles(_), do: ""

  defp get_layout_styles("dashboard") do
    "display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 2rem;"
  end

  defp get_layout_styles("gallery") do
    "display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 1rem;"
  end

  defp get_layout_styles(_) do
    "display: flex; flex-direction: column; gap: 2rem;"
  end

  @impl true
  def handle_info({:preview_update, customization, _css}, socket) do
    {:noreply, assign(socket, :customization, customization)}
  end

  @impl true
  def handle_info({:sections_updated, sections}, socket) do
    {:noreply, assign(socket, :sections, sections)}
  end
end
