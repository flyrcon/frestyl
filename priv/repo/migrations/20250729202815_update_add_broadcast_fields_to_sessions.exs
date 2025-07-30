defmodule Frestyl.Repo.Migrations.AddBroadcastFieldsToSessions do
  use Ecto.Migration

  def change do
    alter table(:sessions) do
      # Broadcast-specific fields
      add_if_not_exists :broadcast_type, :string
      add :visibility, :string, default: "public"
      add :allow_audience_participation, :boolean, default: true
      add_if_not_exists :max_participants, :integer
      add_if_not_exists :started_at, :utc_datetime
      add_if_not_exists :ended_at, :utc_datetime
      add :actual_duration, :integer
    end

    # Add indexes for better query performance
    create_if_not_exists index(:sessions, [:broadcast_type])
    create index(:sessions, [:visibility])
    create_if_not_exists index(:sessions, [:session_type, :status])
  end
end
