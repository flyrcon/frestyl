# Database migration for unified portfolio system
# Run: mix ecto.gen.migration add_portfolio_monetization_support

defmodule Frestyl.Repo.Migrations.AddPortfolioMonetizationSupport do
  use Ecto.Migration

  def up do
    # Check if portfolio_services table already exists to avoid conflicts
    create_if_not_exists table(:portfolio_services) do
      # Add fields to portfolios if not exists (these work with add_if_not_exists)
      alter table(:portfolios) do
        add_if_not_exists :layout, :string, default: "professional_service"
        add_if_not_exists :monetization_enabled, :boolean, default: false
        add_if_not_exists :streaming_enabled, :boolean, default: false
        add_if_not_exists :booking_enabled, :boolean, default: false
      end

      # Portfolio Services table
      create_if_not_exists table(:portfolio_services) do
        add :portfolio_id, references(:portfolios, on_delete: :delete_all), null: false
        add :title, :string, null: false
        add :description, :text
        add :price_amount, :decimal, precision: 10, scale: 2
        add :price_currency, :string, default: "USD"
        add :duration_minutes, :integer
        add :service_type, :string # "consultation", "project", "recurring"
        add :booking_type, :string # "calendar", "request", "instant"
        add :is_active, :boolean, default: true
        add :settings, :map, default: %{}

        timestamps()
      end

      create_if_not_exists index(:portfolio_services, [:portfolio_id])
      create_if_not_exists index(:portfolio_services, [:service_type])

      # Bookings table
      create table(:bookings) do
        add :portfolio_id, references(:portfolios, on_delete: :delete_all), null: false
        add :service_id, references(:portfolio_services, on_delete: :delete_all)
        add :client_name, :string, null: false
        add :client_email, :string, null: false
        add :client_phone, :string
        add :scheduled_at, :utc_datetime, null: false
        add :duration_minutes, :integer, null: false
        add :status, :string, default: "pending" # pending, confirmed, completed, cancelled
        add :price_amount, :decimal, precision: 10, scale: 2
        add :payment_status, :string, default: "pending" # pending, paid, refunded
        add :payment_intent_id, :string # Stripe payment intent
        add :notes, :text
        add :metadata, :map, default: %{}

        timestamps()
      end

      create index(:bookings, [:portfolio_id])
      create index(:bookings, [:scheduled_at])
      create index(:bookings, [:status])
      create index(:bookings, [:payment_status])

      # Streaming Configuration table
      create table(:streaming_configs) do
        add :portfolio_id, references(:portfolios, on_delete: :delete_all), null: false
        add :streaming_key, :string, null: false
        add :rtmp_url, :string
        add :max_viewers, :integer, default: 10
        add :recording_enabled, :boolean, default: false
        add :chat_enabled, :boolean, default: true
        add :settings, :map, default: %{}

        timestamps()
      end

      create unique_index(:streaming_configs, [:portfolio_id])
      create unique_index(:streaming_configs, [:streaming_key])

      # Streaming Sessions table
      create table(:streaming_sessions) do
        add :portfolio_id, references(:portfolios, on_delete: :delete_all), null: false
        add :title, :string, null: false
        add :description, :text
        add :scheduled_at, :utc_datetime
        add :started_at, :utc_datetime
        add :ended_at, :utc_datetime
        add :status, :string, default: "scheduled" # scheduled, live, ended, cancelled
        add :viewer_count, :integer, default: 0
        add :max_viewers, :integer, default: 0
        add :recording_url, :string
        add :metadata, :map, default: %{}

        timestamps()
      end

      create index(:streaming_sessions, [:portfolio_id])
      create index(:streaming_sessions, [:scheduled_at])
      create index(:streaming_sessions, [:status])

      # Revenue Analytics table
      create table(:revenue_analytics) do
        add :portfolio_id, references(:portfolios, on_delete: :delete_all), null: false
        add :period_start, :date, null: false
        add :period_end, :date, null: false
        add :total_revenue, :decimal, precision: 12, scale: 2, default: 0
        add :booking_count, :integer, default: 0
        add :unique_clients, :integer, default: 0
        add :conversion_rate, :decimal, precision: 5, scale: 4, default: 0
        add :avg_booking_value, :decimal, precision: 10, scale: 2, default: 0
        add :metadata, :map, default: %{}

        timestamps()
      end

      create unique_index(:revenue_analytics, [:portfolio_id, :period_start, :period_end])
      create index(:revenue_analytics, [:period_start])

      # Brand Configuration table (for enterprise accounts)
      create table(:brand_configurations) do
        add :account_id, references(:accounts, on_delete: :delete_all), null: false
        add :brand_name, :string
        add :primary_colors, {:array, :string}, default: []
        add :secondary_colors, {:array, :string}, default: []
        add :accent_colors, {:array, :string}, default: []
        add :allowed_fonts, {:array, :string}, default: []
        add :logo_url, :string
        add :enforce_brand, :boolean, default: false
        add :brand_locked_elements, {:array, :string}, default: []
        add :custom_css, :text
        add :settings, :map, default: %{}

        timestamps()
      end

      create unique_index(:brand_configurations, [:account_id])

      # Portfolio Analytics Views table
      create table(:portfolio_views) do
        add :portfolio_id, references(:portfolios, on_delete: :delete_all), null: false
        add :visitor_ip, :string
        add :user_agent, :string
        add :referrer, :string
        add :session_id, :string
        add :viewed_at, :utc_datetime, null: false
        add :time_on_page, :integer # seconds
        add :pages_viewed, :integer, default: 1
        add :conversion_event, :string # "booking", "contact", "download"
        add :metadata, :map, default: %{}

        timestamps()
      end

      create index(:portfolio_views, [:portfolio_id])
      create index(:portfolio_views, [:viewed_at])
      create index(:portfolio_views, [:conversion_event])

      # Update portfolio_sections for content blocks (if table exists)
      if table_exists?(:portfolio_sections) do
        alter table(:portfolio_sections) do
          add_if_not_exists :content_blocks, :map, default: %{}
          add_if_not_exists :monetization_config, :map, default: %{}
          add_if_not_exists :streaming_config, :map, default: %{}
          add_if_not_exists :template_version, :integer, default: 1
        end
      end

      # Section Media Attachments (many-to-many for content blocks)
      create table(:section_media_attachments) do
        add :section_id, references(:portfolio_sections, on_delete: :delete_all), null: false
        add :media_id, references(:portfolio_media, on_delete: :delete_all), null: false
        add :content_block_id, :string # Which content block this media is attached to
        add :position, :integer, default: 0
        add :display_type, :string, default: "inline" # inline, gallery, background, thumbnail
        add :settings, :map, default: %{}

        timestamps()
      end

      create unique_index(:section_media_attachments, [:section_id, :media_id, :content_block_id])
      create index(:section_media_attachments, [:section_id])
      create index(:section_media_attachments, [:media_id])

      # Client Testimonials table
      create table(:client_testimonials) do
        add :portfolio_id, references(:portfolios, on_delete: :delete_all), null: false
        add :client_name, :string, null: false
        add :client_title, :string
        add :client_company, :string
        add :testimonial_text, :text, null: false
        add :rating, :integer # 1-5 stars
        add :project_type, :string
        add :client_photo_url, :string
        add :video_testimonial_url, :string
        add :is_featured, :boolean, default: false
        add :is_approved, :boolean, default: false
        add :display_order, :integer, default: 0
        add :metadata, :map, default: %{}

        timestamps()
      end

      create index(:client_testimonials, [:portfolio_id])
      create index(:client_testimonials, [:is_featured])
      create index(:client_testimonials, [:is_approved])

      # Social Media Integrations table
      create table(:social_integrations) do
        add :portfolio_id, references(:portfolios, on_delete: :delete_all), null: false
        add :platform, :string, null: false # linkedin, github, twitter, instagram
        add :profile_url, :string, null: false
        add :username, :string
        add :display_name, :string
        add :auto_sync, :boolean, default: false
        add :last_sync_at, :utc_datetime
        add :sync_data, :map, default: %{}
        add :is_active, :boolean, default: true
        add :display_order, :integer, default: 0

        timestamps()
      end

      create unique_index(:social_integrations, [:portfolio_id, :platform])
      create index(:social_integrations, [:portfolio_id])

      # Portfolio Collaboration table (for shared editing)
      create table(:portfolio_collaborations) do
        add :portfolio_id, references(:portfolios, on_delete: :delete_all), null: false
        add :collaborator_user_id, references(:users, on_delete: :delete_all), null: false
        add :role, :string, null: false # editor, reviewer, viewer
        add :permissions, {:array, :string}, default: []
        add :invited_by_user_id, references(:users, on_delete: :delete_all), null: false
        add :invited_at, :utc_datetime, null: false
        add :accepted_at, :utc_datetime
        add :status, :string, default: "pending" # pending, accepted, declined, revoked
        add :last_activity_at, :utc_datetime
        add :settings, :map, default: %{}

        timestamps()
      end

      create unique_index(:portfolio_collaborations, [:portfolio_id, :collaborator_user_id])
      create index(:portfolio_collaborations, [:collaborator_user_id])
      create index(:portfolio_collaborations, [:status])

      # Add performance indexes (with existence checks)
      unless index_exists?(:portfolios, [:account_id]) do
        create index(:portfolios, [:account_id])
      end
      unless index_exists?(:portfolios, [:updated_at]) do
        create index(:portfolios, [:updated_at])
      end
      unless index_exists?(:portfolio_sections, [:portfolio_id, :position]) do
        create index(:portfolio_sections, [:portfolio_id, :position])
      end
      unless index_exists?(:portfolio_media, [:portfolio_id, :inserted_at]) do
        create_if_not_exists index(:portfolio_media, [:portfolio_id, :inserted_at])
      end
    end
  end

  def down do
    drop_if_exists table(:portfolio_collaborations)
    drop_if_exists table(:social_integrations)
    drop_if_exists table(:client_testimonials)
    drop_if_exists table(:section_media_attachments)
    drop_if_exists table(:portfolio_views)
    drop_if_exists table(:brand_configurations)
    drop_if_exists table(:revenue_analytics)
    drop_if_exists table(:streaming_sessions)
    drop_if_exists table(:streaming_configs)
    drop_if_exists table(:bookings)
    drop_if_exists table(:portfolio_services)

    if table_exists?(:portfolio_sections) do
      alter table(:portfolio_sections) do
        remove_if_exists :content_blocks, :map
        remove_if_exists :monetization_config, :map
        remove_if_exists :streaming_config, :map
        remove_if_exists :template_version, :integer
      end
    end

    alter table(:portfolios) do
      remove_if_exists :layout, :string
      remove_if_exists :monetization_enabled, :boolean
      remove_if_exists :streaming_enabled, :boolean
      remove_if_exists :booking_enabled, :boolean
    end
  end

  # Helper functions to check table/index existence
  defp table_exists?(table_name) do
    query = """
    SELECT EXISTS (
      SELECT 1
      FROM information_schema.tables
      WHERE table_schema = 'public'
      AND table_name = '#{table_name}'
    );
    """

    case Ecto.Adapters.SQL.query(repo(), query) do
      {:ok, %{rows: [[true]]}} -> true
      _ -> false
    end
  end

  defp index_exists?(table_name, columns) do
    # Simple existence check - you can make this more sophisticated if needed
    query = """
    SELECT EXISTS (
      SELECT 1
      FROM pg_indexes
      WHERE tablename = '#{table_name}'
      AND indexdef LIKE '%#{Enum.join(columns, "%") |> String.replace(":", "")}%'
    );
    """

    case Ecto.Adapters.SQL.query(repo(), query) do
      {:ok, %{rows: [[true]]}} -> true
      _ -> false
    end
  end
end
