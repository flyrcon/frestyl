# priv/repo/migrations/20250706_create_messages.exs

defmodule Frestyl.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add_if_not_exists :content, :string, null: false
      add_if_not_exists :message_type, :string, default: "text"  # "text", "image", "file", "system"
      add_if_not_exists :metadata, :map, default: "{}"


    end

    create_if_not_exists index(:messages, [:conversation_id])
    create_if_not_exists index(:messages, [:user_id])
    create_if_not_exists index(:messages, [:inserted_at])
    create_if_not_exists index(:messages, [:message_type])
  end
end
