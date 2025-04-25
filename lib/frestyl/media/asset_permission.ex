# lib/frestyl/media/asset_permission.ex
defmodule Frestyl.Media.AssetPermission do
  use Ecto.Schema
  import Ecto.Changeset

  schema "asset_permissions" do
    field :permission_level, Ecto.Enum, values: [:owner, :edit, :comment, :view]
    field :user_id, :id

    belongs_to :asset, Frestyl.Media.Asset

    timestamps()
  end

  def changeset(permission, attrs) do
    permission
    |> cast(attrs, [:permission_level, :user_id, :asset_id])
    |> validate_required([:permission_level, :user_id, :asset_id])
    |> foreign_key_constraint(:asset_id)
    |> unique_constraint([:user_id, :asset_id])
  end
end
