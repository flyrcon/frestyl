# lib/frestyl/teams/rating_dimension_config.ex
defmodule Frestyl.Teams.RatingDimensionConfig do
  @moduledoc """
  Configuration module for rating dimensions based on organization type and context.
  Provides the available dimensions for the vibe rating system.
  """

  @doc """
  Gets all available rating dimension categories.
  """
  def get_all_categories do
    %{
      primary_dimensions: get_primary_dimensions(),
      secondary_dimensions: get_secondary_dimensions(),
      organization_types: get_organization_types()
    }
  end

  @doc """
  Gets the default secondary dimension for an organization type.
  """
  def get_default_secondary_dimension(organization_type) do
    case organization_type do
      "academic" -> "collaboration_effectiveness"
      "creative" -> "innovation_level"
      "business" -> "commercial_viability"
      "technical" -> "technical_execution"
      _ -> "collaboration_effectiveness"
    end
  end

  @doc """
  Gets dimension configuration for a specific context.
  """
  def get_dimension_config(primary_dimension, secondary_dimension) do
    %{
      primary: get_dimension_details(primary_dimension),
      secondary: get_dimension_details(secondary_dimension)
    }
  end

  @doc """
  Gets the rating interface configuration for given dimensions.
  """
  def get_interface_config(primary_dimension, secondary_dimension, context \\ "peer_review") do
    %{
      primary_dimension: %{
        name: format_dimension_name(primary_dimension),
        description: get_dimension_description(primary_dimension)
      },
      secondary_dimension: %{
        name: format_dimension_name(secondary_dimension),
        description: get_dimension_description(secondary_dimension)
      },
      context: context,
      gradient_config: get_gradient_config(primary_dimension, secondary_dimension)
    }
  end

  # Private functions

  defp get_primary_dimensions do
    [
      %{
        key: "quality",
        name: "Quality",
        description: "Overall quality of work",
        is_default: true
      },
      %{
        key: "content_quality",
        name: "Content Quality",
        description: "How well-written, clear, and engaging is the content?"
      },
      %{
        key: "audio_quality",
        name: "Audio Quality",
        description: "How clear and professional is the audio production?"
      },
      %{
        key: "production_quality",
        name: "Production Quality",
        description: "How well-produced and polished is the work?"
      },
      %{
        key: "code_quality",
        name: "Code Quality",
        description: "How clean, efficient, and maintainable is the code?"
      },
      %{
        key: "aesthetic_quality",
        name: "Aesthetic Quality",
        description: "How visually appealing and well-designed is it?"
      }
    ]
  end

  defp get_secondary_dimensions do
    [
      %{
        key: "collaboration_effectiveness",
        name: "Collaboration Effectiveness",
        description: "How well do they work with others and contribute to team success?",
        organization_types: ["academic", "general"]
      },
      %{
        key: "innovation_level",
        name: "Innovation Level",
        description: "How creative and original is their approach?",
        organization_types: ["creative", "design"]
      },
      %{
        key: "commercial_viability",
        name: "Commercial Viability",
        description: "How valuable is this in a business context?",
        organization_types: ["business", "entrepreneurship"]
      },
      %{
        key: "technical_execution",
        name: "Technical Execution",
        description: "How technically skilled is the implementation?",
        organization_types: ["technical", "engineering"]
      },
      %{
        key: "communication_clarity",
        name: "Communication Clarity",
        description: "How clearly do they communicate ideas and feedback?"
      },
      %{
        key: "effort_level",
        name: "Effort Level",
        description: "How much effort and care was put into this work?"
      },
      %{
        key: "originality",
        name: "Originality",
        description: "How unique and creative is the contribution?"
      },
      %{
        key: "usability",
        name: "Usability",
        description: "How user-friendly and intuitive is the design?"
      }
    ]
  end

  defp get_organization_types do
    [
      %{
        key: "academic",
        name: "Academic",
        description: "University courses, research projects",
        default_secondary: "collaboration_effectiveness",
        color: "blue"
      },
      %{
        key: "creative",
        name: "Creative",
        description: "Art, design, creative writing projects",
        default_secondary: "innovation_level",
        color: "green"
      },
      %{
        key: "business",
        name: "Business",
        description: "Entrepreneurship, business development",
        default_secondary: "commercial_viability",
        color: "purple"
      },
      %{
        key: "technical",
        name: "Technical",
        description: "Software development, engineering",
        default_secondary: "technical_execution",
        color: "orange"
      }
    ]
  end

  defp get_dimension_details(dimension_key) do
    all_dimensions = get_primary_dimensions() ++ get_secondary_dimensions()

    Enum.find(all_dimensions, fn dim -> dim.key == to_string(dimension_key) end) ||
      %{
        key: to_string(dimension_key),
        name: format_dimension_name(dimension_key),
        description: "Rate this aspect of their work"
      }
  end

  defp format_dimension_name(dimension_key) do
    dimension_key
    |> to_string()
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp get_dimension_description(dimension_key) do
    descriptions = %{
      "quality" => "Overall quality and craftsmanship of the work",
      "content_quality" => "How well-written, clear, and engaging is the content?",
      "audio_quality" => "How clear and professional is the audio production?",
      "production_quality" => "How well-produced and polished is the work?",
      "code_quality" => "How clean, efficient, and maintainable is the code?",
      "aesthetic_quality" => "How visually appealing and well-designed is it?",
      "collaboration_effectiveness" => "How well do they work with others and contribute to team success?",
      "innovation_level" => "How creative and original is their approach?",
      "commercial_viability" => "How valuable is this in a business context?",
      "technical_execution" => "How technically skilled is the implementation?",
      "communication_clarity" => "How clearly do they communicate ideas and feedback?",
      "effort_level" => "How much effort and care was put into this work?",
      "originality" => "How unique and creative is the contribution?",
      "usability" => "How user-friendly and intuitive is the design?"
    }

    Map.get(descriptions, to_string(dimension_key), "Rate this aspect of their work")
  end

  defp get_gradient_config(primary_dimension, secondary_dimension) do
    %{
      horizontal: %{
        dimension: primary_dimension,
        colors: ["#ef4444", "#eab308", "#22c55e"], # Red -> Yellow -> Green
        labels: ["Poor", "Good", "Excellent"]
      },
      vertical: %{
        dimension: secondary_dimension,
        colors: ["#8b5cf6", "#06b6d4"], # Purple -> Cyan
        labels: get_vertical_labels(secondary_dimension)
      }
    }
  end

  defp get_vertical_labels(secondary_dimension) do
    case to_string(secondary_dimension) do
      "collaboration_effectiveness" -> ["Poor Collaboration", "Excellent Collaboration"]
      "innovation_level" -> ["Traditional Approach", "Highly Innovative"]
      "commercial_viability" -> ["Low Commercial Value", "High Commercial Value"]
      "technical_execution" -> ["Basic Implementation", "Advanced Implementation"]
      "communication_clarity" -> ["Unclear Communication", "Crystal Clear"]
      "effort_level" -> ["Minimal Effort", "Maximum Effort"]
      _ -> ["Low", "High"]
    end
  end
end
