# lib/frestyl/portfolios/content_block_builder.ex
defmodule Frestyl.Portfolios.ContentBlockBuilder do
  @moduledoc """
  Builder for creating enhanced content blocks with monetization and streaming.
  Replaces the existing section content system.
  """

  alias Frestyl.Portfolios.{ContentBlock, MonetizationSetting, StreamingIntegration}
  alias Frestyl.Repo

  def create_experience_block(section_id, job_data, options \\ %{}) do
    content_data = %{
      "company" => job_data["company"],
      "title" => job_data["title"],
      "start_date" => job_data["start_date"],
      "end_date" => job_data["end_date"],
      "location" => job_data["location"],
      "responsibilities" => [],
      "achievements" => [],
      "technologies" => job_data["technologies"] || []
    }

    monetization_config = if options[:enable_consulting] do
      %{
        "hourly_rate" => options[:hourly_rate],
        "consultation_available" => true,
        "booking_enabled" => true
      }
    else
      %{}
    end

    streaming_config = if options[:enable_demos] do
      %{
        "demo_sessions_available" => true,
        "session_duration" => 30,
        "requires_booking" => true
      }
    else
      %{}
    end

    %ContentBlock{}
    |> ContentBlock.changeset(%{
      block_uuid: Ecto.UUID.generate(),
      block_type: :experience_entry,
      position: options[:position] || 0,
      portfolio_section_id: section_id,
      content_data: content_data,
      monetization_config: monetization_config,
      streaming_config: streaming_config,
      media_limit: options[:media_limit] || 5
    })
    |> Repo.insert()
  end

  def create_responsibility_block(experience_block_id, responsibility_text, options \\ %{}) do
    content_data = %{
      "text" => responsibility_text,
      "impact_metrics" => options[:metrics] || [],
      "supporting_evidence" => options[:evidence] || []
    }

    %ContentBlock{}
    |> ContentBlock.changeset(%{
      block_uuid: Ecto.UUID.generate(),
      block_type: :responsibility,
      position: options[:position] || 0,
      portfolio_section_id: experience_block_id,
      content_data: content_data,
      media_limit: options[:media_limit] || 2
    })
    |> Repo.insert()
  end

  def create_skill_block(section_id, skill_data, options \\ %{}) do
    content_data = %{
      "name" => skill_data["name"],
      "proficiency" => skill_data["proficiency"],
      "years_experience" => skill_data["years_experience"],
      "certifications" => skill_data["certifications"] || [],
      "portfolio_examples" => skill_data["examples"] || []
    }

    monetization_config = if options[:enable_services] do
      %{
        "hourly_rate" => options[:hourly_rate],
        "project_rate" => options[:project_rate],
        "service_packages" => options[:packages] || []
      }
    else
      %{}
    end

    %ContentBlock{}
    |> ContentBlock.changeset(%{
      block_uuid: Ecto.UUID.generate(),
      block_type: :skill_item,
      position: options[:position] || 0,
      portfolio_section_id: section_id,
      content_data: content_data,
      monetization_config: monetization_config,
      media_limit: options[:media_limit] || 3
    })
    |> Repo.insert()
  end

  def create_service_package_block(section_id, package_data, options \\ %{}) do
    content_data = %{
      "name" => package_data["name"],
      "description" => package_data["description"],
      "deliverables" => package_data["deliverables"] || [],
      "timeline" => package_data["timeline"],
      "included_features" => package_data["features"] || []
    }

    monetization_config = %{
      "pricing_type" => "fixed_package",
      "base_price" => package_data["price"],
      "currency" => package_data["currency"] || "USD",
      "payment_schedule" => package_data["payment_schedule"] || "upfront",
      "booking_enabled" => true,
      "requires_consultation" => package_data["requires_consultation"] || false
    }

    streaming_config = if options[:include_sessions] do
      %{
        "included_sessions" => package_data["included_sessions"] || 0,
        "session_duration" => package_data["session_duration"] || 60,
        "followup_included" => package_data["followup_included"] || false
      }
    else
      %{}
    end

    block_result = %ContentBlock{}
    |> ContentBlock.changeset(%{
      block_uuid: Ecto.UUID.generate(),
      block_type: :service_package,
      position: options[:position] || 0,
      portfolio_section_id: section_id,
      content_data: content_data,
      monetization_config: monetization_config,
      streaming_config: streaming_config,
      is_premium_feature: true,
      requires_subscription_tier: "premium"
    })
    |> Repo.insert()

    case block_result do
      {:ok, block} ->
        # Create monetization setting
        create_monetization_setting(block, package_data)
        {:ok, block}
      error ->
        error
    end
  end

  def create_booking_widget_block(section_id, booking_config, options \\ %{}) do
    content_data = %{
      "title" => booking_config["title"] || "Book a Session",
      "description" => booking_config["description"],
      "session_types" => booking_config["session_types"] || [],
      "availability_notice" => booking_config["availability_notice"]
    }

    streaming_config = %{
      "integration_type" => "calendar_booking",
      "calendar_provider" => booking_config["calendar_provider"] || "calendly",
      "booking_url" => booking_config["booking_url"],
      "auto_streaming_setup" => booking_config["auto_streaming"] || false,
      "confirmation_flow" => booking_config["confirmation_flow"] || "automatic"
    }

    %ContentBlock{}
    |> ContentBlock.changeset(%{
      block_uuid: Ecto.UUID.generate(),
      block_type: :booking_widget,
      position: options[:position] || 0,
      portfolio_section_id: section_id,
      content_data: content_data,
      streaming_config: streaming_config,
      is_premium_feature: true,
      requires_subscription_tier: "basic"
    })
    |> Repo.insert()
  end

  def create_live_session_block(section_id, session_config, options \\ %{}) do
    content_data = %{
      "session_title" => session_config["title"],
      "description" => session_config["description"],
      "target_audience" => session_config["audience"],
      "learning_outcomes" => session_config["outcomes"] || [],
      "prerequisites" => session_config["prerequisites"] || []
    }

    streaming_config = %{
      "session_type" => session_config["type"] || "interactive_demo",
      "duration_minutes" => session_config["duration"] || 60,
      "max_participants" => session_config["max_participants"] || 10,
      "recording_enabled" => session_config["recording"] || true,
      "interactive_features" => session_config["interactive"] || ["chat", "qa"],
      "requires_registration" => session_config["registration"] || true
    }

    monetization_config = if session_config["paid"] do
      %{
        "session_fee" => session_config["fee"],
        "currency" => session_config["currency"] || "USD",
        "refund_policy" => session_config["refund_policy"],
        "group_discounts" => session_config["group_discounts"] || false
      }
    else
      %{}
    end

    block_result = %ContentBlock{}
    |> ContentBlock.changeset(%{
      block_uuid: Ecto.UUID.generate(),
      block_type: :live_session_embed,
      position: options[:position] || 0,
      portfolio_section_id: section_id,
      content_data: content_data,
      streaming_config: streaming_config,
      monetization_config: monetization_config,
      is_premium_feature: true,
      requires_subscription_tier: "creator"
    })
    |> Repo.insert()

    case block_result do
      {:ok, block} ->
        # Create streaming integration
        create_streaming_integration(block, session_config)
        {:ok, block}
      error ->
        error
    end
  end

  # Helper functions for creating related records

  defp create_monetization_setting(content_block, config) do
    %MonetizationSetting{}
    |> MonetizationSetting.changeset(%{
      setting_type: :service_package,
      pricing_data: %{
        "amount" => config["price"],
        "currency" => config["currency"] || "USD"
      },
      booking_config: %{
        "requires_consultation" => config["requires_consultation"] || false,
        "advance_booking_days" => config["advance_booking"] || 7
      },
      content_block_id: content_block.id,
      portfolio_id: content_block.portfolio_section.portfolio_id
    })
    |> Repo.insert()
  end

  defp create_streaming_integration(content_block, config) do
    %StreamingIntegration{}
    |> StreamingIntegration.changeset(%{
      integration_type: :live_session_embed,
      streaming_config: %{
        "platform" => config["platform"] || "native",
        "quality_settings" => config["quality"] || "1080p",
        "backup_recording" => config["backup"] || true
      },
      scheduling_config: %{
        "timezone" => config["timezone"] || "UTC",
        "buffer_minutes" => config["buffer"] || 15,
        "cancellation_policy" => config["cancellation"] || "24_hours"
      },
      session_duration_minutes: config["duration"] || 60,
      max_participants: config["max_participants"] || 10,
      requires_payment: config["paid"] || false,
      content_block_id: content_block.id,
      portfolio_id: content_block.portfolio_section.portfolio_id
    })
    |> Repo.insert()
  end
end
