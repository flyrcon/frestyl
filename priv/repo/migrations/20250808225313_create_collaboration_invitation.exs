defmodule Frestyl.Repo.Migrations.CreateCollaborationInvitations do
  use Ecto.Migration

  def change do
    create table(:collaboration_invitations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :invitation_code, :string, null: false
      add :role, :string, null: false, default: "collaborator"
      add :expires_at, :utc_datetime, null: false
      add :max_uses, :integer, default: 1
      add :uses_count, :integer, default: 0
      add :is_active, :boolean, default: true

      add :story_id, references(:enhanced_story_structures, type: :binary_id, on_delete: :delete_all)
      add :created_by_id, references(:users, on_delete: :delete_all)

      timestamps()
    end

    create unique_index(:collaboration_invitations, [:invitation_code])
    create index(:collaboration_invitations, [:story_id])
    create index(:collaboration_invitations, [:created_by_id])
    create index(:collaboration_invitations, [:expires_at])
  end
end
