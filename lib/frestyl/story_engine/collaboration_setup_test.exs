# test/frestyl/story_engine/collaboration_setup_test.exs
defmodule Frestyl.StoryEngine.CollaborationSetupTest do
  use Frestyl.DataCase

  alias Frestyl.StoryEngine.CollaborationSetup
  import Frestyl.AccountsFixtures
  import Frestyl.StoriesFixtures

  describe "collaboration setup" do
    setup do
      user = user_fixture()
      story = story_fixture(%{created_by_id: user.id})
      %{user: user, story: story}
    end

    test "get_collaboration_options returns tier-appropriate options", %{user: user} do
      personal_options = CollaborationSetup.get_collaboration_options("novel", "personal")
      professional_options = CollaborationSetup.get_collaboration_options("novel", "professional")

      # Personal tier should have basic options
      option_types = Enum.map(personal_options, & &1.type)
      assert "solo" in option_types
      assert "small_team" in option_types

      # Professional tier should have advanced options
      pro_option_types = Enum.map(professional_options, & &1.type)
      assert "department" in pro_option_types
      assert "community" in pro_option_types
    end

    test "collaboration options are filtered by format compatibility" do
      novel_options = CollaborationSetup.get_collaboration_options("novel", "professional")
      live_story_options = CollaborationSetup.get_collaboration_options("live_story", "professional")

      novel_types = Enum.map(novel_options, & &1.type)
      live_story_types = Enum.map(live_story_options, & &1.type)

      # Novel should not include community collaboration
      refute "community" in novel_types

      # Live story should include community collaboration
      assert "community" in live_story_types
    end

    test "creator tier gets writing group option for compatible formats" do
      options = CollaborationSetup.get_collaboration_options("novel", "creator")

      option_types = Enum.map(options, & &1.type)
      assert "writing_group" in option_types

      # Find the writing group option
      writing_group = Enum.find(options, & &1.type == "writing_group")
      assert writing_group.max_collaborators == 10
      assert "critique_tools" in writing_group.features
    end

    test "collaboration options include expected features" do
      options = CollaborationSetup.get_collaboration_options("case_study", "professional")

      # Find department option
      department_option = Enum.find(options, & &1.type == "department")
      assert department_option != nil
      assert "role_management" in department_option.features
      assert "approval_workflows" in department_option.features
    end

    test "solo option is always available" do
      formats = ["novel", "case_study", "live_story", "biography"]
      tiers = ["personal", "creator", "professional"]

      for format <- formats, tier <- tiers do
        options = CollaborationSetup.get_collaboration_options(format, tier)
        option_types = Enum.map(options, & &1.type)
        assert "solo" in option_types, "Solo option missing for #{format} on #{tier} tier"
      end
    end

    test "collaboration type determination works correctly" do
      # Test private function indirectly through create_collaboration_session
      config = %{"type" => "small_team"}
      collaboration_type = CollaborationSetup.determine_collaboration_type(config)
      assert collaboration_type == "editorial"

      config = %{"type" => "community"}
      collaboration_type = CollaborationSetup.determine_collaboration_type(config)
      assert collaboration_type == "open_collaboration"
    end
  end
end
