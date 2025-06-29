# IMMEDIATE FIX for lib/frestyl/templates/template_registry.ex
# This provides the missing functions to resolve compile errors

defmodule Frestyl.Templates.TemplateRegistry do
  @moduledoc """
  Template registry that provides unified access to all template systems.
  This is a transitional implementation to fix compile errors.
  """

  alias Frestyl.Portfolios.PortfolioTemplates
  alias Frestyl.Features.FeatureGate

  @doc """
  Get all templates with access information for a user
  """
  def get_all_templates_with_access(user) do
    %{
      portfolio: get_portfolio_templates_with_access(user),
      story: get_story_templates_with_access(user),
      lab: get_lab_templates_with_access(user)
    }
  end

  @doc """
  Get full template configuration merged from all systems
  """
  def get_template_full_config(template_id, template_type \\ :portfolio) do
    base_config = get_base_template_config(template_id, template_type)
    portfolio_config = get_portfolio_config_safe(template_id)
    story_config = get_story_config_safe(template_id)

    deep_merge_all([base_config, portfolio_config, story_config])
  end

  # ============================================================================
  # MISSING FUNCTIONS - IMPLEMENTATION
  # ============================================================================

  def get_portfolio_templates_with_access(user) do
    try do
      PortfolioTemplates.available_templates()
      |> Enum.map(fn {key, config} ->
        access_status = if FeatureGate.can_access_template?(user, key), do: :accessible, else: :locked
        {key, Map.put(config, :access_status, access_status)}
      end)
      |> Enum.into(%{})
    rescue
      _ ->
        # Fallback templates if PortfolioTemplates module fails
        get_fallback_portfolio_templates(user)
    end
  end

  def get_story_templates_with_access(user) do
    # Story templates - simplified implementation
    user_tier = FeatureGate.get_user_tier(user)
    has_creator_access = user_tier in [:creator, :professional, :enterprise]
    access_status = if has_creator_access, do: :accessible, else: :locked

    %{
      "story_personal_hero_journey" => %{
        name: "Hero's Journey Story",
        category: "story",
        access_status: access_status
      },
      "story_professional_chronological" => %{
        name: "Career Timeline Story",
        category: "story",
        access_status: access_status
      }
    }
  end

  def get_lab_templates_with_access(user) do
    # Lab templates - simplified implementation for now
    user_tier = FeatureGate.get_user_tier(user)

    if user_tier in [:creator, :professional, :enterprise] do
      %{
        "lab_experimental_3d" => %{
          name: "3D Experimental",
          category: "lab",
          access_status: :accessible,
          stability: "alpha"
        }
      }
    else
      %{}
    end
  end

  def get_base_template_config(template_id, template_type) do
    case template_type do
      :portfolio -> get_portfolio_config_safe(template_id)
      :story -> get_story_config_safe(template_id)
      :lab -> get_lab_config_safe(template_id)
      _ -> %{}
    end
  end

  def deep_merge_all(configs) when is_list(configs) do
    configs
    |> Enum.reduce(%{}, fn config, acc ->
      deep_merge_maps(acc, config)
    end)
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp get_portfolio_config_safe(template_key) do
    try do
      PortfolioTemplates.get_template_config(template_key)
    rescue
      _ ->
        get_fallback_config(template_key)
    end
  end

  defp get_story_config_safe(template_key) do
    # Extract story configuration if template_key contains "story_"
    if String.starts_with?(template_key, "story_") do
      %{
        multimedia_blocks: true,
        narrative_structure: true,
        story_enhancements: []
      }
    else
      %{}
    end
  end

  defp get_lab_config_safe(template_key) do
    # Extract lab configuration if template_key contains "lab_"
    if String.starts_with?(template_key, "lab_") do
      %{
        experimental_features: true,
        stability_warning: true,
        lab_enhancements: []
      }
    else
      %{}
    end
  end

  defp deep_merge_maps(left, right) when is_map(left) and is_map(right) do
    Map.merge(left, right, fn _k, v1, v2 ->
      if is_map(v1) and is_map(v2) do
        deep_merge_maps(v1, v2)
      else
        v2  # Right side takes precedence
      end
    end)
  end
  defp deep_merge_maps(_left, right), do: right

  defp get_fallback_config(template_key) do
    %{
      "name" => String.capitalize(to_string(template_key)),
      "category" => "general",
      "primary_color" => "#3b82f6",
      "secondary_color" => "#64748b",
      "accent_color" => "#f59e0b",
      "layout" => "dashboard"
    }
  end

  defp get_fallback_portfolio_templates(user) do
    user_tier = FeatureGate.get_user_tier(user)

    base_templates = %{
      "executive" => %{
        name: "Executive",
        category: "professional",
        subscription_tier: :personal,
        access_status: :accessible
      },
      "minimalist" => %{
        name: "Minimalist",
        category: "minimal",
        subscription_tier: :personal,
        access_status: :accessible
      },
      "developer" => %{
        name: "Developer",
        category: "technical",
        subscription_tier: :personal,
        access_status: :accessible
      }
    }

    # Add premium templates based on user tier
    premium_templates = case user_tier do
      tier when tier in [:creator, :professional, :enterprise] ->
        %{
          "audio_producer" => %{
            name: "Audio Producer",
            category: "audio",
            subscription_tier: :creator,
            access_status: :accessible
          },
          "photographer_portrait" => %{
            name: "Portrait Photographer",
            category: "gallery",
            subscription_tier: :creator,
            access_status: :accessible
          }
        }
      _ ->
        %{
          "audio_producer" => %{
            name: "Audio Producer",
            category: "audio",
            subscription_tier: :creator,
            access_status: :locked
          },
          "photographer_portrait" => %{
            name: "Portrait Photographer",
            category: "gallery",
            subscription_tier: :creator,
            access_status: :locked
          }
        }
    end

    Map.merge(base_templates, premium_templates)
  end
end
