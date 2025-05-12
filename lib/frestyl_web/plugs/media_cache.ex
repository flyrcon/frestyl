defmodule FrestylWeb.Plugs.MediaCache do
  @moduledoc """
  Plug for handling advanced HTTP caching headers for media assets.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    conn = put_resp_header(conn, "vary", "accept-encoding")

    # Check if we have If-None-Match header (ETag)
    case get_req_header(conn, "if-none-match") do
      [etag] ->
        if_none_match(conn, etag)
      _ ->
        # Check if we have If-Modified-Since header
        case get_req_header(conn, "if-modified-since") do
          [if_modified_since] ->
            if_modified_since(conn, if_modified_since)
          _ ->
            conn
        end
    end
  end

  # Handle ETags
  defp if_none_match(conn, etag) do
    path = conn.request_path
    current_etag = generate_etag(path)

    if current_etag == etag do
      conn
      |> put_resp_header("etag", current_etag)
      |> send_resp(304, "")
      |> halt()
    else
      conn
      |> put_resp_header("etag", current_etag)
    end
  end

  # Handle If-Modified-Since
  defp if_modified_since(conn, if_modified_since) do
    path = conn.request_path
    last_modified = get_last_modified(path)
    if_modified_since_date = parse_http_date(if_modified_since)

    if !is_nil(last_modified) && !is_nil(if_modified_since_date) &&
       DateTime.compare(last_modified, if_modified_since_date) != :gt do
      conn
      |> put_resp_header("last-modified", format_http_date(last_modified))
      |> send_resp(304, "")
      |> halt()
    else
      if !is_nil(last_modified) do
        put_resp_header(conn, "last-modified", format_http_date(last_modified))
      else
        conn
      end
    end
  end

  # Generate an ETag for a file
  defp generate_etag(path) do
    # Extract the actual file path from the request path
    # This is a simplification - you might need to adjust based on your routing
    file_path = if String.starts_with?(path, "/uploads/") do
      Path.join([Application.app_dir(:frestyl), "priv", path])
    else
      nil
    end

    if file_path && File.exists?(file_path) do
      {size, mtime} = File.stat!(file_path, time: :posix) |> Map.take([:size, :mtime]) |> Map.values() |> List.to_tuple()
      hash = :crypto.hash(:md5, "#{path}:#{size}:#{mtime}") |> Base.encode16(case: :lower)
      ~s("#{hash}")
    else
      nil
    end
  end

  # Get the last modified time for a file
  defp get_last_modified(path) do
    file_path = if String.starts_with?(path, "/uploads/") do
      Path.join([Application.app_dir(:frestyl), "priv", path])
    else
      nil
    end

    if file_path && File.exists?(file_path) do
      case File.stat(file_path, time: :posix) do
        {:ok, %{mtime: mtime}} ->
          DateTime.from_unix!(mtime)
        _ ->
          nil
      end
    else
      nil
    end
  end

  # Parse an HTTP date
  defp parse_http_date(date_string) do
    case Timex.parse(date_string, "{RFC1123}") do
      {:ok, datetime} -> datetime
      _ -> nil
    end
  end

  # Format a datetime as an HTTP date
  defp format_http_date(datetime) do
    Timex.format!(datetime, "{RFC1123}")
  end
end
