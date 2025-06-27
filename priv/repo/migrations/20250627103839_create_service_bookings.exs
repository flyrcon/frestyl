defmodule Frestyl.Repo.Migrations.CreateServiceBookings do
  use Ecto.Migration

  def change do
    create table(:service_bookings) do
      add :booking_reference, :string, null: false
      add :scheduled_at, :utc_datetime, null: false
      add :client_name, :string, null: false
      add :client_email, :string, null: false
      add :client_phone, :string
      add :client_notes, :text
      add :status, :string, default: "pending"
      add :total_amount_cents, :integer, null: false
      add :platform_fee_cents, :integer, null: false
      add :provider_amount_cents, :integer, null: false
      add :deposit_amount_cents, :integer
      add :payment_status, :string, default: "pending"
      add :stripe_payment_intent_id, :string
      add :stripe_checkout_session_id, :string
      add :confirmation_sent_at, :utc_datetime
      add :reminder_sent_at, :utc_datetime
      add :cancelled_at, :utc_datetime
      add :cancellation_reason, :text
      add :completed_at, :utc_datetime
      add :provider_notes, :text
      add :client_rating, :integer
      add :client_feedback, :text
      add :meeting_link, :string
      add :meeting_details, :map, default: %{}

      add :service_id, references(:services, on_delete: :delete_all), null: false
      add :client_id, references(:users, on_delete: :nilify_all)
      add :provider_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:service_bookings, [:booking_reference])
    create index(:service_bookings, [:service_id])
    create index(:service_bookings, [:client_id])
    create index(:service_bookings, [:provider_id])
    create index(:service_bookings, [:scheduled_at])
    create index(:service_bookings, [:status])
    create index(:service_bookings, [:payment_status])
  end
end
