# lib/frestyl/media/comment.ex
defmodule Frestyl.Media.Comment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "asset_comments" do
    field :content, :string
    field :metadata, :map

    belongs_to :asset, Frestyl.Media.Asset
    belongs_to :user, Frestyl.Accounts.User
    belongs_to :parent, Frestyl.Media.Comment

    timestamps()
  end

  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [:content, :metadata, :user_id, :asset_id, :parent_id])
    |> validate_required([:content, :user_id, :asset_id])
    |> foreign_key_constraint(:asset_id)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:parent_id)
  end
end
