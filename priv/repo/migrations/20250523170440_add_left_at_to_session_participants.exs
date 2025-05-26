defmodule Frestyl.Repo.Migrations.AddLeftAtToSessionParticipants do
  use Ecto.Migration

  def change do
    alter table(:session_participants) do
      add :left_at, :utc_datetime
    end
  end
end
