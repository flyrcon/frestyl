# priv/repo/migrations/20250707000003_add_admin_fields_to_users.exs
defmodule Frestyl.Repo.Migrations.AddAdminFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :is_admin, :boolean, default: false
      add :is_system_user, :boolean, default: false
      add_if_not_exists :status, :string, default: "active"
      add :suspended_at, :utc_datetime
      add :suspension_reason, :text
      add :suspended_by_user_id, references(:users, on_delete: :nilify_all)
      add :unsuspended_at, :utc_datetime
      add :unsuspended_by_user_id, references(:users, on_delete: :nilify_all)
      add :password_reset_required, :boolean, default: false
      add :password_reset_by_admin, :boolean, default: false
      add :password_reset_at, :utc_datetime
    end

    create index(:users, [:is_admin])
    create index(:users, [:is_system_user])
    create_if_not_exists index(:users, [:status])
    create index(:users, [:suspended_at])
  end
end
