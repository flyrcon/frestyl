defmodule Frestyl.Repo.Migrations.CreateExportJobs do
  use Ecto.Migration

  def change do
    create table(:export_jobs) do
      add :portfolio_id, references(:portfolios, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :account_id, references(:user_accounts, on_delete: :delete_all)
      add :export_type, :string, null: false
      add :format, :string, null: false
      add :status, :string, default: "pending", null: false
      add :file_path, :string
      add :file_size, :bigint
      add :options, :map, default: %{}
      add :error_message, :text
      add :completed_at, :utc_datetime

      timestamps()
    end

    create index(:export_jobs, [:portfolio_id])
    create index(:export_jobs, [:user_id])
    create index(:export_jobs, [:account_id])
    create index(:export_jobs, [:status])
    create index(:export_jobs, [:export_type])
    create index(:export_jobs, [:completed_at])

    # Add constraint for valid statuses
    create constraint(:export_jobs, :valid_status,
      check: "status IN ('pending', 'processing', 'completed', 'failed')")
  end
end
