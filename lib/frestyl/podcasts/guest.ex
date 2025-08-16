# lib/frestyl/podcasts/guest.ex
defmodule Frestyl.Podcasts.Guest do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "podcast_shows" do
    field :title, :string
    field :description, :string
    field :slug, :string
    field :author_name, :string
    field :website_url, :string
    field :artwork_url, :string
    field :language, :string, default: "en"
    field :category, :string
    field :explicit, :boolean, default: false
    field :rss_feed_url, :string
    field :distribution_platforms, {:array, :string}, default: []
    field :status, :string, default: "draft" # draft, active, paused, archived
    field :settings, :map, default: %{}

    belongs_to :creator, Frestyl.Accounts.User
    belongs_to :channel, Frestyl.Channels.Channel

    has_many :episodes, Frestyl.Podcasts.Episode
    has_many :analytics, Frestyl.Podcasts.Analytics

    timestamps()
  end

  def changeset(show, attrs) do
    show
    |> cast(attrs, [:title, :description, :author_name, :website_url, :artwork_url,
                    :language, :category, :explicit, :distribution_platforms, :status,
                    :settings, :creator_id, :channel_id])
    |> validate_required([:title, :description, :author_name, :creator_id, :channel_id])
    |> validate_length(:title, min: 1, max: 255)
    |> validate_length(:description, min: 10, max: 4000)
    |> validate_url(:website_url)
    |> validate_url(:artwork_url)
    |> validate_inclusion(:status, ~w(draft active paused archived))
    |> validate_distribution_platforms()
    |> generate_slug()
    |> unique_constraint(:slug)
  end

  defp validate_url(changeset, field) do
    validate_change(changeset, field, fn _, url ->
      case URI.parse(url) do
        %URI{scheme: scheme} when scheme in ~w(http https) -> []
        _ -> [{field, "must be a valid URL"}]
      end
    end)
  end

  defp validate_distribution_platforms(changeset) do
    validate_change(changeset, :distribution_platforms, fn _, platforms ->
      valid_platforms = ~w(spotify apple_podcasts google_podcasts youtube amazon_music
                          castbox podcast_addict overcast pocket_casts)

      invalid = platforms -- valid_platforms
      if Enum.empty?(invalid) do
        []
      else
        [distribution_platforms: "contains invalid platforms: #{Enum.join(invalid, ", ")}"]
      end
    end)
  end

  defp generate_slug(changeset) do
    case get_change(changeset, :title) do
      nil -> changeset
      title ->
        slug = title
        |> String.downcase()
        |> String.replace(~r/[^\w\s-]/, "")
        |> String.replace(~r/\s+/, "-")
        |> String.trim("-")

        put_change(changeset, :slug, slug)
    end
  end
end
