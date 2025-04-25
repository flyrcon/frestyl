# priv/repo/migrations/TIMESTAMP_create_votes.exs
defmodule Frestyl.Repo.Migrations.CreateVotes do
  use Ecto.Migration

  def change do
    create table(:votes) do
      add :score, :integer, null: false
      add :comment, :text

      add :event_id, references(:events, on_delete: :delete_all), null: false
      add :voter_id, references(:users, on_delete: :delete_all), null: false
      add :creator_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:votes, [:event_id])
    create index(:votes, [:voter_id])
    create index(:votes, [:creator_id])
    create unique_index(:votes, [:event_id, :voter_id, :creator_id])
  end
end
