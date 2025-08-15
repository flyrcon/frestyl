# Authentication Implementation Guide
# File: lib/frestyl/auth.ex and related files

# ============================================================================
# 1. USER ROLES AND PERMISSIONS
# ============================================================================

defmodule Frestyl.Auth do
  @moduledoc """
  Authentication and authorization for the team collaboration system.
  """

  @doc """
  User roles in the system:
  - student: Can participate in teams, submit ratings, view own data
  - instructor: Can create teams, view team analytics, manage students
  - supervisor: Can oversee multiple instructors, access cross-team analytics
  - admin: Full system access, user management, system configuration
  """

  def user_roles do
    ~w(student instructor supervisor admin)a
  end

  @doc """
  Check if user can access supervisor dashboard.
  """
  def can_access_supervisor_dashboard?(%{role: role}) do
    role in [:instructor, :supervisor, :admin]
  end

  @doc """
  Check if user can manage teams in a channel.
  """
  def can_manage_teams?(%{role: role, id: user_id}, channel_id) do
    case role do
      :admin -> true
      :supervisor -> true
      :instructor -> is_channel_instructor?(channel_id, user_id)
      _ -> false
    end
  end

  @doc """
  Check if user can view team analytics.
  """
  def can_view_team_analytics?(%{role: role, id: user_id}, team_id) do
    case role do
      :admin -> true
      :supervisor -> true
      :instructor -> is_team_instructor?(team_id, user_id)
      _ -> false
    end
  end

  defp is_channel_instructor?(channel_id, user_id) do
    # Check if user is instructor for this channel
    Frestyl.Channels.is_instructor?(channel_id, user_id)
  end

  defp is_team_instructor?(team_id, user_id) do
    # Check if user is supervisor for this team
    case Frestyl.Teams.get_team(team_id) do
      %{supervisor_id: ^user_id} -> true
      _ -> false
    end
  end
end
