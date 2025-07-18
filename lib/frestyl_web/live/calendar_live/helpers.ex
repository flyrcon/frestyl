defmodule FrestylWeb.CalendarLive.Helpers do
  @moduledoc """
  Helper functions for calendar templates
  """

  def format_date_header(date, view) do
    case view do
      "month" ->
        Calendar.strftime(date, "%B %Y")
      "week" ->
        start_of_week = Date.add(date, -Date.day_of_week(date) + 1)
        end_of_week = Date.add(start_of_week, 6)

        if Date.month(start_of_week) == Date.month(end_of_week) do
          "#{start_of_week.day}-#{end_of_week.day} #{Calendar.strftime(start_of_week, "%B %Y")}"
        else
          "#{Calendar.strftime(start_of_week, "%b %d")} - #{Calendar.strftime(end_of_week, "%b %d, %Y")}"
        end
      "day" ->
        Calendar.strftime(date, "%A, %B %d, %Y")
      "list" ->
        Calendar.strftime(date, "%B %Y")
      _ ->
        Calendar.strftime(date, "%B %Y")
    end
  end

  def get_calendar_weeks(date) do
    start_of_month = Date.beginning_of_month(date)
    end_of_month = Date.end_of_month(date)

    # Get the Monday of the week containing the first day of the month
    start_date = Date.add(start_of_month, -Date.day_of_week(start_of_month) + 1)

    # Get the Sunday of the week containing the last day of the month
    end_date = Date.add(end_of_month, 7 - Date.day_of_week(end_of_month))

    start_date
    |> Date.range(end_date)
    |> Enum.chunk_every(7)
    |> Enum.map(fn week -> Enum.map(week, & &1) end)
  end

  def get_events_for_day(events, date) do
    Enum.filter(events, fn event ->
      event_date = DateTime.to_date(event.starts_at)
      Date.compare(event_date, date) == :eq
    end)
  end

  def get_event_color_class(event_type) do
    case event_type do
      "service_booking" -> "bg-green-100 text-green-800 border-green-200"
      "broadcast" -> "bg-purple-100 text-purple-800 border-purple-200"
      "channel_event" -> "bg-blue-100 text-blue-800 border-blue-200"
      "collaboration" -> "bg-yellow-100 text-yellow-800 border-yellow-200"
      "personal" -> "bg-gray-100 text-gray-800 border-gray-200"
      _ -> "bg-gray-100 text-gray-800 border-gray-200"
    end
  end

  def format_event_time(datetime) do
    Calendar.strftime(datetime, "%I:%M %p")
  end

  def format_event_type(event_type) do
    case event_type do
      "service_booking" -> "Service Booking"
      "channel_event" -> "Channel Event"
      "collaboration" -> "Collaboration"
      _ -> String.capitalize(event_type)
    end
  end
end
