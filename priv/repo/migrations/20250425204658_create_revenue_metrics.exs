defmodule Frestyl.Repo.Migrations.CreateRevenueMetrics do
  use Ecto.Migration

  def change do
    create table(:revenue_metrics) do
      # Use :binary_id type for UUID fields
      add :channel_id, :binary_id, null: false
      add :event_id, :binary_id

      # Revenue amounts
      add :total_amount, :decimal, null: false
      add :subscription_amount, :decimal, default: 0
      add :donation_amount, :decimal, default: 0
      add :ticket_amount, :decimal, default: 0
      add :merchandise_amount, :decimal, default: 0

      # Transaction counts
      add :subscription_count, :integer, default: 0
      add :donation_count, :integer, default: 0
      add :ticket_count, :integer, default: 0
      add :merchandise_count, :integer, default: 0

      # Currency and date
      add :currency, :string, default: "USD"
      add :date, :date, null: false

      timestamps()
    end

    create index(:revenue_metrics, [:channel_id])
    create index(:revenue_metrics, [:event_id])
    create index(:revenue_metrics, [:date])
    create index(:revenue_metrics, [:channel_id, :date])
  end
end
