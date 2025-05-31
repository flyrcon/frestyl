
# priv/repo/migrations/20250530000004_create_discussion_messages.exs
defmodule Frestyl.Repo.Migrations.CreateDiscussionMessages do
  use Ecto.Migration

  def change do
    create table(:discussion_messages) do
      add :content, :text, null: false
      add :media_discussion_id, references(:media_discussions, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :parent_id, references(:discussion_messages, on_delete: :delete_all) # For threading
      add :message_type, :string, default: "text" # text, media, timestamp_note, etc.
      add :timestamp_reference, :float # For time-based comments on audio/video
      add :attachments, {:array, :map}, default: []
      add :mentions, {:array, :integer}, default: [] # User IDs mentioned
      add :edited_at, :utc_datetime
      add :metadata, :map, default: %{}

      timestamps()
    end

    create index(:discussion_messages, [:media_discussion_id])
    create index(:discussion_messages, [:user_id])
    create index(:discussion_messages, [:parent_id])
    create index(:discussion_messages, [:timestamp_reference])
  end
end
