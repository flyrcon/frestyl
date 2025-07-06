# priv/repo/migrations/xxx_create_conversation_mutes.exs
defmodule Frestyl.Repo.Migrations.CreateConversationMutes do
  use Ecto.Migration

  def change do
    create table(:conversation_mutes) do
      add :muted_until, :utc_datetime, null: false
      add :reason, :string

      add :conversation_id, references(:conversations, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:conversation_mutes, [:conversation_id, :user_id])
    create index(:conversation_mutes, [:user_id])
  end
end
