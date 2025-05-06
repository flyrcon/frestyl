# lib/frestyl/accounts/user_notifier.ex
defmodule Frestyl.Accounts.UserNotifier do
  import Swoosh.Email
  alias Frestyl.Mailer

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"Frestyl", "noreply@frestyl.com"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver instructions to confirm account.
  """
  def deliver_confirmation_instructions(user, url) do
    new()
    |> to({user.name || user.email, user.email})
    |> from({"Frestyl", "noreply@frestyl.com"})
    |> subject("Confirm your Frestyl account")
    |> html_body("""
    <!DOCTYPE html>
    <html>
      <head>
        <meta charset="UTF-8">
        <title>Confirm your Frestyl account</title>
      </head>
      <body style="font-family: sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <h2 style="color: #DD1155;">Welcome to Frestyl!</h2>
        <p>Thank you for signing up. Please confirm your account by clicking the link below:</p>
        <p>
          <a href="#{url}" style="background-color: #DD1155; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px; display: inline-block;">
            Confirm My Account
          </a>
        </p>
        <p>If you didn't create an account, please ignore this email.</p>
        <p>Thanks,<br>The Frestyl Team</p>
      </body>
    </html>
    """)
    |> text_body("""
    Welcome to Frestyl!

    Thank you for signing up. Please confirm your account by clicking the link below:

    #{url}

    If you didn't create an account, please ignore this email.

    Thanks,
    The Frestyl Team
    """)
    |> Mailer.deliver()
  end

  @doc """
  Deliver instructions to reset a user password.
  """
  def deliver_reset_password_instructions(user, url) do
    new()
    |> to(user.email)
    |> from({"Frestyl", "noreply@frestyl.com"})
    |> subject("Reset your Frestyl password")
    |> html_body("""
    <!DOCTYPE html>
    <html>
      <head>
        <meta charset="UTF-8">
        <title>Reset your password</title>
      </head>
      <body style="font-family: sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <h2 style="color: #DD1155;">Password Reset Request</h2>
        <p>Hi #{user.email},</p>
        <p>You can reset your password by clicking the link below:</p>
        <p>
          <a href="#{url}" style="background-color: #DD1155; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px; display: inline-block;">
            Reset My Password
          </a>
        </p>
        <p>If you didn't request this change, please ignore this email.</p>
        <p>Thanks,<br>The Frestyl Team</p>
      </body>
    </html>
    """)
    |> text_body("""
    Hi #{user.email},

    You can reset your password by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    Thanks,
    The Frestyl Team
    """)
    |> Mailer.deliver()
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    new()
    |> to(user.email)
    |> from({"Frestyl", "noreply@frestyl.com"})
    |> subject("Update your Frestyl email")
    |> html_body("""
    <!DOCTYPE html>
    <html>
      <head>
        <meta charset="UTF-8">
        <title>Update your email</title>
      </head>
      <body style="font-family: sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <h2 style="color: #DD1155;">Email Update Request</h2>
        <p>Hi #{user.email},</p>
        <p>You can change your email by clicking the link below:</p>
        <p>
          <a href="#{url}" style="background-color: #DD1155; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px; display: inline-block;">
            Update My Email
          </a>
        </p>
        <p>If you didn't request this change, please ignore this email.</p>
        <p>Thanks,<br>The Frestyl Team</p>
      </body>
    </html>
    """)
    |> text_body("""
    Hi #{user.email},

    You can change your email by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    Thanks,
    The Frestyl Team
    """)
    |> Mailer.deliver()
  end

  @doc """
  Deliver email for invitation
  """
  def deliver_invitation_instructions(invitation) do
    invitation_url = "#{FrestylWeb.Endpoint.url()}/invitations/#{invitation.token}/accept"

    new()
    |> to(invitation.email)
    |> from({"Frestyl", "noreply@frestyl.com"})
    |> subject("You're invited to join Frestyl")
    |> html_body("""
    <!DOCTYPE html>
    <html>
      <head>
        <meta charset="UTF-8">
        <title>Join Frestyl</title>
      </head>
      <body style="font-family: sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <h2 style="color: #DD1155;">You're invited to join Frestyl!</h2>
        <p>You've been invited to join our collaborative media platform. Click the link below to create your account:</p>
        <p>
          <a href="#{invitation_url}" style="background-color: #DD1155; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px; display: inline-block;">
            Accept Invitation
          </a>
        </p>
        <p>This invitation will expire in 7 days.</p>
        <p>Thanks,<br>The Frestyl Team</p>
      </body>
    </html>
    """)
    |> text_body("""
    You're invited to join Frestyl!

    You've been invited to join our collaborative media platform. Click the link below to create your account:

    #{invitation_url}

    This invitation will expire in 7 days.

    Thanks,
    The Frestyl Team
    """)
    |> Mailer.deliver()
  end
end
