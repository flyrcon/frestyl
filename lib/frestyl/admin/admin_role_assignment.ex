# lib/frestyl/admin/admin_role_assignment.ex
defmodule Frestyl.Admin.AdminRoleAssignment do
  @moduledoc """
  Schema for tracking admin role assignments to users.
  Includes audit trail of who assigned roles and when.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "admin_role_assignments" do
    field :status, Ecto.Enum, values: [:active, :revoked, :expired], default: :active
    field :assigned_at, :utc_datetime
    field :revoked_at, :utc_datetime
    field :expires_at, :utc_datetime
    field :notes, :string

    belongs_to :user, Frestyl.Accounts.User
    belongs_to :admin_role, Frestyl.Admin.AdminRole
    belongs_to :assigned_by_user, Frestyl.Accounts.User
    belongs_to :revoked_by_user, Frestyl.Accounts.User

    timestamps()
  end

  @required_fields [:user_id, :admin_role_id, :assigned_by_user_id, :status]
  @optional_fields [:assigned_at, :revoked_at, :expires_at, :notes, :revoked_by_user_id]

  def changeset(assignment, attrs) do
    assignment
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:status, [:active, :revoked, :expired])
    |> validate_length(:notes, max: 1000)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:admin_role_id)
    |> foreign_key_constraint(:assigned_by_user_id)
    |> unique_constraint([:user_id, :admin_role_id], name: :unique_active_role_per_user)
    |> set_assigned_at_if_nil()
  end

  def reactivate_changeset(assignment, attrs) do
    assignment
    |> cast(attrs, [:assigned_by_user_id, :assigned_at, :notes])
    |> validate_required([:assigned_by_user_id])
    |> put_change(:status, :active)
    |> put_change(:revoked_at, nil)
    |> put_change(:revoked_by_user_id, nil)
    |> set_assigned_at_if_nil()
  end

  def revoke_changeset(assignment, attrs) do
    assignment
    |> cast(attrs, [:revoked_by_user_id, :notes])
    |> validate_required([:revoked_by_user_id])
    |> put_change(:status, :revoked)
    |> put_change(:revoked_at, DateTime.utc_now() |> DateTime.truncate(:second))
  end

  defp set_assigned_at_if_nil(changeset) do
    case get_field(changeset, :assigned_at) do
      nil -> put_change(changeset, :assigned_at, DateTime.utc_now() |> DateTime.truncate(:second))
      _ -> changeset
    end
  end
end
