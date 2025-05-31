defmodule Frestyl.Repo.Migrations.AddFileTypeToMediaFiles do
  use Ecto.Migration

  def change do
    alter table(:media_files) do
      add :file_type, :string
    end
  end
end
