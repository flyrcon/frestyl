# lib/frestyl/media/collaboration.ex
defmodule Frestyl.Media.Collaboration do
  @moduledoc """
  Handles collaborative editing features for media assets.
  """

  alias Frestyl.Media.Asset
  alias Frestyl.Media.AssetVersion
  alias Frestyl.Repo
  import Ecto.Query
  alias Frestyl.Media.Comment

  @doc """
  Locks an asset for editing by a specific user.
  """
  def lock_for_editing(%Asset{} = asset, user_id) do
    case get_current_lock(asset.id) do
      nil ->
        create_lock(asset, user_id)
      lock ->
        if lock.user_id == user_id do
          # Extend the existing lock
          extend_lock(lock)
        else
          {:error, "Asset is locked by another user"}
        end
    end
  end

  @doc """
  Releases an editing lock.
  """
  def release_lock(%Asset{} = asset, user_id) do
    case get_current_lock(asset.id) do
      nil ->
        {:ok, "No lock to release"}
      lock ->
        if lock.user_id == user_id do
          Repo.delete(lock)
        else
          {:error, "Cannot release lock owned by another user"}
        end
    end
  end

  @doc """
  Checks if an asset is currently locked and by whom.
  """
  def get_lock_status(%Asset{} = asset) do
    case get_current_lock(asset.id) do
      nil ->
        {:unlocked, nil}
      lock ->
        # Check if lock has expired
        if lock_expired?(lock) do
          Repo.delete(lock)
          {:unlocked, nil}
        else
          {:locked, lock.user_id, lock.expires_at}
        end
    end
  end

  @doc """
  Creates comments on an asset.
  """
  def create_comment(%Asset{} = asset, user_id, content, metadata \\ %{}) do
    %Frestyl.Media.Comment{}
    |> Frestyl.Media.Comment.changeset(%{
      asset_id: asset.id,
      user_id: user_id,
      content: content,
      metadata: metadata
    })
    |> Repo.insert()
  end

  @doc """
  Lists all comments for an asset.
  """
  def list_comments(%Asset{} = asset) do
    from(c in Frestyl.Media.Comment,
      where: c.asset_id == ^asset.id,
      order_by: [asc: c.inserted_at],
      preload: [:user]
    )
    |> Repo.all()
  end

  def delete_comment(%Comment{} = comment) do
    Repo.delete(comment)
    |> tap(fn
      {:ok, comment} -> Frestyl.Media.Events.broadcast_comment_deleted(comment)
      _ -> :ok
    end)
  end

  # Private functions

  defp get_current_lock(asset_id) do
    now = DateTime.utc_now()

    from(l in Frestyl.Media.AssetLock,
      where: l.asset_id == ^asset_id and l.expires_at > ^now
    )
    |> Repo.one()
  end

  defp create_lock(%Asset{} = asset, user_id) do
    expires_at = DateTime.add(DateTime.utc_now(), 30 * 60, :second) # 30 minutes

    %Frestyl.Media.AssetLock{}
    |> Frestyl.Media.AssetLock.changeset(%{
      asset_id: asset.id,
      user_id: user_id,
      expires_at: expires_at
    })
    |> Repo.insert()
  end

  defp extend_lock(lock) do
    expires_at = DateTime.add(DateTime.utc_now(), 30 * 60, :second) # 30 minutes

    lock
    |> Frestyl.Media.AssetLock.changeset(%{expires_at: expires_at})
    |> Repo.update()
  end

  defp lock_expired?(lock) do
    DateTime.compare(lock.expires_at, DateTime.utc_now()) == :lt
  end
end
