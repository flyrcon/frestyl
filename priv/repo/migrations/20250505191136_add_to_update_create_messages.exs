defmodule Frestyl.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages) do
      add :metadata, :map, default: %{}
      add :is_edited, :boolean, default: false
      add :is_deleted, :boolean, default: false

      add :user_id, references(:users, on_delete: :nilify_all), null: false
      add :channel_id, references(:channels, on_delete: :delete_all)
      add :conversation_id, references(:conversations, on_delete: :delete_all)

      timestamps()
    end

    create index(:messages, [:user_id])
    create index(:messages, [:channel_id])
    create index(:messages, [:conversation_id])
    create index(:messages, [:message_type])
    create index(:messages, [:inserted_at])
  end
end
