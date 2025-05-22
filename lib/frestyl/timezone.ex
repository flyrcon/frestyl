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
  This is the function that show.ex is looking for.
  """
  def get_user_timezone(%{timezone: timezone}) when is_binary(timezone) and timezone != "" do
    timezone
  end

  def get_user_timezone(%{timezone: nil}) do
    "UTC"
  end

  def get_user_timezone(%{timezone: ""}) do
    "UTC"
  end

  def get_user_timezone(_user) do
    "UTC"
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
  Converts a datetime from its current timezone to UTC.
  This function assumes the input datetime has a timezone and will shift it to UTC.
  """
  def to_utc(nil, _timezone), do: nil
  def to_utc(datetime, _timezone) when is_struct(datetime, DateTime) do
    # This will shift the datetime to UTC, preserving the point in time
    case DateTime.shift_zone(datetime, "UTC") do
      {:ok, utc_datetime} -> utc_datetime
      {:error, _} -> datetime # Fallback if shifting fails
    end
  end
  # Add a clause for NaiveDateTime if you want to handle it here
  # def to_utc(%NaiveDateTime{} = naive_dt, timezone) when is_binary(timezone) do
  #   naive_to_utc(naive_dt, timezone) # Reuse the naive_to_utc logic
  # end
  def to_utc(datetime, _timezone), do: datetime # Catch-all for other types or invalid inputs


  @doc """
  Converts a naive datetime (or its string representation)
  from a specified timezone to a UTC datetime.
  """
  # Handle string input first, convert to NaiveDateTime, then call self
  def naive_to_utc(naive_datetime_str, timezone)
      when is_binary(naive_datetime_str) and is_binary(timezone) do
    case NaiveDateTime.from_iso8601(naive_datetime_str) do
      {:ok, naive_dt} ->
        naive_to_utc(naive_dt, timezone) # Recurse with NaiveDateTime struct
      {:error, reason} ->
        # For example: {:error, :invalid_iso_string_format}
        {:error, {:iso_parse_failed, reason}}
    end
  end

  # Clause 2: Handles NaiveDateTime struct input
  def naive_to_utc(%NaiveDateTime{} = naive_dt, timezone) when is_binary(timezone) do
    # First, assume the naive_dt is in the 'timezone' provided.
    case DateTime.from_naive(naive_dt, timezone) do
      {:ok, datetime_in_chosen_tz} ->
        # Then, shift that DateTime to UTC. This is the crucial step.
        case DateTime.shift_zone(datetime_in_chosen_tz, "UTC") do
          {:ok, utc_datetime} -> {:ok, utc_datetime}
          {:error, reason} -> {:error, {:shift_to_utc_failed, reason}}
        end
      {:error, reason} ->
        # For example: {:error, :invalid_timezone_for_naive_conversion}
        {:error, {:timezone_conversion_failed, reason}}
    end
  end

  # IMPORTANT: Add a specific clause to catch and error if a DateTime struct is passed.
  # This makes the function's contract explicit: it's for *naive* conversions.
  def naive_to_utc(%DateTime{} = datetime, _timezone) do
    IO.warn("Frestyl.Timezone.naive_to_utc was called with a DateTime struct (#{inspect(datetime)}). This function is designed to convert *naive* datetimes from a specified timezone to UTC. If the datetime is already timezone-aware, consider using Frestyl.Timezone.to_utc/2 directly or ensuring the input is naive.")
    {:error, :expected_naive_datetime_got_timezone_aware}
  end

  # Catch-all for any other unexpected types
  def naive_to_utc(other, timezone) do
    IO.warn("Frestyl.Timezone.naive_to_utc called with unexpected type for naive_datetime: #{inspect(other)}. Timezone: #{inspect(timezone)}")
    {:error, :invalid_argument_type}
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
