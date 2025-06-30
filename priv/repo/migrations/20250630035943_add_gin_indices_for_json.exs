

# Migration 7: Add GIN indices for JSON fields (PostgreSQL specific)
# File: priv/repo/migrations/20241201000007_add_gin_indices_for_json.exs

defmodule Frestyl.Repo.Migrations.AddGinIndicesForJson do
  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    # Only for PostgreSQL - enables fast JSON queries
    execute "CREATE INDEX CONCURRENTLY portfolios_privacy_settings_gin_idx ON portfolios USING GIN (privacy_settings)"
    execute "CREATE INDEX CONCURRENTLY portfolios_social_integration_gin_idx ON portfolios USING GIN (social_integration)"
    execute "CREATE INDEX CONCURRENTLY portfolios_contact_info_gin_idx ON portfolios USING GIN (contact_info)"
    execute "CREATE INDEX CONCURRENTLY sharing_analytics_click_position_gin_idx ON sharing_analytics USING GIN (click_position)"
  end

  def down do
    execute "DROP INDEX CONCURRENTLY IF EXISTS portfolios_privacy_settings_gin_idx"
    execute "DROP INDEX CONCURRENTLY IF EXISTS portfolios_social_integration_gin_idx"
    execute "DROP INDEX CONCURRENTLY IF EXISTS portfolios_contact_info_gin_idx"
    execute "DROP INDEX CONCURRENTLY IF EXISTS sharing_analytics_click_position_gin_idx"
  end
end
