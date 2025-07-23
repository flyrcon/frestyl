# File: lib/frestyl/portfolios/collaboration_section_manager.ex

defmodule Frestyl.Portfolios.CollaborationSectionManager do
  @moduledoc """
  Manages the :collaborations portfolio section with real-time campaign data.
  """

  alias Frestyl.DataCampaigns
  alias Frestyl.Portfolios

  @doc """
  Updates collaboration section content with latest campaign data.
  """
  def update_collaboration_section(portfolio_id, user_id) do
    # Get user's completed collaborative works
    collaborations = DataCampaigns.get_user_portfolio_collaborations(user_id)

    # Find or create collaborations section
    case get_or_create_collaboration_section(portfolio_id) do
      {:ok, section} ->
        updated_content = build_collaboration_content(collaborations, section.content)

        Portfolios.update_portfolio_section(section, %{content: updated_content})

      error -> error
    end
  end

  @doc """
  Creates collaboration showcase blocks for portfolio display.
  """
  def create_collaboration_showcase_blocks(collaborations) do
    collaborations
    |> Enum.with_index()
    |> Enum.map(fn {collaboration, index} ->
      %{
        id: "collaboration_#{collaboration.id}",
        block_type: :collaboration_card,
        position: index,
        content_data: %{
          title: collaboration.title,
          type: format_content_type(collaboration.type),
          description: collaboration.description,
          status: collaboration.status,
          completion_date: collaboration.completed_at,
          role: determine_user_role(collaboration),
          contribution_metrics: %{
            revenue_share: collaboration.revenue_share,
            quality_score: collaboration.metrics.quality_score,
            peer_review_rating: collaboration.metrics.peer_review_rating
          },
          collaborators: format_collaborators_for_display(collaboration.collaborators),
          featured_media: extract_featured_media(collaboration),
          achievements: extract_collaboration_achievements(collaboration)
        }
      }
    end)
  end

  # Private helper functions
  defp get_or_create_collaboration_section(portfolio_id) do
    case Portfolios.get_portfolio_section_by_type(portfolio_id, :collaborations) do
      nil ->
        # Create new collaborations section
        Portfolios.create_portfolio_section(portfolio_id, %{
          section_type: :collaborations,
          title: "Collaborations",
          content: default_collaboration_content(),
          position: 999,  # Place at end initially
          visible: true
        })

      section ->
        {:ok, section}
    end
  end

  defp default_collaboration_content do
    %{
      "title" => "Collaborative Works",
      "description" => "Showcasing successful collaborative projects and partnerships",
      "display_format" => "featured_cards",
      "show_revenue_metrics" => true,
      "show_quality_scores" => true,
      "show_collaborator_details" => true,
      "featured_collaboration" => nil,
      "collaboration_stats" => %{
        "total_collaborations" => 0,
        "total_revenue" => 0,
        "average_quality_score" => 0,
        "collaboration_types" => []
      }
    }
  end

  defp build_collaboration_content(collaborations, existing_content) do
    stats = calculate_collaboration_stats(collaborations)

    Map.merge(existing_content, %{
      "collaborations" => format_collaborations_for_content(collaborations),
      "collaboration_stats" => stats,
      "featured_collaboration" => select_featured_collaboration(collaborations),
      "last_updated" => DateTime.utc_now()
    })
  end

  defp calculate_collaboration_stats(collaborations) do
    total_count = length(collaborations)

    total_revenue = collaborations
    |> Enum.map(& &1.revenue_share)
    |> Enum.sum()

    avg_quality = if total_count > 0 do
      collaborations
      |> Enum.map(& &1.metrics.quality_score)
      |> Enum.sum()
      |> Kernel./(total_count)
      |> Float.round(2)
    else
      0.0
    end

    collaboration_types = collaborations
    |> Enum.map(& &1.type)
    |> Enum.frequencies()

    %{
      "total_collaborations" => total_count,
      "total_revenue" => total_revenue,
      "average_quality_score" => avg_quality,
      "collaboration_types" => collaboration_types
    }
  end

  defp select_featured_collaboration(collaborations) do
    # Select highest-revenue or highest-quality collaboration as featured
    collaborations
    |> Enum.max_by(fn collab ->
      (collab.revenue_share * 0.6) + (collab.metrics.quality_score * 0.4)
    end, fn -> nil end)
  end

  defp format_content_type(type) do
    case type do
      :data_story -> "Data Story"
      :book -> "Book"
      :podcast -> "Podcast"
      :music_track -> "Music"
      :blog_post -> "Blog Post"
      :news_article -> "Article"
      :video_content -> "Video"
      _ -> "Content"
    end
  end

  defp determine_user_role(collaboration) do
    # Determine user's primary role in collaboration
    case collaboration.revenue_share do
      share when share >= 50 -> "Lead Contributor"
      share when share >= 25 -> "Co-Creator"
      share when share >= 10 -> "Contributor"
      _ -> "Supporting Role"
    end
  end

  defp format_collaborators_for_display(collaborators) do
    collaborators
    |> Enum.take(3)  # Limit to top 3 for display
    |> Enum.map(fn collaborator ->
      %{
        name: collaborator.username,
        avatar_url: collaborator.avatar_url,
        role: collaborator.role,
        contribution_percentage: collaborator.revenue_percentage
      }
    end)
  end

  defp extract_featured_media(collaboration) do
    # Extract representative media for the collaboration
    case collaboration.type do
      :music_track ->
        %{type: "audio", preview_url: collaboration.preview_url}
      :video_content ->
        %{type: "video", thumbnail_url: collaboration.thumbnail_url}
      _ ->
        %{type: "image", image_url: collaboration.featured_image_url}
    end
  end

  defp extract_collaboration_achievements(collaboration) do
    achievements = []

    # Add quality-based achievements
    achievements = if collaboration.metrics.quality_score >= 4.5 do
      [%{type: "quality", title: "Excellence Award", description: "Achieved 4.5+ quality rating"} | achievements]
    else
      achievements
    end

    # Add revenue-based achievements
    achievements = if collaboration.revenue_share >= 1000 do
      [%{type: "revenue", title: "High Earner", description: "Generated $1000+ revenue"} | achievements]
    else
      achievements
    end

    # Add collaboration-specific achievements
    achievements = if collaboration.metrics.peer_review_rating >= 4.0 do
      [%{type: "peer_recognition", title: "Peer Approved", description: "4.0+ peer review rating"} | achievements]
    else
      achievements
    end

    achievements
  end

  defp format_collaborations_for_content(collaborations) do
    Enum.map(collaborations, fn collaboration ->
      %{
        "id" => collaboration.id,
        "title" => collaboration.title,
        "type" => collaboration.type,
        "status" => collaboration.status,
        "completed_at" => collaboration.completed_at,
        "revenue_share" => collaboration.revenue_share,
        "quality_score" => collaboration.metrics.quality_score,
        "collaborators_count" => length(collaboration.collaborators),
        "preview_data" => extract_featured_media(collaboration)
      }
    end)
  end
end
