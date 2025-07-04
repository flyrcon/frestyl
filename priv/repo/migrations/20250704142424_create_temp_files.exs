# priv/repo/migrations/YYYYMMDDHHMMSS_create_temp_files.exs
defmodule Frestyl.Repo.Migrations.CreateTempFiles do
  use Ecto.Migration

  def change do
    create table(:temp_files, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :filename, :string, null: false
      add :original_name, :string
      add :file_path, :string, null: false
      add :content_type, :string, null: false
      add :file_size, :integer, null: false, default: 0
      add :download_count, :integer, null: false, default: 0
      add :expires_at, :utc_datetime, null: false
      add :export_format, :string
      add :export_options, :map, default: %{}

      # Use bigserial (integer) to match your existing schema
      add :user_id, references(:users, on_delete: :delete_all, type: :bigserial)
      add :portfolio_id, references(:portfolios, on_delete: :delete_all, type: :bigserial)

      timestamps()
    end

    create unique_index(:temp_files, [:filename])
    create index(:temp_files, [:user_id])
    create index(:temp_files, [:portfolio_id])
    create index(:temp_files, [:expires_at])
    create index(:temp_files, [:export_format])
    create index(:temp_files, [:inserted_at])
  end
end
