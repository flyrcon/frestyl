defmodule Frestyl.Repo.Migrations.AddStatusToSessionParticipants do
  use Ecto.Migration

  def change do
    alter table(:session_participants) do
      add :status, :string, default: "waiting", null: false
      add_if_not_exists :last_active_at, :utc_datetime
    end

    # Update existing records to have "waiting" status
    execute """
    UPDATE session_participants
    SET status = CASE
      WHEN left_at IS NOT NULL THEN 'left'
      WHEN joined_at IS NOT NULL THEN 'active'
      ELSE 'waiting'
    END;
    """
  end
end
