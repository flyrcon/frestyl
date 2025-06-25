defmodule Frestyl.Repo.Migrations.CreateUserAccounts do
  use Ecto.Migration

  def change do
    create table(:user_accounts) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      # Note: Add organization_id later if organizations table exists
      # add :organization_id, references(:organizations, on_delete: :nilify_all), null: true
      add :account_type, :string, null: false
      add :account_name, :string, size: 100
      add :subscription_tier, :string, size: 50
      add :custom_domain, :string
      add :branding_settings, :map, default: %{}
      add :seo_settings, :map, default: %{}
      add :analytics_settings, :map, default: %{}

      timestamps()
    end

    create index(:user_accounts, [:user_id])
    create index(:user_accounts, [:account_type])
    create index(:user_accounts, [:subscription_tier])
    create unique_index(:user_accounts, [:custom_domain])
    create unique_index(:user_accounts, [:user_id, :account_type])
  end
end
