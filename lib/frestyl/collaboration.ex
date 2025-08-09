defmodule Frestyl.Collaboration do
  @moduledoc """
  Context for managing collaborative editing operations and operational transforms.
  """

  import Ecto.Query, warn: false
  alias Frestyl.Repo
  alias Frestyl.Collaboration.{SessionOperation, OperationAcknowledgment}
  alias Frestyl.Collaboration.OperationalTransform, as: OT
  alias Phoenix.PubSub

  @doc """
  Creates and broadcasts an operation.
  """
  def create_and_broadcast_operation(session_id, user_id, operation_type, action, data, opts \\ []) do
    # Get current session version
    current_version = get_session_version(session_id)

    # Create operation record
    operation_params = %{
      session_id: session_id,
      user_id: user_id,
      operation_type: operation_type,
      action: action,
      data: data,
      version: current_version + 1
    }

    case create_session_operation(operation_params) do
      {:ok, operation} ->
        # Broadcast to other users
        PubSub.broadcast(
          Frestyl.PubSub,
          "studio:#{session_id}:operations",
          {:new_operation, operation}
        )

        # Update session version
        update_session_version(session_id, operation.version)

        {:ok, operation}

      error ->
        error
    end
  end

  @doc """
  Transforms an operation against all subsequent operations.
  """
  def transform_operation(operation, session_id) do
    # Get all operations after this one
    subsequent_ops = list_operations_after_version(session_id, operation.version)

    # Transform against each subsequent operation
    Enum.reduce(subsequent_ops, operation, fn subsequent_op, acc_op ->
      {transformed_op, _} = OT.transform(acc_op, subsequent_op, :right)
      transformed_op
    end)
  end

  @doc """
  Acknowledges an operation for a user.
  """
  def acknowledge_operation(operation_id, user_id) do
    %OperationAcknowledgment{}
    |> OperationAcknowledgment.changeset(%{
      operation_id: operation_id,
      user_id: user_id,
      acknowledged_at: DateTime.utc_now()
    })
    |> Repo.insert()
    |> case do
      {:ok, ack} ->
        # Broadcast acknowledgment
        operation = get_session_operation!(operation_id)
        PubSub.broadcast(
          Frestyl.PubSub,
          "studio:#{operation.session_id}:operations",
          {:operation_acknowledged, operation_id, user_id}
        )
        {:ok, ack}

      error ->
        error
    end
  end

  @doc """
  Gets unacknowledged operations for a user in a session.
  """
  def list_unacknowledged_operations(session_id, user_id) do
    query = from op in SessionOperation,
      left_join: ack in OperationAcknowledgment,
        on: op.id == ack.operation_id and ack.user_id == ^user_id,
      where: op.session_id == ^session_id and op.user_id != ^user_id and is_nil(ack.id),
      order_by: [asc: op.version]

    Repo.all(query)
  end

  @doc """
  Resolves conflicts between operations.
  """
  def resolve_conflicts(operations) when is_list(operations) do
    # Group operations by timestamp to find concurrent ones
    concurrent_groups = group_concurrent_operations(operations)

    # Resolve conflicts within each group
    Enum.flat_map(concurrent_groups, fn group ->
      if length(group) > 1 do
        resolve_concurrent_operations(group)
      else
        group
      end
    end)
  end

  @doc """
  Gets operation history for debugging.
  """
  def get_operation_history(session_id, limit \\ 100) do
    query = from op in SessionOperation,
      where: op.session_id == ^session_id,
      order_by: [desc: op.inserted_at],
      limit: ^limit,
      preload: [:user]

    Repo.all(query)
  end

  @doc """
  Cleans up old operations (keep last N operations per session).
  """
  def cleanup_old_operations(session_id, keep_count \\ 1000) do
    # Get operations to delete
    operations_to_delete = from op in SessionOperation,
      where: op.session_id == ^session_id,
      order_by: [desc: op.version],
      offset: ^keep_count

    # Delete old operations and their acknowledgments
    {deleted_count, _} = Repo.delete_all(operations_to_delete)
    deleted_count
  end

  @doc """
  Creates a session operation.
  """
  def create_session_operation(attrs) do
    %SessionOperation{}
    |> SessionOperation.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a session operation by ID.
  """
  def get_session_operation!(id) do
    Repo.get!(SessionOperation, id)
  end

  @doc """
  Lists operations after a specific version.
  """
  def list_operations_after_version(session_id, version) do
    query = from op in SessionOperation,
      where: op.session_id == ^session_id and op.version > ^version,
      order_by: [asc: op.version]

    Repo.all(query)
  end

  @doc """
  Gets current session version.
  """
  def get_session_version(session_id) do
    query = from s in Frestyl.Sessions.Session,
      where: s.id == ^session_id,
      select: s.workspace_version

    Repo.one(query) || 0
  end

  @doc """
  Updates session version.
  """
  def update_session_version(session_id, new_version) do
    query = from s in Frestyl.Sessions.Session,
      where: s.id == ^session_id

    Repo.update_all(query, set: [workspace_version: new_version])
  end

  # Private helper functions

  defp group_concurrent_operations(operations) do
    # Group operations that happened within 100ms of each other
    operations
    |> Enum.group_by(fn op ->
      # Round timestamp to nearest 100ms to group concurrent operations
      DateTime.to_unix(op.inserted_at, :millisecond) |> div(100)
    end)
    |> Map.values()
  end

  defp resolve_concurrent_operations(operations) do
    # Sort by user_id for deterministic conflict resolution
    sorted_ops = Enum.sort_by(operations, & &1.user_id)

    # Apply operations in order, transforming each against previous ones
    {resolved_ops, _} = Enum.map_reduce(sorted_ops, [], fn op, applied_ops ->
      # Transform this operation against all previously applied operations
      transformed_op = Enum.reduce(applied_ops, op, fn applied_op, acc_op ->
        {transformed, _} = OT.transform(acc_op, applied_op, :right)
        transformed
      end)

      # Mark conflict resolution in the operation
      conflict_resolution = %{
        original_version: op.version,
        transformed_against: Enum.map(applied_ops, & &1.id),
        resolution_method: "deterministic_user_order"
      }

      resolved_op = %{transformed_op | conflict_resolution: conflict_resolution}

      {resolved_op, [resolved_op | applied_ops]}
    end)

    resolved_ops
  end

    def join_by_invitation_code(code, user) do
    case get_invitation_by_code(code) do
      nil ->
        {:error, :not_found}

      invitation ->
        if invitation_valid?(invitation) do
          add_collaborator_to_story(invitation.story, user, invitation.role)
        else
          {:error, :expired}
        end
    end
  end

  def join_open_collaboration(collaboration_id, user) do
    case get_open_collaboration(collaboration_id) do
      nil ->
        {:error, :not_found}

      collaboration ->
        add_collaborator_to_story(collaboration.story, user, "collaborator")
    end
  end

  def list_open_collaborations do
    # This would query your collaboration system
    # Placeholder implementation
    []
  end

  def create_invitation_code(story, creator, options \\ %{}) do
    code = generate_invitation_code()
    expires_at = DateTime.add(DateTime.utc_now(), 7, :day)

    %Frestyl.Stories.CollaborationInvitation{}
    |> Frestyl.Stories.CollaborationInvitation.changeset(%{
      story_id: story.id,
      created_by_id: creator.id,
      invitation_code: code,
      role: Map.get(options, :role, "collaborator"),
      expires_at: expires_at,
      max_uses: Map.get(options, :max_uses, 1)
    })
    |> Repo.insert()
  end

  defp get_invitation_by_code(code) do
    Frestyl.Stories.CollaborationInvitation
    |> where([i], i.invitation_code == ^code)
    |> preload([:story, :created_by])
    |> Repo.one()
  end

  defp get_open_collaboration(collaboration_id) do
    # Query open collaborations
    nil
  end

  defp invitation_valid?(invitation) do
    DateTime.compare(DateTime.utc_now(), invitation.expires_at) == :lt and
    invitation.uses_count < invitation.max_uses
  end

  defp add_collaborator_to_story(story, user, role) do
    current_collaborators = story.collaborators || []

    unless Enum.member?(current_collaborators, user.id) do
      updated_collaborators = [user.id | current_collaborators]

      story
      |> Ecto.Changeset.change(%{collaborators: updated_collaborators})
      |> Repo.update()
      |> case do
        {:ok, updated_story} ->
          # Broadcast collaboration joined
          Phoenix.PubSub.broadcast(Frestyl.PubSub, "story_collaboration:#{story.id}",
            {:collaborator_joined, user, role})

          {:ok, updated_story}

        error -> error
      end
    else
      {:ok, story}  # Already a collaborator
    end
  end

  defp generate_invitation_code do
    :crypto.strong_rand_bytes(8)
    |> Base.url_encode64(padding: false)
    |> String.slice(0, 8)
    |> String.upcase()
  end
end
