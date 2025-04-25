# priv/repo/migrations/20250422000003_create_sessions.exs
defmodule Frestyl.Repo.Migrations.CreateSessions do
  use Ecto.Migration

  def change do
    create table(:sessions) do
      add :title, :string, null: false
      add :description, :text
      add :status, :string, null: false, default: "draft"
      add :scheduled_start, :utc_datetime
      add :scheduled_end, :utc_datetime
      add :actual_start, :utc_datetime
      add :actual_end, :utc_datetime
      add :max_participants, :integer
      add :is_private, :boolean, default: false, null: false
      add :access_code, :string
      add :session_type, :string, null: false, default: "collaboration"
      add :creator_id, references(:users, on_delete: :restrict), null: false
      add :channel_id, references(:channels, on_delete: :restrict), null: false

      timestamps()
    end

    create index(:sessions, [:creator_id])
    create index(:sessions, [:channel_id])
    create index(:sessions, [:status])
    create index(:sessions, [:scheduled_start])
  end
end
