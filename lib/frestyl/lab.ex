# lib/frestyl/lab.ex - Creative Lab Context Module

defmodule Frestyl.Lab do
  @moduledoc """
  The Lab context for experimental features and A/B testing.

  This module manages experimental portfolio features, time-limited access,
  and subscription-tier based functionality.
  """

  import Ecto.Query, warn: false
  alias Frestyl.Repo
  alias Frestyl.Lab.{Experiment, Feature, Usage}
  alias Frestyl.Accounts.User
  alias Frestyl.Portfolios.Portfolio

  # ============================================================================
  # FEATURE MANAGEMENT
  # ============================================================================

  @doc """
  Lists all available lab features for a user based on their subscription tier.
  """
  def list_available_features(user) do
    tier = user.subscription_tier || "free"

    from(f in Feature,
      where: f.is_active == true and f.min_tier in ^get_accessible_tiers(tier),
      order_by: [asc: f.display_order])
    |> Repo.all()
    |> Enum.map(&add_usage_data(&1, user.id))
  end

  @doc """
  Gets a specific lab feature by ID.
  """
  def get_feature!(id) do
    Repo.get!(Feature, id)
  end

  @doc """
  Creates a new lab feature (admin only).
  """
  def create_feature(attrs \\ %{}) do
    %Feature{}
    |> Feature.changeset(attrs)
    |> Repo.insert()
  end

  # ============================================================================
  # EXPERIMENT MANAGEMENT
  # ============================================================================

  @doc """
  Starts a new experiment for a user.
  """
  def start_experiment(user, feature_id, portfolio \\ nil) do
    feature = get_feature!(feature_id)

    with :ok <- validate_experiment_start(user, feature),
         {:ok, experiment} <- create_experiment(user, feature, portfolio) do

      # Track usage
      track_usage(user.id, feature.id, "start")

      {:ok, experiment}
    else
      error -> error
    end
  end

  @doc """
  Ends an active experiment and saves results.
  """
  def end_experiment(experiment_id, user_id) do
    experiment = get_user_experiment!(experiment_id, user_id)

    end_time = DateTime.utc_now()
    duration_minutes = DateTime.diff(end_time, experiment.started_at, :minute)

    experiment
    |> Experiment.end_changeset(%{
      ended_at: end_time,
      duration_minutes: duration_minutes,
      status: :completed
    })
    |> Repo.update()
    |> case do
      {:ok, updated_experiment} ->
        # Track usage completion
        track_usage(user_id, experiment.feature_id, "complete", duration_minutes)
        {:ok, updated_experiment}

      error -> error
    end
  end

  @doc """
  Lists active experiments for a user.
  """
  def list_active_experiments(user_id) do
    from(e in Experiment,
      join: f in Feature, on: e.feature_id == f.id,
      where: e.user_id == ^user_id and e.status == :active,
      select: %{
        id: e.id,
        name: f.name,
        feature_id: f.id,
        started_at: e.started_at,
        portfolio_id: e.portfolio_id
      },
      order_by: [desc: e.started_at])
    |> Repo.all()
    |> Enum.map(&format_experiment_display/1)
  end

  @doc """
  Gets experiment by ID ensuring user ownership.
  """
  def get_user_experiment!(experiment_id, user_id) do
    from(e in Experiment,
      where: e.id == ^experiment_id and e.user_id == ^user_id)
    |> Repo.one!()
  end

  # ============================================================================
  # USAGE TRACKING & LIMITS
  # ============================================================================

  @doc """
  Gets total time used for a feature by user this month.
  """
  def get_time_used_this_month(user_id, feature_id) do
    start_of_month = Date.beginning_of_month(Date.utc_today()) |> DateTime.new!(~T[00:00:00])

    from(u in Usage,
      where: u.user_id == ^user_id
        and u.feature_id == ^feature_id
        and u.inserted_at >= ^start_of_month,
      select: sum(u.duration_minutes))
    |> Repo.one() || 0
  end

  @doc """
  Checks if user can start a new experiment for a feature.
  """
  def can_start_experiment?(user, feature) do
    case validate_experiment_start(user, feature) do
      :ok -> true
      _ -> false
    end
  end

  @doc """
  Gets usage statistics for a user.
  """
  def get_user_usage_stats(user_id) do
    %{
      experiments_completed: count_completed_experiments(user_id),
      total_lab_time: get_total_lab_time(user_id),
      features_tried: count_features_tried(user_id),
      current_month_usage: get_current_month_usage(user_id)
    }
  end

  # ============================================================================
  # PORTFOLIO INTEGRATION
  # ============================================================================

  @doc """
  Creates a Lab-enhanced portfolio with experimental features.
  """
  def create_lab_portfolio(user, template_id, attrs \\ %{}) do
    lab_template = get_lab_template!(template_id)

    portfolio_attrs = Map.merge(attrs, %{
      theme: lab_template.theme_name,
      template_type: "lab",
      lab_features: lab_template.features,
      experimental: true
    })

    case Frestyl.Portfolios.create_portfolio(user.id, portfolio_attrs) do
      {:ok, portfolio} ->
        # Track lab portfolio creation
        track_usage(user.id, "portfolio_creation", "lab_template", 0)
        {:ok, portfolio}

      error -> error
    end
  end

  @doc """
  Applies experimental modifications to a portfolio.
  """
  def apply_experiment_to_portfolio(experiment_id, modifications) do
    experiment = Repo.get!(Experiment, experiment_id)

    case experiment.portfolio_id do
      nil -> {:error, :no_portfolio_associated}
      portfolio_id ->
        portfolio = Frestyl.Portfolios.get_portfolio!(portfolio_id)

        updated_customization = merge_experimental_changes(
          portfolio.customization || %{},
          modifications
        )

        Frestyl.Portfolios.update_portfolio(portfolio, %{
          customization: updated_customization,
          last_lab_update: DateTime.utc_now()
        })
    end
  end

  # ============================================================================
  # COLLABORATION & CHANNELS INTEGRATION
  # ============================================================================

  @doc """
  Creates a Cipher collaboration session with anonymous matching.
  """
  def create_cipher_collaboration(user, skills \\ []) do
    # Find potential collaborators with complementary skills
    collaborator = find_cipher_match(user, skills)

    channel_attrs = %{
      name: "Cipher Session ##{generate_cipher_id()}",
      description: "Anonymous collaboration session",
      visibility: "private",
      channel_type: "cipher_collaboration",
      cipher_mode: true,
      participants: [user.id, collaborator && collaborator.id]
    }

    case Frestyl.Channels.create_channel(channel_attrs, user) do
      {:ok, channel} ->
        # Create experiment tracking
        {:ok, experiment} = start_experiment(user, "collaboration_cipher", nil)

        # Update experiment with channel info
        experiment
        |> Experiment.changeset(%{channel_id: channel.id})
        |> Repo.update()

        {:ok, %{channel: channel, experiment: experiment, collaborator: collaborator}}

      error -> error
    end
  end

  @doc """
  Manages stranger collaboration matching based on skills and availability.
  """
  def find_stranger_collaboration_match(user, preferences \\ %{}) do
    skills = Map.get(preferences, :skills, [])
    availability = Map.get(preferences, :availability, "flexible")
    project_type = Map.get(preferences, :project_type, "any")

    # Complex matching algorithm
    potential_matches = find_collaboration_candidates(user, skills, project_type)

    case potential_matches do
      [] -> {:error, :no_matches_found}
      matches ->
        best_match = select_best_match(matches, preferences)
        {:ok, best_match}
    end
  end

  # ============================================================================
  # AI & CONTENT GENERATION
  # ============================================================================

  @doc """
  Generates AI-powered bio content for creators.
  """
  def generate_creator_bio(user, style \\ "professional", context \\ %{}) do
    bio_prompt = build_bio_prompt(user, style, context)

    case call_ai_service("bio_generation", bio_prompt) do
      {:ok, generated_content} ->
        # Track usage
        track_usage(user.id, "bio_generator", "generation", 1)

        bio_variations = %{
          professional: generated_content.professional,
          creative: generated_content.creative,
          casual: generated_content.casual,
          technical: generated_content.technical
        }

        {:ok, bio_variations}

      error -> error
    end
  end

  @doc """
  Runs A/B testing on portfolio variations.
  """
  def setup_ab_test(user, portfolio, test_config) do
    variations = create_portfolio_variations(portfolio, test_config)

    ab_test = %{
      id: generate_test_id(),
      portfolio_id: portfolio.id,
      variations: variations,
      traffic_split: test_config.traffic_split || 50,
      duration_days: test_config.duration_days || 7,
      metrics_tracked: test_config.metrics || ["views", "engagement", "conversions"],
      status: :active,
      started_at: DateTime.utc_now()
    }

    # Store test configuration
    {:ok, experiment} = start_experiment(user, "ab_testing", portfolio)

    experiment
    |> Experiment.changeset(%{metadata: ab_test})
    |> Repo.update()
  end

  # ============================================================================
  # BRAINSTORM & IDEATION TOOLS
  # ============================================================================

  @doc """
  Creates a structured brainstorm session.
  """
  def create_brainstorm_session(user, topic, session_type \\ "creative") do
    session_config = get_brainstorm_config(session_type)

    brainstorm_data = %{
      topic: topic,
      session_type: session_type,
      facilitator_prompts: session_config.prompts,
      phases: session_config.phases,
      duration_minutes: session_config.duration,
      collaborative: session_config.collaborative
    }

    {:ok, experiment} = start_experiment(user, "brainstorm_room", nil)

    experiment
    |> Experiment.changeset(%{metadata: brainstorm_data})
    |> Repo.update()
    |> case do
      {:ok, updated_experiment} ->
        # Create channel for collaborative brainstorming if needed
        if brainstorm_data.collaborative do
          create_brainstorm_channel(user, updated_experiment)
        else
          {:ok, updated_experiment}
        end

      error -> error
    end
  end

  # ============================================================================
  # PRIVATE HELPER FUNCTIONS
  # ============================================================================

  defp validate_experiment_start(user, feature) do
    cond do
      not tier_has_access?(user.subscription_tier, feature.min_tier) ->
        {:error, :subscription_required}

      time_limit_exceeded?(user.id, feature) ->
        {:error, :time_limit_exceeded}

      has_active_experiment?(user.id, feature.id) ->
        {:error, :experiment_already_active}

      true -> :ok
    end
  end

  defp create_experiment(user, feature, portfolio) do
    %Experiment{}
    |> Experiment.changeset(%{
      user_id: user.id,
      feature_id: feature.id,
      portfolio_id: portfolio && portfolio.id,
      started_at: DateTime.utc_now(),
      status: :active,
      metadata: %{}
    })
    |> Repo.insert()
  end

  defp get_accessible_tiers("free"), do: ["free"]
  defp get_accessible_tiers("pro"), do: ["free", "pro"]
  defp get_accessible_tiers("premium"), do: ["free", "pro", "premium"]
  defp get_accessible_tiers(_), do: ["free"]

  defp tier_has_access?(user_tier, required_tier) do
    tier_levels = %{"free" => 0, "pro" => 1, "premium" => 2}

    Map.get(tier_levels, user_tier || "free", 0) >=
    Map.get(tier_levels, required_tier, 0)
  end

  defp time_limit_exceeded?(user_id, feature) do
    if feature.time_limit_minutes > 0 do
      used_time = get_time_used_this_month(user_id, feature.id)
      used_time >= feature.time_limit_minutes
    else
      false
    end
  end

  defp has_active_experiment?(user_id, feature_id) do
    from(e in Experiment,
      where: e.user_id == ^user_id
        and e.feature_id == ^feature_id
        and e.status == :active)
    |> Repo.exists?()
  end

  defp add_usage_data(feature, user_id) do
    time_used = get_time_used_this_month(user_id, feature.id)
    time_remaining = max(0, feature.time_limit_minutes - time_used)

    Map.merge(feature, %{
      time_used: time_used,
      time_remaining: time_remaining,
      available: time_remaining > 0 || feature.time_limit_minutes == 0
    })
  end

  defp track_usage(user_id, feature_id, action, duration_minutes \\ 0) do
    %Usage{}
    |> Usage.changeset(%{
      user_id: user_id,
      feature_id: feature_id,
      action: action,
      duration_minutes: duration_minutes,
      timestamp: DateTime.utc_now()
    })
    |> Repo.insert()
  end

  defp format_experiment_display(experiment) do
    Map.merge(experiment, %{
      started_at: format_relative_time(experiment.started_at)
    })
  end

  defp format_relative_time(datetime) do
    case DateTime.diff(DateTime.utc_now(), datetime, :minute) do
      minutes when minutes < 60 -> "#{minutes} minutes ago"
      minutes when minutes < 1440 -> "#{div(minutes, 60)} hours ago"
      minutes -> "#{div(minutes, 1440)} days ago"
    end
  end

  defp count_completed_experiments(user_id) do
    from(e in Experiment,
      where: e.user_id == ^user_id and e.status == :completed,
      select: count())
    |> Repo.one() || 0
  end

  defp get_total_lab_time(user_id) do
    from(u in Usage,
      where: u.user_id == ^user_id,
      select: sum(u.duration_minutes))
    |> Repo.one() || 0
  end

  defp count_features_tried(user_id) do
    from(e in Experiment,
      where: e.user_id == ^user_id,
      distinct: e.feature_id,
      select: count())
    |> Repo.one() || 0
  end

  defp get_current_month_usage(user_id) do
    start_of_month = Date.beginning_of_month(Date.utc_today()) |> DateTime.new!(~T[00:00:00])

    from(u in Usage,
      where: u.user_id == ^user_id and u.inserted_at >= ^start_of_month,
      select: sum(u.duration_minutes))
    |> Repo.one() || 0
  end

  # Lab Template Management
  defp get_lab_template!(template_id) do
    # This would fetch experimental templates
    %{
      id: template_id,
      theme_name: "holographic",
      features: ["immersive_animations", "3d_effects", "gesture_controls"],
      requirements: ["pro"]
    }
  end

  defp merge_experimental_changes(base_customization, modifications) do
    Map.merge(base_customization, modifications)
  end

  # Cipher Collaboration Helpers
  defp find_cipher_match(user, skills) do
    # Anonymous matching algorithm
    # This would find users with complementary skills who are also looking for collaborators
    nil # Placeholder
  end

  defp generate_cipher_id do
    :rand.uniform(999999)
  end

  # Stranger Collaboration Helpers
  defp find_collaboration_candidates(user, skills, project_type) do
    # Complex matching algorithm based on:
    # - Complementary skills
    # - Project type preferences
    # - Availability windows
    # - Past collaboration success
    []
  end

  defp select_best_match(matches, preferences) do
    # Scoring algorithm for best collaboration match
    List.first(matches)
  end

  # AI Integration Helpers
  defp call_ai_service(service_type, prompt) do
    # Integration with AI services for content generation
    case service_type do
      "bio_generation" ->
        {:ok, %{
          professional: "Professional bio content...",
          creative: "Creative bio content...",
          casual: "Casual bio content...",
          technical: "Technical bio content..."
        }}

      _ -> {:error, :service_not_available}
    end
  end

  defp build_bio_prompt(user, style, context) do
    # Build AI prompt based on user data and context
    %{
      user_industry: user.industry,
      style: style,
      context: context,
      portfolio_count: context[:portfolio_count] || 0,
      specializations: context[:skills] || []
    }
  end

  # A/B Testing Helpers
  defp create_portfolio_variations(portfolio, test_config) do
    %{
      control: portfolio.customization,
      variant_a: apply_test_modifications(portfolio.customization, test_config.variant_a),
      variant_b: apply_test_modifications(portfolio.customization, test_config.variant_b)
    }
  end

  defp apply_test_modifications(base_customization, modifications) do
    Map.merge(base_customization, modifications)
  end

  defp generate_test_id do
    "ab_" <> (:crypto.strong_rand_bytes(8) |> Base.encode64() |> String.slice(0, 8))
  end

  # Brainstorm Session Helpers
  defp get_brainstorm_config("creative") do
    %{
      prompts: [
        "What if there were no constraints?",
        "How might we approach this differently?",
        "What would the opposite solution look like?"
      ],
      phases: ["divergent", "convergent", "action_planning"],
      duration: 45,
      collaborative: true
    }
  end

  defp get_brainstorm_config("technical") do
    %{
      prompts: [
        "What are the technical constraints?",
        "How can we optimize for performance?",
        "What edge cases should we consider?"
      ],
      phases: ["problem_analysis", "solution_generation", "feasibility_check"],
      duration: 60,
      collaborative: true
    }
  end

  defp get_brainstorm_config(_), do: get_brainstorm_config("creative")

  defp create_brainstorm_channel(user, experiment) do
    channel_attrs = %{
      name: "Brainstorm: #{experiment.metadata["topic"]}",
      description: "Collaborative brainstorming session",
      visibility: "private",
      channel_type: "brainstorm_session",
      temporary: true,
      auto_archive_hours: 24
    }

    case Frestyl.Channels.create_channel(channel_attrs, user) do
      {:ok, channel} ->
        # Link channel to experiment
        experiment
        |> Experiment.changeset(%{channel_id: channel.id})
        |> Repo.update()

      error -> error
    end
  end
end
