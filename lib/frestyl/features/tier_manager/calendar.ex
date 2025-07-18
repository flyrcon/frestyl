defmodule Frestyl.Features.TierManager.Calendar do
  @moduledoc """
  Calendar-specific tier management functions
  """

  alias Frestyl.Features.TierManager

  def get_calendar_features(tier) do
    normalized = TierManager.normalize_tier(tier)

    case normalized do
      "personal" -> personal_calendar_features()
      "creator" -> creator_calendar_features()
      "professional" -> professional_calendar_features()
      "enterprise" -> enterprise_calendar_features()
      _ -> personal_calendar_features()
    end
  end

  defp personal_calendar_features do
    %{
      calendar_view: true,
      calendar_create: false,
      calendar_edit: :limited, # Only channel events they organize
      calendar_delete: false,
      calendar_sync: false,
      calendar_integrations: 0,
      calendar_analytics: false,
      calendar_attendee_limit: 0,
      calendar_paid_events: false,
      calendar_meeting_links: false,
      calendar_recurring: false,
      visible_event_types: ["channel_event"],
      visibility_options: ["channel"]
    }
  end

  defp creator_calendar_features do
    %{
      calendar_view: true,
      calendar_create: true,
      calendar_edit: :own_and_account,
      calendar_delete: :own_only,
      calendar_sync: true,
      calendar_integrations: 3,
      calendar_analytics: :basic,
      calendar_attendee_limit: 25,
      calendar_paid_events: true,
      calendar_meeting_links: true,
      calendar_recurring: true,
      monthly_event_limit: 50,
      visible_event_types: ["personal", "service_booking", "broadcast", "channel_event"],
      visibility_options: ["private", "channel", "account"]
    }
  end

  defp professional_calendar_features do
    %{
      calendar_view: true,
      calendar_create: true,
      calendar_edit: :full_account,
      calendar_delete: :account_admin,
      calendar_sync: true,
      calendar_integrations: :unlimited,
      calendar_analytics: :advanced,
      calendar_attendee_limit: 100,
      calendar_paid_events: true,
      calendar_meeting_links: true,
      calendar_recurring: true,
      monthly_event_limit: :unlimited,
      visible_event_types: ["personal", "service_booking", "broadcast", "channel_event", "collaboration"],
      visibility_options: ["private", "channel", "account", "public"]
    }
  end

  defp enterprise_calendar_features do
    professional_calendar_features()
    |> Map.merge(%{
      calendar_attendee_limit: :unlimited,
      calendar_white_label: true,
      calendar_api_access: true,
      calendar_custom_domains: true,
      calendar_advanced_security: true
    })
  end
end
