# priv/repo/migrations/006_create_story_collaborations.exs
defmodule Frestyl.Repo.Migrations.CreateStoryCollaborations do
  use Ecto.Migration

  def change do
    create table(:story_collaborations) do
      add :story_id, references(:portfolios, on_delete: :delete_all), null: false
      add :collaborator_user_id, references(:users, on_delete: :delete_all)
      add :collaborator_account_id, references(:accounts, on_delete: :delete_all)
      add :invited_by_user_id, references(:users, on_delete: :delete_all), null: false

      add :role, :string, null: false, default: "viewer"
      add :permissions, :map, default: %{}
      add :access_level, :string, null: false, default: "guest"
      add :billing_context, :string, null: false, default: "host_pays"

      # Invitation management
      add :invitation_token, :string
      add :invitation_email, :string
      add :status, :string, null: false, default: "pending"
      add :expires_at, :utc_datetime
      add :accepted_at, :utc_datetime
      add :last_active_at, :utc_datetime

      timestamps()
    end

    create index(:story_collaborations, [:story_id])
    create index(:story_collaborations, [:collaborator_user_id])
    create index(:story_collaborations, [:invitation_token])
    create unique_index(:story_collaborations, [:story_id, :collaborator_user_id],
      where: "status = 'accepted'", name: :story_collaborations_unique_active)

    # Add constraints
    create constraint(:story_collaborations, :valid_role,
      check: "role IN ('viewer', 'commenter', 'editor', 'co_author')")

    create constraint(:story_collaborations, :valid_access_level,
      check: "access_level IN ('guest', 'account_member', 'cross_account')")

    create constraint(:story_collaborations, :valid_billing_context,
      check: "billing_context IN ('host_pays', 'guest_pays', 'shared')")

    create constraint(:story_collaborations, :valid_status,
      check: "status IN ('pending', 'accepted', 'declined', 'revoked')")
  end
end
