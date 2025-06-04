# lib/frestyl/studio/content_strategy.ex
defmodule Frestyl.Studio.ContentStrategy do
  @moduledoc """
  Handles content protection, export credits, and platform engagement strategy.
  """

  alias Frestyl.Accounts
  alias Frestyl.Studio.AudioEngineConfig

  @content_protection_levels %{
    draft: %{
      watermarked: true,
      quality_limited: true,
      platform_only: true,
      level: :draft
    },
    preview: %{
      watermarked: true,
      quality_limited: false,
      platform_only: false,
      level: :preview
    },
    published: %{
      watermarked: false,
      quality_limited: false,
      platform_only: false,
      level: :published
    }
  }

  @export_requirements %{
    free: %{
      credits_per_month: 3,
      quality_limit: "256kbps",
      watermark_required: true,
      attribution_required: true
    },
    premium: %{
      credits_per_month: 25,
      quality_limit: "lossless",
      watermark_required: false,
      attribution_required: false
    },
    pro: %{
      credits_per_month: :unlimited,
      quality_limit: "stems_available",
      watermark_required: false,
      attribution_required: false
    }
  }

  def get_protection_settings(tier) do
    Map.get(@content_protection_levels, :draft)
    |> Map.put(:tier, tier)
  end

  def check_export_permission(user, export_params, tier_config) do
    tier = AudioEngineConfig.get_user_tier(user)
    requirements = Map.get(@export_requirements, tier)

    with :ok <- check_export_credits(user, requirements),
         :ok <- validate_export_params(export_params, requirements) do

      export_settings = %{
        scenario: export_params[:scenario] || :download,
        quality_overrides: get_quality_overrides(requirements, export_params),
        watermark_required: requirements.watermark_required,
        attribution_required: requirements.attribution_required
      }

      {:ok, export_settings}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def deduct_export_credits(user, export_settings) do
    tier = AudioEngineConfig.get_user_tier(user)
    requirements = Map.get(@export_requirements, tier)

    if requirements.credits_per_month != :unlimited do
      # In a real implementation, you'd track credits in the database
      # For now, we'll just log the deduction
      Logger.info("Deducting 1 export credit for user #{user.id}")
    end
  end

  def get_export_requirements(tier) do
    Map.get(@export_requirements, tier, @export_requirements.free)
  end

  def get_user_monthly_credits(user_id) do
    # In real implementation, track in database with monthly reset
    # For now, return tier limits
    user = Frestyl.Accounts.get_user!(user_id)
    tier = Frestyl.Studio.AudioEngineConfig.get_user_tier(user)
    requirements = get_export_requirements(tier)

    case requirements.credits_per_month do
      :unlimited -> :unlimited
      credits -> credits
    end
  end

  def deduct_export_credits(user, _export_settings) do
    # In real implementation, this would:
    # 1. Check current month's usage
    # 2. Deduct credits from user's allowance
    # 3. Send notifications if credits are low
    # 4. Trigger upgrade prompts when credits exhausted

    Logger.info("Export credit deducted for user #{user.id}")
    :ok
  end

  defp check_export_credits(user, requirements) do
    if requirements.credits_per_month == :unlimited do
      :ok
    else
      # Check user's remaining credits for the month
      # This is simplified - you'd implement actual credit tracking
      current_credits = get_user_monthly_credits(user)

      if current_credits > 0 do
        :ok
      else
        {:error, :insufficient_credits}
      end
    end
  end

  defp validate_export_params(export_params, requirements) do
    # Validate export parameters against tier requirements
    requested_quality = export_params[:quality] || "standard"

    case {requested_quality, requirements.quality_limit} do
      {_, "stems_available"} -> :ok
      {"lossless", "lossless"} -> :ok
      {"lossless", _} -> {:error, :quality_not_available}
      {_, _} -> :ok
    end
  end

  defp get_quality_overrides(requirements, export_params) do
    base_overrides = case requirements.quality_limit do
      "256kbps" -> %{bitrate: 256, format: "mp3"}
      "lossless" -> %{bitrate: :lossless, format: "wav"}
      "stems_available" -> %{stems: true, format: "wav"}
      _ -> %{}
    end

    Map.merge(base_overrides, export_params[:quality_overrides] || %{})
  end

end
