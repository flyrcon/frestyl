# lib/frestyl/pub_sub.ex

defmodule Frestyl.PubSub do
  @moduledoc """
  Real-time PubSub system for distributing messages across clients.
  Optimized for high throughput and low latency with distributed nodes support.
  """

  alias Phoenix.PubSub

  @doc """
  Broadcasts a message to all subscribers of a topic.
  """
  def broadcast(topic, message) do
    PubSub.broadcast(Frestyl.PubSub, topic, message)
  end

  @doc """
  Broadcasts a message to all subscribers of a topic except the sender.
  """
  def broadcast_from(from_pid, topic, message) do
    PubSub.broadcast_from(Frestyl.PubSub, from_pid, topic, message)
  end

  @doc """
  Subscribes the caller to the given topic.
  """
  def subscribe(topic) do
    PubSub.subscribe(Frestyl.PubSub, topic)
  end

  @doc """
  Unsubscribes the caller from the given topic.
  """
  def unsubscribe(topic) do
    PubSub.unsubscribe(Frestyl.PubSub, topic)
  end

  @doc """
  Creates a topic for a specific stream session.
  """
  def stream_topic(stream_id), do: "stream:#{stream_id}"

  @doc """
  Creates a topic for a specific user.
  """
  def user_topic(user_id), do: "user:#{user_id}"

  @doc """
  Creates a topic for a specific room.
  """
  def room_topic(room_id), do: "room:#{room_id}"
end
