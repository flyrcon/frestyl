
# Migration 10: Add default values for existing portfolios
# File: priv/repo/migrations/20241201000010_populate_default_social_privacy_values.exs

defmodule Frestyl.Repo.Migrations.PopulateDefaultSocialPrivacyValues do
  use Ecto.Migration
  import Ecto.Query
  alias Frestyl.Repo

  def up do
    # Set default privacy settings for existing portfolios
    execute """
    UPDATE portfolios
    SET privacy_settings = '{
      "allow_search_engines": false,
      "show_in_discovery": false,
      "require_login_to_view": false,
      "watermark_images": false,
      "disable_right_click": false,
      "track_visitor_analytics": true,
      "allow_social_sharing": true,
      "show_contact_info": true,
      "allow_downloads": false
    }'::jsonb
    WHERE privacy_settings = '{}'::jsonb OR privacy_settings IS NULL
    """

    # Set default social integration settings
    execute """
    UPDATE portfolios
    SET social_integration = '{
      "enabled_platforms": [],
      "auto_sync": false,
      "last_sync_at": null,
      "sync_frequency": "daily",
      "show_follower_counts": true,
      "show_recent_posts": true,
      "max_posts_per_platform": 3
    }'::jsonb
    WHERE social_integration = '{}'::jsonb OR social_integration IS NULL
    """

    # Set default contact info
    execute """
    UPDATE portfolios
    SET contact_info = '{
      "email": null,
      "phone": null,
      "website": null,
      "location": null,
      "linkedin": null,
      "twitter": null,
      "instagram": null,
      "github": null,
      "show_email": false,
      "show_phone": false,
      "show_location": false
    }'::jsonb
    WHERE contact_info = '{}'::jsonb OR contact_info IS NULL
    """

    # Set default access request settings
    execute """
    UPDATE portfolios
    SET access_request_settings = '{
      "enabled": true,
      "require_message": true,
      "auto_approve_connections": false,
      "notification_email": null,
      "custom_message": "Please provide a brief introduction and reason for accessing this portfolio."
    }'::jsonb
    WHERE access_request_settings = '{}'::jsonb OR access_request_settings IS NULL
    """
  end

  def down do
    # Reset to empty JSON objects
    execute "UPDATE portfolios SET privacy_settings = '{}'::jsonb"
    execute "UPDATE portfolios SET social_integration = '{}'::jsonb"
    execute "UPDATE portfolios SET contact_info = '{}'::jsonb"
    execute "UPDATE portfolios SET access_request_settings = '{}'::jsonb"
  end
end
