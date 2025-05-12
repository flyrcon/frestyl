defmodule Frestyl.Cache do
  @moduledoc """
  Provides caching functionality for the application.
  """

  use GenServer
  require Logger

  @cache_ttl 3_600 # 1 hour in seconds
  @prune_interval 900_000 # 15 minutes in milliseconds

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Gets a value from the cache.
  Returns `{:ok, value}` if found, or `:error` if not found or expired.
  """
  def get(key) do
    GenServer.call(__MODULE__, {:get, key})
  end

  @doc """
  Gets a value from the cache. If not found, calls the given function,
  stores the result in the cache, and returns it.
  """
  def get_or_store(key, fun) when is_function(fun, 0) do
    case get(key) do
      {:ok, value} ->
        {:ok, value}
      :error ->
        value = fun.()
        put(key, value)
        {:ok, value}
    end
  end

  @doc """
  Puts a value in the cache with optional TTL.
  """
  def put(key, value, ttl \\ @cache_ttl) do
    GenServer.cast(__MODULE__, {:put, key, value, ttl})
  end

  @doc """
  Invalidates a cache entry.
  """
  def invalidate(key) do
    GenServer.cast(__MODULE__, {:invalidate, key})
  end

  @doc """
  Invalidates all cache entries that start with the given prefix.
  """
  def invalidate_by_prefix(prefix) do
    GenServer.cast(__MODULE__, {:invalidate_by_prefix, prefix})
  end

  @doc """
  Clears the entire cache.
  """
  def clear do
    GenServer.cast(__MODULE__, :clear)
  end

  # Server Callbacks

  @impl true
  def init(state) do
    schedule_prune()
    {:ok, state}
  end

  @impl true
  def handle_call({:get, key}, _from, state) do
    case Map.get(state, key) do
      nil ->
        {:reply, :error, state}

      {value, expires_at} ->
        if DateTime.compare(expires_at, DateTime.utc_now()) == :gt do
          {:reply, {:ok, value}, state}
        else
          {:reply, :error, Map.delete(state, key)}
        end
    end
  end

  @impl true
  def handle_cast({:put, key, value, ttl}, state) do
    expires_at = DateTime.add(DateTime.utc_now(), ttl, :second)
    {:noreply, Map.put(state, key, {value, expires_at})}
  end

  @impl true
  def handle_cast({:invalidate, key}, state) do
    {:noreply, Map.delete(state, key)}
  end

  @impl true
  def handle_cast({:invalidate_by_prefix, prefix}, state) do
    keys_to_remove = for {key, _} <- state, String.starts_with?(to_string(key), prefix), do: key
    new_state = Enum.reduce(keys_to_remove, state, fn key, acc -> Map.delete(acc, key) end)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:clear, _state) do
    {:noreply, %{}}
  end

  @impl true
  def handle_info(:prune, state) do
    now = DateTime.utc_now()
    new_state = Enum.reduce(state, %{}, fn {key, {value, expires_at}}, acc ->
      if DateTime.compare(expires_at, now) == :gt do
        Map.put(acc, key, {value, expires_at})
      else
        acc
      end
    end)

    schedule_prune()
    {:noreply, new_state}
  end

  defp schedule_prune do
    Process.send_after(self(), :prune, @prune_interval)
  end
end
