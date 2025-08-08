# lib/frestyl/story_engine/collaboration_setup.ex
defmodule Frestyl.StoryEngine.CollaborationSetup do
  @moduledoc """
  Handles collaboration setup for story creation.
  """

  alias Frestyl.Stories.CollaborationWorkflow
  alias Frestyl.Accounts

  def create_collaboration_session(story_id, host_user, collaboration_config) do
    collaboration_type = determine_collaboration_type(collaboration_config)

    case CollaborationWorkflow.create_collaboration_session(story_id, host_user, collaboration_type) do
      {:ok, session} ->
        # Send invitations if specified
        if Map.has_key?(collaboration_config, "invitees") do
          send_collaboration_invites(session.id, collaboration_config["invitees"], host_user)
        end

        # Setup collaboration permissions
        setup_collaboration_permissions(session.id, collaboration_config)

        {:ok, session}

      error -> error
    end
  end

  def get_collaboration_options(format, user_tier) do
    base_options = [
      %{
        type: "solo",
        name: "Solo Writing",
        description: "Work on your story independently",
        max_collaborators: 1,
        features: ["private_drafts", "personal_notes", "backup_sync"]
      },
      %{
        type: "small_team",
        name: "Small Team",
        description: "Collaborate with 2-5 trusted people",
        max_collaborators: 5,
        features: ["real_time_editing", "comment_system", "version_history"]
      }
    ]

    # Add tier-specific options
    enhanced_options = case user_tier do
      tier when tier in ["professional", "enterprise"] ->
        base_options ++ [
          %{
            type: "department",
            name: "Department Team",
            description: "Large team collaboration with roles and permissions",
            max_collaborators: 20,
            features: ["role_management", "approval_workflows", "analytics"]
          },
          %{
            type: "community",
            name: "Open Community",
            description: "Public collaboration with community moderation",
            max_collaborators: :unlimited,
            features: ["public_editing", "community_voting", "moderation_tools"]
          }
        ]

      "creator" ->
        base_options ++ [
          %{
            type: "writing_group",
            name: "Writing Group",
            description: "Structured feedback and critique sessions",
            max_collaborators: 10,
            features: ["critique_tools", "feedback_rounds", "peer_review"]
          }
        ]

      _ -> base_options
    end

    # Filter by format compatibility
    filter_options_by_format(enhanced_options, format)
  end

  defp determine_collaboration_type(config) do
    case config["type"] do
      "small_team" -> "editorial"
      "writing_group" -> "peer_review"
      "department" -> "business_workflow"
      "community" -> "open_collaboration"
      _ -> "standard"
    end
  end

  defp send_collaboration_invites(session_id, invitees, host_user) do
    Enum.each(invitees, fn invitee_email ->
      case Accounts.get_user_by_email(invitee_email) do
        nil ->
          # Send email invitation to join platform
          send_platform_invitation(invitee_email, session_id, host_user)
        user ->
          # Send collaboration invitation to existing user
          send_collaboration_invitation(user, session_id, host_user)
      end
    end)
  end

  defp setup_collaboration_permissions(session_id, config) do
    permissions = %{
      "editing_permissions" => Map.get(config, "editing_permissions", "all_can_edit"),
      "comment_permissions" => Map.get(config, "comment_permissions", "all_can_comment"),
      "invite_permissions" => Map.get(config, "invite_permissions", "host_only"),
      "export_permissions" => Map.get(config, "export_permissions", "host_only")
    }

    # Store permissions in collaboration session
    CollaborationWorkflow.update_session_permissions(session_id, permissions)
  end

  defp filter_options_by_format(options, format) do
    # Some formats work better with specific collaboration types
    format_specific_filter = case format do
      "novel" -> &(&1.type in ["solo", "small_team", "writing_group"])
      "screenplay" -> &(&1.type in ["solo", "small_team", "department"])
      "case_study" -> &(&1.type in ["small_team", "department"])
      "live_story" -> &(&1.type in ["community", "department"])
      _ -> fn _option -> true end
    end

    Enum.filter(options, format_specific_filter)
  end

  defp send_platform_invitation(email, session_id, host_user) do
    # Implementation for inviting non-users
    # Would send email with signup link and collaboration invite
  end

  defp send_collaboration_invitation(user, session_id, host_user) do
    # Implementation for inviting existing users
    # Would send in-app notification and email
  end
end
