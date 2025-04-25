# lib/frestyl/media/asset.ex
defmodule Frestyl.Media.Asset do
  use Ecto.Schema
  import Ecto.Changeset

  schema "assets" do
    field :name, :string
    field :description, :string
    field :type, :string  # document, audio, video
    field :mime_type, :string
    field :metadata, :map
    field :owner_id, :id
    field :status, :string, default: "active" # active, archived, deleted

    has_many :versions, Frestyl.Media.AssetVersion
    has_many :permissions, Frestyl.Media.AssetPermission

    timestamps()
  end

  def changeset(asset, attrs) do
    asset
    |> cast(attrs, [:name, :description, :type, :mime_type, :metadata, :owner_id, :status])
    |> validate_required([:name, :type, :owner_id])
    |> validate_inclusion(:type, ["document", "audio", "video", "image"])
  end
end
