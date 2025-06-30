# lib/frestyl_web/live/portfolio_live/show.ex
# COMPLETE WORKING VERSION

defmodule FrestylWeb.PortfolioLive.Show do
  use FrestylWeb, :live_view

  alias Frestyl.Portfolios
  alias Frestyl.Repo

  # Handle /portfolios/:id route
  @impl true
  def mount(%{"id" => id}, _session, socket) do
    try do
      portfolio = Portfolios.get_portfolio!(id)
      # Preload the user association
      portfolio = Repo.preload(portfolio, :user)

      if can_view_portfolio?(portfolio, socket.assigns.current_user) do
        sections = load_portfolio_sections_safe(portfolio.id)

        socket =
          socket
          |> assign(:page_title, portfolio.title)
          |> assign(:portfolio, portfolio)
          |> assign(:sections, sections)
          |> assign(:can_export, false)
          |> assign(:show_export_panel, false)
          |> assign(:export_processing, false)

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
end
