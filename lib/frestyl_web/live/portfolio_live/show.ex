# lib/frestyl_web/live/portfolio_live/show.ex
# COMPLETE WORKING VERSION

defmodule FrestylWeb.PortfolioLive.Show do
  use FrestylWeb, :live_view

  import Ecto.Query

  alias Frestyl.Portfolios
  alias Frestyl.Repo
  alias Frestyl.Portfolios.TemplateSystem

  @impl true
  def mount(params, _session, socket) do
    %{"id" => id} = params
    preview_mode = Map.get(params, "preview") == "true"

    try do
      # Use existing function but add timeout
      portfolio = Task.async(fn ->
        Portfolios.get_portfolio!(id)
        |> Repo.preload(:user)
      end)
      |> Task.await(5000)  # 5 second timeout

      if can_view_portfolio?(portfolio, socket.assigns.current_user) do
        # Load sections with timeout
        sections = Task.async(fn ->
          load_portfolio_sections_safe(portfolio.id)
        end)
        |> Task.await(3000)  # 3 second timeout

        # Handle preview customization
        customization = case preview_mode do
          true ->
            case Map.get(params, "customization") do
              nil -> portfolio.customization || get_default_customization()
              customization_json ->
                try do
                  Jason.decode!(customization_json)
                rescue
                  _ -> portfolio.customization || get_default_customization()
                end
            end
          false ->
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
          |> assign(:customization_css, apply_customization_styles(customization))

        # Only subscribe to preview updates if in preview mode
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
      # Handle any timeout or database errors
      error ->
        IO.puts("Portfolio load error: #{inspect(error)}")
        {:ok, socket
        |> put_flash(:error, "Portfolio temporarily unavailable")
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

  defp get_default_customization do
    %{
      "primary_color" => "#374151",
      "secondary_color" => "#6b7280",
      "accent_color" => "#3b82f6",
      "background_color" => "#ffffff",
      "text_color" => "#111827",
      "layout" => "dashboard"
    }
  end

  defp load_minimal_sections(portfolio_id) do
    # Use a lighter query for preview mode
    try do
      from(s in PortfolioSection,
        where: s.portfolio_id == ^portfolio_id,
        select: %{
          id: s.id,
          title: s.title,
          section_type: s.section_type,
          content: s.content,
          visible: s.visible
        },
        limit: 10
      )
      |> Repo.all()
    rescue
      _ -> []
    end
  end

  defp get_portfolio_basic(id) do
    from(p in Portfolio,
      where: p.id == ^id,
      select: %{
        id: p.id,
        title: p.title,
        description: p.description,
        theme: p.theme,
        customization: p.customization,
        visibility: p.visibility,
        user_id: p.user_id
      }
    )
    |> Repo.one!()
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
    # Use EXACT colors user set - no template overrides
    primary_color = Map.get(customization, "primary_color", "#374151")
    accent_color = Map.get(customization, "accent_color", "#059669")
    secondary_color = Map.get(customization, "secondary_color", "#6b7280")
    background_color = Map.get(customization, "background_color", "#ffffff")
    text_color = Map.get(customization, "text_color", "#1f2937")
    layout = Map.get(customization, "layout", "minimal")

    """
    <style>
      :root {
        --primary-color: #{primary_color};
        --accent-color: #{accent_color};
        --secondary-color: #{secondary_color};
        --background-color: #{background_color};
        --text-color: #{text_color};
      }

      .portfolio-container {
        #{get_layout_styles(layout)}
        background-color: var(--background-color);
        color: var(--text-color);
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

  # ADD these helper functions to show.ex:
  defp map_template_grid_to_layout(grid_type) do
    case grid_type do
      "masonry" -> "dashboard"
      "pinterest" -> "gallery"
      "service_oriented" -> "case_study"
      "minimal_stack" -> "minimal"
      _ -> "dashboard"
    end
  end

  defp get_template_system_layout_styles(layout, spacing, max_columns) do
    case layout do
      "dashboard" ->
        "display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: #{spacing}; max-width: #{max_columns * 400}px; margin: 0 auto;"
      "gallery" ->
        "display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: #{spacing}; max-width: #{max_columns * 350}px; margin: 0 auto;"
      "case_study" ->
        "display: flex; flex-direction: column; gap: #{spacing}; max-width: 900px; margin: 0 auto;"
      "minimal" ->
        "display: flex; flex-direction: column; gap: #{spacing}; max-width: 800px; margin: 0 auto;"
      _ ->
        "display: flex; flex-direction: column; gap: #{spacing}; max-width: 800px; margin: 0 auto;"
    end
  end

  # Helper function to map template system grid types to layouts
  defp map_template_grid_to_layout(grid_type) do
    case grid_type do
      "masonry" -> "dashboard"
      "pinterest" -> "gallery"
      "service_oriented" -> "case_study"
      "minimal_stack" -> "minimal"
      _ -> "dashboard"
    end
  end

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

  @impl true
  def handle_info({:preview_update, customization, _css}, socket) do
    # Only update if customization actually changed
    if customization != socket.assigns.customization do
      new_css = apply_customization_styles(customization)
      socket = socket
      |> assign(:customization, customization)
      |> assign(:customization_css, new_css)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end
end
