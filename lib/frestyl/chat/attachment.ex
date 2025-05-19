defmodule Frestyl.Chat.Attachment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "attachments" do
    field :file_name, :string
    field :content_type, :string
    field :size, :integer
    field :path, :string

    belongs_to :message, Frestyl.Chat.Message

    timestamps()
  end

  def changeset(attachment, attrs) do
    attachment
    |> cast(attrs, [:file_name, :content_type, :size, :path, :message_id])
    |> validate_required([:file_name, :content_type, :size, :path, :message_id])
  end
end
