# lib/frestyl/podcasts/episode.ex
defmodule Frestyl.Podcasts.Episode do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "podcast_episodes" do
    field :title, :string
    field :description, :string
    field :slug, :string
    field :episode_number, :integer
    field :season_number, :integer, default: 1
    field :duration, :integer # in seconds
    field :file_size, :integer # in bytes
    field :audio_url, :string
    field :video_url, :string
    field :transcript, :string
    field :show_notes, :string
    field :chapters, {:array, :map}, default: [] # [{title, start_time, end_time}]
    field :tags, {:array, :string}, default: []
    field :explicit, :boolean, default: false
    field :status, :string, default: "draft" # draft, recording, processing, ready, published, archived
    field :scheduled_for, :utc_datetime
    field :published_at, :utc_datetime
    field :recording_started_at, :utc_datetime
    field :recording_ended_at, :utc_datetime
    field :download_count, :integer, default: 0
    field :play_count, :integer, default: 0
    field :metadata, :map, default: %{}

    belongs_to :show, Frestyl.Podcasts.Show
    belongs_to :creator, Frestyl.Accounts.User
    belongs_to :recording_session, Frestyl.Sessions.Session

    has_many :guests, Frestyl.Podcasts.Guest
    has_many :media_files, Frestyl.Media.MediaFile
    has_many :analytics, Frestyl.Podcasts.Analytics

    timestamps()
  end

  def changeset(episode, attrs) do
    episode
    |> cast(attrs, [:title, :description, :episode_number, :season_number, :duration,
                    :file_size, :audio_url, :video_url, :transcript, :show_notes,
                    :chapters, :tags, :explicit, :status, :scheduled_for, :published_at,
                    :recording_started_at, :recording_ended_at, :metadata, :show_id,
                    :creator_id, :recording_session_id])
    |> validate_required([:title, :description, :show_id, :creator_id])
    |> validate_length(:title, min: 1, max: 255)
    |> validate_length(:description, min: 10, max: 4000)
    |> validate_number(:episode_number, greater_than: 0)
    |> validate_number(:season_number, greater_than: 0)
    |> validate_number(:duration, greater_than: 0)
    |> validate_inclusion(:status, ~w(draft recording processing ready published archived))
    |> validate_chapters()
    |> generate_slug()
    |> unique_constraint([:show_id, :episode_number])
    |> unique_constraint(:slug)
  end

  defp validate_chapters(changeset) do
    validate_change(changeset, :chapters, fn _, chapters ->
      Enum.reduce(chapters, [], fn chapter, errors ->
        required_keys = ["title", "start_time"]
        missing_keys = required_keys -- Map.keys(chapter)

        if Enum.empty?(missing_keys) do
          errors
        else
          [{:chapters, "missing required keys: #{Enum.join(missing_keys, ", ")}"}]
        end
      end)
    end)
  end

  defp generate_slug(changeset) do
    case {get_change(changeset, :title), get_change(changeset, :episode_number)} do
      {nil, _} -> changeset
      {title, episode_num} ->
        base_slug = title
        |> String.downcase()
        |> String.replace(~r/[^\w\s-]/, "")
        |> String.replace(~r/\s+/, "-")
        |> String.trim("-")

        slug = if episode_num do
          "#{episode_num}-#{base_slug}"
        else
          base_slug
        end

        put_change(changeset, :slug, slug)
    end
  end
end
