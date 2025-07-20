# lib/frestyl/stories/visual_ai_generator.ex
defmodule Frestyl.Stories.VisualAIGenerator do
  @moduledoc """
  AI-powered visual content generation for storyboards and comics
  """

  alias Frestyl.Stories.AIGeneration

  def generate_storyboard_image(story_id, shot_data, user) do
    prompt = build_storyboard_prompt(shot_data)

    # Create AI generation record
    generation_attrs = %{
      generation_type: "image",
      prompt: prompt,
      context: %{
        shot_type: shot_data.shot_type,
        description: shot_data.description,
        camera_movement: shot_data.camera_movement
      },
      story_id: story_id,
      user_id: user.id
    }

    with {:ok, generation} <- create_ai_generation(generation_attrs),
         {:ok, image_result} <- call_ai_image_service(prompt, shot_data) do

      # Update generation with result
      updated_generation =
        generation
        |> AIGeneration.changeset(%{
          result: image_result,
          status: "completed"
        })
        |> Frestyl.Repo.update!()

      {:ok, updated_generation}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def generate_comic_panel(story_id, panel_data, user, style_guide \\ %{}) do
    prompt = build_comic_panel_prompt(panel_data, style_guide)

    generation_attrs = %{
      generation_type: "image",
      prompt: prompt,
      context: %{
        panel_type: panel_data.type,
        page_number: panel_data.page,
        panel_number: panel_data.panel,
        style_guide: style_guide
      },
      story_id: story_id,
      user_id: user.id
    }

    with {:ok, generation} <- create_ai_generation(generation_attrs),
         {:ok, image_result} <- call_ai_image_service(prompt, panel_data) do

      updated_generation =
        generation
        |> AIGeneration.changeset(%{
          result: image_result,
          status: "completed"
        })
        |> Frestyl.Repo.update!()

      {:ok, updated_generation}
    end
  end

  def generate_character_design(story_id, character_data, user) do
    prompt = build_character_prompt(character_data)

    generation_attrs = %{
      generation_type: "image",
      prompt: prompt,
      context: %{
        character_name: character_data.name,
        character_type: "design",
        description: character_data.description
      },
      story_id: story_id,
      user_id: user.id
    }

    with {:ok, generation} <- create_ai_generation(generation_attrs),
         {:ok, image_result} <- call_ai_image_service(prompt, character_data) do

      updated_generation =
        generation
        |> AIGeneration.changeset(%{
          result: image_result,
          status: "completed"
        })
        |> Frestyl.Repo.update!()

      {:ok, updated_generation}
    end
  end

  defp build_storyboard_prompt(shot_data) do
    base_prompt = "Professional storyboard frame: #{shot_data.description}"

    shot_type_addition = case shot_data.shot_type do
      :wide_shot -> ", wide establishing shot"
      :medium_shot -> ", medium shot composition"
      :close_up -> ", close-up shot"
      :extreme_close_up -> ", extreme close-up"
      _ -> ""
    end

    camera_addition = case shot_data.camera_movement do
      :static -> ", static camera"
      :pan_left -> ", panning left"
      :pan_right -> ", panning right"
      :tilt_up -> ", tilting up"
      :tilt_down -> ", tilting down"
      :dolly_in -> ", dolly shot moving in"
      :dolly_out -> ", dolly shot pulling back"
      _ -> ""
    end

    "#{base_prompt}#{shot_type_addition}#{camera_addition}, black and white sketch style, professional storyboard illustration"
  end

  defp build_comic_panel_prompt(panel_data, style_guide) do
    base_prompt = "Comic book panel: #{panel_data.description}"

    style_addition = case style_guide do
      %{art_style: style} when style != nil -> ", #{style} art style"
      _ -> ", professional comic book art style"
    end

    panel_type_addition = case panel_data.type do
      :splash_page -> ", full page splash panel"
      :action_sequence -> ", dynamic action scene"
      :dialogue_scene -> ", character dialogue scene"
      :establishing_shot -> ", establishing shot panel"
      _ -> ""
    end

    "#{base_prompt}#{style_addition}#{panel_type_addition}, comic book illustration, professional comic art"
  end

  defp build_character_prompt(character_data) do
    "Character design: #{character_data.description}, #{character_data.name}, full body character sheet, professional character design, multiple angles"
  end

  defp call_ai_image_service(prompt, context) do
    # Placeholder for actual AI service integration
    # This would call OpenAI DALL-E, Midjourney, Stable Diffusion, etc.

    # Simulate AI response
    {:ok, %{
      image_url: "https://example.com/generated-image-#{Ecto.UUID.generate()}.png",
      prompt_used: prompt,
      model: "dall-e-3",
      generation_time: 3.2,
      cost: 0.04
    }}
  end

  defp create_ai_generation(attrs) do
    %AIGeneration{}
    |> AIGeneration.changeset(attrs)
    |> Frestyl.Repo.insert()
  end

  # Batch generation for sequences
  def generate_storyboard_sequence(story_id, shots, user) do
    shots
    |> Enum.with_index()
    |> Enum.map(fn {shot, index} ->
      # Add sequence context to each shot
      enhanced_shot = Map.put(shot, :sequence_position, index)
      generate_storyboard_image(story_id, enhanced_shot, user)
    end)
    |> Enum.reduce({[], []}, fn result, {successes, errors} ->
      case result do
        {:ok, generation} -> {[generation | successes], errors}
        {:error, error} -> {successes, [error | errors]}
      end
    end)
    |> case do
      {successes, []} -> {:ok, Enum.reverse(successes)}
      {successes, errors} -> {:partial_success, Enum.reverse(successes), errors}
    end
  end

  # Style consistency for comics
  def apply_style_consistency(generations, style_guide) do
    # This would analyze existing generations and ensure new ones match
    # the established visual style
    Enum.map(generations, fn generation ->
      enhance_generation_with_style(generation, style_guide)
    end)
  end

  defp enhance_generation_with_style(generation, style_guide) do
    # Apply style guide rules to existing generation
    generation
  end
end
