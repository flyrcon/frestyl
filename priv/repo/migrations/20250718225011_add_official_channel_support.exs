# Database migration to add official channel support
# priv/repo/migrations/xxx_add_official_channel_support.exs
defmodule Frestyl.Repo.Migrations.AddOfficialChannelSupport do
  use Ecto.Migration

  def change do
    # First, add the columns
    alter table(:channels) do
      modify :channel_type, :string, default: "community"
      add :pinned_position, :integer
      add :auto_join_new_users, :boolean, default: false
      add :metadata, :map, default: %{}
    end

    # Add indexes
    create_if_not_exists index(:channels, [:channel_type])
    create_if_not_exists index(:channels, [:pinned_position])
    create_if_not_exists index(:channels, [:auto_join_new_users])

    # REMOVE the execute statement for now
    # The UPDATE can be done in a separate migration or manually
  end

  def down do
    alter table(:channels) do
      remove :channel_type
      remove :pinned_position
      remove :auto_join_new_users
      remove :metadata
    end
  end
end
