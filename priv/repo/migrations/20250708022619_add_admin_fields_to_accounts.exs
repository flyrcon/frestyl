# priv/repo/migrations/20250707000004_add_admin_fields_to_accounts.exs
defmodule Frestyl.Repo.Migrations.AddAdminFieldsToAccounts do
  use Ecto.Migration

  def change do
    alter table(:accounts) do
      add :updated_by_admin, :boolean, default: false
      add :admin_updated_at, :utc_datetime
      add :previous_tier, :string
      add :cancelled_at, :utc_datetime
      add :trial_ends_at, :utc_datetime
    end

    create index(:accounts, [:updated_by_admin])
    create index(:accounts, [:admin_updated_at])
    create index(:accounts, [:cancelled_at])
    create index(:accounts, [:trial_ends_at])
  end
end
