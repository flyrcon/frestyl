# Create this migration file: priv/repo/migrations/add_onboarding_completed_to_users.exs

defmodule Frestyl.Repo.Migrations.AddOnboardingCompletedToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :onboarding_completed, :boolean, default: false
    end
  end
end
