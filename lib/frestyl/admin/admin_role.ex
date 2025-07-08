# lib/frestyl/admin/admin_role.ex
defmodule Frestyl.Admin.AdminRole do
  @moduledoc """
  Schema for admin roles that can be assigned to users.
  Defines different levels of administrative access.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "admin_roles" do
    field :name, :string
    field :description, :string
    field :permissions, {:array, :string}, default: []
    field :is_system_role, :boolean, default: false
    field :color, :string, default: "#6B7280"  # Default gray color

    has_many :admin_role_assignments, Frestyl.Admin.AdminRoleAssignment
    has_many :users, through: [:admin_role_assignments, :user]

    timestamps()
  end

  @required_fields [:name]
  @optional_fields [:description, :permissions, :is_system_role, :color]

  def changeset(admin_role, attrs) do
    admin_role
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:name, min: 2, max: 50)
    |> validate_length(:description, max: 500)
    |> unique_constraint(:name)
    |> validate_permissions()
    |> validate_format(:color, ~r/^#[0-9A-Fa-f]{6}$/, message: "must be a valid hex color")
  end

  defp validate_permissions(changeset) do
    permissions = get_change(changeset, :permissions) || []

    # Validate that all permissions are valid
    valid_permissions = [
      # Content Management
      "moderate_content", "manage_content", "feature_content", "delete_content",

      # User Management
      "view_users", "manage_users", "suspend_users", "delete_users",
      "assign_roles", "manage_subscriptions",

      # Channel Management
      "moderate_channels", "manage_official_channels", "delete_channels",

      # System Administration
      "view_analytics", "generate_reports", "export_data",
      "manage_system_settings", "view_logs", "manage_integrations",

      # Support
      "view_support_tickets", "respond_to_users", "access_user_accounts",

      # Billing
      "view_billing", "process_refunds", "manage_billing_settings",

      # Special
      "*"  # All permissions
    ]

    invalid_permissions = Enum.reject(permissions, &(&1 in valid_permissions))

    if length(invalid_permissions) > 0 do
      add_error(changeset, :permissions, "contains invalid permissions: #{Enum.join(invalid_permissions, ", ")}")
    else
      changeset
    end
  end
end
