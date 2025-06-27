defmodule Frestyl.Repo.Migrations.CreateServices do
  use Ecto.Migration

  def change do
    create table(:services) do
      add :title, :string, null: false
      add :description, :text
      add :service_type, :string, null: false
      add :duration_minutes, :integer, null: false
      add :price_cents, :integer, null: false
      add :currency, :string, default: "USD"
      add :is_active, :boolean, default: true
      add :booking_buffer_minutes, :integer, default: 15
      add :advance_booking_days, :integer, default: 30
      add :cancellation_policy_hours, :integer, default: 24
      add :max_bookings_per_day, :integer
      add :tags, {:array, :string}, default: []
      add :requirements, :string
      add :preparation_notes, :string
      add :location_type, :string, default: "online"
      add :location_details, :map, default: %{}
      add :auto_confirm, :boolean, default: true
      add :deposit_required, :boolean, default: false
      add :deposit_percentage, :decimal, precision: 5, scale: 2
      add :settings, :map, default: %{}

      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :portfolio_id, references(:portfolios, on_delete: :nilify_all)

      timestamps()
    end

    create index(:services, [:user_id])
    create index(:services, [:portfolio_id])
    create index(:services, [:service_type])
    create index(:services, [:is_active])
  end
end
