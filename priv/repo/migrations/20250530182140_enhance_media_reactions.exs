
# priv/repo/migrations/20250530000005_enhance_media_reactions.exs
defmodule Frestyl.Repo.Migrations.EnhanceMediaReactions do
  use Ecto.Migration

  def change do
    create table(:media_reactions) do
      add :reaction_type, :string, null: false # heart, fire, star, thumbsup, etc.
      add :media_file_id, references(:media_files, on_delete: :delete_all)
      add :media_group_id, references(:media_groups, on_delete: :delete_all)
      add :discussion_message_id, references(:discussion_messages, on_delete: :delete_all)
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :intensity, :float, default: 1.0 # For animated reactions
      add :timestamp_reference, :float # Time-specific reactions for audio/video
      add :metadata, :map, default: %{}

      timestamps()
    end

    create unique_index(:media_reactions, [:user_id, :media_file_id, :reaction_type],
      where: "media_file_id IS NOT NULL", name: :unique_user_media_file_reaction)
    create unique_index(:media_reactions, [:user_id, :media_group_id, :reaction_type],
      where: "media_group_id IS NOT NULL", name: :unique_user_media_group_reaction)
    create unique_index(:media_reactions, [:user_id, :discussion_message_id, :reaction_type],
      where: "discussion_message_id IS NOT NULL", name: :unique_user_message_reaction)

    create index(:media_reactions, [:media_file_id])
    create index(:media_reactions, [:media_group_id])
    create index(:media_reactions, [:discussion_message_id])
    create index(:media_reactions, [:user_id])
    create index(:media_reactions, [:reaction_type])
  end
end
