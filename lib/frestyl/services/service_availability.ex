defmodule Frestyl.Services.ServiceAvailability do
  use Ecto.Schema
  import Ecto.Changeset
  alias Frestyl.Services.Service

  schema "service_availabilities" do
    field :day_of_week, :integer # 1 = Monday, 7 = Sunday
    field :start_time, :time
    field :end_time, :time
    field :timezone, :string, default: "UTC"
    field :is_active, :boolean, default: true
    field :effective_from, :date
    field :effective_until, :date
    field :exceptions, {:array, :date}, default: [] # Specific dates to exclude

    belongs_to :service, Service

    timestamps()
  end

  def changeset(availability, attrs) do
    availability
    |> cast(attrs, [
      :day_of_week, :start_time, :end_time, :timezone, :is_active,
      :effective_from, :effective_until, :exceptions, :service_id
    ])
    |> validate_required([:day_of_week, :start_time, :end_time, :service_id])
    |> validate_number(:day_of_week, greater_than_or_equal_to: 1, less_than_or_equal_to: 7)
    |> validate_time_order()
  end

  defp validate_time_order(changeset) do
    start_time = get_field(changeset, :start_time)
    end_time = get_field(changeset, :end_time)

    if start_time && end_time && Time.compare(start_time, end_time) != :lt do
      add_error(changeset, :end_time, "must be after start time")
    else
      changeset
    end
  end
end
