# priv/repo/migrations/TIMESTAMP_create_events.exs
defmodule Frestyl.Repo.Migrations.CreateEvents do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add :starts_at, :utc_datetime, null: false
      add_if_not_exists :ends_at, :utc_datetime
      modify :status, :string, null: false, default: "draft"
      add :admission_type, :string, null: false, default: "open"
      add :price_in_cents, :integer, default: 0
      add :waiting_room_opens_at, :utc_datetime

    end

    create index(:events, [:starts_at])
  end
end
