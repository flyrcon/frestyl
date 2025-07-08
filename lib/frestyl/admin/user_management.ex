# lib/frestyl/admin/user_management.ex
defmodule Frestyl.Admin.UserManagement do
  @moduledoc """
  Context for admin user management functionality.
  Handles user tier changes, admin role assignments, and user oversight.
  """

  import Ecto.Query, warn: false
  alias Frestyl.Repo
  alias Frestyl.Accounts.{User, Account}
  alias Frestyl.Admin.{AdminRole, AdminRoleAssignment}

  # ============================================================================
  # USER LISTING AND SEARCH
  # ============================================================================

  def list_users_with_details(opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 50)
    search = Keyword.get(opts, :search, "")

    query =
      from u in User,
        left_join: a in Account, on: u.id == a.user_id,
        left_join: ara in AdminRoleAssignment, on: u.id == ara.user_id,
        left_join: ar in AdminRole, on: ara.admin_role_id == ar.id,
        preload: [account: a, admin_role_assignments: {ara, admin_role: ar}],
        order_by: [desc: u.inserted_at]

    query = if search != "" do
      from u in query,
        where: ilike(u.email, ^"%#{search}%") or ilike(u.name, ^"%#{search}%")
    else
      query
    end

    users =
      query
      |> limit(^per_page)
      |> offset(^((page - 1) * per_page))
      |> Repo.all()
      |> Enum.map(&format_user_with_roles/1)

    total_count = from(u in User) |> Repo.aggregate(:count, :id)

    %{
      users: users,
      page: page,
      per_page: per_page,
      total_count: total_count,
      total_pages: ceil(total_count / per_page)
    }
  end

  def search_users(query, limit \\ 10) do
    from(u in User,
      where: ilike(u.email, ^"%#{query}%") or ilike(u.name, ^"%#{query}%"),
      limit: ^limit,
      preload: [:account]
    )
    |> Repo.all()
  end

  # ============================================================================
  # SUBSCRIPTION TIER MANAGEMENT
  # ============================================================================

  def update_user_subscription_tier(user_id, new_tier) when new_tier in ["personal", "creator", "professional", "enterprise"] do
    user = Repo.get!(User, user_id) |> Repo.preload(:account)

    case user.account do
      nil ->
        # Create account if it doesn't exist
        create_account_with_tier(user, new_tier)

      account ->
        # Update existing account
        update_account_tier(account, new_tier)
    end
  end

  def update_user_subscription_tier(_user_id, invalid_tier) do
    {:error, "Invalid subscription tier: #{invalid_tier}"}
  end

  defp create_account_with_tier(user, tier) do
    account_attrs = %{
      user_id: user.id,
      subscription_tier: tier,
      subscription_status: "active",
      updated_by_admin: true,
      admin_updated_at: DateTime.utc_now()
    }

    %Account{}
    |> Account.changeset(account_attrs)
    |> Repo.insert()
  end

  defp update_account_tier(account, new_tier) do
    account_attrs = %{
      subscription_tier: new_tier,
      updated_by_admin: true,
      admin_updated_at: DateTime.utc_now(),
      previous_tier: account.subscription_tier
    }

    account
    |> Account.admin_changeset(account_attrs)
    |> Repo.update()
  end

  def bulk_update_user_tiers(user_tier_pairs) do
    Enum.map(user_tier_pairs, fn {user_id, tier} ->
      case update_user_subscription_tier(user_id, tier) do
        {:ok, result} -> {:ok, user_id, result}
        {:error, reason} -> {:error, user_id, reason}
      end
    end)
  end

  # ============================================================================
  # ADMIN ROLE MANAGEMENT
  # ============================================================================

  def assign_admin_role(user_id, role_name, assigned_by_user_id) when is_binary(role_name) do
    with {:ok, user} <- get_user_by_id(user_id),
         {:ok, admin_role} <- get_or_create_admin_role(role_name),
         {:ok, assigner} <- get_user_by_id(assigned_by_user_id),
         :ok <- validate_role_assignment_permissions(assigner, role_name),
         {:ok, assignment} <- create_role_assignment(user, admin_role, assigner) do

      # Log the role assignment
      log_admin_action(assigner, "assign_role", %{
        target_user_id: user_id,
        role_name: role_name
      })

      {:ok, assignment}
    else
      {:error, reason} -> {:error, reason}
      error -> {:error, "Failed to assign role: #{inspect(error)}"}
    end
  end

  def revoke_admin_role(user_id, role_name) do
    query =
      from ara in AdminRoleAssignment,
        join: ar in AdminRole, on: ara.admin_role_id == ar.id,
        where: ara.user_id == ^user_id and ar.name == ^role_name

    case Repo.one(query) do
      nil -> {:error, "Role assignment not found"}
      assignment ->
        assignment
        |> Repo.delete()
        |> case do
          {:ok, deleted} -> {:ok, deleted}
          {:error, changeset} -> {:error, "Failed to revoke role"}
        end
    end
  end

  def list_admin_role_assignments do
    from(ara in AdminRoleAssignment,
      join: u in User, on: ara.user_id == u.id,
      join: ar in AdminRole, on: ara.admin_role_id == ar.id,
      left_join: assigner in User, on: ara.assigned_by_user_id == assigner.id,
      preload: [user: u, admin_role: ar, assigned_by_user: assigner],
      order_by: [desc: ara.inserted_at]
    )
    |> Repo.all()
  end

  def get_user_admin_roles(user_id) do
    from(ara in AdminRoleAssignment,
      join: ar in AdminRole, on: ara.admin_role_id == ar.id,
      where: ara.user_id == ^user_id and ara.status == "active",
      select: ar.name
    )
    |> Repo.all()
  end

  def user_has_admin_role?(user_id, role_name) do
    query =
      from ara in AdminRoleAssignment,
        join: ar in AdminRole, on: ara.admin_role_id == ar.id,
        where: ara.user_id == ^user_id and ar.name == ^role_name and ara.status == "active"

    Repo.exists?(query)
  end

  def bulk_assign_roles(assignments) do
    Enum.map(assignments, fn {user_id, role_name, assigned_by_user_id} ->
      case assign_admin_role(user_id, role_name, assigned_by_user_id) do
        {:ok, assignment} -> {:ok, user_id, assignment}
        {:error, reason} -> {:error, user_id, reason}
      end
    end)
  end

  # ============================================================================
  # USER ACCOUNT ACTIONS
  # ============================================================================

  def suspend_user(user_id, reason, suspended_by_user_id) do
    user = Repo.get!(User, user_id)

    user_attrs = %{
      status: "suspended",
      suspended_at: DateTime.utc_now(),
      suspension_reason: reason,
      suspended_by_user_id: suspended_by_user_id
    }

    case User.admin_changeset(user, user_attrs) |> Repo.update() do
      {:ok, updated_user} ->
        log_admin_action(suspended_by_user_id, "suspend_user", %{
          target_user_id: user_id,
          reason: reason
        })
        {:ok, updated_user}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def unsuspend_user(user_id, unsuspended_by_user_id) do
    user = Repo.get!(User, user_id)

    user_attrs = %{
      status: "active",
      suspended_at: nil,
      suspension_reason: nil,
      suspended_by_user_id: nil,
      unsuspended_at: DateTime.utc_now(),
      unsuspended_by_user_id: unsuspended_by_user_id
    }

    case User.admin_changeset(user, user_attrs) |> Repo.update() do
      {:ok, updated_user} ->
        log_admin_action(unsuspended_by_user_id, "unsuspend_user", %{
          target_user_id: user_id
        })
        {:ok, updated_user}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def reset_user_password(user_id, admin_user_id) do
    user = Repo.get!(User, user_id)
    temporary_password = generate_temporary_password()

    user_attrs = %{
      password: temporary_password,
      password_reset_required: true,
      password_reset_by_admin: true,
      password_reset_at: DateTime.utc_now()
    }

    case User.admin_password_changeset(user, user_attrs) |> Repo.update() do
      {:ok, updated_user} ->
        log_admin_action(admin_user_id, "reset_password", %{
          target_user_id: user_id
        })

        # Send email with temporary password
        send_temporary_password_email(user, temporary_password)

        {:ok, updated_user, temporary_password}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp format_user_with_roles(user) do
    admin_roles = Enum.map(user.admin_role_assignments, & &1.admin_role.name)

    %{
      id: user.id,
      email: user.email,
      name: user.name,
      status: user.status || "active",
      account: user.account || %{subscription_tier: "personal"},
      admin_roles: admin_roles,
      last_sign_in_at: user.last_sign_in_at,
      inserted_at: user.inserted_at,
      suspended_at: user.suspended_at,
      suspension_reason: user.suspension_reason
    }
  end

  defp get_user_by_id(user_id) do
    case Repo.get(User, user_id) do
      nil -> {:error, "User not found"}
      user -> {:ok, user}
    end
  end

  defp get_or_create_admin_role(role_name) do
    case Repo.get_by(AdminRole, name: role_name) do
      nil -> create_admin_role(role_name)
      role -> {:ok, role}
    end
  end

  defp create_admin_role(role_name) do
    role_attrs = %{
      name: role_name,
      description: get_role_description(role_name),
      permissions: get_role_permissions(role_name)
    }

    %AdminRole{}
    |> AdminRole.changeset(role_attrs)
    |> Repo.insert()
  end

  defp get_role_description(role_name) do
    case role_name do
      "super_admin" -> "Full system administration access"
      "moderator" -> "Content and community moderation"
      "content_admin" -> "Content management and curation"
      "support_admin" -> "User support and assistance"
      "billing_admin" -> "Billing and subscription management"
      "analytics_admin" -> "Analytics and reporting access"
      _ -> "Custom admin role"
    end
  end

  defp get_role_permissions(role_name) do
    case role_name do
      "super_admin" -> ["*"]  # All permissions
      "moderator" -> ["moderate_content", "moderate_channels", "review_reports", "suspend_users"]
      "content_admin" -> ["manage_content", "feature_content", "manage_official_channels"]
      "support_admin" -> ["view_support_tickets", "respond_to_users", "access_user_accounts"]
      "billing_admin" -> ["view_billing", "process_refunds", "manage_subscriptions"]
      "analytics_admin" -> ["view_analytics", "generate_reports", "export_data"]
      _ -> []
    end
  end

  defp validate_role_assignment_permissions(assigner, role_name) do
    assigner_roles = get_user_admin_roles(assigner.id)

    cond do
      "super_admin" in assigner_roles -> :ok
      role_name == "super_admin" -> {:error, "Only super admins can assign super admin role"}
      length(assigner_roles) == 0 -> {:error, "User does not have admin privileges"}
      true -> :ok
    end
  end

  defp create_role_assignment(user, admin_role, assigner) do
    # Check if assignment already exists
    existing =
      from(ara in AdminRoleAssignment,
        where: ara.user_id == ^user.id and ara.admin_role_id == ^admin_role.id
      )
      |> Repo.one()

    case existing do
      nil ->
        assignment_attrs = %{
          user_id: user.id,
          admin_role_id: admin_role.id,
          assigned_by_user_id: assigner.id,
          status: "active",
          assigned_at: DateTime.utc_now()
        }

        %AdminRoleAssignment{}
        |> AdminRoleAssignment.changeset(assignment_attrs)
        |> Repo.insert()

      existing_assignment ->
        if existing_assignment.status == "revoked" do
          # Reactivate the role
          existing_assignment
          |> AdminRoleAssignment.reactivate_changeset(%{
            assigned_by_user_id: assigner.id,
            assigned_at: DateTime.utc_now()
          })
          |> Repo.update()
        else
          {:error, "Role already assigned"}
        end
    end
  end

  defp generate_temporary_password do
    :crypto.strong_rand_bytes(12)
    |> Base.encode64()
    |> String.slice(0, 12)
  end

  defp send_temporary_password_email(user, password) do
    # Implementation would send email with temporary password
    # For now, just log it
    require Logger
    Logger.info("Temporary password for #{user.email}: #{password}")
  end

  defp log_admin_action(admin_user_id, action, metadata) do
    # Implementation would log admin actions for audit trail
    require Logger
    Logger.info("Admin action: #{action} by user #{admin_user_id} - #{inspect(metadata)}")
  end

  # ============================================================================
  # STATISTICS AND REPORTING
  # ============================================================================

  def get_user_statistics do
    total_users = from(u in User) |> Repo.aggregate(:count, :id)

    active_users =
      from(u in User,
        where: u.status == "active" or is_nil(u.status)
      )
      |> Repo.aggregate(:count, :id)

    suspended_users =
      from(u in User,
        where: u.status == "suspended"
      )
      |> Repo.aggregate(:count, :id)

    users_by_tier =
      from(a in Account,
        group_by: a.subscription_tier,
        select: {a.subscription_tier, count(a.id)}
      )
      |> Repo.all()
      |> Enum.into(%{})

    admin_users =
      from(ara in AdminRoleAssignment,
        where: ara.status == "active",
        distinct: ara.user_id
      )
      |> Repo.aggregate(:count, :user_id)

    %{
      total_users: total_users,
      active_users: active_users,
      suspended_users: suspended_users,
      users_by_tier: users_by_tier,
      admin_users: admin_users
    }
  end

  def get_recent_user_activity(limit \\ 20) do
    from(u in User,
      order_by: [desc: u.last_sign_in_at],
      limit: ^limit,
      preload: [:account]
    )
    |> Repo.all()
  end

  def get_user_growth_data(days \\ 30) do
    start_date = DateTime.utc_now() |> DateTime.add(-days * 24 * 3600, :second)

    from(u in User,
      where: u.inserted_at >= ^start_date,
      group_by: fragment("date_trunc('day', ?)", u.inserted_at),
      order_by: fragment("date_trunc('day', ?)", u.inserted_at),
      select: {fragment("date_trunc('day', ?)", u.inserted_at), count(u.id)}
    )
    |> Repo.all()
  end
end
