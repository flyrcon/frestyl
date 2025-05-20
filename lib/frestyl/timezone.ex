defmodule Frestyl.Timezone do
  @moduledoc """
  Utilities for handling timezones in the application.
  """

  # Common timezones that users are likely to select
  @common_timezones [
    {"UTC", "UTC"},
    {"America/New_York", "Eastern Time (US & Canada)"},
    {"America/Chicago", "Central Time (US & Canada)"},
    {"America/Denver", "Mountain Time (US & Canada)"},
    {"America/Los_Angeles", "Pacific Time (US & Canada)"},
    {"Europe/London", "London"},
    {"Europe/Berlin", "Berlin, Amsterdam, Paris"},
    {"Europe/Rome", "Rome, Madrid"},
    {"Asia/Tokyo", "Tokyo"},
    {"Asia/Shanghai", "Beijing, Shanghai"},
    {"Asia/Kolkata", "Mumbai, Delhi"},
    {"Australia/Sydney", "Sydney"},
    {"Australia/Melbourne", "Melbourne"}
  ]

  @doc """
  Returns a list of common timezones for user selection.
  """
  def common_timezones, do: @common_timezones

  @doc """
  Gets the user's timezone or defaults to UTC.
  """
  def get_user_timezone(user) do
    if user && user.timezone do
      user.timezone
    else
      "UTC"
    end
  end

  @doc """
  Converts a UTC datetime to the user's timezone.
  """
  def to_user_timezone(nil, _timezone), do: nil
  def to_user_timezone(utc_datetime, timezone) when is_binary(timezone) do
    case DateTime.shift_zone(utc_datetime, timezone) do
      {:ok, datetime} -> datetime
      {:error, _} -> utc_datetime
    end
  end
  def to_user_timezone(utc_datetime, _timezone), do: utc_datetime

  @doc """
  Converts a user timezone datetime to UTC.
  """
  def to_utc(nil, _timezone), do: nil
  def to_utc(datetime, timezone) when is_binary(timezone) do
    case DateTime.shift_zone(datetime, "UTC") do
      {:ok, utc_datetime} -> utc_datetime
      {:error, _} -> datetime
    end
  end
  def to_utc(datetime, _timezone), do: datetime

  @doc """
  Converts a naive datetime with timezone string to UTC datetime.
  """
  def naive_to_utc(naive_datetime, timezone) when is_binary(naive_datetime) do
    case NaiveDateTime.from_iso8601(naive_datetime) do
      {:ok, naive} -> naive_to_utc(naive, timezone)
      error -> error
    end
  end

  def naive_to_utc(%NaiveDateTime{} = naive, timezone) do
    # Convert to DateTime in the specified timezone
    case DateTime.from_naive(naive, timezone) do
      {:ok, datetime} -> {:ok, datetime}
      error -> error
    end
  end

  @doc """
  Formats datetime with timezone information.
  """
  def format_with_timezone(nil, _timezone), do: ""
  def format_with_timezone(utc_datetime, user_timezone) do
    local_datetime = to_user_timezone(utc_datetime, user_timezone)

    # Format with timezone abbreviation
    format = "%B %d, %Y at %I:%M %p %Z"
    Calendar.strftime(local_datetime, format)
  end

  @doc """
  Compact format with timezone, specifically in mm.dd.yy format
  """
  def compact_format_with_timezone(nil, _timezone), do: ""
  def compact_format_with_timezone(utc_datetime, user_timezone) do
    local_datetime = to_user_timezone(utc_datetime, user_timezone)

    # Format as mm.dd.yy HH:MM
    Calendar.strftime(local_datetime, "%m.%d.%y %H:%M")
  end

  @doc """
  Calculates readable time until a future event based on user timezone.
  """
  def time_until_with_timezone(nil, _timezone), do: ""
  def time_until_with_timezone(utc_datetime, user_timezone) do
    local_datetime = to_user_timezone(utc_datetime, user_timezone)
    now = DateTime.utc_now() |> to_user_timezone(user_timezone)
    diff = DateTime.diff(local_datetime, now, :second)

    cond do
      diff < 0 -> "Past event"
      diff < 60 -> "Starting soon"
      diff < 3600 ->
        minutes = div(diff, 60)
        "#{minutes} #{pluralize("minute", minutes)}"
      diff < 86400 ->
        hours = div(diff, 3600)
        "#{hours} #{pluralize("hour", hours)}"
      diff < 2_592_000 ->
        days = div(diff, 86400)
        "#{days} #{pluralize("day", days)}"
      true ->
        months = div(diff, 2_592_000)
        "#{months} #{pluralize("month", months)}"
    end
  end

  # Helper function for proper pluralization
  defp pluralize(word, 1), do: word
  defp pluralize(word, _), do: word <> "s"
end
