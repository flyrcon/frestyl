# lib/frestyl/live_story/session_archive.ex
defmodule Frestyl.LiveStory.SessionArchive do
  @moduledoc """
  Recordings and transcripts of live story sessions.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "session_archives" do
    field :archive_type, :string
    field :file_path, :string
    field :file_size, :integer
    field :duration_seconds, :integer
    field :metadata, :map, default: %{}
    field :processing_status, :string, default: "pending"
    field :is_public, :boolean, default: false
    field :download_count, :integer, default: 0

    belongs_to :live_story_session, Frestyl.LiveStory.Session

    timestamps()
  end

  def changeset(archive, attrs) do
    archive
    |> cast(attrs, [
      :archive_type, :file_path, :file_size, :duration_seconds,
      :metadata, :processing_status, :is_public, :download_count,
      :live_story_session_id
    ])
    |> validate_required([:archive_type, :live_story_session_id])
    |> validate_inclusion(:archive_type, [
      "video", "audio", "transcript", "session_data", "chat_log"
    ])
    |> validate_inclusion(:processing_status, [
      "pending", "processing", "complete", "failed", "cancelled"
    ])
    |> validate_number(:file_size, greater_than_or_equal_to: 0)
    |> validate_number(:duration_seconds, greater_than_or_equal_to: 0)
    |> validate_number(:download_count, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:live_story_session_id)
  end
end
