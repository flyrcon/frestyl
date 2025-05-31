defmodule Frestyl.Repo.Migrations.AddMissingChannelFields do
  use Ecto.Migration

  def change do
    alter table(:channels) do
      add_if_not_exists :thumbnail_url, :string
      add_if_not_exists :subscriber_count, :integer, default: 0
      add_if_not_exists :fundraising_enabled, :boolean, default: false
      add_if_not_exists :enable_transparency_mode, :boolean, default: false
      add_if_not_exists :settings, :map, default: %{}
    end
  end
end
