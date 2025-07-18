# Database Migration for Calendar System (Only existing table references)
# priv/repo/migrations/20250718_create_calendar_system.exs

defmodule Frestyl.Repo.Migrations.CreateCalendarSystem do
  use Ecto.Migration

  def change do
    # Calendar Events - Core event storage
    create table(:calendar_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :description, :text
      add :event_type, :string, null: false # service_booking, broadcast, collaboration, channel_event, personal
      add :status, :string, default: "scheduled" # scheduled, confirmed, in_progress, completed, cancelled

      # Date/Time Information
      add :starts_at, :utc_datetime, null: false
      add :ends_at, :utc_datetime, null: false
      add :timezone, :string, default: "UTC"
      add :all_day, :boolean, default: false

      # Core relationships that should exist
      add :creator_id, references(:users, type: :bigint), null: false
      add :account_id, references(:accounts, type: :bigint), null: false

      # Optional relationships - only add if tables exist
      # Remove references to tables that don't exist yet
      add :portfolio_id, :bigint  # Will add foreign key constraint later when portfolios table is confirmed
      add :channel_id, :bigint    # Will add foreign key constraint later when channels table is confirmed
      add :service_booking_id, :bigint  # Will add foreign key constraint later
      add :broadcast_id, :bigint  # Will add foreign key constraint later when broadcasts table exists

      # Event Configuration
      add :visibility, :string, default: "private" # private, channel, public, account
      add :booking_enabled, :boolean, default: false
      add :max_attendees, :integer
      add :requires_approval, :boolean, default: false
      add :meeting_url, :string
      add :location, :string

      # Monetization
      add :is_paid, :boolean, default: false
      add :price_cents, :integer, default: 0
      add :currency, :string, default: "USD"

      # External Integration
      add :external_calendar_id, :string
      add :external_event_id, :string
      add :external_provider, :string # google, outlook, apple, calendly
      add :sync_status, :string, default: "pending" # pending, synced, failed

      # Metadata
      add :metadata, :map, default: %{}
      add :reminders, {:array, :map}, default: []
      add :recurrence_rule, :string
      add :parent_event_id, references(:calendar_events, type: :binary_id)

      timestamps()
    end

    # Calendar Event Attendees
    create table(:calendar_event_attendees, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :event_id, references(:calendar_events, type: :binary_id), null: false
      add :user_id, references(:users, type: :bigint)
      add :email, :string
      add :name, :string
      add :status, :string, default: "invited" # invited, accepted, declined, tentative
      add :role, :string, default: "attendee" # organizer, attendee, optional
      add :notification_preferences, :map, default: %{}

      timestamps()
    end

    # Calendar Integrations - External calendar connections
    create table(:calendar_integrations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :bigint), null: false
      add :account_id, references(:accounts, type: :bigint), null: false
      add :provider, :string, null: false # google, outlook, apple, caldav
      add :provider_account_id, :string, null: false
      add :calendar_id, :string, null: false
      add :calendar_name, :string
      add :access_token, :text
      add :refresh_token, :text
      add :token_expires_at, :utc_datetime
      add :is_primary, :boolean, default: false
      add :sync_enabled, :boolean, default: true
      add :sync_direction, :string, default: "bidirectional" # import_only, export_only, bidirectional
      add :last_synced_at, :utc_datetime
      add :sync_errors, {:array, :string}, default: []
      add :settings, :map, default: %{}

      timestamps()
    end

    # Calendar Views - User preferences for calendar display
    create table(:calendar_views, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :bigint), null: false
      add :account_id, references(:accounts, type: :bigint), null: false
      add :name, :string, null: false # "My Calendar", "Team Events", "Bookings"
      add :view_type, :string, default: "month" # month, week, day, list, agenda
      add :default_view, :boolean, default: false
      add :color_scheme, :string, default: "default"
      add :filters, :map, default: %{} # event_types, channels, etc.
      add :settings, :map, default: %{}

      timestamps()
    end

    # Indexes for performance
    create index(:calendar_events, [:creator_id])
    create index(:calendar_events, [:account_id])
    create index(:calendar_events, [:portfolio_id])
    create index(:calendar_events, [:channel_id])
    create index(:calendar_events, [:service_booking_id])
    create index(:calendar_events, [:broadcast_id])
    create index(:calendar_events, [:starts_at])
    create index(:calendar_events, [:ends_at])
    create index(:calendar_events, [:event_type])
    create index(:calendar_events, [:visibility])
    create index(:calendar_events, [:external_provider, :external_event_id])

    create index(:calendar_event_attendees, [:event_id])
    create index(:calendar_event_attendees, [:user_id])
    create index(:calendar_event_attendees, [:email])

    create index(:calendar_integrations, [:user_id])
    create index(:calendar_integrations, [:provider])
    create index(:calendar_integrations, [:provider_account_id])

    create index(:calendar_views, [:user_id])
    create index(:calendar_views, [:account_id])

    # Unique constraints
    create unique_index(:calendar_integrations, [:user_id, :provider, :calendar_id])
    create unique_index(:calendar_event_attendees, [:event_id, :user_id])
    create unique_index(:calendar_event_attendees, [:event_id, :email])

    # Add foreign key constraints for tables that exist
    # You can add these constraints later when the referenced tables are created
    #
    # execute """
    # ALTER TABLE calendar_events
    # ADD CONSTRAINT calendar_events_portfolio_id_fkey
    # FOREIGN KEY (portfolio_id) REFERENCES portfolios(id);
    # """
    #
    # execute """
    # ALTER TABLE calendar_events
    # ADD CONSTRAINT calendar_events_channel_id_fkey
    # FOREIGN KEY (channel_id) REFERENCES channels(id);
    # """
    #
    # execute """
    # ALTER TABLE calendar_events
    # ADD CONSTRAINT calendar_events_service_booking_id_fkey
    # FOREIGN KEY (service_booking_id) REFERENCES service_bookings(id);
    # """
    #
    # execute """
    # ALTER TABLE calendar_events
    # ADD CONSTRAINT calendar_events_broadcast_id_fkey
    # FOREIGN KEY (broadcast_id) REFERENCES broadcasts(id);
    # """
  end
end
