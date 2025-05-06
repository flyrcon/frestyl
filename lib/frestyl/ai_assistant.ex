defmodule Frestyl.AIAssistant do
  @moduledoc """
  Provides AI assistant capabilities for user onboarding, recommendations,
  and general assistance within the Frestyl application.
  """

  alias Frestyl.Repo
  alias Frestyl.AIAssistant.{Interaction, UserPreference, Recommendation}

  @doc """
  Initiates the onboarding flow with AI-driven questions based on user profile.
  """
  def start_onboarding(user) do
    # Create initial interaction for onboarding
    %Interaction{}
    |> Interaction.changeset(%{
      user_id: user.id,
      flow_type: "onboarding",
      status: "started",
      metadata: %{
        step: 1,
        total_steps: 5
      }
    })
    |> Repo.insert()
    |> case do
      {:ok, interaction} -> {:ok, get_onboarding_question(interaction)}
      error -> error
    end
  end

  @doc """
  Processes a user response during the onboarding flow and returns the next question
  or completes the flow.
  """
  def process_onboarding_response(interaction_id, response) do
    interaction = Repo.get!(Interaction, interaction_id)

    # Update the interaction with the user's response
    updated_interaction =
      interaction
      |> Interaction.changeset(%{
        responses: Map.put(interaction.responses || %{}, "step_#{interaction.metadata.step}", response),
        metadata: %{
          step: interaction.metadata.step + 1,
          total_steps: interaction.metadata.total_steps
        }
      })
      |> Repo.update!()

    if updated_interaction.metadata.step > updated_interaction.metadata.total_steps do
      # Onboarding complete, categorize and save preferences
      save_preferences_from_onboarding(updated_interaction)
    else
      # Get the next question
      {:ok, get_onboarding_question(updated_interaction)}
    end
  end

  @doc """
  Generates the next onboarding question based on the current interaction state.
  """
  def get_onboarding_question(interaction) do
    case interaction.metadata.step do
      1 -> "What is your primary purpose for using Frestyl? (e.g., hosting events, selling tickets, managing performers)"
      2 -> "What types of content or events are you most interested in? (e.g., music, theater, workshops)"
      3 -> "How often do you plan to host or participate in events?"
      4 -> "What features are most important to you? (e.g., payments, scheduling, communication)"
      5 -> "Do you prefer a more guided experience or a self-directed approach?"
      _ -> "Invalid step"
    end
  end

  @doc """
  Analyzes user responses and saves their preferences.
  """
  def save_preferences_from_onboarding(interaction) do
    # Extract user responses
    responses = interaction.responses

    # Use AI to analyze responses and generate preferences
    preferences = analyze_responses_with_ai(responses)

    # Save preferences to database
    %UserPreference{}
    |> UserPreference.changeset(%{
      user_id: interaction.user_id,
      content_preferences: preferences.content_types,
      feature_preferences: preferences.important_features,
      experience_level: preferences.experience_level,
      guidance_preference: preferences.guidance_preference,
      usage_frequency: preferences.usage_frequency
    })
    |> Repo.insert()
    |> case do
      {:ok, user_preference} ->
        # Mark onboarding as completed
        Interaction.changeset(interaction, %{status: "completed"})
        |> Repo.update()

        {:ok, user_preference}
      error -> error
    end
  end

  @doc """
  Uses AI to analyze user responses and categorize their preferences.
  """
  def analyze_responses_with_ai(responses) do
    # This would call the AI service API with the user's responses
    # For now, we'll implement a simple rule-based analysis

    # Example implementation (to be replaced with actual AI call)
    content_types = extract_content_types(responses["step_2"] || "")

    %{
      content_types: content_types,
      important_features: extract_features(responses["step_4"] || ""),
      experience_level: determine_experience_level(responses),
      guidance_preference: determine_guidance_preference(responses["step_5"] || ""),
      usage_frequency: determine_usage_frequency(responses["step_3"] || "")
    }
  end

  @doc """
  Extracts content types from a user response.
  """
  def extract_content_types(response) do
    cond do
      String.contains?(String.downcase(response), "music") -> ["music"]
      String.contains?(String.downcase(response), "theater") -> ["theater"]
      String.contains?(String.downcase(response), "workshop") -> ["workshop"]
      true -> ["general"]
    end
  end

  @doc """
  Extracts important features from a user response.
  """
  def extract_features(response) do
    features = []

    features = if String.contains?(String.downcase(response), "payment"), do: ["payments" | features], else: features
    features = if String.contains?(String.downcase(response), "schedul"), do: ["scheduling" | features], else: features
    features = if String.contains?(String.downcase(response), "communicat"), do: ["communication" | features], else: features

    if features == [], do: ["general"], else: features
  end

  @doc """
  Determines the user's experience level based on their responses.
  """
  def determine_experience_level(responses) do
    # Simple logic for now - to be enhanced with AI
    "beginner"
  end

  @doc """
  Determines the user's preference for guidance based on their response.
  """
  def determine_guidance_preference(response) do
    cond do
      String.contains?(String.downcase(response), "guided") -> "guided"
      String.contains?(String.downcase(response), "self") -> "self_directed"
      true -> "balanced"
    end
  end

  @doc """
  Determines the user's usage frequency based on their response.
  """
  def determine_usage_frequency(response) do
    cond do
      String.contains?(String.downcase(response), "daily") -> "daily"
      String.contains?(String.downcase(response), "weekly") -> "weekly"
      String.contains?(String.downcase(response), "monthly") -> "monthly"
      true -> "occasional"
    end
  end

  @doc """
  Generates content recommendations based on user preferences.
  """
  def generate_recommendations(user_id) do
    preferences = Repo.get_by!(UserPreference, user_id: user_id)

    # Call AI service to generate recommendations based on preferences
    # For now, we'll use simple rule-based recommendations
    recommendations = generate_recommendations_by_preferences(preferences)

    # Save recommendations to database
    Enum.map(recommendations, fn rec ->
      %Recommendation{}
      |> Recommendation.changeset(%{
        user_id: user_id,
        category: rec.category,
        title: rec.title,
        description: rec.description,
        relevance_score: rec.relevance_score,
        status: "active"
      })
      |> Repo.insert()
    end)

    {:ok, recommendations}
  end

  @doc """
  Generates recommendations based on user preferences.
  """
  def generate_recommendations_by_preferences(preferences) do
    # Simple rule-based recommendations - would be replaced by AI
    Enum.flat_map(preferences.content_preferences, fn content_type ->
      case content_type do
        "music" -> [
          %{
            category: "channel_setup",
            title: "Create a Music Event Channel",
            description: "Set up a dedicated channel for your music events with specialized tools for musicians.",
            relevance_score: 0.9
          },
          %{
            category: "content",
            title: "Best Practices for Music Event Promotion",
            description: "Learn how to effectively promote your music events to reach a wider audience.",
            relevance_score: 0.8
          }
        ]
        "theater" -> [
          %{
            category: "channel_setup",
            title: "Theater Performance Channel",
            description: "Create a channel specifically designed for theatrical performances with seating arrangements.",
            relevance_score: 0.9
          }
        ]
        _ -> [
          %{
            category: "general",
            title: "Getting Started with Frestyl",
            description: "A general guide to making the most of the Frestyl platform.",
            relevance_score: 0.7
          }
        ]
      end
    end)
  end

  @doc """
  Categorizes a channel based on its purpose and content.
  """
  def categorize_channel(channel) do
    # Extract channel details
    channel_info = %{
      name: channel.name,
      description: channel.description || "",
      tags: channel.tags || []
    }

    # Call AI service to categorize the channel
    # For now, use simple keyword matching
    category = determine_channel_category(channel_info)

    # Update channel with category
    channel
    |> Ecto.Changeset.change(%{category: category})
    |> Repo.update()
  end

  @doc """
  Determines the category of a channel based on its information.
  """
  def determine_channel_category(channel_info) do
    description = String.downcase(channel_info.description)
    name = String.downcase(channel_info.name)

    cond do
      String.contains?(description, "music") || String.contains?(name, "music") -> "music"
      String.contains?(description, "theater") || String.contains?(name, "theater") -> "theater"
      String.contains?(description, "workshop") || String.contains?(name, "workshop") -> "workshop"
      String.contains?(description, "conference") || String.contains?(name, "conference") -> "conference"
      true -> "general"
    end
  end

  @doc """
  Provides assistance with setting up a session or event.
  """
  def assist_with_setup(user_id, setup_type, details) do
    # Create an assistance interaction
    %Interaction{}
    |> Interaction.changeset(%{
      user_id: user_id,
      flow_type: "setup_assistance",
      status: "started",
      metadata: %{
        setup_type: setup_type,
        details: details
      }
    })
    |> Repo.insert()
    |> case do
      {:ok, interaction} ->
        # Generate assistance based on setup type
        guidance = generate_setup_guidance(setup_type, details)

        # Update interaction with guidance
        interaction
        |> Interaction.changeset(%{
          status: "completed",
          responses: %{"guidance" => guidance}
        })
        |> Repo.update()

        {:ok, guidance}
      error -> error
    end
  end

  @doc """
  Generates guidance for setting up a session or event.
  """
  def generate_setup_guidance(setup_type, details) do
    # This would call the AI service to generate personalized guidance
    # For now, we'll use predefined guidance based on setup type

    case setup_type do
      "event" ->
        """
        Here's how to set up your event:

        1. Start by giving your event a clear, descriptive name
        2. Add details about date, time, and location
        3. Describe what attendees can expect
        4. Set up ticketing if applicable
        5. Create promotional materials
        """

      "session" ->
        """
        Follow these steps to set up your session:

        1. Determine the session format (workshop, class, etc.)
        2. Set a clear agenda and timeframe
        3. Prepare any necessary materials or resources
        4. Configure participant limits if needed
        5. Set up communication channels for participants
        """

      _ ->
        """
        To get started with your setup:

        1. Determine what type of activity you're creating
        2. Add all relevant details and information
        3. Consider your audience and their needs
        4. Set up any necessary payment or registration systems
        5. Plan your promotion strategy
        """
    end
  end
end
