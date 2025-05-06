# lib/frestyl/channels/channel.ex
defmodule Frestyl.Channels.Channel do
  use Ecto.Schema
  import Ecto.Changeset
  alias Frestyl.Channels.ChannelMembership
  alias Frestyl.Chat.Message

  schema "channels" do
    field :name, :string
    field :description, :string
    field :visibility, :string, default: "public"
    field :icon_url, :string
    field :slug, :string
    field :category, :string

    has_many :memberships, ChannelMembership
    has_many :messages, Message

    # Virtual fields
    field :member_count, :integer, virtual: true

    timestamps()
  end

  @doc false
  def changeset(channel, attrs) do
    channel
    |> cast(attrs, [:name, :description, :visibility, :icon_url, :category]) # Add category
    |> validate_required([:name, :visibility])
    |> validate_length(:name, min: 2, max: 50)
    |> validate_length(:description, max: 500)
    |> validate_inclusion(:visibility, ["public", "private", "invite_only"])
    |> maybe_generate_slug()
  end

  defp maybe_generate_slug(%Ecto.Changeset{valid?: true, changes: %{name: name}} = changeset) do
    if get_field(changeset, :slug) do
      changeset
    else
      slug = name
        |> String.downcase()
        |> String.replace(~r/[^a-z0-9\s-]/, "")
        |> String.replace(~r/\s+/, "-")
        |> String.replace(~r/-+/, "-")
        |> String.trim_leading("-")
        |> String.trim_trailing("-")

      # Ensure uniqueness by adding a timestamp if needed
      slug = case Frestyl.Repo.get_by(__MODULE__, slug: slug) do
        nil -> slug
        _ -> "#{slug}-#{System.system_time(:second)}"
      end

      put_change(changeset, :slug, slug)
    end
  end

  defp maybe_generate_slug(changeset), do: changeset
end
