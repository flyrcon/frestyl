# lib/frestyl/event_notifications.ex (continued)
defmodule Frestyl.EventNotifications do
  @moduledoc """
  Handles email notifications for events.
  """

  import Swoosh.Email
  alias Frestyl.Mailer

  @from_email "notifications@frestyl.com"

  def send_invitation_email(invitation, event) do
    accept_url = FrestylWeb.Router.Helpers.invitation_url(FrestylWeb.Endpoint, :accept, invitation.token)
    decline_url = FrestylWeb.Router.Helpers.invitation_url(FrestylWeb.Endpoint, :decline, invitation.token)

    new()
    |> to(invitation.email)
    |> from(@from_email)
    |> subject("You've been invited to an event: #{event.title}")
    |> html_body("""
    <p>Hello,</p>
    <p>You've been invited to the event: <strong>#{event.title}</strong></p>
    <p>Date: #{Calendar.strftime(event.starts_at, "%B %d, %Y at %I:%M %p")}</p>
    <p>Description: #{event.description}</p>
    <p>To respond to this invitation, please click one of the links below:</p>
    <p>
      <a href="#{accept_url}">Accept Invitation</a> |
      <a href="#{decline_url}">Decline Invitation</a>
    </p>
    <p>This invitation will expire on #{Calendar.strftime(invitation.expires_at, "%B %d, %Y")}.</p>
    """)
    |> Mailer.deliver()
  end

  def send_event_reminder(event, attendee) do
    new()
    |> to(attendee.user.email)
    |> from(@from_email)
    |> subject("Reminder: Event #{event.title} is starting soon")
    |> html_body("""
    <p>Hello,</p>
    <p>This is a reminder that the event <strong>#{event.title}</strong> is starting soon.</p>
    <p>Date: #{Calendar.strftime(event.starts_at, "%B %d, %Y at %I:%M %p")}</p>
    <p>
      <a href="#{FrestylWeb.Router.Helpers.event_show_url(FrestylWeb.Endpoint, :show, event.id)}">
        Join the event
      </a>
    </p>
    """)
    |> Mailer.deliver()
  end

  def send_event_started_notification(event, attendee) do
    new()
    |> to(attendee.user.email)
    |> from(@from_email)
    |> subject("Event Started: #{event.title}")
    |> html_body("""
    <p>Hello,</p>
    <p>The event <strong>#{event.title}</strong> has started!</p>
    <p>
      <a href="#{FrestylWeb.Router.Helpers.event_show_url(FrestylWeb.Endpoint, :show, event.id)}">
        Join now
      </a>
    </p>
    """)
    |> Mailer.deliver()
  end

  def send_admission_notification(event, attendee) do
    new()
    |> to(attendee.user.email)
    |> from(@from_email)
    |> subject("You've been admitted to: #{event.title}")
    |> html_body("""
    <p>Hello,</p>
    <p>You have been admitted to the event <strong>#{event.title}</strong>.</p>
    <p>Date: #{Calendar.strftime(event.starts_at, "%B %d, %Y at %I:%M %p")}</p>
    <p>
      <a href="#{FrestylWeb.Router.Helpers.event_show_url(FrestylWeb.Endpoint, :show, event.id)}">
        View event details
      </a>
    </p>
    """)
    |> Mailer.deliver()
  end

  def send_payment_confirmation(event, attendee) do
    new()
    |> to(attendee.user.email)
    |> from(@from_email)
    |> subject("Payment Confirmed for: #{event.title}")
    |> html_body("""
    <p>Hello,</p>
    <p>Your payment for the event <strong>#{event.title}</strong> has been confirmed.</p>
    <p>Amount: #{format_price(attendee.payment_amount_in_cents)}</p>
    <p>You are now registered for the event.</p>
    <p>Date: #{Calendar.strftime(event.starts_at, "%B %d, %Y at %I:%M %p")}</p>
    <p>
      <a href="#{FrestylWeb.Router.Helpers.event_show_url(FrestylWeb.Endpoint, :show, event.id)}">
        View event details
      </a>
    </p>
    """)
    |> Mailer.deliver()
  end

  def send_lottery_result_notification(event, attendee) do
    status = if attendee.status == :admitted, do: "selected", else: "not selected"

    new()
    |> to(attendee.user.email)
    |> from(@from_email)
    |> subject("Lottery Results for: #{event.title}")
    |> html_body("""
    <p>Hello,</p>
    <p>The admission lottery for the event <strong>#{event.title}</strong> has been completed.</p>
    <p>You were <strong>#{status}</strong> in the lottery.</p>
    #{if attendee.status == :admitted do
      """
      <p>You are now registered to attend the event.</p>
      <p>Date: #{Calendar.strftime(event.starts_at, "%B %d, %Y at %I:%M %p")}</p>
      <p>
        <a href="#{FrestylWeb.Router.Helpers.event_show_url(FrestylWeb.Endpoint, :show, event.id)}">
          View event details
        </a>
      </p>
      """
    else
      """
      <p>Unfortunately, you were not selected in this lottery.</p>
      <p>You have been placed on the waiting list, and we will notify you if a spot becomes available.</p>
      """
    end}
    """)
    |> Mailer.deliver()
  end

  defp format_price(price_in_cents) when is_integer(price_in_cents) do
    dollars = price_in_cents / 100
    :io_lib.format("$~.2f", [dollars]) |> to_string()
  end
end
