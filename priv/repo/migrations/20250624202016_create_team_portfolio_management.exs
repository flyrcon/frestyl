defmodule Frestyl.Repo.Migrations.CreateTeamPortfolioManagement do
  use Ecto.Migration

  def change do
    create table(:teams) do
      add :account_id, references(:user_accounts, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :description, :text
      add :settings, :map, default: %{}

      timestamps()
    end

    create table(:team_members) do
      add :team_id, references(:teams, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :role, :string, default: "member", null: false
      add :permissions, :map, default: %{}
      add :joined_at, :utc_datetime, default: fragment("now()")

      timestamps()
    end

    create table(:team_portfolios) do
      add :team_id, references(:teams, on_delete: :delete_all), null: false
      add :portfolio_id, references(:portfolios, on_delete: :delete_all), null: false
      add :collaboration_level, :string, default: "view", null: false

      timestamps()
    end

    create index(:teams, [:account_id])
    create index(:team_members, [:team_id])
    create index(:team_members, [:user_id])
    create index(:team_portfolios, [:team_id])
    create index(:team_portfolios, [:portfolio_id])

    create unique_index(:team_members, [:team_id, :user_id])
    create unique_index(:team_portfolios, [:team_id, :portfolio_id])

    # Add constraints
    create constraint(:team_members, :valid_role,
      check: "role IN ('owner', 'admin', 'editor', 'member')")
    create constraint(:team_portfolios, :valid_collaboration_level,
      check: "collaboration_level IN ('view', 'comment', 'edit', 'admin')")
  end
end
