# Peer Review Integration with Vibe Rating System
# File: lib/frestyl/data_campaigns/enhanced_peer_review.ex

defmodule Frestyl.DataCampaigns.EnhancedPeerReview do
  @moduledoc """
  Enhanced peer review system that integrates with the vibe rating system.
  Uses the same color-gradient interface for all types of peer review.
  """

  import Ecto.Query, warn: false
  alias Frestyl.DataCampaigns.PeerReview
  alias Frestyl.Teams
  alias Frestyl.Teams.VibeRating
  alias Phoenix.PubSub

  @doc """
  Submits a vibe-based peer review for campaign contributions.
  """
  def submit_vibe_peer_review(reviewer_id, contribution_id, rating_data) do
    # Get contribution and campaign details
    contribution = get_contribution!(contribution_id)
    campaign = get_campaign!(contribution.campaign_id)

    # Determine review criteria based on contribution type
    {primary_dimension, secondary_dimension} = get_review_dimensions(contribution.type, campaign)

    # Create vibe rating record
    vibe_rating_attrs = %{
      reviewer_id: reviewer_id,
      reviewee_id: contribution.user_id,
      team_id: get_or_create_campaign_team(campaign.id),
      primary_score: rating_data.primary_score,
      secondary_score: rating_data.secondary_score,
      rating_coordinates: rating_data.rating_coordinates,
      rating_type: "peer_review",
      dimension_context: "#{primary_dimension}_#{secondary_dimension}",
      rating_session_duration: rating_data.rating_session_duration,
      rating_prompt: generate_review_prompt(contribution, primary_dimension, secondary_dimension),
      translated_scores: %{
        "quality" => rating_data.primary_score / 20.0,
        "secondary_metric" => rating_data.secondary_score / 20.0
      }
    }

    case Teams.submit_vibe_rating(vibe_rating_attrs) do
      {:ok, vibe_rating} ->
        # Create traditional peer review record for campaign tracking
        create_traditional_peer_review(vibe_rating, contribution)

        # Check if review is complete and update contribution status
        check_and_complete_contribution_review(contribution_id)

        {:ok, vibe_rating}

      error -> error
    end
  end

  @doc """
  Gets review interface configuration for different contribution types.
  """
  def get_review_interface_config(contribution_type, campaign_type \\ "academic") do
    {primary_dim, secondary_dim} = get_review_dimensions(contribution_type, %{type: campaign_type})

    %{
      primary_dimension: %{
        name: format_dimension_name(primary_dim),
        description: get_dimension_description(primary_dim)
      },
      secondary_dimension: %{
        name: format_dimension_name(secondary_dim),
        description: get_dimension_description(secondary_dim)
      },
      review_prompt: generate_dimension_prompt(primary_dim, secondary_dim),
      success_message: "Thank you! Your peer review helps improve collaboration quality."
    }
  end

  @doc """
  Gets aggregated peer review results for a contribution.
  """
  def get_contribution_review_summary(contribution_id) do
    contribution = get_contribution!(contribution_id)
    team_id = get_or_create_campaign_team(contribution.campaign_id)

    # Get all vibe ratings for this contribution
    reviews = from(v in VibeRating,
      where: v.reviewee_id == ^contribution.user_id and
             v.team_id == ^team_id and
             v.rating_type == "peer_review",
      preload: [:reviewer],
      order_by: [desc: v.inserted_at]
    ) |> Frestyl.Repo.all()

    if length(reviews) == 0 do
      %{
        review_count: 0,
        average_quality: 0.0,
        average_secondary: 0.0,
        overall_color: "#64748b",
        review_status: :pending,
        individual_reviews: []
      }
    else
      avg_primary = reviews |> Enum.map(& &1.primary_score) |> Enum.sum() |> Kernel./(length(reviews))
      avg_secondary = reviews |> Enum.map(& &1.secondary_score) |> Enum.sum() |> Kernel./(length(reviews))

      %{
        review_count: length(reviews),
        average_quality: Float.round(avg_primary / 20.0, 2),
        average_secondary: Float.round(avg_secondary / 20.0, 2),
        overall_color: hue_to_hex_color(avg_primary),
        review_status: determine_review_status(avg_primary, length(reviews)),
        individual_reviews: format_individual_reviews(reviews),
        consensus_level: calculate_review_consensus(reviews)
      }
    end
  end

  @doc """
  Creates milestone-based peer review requests for campaigns.
  """
  def create_milestone_peer_reviews(campaign_id, milestone_percentage) do
    campaign = get_campaign!(campaign_id)
    contributors = get_campaign_contributors(campaign_id)

    # Create vibe rating reminders for all contributors
    team_id = get_or_create_campaign_team(campaign_id)

    Enum.each(contributors, fn contributor ->
      Teams.create_rating_reminders(team_id, "milestone_rating", calculate_milestone_due_date(campaign, milestone_percentage))
    end)

    # Notify contributors about milestone review
    notify_milestone_review_available(campaign_id, milestone_percentage)
  end

  # Private Helper Functions

  defp get_review_dimensions(contribution_type, campaign) do
    base_dimensions = case contribution_type do
      :content_contribution -> {"content_quality", "originality"}
      :audio_contribution -> {"audio_quality", "technical_execution"}
      :video_contribution -> {"production_quality", "storytelling"}
      :code_contribution -> {"code_quality", "documentation"}
      :design_contribution -> {"aesthetic_quality", "usability"}
      _ -> {"overall_quality", "effort_level"}
    end

    # Override secondary dimension based on campaign context
    {primary, _secondary} = base_dimensions
    campaign_secondary = case campaign.type || "academic" do
      "academic" -> "collaboration_effectiveness"
      "creative" -> "innovation_level"
      "business" -> "commercial_viability"
      "technical" -> "technical_execution"
      _ -> "collaboration_effectiveness"
    end

    {primary, campaign_secondary}
  end

  defp get_or_create_campaign_team(campaign_id) do
    # Check if campaign team exists, create if not
    case Frestyl.Repo.get_by(Teams.ChannelTeam, metadata: %{"campaign_id" => campaign_id}) do
      nil ->
        {:ok, team} = Teams.create_team(nil, nil, %{
          name: "Campaign #{campaign_id} Team",
          metadata: %{"campaign_id" => campaign_id, "auto_generated" => true}
        })
        team.id

      team -> team.id
    end
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
      "content_quality" => "How well-written, clear, and engaging is the content?",
      "audio_quality" => "How clear and professional is the audio production?",
      "production_quality" => "How well-produced and polished is the work?",
      "code_quality" => "How clean, efficient, and maintainable is the code?",
      "aesthetic_quality" => "How visually appealing and well-designed is it?",
      "collaboration_effectiveness" => "How well do they work with others?",
      "innovation_level" => "How creative and original is their approach?",
      "commercial_viability" => "How valuable is this in a business context?",
      "technical_execution" => "How technically skilled is the implementation?",
      "originality" => "How unique and creative is the contribution?",
      "usability" => "How user-friendly and intuitive is the design?",
      "effort_level" => "How much effort and care was put into this work?"
    }

    Map.get(descriptions, to_string(dimension_key), "Rate this aspect of their work")
  end

  defp generate_review_prompt(contribution, primary_dim, secondary_dim) do
    contributor_name = contribution.user.first_name
    primary_name = format_dimension_name(primary_dim)
    secondary_name = format_dimension_name(secondary_dim)

    "How would you rate #{contributor_name}'s contribution? Use the color gradient to indicate #{primary_name}, and the vertical position for #{secondary_name}."
  end

  defp generate_dimension_prompt(primary_dim, secondary_dim) do
    primary_name = format_dimension_name(primary_dim)
    secondary_name = format_dimension_name(secondary_dim)

    "Rate this contribution using the color gradient for #{primary_name} and vertical position for #{secondary_name}."
  end

  defp create_traditional_peer_review(vibe_rating, contribution) do
    # Create a traditional peer review record for backwards compatibility
    review_attrs = %{
      contribution_id: contribution.id,
      reviewer_id: vibe_rating.reviewer_id,
      overall_score: vibe_rating.translated_scores["quality"],
      criteria_scores: [
        %{
          name: "Quality",
          score: vibe_rating.translated_scores["quality"],
          weight: 0.6
        },
        %{
          name: "Secondary Metric",
          score: vibe_rating.translated_scores["secondary_metric"],
          weight: 0.4
        }
      ],
      comments: "",
      review_type: "vibe_based",
      metadata: %{
        vibe_rating_id: vibe_rating.id,
        color_position: vibe_rating.primary_score,
        vertical_position: vibe_rating.secondary_score
      }
    }

    PeerReview.create_review(review_attrs)
  end

  defp check_and_complete_contribution_review(contribution_id) do
    contribution = get_contribution!(contribution_id)
    review_summary = get_contribution_review_summary(contribution_id)

    # Check if minimum reviews are complete
    min_reviews_required = 2

    if review_summary.review_count >= min_reviews_required do
      # Update contribution status based on average score
      new_status = case review_summary.average_quality do
        score when score >= 4.0 -> "approved"
        score when score >= 3.0 -> "approved_with_suggestions"
        score when score >= 2.0 -> "needs_improvement"
        _ -> "rejected"
      end

      update_contribution_status(contribution_id, new_status, review_summary)

      # Notify contributor of review completion
      notify_review_completion(contribution, review_summary)
    end
  end

  defp determine_review_status(avg_primary_score, review_count) do
    min_reviews = 2

    cond do
      review_count < min_reviews -> :pending
      avg_primary_score >= 80 -> :approved
      avg_primary_score >= 60 -> :approved_with_feedback
      avg_primary_score >= 40 -> :needs_improvement
      true -> :rejected
    end
  end

  defp format_individual_reviews(reviews) do
    Enum.map(reviews, fn review ->
      %{
        reviewer_name: review.reviewer.first_name,
        quality_score: Float.round(review.primary_score / 20.0, 1),
        secondary_score: Float.round(review.secondary_score / 20.0, 1),
        color: hue_to_hex_color(review.primary_score),
        timestamp: review.inserted_at,
        session_duration: review.rating_session_duration
      }
    end)
  end

  defp calculate_review_consensus(reviews) do
    if length(reviews) < 2 do
      0.0
    else
      primary_scores = Enum.map(reviews, & &1.primary_score)
      variance = calculate_variance(primary_scores)

      # Convert variance to consensus percentage (lower variance = higher consensus)
      max_variance = 2500 # Max possible variance for 0-100 scale
      consensus_percentage = max(0, 100 - (variance / max_variance * 100))

      Float.round(consensus_percentage, 1)
    end
  end

  defp calculate_variance(numbers) do
    mean = Enum.sum(numbers) / length(numbers)
    squared_diffs = Enum.map(numbers, &:math.pow(&1 - mean, 2))
    Enum.sum(squared_diffs) / length(squared_diffs)
  end

  defp hue_to_hex_color(hue_value) do
    # Same color conversion as in Teams module
    hue = (hue_value / 100.0) * 120
    saturation = 75
    lightness = 50
    hsl_to_hex(hue, saturation, lightness)
  end

  defp hsl_to_hex(h, s, l) do
    # HSL to HEX conversion (same as Teams module)
    h = h / 360
    s = s / 100
    l = l / 100

    c = (1 - abs(2 * l - 1)) * s
    x = c * (1 - abs(rem(h * 6, 2) - 1))
    m = l - c / 2

    {r, g, b} = case trunc(h * 6) do
      0 -> {c, x, 0}
      1 -> {x, c, 0}
      2 -> {0, c, x}
      3 -> {0, x, c}
      4 -> {x, 0, c}
      5 -> {c, 0, x}
      _ -> {0, 0, 0}
    end

    r = trunc((r + m) * 255)
    g = trunc((g + m) * 255)
    b = trunc((b + m) * 255)

    r_hex = Integer.to_string(r, 16) |> String.pad_leading(2, "0")
    g_hex = Integer.to_string(g, 16) |> String.pad_leading(2, "0")
    b_hex = Integer.to_string(b, 16) |> String.pad_leading(2, "0")

    "#" <> r_hex <> g_hex <> b_hex
  end

  defp calculate_milestone_due_date(campaign, milestone_percentage) do
    case campaign.due_date do
      nil -> DateTime.add(DateTime.utc_now(), 7 * 24 * 60 * 60)
      due_date ->
        days_before = case milestone_percentage do
          25 -> 21
          50 -> 14
          75 -> 7
          100 -> 0
          _ -> 7
        end
        DateTime.add(due_date, -days_before * 24 * 60 * 60)
    end
  end

  defp notify_milestone_review_available(campaign_id, milestone_percentage) do
    contributors = get_campaign_contributors(campaign_id)

    Enum.each(contributors, fn contributor ->
      PubSub.broadcast(
        Frestyl.PubSub,
        "user:#{contributor.id}",
        {:milestone_review_available, %{
          campaign_id: campaign_id,
          milestone: "#{milestone_percentage}%",
          due_date: calculate_milestone_due_date(%{due_date: nil}, milestone_percentage)
        }}
      )
    end)
  end

  defp notify_review_completion(contribution, review_summary) do
    PubSub.broadcast(
      Frestyl.PubSub,
      "user:#{contribution.user_id}",
      {:peer_review_completed, %{
        contribution_id: contribution.id,
        average_score: review_summary.average_quality,
        review_count: review_summary.review_count,
        status: review_summary.review_status,
        overall_color: review_summary.overall_color
      }}
    )
  end

  # Placeholder functions - these would integrate with existing campaign system
  defp get_contribution!(id), do: %{id: id, user_id: 1, campaign_id: 1, type: :content_contribution, user: %{first_name: "John"}}
  defp get_campaign!(id), do: %{id: id, type: "academic", due_date: nil}
  defp get_campaign_contributors(id), do: []
  defp update_contribution_status(id, status, summary), do: :ok
