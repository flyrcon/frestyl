# priv/repo/migrations/20250815000011_create_ai_processing_jobs.exs
defmodule Frestyl.Repo.Migrations.CreateAiProcessingJobs do
  use Ecto.Migration

  def change do
    # AI processing jobs for transcription, chapter detection, etc.
    create table(:ai_processing_jobs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :job_type, :string, null: false # transcription, chapter_detection, noise_reduction, etc.
      add :status, :string, default: "queued" # queued, processing, completed, failed
      add :progress, :float, default: 0.0
      add :input_data, :map, null: false
      add :output_data, :map, default: %{}
      add :error_message, :text
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime
      add :processing_time, :integer # milliseconds
      add :cost_cents, :integer # AI processing cost in cents
      add :priority, :integer, default: 0
      add :retry_count, :integer, default: 0
      add :max_retries, :integer, default: 3
      add :metadata, :map, default: %{}

      # Polymorphic associations
      add :target_type, :string # Episode, MediaFile, Session, etc.
      add :target_id, :binary_id
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:ai_processing_jobs, [:job_type])
    create index(:ai_processing_jobs, [:status])
    create index(:ai_processing_jobs, [:target_type, :target_id])
    create index(:ai_processing_jobs, [:user_id])
    create index(:ai_processing_jobs, [:priority])
    create index(:ai_processing_jobs, [:inserted_at])
  end
end
