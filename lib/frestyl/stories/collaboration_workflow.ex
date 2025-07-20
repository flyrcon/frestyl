# lib/frestyl/stories/collaboration_workflow.ex
defmodule Frestyl.Stories.CollaborationWorkflow do
  @moduledoc """
  Enhanced collaboration system supporting different creative roles and workflows
  """

  alias Frestyl.Stories.EnhancedStoryStructure
  alias Frestyl.Accounts.User
  alias Frestyl.PubSub

  def create_collaboration_session(story_id, host_user, collaboration_type \\ "standard") do
    story = Frestyl.Repo.get!(EnhancedStoryStructure, story_id)

    session_data = %{
      id: Ecto.UUID.generate(),
      story_id: story_id,
      host_user_id: host_user.id,
      collaboration_type: collaboration_type,
      active_users: [host_user.id],
      created_at: DateTime.utc_now(),
      status: "active",
      workflow_data: initialize_workflow_data(story.story_type, collaboration_type)
    }

    # Broadcast session creation
    PubSub.broadcast(
      Frestyl.PubSub,
      "story:#{story_id}",
      {:collaboration_session_created, session_data}
    )

    {:ok, session_data}
  end

  defp initialize_workflow_data("comic_book", "artist_writer") do
    %{
      stages: ["script", "thumbnails", "pencils", "inks", "colors", "letters"],
      current_stage: "script",
      assignments: %{},
      approvals: %{},
      revisions: []
    }
  end

  defp initialize_workflow_data("screenplay", "production") do
    %{
      stages: ["script", "notes", "revision", "table_read", "final"],
      current_stage: "script",
      read_through_mode: false,
      scene_assignments: %{},
      revision_notes: []
    }
  end

  defp initialize_workflow_data("novel", "editorial") do
    %{
      stages: ["draft", "developmental_edit", "line_edit", "copy_edit", "proof"],
      current_stage: "draft",
      edit_assignments: %{},
      track_changes: true,
      comment_threads: []
    }
  end

  defp initialize_workflow_data(_, _) do
    %{
      stages: ["development", "review", "revision", "final"],
      current_stage: "development",
      permissions: %{},
      real_time_cursors: true
    }
  end

  def add_collaborator(session_id, user, role \\ "collaborator") do
    # Add user to collaboration session with specific role
    session_data = get_session(session_id)

    updated_session = %{session_data |
      active_users: [user.id | session_data.active_users],
      workflow_data: Map.put(session_data.workflow_data, "user_roles",
        Map.put(session_data.workflow_data["user_roles"] || %{}, user.id, role))
    }

    # Broadcast user joined
    PubSub.broadcast(
      Frestyl.PubSub,
      "collaboration:#{session_id}",
      {:user_joined, user, role}
    )

    {:ok, updated_session}
  end

  def assign_workflow_task(session_id, user_id, task_type, task_data) do
    session_data = get_session(session_id)

    task = %{
      id: Ecto.UUID.generate(),
      type: task_type,
      assigned_to: user_id,
      data: task_data,
      status: "assigned",
      created_at: DateTime.utc_now()
    }

    # Broadcast task assignment
    PubSub.broadcast(
      Frestyl.PubSub,
      "collaboration:#{session_id}",
      {:task_assigned, task}
    )

    {:ok, task}
  end

  defp get_session(session_id) do
    # Placeholder - would retrieve from session store
    %{id: session_id, active_users: [], workflow_data: %{}}
  end
end
