# priv/repo/migrations/20250707000005_add_admin_fields_to_channels.exs
defmodule Frestyl.Repo.Migrations.AddAdminFieldsToChannels do
  use Ecto.Migration

  def change do
    alter table(:channels) do
      add :is_official, :boolean, default: false
      add :auto_join_all_users, :boolean, default: false
      add :moderated_by_admin_id, references(:users, on_delete: :nilify_all)
      add :moderation_reason, :text
      add :moderated_at, :utc_datetime
      add :reported_at, :utc_datetime
      add :deleted_by_admin_id, references(:users, on_delete: :nilify_all)
      add :deletion_reason, :text
      add :deleted_at, :utc_datetime
    end

    create index(:channels, [:is_official])
    create index(:channels, [:auto_join_all_users])
    create index(:channels, [:moderated_by_admin_id])
    create index(:channels, [:moderated_at])
    create index(:channels, [:reported_at])
    create index(:channels, [:deleted_at])
  end
end
