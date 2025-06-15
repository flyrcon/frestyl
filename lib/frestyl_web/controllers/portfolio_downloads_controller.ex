# lib/frestyl_web/controllers/portfolio_downloads_controller.ex
defmodule FrestylWeb.PortfolioDownloadsController do
  use FrestylWeb, :controller

  require Logger
  alias FrestylWeb.Services.PortfolioPdfExport

  def download_pdf(conn, %{"filename" => filename, "user_id" => user_id}) do
    # Verify user ownership
    current_user = conn.assigns.current_user

    unless to_string(current_user.id) == user_id do
      conn
      |> put_status(:forbidden)
      |> put_view(html: FrestylWeb.ErrorHTML)
      |> render(:"403")
      |> halt()
    end

    # Build file path
    file_path = Path.join([
      Application.app_dir(:frestyl, "priv"),
      "static",
      "uploads",
      "portfolios",
      "user_#{user_id}",
      "exports",
      filename
    ])

    if File.exists?(file_path) do
      # Get file stats
      {:ok, stat} = File.stat(file_path)

      # Set appropriate headers for PDF download
      conn
      |> put_resp_content_type("application/pdf")
      |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}\"")
      |> put_resp_header("content-length", to_string(stat.size))
      |> put_resp_header("cache-control", "private, max-age=3600")
      |> send_file(200, file_path)
    else
      Logger.warning("PDF file not found: #{file_path}")

      conn
      |> put_status(:not_found)
      |> put_view(html: FrestylWeb.ErrorHTML)
      |> render(:"404")
    end
  end

  def download_export(conn, %{"filename" => filename}) do
    # Extract user_id from filename or get from current user
    current_user = conn.assigns.current_user

    # Build file path for current user
    file_path = Path.join([
      Application.app_dir(:frestyl, "priv"),
      "static",
      "uploads",
      "portfolios",
      "user_#{current_user.id}",
      "exports",
      filename
    ])

    if File.exists?(file_path) do
      # Determine content type based on file extension
      content_type = case Path.extname(filename) do
        ".pdf" -> "application/pdf"
        ".zip" -> "application/zip"
        ".json" -> "application/json"
        _ -> "application/octet-stream"
      end

      # Get file stats
      {:ok, stat} = File.stat(file_path)

      conn
      |> put_resp_content_type(content_type)
      |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}\"")
      |> put_resp_header("content-length", to_string(stat.size))
      |> put_resp_header("cache-control", "private, max-age=3600")
      |> send_file(200, file_path)
    else
      Logger.warning("Export file not found: #{file_path}")

      conn
      |> put_status(:not_found)
      |> put_view(html: FrestylWeb.ErrorHTML)
      |> render(:"404")
    end
  end

  def list_exports(conn, _params) do
    current_user = conn.assigns.current_user
    exports = PortfolioPdfExport.list_user_exports(current_user.id)

    json(conn, %{
      exports: exports,
      total: length(exports)
    })
  end

  def cleanup_exports(conn, _params) do
    current_user = conn.assigns.current_user
    PortfolioPdfExport.cleanup_old_exports(current_user.id)

    json(conn, %{message: "Cleanup completed"})
  end
end
