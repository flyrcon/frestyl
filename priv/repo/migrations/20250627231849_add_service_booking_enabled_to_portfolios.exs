defmodule Frestyl.Repo.Migrations.AddServiceBookingEnabledToPortfolios do
  use Ecto.Migration

  def change do
    alter table(:portfolios) do
      add :service_booking_enabled, :boolean, default: false, null: false
      # If you find other undefined_column errors for 'portfolios' later,
      # you can add them here as well, or create new migrations for them.
      # For example, if your Portfolio schema also expects `require_approval`,
      # `sharing_permissions`, `cross_account_sharing`, `customization`,
      # `story_type`, `narrative_structure`, `target_audience`, `story_tags`,
      # `estimated_read_time`, `collaboration_settings` as the error message suggests
      # they are being queried, you might need to add them too if they're not there.
      # Example:
      # add :require_approval, :boolean, default: false
      # add :sharing_permissions, :map, default: %{}
      # add :customization, :map, default: %{}
    end
  end
end
