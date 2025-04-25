# priv/repo/migrations/TIMESTAMP_create_event_attendees.exs
defmodule Frestyl.Repo.Migrations.CreateEventAttendees do
  use Ecto.Migration

  def change do
    alter table(:event_attendees) do
      modify :status, :string, null: false, default: "registered"
      add :joined_at, :utc_datetime
      add :left_at, :utc_datetime
      add :payment_status, :string, default: "not_required"
      add :payment_amount_in_cents, :integer
      add :lottery_position, :integer

    end

    create index(:event_attendees, [:user_id])
    create unique_index(:event_attendees, [:event_id, :user_id])
    create index(:event_attendees, [:status])
  end
end
