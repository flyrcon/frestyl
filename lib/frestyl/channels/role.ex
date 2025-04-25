defmodule Frestyl.Channels.Role do
  use Ecto.Schema
  import Ecto.Changeset
  alias Frestyl.Channels.Permission

  schema "roles" do
    field :name, :string
    field :description, :string

    many_to_many :permissions, Permission, join_through: "role_permissions"

    timestamps()
  end

  def changeset(role, attrs) do
    role
    |> cast(attrs, [:name, :description])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
