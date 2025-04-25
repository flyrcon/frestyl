# lib/frestyl/media/streamer.ex
defmodule Frestyl.Media.Streamer do
  @moduledoc """
  Handles media streaming functionality.
  """

  import Plug.Conn
  alias Frestyl.Media.Asset
  alias Frestyl.Media.AssetVersion
  alias Frestyl.Media.Storage

  @chunk_size 1_048_576 # 1MB

  @doc """
  Streams a media file to the client with proper headers.
  """
  def stream_media(conn, %AssetVersion{} = version) do
    case Storage.get_file(version.file_path) do
      {:ok, path} ->
        stream_file(conn, path, version.asset.mime_type)
      {:error, reason} ->
        conn
        |> put_status(404)
        |> Phoenix.Controller.json(%{error: "File not found: #{reason}"})
        |> halt()
    end
  end

  defp stream_file(conn, path, content_type) do
    file_size = File.stat!(path).size

    case get_range(conn) do
      :entire ->
        conn
        |> put_resp_content_type(content_type)
        |> put_resp_header("content-length", "#{file_size}")
        |> send_file(200, path)

      {range_start, range_end} ->
        byte_size = range_end - range_start + 1

        conn
        |> put_resp_content_type(content_type)
        |> put_resp_header("content-length", "#{byte_size}")
        |> put_resp_header("content-range", "bytes #{range_start}-#{range_end}/#{file_size}")
        |> put_resp_header("accept-ranges", "bytes")
        |> send_range(path, range_start, byte_size)
    end
  end

  defp get_range(conn) do
    case get_req_header(conn, "range") do
      ["bytes=" <> range] ->
        parse_range(range)
      _ ->
        :entire
    end
  end

  defp parse_range(range) do
    case String.split(range, "-") do
      [start_str, ""] ->
        {String.to_integer(start_str), :infinity}
      [start_str, end_str] ->
        {String.to_integer(start_str), String.to_integer(end_str)}
      _ ->
        :entire
    end
  end

  defp send_range(conn, path, start_offset, byte_size) do
    conn = put_status(conn, 206) # Partial Content

    # Open the file for streaming
    {:ok, file} = File.open(path, [:read, :binary])

    # Seek to the start position
    :file.position(file, start_offset)

    # Stream the content in chunks
    conn = send_chunked(conn, 206)

    stream_chunks(conn, file, byte_size, @chunk_size)
  end

  defp stream_chunks(conn, file, remaining_bytes, chunk_size) when remaining_bytes > 0 do
    bytes_to_read = min(chunk_size, remaining_bytes)

    case :file.read(file, bytes_to_read) do
      {:ok, data} ->
        case chunk(conn, data) do
          {:ok, conn} ->
            stream_chunks(conn, file, remaining_bytes - bytes_to_read, chunk_size)
          {:error, reason} ->
            File.close(file)
            {:error, reason}
        end
      eof ->
        File.close(file)
        conn
    end
  end

  defp stream_chunks(conn, file, _, _) do
    File.close(file)
    conn
  end
end
