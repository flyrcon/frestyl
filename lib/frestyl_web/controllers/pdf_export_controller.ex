defmodule FrestylWeb.PdfExportController do
  use FrestylWeb, :controller

  alias Frestyl.{Portfolios, PdfExport}

  @doc """
  Export portfolio as PDF
  """
  def export(conn, %{"slug" => slug} = params) do
    # Check if portfolio exists and is accessible
    case Portfolios.get_portfolio_by_slug(slug) do
      nil ->
        conn
        |> put_flash(:error, "Portfolio not found")
        |> redirect(to: "/")

      portfolio ->
        if portfolio_accessible?(portfolio) do
          # Get export format
          format = Map.get(params, "format", "portfolio")

          # Track export event
          track_export_event(portfolio, conn)

          # Generate PDF
          case export_portfolio_pdf(portfolio, format) do
            {:ok, export_info} ->
              # Send file for download
              conn
              |> put_resp_content_type("application/pdf")
              |> put_resp_header("content-disposition", "attachment; filename=\"#{export_info.filename}\"")
              |> send_file(200, export_info.path)

            {:error, reason} ->
              conn
              |> put_flash(:error, "Failed to export PDF: #{reason}")
              |> redirect(to: "/p/#{slug}")
          end
        else
          conn
          |> put_flash(:error, "This portfolio is not available for export")
          |> redirect(to: "/")
        end
    end
  end

  @doc """
  Preview PDF export (returns JSON with export URL)
  """
  def preview(conn, %{"slug" => slug} = params) do
    case Portfolios.get_portfolio_by_slug(slug) do
      nil ->
        conn
        |> put_status(404)
        |> json(%{error: "Portfolio not found"})

      portfolio ->
        if portfolio_accessible?(portfolio) do
          format = Map.get(params, "format", "portfolio")

          case export_portfolio_pdf(portfolio, format) do
            {:ok, export_info} ->
              json(conn, %{
                success: true,
                download_url: "/api/exports/download/#{Path.basename(export_info.filename)}",
                filename: export_info.filename,
                size: export_info.size
              })

            {:error, reason} ->
              conn
              |> put_status(500)
              |> json(%{error: reason})
          end
        else
          conn
          |> put_status(403)
          |> json(%{error: "Portfolio not accessible"})
        end
    end
  end

  @doc """
  Download generated PDF file
  """
  def download(conn, %{"filename" => filename}) do
    export_path = Path.join([
      Application.app_dir(:frestyl, "priv"),
      "static",
      "uploads",
      "exports",
      filename
    ])

    if File.exists?(export_path) do
      conn
      |> put_resp_content_type("application/pdf")
      |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}\"")
      |> send_file(200, export_path)
    else
      conn
      |> put_status(404)
      |> json(%{error: "Export file not found"})
    end
  end

  # Private helper functions

  defp portfolio_accessible?(portfolio) do
    # Check if portfolio is public or user has permission
    portfolio.visibility == "public" or portfolio.visibility == "unlisted"
  end

  defp track_export_event(portfolio, conn) do
    # Track export analytics
    try do
      user_agent = get_req_header(conn, "user-agent") |> List.first()
      ip_address = get_peer_data(conn).address |> :inet.ntoa() |> to_string()

      # You can implement analytics tracking here
      # Analytics.track_export(portfolio.id, %{
      #   user_agent: user_agent,
      #   ip_address: ip_address,
      #   timestamp: DateTime.utc_now()
      # })
    rescue
      _ -> :ok # Fail silently for analytics
    end
  end

  defp export_portfolio_pdf(portfolio, format) do
    try do
      case PdfExport.generate_pdf(portfolio, format) do
        {:ok, file_path} ->
          # Get file info
          %{size: size} = File.stat!(file_path)
          filename = Path.basename(file_path)

          {:ok, %{
            path: file_path,
            filename: filename,
            size: size
          }}

        {:error, reason} ->
          {:error, reason}
      end
    rescue
      error ->
        {:error, "PDF generation failed: #{inspect(error)}"}
    end
  end
end