end

# Vibe-based Peer Review LiveView Component
# File: lib/frestyl_web/live/components/vibe_peer_review_component.ex

defmodule FrestylWeb.VibePeerReviewComponent do
  use FrestylWeb, :live_component
  alias Frestyl.DataCampaigns.EnhancedPeerReview

  @impl true
  def update(assigns, socket) do
    config = EnhancedPeerReview.get_review_interface_config(
      assigns.contribution.type,
      assigns.campaign.type
    )

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:config, config)
     |> assign(:rating_submitted, false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="vibe-peer-review bg-white rounded-xl shadow-lg p-6">
      <%= if @rating_submitted do %>
        <!-- Success State -->
        <div class="text-center py-8">
          <div class="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <svg class="w-8 h-8 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
            </svg>
          </div>
          <h3 class="text-lg font-semibold text-gray-900 mb-2">Review Submitted!</h3>
          <p class="text-gray-600"><%= @config.success_message %></p>
        </div>
      <% else %>
        <!-- Review Interface -->
        <div class="mb-6">
          <h3 class="text-lg font-semibold text-gray-900 mb-2">Peer Review</h3>
          <p class="text-gray-600"><%= @config.review_prompt %></p>
        </div>

        <!-- Vibe Rating Widget (embedded React component) -->
        <div id="vibe-rating-container" phx-hook="VibeRatingWidget" phx-target={@myself}
             data-primary-dimension={@config.primary_dimension.name}
             data-secondary-dimension={@config.secondary_dimension.name}
             data-review-prompt={@config.review_prompt}>
        </div>

        <!-- Dimension Explanations -->
        <div class="mt-6 grid grid-cols-1 md:grid-cols-2 gap-4">
          <div class="bg-gray-50 rounded-lg p-4">
            <h4 class="font-medium text-gray-900 mb-2">
              <%= @config.primary_dimension.name %> (Horizontal)
            </h4>
            <p class="text-sm text-gray-600">
              <%= @config.primary_dimension.description %>
            </p>
          </div>

          <div class="bg-gray-50 rounded-lg p-4">
            <h4 class="font-medium text-gray-900 mb-2">
              <%= @config.secondary_dimension.name %> (Vertical)
            </h4>
            <p class="text-sm text-gray-600">
              <%= @config.secondary_dimension.description %>
            </p>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("submit_vibe_rating", rating_data, socket) do
    case EnhancedPeerReview.submit_vibe_peer_review(
      socket.assigns.current_user.id,
      socket.assigns.contribution.id,
      rating_data
    ) do
      {:ok, _vibe_rating} ->
        {:noreply, assign(socket, :rating_submitted, true)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to submit review. Please try again.")}
    end
  end
end
