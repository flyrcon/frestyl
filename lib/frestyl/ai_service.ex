defmodule Frestyl.AIService do
  @moduledoc """
  Service for interacting with AI providers (OpenAI, Anthropic, etc.)
  """

  @doc """
  Configure which AI provider to use.
  """
  def provider do
    Application.get_env(:frestyl, :ai_provider, :openai)
  end

  @doc """
  Generate a response from the AI model for a given prompt.
  """
  def generate_response(prompt, options \\ []) do
    case provider() do
      :openai -> openai_generate(prompt, options)
      :anthropic -> anthropic_generate(prompt, options)
      _ -> {:error, "Unsupported AI provider"}
    end
  end

  defp openai_generate(prompt, options) do
    # Setup for OpenAI API call
    api_key = Application.get_env(:frestyl, :openai_api_key)
    model = Keyword.get(options, :model, "gpt-4")

    # This would make an actual API call using HTTPoison or similar
    # For now, a simplified implementation
    case HTTPoison.post(
      "https://api.openai.com/v1/chat/completions",
      Jason.encode!(%{
        model: model,
        messages: [
          %{role: "system", content: "You are an helpful assistant for the Frestyl platform."},
          %{role: "user", content: prompt}
        ],
        temperature: Keyword.get(options, :temperature, 0.7)
      }),
      [
        {"Content-Type", "application/json"},
        {"Authorization", "Bearer #{api_key}"}
      ]
    ) do
      {:ok, %{status_code: 200, body: body}} ->
        response = Jason.decode!(body)
        {:ok, response["choices"][0]["message"]["content"]}

      {:ok, %{status_code: status_code, body: body}} ->
        {:error, "OpenAI API error: #{status_code} - #{body}"}

      {:error, reason} ->
        {:error, "HTTP error: #{inspect(reason)}"}
    end
  end

  defp anthropic_generate(prompt, options) do
    # Setup for Anthropic API call
    api_key = Application.get_env(:frestyl, :anthropic_api_key)
    model = Keyword.get(options, :model, "claude-3-opus-20240229")

    # This would make an actual API call using HTTPoison or similar
    # For now, a simplified implementation
    case HTTPoison.post(
      "https://api.anthropic.com/v1/messages",
      Jason.encode!(%{
        model: model,
        messages: [
          %{role: "user", content: prompt}
        ],
        max_tokens: Keyword.get(options, :max_tokens, 1000),
        temperature: Keyword.get(options, :temperature, 0.7)
      }),
      [
        {"Content-Type", "application/json"},
        {"x-api-key", api_key},
        {"anthropic-version", "2023-06-01"}
      ]
    ) do
      {:ok, %{status_code: 200, body: body}} ->
        response = Jason.decode!(body)
        {:ok, response["content"][0]["text"]}

      {:ok, %{status_code: status_code, body: body}} ->
        {:error, "Anthropic API error: #{status_code} - #{body}"}

      {:error, reason} ->
        {:error, "HTTP error: #{inspect(reason)}"}
    end
  end

  @doc """
  Analyze text for sentiment, topic, or other attributes.
  """
  def analyze_text(text, analysis_type, options \\ []) do
    prompt = case analysis_type do
      :sentiment -> "Analyze the sentiment of the following text: #{text}"
      :topic -> "Identify the main topics in the following text: #{text}"
      :categorize -> "Categorize the following text into one of these categories: #{Keyword.get(options, :categories, "general")}: #{text}"
      _ -> "Analyze the following text: #{text}"
    end

    generate_response(prompt, options)
  end

  @doc """
  Generate user preferences based on onboarding responses.
  """
  def generate_preferences(responses) do
    prompt = """
    Based on the following user responses from an onboarding flow, determine their preferences:

    Primary purpose: #{responses["step_1"] || "N/A"}
    Content interests: #{responses["step_2"] || "N/A"}
    Usage frequency: #{responses["step_3"] || "N/A"}
    Important features: #{responses["step_4"] || "N/A"}
    Guidance preference: #{responses["step_5"] || "N/A"}

    Provide a structured response with:
    1. Content types they're interested in (list)
    2. Features they prioritize (list)
    3. Their experience level (beginner, intermediate, or advanced)
    4. Their guidance preference (guided, self-directed, or balanced)
    5. Their usage frequency (daily, weekly, monthly, or occasional)
    """

    case generate_response(prompt) do
      {:ok, response} -> parse_preference_response(response)
      error -> error
    end
  end

  defp parse_preference_response(response) do
    # In a real implementation, this would parse the AI response
    # For now, a simple implementation
    {:ok, %{
      content_types: ["music", "events"],
      important_features: ["payments", "scheduling"],
      experience_level: "beginner",
      guidance_preference: "guided",
      usage_frequency: "weekly"
    }}
  end

  @doc """
  Generate recommendations based on user preferences.
  """
  def generate_recommendations(preferences) do
    prompt = """
    Generate personalized recommendations for a user with the following preferences:

    Content interests: #{Enum.join(preferences.content_preferences, ", ")}
    Feature priorities: #{Enum.join(preferences.feature_preferences, ", ")}
    Experience level: #{preferences.experience_level}
    Guidance preference: #{preferences.guidance_preference}
    Usage frequency: #{preferences.usage_frequency}

    Provide 3-5 recommendations with:
    1. Category (channel_setup, content, feature)
    2. Title
    3. Brief description
    4. Relevance score (0.0-1.0)
    """

    case generate_response(prompt) do
      {:ok, response} -> parse_recommendations_response(response)
      error -> error
    end
  end

  defp parse_recommendations_response(response) do
    # In a real implementation, this would parse the AI response
    # For now, a simple implementation
    {:ok, [
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
      },
      %{
        category: "feature",
        title: "Set Up Automated Payment Collection",
        description: "Configure your payment settings to automatically collect funds from ticket sales.",
        relevance_score: 0.7
      }
    ]}
  end
end
