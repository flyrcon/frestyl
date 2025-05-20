defmodule Frestyl.Repo.Migrations.AddSessionParticipantId do
  use Ecto.Migration

  def change do
    alter table(:session_participants) do
      add :id, :serial, primary_key: true
    end
  end
end
