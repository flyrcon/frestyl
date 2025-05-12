# lib/frestyl/media/tag.ex
defmodule Frestyl.Media.Tag do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, warn: false

  alias Frestyl.Repo
  alias Frestyl.Accounts.User
  # Instead of directly referencing MediaFile here, we'll use the module name as a string
  # to break the circular dependency

  schema "tags" do
    field :name, :string
    field :color, :string, default: "#cccccc"

    belongs_to :user, User
    many_to_many :media_files, Frestyl.Media.MediaFile, join_through: "media_files_tags"

    timestamps()
  end

  @required_fields [:name, :user_id]
  @optional_fields [:color]

  def changeset(tag, attrs) do
    tag
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:name, :user_id])
  end
end
