# priv/repo/migrations/20250424000003_create_streams.exs

defmodule Frestyl.Repo.Migrations.CreateStreams do
  use Ecto.Migration

  def change do
    create table(:streams) do
      add :title, :string, null: false
      add :description, :text
      add :status, :string, default: "active"
      add :stream_key, :string
      add :ended_at, :utc_datetime

      add :room_id, references(:rooms, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :nilify_all), null: false

      timestamps()
    end

    create index(:streams, [:room_id])
    create index(:streams, [:user_id])
    create index(:streams, [:status])
    create unique_index(:streams, [:stream_key])
  end
end
