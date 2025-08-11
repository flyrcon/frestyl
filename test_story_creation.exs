# Test script to verify the personal workspace and session creation
# You can run this in IEx to test the implementation

defmodule StoryCreationTest do
  @moduledoc """
  Test module to verify story creation workflow works end-to-end
  """

  def test_personal_workspace_creation(user) do
    IO.puts("Testing personal workspace creation for user: #{user.username}")

    case Frestyl.Channels.get_or_create_personal_workspace(user) do
      {:ok, workspace} ->
        IO.puts("✅ Personal workspace created: #{workspace.title}")
        IO.puts("   ID: #{workspace.id}")
        IO.puts("   Type: #{workspace.channel_type}")
        {:ok, workspace}

      {:error, error} ->
        IO.puts("❌ Failed to create personal workspace")
        IO.inspect(error, label: "Error")
        {:error, error}
    end
  end

  def test_session_creation(user, workspace) do
    IO.puts("Testing session creation in workspace: #{workspace.title}")

    session_params = %{
      "title" => "Test Story Session",
      "session_type" => "regular",
      "channel_id" => workspace.id,
      "creator_id" => user.id
    }

    case Frestyl.Sessions.create_story_session(session_params, user) do
      {:ok, session} ->
        IO.puts("✅ Session created: #{session.title}")
        IO.puts("   ID: #{session.id}")
        IO.puts("   Type: #{session.session_type}")
        {:ok, session}

      {:error, error} ->
        IO.puts("❌ Failed to create session")
        IO.inspect(error, label: "Error")
        {:error, error}
    end
  end

  def test_story_creation(user, session) do
    IO.puts("Testing story creation with session: #{session.id}")

    story_params = %{
      title: "Test Novel",
      story_type: "novel",
      intent_category: "entertain",
      session_id: session.id,
      creation_source: "story_engine_hub",
      created_by_id: user.id,
      collaboration_mode: "owner_only"
    }

    case Frestyl.Stories.create_story_for_engine(story_params, user) do
      {:ok, story} ->
        IO.puts("✅ Story created: #{story.title}")
        IO.puts("   ID: #{story.id}")
        IO.puts("   Type: #{story.story_type}")
        IO.puts("   Session: #{story.session_id}")
        {:ok, story}

      {:error, error} ->
        IO.puts("❌ Failed to create story")
        IO.inspect(error, label: "Error")
        {:error, error}
    end
  end

  def run_full_test(user) do
    IO.puts("🧪 Running full story creation test workflow")
    IO.puts("=" <> String.duplicate("=", 50))

    with {:ok, workspace} <- test_personal_workspace_creation(user),
         {:ok, session} <- test_session_creation(user, workspace),
         {:ok, story} <- test_story_creation(user, session) do

      IO.puts("\n🎉 All tests passed! Story creation workflow is working.")
      IO.puts("Story URL: /stories/#{story.id}/edit")

      {:ok, %{workspace: workspace, session: session, story: story}}
    else
      error ->
        IO.puts("\n💥 Test failed at some step")
        error
    end
  end

  def quick_test do
    IO.puts("To test this implementation:")
    IO.puts("1. Start your Phoenix server")
    IO.puts("2. Open IEx and run:")
    IO.puts("   user = Frestyl.Accounts.get_user!(1)  # or any valid user ID")
    IO.puts("   StoryCreationTest.run_full_test(user)")
    IO.puts("")
    IO.puts("This will test the complete workflow and show any remaining issues.")
  end
end

# Usage instructions:
# 1. Make sure your Phoenix app is running
# 2. In IEx:
#    user = Frestyl.Accounts.get_user!(1)  # Replace with valid user
#    StoryCreationTest.run_full_test(user)
