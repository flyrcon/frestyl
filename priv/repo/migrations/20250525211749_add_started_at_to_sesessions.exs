defmodule Frestyl.Repo.Migrations.AddStartedAtToSessions do
  use Ecto.Migration

  def change do
    alter table(:sessions) do
      modify :started_at, :utc_datetime
    end
  end
end
