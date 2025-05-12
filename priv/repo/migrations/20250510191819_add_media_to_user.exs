# In a new migration file
defmodule Frestyl.Repo.Migrations.AddMediaProfileFields do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :profile_video_url, :string
      add :profile_audio_url, :string
    end
  end
end
