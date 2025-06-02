# Generate this migration with:
# mix ecto.gen.migration add_duration_fields_to_sessions

defmodule Frestyl.Repo.Migrations.AddDurationFieldsToSessions do
  use Ecto.Migration

  def change do
    alter table(:sessions) do
      add :scheduled_end, :utc_datetime
      add :duration_minutes, :integer
    end

    # Add index for querying active sessions by end time
    create index(:sessions, [:scheduled_end])
  end
end
