defmodule Frestyl.Repo.Migrations.AddStatusToMediaFiles do
  use Ecto.Migration

  def change do
    alter table(:media_files) do
      modify :status, :string, default: "active"
    end
  end
end
