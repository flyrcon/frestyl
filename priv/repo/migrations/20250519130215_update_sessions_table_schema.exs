defmodule Frestyl.Repo.Migrations.UpdateSessionsTableSchema do
  use Ecto.Migration

  def change do
    # First rename the column (separate from alter block)
    rename table(:sessions), :scheduled_end, to: :scheduled_for

    # Then add missing columns
    alter table(:sessions) do
      add_if_not_exists :is_public, :boolean, default: true
      add_if_not_exists :ended_at, :utc_datetime
      add_if_not_exists :workspace_state, :map
      add_if_not_exists :recording_available, :boolean, default: false
      add_if_not_exists :recording_url, :string
      add_if_not_exists :max_participants, :integer
      add_if_not_exists :broadcast_type, :string
      add_if_not_exists :waiting_room_enabled, :boolean, default: true
      add_if_not_exists :waiting_room_open_time, :utc_datetime
    end
  end
end
