defmodule Frestyl.Repo.Migrations.UpdateFrestylOfficialChannel do
  use Ecto.Migration

    def up do
      execute """
      UPDATE channels
      SET channel_type = 'official',
          pinned_position = 1,
          auto_join_new_users = true,
          metadata = '{"is_official": true, "discovery_enabled": true}'
      WHERE slug = 'frestyl-official';
      """
    end

    def down do
      execute """
      UPDATE channels
      SET channel_type = 'community',
          pinned_position = NULL,
          auto_join_new_users = false,
          metadata = '{}'
      WHERE slug = 'frestyl-official';
      """
    end
end
