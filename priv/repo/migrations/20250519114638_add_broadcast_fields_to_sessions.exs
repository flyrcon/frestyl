# Migration for sessions table broadcast fields
defmodule Frestyl.Repo.Migrations.AddBroadcastFieldsToSessions do
  use Ecto.Migration

  def change do
    alter table(:sessions) do
      add :broadcast_type, :string
      add :waiting_room_enabled, :boolean, default: true
      add :waiting_room_open_time, :utc_datetime
      add :host_id, references(:users), null: true
      add :started_at, :utc_datetime
    end

    create index(:sessions, [:broadcast_type])
    create index(:sessions, [:host_id])
  end
end

# Migration for session participants muted/blocked fields
defmodule Frestyl.Repo.Migrations.AddModerationFieldsToSessionParticipants do
  use Ecto.Migration

  def change do
    alter table(:session_participants) do
      add :muted, :boolean, default: false
      add :blocked, :boolean, default: false
    end
  end
end
