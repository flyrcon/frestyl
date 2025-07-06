# lib/frestyl/services/service.ex - Simplified version to avoid enum issues
defmodule Frestyl.Services.Service do
  @moduledoc """
  Service schema for Creator+ tier services with enhanced audio production capabilities.
  Merges existing service functionality with audio-specific features.
  """

  use Ecto.Schema
  import Ecto.Changeset
  alias Frestyl.Accounts.User
  alias Frestyl.Portfolios.Portfolio
  alias Frestyl.Services.{ServiceBooking, ServiceAvailability}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "services" do
    # Core service fields (existing)
    field :title, :string
    field :description, :string
    field :duration_minutes, :integer
    field :price_cents, :integer
    field :currency, :string, default: "USD"
    field :is_active, :boolean, default: true
    field :booking_buffer_minutes, :integer, default: 15
    field :advance_booking_days, :integer, default: 30
    field :cancellation_policy_hours, :integer, default: 24
    field :max_bookings_per_day, :integer
    field :tags, {:array, :string}, default: []
    field :requirements, :string
    field :preparation_notes, :string
    field :location_type, Ecto.Enum, values: [:online, :in_person, :hybrid], default: :online
    field :location_details, :map, default: %{}
    field :auto_confirm, :boolean, default: true
    field :deposit_required, :boolean, default: false
    field :deposit_percentage, :decimal
    field :settings, :map, default: %{}

    # Use string for service_type to avoid enum modification issues
    field :service_type, :string

    # Audio-specific fields (new)
    field :name, :string  # Alternative to title for consistency with new system
    field :starting_price, :integer  # Alternative to price_cents for consistency
    field :pricing_model, :string, default: "fixed"
    field :duration_hours, :float
    field :max_revisions, :integer, default: 2
    field :requires_deposit, :boolean, default: true

    # Audio service capabilities
    field :includes_recording, :boolean, default: false
    field :includes_mixing, :boolean, default: false
    field :includes_mastering, :boolean, default: false
    field :includes_editing, :boolean, default: false

    # Service management
    field :featured, :boolean, default: false
    field :auto_accept_bookings, :boolean, default: false

    # Configuration maps for audio services
    field :service_config, :map, default: %{}
    field :booking_settings, :map, default: %{}
    field :delivery_settings, :map, default: %{}
    field :audio_settings, :map, default: %{}
    field :quality_settings, :map, default: %{}
    field :export_options, :map, default: %{}

    # Relationships
    belongs_to :user, User
    belongs_to :portfolio, Portfolio
    has_many :bookings, ServiceBooking
    has_many :availabilities, ServiceAvailability

    timestamps()
  end

  # Define valid service types as module attributes
  @original_service_types ["consultation", "coaching", "design_work", "lessons", "custom"]
  @audio_service_types ["music_production", "podcast_editing", "voiceover_recording",
                        "audio_mastering", "live_session_coaching", "sound_design", "mixing_mastering"]
  @all_service_types @original_service_types ++ @audio_service_types
  @pricing_models ["fixed", "hourly", "project", "package"]

  def changeset(service, attrs) do
    service
    |> cast(attrs, [
      # Original fields
      :title, :description, :service_type, :duration_minutes, :price_cents,
      :currency, :is_active, :booking_buffer_minutes, :advance_booking_days,
      :cancellation_policy_hours, :max_bookings_per_day, :tags, :requirements,
      :preparation_notes, :location_type, :location_details, :auto_confirm,
      :deposit_required, :deposit_percentage, :settings, :user_id, :portfolio_id,

      # Enhanced audio fields
      :name, :starting_price, :pricing_model, :duration_hours, :max_revisions,
      :requires_deposit, :includes_recording, :includes_mixing, :includes_mastering,
      :includes_editing, :featured, :auto_accept_bookings,
      :service_config, :booking_settings, :delivery_settings,
      :audio_settings, :quality_settings, :export_options
    ])
    |> validate_required_fields()
    |> validate_title_or_name()
    |> validate_price_fields()
    |> validate_duration_fields()
    |> validate_numeric_fields()
    |> validate_inclusion(:service_type, @all_service_types)
    |> validate_inclusion(:pricing_model, @pricing_models)
    |> validate_inclusion(:currency, ["USD", "EUR", "GBP", "CAD", "AUD"])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:portfolio_id)
  end

  # Validation helpers
  defp validate_required_fields(changeset) do
    changeset
    |> validate_required([:service_type, :user_id])
  end

  defp validate_title_or_name(changeset) do
    title = get_field(changeset, :title)
    name = get_field(changeset, :name)

    cond do
      title && String.length(title) >= 3 ->
        validate_length(changeset, :title, min: 3, max: 100)
      name && String.length(name) >= 3 ->
        validate_length(changeset, :name, min: 3, max: 100)
      true ->
        add_error(changeset, :title, "title or name is required")
    end
  end

  defp validate_price_fields(changeset) do
    price_cents = get_field(changeset, :price_cents)
    starting_price = get_field(changeset, :starting_price)

    cond do
      price_cents ->
        validate_number(changeset, :price_cents, greater_than_or_equal_to: 0)
      starting_price ->
        validate_number(changeset, :starting_price, greater_than: 0)
      true ->
        add_error(changeset, :price_cents, "price_cents or starting_price is required")
    end
  end

  defp validate_duration_fields(changeset) do
    duration_minutes = get_field(changeset, :duration_minutes)
    duration_hours = get_field(changeset, :duration_hours)

    cond do
      duration_minutes ->
        validate_number(changeset, :duration_minutes, greater_than: 0, less_than_or_equal_to: 480)
      duration_hours ->
        validate_number(changeset, :duration_hours, greater_than: 0, less_than: 168) # Max 1 week
      true ->
        add_error(changeset, :duration_minutes, "duration_minutes or duration_hours is required")
    end
  end

  defp validate_numeric_fields(changeset) do
    changeset
    |> validate_number(:booking_buffer_minutes, greater_than_or_equal_to: 0)
    |> validate_number(:advance_booking_days, greater_than: 0, less_than_or_equal_to: 365)
    |> validate_number(:cancellation_policy_hours, greater_than_or_equal_to: 0)
    |> validate_number(:max_revisions, greater_than_or_equal_to: 0, less_than: 10)
  end

  # Helper functions for service types
  def audio_service_types, do: @audio_service_types
  def original_service_types, do: @original_service_types
  def all_service_types, do: @all_service_types
  def pricing_models, do: @pricing_models

  def is_audio_service?(%__MODULE__{service_type: service_type}) do
    service_type in @audio_service_types
  end

  def get_display_name(%__MODULE__{} = service) do
    service.name || service.title || "Untitled Service"
  end

  def get_price_cents(%__MODULE__{} = service) do
    service.starting_price || service.price_cents || 0
  end

  def get_duration_minutes(%__MODULE__{} = service) do
    cond do
      service.duration_minutes -> service.duration_minutes
      service.duration_hours -> round(service.duration_hours * 60)
      true -> 60 # Default 1 hour
    end
  end
end
