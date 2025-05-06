defmodule FrestylWeb.AIAssistantController do
  use FrestylWeb, :controller

  alias Frestyl.AIAssistant
  alias Frestyl.Accounts

  @doc """
  Start the onboarding flow for a user.
  """
  def start_onboarding(conn, _params) do
    user = Accounts.get_user!(conn.assigns.current_user.id)

    case AIAssistant.start_onboarding(user) do
      {:ok, question} ->
        json(conn, %{
          success: true,
          interaction_id: question.id,
          question: question.text,
          step: question.step,
          total_steps: question.total_steps
        })

      {:error, reason} ->
        conn
        |> put_status(400)
        |> json(%{success: false, error: reason})
    end
  end

  @doc """
  Process a user's response during the onboarding flow.
  """
  def process_onboarding_response(conn, %{"interaction_id" => interaction_id, "response" => response}) do
    case AIAssistant.process_onboarding_response(interaction_id, response) do
      {:ok, question} ->
        json(conn, %{
          success: true,
          interaction_id: question.id,
          question: question.text,
          step: question.step,
          total_steps: question.total_steps,
          completed: false
        })

      {:ok, :completed, preferences} ->
        json(conn, %{
          success: true,
          completed: true,
          preferences: %{
            content_preferences: preferences.content_preferences,
            feature_preferences: preferences.feature_preferences,
            experience_level: preferences.experience_level,
            guidance_preference: preferences.guidance_preference,
            usage_frequency: preferences.usage_frequency
          }
        })

      {:error, reason} ->
        conn
        |> put_status(400)
        |> json(%{success: false, error: reason})
    end
  end

  @doc """
  Get recommendations for the current user.
  """
  def get_recommendations(conn, _params) do
    user_id = conn.assigns.current_user.id

    case AIAssistant.generate_recommendations(user_id) do
      {:ok, recommendations} ->
        json(conn, %{
          success: true,
          recommendations: Enum.map(recommendations, fn rec ->
            %{
              id: rec.id,
              category: rec.category,
              title: rec.title,
              description: rec.description,
              relevance_score: rec.relevance_score
            }
          end)
        })

      {:error, reason} ->
        conn
        |> put_status(400)
        |> json(%{success: false, error: reason})
    end
  end

  @doc """
  Update the status of a recommendation (dismissed, completed).
  """
  def update_recommendation_status(conn, %{"recommendation_id" => recommendation_id, "status" => status}) do
    user_id = conn.assigns.current_user.id

    # Implementation would update the recommendation status
    json(conn, %{success: true})
  end

  @doc """
  Get assistance with setting up a session or event.
  """
  def get_setup_assistance(conn, %{"setup_type" => setup_type, "details" => details}) do
    user_id = conn.assigns.current_user.id

    case AIAssistant.assist_with_setup(user_id, setup_type, details) do
      {:ok, guidance} ->
        json(conn, %{
          success: true,
          guidance: guidance
        })

      {:error, reason} ->
        conn
        |> put_status(400)
        |> json(%{success: false, error: reason})
    end
  end

  @doc """
  Categorize a channel based on its purpose and content.
  """
  def categorize_channel(conn, %{"channel_id" => channel_id}) do
    # Fetch channel and categorize it
    channel = Frestyl.Channels.get_channel!(channel_id)

    case AIAssistant.categorize_channel(channel) do
      {:ok, updated_channel} ->
        json(conn, %{
          success: true,
          category: updated_channel.category
        })

      {:error, reason} ->
        conn
        |> put_status(400)
        |> json(%{success: false, error: reason})
    end
  end
end
