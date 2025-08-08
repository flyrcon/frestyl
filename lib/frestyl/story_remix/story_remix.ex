# lib/frestyl/story_remix.ex
defmodule Frestyl.StoryRemix do
  @moduledoc """
  Story Remix - Transform stories between different formats while preserving core narrative.
  """

  alias Frestyl.Stories.EnhancedStoryStructure
  alias Frestyl.StoryEngine.{FormatManager, QuickStartTemplates}

  @supported_remixes %{
    # From -> To mappings with transformation rules
    "case_study" => ["video_script", "podcast_outline", "infographic_story", "social_media_thread"],
    "biography" => ["documentary_outline", "podcast_series", "comic_book", "social_posts"],
    "article" => ["video_script", "podcast_episode", "newsletter", "twitter_thread"],
    "novel" => ["screenplay", "comic_book", "audiobook_script", "podcast_drama"],
    "screenplay" => ["novel", "comic_book", "stage_play", "podcast_drama"]
  }

  def get_remix_options(source_format) do
    Map.get(@supported_remixes, source_format, [])
  end

  def can_remix?(source_format, target_format) do
    target_format in get_remix_options(source_format)
  end

  def create_remix(source_story_id, target_format, user, remix_options \\ %{}) do
    source_story = Frestyl.Repo.get!(EnhancedStoryStructure, source_story_id)

    if can_remix?(source_story.story_type, target_format) do
      # Transform content based on format rules
      remixed_content = transform_content(source_story, target_format, remix_options)

      # Create new story with remixed content
      remix_params = %{
        title: "#{source_story.title} (#{String.capitalize(target_format)})",
        story_type: target_format,
        template_data: remixed_content.template,
        content: remixed_content.content,
        creation_source: "story_remix",
        original_story_id: source_story_id
      }

      case Frestyl.Stories.create_enhanced_story(remix_params, user) do
        {:ok, remixed_story} ->
          # Track remix activity
          track_remix_usage(user.id, source_story.story_type, target_format)
          {:ok, remixed_story}

        error -> error
      end
    else
      {:error, :unsupported_remix}
    end
  end

  defp transform_content(source_story, target_format, options) do
    transformer = get_transformer(source_story.story_type, target_format)
    transformer.(source_story, options)
  end

  defp get_transformer(source_format, target_format) do
    case {source_format, target_format} do
      {"case_study", "video_script"} -> &transform_case_study_to_video/2
      {"biography", "podcast_series"} -> &transform_biography_to_podcast/2
      {"article", "twitter_thread"} -> &transform_article_to_thread/2
      _ -> &default_transformation/2
    end
  end

  defp transform_case_study_to_video(source_story, _options) do
    # Transform case study structure to video script format
    template = QuickStartTemplates.get_template("video_script", "business_growth")

    content = %{
      "hook" => extract_challenge_hook(source_story),
      "problem_setup" => extract_problem_context(source_story),
      "solution_reveal" => extract_solution_approach(source_story),
      "results_showcase" => extract_measurable_outcomes(source_story),
      "call_to_action" => generate_video_cta(source_story)
    }

    %{template: template, content: content}
  end

  defp transform_biography_to_podcast(source_story, _options) do
    template = QuickStartTemplates.get_template("podcast_series", "personal_professional")

    # Break biography into episodic structure
    content = %{
      "episode_1" => %{title: "Early Years", content: extract_early_life(source_story)},
      "episode_2" => %{title: "Turning Points", content: extract_pivotal_moments(source_story)},
      "episode_3" => %{title: "Current Chapter", content: extract_current_situation(source_story)}
    }

    %{template: template, content: content}
  end

  defp transform_article_to_thread(source_story, _options) do
    template = QuickStartTemplates.get_template("twitter_thread", "personal_professional")

    # Break article into tweet-sized chunks
    content = break_into_tweets(source_story.content, 280)

    %{template: template, content: content}
  end

  defp default_transformation(source_story, _options) do
    # Generic transformation that preserves core narrative elements
    %{
      template: %{name: "Remixed Story", outline: []},
      content: %{"original_content" => source_story.content}
    }
  end

  # Helper extraction functions (simplified)
  defp extract_challenge_hook(story), do: "What if I told you..."
  defp extract_problem_context(story), do: "The problem was clear..."
  defp extract_solution_approach(story), do: "Here's how we solved it..."
  defp extract_measurable_outcomes(story), do: "The results were incredible..."
  defp generate_video_cta(story), do: "Want to achieve similar results?"

  defp extract_early_life(story), do: "In the beginning..."
  defp extract_pivotal_moments(story), do: "Then everything changed when..."
  defp extract_current_situation(story), do: "Today, I find myself..."

  defp break_into_tweets(content, max_length) do
    # Simple implementation - would be more sophisticated in production
    content
    |> String.split(". ")
    |> Enum.chunk_every(2)
    |> Enum.map(&Enum.join(&1, ". "))
    |> Enum.with_index()
    |> Enum.map(fn {chunk, index} ->
      %{"tweet_#{index + 1}" => String.slice(chunk, 0, max_length)}
    end)
    |> Enum.reduce(%{}, &Map.merge/2)
  end

  defp track_remix_usage(user_id, source_format, target_format) do
    # Analytics tracking for remix usage
    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "story_remix_analytics",
      {:remix_created, user_id, source_format, target_format}
    )
  end
end
