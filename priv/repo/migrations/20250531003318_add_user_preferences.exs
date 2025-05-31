defmodule Frestyl.Repo.Migrations.AddUserPreferences do
  use Ecto.Migration

  def change do
    alter table(:users) do
      # Add preferences field that's expected by your authentication system
      add :preferences, :map, default: %{}
    end
  end
end
