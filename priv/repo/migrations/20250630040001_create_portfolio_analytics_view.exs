
# Migration 8: Create analytics view for performance
# File: priv/repo/migrations/20241201000008_create_portfolio_analytics_view.exs

defmodule Frestyl.Repo.Migrations.CreatePortfolioAnalyticsView do
  use Ecto.Migration

  def up do
    execute """
    CREATE VIEW portfolio_analytics_summary AS
    SELECT
      p.id as portfolio_id,
      p.title,
      p.visibility,
      COUNT(DISTINCT pv.id) as total_visits,
      COUNT(DISTINCT pv.ip_address) as unique_visitors,
      COUNT(DISTINCT ps.id) as total_shares,
      COUNT(DISTINCT si.id) as social_integrations,
      COUNT(DISTINCT ar.id) FILTER (WHERE ar.status = 'pending') as pending_access_requests,
      COUNT(DISTINCT sa.id) FILTER (WHERE sa.event_type = 'social_share_clicked') as social_shares,
      MAX(pv.inserted_at) as last_visit,
      p.updated_at
    FROM portfolios p
    LEFT JOIN portfolio_visits pv ON p.id = pv.portfolio_id
    LEFT JOIN portfolio_shares ps ON p.id = ps.portfolio_id
    LEFT JOIN social_integrations si ON p.id = si.portfolio_id AND si.sync_status = 'active'
    LEFT JOIN access_requests ar ON p.id = ar.portfolio_id
    LEFT JOIN sharing_analytics sa ON p.id = sa.portfolio_id
    GROUP BY p.id, p.title, p.visibility, p.updated_at
    """
  end

  def down do
    execute "DROP VIEW IF EXISTS portfolio_analytics_summary"
  end
end
