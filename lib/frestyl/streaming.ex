# lib/frestyl/streaming.ex

defmodule Frestyl.Streaming do
  @moduledoc """
  The Streaming context provides functions for real-time media streaming.
  Optimized for low-latency, high-throughput WebRTC connections.
  """

  alias Frestyl.Repo
  alias Frestyl.Streaming.{Room, Message, Stream}
  alias Frestyl.PubSub

  import Ecto.Query

  @doc """
  Returns a list of active rooms.
  """
  def list_active_rooms do
    Room
    |> where([r], r.status == "active")
    |> order_by([r], desc: r.inserted_at)
    |> Repo.all()
  end

  @doc """
  Creates a new streaming room.
  """
  def create_room(attrs) do
    %Room{}
    |> Room.changeset(attrs)
    |> Repo.insert()
    |> notify_room_created()
  end

  defp notify_room_created({:ok, room} = result) do
    PubSub.broadcast("rooms", {:room_created, room})
    result
  end

  defp notify_room_created(error), do: error

  @doc """
  Gets a room by ID.
  """
  def get_room(id) do
    Repo.get(Room, id)
  end

  @doc """
  Creates a message in a room.
  """
  def create_message(attrs) do
    %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets recent messages for a room.
  """
  def get_recent_messages(room_id, limit \\ 50) do
    Message
    |> where([m], m.room_id == ^room_id)
    |> order_by([m], desc: m.inserted_at)
    |> limit(^limit)
    |> Repo.all()
    |> Enum.map(fn message ->
      %{
        id: message.id,
        user_id: message.user_id,
        content: message.content,
        timestamp: message.inserted_at
      }
    end)
  end

  @doc """
  Starts a new stream.
  """
  def start_stream(attrs) do
    %Stream{}
    |> Stream.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, stream} ->
        PubSub.broadcast(PubSub.room_topic(stream.room_id), {:stream_started, stream})
        {:ok, stream}
      error ->
        error
    end
  end

  @doc """
  Ends a stream.
  """
  def end_stream(stream_id) do
    get_stream(stream_id)
    |> case do
      nil -> {:error, :not_found}
      stream ->
        stream
        |> Stream.changeset(%{status: "ended", ended_at: DateTime.utc_now()})
        |> Repo.update()
        |> case do
          {:ok, updated_stream} ->
            PubSub.broadcast(
              PubSub.room_topic(updated_stream.room_id),
              {:stream_ended, updated_stream}
            )
            {:ok, updated_stream}
          error ->
            error
        end
    end
  end

  @doc """
  Gets a stream by ID.
  """
  def get_stream(id) do
    Repo.get(Stream, id)
  end

    def get_user_streaming_key(user_id) do
    # Generate a consistent streaming key for the user
    key = "sk_user_#{user_id}_" <>
      (:crypto.strong_rand_bytes(16) |> Base.encode64() |> binary_part(0, 16))
    {:ok, key}
  end

  def get_scheduled_streams(user_id) do
    # TODO: Implement when streaming schedule schema is ready
    {:ok, []}
  end

  def get_stream_analytics(user_id) do
    # TODO: Implement when analytics schema is ready
    analytics = %{
      total_streams: 0,
      total_viewers: 0,
      average_duration: 0,
      last_stream_at: nil
    }
    {:ok, analytics}
  end

  def get_rtmp_config(user_id) do
    {:ok, streaming_key} = get_user_streaming_key(user_id)

    config = %{
      server: "rtmp://stream.frestyl.com/live/",
      stream_key: streaming_key,
      backup_server: "rtmp://backup.frestyl.com/live/",
      enabled: true
    }
    {:ok, config}
  end
end
