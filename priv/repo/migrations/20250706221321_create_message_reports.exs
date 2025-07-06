# priv/repo/migrations/xxx_create_message_reports.exs
defmodule Frestyl.Repo.Migrations.CreateMessageReports do
  use Ecto.Migration

  def change do
    create table(:message_reports) do
      add :reason, :string, null: false
      add :status, :string, default: "pending"
      add :moderator_notes, :text
      add :resolved_at, :utc_datetime

      add :message_id, references(:messages, on_delete: :delete_all), null: false
      add :reporter_id, references(:users, on_delete: :delete_all), null: false
      add :moderator_id, references(:users, on_delete: :nilify_all)

      timestamps()
    end

    create index(:message_reports, [:message_id])
    create index(:message_reports, [:reporter_id])
    create index(:message_reports, [:status])
  end
end
