defmodule Frestyl.Repo.Migrations.AddMissingPortfolioColumns do
  use Ecto.Migration

  def change do
    alter table(:portfolios) do
      add_if_not_exists :monetization_settings, :map, default: %{}
      add_if_not_exists :brand_enforcement, :map, default: %{}
      add_if_not_exists :story_type, :string
      add_if_not_exists :narrative_structure, :map, default: %{}
      add_if_not_exists :target_audience, {:array, :string}, default: []
      add_if_not_exists :story_tags, {:array, :string}, default: []
      add_if_not_exists :estimated_read_time, :integer
      add_if_not_exists :collaboration_settings, :map, default: %{}
      add_if_not_exists :service_booking_enabled, :boolean, default: false
    end
  end
end
