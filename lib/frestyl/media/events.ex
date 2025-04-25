# lib/frestyl/media/events.ex
defmodule Frestyl.Media.Events do
  @moduledoc """
  Handles PubSub events for the Media context.
  """

  alias Phoenix.PubSub
  alias Frestyl.Media.{Asset, AssetVersion, Comment}

  @topic "media"

  def subscribe do
    PubSub.subscribe(Frestyl.PubSub, @topic)
  end

  def subscribe_to_asset(asset_id) do
    PubSub.subscribe(Frestyl.PubSub, "#{@topic}:#{asset_id}")
  end

  def broadcast_asset_created(%Asset{} = asset) do
    PubSub.broadcast(Frestyl.PubSub, @topic, {:asset_created, asset})
  end

  def broadcast_asset_updated(%Asset{} = asset) do
    PubSub.broadcast(Frestyl.PubSub, @topic, {:asset_updated, asset})
    PubSub.broadcast(Frestyl.PubSub, "#{@topic}:#{asset.id}", {:asset_updated, asset})
  end

  def broadcast_asset_deleted(%Asset{} = asset) do
    PubSub.broadcast(Frestyl.PubSub, @topic, {:asset_deleted, asset})
    PubSub.broadcast(Frestyl.PubSub, "#{@topic}:#{asset.id}", {:asset_deleted, asset})
  end

  def broadcast_version_added(%AssetVersion{} = version) do
    PubSub.broadcast(Frestyl.PubSub, "#{@topic}:#{version.asset_id}", {:version_added, version})
  end

  def broadcast_comment_added(%Comment{} = comment) do
    PubSub.broadcast(Frestyl.PubSub, "#{@topic}:#{comment.asset_id}", {:comment_added, comment})
  end

  def broadcast_comment_deleted(%Comment{} = comment) do
    PubSub.broadcast(Frestyl.PubSub, "#{@topic}:#{comment.asset_id}", {:comment_deleted, comment})
  end

  def broadcast_lock_acquired(asset_id, user_id, expires_at) do
    PubSub.broadcast(Frestyl.PubSub, "#{@topic}:#{asset_id}", {:lock_acquired, user_id, expires_at})
  end

  def broadcast_lock_released(asset_id) do
    PubSub.broadcast(Frestyl.PubSub, "#{@topic}:#{asset_id}", {:lock_released})
  end
end
