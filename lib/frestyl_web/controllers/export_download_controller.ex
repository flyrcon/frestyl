# lib/frestyl_web/controllers/export_download_controller.ex
defmodule FrestylWeb.ExportDownloadController do
  use FrestylWeb, :controller

  alias Frestyl.Storage.{TempFileManager, TempFileStore}
  alias Frestyl.Portfolios

  require Logger

  @doc """
  Download exported portfolio file
  """
  def download(conn, %{"filename" => filename}) do
    with {:ok, file_info} <- validate_file_access(conn, filename),
         {:ok, file_content} <- read_file(file_info.file_path) do

      # Increment download count
      TempFileStore.increment_download_count(filename)

      # Set response headers for download
      conn
      |> put_resp_header("content-type", file_info.content_type)
      |> put_resp_header("content-disposition", ~s[attachment; filename="#{file_info.original_name || filename}"])
      |> put_resp_header("content-length", to_string(byte_size(file_content)))
      |> put_resp_header("cache-control", "no-cache, no-store, must-revalidate")
      |> send_resp(200, file_content)

    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "File not found or expired"})

      {:error, :access_denied} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Access denied"})

      {:error, :file_read_error} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Unable to read file"})

      {:error, reason} ->
        Logger.error("Download error for #{filename}: #{inspect(reason)}")

        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Download failed"})
    end
  end

  @doc """
  Get download information without downloading
  """
  def download_info(conn, %{"filename" => filename}) do
    case validate_file_access(conn, filename) do
      {:ok, file_info} ->
        response_data = %{
          filename: file_info.filename,
          original_name: file_info.original_name,
          content_type: file_info.content_type,
          file_size: file_info.file_size,
          download_count: file_info.download_count || 0,
          expires_at: file_info.expires_at,
          created_at: file_info.inserted_at
        }

        json(conn, response_data)

      {:error, reason} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "File not found or access denied"})
    end
  end

  @doc """
  List user's export files
  """
  def list_exports(conn, _params) do
    current_user = conn.assigns.current_user

    temp_files = TempFileStore.list_user_temp_files(current_user.id)

    response_data =
      temp_files
      |> Enum.map(fn file ->
        %{
          filename: file.filename,
          original_name: file.original_name,
          content_type: file.content_type,
          file_size: file.file_size,
          download_count: file.download_count,
          export_format: file.export_format,
          expires_at: file.expires_at,
          created_at: file.inserted_at,
          download_url: Routes.export_download_path(conn, :download, file.filename)
        }
      end)

    json(conn, %{exports: response_data})
  end

  @doc """
  Delete an export file
  """
  def delete_export(conn, %{"filename" => filename}) do
    current_user = conn.assigns.current_user

    case TempFileStore.get_temp_file(filename) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "File not found"})

      temp_file ->
        if temp_file.user_id == current_user.id do
          # Clean up file from filesystem
          TempFileManager.cleanup_file(filename)

          # Remove from database
          Repo.delete(temp_file)

          json(conn, %{message: "Export deleted successfully"})
        else
          conn
          |> put_status(:forbidden)
          |> json(%{error: "Access denied"})
        end
    end
  end

  # Private functions

  defp validate_file_access(conn, filename) do
    current_user = conn.assigns[:current_user]

    # Check if file exists in memory manager
    case TempFileManager.get_temp_file(filename) do
      nil ->
        # Check database store
        check_database_file(filename, current_user)

      file_info ->
        # Validate access to memory-managed file
        validate_memory_file_access(file_info, current_user)
    end
  end

  defp check_database_file(filename, current_user) do
    case TempFileStore.get_temp_file(filename) do
      nil ->
        {:error, :not_found}

      temp_file ->
        # Check if user has access to this file
        if has_file_access?(temp_file, current_user) do
          file_info = %{
            filename: temp_file.filename,
            original_name: temp_file.original_name,
            file_path: temp_file.file_path,
            content_type: temp_file.content_type,
            file_size: temp_file.file_size,
            expires_at: temp_file.expires_at,
            inserted_at: temp_file.inserted_at,
            download_count: temp_file.download_count
          }

          {:ok, file_info}
        else
          {:error, :access_denied}
        end
    end
  end

  defp validate_memory_file_access(file_info, current_user) do
    # For memory-managed files, we need to check access differently
    # This is a simplified check - you may want more sophisticated logic
    if current_user do
      {:ok, file_info}
    else
      {:error, :access_denied}
    end
  end

  defp has_file_access?(temp_file, current_user) do
    cond do
      # User owns the file
      temp_file.user_id == current_user.id ->
        true

      # User has access to the portfolio that generated this file
      temp_file.portfolio_id && can_access_portfolio?(temp_file.portfolio_id, current_user) ->
        true

      # Admin access (if you have admin roles)
      is_admin?(current_user) ->
        true

      # Default deny
      true ->
        false
    end
  end

  defp can_access_portfolio?(portfolio_id, current_user) do
    case Portfolios.get_portfolio(portfolio_id) do
      nil -> false
      portfolio ->
        # Check if portfolio is public or user has access
        portfolio.public || portfolio.user_id == current_user.id
    end
  end

  defp is_admin?(user) do
    # Implement your admin role checking logic
    user.role == "admin"
  end

  defp read_file(file_path) do
    case File.read(file_path) do
      {:ok, content} -> {:ok, content}
      {:error, _reason} -> {:error, :file_read_error}
    end
  end
end
