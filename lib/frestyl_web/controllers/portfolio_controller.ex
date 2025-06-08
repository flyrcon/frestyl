# lib/frestyl_web/controllers/portfolio_controller.ex
defmodule FrestylWeb.PortfolioController do
  use FrestylWeb, :controller

  alias Frestyl.Portfolios
  alias Frestyl.Portfolios.Portfolio
  alias FrestylWeb.PortfolioHTML

  # Public portfolio viewing
  def show(conn, %{"slug" => slug}) do
    case Portfolios.get_portfolio_by_slug(slug) do
      nil ->
        conn
        |> put_status(:not_found)
        |> put_view(FrestylWeb.ErrorHTML)
        |> render(:"404")

      portfolio ->
        # Check if portfolio is accessible
        if portfolio_accessible?(portfolio, conn) do
          sections = Portfolios.list_portfolio_sections(portfolio.id) |> Enum.filter(& &1.visible)

          # Track view if not the owner
          unless owns_portfolio?(portfolio, conn) do
            track_portfolio_view(portfolio, conn)
          end

          conn
          |> assign(:portfolio, portfolio)
          |> assign(:sections, sections)
          |> put_layout(false) # Use custom layout for portfolios
          |> render(:show)
        else
          conn
          |> put_status(:forbidden)
          |> put_flash(:error, "This portfolio is private.")
          |> redirect(to: "/")
        end
    end
  end

  # Portfolio PDF export
  def export(conn, %{"slug" => slug}) do
    case Portfolios.get_portfolio_by_slug(slug) do
      nil ->
        conn
        |> put_status(:not_found)
        |> put_view(FrestylWeb.ErrorHTML)
        |> render(:"404")

      portfolio ->
        if portfolio_accessible?(portfolio, conn) and portfolio.allow_resume_export do
          # Generate PDF export
          case generate_portfolio_pdf(portfolio, conn) do
            {:ok, pdf_data} ->
              filename = sanitize_filename("#{portfolio.title || portfolio.slug}-portfolio.pdf")

              conn
              |> put_resp_content_type("application/pdf")
              |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}\"")
              |> send_resp(200, pdf_data)

            {:error, reason} ->
              conn
              |> put_flash(:error, "Failed to generate PDF export: #{reason}")
              |> redirect(to: "/p/#{slug}")
          end
        else
          conn
          |> put_status(:forbidden)
          |> put_flash(:error, "PDF export is not enabled for this portfolio.")
          |> redirect(to: "/p/#{slug}")
        end
    end
  end

  # Portfolio sharing management
  def share(conn, %{"id" => id}) do
    portfolio = get_user_portfolio!(id, conn)
    shares = Portfolios.list_portfolio_shares(portfolio.id)

    conn
    |> assign(:portfolio, portfolio)
    |> assign(:shares, shares)
    |> assign(:changeset, Portfolios.change_share(%Portfolios.PortfolioShare{}))
    |> render(:share)
  end

  def create_share(conn, %{"id" => id, "share" => share_params}) do
    portfolio = get_user_portfolio!(id, conn)

    share_attrs =
      share_params
      |> Map.put("portfolio_id", portfolio.id)
      |> Map.put("created_by_user_id", conn.assigns.current_user.id)

    case Portfolios.create_share(share_attrs) do
      {:ok, share} ->
        # Fix: Use proper URL generation
        share_url = "#{FrestylWeb.Endpoint.url()}/collaborate/#{share.token}"

        conn
        |> put_flash(:info, "Share link created! URL: #{share_url}")
        |> redirect(to: "/portfolios/#{id}/share")  # Also fix this redirect

      {:error, changeset} ->
        shares = Portfolios.list_portfolio_shares(portfolio.id)

        conn
        |> assign(:portfolio, portfolio)
        |> assign(:shares, shares)
        |> assign(:changeset, changeset)
        |> put_flash(:error, "Failed to create share link")
        |> render(:share)
    end
  end

  # Portfolio analytics
  def analytics(conn, %{"id" => id}) do
    portfolio = get_user_portfolio!(id, conn)

    # Get analytics data with date range
    date_range = get_date_range_from_params(conn.params)
    analytics_data = Portfolios.get_portfolio_analytics(portfolio.id, conn.assigns.current_user.id, date_range)

    conn
    |> assign(:portfolio, portfolio)
    |> assign(:analytics, analytics_data)
    |> assign(:date_range, date_range)
    |> render(:analytics)
  end

  # API endpoints for portfolio data
  def api_show(conn, %{"id" => id}) do
    portfolio = get_user_portfolio!(id, conn)
    sections = Portfolios.list_portfolio_sections(portfolio.id)

    portfolio_data = %{
      id: portfolio.id,
      title: portfolio.title,
      description: portfolio.description,
      slug: portfolio.slug,
      theme: portfolio.theme,
      visibility: portfolio.visibility,
      created_at: portfolio.inserted_at,
      updated_at: portfolio.updated_at,
      sections: Enum.map(sections, &format_section_for_api/1)
    }

    json(conn, %{portfolio: portfolio_data})
  end

  def export_api(conn, %{"id" => id, "format" => format}) do
    portfolio = get_user_portfolio!(id, conn)

    case format do
      "pdf" ->
        case generate_portfolio_pdf(portfolio, conn) do
          {:ok, pdf_data} ->
            conn
            |> put_resp_content_type("application/pdf")
            |> send_resp(200, pdf_data)

          {:error, reason} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "Failed to generate PDF: #{reason}"})
        end

      "json" ->
        sections = Portfolios.list_portfolio_sections(portfolio.id)
        portfolio_data = %{
          portfolio: portfolio,
          sections: Enum.map(sections, &format_section_for_api/1)
        }

        json(conn, portfolio_data)

      "html" ->
        sections = Portfolios.list_visible_portfolio_sections(portfolio.id)

        html_content = Phoenix.View.render_to_string(
          FrestylWeb.PortfolioHTML,
          "export.html",
          portfolio: portfolio,
          sections: sections
        )

        conn
        |> put_resp_content_type("text/html")
        |> send_resp(200, html_content)

      _ ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Unsupported export format. Supported: pdf, json, html"})
    end
  end

  # Helper functions
  defp portfolio_accessible?(portfolio, conn) do
    case portfolio.visibility do
      :public -> true
      :link_only -> true
      :private -> owns_portfolio?(portfolio, conn)
    end
  end

  defp owns_portfolio?(portfolio, conn) do
    case conn.assigns[:current_user] do
      nil -> false
      user -> user.id == portfolio.user_id
    end
  end

  defp get_user_portfolio!(id, conn) do
    portfolio = Portfolios.get_portfolio!(id)

    unless owns_portfolio?(portfolio, conn) do
      raise Phoenix.Router.NoRouteError, conn: conn, router: FrestylWeb.Router
    end

    portfolio
  end

  defp track_portfolio_view(portfolio, conn) do
    visitor_info = %{
      portfolio_id: portfolio.id,
      ip_address: get_client_ip(conn),
      user_agent: get_user_agent(conn),
      referrer: get_referrer(conn),
      viewed_at: DateTime.utc_now()
    }

    # Track view asynchronously to avoid slowing down the request
    Task.start(fn ->
      Portfolios.track_portfolio_view(visitor_info)
    end)
  end

  defp get_client_ip(conn) do
    case get_peer_data(conn) do
      %{address: address} ->
        address |> :inet.ntoa() |> to_string()
      _ ->
        "unknown"
    end
  rescue
    _ -> "unknown"
  end

  defp get_user_agent(conn) do
    case get_req_header(conn, "user-agent") do
      [user_agent] -> user_agent
      _ -> "unknown"
    end
  end

  defp get_referrer(conn) do
    case get_req_header(conn, "referer") do
      [referrer] -> referrer
      _ -> nil
    end
  end

  defp get_date_range_from_params(params) do
    start_date = case Map.get(params, "start_date") do
      nil -> Date.utc_today() |> Date.add(-30) # Default: last 30 days
      date_string -> Date.from_iso8601!(date_string)
    end

    end_date = case Map.get(params, "end_date") do
      nil -> Date.utc_today()
      date_string -> Date.from_iso8601!(date_string)
    end

    {start_date, end_date}
  end

  defp format_section_for_api(section) do
    %{
      id: section.id,
      title: section.title,
      section_type: section.section_type,
      content: section.content,
      position: section.position,
      visible: section.visible,
      created_at: section.inserted_at,
      updated_at: section.updated_at
    }
  end

  defp sanitize_filename(filename) do
    filename
    |> String.replace(~r/[^a-zA-Z0-9._-]/, "-")
    |> String.replace(~r/-+/, "-")
    |> String.trim("-")
  end

  defp generate_portfolio_pdf(portfolio, conn) do
    try do
      # Get portfolio sections
      sections = Portfolios.list_visible_portfolio_sections(portfolio.id)

      # Render HTML for PDF conversion
      html_content = Phoenix.View.render_to_string(
        FrestylWeb.PortfolioHTML,
        "pdf_export.html",
        portfolio: portfolio,
        sections: sections,
        base_url: FrestylWeb.Endpoint.url()
      )

      # Convert HTML to PDF using a PDF library
      # You'll need to add a PDF library like PuppeteerPdf, ChromicPDF, or similar
      case convert_html_to_pdf(html_content) do
        {:ok, pdf_binary} -> {:ok, pdf_binary}
        {:error, reason} -> {:error, "PDF generation failed: #{reason}"}
      end

    rescue
      error ->
        {:error, "PDF generation error: #{Exception.message(error)}"}
    end
  end

  # Placeholder for PDF conversion - implement with your preferred PDF library
  defp convert_html_to_pdf(html_content) do
    # Option 1: Using ChromicPDF (recommended)
    # ChromicPDF.print_to_binary({:html, html_content}, size: :a4)

    # Option 2: Using PuppeteerPdf
    # PuppeteerPdf.generate_binary(html_content, format: "A4")

    # Option 3: Simple fallback - return HTML as "PDF" (for development)
    {:ok, html_content}
  end
end
