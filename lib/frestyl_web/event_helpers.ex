# lib/frestyl_web/event_helpers.ex
defmodule FrestylWeb.EventHelpers do
  @moduledoc """
  Event-related view helpers.
  """

  def format_datetime(datetime) do
    Calendar.strftime(datetime, "%B %d, %Y at %I:%M %p")
  end

  def format_status(:draft), do: "Draft"
  def format_status(:scheduled), do: "Scheduled"
  def format_status(:live), do: "Live"
  def format_status(:completed), do: "Completed"
  def format_status(:cancelled), do: "Cancelled"

  def format_admission(:open), do: "Open"
  def format_admission(:invite_only), do: "Invite Only"
  def format_admission(:paid), do: "Paid"
  def format_admission(:lottery), do: "Lottery"

  def format_attendee_status(:registered), do: "Registered"
  def format_attendee_status(:waiting), do: "Waiting"
  def format_attendee_status(:admitted), do: "Admitted"
  def format_attendee_status(:rejected), do: "Rejected"

  def format_price(nil), do: "Free"
  def format_price(0), do: "Free"
  def format_price(price_in_cents) when is_integer(price_in_cents) do
    dollars = price_in_cents / 100
    :io_lib.format("$~.2f", [dollars]) |> to_string()
  end
end
