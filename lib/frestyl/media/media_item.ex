defmodule Frestyl.Media.MediaItem do
  use Ecto.Schema
  import Ecto.Changeset

  schema "media_items" do
    field :name, :string
    field :title, :string
    field :media_type, Ecto.Enum, values: [:document, :image, :video, :audio]
    field :description, :string
    field :file_path, :string
    field :file_size, :integer
    field :file_type, :string
    field :content_type, :string
    field :mime_type, :string
    field :duration, :integer
    field :width, :integer
    field :height, :integer
    field :thumbnail_url, :string
    field :is_public, :boolean, default: false
    field :status, Ecto.Enum, values: [:processing, :ready, :error], default: :processing
    field :metadata, :map, default: %{}

    belongs_to :uploader, Frestyl.Accounts.User
    belongs_to :channel, Frestyl.Channels.Channel
    belongs_to :session, Frestyl.Sessions.Session
    belongs_to :event, Frestyl.Events.Event

    timestamps()
  end

  def changeset(media_item, attrs) do
    media_item
    |> cast(attrs, [:name, :content_type, :title, :description, :file_path, :file_size, :file_type, :mime_type,
                   :duration, :width, :height, :thumbnail_url, :is_public, :status,
                   :media_type, :metadata, :uploader_id, :channel_id, :session_id, :event_id])
    |> validate_required([:name, :title, :content_type, :file_path, :file_type, :mime_type, :media_type, :uploader_id])
    |> validate_length(:title, min: 2, max: 255)
    |> validate_length(:description, max: 2000)
    |> validate_number(:file_size, greater_than: 0)
    |> validate_required_associations()
  end

  defp validate_required_associations(changeset) do
    channel_id = get_field(changeset, :channel_id)
    session_id = get_field(changeset, :session_id)
    event_id = get_field(changeset, :event_id)

    if !channel_id && !session_id && !event_id do
      add_error(changeset, :base, "Media must be associated with at least one of: channel, session, or event")
    else
      changeset
    end
  end
end
