# lib/frestyl/channels/ai_client.ex
defmodule Frestyl.Channels.AIClient do
  @moduledoc """
  Client for interacting with AI services for channel categorization.
  """

  # Replace with your actual AI service API key and endpoint
  @ai_api_key System.get_env("AI_SERVICE_API_KEY")
  @ai_endpoint System.get_env("AI_SERVICE_ENDPOINT", "https://api.example.com/categorize")

  # Suggested categories for the application
  @available_categories [
    "Technology",
    "Marketing",
    "Design",
    "Business",
    "Education",
    "Entertainment",
    "Gaming",
    "Health & Wellness",
    "Finance",
    "Social",
    "Project Management",
    "Customer Support",
    "Research",
    "Other"
  ]

  @doc """
  Request AI service to suggest categories for a channel.
  Falls back to simple pattern matching if AI service is not available.
  """
  def suggest_categories(name, description) do
    case request_ai_suggestions(name, description) do
      {:ok, suggestions} ->
        suggestions

      {:error, _reason} ->
        # Fallback to simple pattern matching
        fallback_suggest_categories(name, description)
    end
  end

  # Makes an HTTP request to the AI service
  defp request_ai_suggestions(name, description) do
    if @ai_api_key do
      # This is a placeholder for actual HTTP client code
      # In a real implementation, you would use HTTPoison or similar
      # to make a request to your AI service

      # Mock implementation for now
      {:error, "AI service not configured"}
    else
      {:error, "AI service API key not configured"}
    end
  end

  # Fallback implementation using simple pattern matching
  defp fallback_suggest_categories(name, description) do
    name = String.downcase(name || "")
    description = String.downcase(description || "")

    combined_text = name <> " " <> description

    # Simple keyword matching - in a real app, you would want more sophisticated logic
    suggested_category = cond do
      String.contains?(combined_text, "tech") or
      String.contains?(combined_text, "programming") or
      String.contains?(combined_text, "developer") ->
        "Technology"

      String.contains?(combined_text, "market") or
      String.contains?(combined_text, "advertising") or
      String.contains?(combined_text, "promotion") ->
        "Marketing"

      String.contains?(combined_text, "design") or
      String.contains?(combined_text, "ui") or
      String.contains?(combined_text, "ux") or
      String.contains?(combined_text, "graphic") ->
        "Design"

      String.contains?(combined_text, "business") or
      String.contains?(combined_text, "startup") or
      String.contains?(combined_text, "entrepreneur") ->
        "Business"

      String.contains?(combined_text, "education") or
      String.contains?(combined_text, "learn") or
      String.contains?(combined_text, "training") or
      String.contains?(combined_text, "course") ->
        "Education"

      String.contains?(combined_text, "entertainment") or
      String.contains?(combined_text, "fun") or
      String.contains?(combined_text, "media") ->
        "Entertainment"

      String.contains?(combined_text, "game") or
      String.contains?(combined_text, "gaming") or
      String.contains?(combined_text, "play") ->
        "Gaming"

      String.contains?(combined_text, "health") or
      String.contains?(combined_text, "wellness") or
      String.contains?(combined_text, "fitness") ->
        "Health & Wellness"

      true ->
        "Other"
    end

    # Return the suggestion and full list of available categories
    %{
      suggested_category: suggested_category,
      available_categories: @available_categories
    }
  end
end
