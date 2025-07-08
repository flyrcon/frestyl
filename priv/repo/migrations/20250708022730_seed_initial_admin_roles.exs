# priv/repo/migrations/20250707000008_seed_initial_admin_roles.exs
defmodule Frestyl.Repo.Migrations.SeedInitialAdminRoles do
  use Ecto.Migration

  alias Frestyl.Repo
  alias Frestyl.Admin.AdminRole

  def up do
    # Insert initial admin roles
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    initial_roles = [
      %{
        name: "super_admin",
        description: "Full system administration access with all permissions",
        permissions: ["*"],
        is_system_role: true,
        color: "#DC2626",
        inserted_at: now,
        updated_at: now
      },
      %{
        name: "moderator",
        description: "Content and community moderation capabilities",
        permissions: ["moderate_content", "moderate_channels", "view_users", "suspend_users"],
        is_system_role: true,
        color: "#2563EB",
        inserted_at: now,
        updated_at: now
      },
      %{
        name: "content_admin",
        description: "Content management and curation",
        permissions: ["manage_content", "feature_content", "manage_official_channels"],
        is_system_role: true,
        color: "#059669",
        inserted_at: now,
        updated_at: now
      },
      %{
        name: "support_admin",
        description: "User support and assistance",
        permissions: ["view_support_tickets", "respond_to_users", "access_user_accounts"],
        is_system_role: true,
        color: "#D97706",
        inserted_at: now,
        updated_at: now
      },
      %{
        name: "billing_admin",
        description: "Billing and subscription management",
        permissions: ["view_billing", "process_refunds", "manage_subscriptions"],
        is_system_role: true,
        color: "#7C3AED",
        inserted_at: now,
        updated_at: now
      },
      %{
        name: "analytics_admin",
        description: "Analytics and reporting access",
        permissions: ["view_analytics", "generate_reports", "export_data"],
        is_system_role: true,
        color: "#0891B2",
        inserted_at: now,
        updated_at: now
      }
    ]

    Repo.insert_all("admin_roles", initial_roles)
  end

  def down do
    # Import Ecto.Query for the query syntax
    import Ecto.Query

    # Delete all system roles
    from(r in "admin_roles", where: r.is_system_role == true)
    |> Repo.delete_all()
  end
end
