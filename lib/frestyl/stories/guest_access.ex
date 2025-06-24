defmodule Frestyl.Stories.GuestAccess do
  @moduledoc """
  Handles guest access and invitation management for stories.
  """

  alias Frestyl.Stories.CollaborationBilling
  alias Frestyl.Accounts
  alias Frestyl.Repo
  import Ecto.Query
  require Logger

  # ============================================================================
  # Guest Invitation Management
  # ============================================================================

  def create_guest_invite(inviting_user, story, guest_emails, permissions) do
    host_account = get_user_account_for_story(inviting_user, story)

    unless feature_available?(host_account, :guest_access_enabled) do
      return {:error, :guest_access_not_available}
    end

    invite = %{
      story_id: story.id,
      inviting_user_id: inviting_user.id,
      guest_emails: guest_emails,
      invite_token: generate_secure_token(),
      permissions: permissions,
      max_sessions: get_guest_session_limit(host_account),
      expires_at: DateTime.add(DateTime.utc_now(), 7 * 24 * 3600, :second), # 7 days
      created_at: DateTime.utc_now()
    }

    send_guest_invitation_email(invite)

    {:ok, invite}
  end

  def accept_guest_invite(guest_user, invite_token) do
    case get_valid_invite(invite_token) do
      {:ok, invite} ->
        # Create guest session
        guest_session = %{
          invite_id: invite.id,
          guest_user_id: guest_user.id,
          permissions: normalize_guest_permissions(invite.permissions, invite.host_account),
          joined_at: DateTime.utc_now(),
          status: :active
        }

        {:ok, guest_session}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def normalize_guest_permissions(requested_permissions, host_account) do
    # Ensure guest permissions don't exceed host account limits
    max_permissions = get_max_guest_permissions(host_account)

    %{
      can_edit: Map.get(requested_permissions, :can_edit, false) && max_permissions.can_edit,
      can_comment: Map.get(requested_permissions, :can_comment, true) && max_permissions.can_comment,
      can_view_analytics: Map.get(requested_permissions, :can_view_analytics, false) && max_permissions.can_view_analytics,
      can_export: Map.get(requested_permissions, :can_export, false) && max_permissions.can_export
    }
  end

  # ============================================================================
  # Helper Functions
  # ============================================================================

  def get_user_account_for_story(user, story) do
    # Delegate to CollaborationBilling module
    CollaborationBilling.get_user_account_for_story(user, story)
  end

  def feature_available?(account, feature) do
    # Delegate to CollaborationBilling module
    CollaborationBilling.feature_available?(account, feature)
  end

  def generate_secure_token do
    # Generate a secure random token
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end

  def get_guest_session_limit(account) do
    tier = Map.get(account, :subscription_tier, "free")

    case tier do
      "free" -> 5
      "pro" -> 25
      "premium" -> 100
      "enterprise" -> 500
      _ -> 5
    end
  end

  def send_guest_invitation_email(invite) do
    # Placeholder - send invitation email
    Logger.info("Sending guest invitation email for story #{invite.story_id} to #{length(invite.guest_emails)} recipients")

    # Here you would typically:
    # 1. Generate invitation email template
    # 2. Send email via your email service
    # 3. Track email delivery

    :ok
  end

  def get_valid_invite(token) do
    # Placeholder - validate and retrieve invite by token
    # In a real implementation, you'd query the database
    case token do
      "" -> {:error, :invalid_token}
      nil -> {:error, :invalid_token}
      _valid_token ->
        # Mock valid invite
        invite = %{
          id: 1,
          story_id: 1,
          permissions: %{can_edit: true, can_comment: true},
          host_account: %{subscription_tier: "pro"},
          expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
          status: :active
        }
        {:ok, invite}
    end
  end

  def get_max_guest_permissions(account) do
    tier = Map.get(account, :subscription_tier, "free")

    case tier do
      "free" ->
        %{
          can_edit: false,
          can_comment: true,
          can_view_analytics: false,
          can_export: false
        }
      "pro" ->
        %{
          can_edit: true,
          can_comment: true,
          can_view_analytics: false,
          can_export: false
        }
      "premium" ->
        %{
          can_edit: true,
          can_comment: true,
          can_view_analytics: true,
          can_export: true
        }
      "enterprise" ->
        %{
          can_edit: true,
          can_comment: true,
          can_view_analytics: true,
          can_export: true
        }
      _ ->
        %{
          can_edit: false,
          can_comment: false,
          can_view_analytics: false,
          can_export: false
        }
    end
  end

  # ============================================================================
  # Private Helper Functions
  # ============================================================================

  defp return(value), do: value
end
