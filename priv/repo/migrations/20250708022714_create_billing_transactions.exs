# priv/repo/migrations/20250707000007_create_billing_transactions.exs
defmodule Frestyl.Repo.Migrations.CreateBillingTransactions do
  use Ecto.Migration

  def change do
    create table(:billing_transactions) do
      add :account_id, references(:accounts, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      add :amount, :decimal, precision: 10, scale: 2, null: false
      add :currency, :string, default: "USD", null: false
      add :transaction_type, :string, null: false # payment, refund, adjustment
      add :status, :string, null: false # pending, completed, failed, cancelled
      add :description, :text

      add :external_transaction_id, :string
      add :payment_method, :string
      add :payment_gateway, :string

      add :processed_at, :utc_datetime
      add :failed_at, :utc_datetime
      add :failure_reason, :text

      add :metadata, :map, default: %{}

      timestamps()
    end

    create index(:billing_transactions, [:account_id])
    create index(:billing_transactions, [:user_id])
    create index(:billing_transactions, [:transaction_type])
    create index(:billing_transactions, [:status])
    create index(:billing_transactions, [:processed_at])
    create index(:billing_transactions, [:external_transaction_id])
  end
end
