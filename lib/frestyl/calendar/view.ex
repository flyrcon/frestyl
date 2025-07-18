defmodule Frestyl.Calendar.View do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "calendar_views" do
    field :name, :string
    field :view_type, :string, default: "month"
    field :default_view, :boolean, default: false
    field :color_scheme, :string, default: "default"
    field :filters, :map, default: %{}
    field :settings, :map, default: %{}

    field :user_id, :integer
    field :account_id, :integer

    # Manual associations
    belongs_to :user, Frestyl.Accounts.User, foreign_key: :user_id, references: :id, define_field: false
    belongs_to :account, Frestyl.Accounts.Account, foreign_key: :account_id, references: :id, define_field: false

    timestamps()
  end

  def changeset(view, attrs) do
    view
    |> cast(attrs, [:name, :view_type, :default_view, :color_scheme, :filters, :settings, :user_id, :account_id])
    |> validate_required([:name, :view_type])
    |> validate_inclusion(:view_type, ["month", "week", "day", "list", "agenda"])
    |> validate_length(:name, min: 1, max: 100)
  end

  defp validate_datetime_order(changeset) do
    starts_at = get_field(changeset, :starts_at)
    ends_at = get_field(changeset, :ends_at)

    if starts_at && ends_at && DateTime.compare(starts_at, ends_at) != :lt do
      add_error(changeset, :ends_at, "must be after start time")
    else
      changeset
    end
  end

  defp validate_attendee_limit(changeset) do
    max_attendees = get_field(changeset, :max_attendees)

    if max_attendees && max_attendees < 1 do
      add_error(changeset, :max_attendees, "must be at least 1")
    else
      changeset
    end
  end
end
