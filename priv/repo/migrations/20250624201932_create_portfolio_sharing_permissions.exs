defmodule Frestyl.Repo.Migrations.CreatePortfolioSharingPermissions do
  use Ecto.Migration

  def change do
    create table(:portfolio_sharing_permissions) do
      add :portfolio_id, references(:portfolios, on_delete: :delete_all), null: false
      add :shared_with_user_id, references(:users, on_delete: :delete_all), null: false
      add :shared_by_user_id, references(:users, on_delete: :delete_all), null: false
      add :permission_level, :string, null: false
      add :expires_at, :utc_datetime
      add :access_token, :string
      add :embed_settings, :map, default: %{}

      timestamps()
    end

    create index(:portfolio_sharing_permissions, [:portfolio_id])
    create index(:portfolio_sharing_permissions, [:shared_with_user_id])
    create index(:portfolio_sharing_permissions, [:shared_by_user_id])
    create index(:portfolio_sharing_permissions, [:permission_level])
    create index(:portfolio_sharing_permissions, [:expires_at])
    create unique_index(:portfolio_sharing_permissions, [:portfolio_id, :shared_with_user_id])
    create unique_index(:portfolio_sharing_permissions, [:access_token])

    # Add constraint for valid permission levels
    create constraint(:portfolio_sharing_permissions, :valid_permission_level,
      check: "permission_level IN ('view', 'comment', 'edit', 'embed')")
  end
end
