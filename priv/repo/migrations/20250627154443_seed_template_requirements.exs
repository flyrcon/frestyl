# Migration 8: Seed Template Requirements Data
# priv/repo/migrations/20250627_008_seed_template_requirements.exs

defmodule Frestyl.Repo.Migrations.SeedTemplateRequirements do
  use Ecto.Migration

  def up do
    # Insert template subscription requirements
    execute """
    INSERT INTO template_subscription_requirements (template_theme, template_category, minimum_tier, premium_features, feature_limits, inserted_at, updated_at) VALUES
    -- Personal tier templates
    ('executive', 'professional', 'personal', ARRAY[]::text[], '{}', NOW(), NOW()),
    ('minimalist', 'minimal', 'personal', ARRAY[]::text[], '{}', NOW(), NOW()),

    -- Creator tier templates (Audio & Gallery)
    ('audio_producer', 'audio', 'creator', ARRAY['waveform_player', 'track_listing'], '{"max_tracks": 20}', NOW(), NOW()),
    ('podcast_host', 'audio', 'creator', ARRAY['episode_grid', 'subscribe_buttons'], '{"max_episodes": 50}', NOW(), NOW()),
    ('voice_artist', 'audio', 'creator', ARRAY['demo_reels', 'client_testimonials'], '{"max_demos": 10}', NOW(), NOW()),
    ('photographer_portrait', 'gallery', 'creator', ARRAY['lightbox_gallery', 'client_booking'], '{"max_images": 200}', NOW(), NOW()),
    ('photographer_wedding', 'gallery', 'creator', ARRAY['gallery_collections', 'client_proofing'], '{"max_galleries": 10}', NOW(), NOW()),
    ('visual_artist', 'gallery', 'creator', ARRAY['portfolio_showcase', 'commission_info'], '{"max_artworks": 100}', NOW(), NOW()),

    -- Professional tier templates (Service & Social)
    ('life_coach', 'service', 'professional', ARRAY['service_booking', 'client_portal'], '{}', NOW(), NOW()),
    ('fitness_trainer', 'service', 'professional', ARRAY['workout_plans', 'progress_tracking'], '{}', NOW(), NOW()),
    ('business_coach', 'service', 'professional', ARRAY['consultation_booking', 'success_metrics'], '{}', NOW(), NOW()),
    ('data_scientist', 'dashboard', 'professional', ARRAY['chart_integration', 'code_display'], '{}', NOW(), NOW()),
    ('content_creator', 'social', 'professional', ARRAY['social_metrics', 'brand_partnerships'], '{}', NOW(), NOW()),
    ('influencer_lifestyle', 'social', 'professional', ARRAY['engagement_tracking', 'collaboration_showcase'], '{}', NOW(), NOW())
    """

    # Insert template section types
    execute """
    INSERT INTO template_section_types (template_theme, section_type, display_name, description, default_config, required_subscription_tier, inserted_at, updated_at) VALUES
    -- Audio template sections
    ('audio_producer', 'track_showcase', 'Track Showcase', 'Display music tracks with players', '{"layout": "grid", "player_style": "waveform"}', 'creator', NOW(), NOW()),
    ('audio_producer', 'discography', 'Discography', 'Album and release history', '{"layout": "timeline", "show_covers": true}', 'creator', NOW(), NOW()),
    ('podcast_host', 'episode_grid', 'Episode Grid', 'Podcast episode showcase', '{"layout": "card_grid", "episodes_per_row": 3}', 'creator', NOW(), NOW()),
    ('podcast_host', 'guest_highlights', 'Guest Highlights', 'Featured podcast guests', '{"layout": "carousel", "auto_rotate": true}', 'creator', NOW(), NOW()),

    -- Gallery template sections
    ('photographer_portrait', 'photo_gallery', 'Photo Gallery', 'Image showcase with lightbox', '{"layout": "masonry", "lightbox": true}', 'creator', NOW(), NOW()),
    ('photographer_portrait', 'session_types', 'Session Types', 'Photography service offerings', '{"layout": "cards", "show_pricing": true}', 'creator', NOW(), NOW()),
    ('visual_artist', 'artwork_showcase', 'Artwork Showcase', 'Art portfolio display', '{"layout": "grid", "zoom_enabled": true}', 'creator', NOW(), NOW()),

    -- Service template sections
    ('life_coach', 'service_packages', 'Service Packages', 'Coaching service offerings', '{"layout": "pricing_table", "highlight_popular": true}', 'professional', NOW(), NOW()),
    ('life_coach', 'testimonials', 'Client Testimonials', 'Success stories and reviews', '{"layout": "carousel", "show_photos": true}', 'professional', NOW(), NOW()),
    ('fitness_trainer', 'workout_programs', 'Workout Programs', 'Training program showcase', '{"layout": "cards", "difficulty_badges": true}', 'professional', NOW(), NOW()),

    -- Dashboard template sections
    ('data_scientist', 'project_showcase', 'Project Showcase', 'Data science project display', '{"layout": "case_studies", "show_code": true}', 'professional', NOW(), NOW()),
    ('data_scientist', 'skills_matrix', 'Skills Matrix', 'Technical skills visualization', '{"layout": "chart", "chart_type": "radar"}', 'professional', NOW(), NOW()),

    -- Social template sections
    ('content_creator', 'social_feed', 'Social Media Feed', 'Multi-platform content display', '{"platforms": ["instagram", "youtube", "tiktok"], "auto_sync": true}', 'professional', NOW(), NOW()),
    ('content_creator', 'engagement_metrics', 'Engagement Metrics', 'Social media statistics', '{"metrics": ["followers", "engagement_rate", "reach"], "update_frequency": "daily"}', 'professional', NOW(), NOW())
    """
  end

  def down do
    execute "DELETE FROM template_section_types"
    execute "DELETE FROM template_subscription_requirements"
  end
end
