# lib/frestyl/studio/portfolio_collaboration_manager.ex
defmodule Frestyl.Studio.PortfolioCollaborationManager do
  @moduledoc """
  Manages real-time collaborative portfolio editing with operational transforms,
  presence tracking, and granular section-level permissions.
  """

  require Logger
  alias Frestyl.{Presence, Portfolios}
  alias Frestyl.Studio.CollaborationManager
  alias Phoenix.PubSub

  @doc """
  Setup real-time subscriptions for portfolio collaboration.
  """
  def setup_portfolio_subscriptions(portfolio_id, user_id, section_id \\ nil) do
    # Subscribe to portfolio-level collaboration
    PubSub.subscribe(Frestyl.PubSub, "portfolio:#{portfolio_id}")
    PubSub.subscribe(Frestyl.PubSub, "portfolio:#{portfolio_id}:presence")
    PubSub.subscribe(Frestyl.PubSub, "portfolio:#{portfolio_id}:operations")

    # Subscribe to user-specific notifications
    PubSub.subscribe(Frestyl.PubSub, "user:#{user_id}:portfolio_invites")

    # Subscribe to section-specific collaboration if provided
    if section_id do
      PubSub.subscribe(Frestyl.PubSub, "portfolio:#{portfolio_id}:section:#{section_id}")
    end
  end

  @doc """
  Track user presence in portfolio with collaboration metadata.
  """
  def track_portfolio_presence(portfolio_id, user, permissions, device_info) do
    presence_data = %{
      user_id: user.id,
      username: user.username || user.email,
      avatar_url: user.avatar_url,
      joined_at: DateTime.utc_now(),
      permissions: permissions,
      active_section: nil,
      is_typing: false,
      last_activity: DateTime.utc_now(),
      device_type: device_info.device_type || "desktop",
      is_mobile: device_info.is_mobile || false,
      editing_state: %{
        section_id: nil,
        cursor_position: nil,
        selection_range: nil
      }
    }

    {:ok, _} = Presence.track(
      self(),
      "portfolio:#{portfolio_id}:presence",
      to_string(user.id),
      presence_data
    )
  end

  @doc """
  Update user's active section and editing state.
  """
  def update_editing_state(portfolio_id, user_id, section_id, editing_data \\ %{}) do
    updates = %{
      active_section: section_id,
      last_activity: DateTime.utc_now(),
      editing_state: Map.merge(%{
        section_id: section_id,
        cursor_position: editing_data[:cursor_position],
        selection_range: editing_data[:selection_range]
      }, editing_data)
    }

    case Presence.get_by_key("portfolio:#{portfolio_id}:presence", to_string(user_id)) do
      %{metas: [meta | _]} ->
        new_meta = Map.merge(meta, updates)
        Presence.update(self(), "portfolio:#{portfolio_id}:presence", to_string(user_id), new_meta)

        # Broadcast section lock/unlock
        broadcast_section_activity(portfolio_id, section_id, user_id, :editing)

      _ ->
        Logger.warn("Could not update editing state for user #{user_id} in portfolio #{portfolio_id}")
        nil
    end
  end

  @doc """
  Apply operational transform to portfolio content.
  """
  def apply_operation(portfolio_id, section_id, operation, user_id) do
    # Validate user permissions for this section
    case validate_section_permissions(portfolio_id, section_id, user_id, :edit) do
      {:ok, _permissions} ->
        # Apply operation with conflict resolution
        case apply_ot_operation(portfolio_id, section_id, operation) do
          {:ok, transformed_op, new_state} ->
            # Broadcast operation to other collaborators
            broadcast_operation(portfolio_id, section_id, transformed_op, user_id)

            # Track editing activity for analytics
            track_collaboration_activity(portfolio_id, section_id, user_id, :edit, operation)

            {:ok, new_state}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Create collaboration invitation for portfolio.
  """
  def create_portfolio_invitation(portfolio_id, inviting_user, invitee_email, permissions) do
    portfolio = Portfolios.get_portfolio!(portfolio_id)

    # Validate inviting user permissions
    case validate_portfolio_permissions(portfolio, inviting_user.id, :invite) do
      {:ok, _} ->
        invitation = %{
          portfolio_id: portfolio_id,
          inviting_user_id: inviting_user.id,
          invitee_email: invitee_email,
          permissions: normalize_permissions(permissions, inviting_user),
          token: generate_invitation_token(),
          expires_at: DateTime.add(DateTime.utc_now(), 7 * 24 * 3600, :second),
          created_at: DateTime.utc_now(),
          status: :pending
        }

        # Send invitation email
        send_portfolio_invitation_email(invitation, portfolio, inviting_user)

        # Store invitation in ETS for quick lookup
        :ets.insert(:portfolio_invitations, {invitation.token, invitation})

        {:ok, invitation}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Accept portfolio collaboration invitation.
  """
  def accept_invitation(token, accepting_user) do
    case :ets.lookup(:portfolio_invitations, token) do
      [{^token, invitation}] ->
        if DateTime.compare(invitation.expires_at, DateTime.utc_now()) == :gt do
          # Create collaboration session
          session = %{
            portfolio_id: invitation.portfolio_id,
            user_id: accepting_user.id,
            permissions: invitation.permissions,
            invited_by: invitation.inviting_user_id,
            joined_at: DateTime.utc_now(),
            status: :active
          }

          # Remove invitation from ETS
          :ets.delete(:portfolio_invitations, token)

          # Notify portfolio owner
          notify_collaboration_joined(invitation.portfolio_id, accepting_user, invitation.inviting_user_id)

          {:ok, session}
        else
          {:error, :invitation_expired}
        end

      [] ->
        {:error, :invitation_not_found}
    end
  end

  @doc """
  Get collaboration analytics for portfolio.
  """
  def get_collaboration_analytics(portfolio_id, timeframe \\ :week) do
    case :ets.lookup(:portfolio_analytics, portfolio_id) do
      [{^portfolio_id, analytics}] ->
        filter_analytics_by_timeframe(analytics, timeframe)

      [] ->
        %{
          total_collaborators: 0,
          active_sessions: 0,
          edit_count: 0,
          session_duration: 0,
          most_edited_sections: []
        }
    end
  end

  # Private Functions

  defp apply_ot_operation(portfolio_id, section_id, operation) do
    # Simple operational transform - in production, use a proper OT library
    case get_section_state(portfolio_id, section_id) do
      {:ok, current_state} ->
        case transform_operation(operation, current_state) do
          {:ok, transformed_op} ->
            new_state = apply_operation_to_state(transformed_op, current_state)
            update_section_state(portfolio_id, section_id, new_state)
            {:ok, transformed_op, new_state}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp transform_operation(operation, state) do
    # Implement operational transform logic based on operation type
    case operation.type do
      :insert ->
        # Transform insert operation based on concurrent operations
        {:ok, adjust_insert_position(operation, state)}

      :delete ->
        # Transform delete operation
        {:ok, adjust_delete_range(operation, state)}

      :retain ->
        # Retain operations typically don't need transformation
        {:ok, operation}

      _ ->
        {:error, :unsupported_operation}
    end
  end

  defp adjust_insert_position(operation, state) do
    # Adjust insert position based on concurrent operations
    # This is a simplified implementation
    %{operation | position: operation.position + get_position_offset(state, operation.position)}
  end

  defp adjust_delete_range(operation, state) do
    # Adjust delete range based on concurrent operations
    %{operation |
      start: operation.start + get_position_offset(state, operation.start),
      end: operation.end + get_position_offset(state, operation.end)
    }
  end

  defp get_position_offset(state, position) do
    # Calculate position offset based on concurrent operations
    # This would be more sophisticated in a real OT implementation
    Map.get(state.position_offsets, position, 0)
  end

  defp apply_operation_to_state(operation, state) do
    case operation.type do
      :insert ->
        insert_text_at_position(state, operation.position, operation.content)

      :delete ->
        delete_text_range(state, operation.start, operation.end)

      :retain ->
        state
    end
  end

  defp insert_text_at_position(state, position, content) do
    current_content = state.content || ""
    {before, after_text} = String.split_at(current_content, position)
    new_content = before <> content <> after_text

    %{state |
      content: new_content,
      version: state.version + 1,
      last_modified: DateTime.utc_now()
    }
  end

  defp delete_text_range(state, start_pos, end_pos) do
    current_content = state.content || ""
    {before, rest} = String.split_at(current_content, start_pos)
    {_, after_text} = String.split_at(rest, end_pos - start_pos)
    new_content = before <> after_text

    %{state |
      content: new_content,
      version: state.version + 1,
      last_modified: DateTime.utc_now()
    }
  end

  defp get_section_state(portfolio_id, section_id) do
    case :ets.lookup(:portfolio_sections, {portfolio_id, section_id}) do
      [{{^portfolio_id, ^section_id}, state}] ->
        {:ok, state}

      [] ->
        # Initialize section state if not found
        initial_state = %{
          content: "",
          version: 0,
          position_offsets: %{},
          last_modified: DateTime.utc_now()
        }
        :ets.insert(:portfolio_sections, {{portfolio_id, section_id}, initial_state})
        {:ok, initial_state}
    end
  end

  defp update_section_state(portfolio_id, section_id, new_state) do
    :ets.insert(:portfolio_sections, {{portfolio_id, section_id}, new_state})
  end

  defp validate_section_permissions(portfolio_id, section_id, user_id, action) do
    # Check if user has permission to perform action on this section
    case get_user_portfolio_permissions(portfolio_id, user_id) do
      {:ok, permissions} ->
        if can_perform_action?(permissions, action, section_id) do
          {:ok, permissions}
        else
          {:error, :insufficient_permissions}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp validate_portfolio_permissions(portfolio, user_id, action) do
    cond do
      portfolio.user_id == user_id ->
        {:ok, :owner}

      true ->
        # Check collaboration permissions
        case get_user_portfolio_permissions(portfolio.id, user_id) do
          {:ok, permissions} ->
            if can_perform_action?(permissions, action) do
              {:ok, permissions}
            else
              {:error, :insufficient_permissions}
            end

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp get_user_portfolio_permissions(portfolio_id, user_id) do
    # Look up user permissions for this portfolio
    case :ets.lookup(:portfolio_permissions, {portfolio_id, user_id}) do
      [{{^portfolio_id, ^user_id}, permissions}] ->
        {:ok, permissions}

      [] ->
        {:error, :no_permissions}
    end
  end

  defp can_perform_action?(permissions, action, section_id \\ nil) do
    case {permissions, action} do
      {:owner, _} -> true

      {perms, :view} when is_map(perms) ->
        Map.get(perms, :can_view, false)

      {perms, :edit} when is_map(perms) ->
        if section_id do
          section_perms = Map.get(perms, :section_permissions, %{})
          Map.get(section_perms, section_id, %{}) |> Map.get(:can_edit, false) ||
          Map.get(perms, :can_edit_all, false)
        else
          Map.get(perms, :can_edit_all, false)
        end

      {perms, :invite} when is_map(perms) ->
        Map.get(perms, :can_invite, false)

      _ ->
        false
    end
  end

  defp normalize_permissions(requested_permissions, inviting_user) do
    # Ensure invited user can't have more permissions than inviting user
    # This would integrate with the existing subscription tier system
    requested_permissions
  end

  defp broadcast_operation(portfolio_id, section_id, operation, sender_id) do
    PubSub.broadcast(
      Frestyl.PubSub,
      "portfolio:#{portfolio_id}:section:#{section_id}",
      {:operation, operation, sender_id}
    )
  end

  defp broadcast_section_activity(portfolio_id, section_id, user_id, activity) do
    PubSub.broadcast(
      Frestyl.PubSub,
      "portfolio:#{portfolio_id}",
      {:section_activity, section_id, user_id, activity}
    )
  end

  defp track_collaboration_activity(portfolio_id, section_id, user_id, action, metadata) do
    activity = %{
      portfolio_id: portfolio_id,
      section_id: section_id,
      user_id: user_id,
      action: action,
      metadata: metadata,
      timestamp: DateTime.utc_now()
    }

    # Store in ETS for analytics
    case :ets.lookup(:portfolio_analytics, portfolio_id) do
      [{^portfolio_id, analytics}] ->
        updated_analytics = update_analytics(analytics, activity)
        :ets.insert(:portfolio_analytics, {portfolio_id, updated_analytics})

      [] ->
        initial_analytics = initialize_analytics(activity)
        :ets.insert(:portfolio_analytics, {portfolio_id, initial_analytics})
    end
  end

  defp update_analytics(analytics, activity) do
    %{analytics |
      edit_count: analytics.edit_count + 1,
      last_activity: activity.timestamp,
      section_edits: update_section_edits(analytics.section_edits, activity.section_id)
    }
  end

  defp initialize_analytics(activity) do
    %{
      edit_count: 1,
      collaborators: [activity.user_id],
      session_start: activity.timestamp,
      last_activity: activity.timestamp,
      section_edits: %{activity.section_id => 1}
    }
  end

  defp update_section_edits(section_edits, section_id) do
    Map.update(section_edits, section_id, 1, &(&1 + 1))
  end

  defp generate_invitation_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end

  defp send_portfolio_invitation_email(invitation, portfolio, inviting_user) do
    # Integration point for email service
    Logger.info("Sending portfolio collaboration invitation for '#{portfolio.title}' to #{invitation.invitee_email}")
    # TODO: Implement actual email sending
  end

  defp notify_collaboration_joined(portfolio_id, joining_user, owner_id) do
    PubSub.broadcast(
      Frestyl.PubSub,
      "user:#{owner_id}:portfolio_invites",
      {:collaboration_joined, portfolio_id, joining_user}
    )
  end

  defp filter_analytics_by_timeframe(analytics, timeframe) do
    # Filter analytics based on timeframe
    analytics
  end
end
