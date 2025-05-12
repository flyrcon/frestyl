# lib/frestyl/media/folder.ex
defmodule Frestyl.Media.Folder do
  use Ecto.Schema
  import Ecto.Changeset

  alias Frestyl.Accounts.User

  schema "folders" do
    field :name, :string

    belongs_to :user, User
    belongs_to :parent, __MODULE__
    has_many :subfolders, __MODULE__, foreign_key: :parent_id
    has_many :media_files, Frestyl.Media.MediaFile

    timestamps()
  end

  @required_fields [:name, :user_id]
  @optional_fields [:parent_id]

  def changeset(folder, attrs) do
    folder
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:parent_id)
  end
end
