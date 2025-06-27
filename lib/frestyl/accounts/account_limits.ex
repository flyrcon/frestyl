defmodule Frestyl.Accounts.AccountLimits do
  @moduledoc "Dynamic limits based on subscription tier"

  def get_story_limits(account) do
    base_limits = get_base_limits(account.subscription_tier)

    %{
      max_stories: base_limits.max_stories,
      storage_quota_gb: base_limits.storage_quota_gb,
      max_collaborators: base_limits.max_collaborators,
      max_chapters_per_story: base_limits.max_chapters_per_story,
      video_recording_minutes: base_limits.video_recording_minutes,
      audio_recording_hours: base_limits.audio_recording_hours,

      # Story-type specific limits
      story_type_access: base_limits.story_type_access,
      advanced_templates: base_limits.advanced_templates,
      custom_branding: base_limits.custom_branding,
      analytics_depth: base_limits.analytics_depth,

      # Collaboration limits
      cross_account_sharing: base_limits.cross_account_sharing,
      guest_access_enabled: base_limits.guest_access_enabled,
      real_time_collaboration: base_limits.real_time_collaboration
    }
  end

  defp get_base_limits(:personal) do
    %{
      max_stories: 3,
      storage_quota_gb: 1,
      max_collaborators: 2,
      max_chapters_per_story: 10,
      video_recording_minutes: 30,
      audio_recording_hours: 2,
      story_type_access: [:personal_narrative, :professional_showcase],
      advanced_templates: false,
      custom_branding: false,
      analytics_depth: :basic,
      cross_account_sharing: :view_only,
      guest_access_enabled: false,
      real_time_collaboration: false,
      service_booking_enabled: false,
      max_services: 0,
      service_calendar_integration: false,
      service_analytics_enabled: false,
      max_booking_amount_cents: 0,
      platform_fee_percentage: Decimal.new("0.00")
    }
  end

  defp get_base_limits(:creator) do
    %{
      max_stories: 25,
      storage_quota_gb: 10,
      max_collaborators: 10,
      max_chapters_per_story: 50,
      video_recording_minutes: 300,
      audio_recording_hours: 20,
      story_type_access: [:all],
      advanced_templates: true,
      custom_branding: :basic,
      analytics_depth: :standard,
      cross_account_sharing: :comment_and_suggest,
      guest_access_enabled: true,
      real_time_collaboration: :limited,
      service_booking_enabled: true,
      max_services: 10,
      service_calendar_integration: true,
      service_analytics_enabled: true,
      max_booking_amount_cents: 50000, # $500 max per booking
      platform_fee_percentage: Decimal.new("5.0") # 5% platform fee
    }
  end

  defp get_base_limits(:professional) do
    %{
      max_stories: :unlimited,
      storage_quota_gb: 100,
      max_collaborators: :unlimited,
      max_chapters_per_story: :unlimited,
      video_recording_minutes: :unlimited,
      audio_recording_hours: :unlimited,
      story_type_access: [:all],
      advanced_templates: true,
      custom_branding: :full,
      analytics_depth: :advanced,
      cross_account_sharing: :full_edit,
      guest_access_enabled: true,
      real_time_collaboration: :full,
      service_booking_enabled: true,
      max_services: :unlimited,
      service_calendar_integration: true,
      service_analytics_enabled: true,
      max_booking_amount_cents: :unlimited,
      platform_fee_percentage: Decimal.new("3.0") # 3% platform fee
    }
  end

  defp get_base_limits(:enterprise) do
    get_base_limits(:professional)
    |> Map.merge(%{
      storage_quota_gb: :unlimited,
      custom_branding: :white_label,
      analytics_depth: :enterprise,
      sso_enabled: true,
      api_access: true,
      dedicated_support: true,
      platform_fee_percentage: Decimal.new("1.5") # 1.5% platform fee
    })
  end
end
