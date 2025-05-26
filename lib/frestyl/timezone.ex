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
  Gets the user's timezone or returns UTC as default.
  """
  def get_user_timezone(nil), do: "UTC"
  def get_user_timezone(%{timezone: timezone}) when is_binary(timezone) and timezone != "" do
    timezone
  end
  def get_user_timezone(%{timezone: nil}), do: "UTC"
  def get_user_timezone(%{timezone: ""}), do: "UTC"
  def get_user_timezone(user) when is_map(user) do
    Map.get(user, :timezone, "UTC") || "UTC"
  end
  def get_user_timezone(_), do: "UTC"

  @doc """
  Converts any datetime type to a proper DateTime in UTC for consistent handling.
  This is the key function that solves the DateTime vs NaiveDateTime issues.
  """
  def normalize_to_utc_datetime(nil), do: nil

  def normalize_to_utc_datetime(%DateTime{} = dt) do
    # Already a DateTime, convert to UTC if not already
    case DateTime.shift_zone(dt, "UTC") do
      {:ok, utc_dt} -> utc_dt
      {:error, _} -> dt  # Return original if shift fails
    end
  end

  def normalize_to_utc_datetime(%NaiveDateTime{} = naive_dt) do
    # Assume NaiveDateTime is in UTC and convert to DateTime
    DateTime.from_naive!(naive_dt, "Etc/UTC")
  end

  def normalize_to_utc_datetime(_), do: nil

  @doc """
  Converts a UTC datetime to the user's timezone.
  Now handles both DateTime and NaiveDateTime inputs.
  """
  def to_user_timezone(nil, _timezone), do: nil

  def to_user_timezone(datetime, timezone) when is_binary(timezone) do
    # First normalize to UTC DateTime
    case normalize_to_utc_datetime(datetime) do
      nil -> nil
      utc_datetime ->
        case DateTime.shift_zone(utc_datetime, timezone) do
          {:ok, shifted_datetime} -> shifted_datetime
          {:error, _} -> utc_datetime  # Fallback to UTC if timezone shift fails
        end
    end
  end

  def to_user_timezone(datetime, _timezone) do
    normalize_to_utc_datetime(datetime)
  end

  @doc """
  Converts a datetime from its current timezone to UTC.
  """
  def to_utc(nil, _timezone), do: nil

  def to_utc(datetime, _timezone) when is_struct(datetime, DateTime) do
    case DateTime.shift_zone(datetime, "UTC") do
      {:ok, utc_datetime} -> utc_datetime
      {:error, _} -> datetime
    end
  end

  def to_utc(%NaiveDateTime{} = naive_dt, _timezone) do
    {:ok, DateTime.from_naive!(naive_dt, "Etc/UTC")}
  end

  def to_utc(datetime, _timezone), do: datetime

  @doc """
  Calculates time ago from any datetime type, handling the mixed DateTime/NaiveDateTime issue.
  """
  def time_ago(nil), do: ""

  def time_ago(datetime) do
    case normalize_to_utc_datetime(datetime) do
      nil -> ""
      utc_datetime ->
        now = DateTime.utc_now()
        diff = DateTime.diff(now, utc_datetime, :second)
        format_time_diff(diff)
    end
  end

  # Helper function to format time differences
  defp format_time_diff(diff) when diff < 0, do: "in the future"
  defp format_time_diff(diff) when diff < 60, do: "just now"
  defp format_time_diff(diff) when diff < 3600 do
    minutes = div(diff, 60)
    "#{minutes} #{pluralize("minute", minutes)} ago"
  end
  defp format_time_diff(diff) when diff < 86400 do
    hours = div(diff, 3600)
    "#{hours} #{pluralize("hour", hours)} ago"
  end
  defp format_time_diff(diff) when diff < 2_592_000 do
    days = div(diff, 86400)
    "#{days} #{pluralize("day", days)} ago"
  end
  defp format_time_diff(diff) do
    months = div(diff, 2_592_000)
    "#{months} #{pluralize("month", months)} ago"
  end

  @doc """
  Converts a naive datetime from a specified timezone to UTC datetime.
  """
  def naive_to_utc(naive_datetime_str, timezone) when is_binary(naive_datetime_str) and is_binary(timezone) do
    case NaiveDateTime.from_iso8601(naive_datetime_str) do
      {:ok, naive_dt} -> naive_to_utc(naive_dt, timezone)
      {:error, reason} -> {:error, {:iso_parse_failed, reason}}
    end
  end

  def naive_to_utc(%NaiveDateTime{} = naive_dt, timezone) when is_binary(timezone) do
    case DateTime.from_naive(naive_dt, timezone) do
      {:ok, datetime_in_chosen_tz} ->
        case DateTime.shift_zone(datetime_in_chosen_tz, "UTC") do
          {:ok, utc_datetime} -> {:ok, utc_datetime}
          {:error, reason} -> {:error, {:shift_to_utc_failed, reason}}
        end
      {:error, reason} -> {:error, {:timezone_conversion_failed, reason}}
    end
  end

  def naive_to_utc(%DateTime{} = datetime, _timezone) do
    IO.warn("naive_to_utc called with DateTime struct. Use to_utc/2 instead.")
    {:error, :expected_naive_datetime_got_timezone_aware}
  end

  def naive_to_utc(other, timezone) do
    IO.warn("naive_to_utc called with unexpected type: #{inspect(other)}, timezone: #{inspect(timezone)}")
    {:error, :invalid_argument_type}
  end

  @doc """
  Formats datetime with timezone information.
  """
  def format_with_timezone(nil, _timezone), do: ""

  def format_with_timezone(datetime, user_timezone) do
    case to_user_timezone(datetime, user_timezone) do
      nil -> ""
      local_datetime ->
        format = "%B %d, %Y at %I:%M %p %Z"
        Calendar.strftime(local_datetime, format)
    end
  end

  @doc """
  Compact format with timezone (mm.dd.yy HH:MM)
  """
  def compact_format_with_timezone(nil, _timezone), do: ""

  def compact_format_with_timezone(datetime, user_timezone) do
    case to_user_timezone(datetime, user_timezone) do
      nil -> ""
      local_datetime ->
        Calendar.strftime(local_datetime, "%m.%d.%y %H:%M")
    end
  end

  @doc """
  Calculates readable time until a future event.
  """
  def time_until_with_timezone(nil, _timezone), do: ""

  def time_until_with_timezone(datetime, user_timezone) do
    case {normalize_to_utc_datetime(datetime), user_timezone} do
      {nil, _} -> ""
      {utc_datetime, timezone} ->
        local_datetime = to_user_timezone(utc_datetime, timezone)
        now_local = DateTime.utc_now() |> to_user_timezone(timezone)

        case {local_datetime, now_local} do
          {nil, _} -> ""
          {_, nil} -> ""
          {local_dt, now_dt} ->
            diff = DateTime.diff(local_dt, now_dt, :second)
            format_time_until(diff)
        end
    end
  end

  defp format_time_until(diff) when diff < 0, do: "Past event"
  defp format_time_until(diff) when diff < 60, do: "Starting soon"
  defp format_time_until(diff) when diff < 3600 do
    minutes = div(diff, 60)
    "#{minutes} #{pluralize("minute", minutes)}"
  end
  defp format_time_until(diff) when diff < 86400 do
    hours = div(diff, 3600)
    "#{hours} #{pluralize("hour", hours)}"
  end
  defp format_time_until(diff) when diff < 2_592_000 do
    days = div(diff, 86400)
    "#{days} #{pluralize("day", days)}"
  end
  defp format_time_until(diff) do
    months = div(diff, 2_592_000)
    "#{months} #{pluralize("month", months)}"
  end

  # Helper function for proper pluralization
  defp pluralize(word, 1), do: word
  defp pluralize(word, _), do: word <> "s"
end
