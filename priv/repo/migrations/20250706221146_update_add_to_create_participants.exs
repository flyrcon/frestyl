# priv/repo/migrations/20250706_create_participants.exs

defmodule Frestyl.Repo.Migrations.CreateParticipants do
  use Ecto.Migration

  def change do
    create table(:participants) do
      add :role, :string, default: "member"  # "member", "admin", "moderator"
      add :joined_at, :utc_datetime
      add :last_read_at, :utc_datetime
      add :unread_count, :integer, default: 0
      add :notifications_enabled, :boolean, default: true

      add :conversation_id, references(:conversations, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:participants, [:conversation_id, :user_id])
    create index(:participants, [:user_id])
    create index(:participants, [:conversation_id])
    create index(:participants, [:last_read_at])
  end
end
