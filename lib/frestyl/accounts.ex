# lib/frestyl/accounts.ex
defmodule Frestyl.Accounts do
  # Keep existing imports, aliases, and functions from phx.gen.auth...
  import Ecto.Query
  alias Frestyl.Repo
  alias Frestyl.Accounts.User

  # Add these new functions

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
def change_user(user, attrs \\ %{}) do
  User.changeset(user, attrs)
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

    Notification
    |> where([n], n.user_id == ^user_id)
    |> order_by([n], desc: n.inserted_at)
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
    |> Enum.map(fn notification ->
      %{
        id: notification.id,
        type: notification.type,
        content: notification.content,
        read: notification.read,
        inserted_at: notification.inserted_at
      }
    end)
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

    # For numeric limits, nil means unlimited
    cond do
      is_nil(value) -> true
      is_boolean(value) -> value
      is_number(value) -> value > 0
      true -> false
    end
  end
end
