# priv/repo/migrations/20250422000004_create_events.exs
defmodule Frestyl.Repo.Migrations.CreateEvents do
  use Ecto.Migration

  def change do
    create table(:events) do
      add :title, :string, null: false
      add :description, :text
      add :status, :string, null: false, default: "scheduled"
      add :scheduled_start, :utc_datetime, null: false
      add :scheduled_end, :utc_datetime
      add :actual_start, :utc_datetime
      add :actual_end, :utc_datetime
      add :visibility, :string, null: false, default: "public"
      add :access_code, :string
      add :max_attendees, :integer
      add :thumbnail_url, :string
      add :recording_available, :boolean, default: false, null: false
      add :host_id, references(:users, on_delete: :restrict), null: false
      add :channel_id, references(:channels, on_delete: :restrict), null: false
      add :session_id, references(:sessions, on_delete: :nilify_all)

      timestamps()
    end

    create index(:events, [:host_id])
    create index(:events, [:channel_id])
    create index(:events, [:session_id])
    create index(:events, [:status])
    create index(:events, [:scheduled_start])
    create index(:events, [:visibility])
  end
end
