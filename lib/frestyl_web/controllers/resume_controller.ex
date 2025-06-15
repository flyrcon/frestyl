defmodule FrestylWeb.ResumeController do
  use FrestylWeb, :controller

  alias Frestyl.ResumeParser

  def parse(conn, %{"resume" => upload}) do
    case process_uploaded_resume(upload) do
      {:ok, parsed_data} ->
        json(conn, %{
          success: true,
          data: parsed_data
        })

      {:error, reason} ->
        conn
        |> put_status(422)
        |> json(%{
          success: false,
          error: reason
        })
    end
  end

  defp process_uploaded_resume(%Plug.Upload{path: path, filename: filename}) do
    ResumeParser.parse_resume_with_filename(path, filename)
  end

  defp process_uploaded_resume(_), do: {:error, "Invalid file upload"}
end
