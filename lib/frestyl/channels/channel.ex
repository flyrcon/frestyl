defmodule Frestyl.Channels.Channel do
  use Ecto.Schema
  import Ecto.Changeset
  alias Frestyl.Accounts.User

  schema "channels" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :is_public, :boolean, default: true
    field :primary_color, :string, default: "#EE7868"  # Default to Frestyl theme color
    field :secondary_color, :string, default: "#FFFFFF"
    field :logo_url, :string

    # For channel hierarchy
    field :parent_id, :id
    has_many :sub_channels, __MODULE__, foreign_key: :parent_id
    belongs_to :parent, __MODULE__, foreign_key: :parent_id, define_field: false

    # For ownership/permissions
    belongs_to :owner, User
    many_to_many :members, User, join_through: "channel_memberships"

    # For categories
    field :category, :string
    field :tags, {:array, :string}, default: []

    timestamps()
  end

  def changeset(channel, attrs) do
    channel
    |> cast(attrs, [:name, :slug, :description, :is_public, :primary_color,
                    :secondary_color, :logo_url, :parent_id, :owner_id,
                    :category, :tags])
    |> validate_required([:name, :owner_id])
    |> validate_length(:name, min: 3, max: 50)
    |> validate_format(:primary_color, ~r/^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$/,
                      message: "must be a valid hex color")
    |> validate_format(:secondary_color, ~r/^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$/,
                      message: "must be a valid hex color")
    |> unique_constraint(:name)
    |> generate_slug()
  end

  # Private function to generate a URL-friendly slug from the channel name
  defp generate_slug(changeset) do
    case get_change(changeset, :name) do
      nil -> changeset
      name ->
        slug = name
               |> String.downcase()
               |> String.replace(~r/[^a-z0-9\s-]/, "")
               |> String.replace(~r/\s+/, "-")
        put_change(changeset, :slug, slug)
    end
  end
end
