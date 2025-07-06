# lib/frestyl/notifications/notification.ex

defmodule Frestyl.Notifications.Notification do
  use Ecto.Schema
  import Ecto.Changeset

  schema "notifications" do
    field :title, :string
    field :message, :string
    field :type, :string  # "chat", "collaboration", "service", "system", "lab"
    field :category, :string  # "chat", "update", "reminder", "alert"
    field :priority, :string, default: "normal"  # "low", "normal", "high", "urgent"
    field :metadata, :map, default: %{}
    field :read_at, :utc_datetime
    field :expires_at, :utc_datetime

    belongs_to :user, Frestyl.Accounts.User

    timestamps()
  end

  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:title, :message, :type, :category, :priority, :metadata, :expires_at, :user_id])
    |> validate_required([:title, :message, :type, :user_id])
    |> validate_inclusion(:type, ["chat", "collaboration", "service", "system", "lab"])
    |> validate_inclusion(:category, ["chat", "update", "reminder", "alert"])
    |> validate_inclusion(:priority, ["low", "normal", "high", "urgent"])
    |> validate_length(:title, max: 100)
    |> validate_length(:message, max: 500)
  end
end
