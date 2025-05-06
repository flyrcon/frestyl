# priv/repo/migrations/20240515000004_create_files.exs
defmodule Frestyl.Repo.Migrations.CreateFiles do
  use Ecto.Migration

  def change do
    create table(:files) do
      add :filename, :string, null: false
      add :content_type, :string, null: false
      add :file_size, :bigint, null: false
      add :file_path, :string, null: false
      add :url, :string, null: false
      add :storage_type, :string, default: "local"
      add :status, :string, default: "active"
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :channel_id, references(:channels, on_delete: :delete_all)

      timestamps()
    end

    create index(:files, [:user_id])
    create index(:files, [:channel_id])
    create index(:files, [:content_type])
    create index(:files, [:status])
  end
end
