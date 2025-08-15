# Team Assignment LiveView for Channel Management
# File: lib/frestyl_web/live/channel_team_management_live.ex

defmodule FrestylWeb.ChannelTeamManagementLive do
  use FrestylWeb, :live_view
  alias Frestyl.Teams
  alias Frestyl.Channels
  alias Frestyl.Teams.RatingDimensionConfig

  @impl true
  def mount(%{"channel_id" => channel_id}, _session, socket) do
    channel = Channels.get_channel!(channel_id)
    current_user = socket.assigns.current_user

    # Check if user is channel admin or supervisor
    unless can_manage_teams?(current_user, channel) do
      raise FrestylWeb.NotAuthorizedError
    end

    socket =
      socket
      |> assign(:channel, channel)
      |> assign(:current_user, current_user)
      |> assign(:teams, Teams.list_channel_teams(channel_id))
      |> assign(:channel_members, Channels.list_channel_members(channel_id))
      |> assign(:unassigned_members, get_unassigned_members(channel_id))
      |> assign(:show_create_team_modal, false)
      |> assign(:show_assignment_modal, false)
      |> assign(:selected_team, nil)
      |> assign(:assignment_mode, "individual") # individual or bulk
      |> assign(:rating_dimensions, RatingDimensionConfig.get_all_categories())

    {:ok, socket}
  end

  @impl true
  def handle_event("show_create_team_modal", _params, socket) do
    {:noreply, assign(socket, :show_create_team_modal, true)}
  end

  def handle_event("hide_create_team_modal", _params, socket) do
    {:noreply, assign(socket, :show_create_team_modal, false)}
  end

  def handle_event("create_team", %{"team" => team_params}, socket) do
    channel_id = socket.assigns.channel.id
    creator_id = socket.assigns.current_user.id

    # Add default rating config based on organization type
    rating_config = %{
      "organization_type" => team_params["organization_type"] || "academic",
      "primary_dimension" => "quality",
      "secondary_dimension" => get_default_secondary_dimension(team_params["organization_type"]),
      "rating_frequency" => "milestone_based",
      "intervention_thresholds" => %{
        "sentiment_deviation" => 2.0,
        "collaboration_variance" => 3.0,
        "completion_threshold" => 50
      }
    }

    team_attrs = Map.merge(team_params, %{"rating_config" => rating_config})

    case Teams.create_team(channel_id, creator_id, team_attrs) do
      {:ok, team} ->
        {:noreply,
         socket
         |> assign(:show_create_team_modal, false)
         |> assign(:teams, Teams.list_channel_teams(channel_id))
         |> put_flash(:info, "Team '#{team.name}' created successfully!")}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create team. Please check your input.")}
    end
  end

  def handle_event("show_assignment_modal", %{"team-id" => team_id}, socket) do
    team = Teams.get_team!(team_id)

    {:noreply,
     socket
     |> assign(:show_assignment_modal, true)
     |> assign(:selected_team, team)}
  end

  def handle_event("hide_assignment_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_assignment_modal, false)
     |> assign(:selected_team, nil)}
  end

  def handle_event("assign_member", %{"user-id" => user_id, "team-id" => team_id, "role" => role}, socket) do
    case Teams.assign_to_team(team_id, user_id, role, socket.assigns.current_user.id) do
      {:ok, _membership} ->
        {:noreply,
         socket
         |> refresh_data()
         |> put_flash(:info, "Member assigned successfully!")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to assign member to team.")}
    end
  end

  def handle_event("remove_member", %{"user-id" => user_id, "team-id" => team_id}, socket) do
    case Teams.remove_from_team(team_id, user_id) do
      {1, _} ->
        {:noreply,
         socket
         |> refresh_data()
         |> put_flash(:info, "Member removed from team.")}

      _ ->
        {:noreply, put_flash(socket, :error, "Failed to remove member from team.")}
    end
  end

  def handle_event("bulk_assign", %{"assignments" => assignments}, socket) do
    team_id = socket.assigns.selected_team.id

    results = Enum.map(assignments, fn {user_id, role} ->
      Teams.assign_to_team(team_id, user_id, role, socket.assigns.current_user.id)
    end)

    success_count = Enum.count(results, fn {status, _} -> status == :ok end)

    {:noreply,
     socket
     |> assign(:show_assignment_modal, false)
     |> refresh_data()
     |> put_flash(:info, "#{success_count} members assigned successfully!")}
  end

  def handle_event("update_team_config", %{"team_id" => team_id, "config" => config}, socket) do
    team = Teams.get_team!(team_id)

    updated_config = Map.merge(team.rating_config || %{}, config)

    case Teams.update_team(team, %{rating_config: updated_config}) do
      {:ok, _team} ->
        {:noreply,
         socket
         |> refresh_data()
         |> put_flash(:info, "Team configuration updated!")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update team configuration.")}
    end
  end

  def handle_event("delete_team", %{"team-id" => team_id}, socket) do
    team = Teams.get_team!(team_id)

    case Teams.delete_team(team) do
      {:ok, _team} ->
        {:noreply,
         socket
         |> refresh_data()
         |> put_flash(:info, "Team deleted successfully.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to delete team.")}
    end
  end

  def handle_event("auto_assign_teams", %{"strategy" => strategy}, socket) do
    channel_id = socket.assigns.channel.id
    unassigned = socket.assigns.unassigned_members

    case auto_assign_strategy(strategy, unassigned, socket.assigns.teams) do
      {:ok, assignments} ->
        apply_auto_assignments(assignments)

        {:noreply,
         socket
         |> refresh_data()
         |> put_flash(:info, "Auto-assignment completed!")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, reason)}
    end
  end

  # Helper Functions

  defp can_manage_teams?(user, channel) do
    # Check if user is channel admin, supervisor, or has manage_teams permission
    membership = Channels.get_channel_membership(user.id, channel.id)
    membership && membership.role in ["admin", "moderator"]
  end

  defp get_unassigned_members(channel_id) do
    all_members = Channels.list_channel_members(channel_id)
    teams = Teams.list_channel_teams(channel_id)

    assigned_user_ids = teams
                       |> Enum.flat_map(& &1.members)
                       |> Enum.map(& &1.id)
                       |> Enum.uniq()

    Enum.reject(all_members, &(&1.id in assigned_user_ids))
  end

  defp get_default_secondary_dimension(organization_type) do
    case organization_type do
      "academic" -> "collaboration_effectiveness"
      "creative" -> "innovation_level"
      "business" -> "commercial_viability"
      "technical" -> "technical_execution"
      _ -> "collaboration_effectiveness"
    end
  end

  defp refresh_data(socket) do
    channel_id = socket.assigns.channel.id

    socket
    |> assign(:teams, Teams.list_channel_teams(channel_id))
    |> assign(:unassigned_members, get_unassigned_members(channel_id))
  end

  defp auto_assign_strategy("balanced", unassigned_members, teams) do
    if length(teams) == 0 do
      {:error, "No teams available for assignment"}
    else
      # Distribute members evenly across teams
      team_assignments = unassigned_members
                        |> Enum.with_index()
                        |> Enum.map(fn {member, index} ->
                          team = Enum.at(teams, rem(index, length(teams)))
                          {member.id, team.id, "member"}
                        end)

      {:ok, team_assignments}
    end
  end

  defp auto_assign_strategy("random", unassigned_members, teams) do
    if length(teams) == 0 do
      {:error, "No teams available for assignment"}
    else
      # Randomly assign members to teams
      team_assignments = Enum.map(unassigned_members, fn member ->
        team = Enum.random(teams)
        {member.id, team.id, "member"}
      end)

      {:ok, team_assignments}
    end
  end

  defp auto_assign_strategy("skill_based", unassigned_members, teams) do
    # TODO: Implement skill-based assignment using user profile data
    {:error, "Skill-based assignment not yet implemented"}
  end

  defp apply_auto_assignments(assignments) do
    Enum.each(assignments, fn {user_id, team_id, role} ->
      Teams.assign_to_team(team_id, user_id, role)
    end)
  end

  defp get_team_member_count(team) do
    length(team.members || [])
  end

  defp get_team_completion_color(percentage) do
    cond do
      percentage >= 80 -> "text-green-600 bg-green-100"
      percentage >= 60 -> "text-yellow-600 bg-yellow-100"
      percentage >= 40 -> "text-orange-600 bg-orange-100"
      true -> "text-red-600 bg-red-100"
    end
  end
end
