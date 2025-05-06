# priv/repo/migrations/TIMESTAMP_create_events.exs
defmodule Frestyl.Repo.Migrations.CreateEvents do
  use Ecto.Migration

  def change do
    alter table(:events) do
      modify :starts_at, :utc_datetime, null: false
      modify :ends_at, :utc_datetime
      modify :status, :string, null: false, default: "draft"
      modify :admission_type, :string, null: false, default: "open"
      modify :price_in_cents, :integer, default: 0
      modify :waiting_room_opens_at, :utc_datetime

    end

    create_if_not_exists index(:events, [:starts_at])
  end
end
