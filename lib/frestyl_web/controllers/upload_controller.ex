defmodule FrestylWeb.UploadController do
  use FrestylWeb, :controller
  require Logger

  def create(conn, %{"file" => file, "conversation_id" => conversation_id}) do
    Logger.info("Received file upload: #{file.filename}")

    case process_upload(file) do
      {:ok, file_info} ->
        json(conn, %{
          success: true,
          file: file_info,
          conversation_id: conversation_id
        })
      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{success: false, error: reason})
    end
  end

  defp process_upload(%Plug.Upload{} = uploaded_file) do
    filename = "#{Ecto.UUID.generate()}-#{uploaded_file.filename}"
    dest = Path.join(["priv", "static", "uploads", filename])

    # Ensure directory exists
    File.mkdir_p!(Path.dirname(dest))

    case File.cp(uploaded_file.path, dest) do
      :ok ->
        file_info = %{
          original_name: uploaded_file.filename,
          filename: filename,
          path: "/uploads/#{filename}",
          content_type: uploaded_file.content_type,
          size: File.stat!(dest).size
        }
        Logger.info("Successfully uploaded file: #{filename}")
        {:ok, file_info}

      {:error, reason} ->
        Logger.error("Failed to copy uploaded file: #{reason}")
        {:error, "Failed to save file"}
    end
  end
end
