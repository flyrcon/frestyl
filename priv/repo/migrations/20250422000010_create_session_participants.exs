defmodule Frestyl.Repo.Migrations.CreateSessionParticipants do
  use Ecto.Migration

  def change do
    # Session participants join table
    create table(:session_participants, primary_key: false) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :session_id, references(:sessions, on_delete: :delete_all), null: false
      add :joined_at, :utc_datetime, null: false, default: fragment("NOW()")

      timestamps()
    end

    create unique_index(:session_participants, [:user_id, :session_id])
    create index(:session_participants, [:session_id])
  end
end
