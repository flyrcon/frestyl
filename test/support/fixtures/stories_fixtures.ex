# test/support/fixtures/stories_fixtures.ex
defmodule Frestyl.StoriesFixtures do
  @moduledoc """
  This module defines test helpers for creating story entities.
  """

  def story_fixture(attrs \\ %{}) do
    user = if attrs[:created_by_id] do
      %{id: attrs[:created_by_id]}
    else
      Frestyl.AccountsFixtures.user_fixture()
    end

    valid_attrs = %{
      title: "Test Story #{System.unique_integer()}",
      story_type: "novel",
      narrative_structure: "three_act",
      intent_category: "creative_expression",
      creation_source: "test",
      template_data: %{},
      completion_percentage: 0.0,
      current_word_count: 0,
      collaboration_mode: "owner_only",
      workflow_stage: "development",
      approval_status: "draft",
      session_id: Ecto.UUID.generate(),
      created_by_id: user.id
    }

    merged_attrs = Map.merge(valid_attrs, attrs)

    case Frestyl.Stories.create_enhanced_story(merged_attrs, user) do
      {:ok, story} -> story
      {:error, changeset} ->
        raise "Failed to create story fixture: #{inspect(changeset.errors)}"
    end
  end

  def voice_sketch_session_fixture(attrs \\ %{}) do
    user = if attrs[:user_id] do
      %{id: attrs[:user_id]}
    else
      Frestyl.AccountsFixtures.user_fixture()
    end

    valid_attrs = %{
      title: "Test Voice Sketch #{System.unique_integer()}",
      status: "draft",
      duration: 0,
      audio_quality: "standard",
      sketch_strokes: [],
      collaborators: [],
      progress: 0,
      user_id: user.id
    }

    merged_attrs = Map.merge(valid_attrs, attrs)

    # This would create a voice sketch session
    # Implementation depends on your VoiceSketch context
    %{
      id: Ecto.UUID.generate(),
      title: merged_attrs.title,
      status: merged_attrs.status,
      duration: merged_attrs.duration,
      audio_quality: merged_attrs.audio_quality,
      sketch_strokes: merged_attrs.sketch_strokes,
      collaborators: merged_attrs.collaborators,
      progress: merged_attrs.progress,
      user_id: merged_attrs.user_id,
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
  end
end
