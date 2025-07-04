# lib/frestyl_web/controllers/portfolio_export_controller.ex
defmodule FrestylWeb.PortfolioExportController do
  use FrestylWeb, :controller

  alias Frestyl.ResumeExporter
  alias Frestyl.Storage.TempFileStore
  alias Frestyl.Portfolios

  @doc """
  Initiate portfolio export
  """
  def export(conn, %{"portfolio_id" => portfolio_id, "format" => format} = params) do
    current_user = conn.assigns.current_user
    options = Map.get(params, "options", %{})

    with {:ok, portfolio} <- get_accessible_portfolio(portfolio_id, current_user),
         {:ok, export_format} <- validate_export_format(format),
         {:ok, file_info} <- ResumeExporter.export_portfolio(portfolio, export_format, options) do

      # Store export metadata in database
      temp_file_attrs = %{
        filename: file_info.filename,
        original_name: generate_user_friendly_name(portfolio, export_format),
        file_path: file_info.file_path,
        content_type: file_info.content_type,
        file_size: file_info.file_size,
        expires_at: DateTime.add(DateTime.utc_now(), 48, :hour),
        export_format: format,
        export_options: options,
        user_id: current_user.id,
        portfolio_id: portfolio.id
      }

      case TempFileStore.create_temp_file(temp_file_attrs) do
        {:ok, _temp_file} ->
          response_data = %{
            success: true,
            filename: file_info.filename,
            download_url: file_info.download_url,
            file_size: file_info.file_size,
            expires_at: temp_file_attrs.expires_at
          }

          json(conn, response_data)

        {:error, changeset} ->
          # File was created but DB storage failed - still return success
          Logger.warning("Failed to store temp file metadata: #{inspect(changeset.errors)}")

          json(conn, %{
            success: true,
            filename: file_info.filename,
            download_url: file_info.download_url,
            file_size: file_info.file_size,
            warning: "Export successful but metadata storage failed"
          })
      end

    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Portfolio not found"})

      {:error, :access_denied} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Access denied"})

      {:error, :invalid_format} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid export format"})

      {:error, reason} ->
        Logger.error("Export failed: #{inspect(reason)}")

        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Export failed: #{reason}"})
    end
  end

  # Private functions

  defp get_accessible_portfolio(portfolio_id, current_user) do
    case Portfolios.get_portfolio(portfolio_id) do
      nil ->
        {:error, :not_found}

      portfolio ->
        if portfolio.user_id == current_user.id || portfolio.public do
          {:ok, portfolio}
        else
          {:error, :access_denied}
        end
    end
  end

  defp validate_export_format(format) do
    valid_formats = ["ats_resume", "full_portfolio", "html_archive", "docx_resume"]

    if format in valid_formats do
      {:ok, String.to_atom(format)}
    else
      {:error, :invalid_format}
    end
  end

  defp generate_user_friendly_name(portfolio, format) do
    base_name = portfolio.title || "Portfolio"

    suffix =
      case format do
        :ats_resume -> "ATS_Resume"
        :full_portfolio -> "Complete_Portfolio"
        :html_archive -> "Portfolio_Archive"
        :docx_resume -> "Resume"
      end

    "#{base_name}_#{suffix}"
  end
end
