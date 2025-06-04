defmodule Frestyl.Repo.Migrations.AddAudioFieldsToSessions do
  use Ecto.Migration

  def change do
    alter table(:sessions) do
      add :audio_enabled, :boolean, default: false
      add :max_audio_tracks, :integer, default: 8
      add :audio_settings, :map, default: %{}
      add_if_not_exists :recording_enabled, :boolean, default: false
    end
  end
end
