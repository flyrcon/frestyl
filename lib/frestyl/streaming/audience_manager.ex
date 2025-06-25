# lib/frestyl/streaming/audience_manager.ex
defmodule Frestyl.Streaming.AudienceManager do
  @moduledoc """
  Manages audience for live streams with subscription-based limits and features.

  Handles:
  - Subscription-based viewer limits (Personal: 10, Creator: 100, Professional: 1000, Enterprise: unlimited)
  - Waiting room capacity and queue management
  - Account-specific audience interaction features
  - Cross-account audience sharing and permissions
  - Billing for overage usage
  """

  use GenServer
  require Logger

  alias Frestyl.Accounts
  alias Frestyl.Billing
  alias Phoenix.PubSub

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def join_stream(stream_session_id, viewer_id, join_metadata \\ %{}) do
    GenServer.call(__MODULE__, {:join_stream, stream_session_id, viewer_id, join_metadata})
  end

  def leave_stream(stream_session_id, viewer_id) do
    GenServer.call(__MODULE__, {:leave_stream, stream_session_id, viewer_id})
  end

  def get_audience_stats(stream_session_id) do
    GenServer.call(__MODULE__, {:get_audience_stats, stream_session_id})
  end

  def update_viewer_permissions(stream_session_id, viewer_id, permissions) do
    GenServer.call(__MODULE__, {:update_permissions, stream_session_id, viewer_id, permissions})
  end

  def send_interaction(stream_session_id, viewer_id, interaction_type, data) do
    GenServer.call(__MODULE__, {:send_interaction, stream_session_id, viewer_id, interaction_type, data})
  end

  def moderate_viewer(stream_session_id, moderator_id, viewer_id, action) do
    GenServer.call(__MODULE__, {:moderate_viewer, stream_session_id, moderator_id, viewer_id, action})
  end

  def check_overage_billing(stream_session_id) do
    GenServer.call(__MODULE__, {:check_overage_billing, stream_session_id})
  end

  # Server Implementation

  @impl true
  def init(_) do
    Logger.info("Starting Audience Manager")

    state = %{
      # stream_session_id => audience_state
      audiences: %{},
      # stream_session_id => waiting_room_state
      waiting_rooms: %{},
      # viewer_id => stream_session_id (for quick lookup)
      viewer_locations: %{},
      # Billing tracking
      overage_tracking: %{}
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:join_stream, stream_session_id, viewer_id, join_metadata}, _from, state) do
    viewer = Accounts.get_user!(viewer_id)
    stream_owner = get_stream_owner(stream_session_id)

    case validate_stream_join(stream_session_id, viewer, stream_owner, state) do
      {:ok, :direct_join} ->
        case add_viewer_to_stream(stream_session_id, viewer, join_metadata, state) do
          {:ok, new_state} ->
            broadcast_viewer_joined(stream_session_id, viewer_id, join_metadata)
            {:reply, {:ok, :joined}, new_state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end

      {:ok, :waiting_room} ->
        case add_viewer_to_waiting_room(stream_session_id, viewer, join_metadata, state) do
          {:ok, new_state} ->
            broadcast_viewer_in_waiting_room(stream_session_id, viewer_id)
            {:reply, {:ok, :waiting_room}, new_state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:leave_stream, stream_session_id, viewer_id}, _from, state) do
    case remove_viewer(stream_session_id, viewer_id, state) do
      {:ok, new_state} ->
        # Try to admit someone from waiting room
        final_state = try_admit_from_waiting_room(stream_session_id, new_state)

        broadcast_viewer_left(stream_session_id, viewer_id)
        {:reply, :ok, final_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:get_audience_stats, stream_session_id}, _from, state) do
    audience_state = Map.get(state.audiences, stream_session_id, %{})
    waiting_room_state = Map.get(state.waiting_rooms, stream_session_id, %{})

    stats = %{
      current_viewers: map_size(Map.get(audience_state, :viewers, %{})),
      waiting_room_count: map_size(Map.get(waiting_room_state, :queue, %{})),
      peak_viewers: Map.get(audience_state, :peak_viewers, 0),
      total_joins: Map.get(audience_state, :total_joins, 0),
      viewer_breakdown: get_viewer_breakdown(audience_state),
      interaction_stats: get_interaction_stats(audience_state)
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_call({:update_permissions, stream_session_id, viewer_id, permissions}, _from, state) do
    case update_viewer_permissions_internal(stream_session_id, viewer_id, permissions, state) do
      {:ok, new_state} ->
        broadcast_permissions_updated(stream_session_id, viewer_id, permissions)
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:send_interaction, stream_session_id, viewer_id, interaction_type, data}, _from, state) do
    case validate_interaction(stream_session_id, viewer_id, interaction_type, state) do
      {:ok, validated_data} ->
        new_state = record_interaction(stream_session_id, viewer_id, interaction_type, validated_data, state)
        broadcast_interaction(stream_session_id, viewer_id, interaction_type, validated_data)
        {:reply, {:ok, validated_data}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:moderate_viewer, stream_session_id, moderator_id, viewer_id, action}, _from, state) do
    case validate_moderation_action(stream_session_id, moderator_id, viewer_id, action, state) do
      {:ok, moderation_result} ->
        new_state = apply_moderation_action(stream_session_id, viewer_id, action, state)
        broadcast_moderation_action(stream_session_id, moderator_id, viewer_id, action)
        {:reply, {:ok, moderation_result}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:check_overage_billing, stream_session_id}, _from, state) do
    stream_owner = get_stream_owner(stream_session_id)
    limits = get_viewer_limits(stream_owner.subscription_tier)
    current_viewers = get_current_viewer_count(stream_session_id, state)

    overage_result = if limits.max_viewers != -1 and current_viewers > limits.max_viewers do
      overage_count = current_viewers - limits.max_viewers
      overage_cost = calculate_overage_cost(overage_count, stream_owner.subscription_tier)

      # Track overage for billing
      new_overage_tracking = Map.update(state.overage_tracking, stream_session_id,
        %{total_overage_minutes: 1, total_cost: overage_cost},
        fn existing ->
          %{
            total_overage_minutes: existing.total_overage_minutes + 1,
            total_cost: existing.total_cost + overage_cost
          }
        end)

      new_state = %{state | overage_tracking: new_overage_tracking}

      {{:overage, overage_count, overage_cost}, new_state}
    else
      {:ok, state}
    end

    case overage_result do
      {{:overage, count, cost}, new_state} ->
        {:reply, {:overage, count, cost}, new_state}
      {:ok, state} ->
        {:reply, :ok, state}
    end
  end

  # Internal Helper Functions

  defp validate_stream_join(stream_session_id, viewer, stream_owner, state) do
    limits = get_viewer_limits(stream_owner.subscription_tier)
    current_viewers = get_current_viewer_count(stream_session_id, state)
    waiting_room_count = get_waiting_room_count(stream_session_id, state)

    cond do
      # Priority access for premium viewers
      viewer.subscription_tier in ["professional", "enterprise"] ->
        {:ok, :direct_join}

      # Within viewer limits
      limits.max_viewers == -1 or current_viewers < limits.max_viewers ->
        {:ok, :direct_join}

      # Can join waiting room
      waiting_room_count < limits.waiting_room_capacity ->
        {:ok, :waiting_room}

      # Stream is full
      true ->
        {:error, :stream_full}
    end
  end

  defp add_viewer_to_stream(stream_session_id, viewer, join_metadata, state) do
    audience_state = Map.get(state.audiences, stream_session_id, %{
      viewers: %{},
      peak_viewers: 0,
      total_joins: 0,
      interactions: [],
      start_time: DateTime.utc_now()
    })

    viewer_data = %{
      user_id: viewer.id,
      username: viewer.username,
      subscription_tier: viewer.subscription_tier,
      joined_at: DateTime.utc_now(),
      permissions: get_viewer_permissions(viewer, stream_session_id),
      metadata: join_metadata,
      interactions_count: 0
    }

    new_viewers = Map.put(audience_state.viewers, viewer.id, viewer_data)
    current_count = map_size(new_viewers)

    updated_audience_state = %{audience_state |
      viewers: new_viewers,
      peak_viewers: max(audience_state.peak_viewers, current_count),
      total_joins: audience_state.total_joins + 1
    }

    new_audiences = Map.put(state.audiences, stream_session_id, updated_audience_state)
    new_viewer_locations = Map.put(state.viewer_locations, viewer.id, stream_session_id)

    {:ok, %{state | audiences: new_audiences, viewer_locations: new_viewer_locations}}
  end

  defp add_viewer_to_waiting_room(stream_session_id, viewer, join_metadata, state) do
    waiting_room_state = Map.get(state.waiting_rooms, stream_session_id, %{
      queue: %{},
      next_position: 1
    })

    viewer_data = %{
      user_id: viewer.id,
      username: viewer.username,
      subscription_tier: viewer.subscription_tier,
      joined_waiting_at: DateTime.utc_now(),
      position: waiting_room_state.next_position,
      metadata: join_metadata
    }

    new_queue = Map.put(waiting_room_state.queue, viewer.id, viewer_data)
    updated_waiting_room = %{waiting_room_state |
      queue: new_queue,
      next_position: waiting_room_state.next_position + 1
    }

    new_waiting_rooms = Map.put(state.waiting_rooms, stream_session_id, updated_waiting_room)

    {:ok, %{state | waiting_rooms: new_waiting_rooms}}
  end

  defp remove_viewer(stream_session_id, viewer_id, state) do
    # Remove from main audience
    audience_state = Map.get(state.audiences, stream_session_id, %{viewers: %{}})
    new_viewers = Map.delete(audience_state.viewers, viewer_id)
    updated_audience_state = %{audience_state | viewers: new_viewers}
    new_audiences = Map.put(state.audiences, stream_session_id, updated_audience_state)

    # Remove from waiting room if present
    waiting_room_state = Map.get(state.waiting_rooms, stream_session_id, %{queue: %{}})
    new_queue = Map.delete(waiting_room_state.queue, viewer_id)
    updated_waiting_room = %{waiting_room_state | queue: new_queue}
    new_waiting_rooms = Map.put(state.waiting_rooms, stream_session_id, updated_waiting_room)

    # Remove viewer location tracking
    new_viewer_locations = Map.delete(state.viewer_locations, viewer_id)

    {:ok, %{state |
      audiences: new_audiences,
      waiting_rooms: new_waiting_rooms,
      viewer_locations: new_viewer_locations
    }}
  end

  defp try_admit_from_waiting_room(stream_session_id, state) do
    waiting_room_state = Map.get(state.waiting_rooms, stream_session_id, %{queue: %{}})

    case get_next_in_queue(waiting_room_state.queue) do
      nil ->
        state

      {viewer_id, viewer_data} ->
        viewer = Accounts.get_user!(viewer_id)

        case add_viewer_to_stream(stream_session_id, viewer, viewer_data.metadata, state) do
          {:ok, new_state} ->
            # Remove from waiting room
            new_queue = Map.delete(waiting_room_state.queue, viewer_id)
            updated_waiting_room = %{waiting_room_state | queue: new_queue}
            final_waiting_rooms = Map.put(new_state.waiting_rooms, stream_session_id, updated_waiting_room)

            broadcast_viewer_admitted_from_waiting_room(stream_session_id, viewer_id)
            %{new_state | waiting_rooms: final_waiting_rooms}

          {:error, _reason} ->
            state
        end
    end
  end

  defp get_viewer_limits(subscription_tier) do
    case subscription_tier do
      "personal" -> %{
        max_viewers: 10,
        waiting_room_capacity: 5,
        moderation_tools: [:basic],
        interaction_features: [:chat]
      }

      "creator" -> %{
        max_viewers: 100,
        waiting_room_capacity: 50,
        moderation_tools: [:basic, :timeout, :kick],
        interaction_features: [:chat, :polls, :quiz, :reactions]
      }

      "professional" -> %{
        max_viewers: 1000,
        waiting_room_capacity: 200,
        moderation_tools: [:all],
        interaction_features: [:all],
        priority_support: true
      }

      "enterprise" -> %{
        max_viewers: -1, # unlimited
        waiting_room_capacity: -1, # unlimited
        moderation_tools: [:all],
        interaction_features: [:all],
        custom_moderation: true,
        api_access: true
      }

      _ -> get_viewer_limits("personal") # Default fallback
    end
  end

  # Broadcasting functions
  defp broadcast_viewer_joined(stream_session_id, viewer_id, metadata) do
    PubSub.broadcast(Frestyl.PubSub, "stream:#{stream_session_id}",
      {:viewer_joined, viewer_id, metadata})
  end

  defp broadcast_viewer_left(stream_session_id, viewer_id) do
    PubSub.broadcast(Frestyl.PubSub, "stream:#{stream_session_id}",
      {:viewer_left, viewer_id})
  end

  defp broadcast_viewer_in_waiting_room(stream_session_id, viewer_id) do
    PubSub.broadcast(Frestyl.PubSub, "stream:#{stream_session_id}",
      {:viewer_waiting, viewer_id})
  end

  defp broadcast_viewer_admitted_from_waiting_room(stream_session_id, viewer_id) do
    PubSub.broadcast(Frestyl.PubSub, "stream:#{stream_session_id}",
      {:viewer_admitted, viewer_id})
  end

  defp broadcast_permissions_updated(stream_session_id, viewer_id, permissions) do
    PubSub.broadcast(Frestyl.PubSub, "stream:#{stream_session_id}",
      {:permissions_updated, viewer_id, permissions})
  end

  defp broadcast_interaction(stream_session_id, viewer_id, type, data) do
    PubSub.broadcast(Frestyl.PubSub, "stream:#{stream_session_id}",
      {:interaction, viewer_id, type, data})
  end

  defp broadcast_moderation_action(stream_session_id, moderator_id, viewer_id, action) do
    PubSub.broadcast(Frestyl.PubSub, "stream:#{stream_session_id}",
      {:moderation_action, moderator_id, viewer_id, action})
  end

  # Utility functions (simplified - would need full implementation)
  defp get_stream_owner(_stream_session_id), do: %{subscription_tier: "creator"} # Placeholder
  defp get_current_viewer_count(_stream_session_id, _state), do: 0 # Placeholder
  defp get_waiting_room_count(_stream_session_id, _state), do: 0 # Placeholder
  defp get_viewer_permissions(_viewer, _stream_session_id), do: %{} # Placeholder
  defp get_viewer_breakdown(_audience_state), do: %{} # Placeholder
  defp get_interaction_stats(_audience_state), do: %{} # Placeholder
  defp update_viewer_permissions_internal(_stream_session_id, _viewer_id, _permissions, state), do: {:ok, state}
  defp validate_interaction(_stream_session_id, _viewer_id, _type, _state), do: {:ok, %{}}
  defp record_interaction(_stream_session_id, _viewer_id, _type, _data, state), do: state
  defp validate_moderation_action(_stream_session_id, _moderator_id, _viewer_id, _action, _state), do: {:ok, %{}}
  defp apply_moderation_action(_stream_session_id, _viewer_id, _action, state), do: state
  defp calculate_overage_cost(_count, _tier), do: 0.10 # $0.10 per extra viewer per minute
  defp get_next_in_queue(_queue), do: nil # Placeholder
end
