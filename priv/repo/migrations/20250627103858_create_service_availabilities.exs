defmodule Frestyl.Repo.Migrations.CreateServiceAvailabilities do
  use Ecto.Migration

  def change do
    create table(:service_availabilities) do
      add :day_of_week, :integer, null: false
      add :start_time, :time, null: false
      add :end_time, :time, null: false
      add :timezone, :string, default: "UTC"
      add :is_active, :boolean, default: true
      add :effective_from, :date
      add :effective_until, :date
      add :exceptions, {:array, :date}, default: []

      add :service_id, references(:services, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:service_availabilities, [:service_id])
    create index(:service_availabilities, [:day_of_week])
    create index(:service_availabilities, [:is_active])
  end
end
