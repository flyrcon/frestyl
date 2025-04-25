# lib/frestyl/media/asset_lock.ex
defmodule Frestyl.Media.AssetLock do
  use Ecto.Schema
  import Ecto.Changeset

  schema "asset_locks" do
    field :expires_at, :utc_datetime
    field :user_id, :id

    belongs_to :asset, Frestyl.Media.Asset

    timestamps()
  end

  def changeset(lock, attrs) do
    lock
    |> cast(attrs, [:expires_at, :user_id, :asset_id])
    |> validate_required([:expires_at, :user_id, :asset_id])
    |> foreign_key_constraint(:asset_id)
  end
end
