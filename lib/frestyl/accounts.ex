# lib/frestyl/accounts.ex
defmodule Frestyl.Accounts do
  import Ecto.Query
  alias Frestyl.Repo
  alias Frestyl.Accounts.User
  alias Frestyl.Accounts.UserToken
  alias Frestyl.Accounts.UserInvitation
  alias Ecto.Multi
  import Bcrypt, only: [verify_pass: 2]
  require Logger

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

  @doc """
  Registers a new user.
  """
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
  Updates a user's profile information.
  """
  def update_profile(user, attrs) do
    user
    |> User.profile_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Prepares a changeset for updating a user's profile.
  """
  def change_user_profile(user, attrs \\ %{}) do
    User.profile_changeset(user, attrs)
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
end
