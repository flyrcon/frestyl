defmodule Frestyl.Channels.Room do
  use Ecto.Schema
  import Ecto.Changeset
  alias Frestyl.Channels.Channel

  schema "rooms" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :is_public, :boolean, default: true

    # Reference to parent channel
    belongs_to :channel, Channel

    # Customization (can override inherited settings)
    field :override_branding, :boolean, default: false
    field :primary_color, :string
    field :secondary_color, :string

    timestamps()
  end

  def changeset(room, attrs) do
    room
    |> cast(attrs, [:name, :slug, :description, :is_public, :channel_id,
                   :override_branding, :primary_color, :secondary_color])
    |> validate_required([:name, :channel_id])
    |> validate_length(:name, min: 3, max: 50)
    |> validate_format(:primary_color, ~r/^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$/,
                      message: "must be a valid hex color")
    |> validate_format(:secondary_color, ~r/^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$/,
                      message: "must be a valid hex color")
    |> unique_constraint([:name, :channel_id])
    |> generate_slug()
  end

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
