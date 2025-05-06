defmodule Frestyl.Repo.Migrations.CreateConversations do
  use Ecto.Migration

  def change do
    create table(:conversations) do
      add :title, :string
      add :last_message_at, :utc_datetime
      add :unread_count, :integer, default: 0

      timestamps()
    end

    create table(:conversation_participants) do
      add :conversation_id, references(:conversations, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:conversation_participants, [:conversation_id])
    create index(:conversation_participants, [:user_id])
    create unique_index(:conversation_participants, [:conversation_id, :user_id])
  end
end
