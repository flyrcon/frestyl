
# Migration 4: Create access_requests table
# File: priv/repo/migrations/20241201000004_create_access_requests.exs

defmodule Frestyl.Repo.Migrations.CreateAccessRequests do
  use Ecto.Migration

  def change do
    create table(:access_requests, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :requester_email, :string, null: false
      add :requester_name, :string
      add :message, :text
      add :status, :string, default: "pending"
      add :approved_at, :utc_datetime
      add :expires_at, :utc_datetime
      add :access_token, :string
      add :ip_address, :string
      add :user_agent, :text
      add :referrer, :string

      # Admin response
      add :admin_response, :text
      add :reviewed_by_user_id, references(:users, on_delete: :nilify_all)
      add :reviewed_at, :utc_datetime

      # Foreign keys
      add :portfolio_id, references(:portfolios, on_delete: :delete_all), null: false
      add :requester_user_id, references(:users, on_delete: :nilify_all)

      timestamps()
    end

    create index(:access_requests, [:portfolio_id])
    create index(:access_requests, [:requester_email])
    create index(:access_requests, [:status])
    create index(:access_requests, [:access_token])
    create_if_not_exists index(:access_requests, [:expires_at])
    create index(:access_requests, [:portfolio_id, :status])

    # Add check constraints
    create constraint(:access_requests, :valid_status,
      check: "status IN ('pending', 'approved', 'denied')")
    create constraint(:access_requests, :valid_email_format,
      check: "requester_email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}$'")
  end
end
