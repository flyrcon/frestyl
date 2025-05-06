defmodule Frestyl.Repo.Migrations.CreateChatMessages do
  use Ecto.Migration

  def change do
    create table(:chat_messages) do
      add :content, :text, null: false
      add :read_at, :utc_datetime
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :conversation_id, references(:conversations, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:chat_messages, [:conversation_id])
    create index(:chat_messages, [:user_id])
  end
end
