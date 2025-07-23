# lib/frestyl/accounts.ex
defmodule Frestyl.Accounts do
  import Ecto.Query, warn: false
  alias Frestyl.Repo
  alias Frestyl.Accounts.{Account, AccountMembership, User}
  alias Frestyl.Accounts.User
  alias Frestyl.Accounts.UserToken
  alias Frestyl.Accounts.UserInvitation
  alias NimbleTOTP
  alias Frestyl.Accounts.UserToken
  alias Ecto.Multi
  import Bcrypt, only: [verify_pass: 2]
  require Logger

  def create_account(user, attrs) do
    account_attrs = Map.put(attrs, :owner_id, user.id)

    Repo.transaction(fn ->
      # Create account
      account = %Account{}
      |> Account.changeset(account_attrs)
      |> Repo.insert!()

      # Create owner membership
      %AccountMembership{}
      |> AccountMembership.changeset(%{
        user_id: user.id,
        account_id: account.id,
        role: :owner
      })
      |> Repo.insert!()

      account
    end)
  end

  def complete_onboarding(user) do
    Multi.new()
    |> Multi.update(:user, User.changeset(user, %{onboarding_completed: true}))
    |> Multi.run(:auto_join_official, fn _repo, %{user: user} ->
      Channels.ensure_user_in_frestyl_official(user.id)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{user: updated_user}} -> {:ok, updated_user}
      {:error, _operation, changeset, _changes} -> {:error, changeset}
    end
  end

  def list_user_accounts(user_id) do
    from(a in Account,
      join: m in AccountMembership,
      on: m.account_id == a.id,
      where: m.user_id == ^user_id,
      preload: [:owner]
    )
    |> Repo.all()
  end

  def get_account!(id), do: Repo.get!(Account, id)

  def get_user_primary_account(user) do
    # For now, get the first personal account
    # Later, add primary_account_id to users table
    from(a in Account,
      join: m in AccountMembership,
      on: m.account_id == a.id,
      where: m.user_id == ^user.id and a.type == :personal,
      limit: 1
    )
    |> Repo.one()
  end

  def get_primary_account_for_user(user_id) do
    # This depends on your account structure
    # Option 1: If users have a primary_account_id field
    from(u in User,
      where: u.id == ^user_id,
      preload: [:account]
    )
    |> Repo.one()
    |> case do
      %{account: account} when not is_nil(account) -> account
      _ -> nil
    end
  end

  @doc """
  Authenticates a user by email and password.
  """
  def authenticate_user(email, password) do
    user = Repo.get_by(User, email: email)

    case user do
      %User{} = user ->
        if User.valid_password?(user, password) do
          {:ok, user}
        else
          Logger.warning("Authentication failed for email: #{email}")
          {:error, :invalid_credentials}
        end
      nil ->
        Logger.warning("Authentication failed - user not found for email: #{email}")
        {:error, :invalid_credentials}
    end
  end

  def list_users do
    Repo.all(User)
  end

  def search_users(search_term) do
    search_pattern = "%#{search_term}%"

    User
    |> where([u], ilike(u.name, ^search_pattern) or ilike(u.email, ^search_pattern))
    |> limit(20)
    |> Repo.all()
  end

  @doc """
  Generates a new TOTP secret for a user.
  """
  def generate_totp_secret do
    NimbleTOTP.secret()
  end

  @doc """
  Generates a URI for QR code generation.
  """
  def generate_totp_uri(user, secret) do
    NimbleTOTP.otpauth_uri("Frestyl:#{user.email}", secret, issuer: "Frestyl")
  end

  @doc """
  Creates QR code as SVG for a given URI.
  """
  def generate_totp_qr_code(uri) do
    uri
    |> EQRCode.encode()
    |> EQRCode.svg(width: 300)
  end

  @doc """
  Verifies a TOTP code against a user's secret.
  """
  def verify_totp(secret, code) when is_binary(secret) and is_binary(code) do
    NimbleTOTP.valid?(secret, code)
  end
  def verify_totp(_, _), do: false

  @doc """
  Enables 2FA for a user after verification.
  """
  def enable_two_factor(user, code, secret) do
    if verify_totp(secret, code) do
      # Generate backup codes - 8 random 10-character alphanumeric codes
      backup_codes = Enum.map(1..8, fn _ ->
        :crypto.strong_rand_bytes(5)
        |> Base.encode32(padding: false)
        |> binary_part(0, 10)
      end)

      user
      |> User.two_factor_auth_changeset(%{
        totp_secret: secret,
        totp_enabled: true,
        backup_codes: backup_codes
      })
      |> Repo.update()
      |> case do
        {:ok, updated_user} -> {:ok, updated_user, backup_codes}
        error -> error
      end
    else
      {:error, :invalid_code}
    end
  end

  @doc """
  Disables 2FA for a user.
  """
  def disable_two_factor(user) do
    user
    |> User.two_factor_auth_changeset(%{
      totp_secret: nil,
      totp_enabled: false,
      backup_codes: nil
    })
    |> Repo.update()
  end

  @doc """
  Verifies a backup code for a user.
  """
  def verify_backup_code(user, code) do
    if user.backup_codes && code in user.backup_codes do
      # Remove the used backup code
      remaining_codes = Enum.reject(user.backup_codes, fn c -> c == code end)

      user
      |> User.two_factor_auth_changeset(%{backup_codes: remaining_codes})
      |> Repo.update()
      |> case do
        {:ok, updated_user} -> {:ok, updated_user}
        error -> error
      end
    else
      {:error, :invalid_code}
    end
  end

  @doc """
  Authenticates a user with 2FA.
  """
  def authenticate_user_with_2fa(email, password, totp_code) do
    case authenticate_user(email, password) do
      {:ok, user} ->
        if user.totp_enabled do
          if verify_totp(user.totp_secret, totp_code) do
            {:ok, user}
          else
            {:error, :invalid_totp}
          end
        else
          {:ok, user}
        end
      error -> error
    end
  end

  @doc """
  Registers a new user and sends confirmation email.
  """
  def register_user(attrs) do
    Multi.new()
    |> Multi.insert(:user, User.registration_changeset(%User{}, attrs))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} ->
        # Generate and store confirmation token
        token = generate_user_confirmation_token(user)

        # Send confirmation email
        confirmation_url = FrestylWeb.EmailHelpers.confirmation_url(token)

        case Frestyl.Accounts.UserNotifier.deliver_confirmation_instructions(user, confirmation_url) do
          {:ok, _} ->
            Logger.info("Successfully sent confirmation email to #{user.email}")
            {:ok, user}
          {:error, error} ->
            Logger.error("Failed to send confirmation email: #{inspect(error)}")
            {:ok, user}  # Still return success since user was created
        end
      {:error, :user, changeset, _} ->
        {:error, changeset}
    end
  end

  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  def get_user_by_email_and_password(email, password) do
    user = get_user_by_email(email)

    if user && User.valid_password?(user, password) do
      {:ok, user}
    else
      {:error, :invalid_credentials}
    end
  end

    @doc """
  Gets users by a list of IDs.
  """

  def get_users_by_ids(user_ids) when is_list(user_ids) do
    from(u in User, where: u.id in ^user_ids)
    |> Repo.all()
  end

  def get_users_by_ids(ids) do
    User
    |> where([u], u.id in ^ids)
    |> Repo.all()
    |> Enum.reduce(%{}, fn user, acc ->
      Map.put(acc, to_string(user.id), user)
    end)
  end

  def list_users do
    Repo.all(User)
  end

  def get_user!(id), do: Repo.get!(User, id)

  def get_user(id), do: Repo.get(User, id)


  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Generates a session token for a user.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end


  @doc """
  Lists active sessions for a user.
  """
  def list_user_sessions(user_id) do
    query =
      from t in UserToken,
        where: t.user_id == ^user_id and t.context == "session",
        select: %{
          id: t.id,
          token: t.token,
          inserted_at: t.inserted_at,
          user_agent: t.metadata["user_agent"],
          ip: t.metadata["ip"]
        }

    Repo.all(query)
  end

  @doc """
  Revokes a specific session.
  """
  def revoke_session(token_id, user_id) do
    query =
      from t in UserToken,
        where: t.id == ^token_id and t.user_id == ^user_id and t.context == "session"

    Repo.delete_all(query)
  end

  @doc """
  Revokes all sessions except the current one.
  """
  def revoke_all_sessions_except_current(current_token, user_id) do
    query =
      from t in UserToken,
        where: t.user_id == ^user_id and t.context == "session" and t.token != ^current_token

    Repo.delete_all(query)
  end

  @doc """
  Deletes a session token.
  """
  def delete_session_token(token) do
    Repo.delete_all(UserToken.by_token_and_context_query(token, "session"))
  end

  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns the list of users with optional filtering.
  """
  def list_users(opts \\ []) do
    User
    |> filter_by_role(opts[:role])
    |> filter_by_tier(opts[:tier])
    |> Repo.all()
  end

  defp filter_by_role(query, nil), do: query
  defp filter_by_role(query, role), do: where(query, [u], u.role == ^role)

  defp filter_by_tier(query, nil), do: query
  defp filter_by_tier(query, tier), do: where(query, [u], u.subscription_tier == ^tier)

  @doc """
  Updates a user's role.
  """
  def update_user_role(user, role) when role in ["user", "creator", "host", "channel_owner", "admin"] do
    user
    |> User.role_changeset(%{role: role})
    |> Repo.update()
  end

  @doc """
  Updates a user's subscription tier.
  """
  def update_subscription_tier(user, tier) when tier in ["free", "basic", "premium", "pro"] do
    user
    |> User.subscription_changeset(%{subscription_tier: tier})
    |> Repo.update()
  end

  @doc """
  Prepares a changeset for updating a user's profile.
  """
  def change_user_profile(%User{} = user, attrs \\ %{}) do
    User.profile_changeset(user, attrs)
  end

  def update_profile(%User{} = user, attrs) do
    user
    |> User.profile_changeset(attrs)
    |> Repo.update()
  end

  def username_available?(username) do
    # Skip empty usernames
    if username == nil || String.trim(username) == "" do
      false
    else
      # Check if username exists in database
      !Repo.exists?(from u in User, where: u.username == ^username)
    end
  end

  # Add to lib/frestyl/accounts.ex
  @doc """
  Updates a user's privacy settings.
  """
  def update_privacy_settings(user, privacy_settings) do
    user
    |> User.privacy_changeset(%{privacy_settings: privacy_settings})
    |> Repo.update()
  end

  @doc """
  Checks if a user can view another user's content based on privacy settings.
  """
  def can_view_content?(viewer, owner, content_type) do
    visibility_key = case content_type do
      :profile -> "profile_visibility"
      :media -> "media_visibility"
      :metrics -> "metrics_visibility"
      _ -> nil
    end

    if visibility_key do
      # If viewer is the owner, always allow
      if viewer && viewer.id == owner.id do
        true
      else
        visibility = get_in(owner.privacy_settings, [visibility_key])

        case visibility do
          "public" -> true
          "friends" -> is_friend?(viewer, owner)
          "private" -> false
          _ -> false
        end
      end
    else
      false
    end
  end

  # Helper function to check if two users are friends (placeholder)
  defp is_friend?(viewer, owner) do
    # In a real implementation, you would check if they're friends
    # For now, return false
    false
  end

  @doc """
  Change a user struct.
  """
  def change_user(nil, attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
  end

  def change_user(%User{} = user, attrs) do
    User.changeset(user, attrs)
  end

  @doc """
  Prepares a changeset for user registration.
  """
  def change_user_registration(attrs \\ %{}) do
    change_user(nil, attrs)
  end

  def change_user_login(attrs \\ %{}) do
    %User{}
    |> User.login_changeset(attrs)
  end

  @doc """
  Delete a user.
  """
  def delete_user(user) do
    Repo.delete(user)
  end

  @doc """
  Tracks user activity, updating the last_active_at field.
  """
  def track_user_activity(user) do
    user
    |> User.activity_changeset(%{last_active_at: DateTime.utc_now()})
    |> Repo.update()
  end

  @doc """
  Admin functionality to update any user fields.
  """
  def admin_update_user(user, attrs) do
    user
    |> User.role_changeset(attrs)
    |> User.subscription_changeset(attrs)
    |> User.profile_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Gets user notifications.
  """
  def get_user_notifications(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    offset = Keyword.get(opts, :offset, 0)

    # Assuming Notification schema/context exists
    [] # Return empty list as a placeholder if Notification context is not ready
  end

  @doc """
  Updates a user's status.
  """
  def update_user_status(user_id, status) do
    User
    |> Repo.get!(user_id)
    |> User.status_changeset(%{status: status})
    |> Repo.update()
  end

  @doc """
  Returns a map of role permissions.
  """
  def role_permissions do
    %{
      "user" => %{
        can_view_content: true,
        can_comment: true
      },
      "creator" => %{
        can_view_content: true,
        can_comment: true,
        can_create_content: true,
        can_manage_own_content: true
      },
      "host" => %{
        can_view_content: true,
        can_comment: true,
        can_create_content: true,
        can_manage_own_content: true,
        can_moderate_comments: true
      },
      "channel_owner" => %{
        can_view_content: true,
        can_comment: true,
        can_create_content: true,
        can_manage_own_content: true,
        can_moderate_comments: true,
        can_manage_channel: true,
        can_invite_creators: true
      },
      "admin" => %{
        can_view_content: true,
        can_comment: true,
        can_create_content: true,
        can_manage_all_content: true,
        can_moderate_comments: true,
        can_manage_users: true,
        can_manage_settings: true
      }
    }
  end

  @doc """
  Checks if a user has a specific permission.
  """
  def has_permission?(user, permission) do
    permissions = role_permissions()[user.role] || %{}
    Map.get(permissions, permission, false)
  end

  @doc """
  Returns tier-based access permissions.
  """
  def tier_permissions do
    %{
      "free" => %{
        max_channels: 1,
        max_content_per_day: 2,
        advanced_analytics: false
      },
      "basic" => %{
        max_channels: 3,
        max_content_per_day: 5,
        advanced_analytics: false
      },
      "premium" => %{
        max_channels: 10,
        max_content_per_day: 20,
        advanced_analytics: true
      },
      "pro" => %{
        max_channels: nil, # unlimited
        max_content_per_day: nil, # unlimited
        advanced_analytics: true
      }
    }
  end

  @doc """
  Checks if a user has access to a specific tier feature.
  """
  def has_tier_access?(user, feature) do
    permissions = tier_permissions()[user.subscription_tier] || %{}
    value = Map.get(permissions, feature)

    cond do
      is_nil(value) -> true
      is_boolean(value) -> value
      is_number(value) -> value > 0
      true -> false
    end
  end

  # Helper function to build confirmation URLs
  defp build_confirmation_url(token) do
    base_url = FrestylWeb.Endpoint.url()
    "#{base_url}/users/confirm/#{token}"
  end

  @doc """
  Sends confirmation email to new user.
  """
  def send_confirmation_email(user) do
    token = generate_user_confirmation_token(user)
    confirmation_url = build_confirmation_url(token)

    Logger.info("Sending confirmation email to #{user.email}")
    Logger.info("Confirmation URL: #{confirmation_url}")
    {:ok, user}
  end

  @doc """
  Delivers user confirmation instructions.
  """
  def deliver_user_confirmation_instructions(user, confirmation_url_fun \\ nil) do
    token = generate_user_confirmation_token(user)

    confirmation_url = if confirmation_url_fun do
      confirmation_url_fun.(token)
    else
      build_confirmation_url(token)
    end

    Logger.info("Confirmation URL generated: #{confirmation_url}")
    {:ok, nil}
  end

  @doc """
  Invites a user by email to join the platform.
  """
  def invite_user(email, invited_by_user) do
    case get_user_by_email(email) do
      nil ->
        token = generate_invitation_token()
        expires_at = DateTime.add(DateTime.utc_now(), 7 * 24 * 3600, :second)

        attrs = %{
          email: email,
          invited_by_id: invited_by_user.id,
          token: token,
          expires_at: expires_at
        }

        case create_invitation(attrs) do
          {:ok, invitation} ->
            send_invitation_email(invitation)
          {:error, changeset} ->
            {:error, changeset}
        end
      _user ->
        {:error, "User already exists"}
    end
  end

  defp create_invitation(attrs) do
    %UserInvitation{}
    |> UserInvitation.changeset(attrs)
    |> Repo.insert()
  end

  defp generate_invitation_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64()
  end

  defp send_invitation_email(invitation) do
    Logger.info("Sending invitation email to #{invitation.email}")

    case Frestyl.Accounts.UserNotifier.deliver_invitation_instructions(invitation) do
      {:ok, _} ->
        Logger.info("Successfully sent invitation email to #{invitation.email}")
        {:ok, invitation}
      {:error, error} ->
        Logger.error("Failed to send invitation email: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Gets an invitation by token.
  """
  def get_invitation_by_token(token) do
    Repo.get_by(UserInvitation, token: token)
  end

  @doc """
  Updates an invitation status.
  """
  def update_invitation_status(invitation, status) do
    invitation
    |> UserInvitation.changeset(%{status: status})
    |> Repo.update()
  end

  @doc """
  Accepts an invitation and creates user account.
  """
  def accept_invitation(invitation_token, user_params) do
    Repo.transaction(fn ->
      with %UserInvitation{} = invitation <- get_invitation_by_token(invitation_token),
          true <- invitation.status == "pending",
          true <- DateTime.compare(DateTime.utc_now(), invitation.expires_at) == :lt,
          {:ok, %User{} = user} <- register_user(user_params),
          {:ok, _} <- update_invitation_status(invitation, "accepted") do
        user
      else
        nil -> {:error, "Invalid invitation"}
        false -> {:error, "Invitation expired or already used"}
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Deletes a session token.
  """
  def delete_user_session_token(token) do
    Repo.get_by(UserToken, token: token)
    |> case do
      %UserToken{} = user_token -> Repo.delete(user_token)
      nil -> {:ok, nil}
    end
  end

  @doc """
  Retrieves a user by their session token.
  """
  def get_user_by_session_token(token) do
    case UserToken.verify_session_token_query(token) do
      {:ok, query} ->
        Repo.one(query)
      :error ->
        nil
    end
  end

  @doc """
  Generates a new confirmation token for the user.
  """
  def generate_user_confirmation_token(%User{} = user) do
    {token, user_token} = UserToken.build_email_token(user, "confirm")
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets a user by their confirmation token.
  """
  def get_user_by_confirmation_token(token) do
    case UserToken.verify_email_token_query(token, "confirm") do
      {:ok, query} ->
        Repo.one(query)
      :error ->
        nil
    end
  end

  @doc """
  Confirms a user's account.
  """
  def confirm_user(%User{} = user) do
    Multi.new()
    |> Multi.update(:user, User.confirm_changeset(user))
    |> Multi.delete_all(:tokens, UserToken |> where([t], t.user_id == ^user.id and t.context == "confirm"))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: confirmed_user}} ->
        {:ok, confirmed_user}
      {:error, :user, changeset, _} ->
        {:error, changeset}
    end
  end

  @doc """
  Confirms a user's account using a token.
  """
  def confirm_user_by_token(token) do
    case get_user_by_confirmation_token(token) do
      nil ->
        {:error, "Invalid token"}
      user ->
        confirm_user(user)
    end
  end

  def get_user_metrics(user_id) do
    # In a real implementation, you would query your database
    # For now, we'll return mock data
    %{
      hours_consumed: Enum.random(5..150),
      total_engagements: Enum.random(10..500),
      content_hours_created: Enum.random(0..30),
      days_active: Enum.random(1..90),
      unique_channels_visited: Enum.random(3..20),
      comments_posted: Enum.random(0..100),
      likes_given: Enum.random(0..200),
      events_attended: Enum.random(0..15)
    }
  end

  def get_user_activity_percentile(user_id) do
    # Mock implementation - would normally calculate based on all users
    # Returns a number between 1-100 representing user percentile
    Enum.random(1..100)
  end
end
