defmodule Frestyl.Repo.Migrations.AddServiceFieldsToSubscriptionPlans do
  use Ecto.Migration

  def change do
    alter table(:subscription_plans) do
      add :max_services, :integer
      add :service_booking_enabled, :boolean, default: false
      add :service_analytics_enabled, :boolean, default: false
      add :service_calendar_integration, :boolean, default: false
    end
  end
end
