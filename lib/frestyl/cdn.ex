# lib/frestyl/cdn.ex
defmodule Frestyl.CDN do
  @moduledoc """
  Helper module for CDN URLs.
  """

  @doc """
  Returns a CDN URL for the given path, if CDN is configured.
  Otherwise, returns the original path.
  """
  def url(path) do
    if cdn_enabled?() do
      cdn_host = Application.get_env(:frestyl, :cdn)[:host] || ""
      path_with_host = if String.starts_with?(path, "/"), do: path, else: "/#{path}"
      "#{cdn_host}#{path_with_host}"
    else
      path
    end
  end

  @doc """
  Returns a CDN URL for a media item, if it's a public branding asset.
  For non-public or non-branding assets, returns the original URL.
  """
  def media_url(media_item) do
    if cdn_eligible?(media_item) do
      url(media_item.file_path)
    else
      media_item.file_path
    end
  end

  defp cdn_enabled? do
    case Application.get_env(:frestyl, :cdn) do
      nil -> false
      config -> Keyword.get(config, :enabled, false)
    end
  end

  defp cdn_eligible?(media_item) do
    # Only public branding assets can be served via CDN
    media_item.category == "branding" && media_item.visibility == "public"
  end
end
