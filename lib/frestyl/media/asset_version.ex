defmodule Frestyl.Media.AssetVersion do
  use Ecto.Schema
  import Ecto.Changeset

  schema "asset_versions" do
    field :version_number, :integer
    field :file_path, :string
    field :file_size, :integer
    field :metadata, :map
    field :created_by_id, :id

    # This already defines asset_id field, so remove the separate field declaration
    belongs_to :asset, Frestyl.Media.Asset

    timestamps()
  end

  def changeset(version, attrs) do
    version
    |> cast(attrs, [:version_number, :file_path, :file_size, :metadata, :created_by_id, :asset_id])
    |> validate_required([:file_path, :created_by_id, :asset_id])
    |> foreign_key_constraint(:asset_id)
  end
end
