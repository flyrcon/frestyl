# priv/repo/migrations/20250815000005_create_collaboration_contributions.exs
defmodule Frestyl.Repo.Migrations.CreateCollaborationContributions do
  use Ecto.Migration

  def change do
    # Collaboration contributions for tokenization tracking
    create table(:collaboration_contributions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :session_id, references(:sessions, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :contribution_type, :string, null: false # track_creation, recording_time, effect_application, etc.
      add :weight, :integer, default: 1
      add :metadata, :map, default: %{}
      add :operation_data, :map, default: %{}
      add :complexity, :string, default: "low" # low, medium, high
      add :timestamp, :utc_datetime, null: false
      add :processed_for_tokens, :boolean, default: false

      timestamps()
    end

    create index(:collaboration_contributions, [:session_id])
    create index(:collaboration_contributions, [:user_id])
    create index(:collaboration_contributions, [:contribution_type])
    create index(:collaboration_contributions, [:timestamp])
    create index(:collaboration_contributions, [:processed_for_tokens])
  end
end
