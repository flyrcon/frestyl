# lib/frestyl/emails/invitation_email.ex
defmodule Frestyl.Emails.InvitationEmail do
  import Swoosh.Email

  def channel_invitation(invitation, channel, invited_by) do
    # Construct invitation URL
    invitation_url = FrestylWeb.Endpoint.url() <> "/invitations/#{invitation.token}"

    # Format expiration time
    expiry_date = Calendar.strftime(invitation.expires_at, "%B %d, %Y at %I:%M %p UTC")

    new()
    |> to(invitation.email)
    |> from({"Frestyl", "noreply@frestyl.example.com"})
    |> subject("You've been invited to join the #{channel.name} channel on Frestyl")
    |> html_body("""
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
      <h2 style="color: #{channel.primary_color};">You've been invited to join a channel</h2>

      <p>Hello,</p>

      <p>#{invited_by.name || invited_by.email} has invited you to join the <strong>#{channel.name}</strong> channel on Frestyl.</p>

      <div style="margin: 20px 0; padding: 15px; border-radius: 5px; background-color: #f5f5f5;">
        <p style="margin: 0;"><strong>Channel:</strong> #{channel.name}</p>
        <p style="margin: 5px 0 0;"><strong>Invited by:</strong> #{invited_by.name || invited_by.email}</p>
        <p style="margin: 5px 0 0;"><strong>Expires:</strong> #{expiry_date}</p>
      </div>

      <div style="text-align: center; margin: 30px 0;">
        <a href="#{invitation_url}" style="display: inline-block; padding: 12px 20px; background-color: #{channel.primary_color}; color: #{channel.secondary_color}; text-decoration: none; border-radius: 4px; font-weight: bold;">
          Accept Invitation
        </a>
      </div>

      <p>If you don't have a Frestyl account yet, you'll be able to create one after accepting the invitation.</p>

      <p>This invitation will expire on #{expiry_date}.</p>

      <hr style="margin: 30px 0; border: none; border-top: 1px solid #eaeaea;" />

      <p style="color: #888; font-size: 12px;">
        If you did not expect this invitation or don't want to join, you can simply ignore this email.
      </p>
    </div>
    """)
    |> text_body("""
    You've been invited to join the #{channel.name} channel on Frestyl

    Hello,

    #{invited_by.name || invited_by.email} has invited you to join the #{channel.name} channel on Frestyl.

    Channel: #{channel.name}
    Invited by: #{invited_by.name || invited_by.email}
    Expires: #{expiry_date}

    To accept this invitation, please visit:
    #{invitation_url}

    If you don't have a Frestyl account yet, you'll be able to create one after accepting the invitation.

    This invitation will expire on #{expiry_date}.

    If you did not expect this invitation or don't want to join, you can simply ignore this email.
    """)
  end
end
