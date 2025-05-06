defmodule Frestyl.Repo.Migrations.CreateSessionParticipants do
  use Ecto.Migration

  def change do
    # Session participants join table
    alter table(:session_participants, primary_key: false) do
      add_if_not_exists :joined_at, :utc_datetime, null: false, default: fragment("NOW()")

    end
  end
end
