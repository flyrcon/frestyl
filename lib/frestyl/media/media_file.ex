# lib/frestyl/media/media_file.ex
defmodule Frestyl.Media.MediaFile do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:id, :filename, :file_path, :file_size, :duration, :file_type, :metadata, :thumbnail_url, :waveform_data, :audio_features, :tags, :uploaded_at, :user_id, :channel_id]}

  schema "media_files" do
    field :filename, :string
    field :file_path, :string
    field :file_size, :integer
    field :duration, :float
    field :file_type, :string
    field :metadata, :map
    field :thumbnail_url, :string
    field :waveform_data, :map
    field :audio_features, :map
    field :tags, {:array, :string}
    field :uploaded_at, :utc_datetime
    field :status, :string, default: "active"

    # Enhanced fields from migration
    field :bpm, :float
    field :key_signature, :string
    field :time_signature, :string
    field :energy_level, :float
    field :mood_tags, {:array, :string}
    field :genre_detected, :string
    field :loudness, :float
    field :spectral_centroid, :float
    field :zero_crossing_rate, :float
    field :mfcc_features, :map
    field :chromagram, :map
    field :onset_detection, :map

    belongs_to :user, Frestyl.Accounts.User
    belongs_to :channel, Frestyl.Channels.Channel

    # Enhanced relationships
    has_many :reactions, Frestyl.Media.MediaReaction, on_delete: :delete_all
    has_many :view_histories, Frestyl.Media.ViewHistory, on_delete: :delete_all
    has_many :group_files, Frestyl.Media.MediaGroupFile, on_delete: :delete_all
    has_many :media_groups, through: [:group_files, :media_group]
    has_one :music_metadata, Frestyl.Media.MusicMetadata, on_delete: :delete_all

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(media_file, attrs) do
    media_file
    |> cast(attrs, [
      :filename, :file_path, :file_size, :duration, :file_type, :metadata,
      :thumbnail_url, :waveform_data, :audio_features, :tags, :uploaded_at,
      :user_id, :channel_id, :bpm, :key_signature, :time_signature,
      :energy_level, :mood_tags, :genre_detected, :loudness,
      :spectral_centroid, :zero_crossing_rate, :mfcc_features,
      :chromagram, :onset_detection
    ])
    |> validate_required([:filename, :file_path, :file_type, :user_id])
    |> validate_inclusion(:file_type, ["audio", "video", "image"])
    |> validate_number(:file_size, greater_than: 0)
    |> validate_number(:duration, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:channel_id)
  end

  # Helper function to get display name
  def display_name(%__MODULE__{} = media_file) do
    media_file.filename
    |> String.replace(~r/\.[^.]*$/, "")
    |> String.replace(~r/[_-]/, " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  # Helper function to get file extension
  def file_extension(%__MODULE__{filename: filename}) do
    filename
    |> String.split(".")
    |> List.last()
    |> String.downcase()
  end

  # Helper function to check if file is audio
  def audio?(%__MODULE__{file_type: "audio"}), do: true
  def audio?(_), do: false

  # Helper function to format duration
  def format_duration(%__MODULE__{duration: nil}), do: "Unknown"
  def format_duration(%__MODULE__{duration: duration}) when is_number(duration) do
    minutes = trunc(duration / 60)
    seconds = trunc(duration - minutes * 60)
    "#{minutes}:#{String.pad_leading("#{seconds}", 2, "0")}"
  end

  # Helper function to get human readable file size
  def format_file_size(%__MODULE__{file_size: nil}), do: "Unknown"
  def format_file_size(%__MODULE__{file_size: size}) when is_number(size) do
    cond do
      size < 1024 -> "#{size} B"
      size < 1024 * 1024 -> "#{Float.round(size / 1024, 1)} KB"
      size < 1024 * 1024 * 1024 -> "#{Float.round(size / (1024 * 1024), 1)} MB"
      true -> "#{Float.round(size / (1024 * 1024 * 1024), 1)} GB"
    end
  end
end
