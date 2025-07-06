# priv/repo/migrations/20250706_create_conversations.exs

defmodule Frestyl.Repo.Migrations.CreateConversations do
  use Ecto.Migration

  def change do
    alter table(:conversations) do
      modify :title, :string
      modify :type, :string, null: false  # "direct", "group", "channel"
      add_if_not_exists :context, :string  # "portfolio", "session", "service", "channel", "lab", "general"
      add_if_not_exists :context_id, :integer  # ID of the context object
      add_if_not_exists :metadata, :map, default: "{}"
      add :last_message_id, references(:messages, on_delete: :nilify_all)
      modify :last_message_at, :utc_datetime

    end

    create_if_not_exists index(:conversations, [:context, :context_id])
    create index(:conversations, [:type])
    create_if_not_exists index(:conversations, [:last_message_at])
  end
end
