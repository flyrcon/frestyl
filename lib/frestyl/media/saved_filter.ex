# Create this file: lib/frestyl/media/saved_filter.ex

defmodule Frestyl.Media.SavedFilter do
  use Ecto.Schema
  import Ecto.Changeset

  schema "saved_filters" do
    field :name, :string
    field :filter_data, :map, default: %{}

    belongs_to :user, Frestyl.Accounts.User

    timestamps()
  end

  def changeset(saved_filter, attrs) do
    saved_filter
    |> cast(attrs, [:name, :filter_data, :user_id])
    |> validate_required([:name, :user_id])
  end
end
