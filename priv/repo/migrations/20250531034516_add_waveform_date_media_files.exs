defmodule Frestyl.Repo.Migrations.AddMissingFieldsToMediaFiles do
  use Ecto.Migration

  def change do
    alter table(:media_files) do
      # Basic file information
      add_if_not_exists :file_type, :string
      add_if_not_exists :status, :string, default: "active"

      # Audio analysis fields
      add_if_not_exists :waveform_data, :binary
      add_if_not_exists :audio_features, :map
      add_if_not_exists :bpm, :float
      add_if_not_exists :key_signature, :string
      add_if_not_exists :time_signature, :string
      add_if_not_exists :energy_level, :float
      add_if_not_exists :mood_tags, {:array, :string}
      add_if_not_exists :genre_detected, :string
      add_if_not_exists :loudness, :float
      add_if_not_exists :spectral_centroid, :float
      add_if_not_exists :zero_crossing_rate, :float
      add_if_not_exists :mfcc_features, :binary
      add_if_not_exists :chromagram, :binary
      add_if_not_exists :onset_detection, :binary
    end

    # Add indexes for commonly queried fields
    create_if_not_exists index(:media_files, [:file_type])
    create_if_not_exists index(:media_files, [:status])
    create_if_not_exists index(:media_files, [:bpm])
    create_if_not_exists index(:media_files, [:genre_detected])
    create_if_not_exists index(:media_files, [:energy_level])
  end
end
