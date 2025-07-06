# priv/repo/migrations/add_audio_service_fields_to_services.exs
defmodule Frestyl.Repo.Migrations.AddAudioServiceFieldsToServices do
  use Ecto.Migration

  def change do
    alter table(:services) do
      # Audio-specific fields
      add :name, :string  # Alternative to title
      add :starting_price, :integer  # Alternative to price_cents
      add :pricing_model, :string, default: "fixed"
      add :duration_hours, :float
      add :max_revisions, :integer, default: 2
      add :requires_deposit, :boolean, default: true

      # Audio service capabilities
      add :includes_recording, :boolean, default: false
      add :includes_mixing, :boolean, default: false
      add :includes_mastering, :boolean, default: false
      add :includes_editing, :boolean, default: false

      # Service management
      add :featured, :boolean, default: false
      add :auto_accept_bookings, :boolean, default: false

      # Configuration maps
      add :service_config, :map, default: %{}
      add :booking_settings, :map, default: %{}
      add :delivery_settings, :map, default: %{}
      add :audio_settings, :map, default: %{}
      add :quality_settings, :map, default: %{}
      add :export_options, :map, default: %{}
    end

    # Add indexes for the new fields
    create index(:services, [:pricing_model])
    create index(:services, [:featured])
    create index(:services, [:includes_recording])
    create index(:services, [:includes_mixing])
  end
end
