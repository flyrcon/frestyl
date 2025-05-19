# Create this file manually at priv/repo/migrations/TIMESTAMP_create_reactions.exs
# Replace TIMESTAMP with the current timestamp (e.g., 20250517120000)

defmodule Frestyl.Repo.Migrations.CreateReactions do
  use Ecto.Migration

  def change do
    create table(:reactions) do
      add :emoji, :string
      add :reaction_type, :string, null: false
      add :custom_text, :string
      add :message_id, references(:messages, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:reactions, [:message_id])
    create index(:reactions, [:user_id])
    create unique_index(:reactions, [:message_id, :user_id, :emoji, :reaction_type], name: :unique_user_emoji_reaction)
  end
end
