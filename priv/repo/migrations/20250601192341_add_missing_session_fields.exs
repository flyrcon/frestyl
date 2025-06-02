# Generate this migration with:
# mix ecto.gen.migration add_missing_session_fields

defmodule Frestyl.Repo.Migrations.AddMissingSessionFields do
  use Ecto.Migration

  def change do
    alter table(:sessions) do
      # Add missing fields that are in your schema but not in the database
      add_if_not_exists :stream_key, :string
      add_if_not_exists :rtmp_url, :string
      add_if_not_exists :recording_url, :string
      add_if_not_exists :waiting_room_open_time, :utc_datetime
      add_if_not_exists :workspace_state, :map
    end
  end
end
