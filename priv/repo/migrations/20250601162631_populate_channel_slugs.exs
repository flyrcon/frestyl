# Create a new migration to populate slugs for existing channels
# mix ecto.gen.migration populate_channel_slugs

defmodule Frestyl.Repo.Migrations.PopulateChannelSlugs do
  use Ecto.Migration
  import Ecto.Query
  alias Frestyl.Repo

  def up do
    # Get all channels without slugs
    channels_without_slugs =
      from(c in "channels", where: is_nil(c.slug), select: [:id, :name])
      |> Repo.all()

    # Generate slugs for existing channels
    Enum.each(channels_without_slugs, fn channel ->
      slug = generate_slug(channel.name)
      unique_slug = ensure_unique_slug(slug)

      from(c in "channels", where: c.id == ^channel.id)
      |> Repo.update_all(set: [slug: unique_slug])
    end)
  end

  def down do
    # Remove all slugs
    from(c in "channels")
    |> Repo.update_all(set: [slug: nil])
  end

  defp generate_slug(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^\w\s-]/, "")
    |> String.replace(~r/\s+/, "-")
    |> String.replace(~r/-+/, "-")
    |> String.trim("-")
  end

  defp ensure_unique_slug(base_slug, counter \\ 0) do
    slug = if counter == 0, do: base_slug, else: "#{base_slug}-#{counter}"

    case Repo.one(from(c in "channels", where: c.slug == ^slug, select: count())) do
      0 -> slug
      _ -> ensure_unique_slug(base_slug, counter + 1)
    end
  end
end
