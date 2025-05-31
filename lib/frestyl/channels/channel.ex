# lib/frestyl/channels/channel.ex
defmodule Frestyl.Channels.Channel do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:id, :name, :description, :slug, :is_public, :thumbnail_url, :subscriber_count, :fundraising_enabled, :enable_transparency_mode, :inserted_at, :updated_at]}

  schema "channels" do
    field :name, :string
    field :description, :string
    field :slug, :string
    field :is_public, :boolean, default: true
    # field :settings, :map, default: %{}
    field :thumbnail_url, :string
    field :subscriber_count, :integer, default: 0
    field :fundraising_enabled, :boolean, default: false
    field :enable_transparency_mode, :boolean, default: false
    field :visibility, :string, default: "private"

    belongs_to :owner, Frestyl.Accounts.User, foreign_key: :user_id

    # Relationships
    has_many :media_files, Frestyl.Media.MediaFile, on_delete: :delete_all
    has_many :media_groups, Frestyl.Media.MediaGroup, on_delete: :delete_all

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(channel, attrs) do
    channel
    |> cast(attrs, [:name, :description, :slug, :is_public, :settings, :thumbnail_url, :user_id, :fundraising_enabled, :enable_transparency_mode])
    |> validate_required([:name, :user_id])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_length(:description, max: 500)
    |> validate_slug()
    |> unique_constraint(:slug)
    |> foreign_key_constraint(:user_id)
  end

  defp validate_slug(changeset) do
    changeset
    |> maybe_generate_slug()
    |> validate_format(:slug, ~r/^[a-z0-9-]+$/, message: "only lowercase letters, numbers, and hyphens allowed")
    |> validate_length(:slug, min: 3, max: 50)
  end

  defp maybe_generate_slug(%{changes: %{name: name}} = changeset) when is_binary(name) do
    if get_field(changeset, :slug) do
      changeset
    else
      slug =
        name
        |> String.downcase()
        |> String.replace(~r/[^a-z0-9\s-]/, "")
        |> String.replace(~r/\s+/, "-")
        |> String.trim("-")

      put_change(changeset, :slug, slug)
    end
  end

  defp maybe_generate_slug(changeset), do: changeset

  # Helper functions
  def display_name(%__MODULE__{name: name}), do: name

  def public?(%__MODULE__{is_public: is_public}), do: is_public

  def media_count(%__MODULE__{} = channel) do
    # This would typically be preloaded or calculated in the context
    channel.media_files |> length()
  rescue
    _ -> 0
  end

  def thumbnail_url(%__MODULE__{thumbnail_url: nil}) do
    # Default channel thumbnail
    "/images/default-channel.png"
  end

  def thumbnail_url(%__MODULE__{thumbnail_url: url}), do: url

  def formatted_subscriber_count(%__MODULE__{subscriber_count: count}) when is_integer(count) do
    cond do
      count < 1_000 -> to_string(count)
      count < 1_000_000 -> "#{Float.round(count / 1_000, 1)}K"
      true -> "#{Float.round(count / 1_000_000, 1)}M"
    end
  end

  def formatted_subscriber_count(_), do: "0"
end
