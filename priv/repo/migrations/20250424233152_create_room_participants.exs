# priv/repo/migrations/20250424000004_create_room_participants.exs

defmodule Frestyl.Repo.Migrations.CreateRoomParticipants do
  use Ecto.Migration

  def change do
    create table(:room_participants) do
      add :role, :string, default: "viewer"
      add :joined_at, :utc_datetime, null: false
      add :last_activity, :utc_datetime, null: false

      add :room_id, references(:rooms, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :nilify_all), null: false

      timestamps()
    end

    create index(:room_participants, [:room_id])
    create index(:room_participants, [:user_id])
    create unique_index(:room_participants, [:room_id, :user_id])
  end
end
