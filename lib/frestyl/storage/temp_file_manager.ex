# lib/frestyl/storage/temp_file_manager.ex
defmodule Frestyl.Storage.TempFileManager do
  @moduledoc """
  Manages temporary files for exports with automatic cleanup.
  Files are stored temporarily and cleaned up after expiration.
  """

  use GenServer
  require Logger

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Register a temporary file for cleanup
  """
  def register_temp_file(filename, file_path, expires_at) do
    GenServer.cast(__MODULE__, {:register_file, filename, file_path, expires_at})
  end

  @doc """
  Get temporary file info
  """
  def get_temp_file(filename) do
    GenServer.call(__MODULE__, {:get_file, filename})
  end

  @doc """
  Force cleanup of a specific file
  """
  def cleanup_file(filename) do
    GenServer.cast(__MODULE__, {:cleanup_file, filename})
  end

  @doc """
  Get all registered temporary files
  """
  def list_temp_files do
    GenServer.call(__MODULE__, :list_files)
  end

  @doc """
  Force cleanup of all expired files
  """
  def cleanup_expired_files do
    GenServer.cast(__MODULE__, :cleanup_expired)
  end

  # Server Implementation

  @impl true
  def init(_opts) do
    # Schedule periodic cleanup every hour
    schedule_cleanup()

    state = %{
      files: %{},
      cleanup_interval: :timer.hours(1)
    }

    Logger.info("TempFileManager started")
    {:ok, state}
  end

  @impl true
  def handle_cast({:register_file, filename, file_path, expires_at}, state) do
    file_info = %{
      filename: filename,
      file_path: file_path,
      expires_at: expires_at,
      registered_at: DateTime.utc_now(),
      size: get_file_size(file_path)
    }

    new_files = Map.put(state.files, filename, file_info)

    Logger.debug("Registered temp file: #{filename}, expires at: #{expires_at}")

    {:noreply, %{state | files: new_files}}
  end

  @impl true
  def handle_cast({:cleanup_file, filename}, state) do
    case Map.get(state.files, filename) do
      nil ->
        Logger.debug("File not found for cleanup: #{filename}")
        {:noreply, state}

      file_info ->
        cleanup_single_file(file_info)
        new_files = Map.delete(state.files, filename)
        {:noreply, %{state | files: new_files}}
    end
  end

  @impl true
  def handle_cast(:cleanup_expired, state) do
    now = DateTime.utc_now()

    {expired_files, active_files} =
      state.files
      |> Enum.split_with(fn {_filename, file_info} ->
        DateTime.compare(file_info.expires_at, now) == :lt
      end)

    # Cleanup expired files
    Enum.each(expired_files, fn {_filename, file_info} ->
      cleanup_single_file(file_info)
    end)

    if length(expired_files) > 0 do
      Logger.info("Cleaned up #{length(expired_files)} expired temp files")
    end

    new_files = Map.new(active_files)
    {:noreply, %{state | files: new_files}}
  end

  @impl true
  def handle_call({:get_file, filename}, _from, state) do
    file_info = Map.get(state.files, filename)
    {:reply, file_info, state}
  end

  @impl true
  def handle_call(:list_files, _from, state) do
    {:reply, state.files, state}
  end

  @impl true
  def handle_info(:cleanup_expired, state) do
    # Periodic cleanup triggered by timer
    GenServer.cast(__MODULE__, :cleanup_expired)
    schedule_cleanup()
    {:noreply, state}
  end

  # Private functions

  defp schedule_cleanup do
    Process.send_after(__MODULE__, :cleanup_expired, :timer.hours(1))
  end

  defp cleanup_single_file(file_info) do
    try do
      if File.exists?(file_info.file_path) do
        File.rm!(file_info.file_path)
        Logger.debug("Cleaned up temp file: #{file_info.filename}")
      end
    rescue
      e ->
        Logger.error("Failed to cleanup file #{file_info.filename}: #{Exception.message(e)}")
    end
  end

  defp get_file_size(file_path) do
    case File.stat(file_path) do
      {:ok, %{size: size}} -> size
      {:error, _} -> 0
    end
  end
end
