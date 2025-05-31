
# priv/repo/migrations/20250530000008_create_view_history.exs
defmodule Frestyl.Repo.Migrations.CreateViewHistory do
  use Ecto.Migration

  def change do
    create table(:view_history) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :media_file_id, references(:media_files, on_delete: :delete_all)
      add :media_group_id, references(:media_groups, on_delete: :delete_all)
      add :channel_id, references(:channels, on_delete: :delete_all)
      add :view_duration, :integer # In seconds
      add :interaction_count, :integer, default: 0
      add :device_type, :string # mobile, desktop, tablet
      add :view_context, :string # discovery, search, channel, discussion
      add :completion_percentage, :float # For audio/video
      add :metadata, :map, default: %{}

      timestamps()
    end

    create index(:view_history, [:user_id, :inserted_at])
    create index(:view_history, [:media_file_id])
    create index(:view_history, [:media_group_id])
    create index(:view_history, [:channel_id])
  end
end
