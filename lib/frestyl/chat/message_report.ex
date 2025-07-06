# lib/frestyl/chat/message_report.ex
defmodule Frestyl.Chat.MessageReport do
  use Ecto.Schema
  import Ecto.Changeset

  schema "message_reports" do
    field :reason, :string
    field :status, :string, default: "pending"  # "pending", "reviewed", "resolved", "dismissed"
    field :moderator_notes, :string
    field :resolved_at, :utc_datetime

    belongs_to :message, Frestyl.Chat.Message
    belongs_to :reporter, Frestyl.Accounts.User
    belongs_to :moderator, Frestyl.Accounts.User

    timestamps()
  end

  def changeset(message_report, attrs) do
    message_report
    |> cast(attrs, [:reason, :status, :moderator_notes, :resolved_at, :message_id, :reporter_id, :moderator_id])
    |> validate_required([:reason, :message_id, :reporter_id])
    |> validate_inclusion(:status, ["pending", "reviewed", "resolved", "dismissed"])
    |> validate_length(:reason, min: 1, max: 500)
  end
end
