# lib/frestyl_web/live/media_live/media_helpers.ex
defmodule FrestylWeb.MediaLive.MediaHelpers do
  @moduledoc """
  Shared helper functions for media-related LiveViews and components.
  """

  @doc """
  Formats bytes into human-readable format.
  """
  def format_bytes(bytes) when is_number(bytes) do
    cond do
      bytes >= 1_000_000_000 -> "#{Float.round(bytes / 1_000_000_000, 1)} GB"
      bytes >= 1_000_000 -> "#{Float.round(bytes / 1_000_000, 1)} MB"
      bytes >= 1_000 -> "#{Float.round(bytes / 1_000, 1)} KB"
      true -> "#{bytes} B"
    end
  end

  def format_bytes(_), do: "0 B"

  @doc """
  Formats numbers with K/M suffixes.
  """
  def format_number(number) when is_number(number) do
    cond do
      number >= 1_000_000 -> "#{Float.round(number / 1_000_000, 1)}M"
      number >= 1_000 -> "#{Float.round(number / 1_000, 1)}K"
      true -> "#{number}"
    end
  end

  def format_number(_), do: "0"

  @doc """
  Formats datetime into relative time format.
  """
  def format_relative_time(datetime) do
    now = case datetime do
      %DateTime{} -> DateTime.utc_now()
      %NaiveDateTime{} -> NaiveDateTime.utc_now()
    end

    diff = case datetime do
      %DateTime{} -> DateTime.diff(now, datetime, :second)
      %NaiveDateTime{} -> NaiveDateTime.diff(now, datetime, :second)
    end

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      diff < 604800 -> "#{div(diff, 86400)}d ago"
      diff < 2592000 -> "#{div(diff, 604800)}w ago"
      true -> "#{div(diff, 2592000)}mo ago"
    end
  end

  @doc """
  Media type styling helpers.
  """
  def media_type_bg("image"), do: "bg-purple-100"
  def media_type_bg("video"), do: "bg-blue-100"
  def media_type_bg("audio"), do: "bg-green-100"
  def media_type_bg("document"), do: "bg-yellow-100"
  def media_type_bg("other"), do: "bg-gray-100"
  def media_type_bg(_), do: "bg-gray-100"

  def media_type_color("image"), do: "text-purple-600"
  def media_type_color("video"), do: "text-blue-600"
  def media_type_color("audio"), do: "text-green-600"
  def media_type_color("document"), do: "text-yellow-600"
  def media_type_color("other"), do: "text-gray-600"
  def media_type_color(_), do: "text-gray-600"

  def media_type_badge_color("image"), do: "bg-purple-100 text-purple-800 border border-purple-200"
  def media_type_badge_color("video"), do: "bg-blue-100 text-blue-800 border border-blue-200"
  def media_type_badge_color("audio"), do: "bg-green-100 text-green-800 border border-green-200"
  def media_type_badge_color("document"), do: "bg-yellow-100 text-yellow-800 border border-yellow-200"
  def media_type_badge_color("other"), do: "bg-gray-100 text-gray-800 border border-gray-200"
  def media_type_badge_color(_), do: "bg-gray-100 text-gray-800 border border-gray-200"

  def content_type_badge_color("image"), do: "bg-purple-100 text-purple-800"
  def content_type_badge_color("video"), do: "bg-blue-100 text-blue-800"
  def content_type_badge_color("audio"), do: "bg-green-100 text-green-800"
  def content_type_badge_color("document"), do: "bg-yellow-100 text-yellow-800"
  def content_type_badge_color("other"), do: "bg-gray-100 text-gray-800"
  def content_type_badge_color(_), do: "bg-gray-100 text-gray-800"

  @doc """
  Media type icon SVG paths.
  """
  def media_type_icon("image") do
    """
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
    """
  end

  def media_type_icon("video") do
    """
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z" />
    """
  end

  def media_type_icon("audio") do
    """
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3" />
    """
  end

  def media_type_icon("document") do
    """
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
    """
  end

  def media_type_icon(_) do
    """
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 21h10a2 2 0 002-2V9.414a1 1 0 00-.293-.707l-5.414-5.414A1 1 0 0012.586 3H7a2 2 0 00-2 2v14a2 2 0 002 2z" />
    """
  end

  @doc """
  Checks if a file is trending based on recent view activity.
  """
  def is_trending?(file) do
    recent_views = get_recent_views(file, 24) # Last 24 hours
    total_views = get_in(file.metadata, ["views"]) || 0

    # Trending if >50% of views are recent and has >10 total views
    total_views > 10 and recent_views > (total_views * 0.5)
  end

  @doc """
  Gets recent views for a file within the specified hours.
  """
  def get_recent_views(file, hours_ago) do
    cutoff = DateTime.utc_now() |> DateTime.add(-hours_ago, :hour)
    view_history = get_in(file.metadata, ["view_history"]) || []

    Enum.reduce(view_history, 0, fn entry, acc ->
      case DateTime.from_iso8601(entry["date"] || "") do
        {:ok, date, _} ->
          if DateTime.compare(date, cutoff) == :gt do
            acc + (entry["count"] || 0)
          else
            acc
          end
        _ -> acc
      end
    end)
  end

  @doc """
  Gets engagement data for a file.
  """
  def get_engagement_data(file) do
    %{
      views: get_in(file.metadata, ["views"]) || 0,
      comments: get_in(file.metadata, ["comments"]) || 0,
      reactions: get_in(file.metadata, ["reactions"]) || %{},
      is_trending: is_trending?(file)
    }
  end
end
