# priv/repo/migrations/20250422000006_create_join_tables.exs
defmodule Frestyl.Repo.Migrations.CreateJoinTables do
  use Ecto.Migration

  def change do
    # Channel subscribers join table
    create table(:channel_subscribers, primary_key: false) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :channel_id, references(:channels, on_delete: :delete_all), null: false
      add :subscribed_at, :utc_datetime, null: false, default: fragment("NOW()")

      timestamps()
    end

    create_if_not_exists unique_index(:channel_subscribers, [:user_id, :channel_id])
    create_if_not_exists index(:channel_subscribers, [:channel_id])



    create_if_not_exists unique_index(:session_participants, [:user_id, :session_id])
    create_if_not_exists index(:session_participants, [:session_id])

    # Event attendees join table
    create table(:event_attendees, primary_key: false) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :event_id, references(:events, on_delete: :delete_all), null: false
      add :registered_at, :utc_datetime, null: false, default: fragment("NOW()")
      add :attended_at, :utc_datetime
      add :status, :string, null: false, default: "registered"

      timestamps()
    end

    create_if_not_exists unique_index(:event_attendees, [:user_id, :event_id])
    create_if_not_exists index(:event_attendees, [:event_id])
  end
end
