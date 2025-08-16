# priv/repo/migrations/20250815000007_create_operation_acknowledgments.exs
defmodule Frestyl.Repo.Migrations.CreateOperationAcknowledgments do
  use Ecto.Migration

  def change do
    alter table(:operation_acknowledgments) do
      #modify :operation_id, references(:session_operations, type: :binary_id, on_delete: :delete_all), null: false
      # add_if_not_exists :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add_if_not_exists :acknowledged_at, :utc_datetime, null: false
      add_if_not_exists :client_timestamp, :utc_datetime
      add_if_not_exists :metadata, :map, default: %{}
    end

    create_if_not_exists index(:operation_acknowledgments, [:operation_id])
    create_if_not_exists index(:operation_acknowledgments, [:user_id])
    create index(:operation_acknowledgments, [:acknowledged_at])
    # create_if_not_exists unique_index(:operation_acknowledgments, [:operation_id, :user_id])
  end

end
