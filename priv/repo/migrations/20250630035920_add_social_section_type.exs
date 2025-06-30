
# Migration 6: Add performance indices
# File: priv/repo/migrations/20241201000006_add_social_performance_indices.exs

defmodule Frestyl.Repo.Migrations.AddSocialPerformanceIndices do
  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    # Portfolio privacy and social queries
    create_if_not_exists index(:portfolios, [:visibility], concurrently: true)

    # Social integration performance
    create_if_not_exists index(:social_integrations, [:portfolio_id, :public_visibility], concurrently: true)
    create_if_not_exists index(:social_integrations, [:auto_sync_enabled, :sync_status], concurrently: true)

    # Access requests performance
    create_if_not_exists index(:access_requests, [:expires_at],
      concurrently: true,
      where: "expires_at IS NOT NULL")
  end
end
