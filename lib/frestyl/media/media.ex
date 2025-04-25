# lib/frestyl/media/media.ex
defmodule Frestyl.Media do
  @moduledoc """
  The Media context handles all media-related functionality including
  documents, audio, video, and collaborative features.
  """

  import Ecto.Query, warn: false
  alias Frestyl.Repo
  alias Frestyl.Media.{Asset, AssetVersion, AssetPermission}

  # Asset CRUD operations

  def list_assets(opts \\ []) do
    Repo.all(Asset)
  end

  def get_asset!(id), do: Repo.get!(Asset, id)

  def create_asset(attrs \\ %{}) do
    %Asset{}
    |> Asset.changeset(attrs)
    |> Repo.insert()
  end

  def update_asset(%Asset{} = asset, attrs) do
    asset
    |> Asset.changeset(attrs)
    |> Repo.insert()
  end

  def delete_asset(%Asset{} = asset) do
    Repo.delete(asset)
  end

  # Version operations

  def create_asset_version(%Asset{} = asset, attrs \\ %{}) do
    %AssetVersion{}
    |> AssetVersion.changeset(attrs |> Map.put(:asset_id, asset.id))
    |> Repo.insert()
  end

  def list_asset_versions(%Asset{} = asset) do
    from(v in AssetVersion, where: v.asset_id == ^asset.id, order_by: [desc: v.inserted_at])
    |> Repo.all()
  end

  # Permission operations

  def grant_permission(%Asset{} = asset, user_id, permission_level) do
    %AssetPermission{}
    |> AssetPermission.changeset(%{
      asset_id: asset.id,
      user_id: user_id,
      permission_level: permission_level
    })
    |> Repo.insert()
  end

  def user_can_access?(%Asset{} = asset, user_id, required_level \\ :view) do
    # Implementation for checking user permissions
    permission = Repo.get_by(AssetPermission, asset_id: asset.id, user_id: user_id)
    permission && permission_sufficient?(permission.permission_level, required_level)
  end

  defp permission_sufficient?(actual, required) do
    permission_levels = %{owner: 4, edit: 3, comment: 2, view: 1}
    Map.get(permission_levels, actual, 0) >= Map.get(permission_levels, required, 0)
  end
end
