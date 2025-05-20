defmodule Frestyl.Repo.Migrations.AddMissingColumnsToSessionParticipants do
  use Ecto.Migration

  def up do
    # Only add columns that don't exist yet
    alter table(:session_participants) do
      # Add role column if it doesn't exist
      add_if_not_exists :role, :string, default: "participant"

      # Add joined_at column if it doesn't exist
      add_if_not_exists :joined_at, :utc_datetime

      # Add last_active_at column if it doesn't exist
      add_if_not_exists :last_active_at, :utc_datetime
    end
  end

  def down do
    alter table(:session_participants) do
      remove_if_exists :role, :string
      remove_if_exists :joined_at, :utc_datetime
      remove_if_exists :last_active_at, :utc_datetime
    end
  end
end
