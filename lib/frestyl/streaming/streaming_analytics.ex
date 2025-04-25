# lib/frestyl/streaming/analytics.ex

defmodule Frestyl.Streaming.Analytics do
  @moduledoc """
  Handles real-time analytics for streaming sessions.
  Optimized for high throughput and minimal overhead.
  """

  use GenServer
  alias Frestyl.Repo
  alias Frestyl.Streaming.Stream

  @retention_period 24 * 60 * 60 * 1000 # 24 hours in milliseconds

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Records a viewer joining a stream.
  """
  def record_join(stream_id, user_id) do
    GenServer.cast(__MODULE__, {:join, stream_id, user_id, System.system_time(:millisecond)})
  end

  @doc """
  Records a viewer leaving a stream.
  """
  def record_leave(stream_id, user_id) do
    GenServer.cast(__MODULE__, {:leave, stream_id, user_id, System.system_time(:millisecond)})
  end

  @doc """
  Gets the current viewer count for a stream.
  """
  def viewer_count(stream_id) do
    GenServer.call(__MODULE__, {:viewer_count, stream_id})
  end

  @doc """
  Gets the peak viewer count for a stream.
  """
  def peak_viewer_count(stream_id) do
    GenServer.call(__MODULE__, {:peak_viewer_count, stream_id})
  end

  @doc """
  Gets detailed analytics for a stream.
  """
  def get_analytics(stream_id) do
    GenServer.call(__MODULE__, {:analytics, stream_id})
  end

  # Server callbacks

  @impl true
  def init(_) do
    # Schedule periodic cleanup
    schedule_cleanup()

    {:ok, %{
      # Map of stream_id => %{
      #   viewers: %{user_id => joined_at},
      #   peak_count: 0,
      #   total_views: 0,
      #   history: [] # List of {timestamp, action, count} tuples
      # }
      streams: %{},
      # Map to track session duration: %{
      #   {stream_id, user_id} => joined_at
      # }
      sessions: %{}
    }}
  end

  @impl true
  def handle_cast({:join, stream_id, user_id, timestamp}, state) do
    # Update viewers count and tracking
    stream_data = Map.get(state.streams, stream_id, %{
      viewers: %{},
      peak_count: 0,
      total_views: 0,
      history: []
    })

    # Check if this is a new view
    is_new_view = not Map.has_key?(stream_data.viewers, user_id)

    # Update viewers map
    viewers = Map.put(stream_data.viewers, user_id, timestamp)
    current_count = map_size(viewers)

    # Update peak count if needed
    peak_count = max(stream_data.peak_count, current_count)

    # Update total views if this is a new view
    total_views = if is_new_view, do: stream_data.total_views + 1, else: stream_data.total_views

    # Add to history
    history = [{timestamp, :join, current_count} | stream_data.history]

    # Update stream data
    updated_stream = %{
      viewers: viewers,
      peak_count: peak_count,
      total_views: total_views,
      history: history
    }

    # Update sessions tracking
    sessions = Map.put(state.sessions, {stream_id, user_id}, timestamp)

    # Update state
    streams = Map.put(state.streams, stream_id, updated_stream)

    {:noreply, %{state | streams: streams, sessions: sessions}}
  end

  @impl true
  def handle_cast({:leave, stream_id, user_id, timestamp}, state) do
    # Get stream data
    stream_data = Map.get(state.streams, stream_id, %{
      viewers: %{},
      peak_count: 0,
      total_views: 0,
      history: []
    })

    # Remove from viewers
    viewers = Map.delete(stream_data.viewers, user_id)
    current_count = map_size(viewers)

    # Add to history
    history = [{timestamp, :leave, current_count} | stream_data.history]

    # Update stream data
    updated_stream = %{
      stream_data |
      viewers: viewers,
      history: history
    }

    # Remove from sessions tracking
    sessions = Map.delete(state.sessions, {stream_id, user_id})

    # Record session duration if we have the join timestamp
    state = case Map.get(state.sessions, {stream_id, user_id}) do
      nil ->
        state

      joined_at ->
        duration = timestamp - joined_at
        # Here you could persist the session duration to a database
        # or aggregate it in memory
        state
    end

    # Update state
    streams = Map.put(state.streams, stream_id, updated_stream)

    {:noreply, %{state | streams: streams, sessions: sessions}}
  end

  @impl true
  def handle_call({:viewer_count, stream_id}, _from, state) do
    count = case Map.get(state.streams, stream_id) do
      nil -> 0
      data -> map_size(data.viewers)
    end

    {:reply, count, state}
  end

  @impl true
  def handle_call({:peak_viewer_count, stream_id}, _from, state) do
    peak = case Map.get(state.streams, stream_id) do
      nil -> 0
      data -> data.peak_count
    end

    {:reply, peak, state}
  end

  @impl true
  def handle_call({:analytics, stream_id}, _from, state) do
    analytics = case Map.get(state.streams, stream_id) do
      nil ->
        %{
          current_viewers: 0,
          peak_viewers: 0,
          total_views: 0,
          history: []
        }

      data ->
        %{
          current_viewers: map_size(data.viewers),
          peak_viewers: data.peak_count,
          total_views: data.total_views,
          history: Enum.reverse(data.history)
        }
    end

    {:reply, analytics, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    now = System.system_time(:millisecond)
    cutoff = now - @retention_period

    # Cleanup old stream data
    streams = Enum.reduce(state.streams, %{}, fn {stream_id, data}, acc ->
      # Get stream status from database
      stream = Repo.get(Stream, stream_id)

      cond do
        # If stream is ended and older than retention period, remove it
        stream && stream.status == "ended" &&
        DateTime.to_unix(stream.ended_at, :millisecond) < cutoff ->
          acc

        # If no activity for retention period, remove it
        data.history != [] &&
        elem(List.first(data.history), 0) < cutoff &&
        map_size(data.viewers) == 0 ->
          acc

        # Otherwise keep it
        true ->
          Map.put(acc, stream_id, data)
      end
    end)

    # Cleanup old sessions
    sessions = Enum.reduce(state.sessions, %{}, fn {{stream_id, _}, joined_at}, acc ->
      if joined_at < cutoff do
        acc
      else
        Map.put(acc, {stream_id, joined_at}, joined_at)
      end
    end)

    # Schedule next cleanup
    schedule_cleanup()

    {:noreply, %{state | streams: streams, sessions: sessions}}
  end

  defp schedule_cleanup do
    # Run cleanup every hour
    Process.send_after(self(), :cleanup, 60 * 60 * 1000)
  end
end
