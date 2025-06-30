

# Migration 9: Add function and trigger for auto-updating sync timestamps
# File: priv/repo/migrations/20241201000009_add_sync_triggers.exs

defmodule Frestyl.Repo.Migrations.AddSyncTriggers do
  use Ecto.Migration

  def up do
    # Function to update social integration sync timestamp
    execute """
    CREATE OR REPLACE FUNCTION update_social_integration_sync()
    RETURNS TRIGGER AS $$
    BEGIN
      UPDATE social_integrations
      SET last_sync_at = NOW()
      WHERE id = NEW.social_integration_id;
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """

    # Trigger that fires when new social posts are inserted
    execute """
    CREATE TRIGGER social_posts_sync_trigger
      AFTER INSERT ON social_posts
      FOR EACH ROW
      EXECUTE FUNCTION update_social_integration_sync();
    """

    # Function to automatically generate access tokens
    execute """
    CREATE OR REPLACE FUNCTION generate_access_token()
    RETURNS TRIGGER AS $$
    BEGIN
      IF NEW.status = 'approved' AND NEW.access_token IS NULL THEN
        NEW.access_token = encode(gen_random_bytes(32), 'base64');
        NEW.expires_at = NOW() + INTERVAL '30 days';
      END IF;
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """

    # Trigger for access request approval
    execute """
    CREATE TRIGGER access_request_approval_trigger
      BEFORE UPDATE ON access_requests
      FOR EACH ROW
      WHEN (OLD.status = 'pending' AND NEW.status = 'approved')
      EXECUTE FUNCTION generate_access_token();
    """
  end

  def down do
    execute "DROP TRIGGER IF EXISTS social_posts_sync_trigger ON social_posts"
    execute "DROP TRIGGER IF EXISTS access_request_approval_trigger ON access_requests"
    execute "DROP FUNCTION IF EXISTS update_social_integration_sync()"
    execute "DROP FUNCTION IF EXISTS generate_access_token()"
  end
end
