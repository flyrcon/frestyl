
# Migration 5: Create sharing_analytics table
# File: priv/repo/migrations/20241201000005_create_sharing_analytics.exs

defmodule Frestyl.Repo.Migrations.CreateSharingAnalytics do
  use Ecto.Migration

  def change do
    create table(:sharing_analytics, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :event_type, :string, null: false
      add :platform, :string
      add :referrer_url, :string
      add :user_agent, :text
      add :ip_address, :string
      add :country, :string
      add :city, :string
      add :device_type, :string
      add :browser, :string

      # Event-specific data
      add :section_id, :integer
      add :media_id, :integer
      add :click_position, :map
      add :time_on_page, :integer
      add :scroll_depth, :float

      # Session tracking
      add :session_id, :string
      add :visitor_id, :string

      # Lead generation
      add :is_potential_lead, :boolean, default: false
      add :lead_score, :integer, default: 0
      add :conversion_action, :string

      # Foreign keys
      add :portfolio_id, references(:portfolios, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :nilify_all)

      timestamps()
    end

    create index(:sharing_analytics, [:portfolio_id])
    create index(:sharing_analytics, [:event_type])
    create index(:sharing_analytics, [:platform])
    create index(:sharing_analytics, [:visitor_id])
    create index(:sharing_analytics, [:session_id])
    create index(:sharing_analytics, [:inserted_at])
    create index(:sharing_analytics, [:is_potential_lead])
    create index(:sharing_analytics, [:portfolio_id, :event_type, :inserted_at])
    create index(:sharing_analytics, [:portfolio_id, :inserted_at])

    # Add check constraints
    create constraint(:sharing_analytics, :valid_event_type,
      check: "event_type IN ('portfolio_shared', 'portfolio_viewed', 'social_share_clicked',
                            'contact_info_viewed', 'section_viewed', 'media_viewed',
                            'resume_downloaded', 'contact_form_submitted')")
    create constraint(:sharing_analytics, :valid_lead_score,
      check: "lead_score >= 0 AND lead_score <= 100")
    create constraint(:sharing_analytics, :valid_scroll_depth,
      check: "scroll_depth >= 0 AND scroll_depth <= 100")
    create constraint(:sharing_analytics, :valid_time_on_page,
      check: "time_on_page >= 0")
  end
end
