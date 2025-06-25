defmodule Frestyl.Repo.Migrations.AddCareerJourneyAnalytics do
  use Ecto.Migration

  def change do
    create table(:career_milestones) do
      add :portfolio_id, references(:portfolios, on_delete: :delete_all), null: false
      add :title, :string, null: false
      add :description, :text
      add :milestone_type, :string, null: false
      add :date_achieved, :date
      add :metadata, :map, default: %{}
      add :visibility, :string, default: "public"

      timestamps()
    end

    create table(:portfolio_analytics) do
      add :portfolio_id, references(:portfolios, on_delete: :delete_all), null: false
      add :account_id, references(:user_accounts, on_delete: :delete_all), null: false
      add :date, :date, null: false
      add :views, :integer, default: 0
      add :unique_visitors, :integer, default: 0
      add :engagement_time, :integer, default: 0
      add :bounce_rate, :float, default: 0.0
      add :referrer_data, :map, default: %{}
      add :device_data, :map, default: %{}

      timestamps()
    end

    create index(:career_milestones, [:portfolio_id])
    create index(:career_milestones, [:milestone_type])
    create index(:career_milestones, [:date_achieved])
    create index(:portfolio_analytics, [:portfolio_id])
    create index(:portfolio_analytics, [:account_id])
    create index(:portfolio_analytics, [:date])

    create unique_index(:portfolio_analytics, [:portfolio_id, :date])

    # Add constraints
    create constraint(:career_milestones, :valid_milestone_type,
      check: "milestone_type IN ('job', 'education', 'certification', 'project', 'achievement', 'custom')")
    create constraint(:career_milestones, :valid_visibility,
      check: "visibility IN ('public', 'private', 'professional_only')")
  end
end
