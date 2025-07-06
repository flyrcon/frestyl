# priv/repo/migrations/20250706_create_notifications.exs

defmodule Frestyl.Repo.Migrations.CreateNotifications do
  use Ecto.Migration

  def change do
    create table(:notifications) do
      add :title, :string, null: false
      add :message, :text, null: false
      add :type, :string, null: false  # "chat", "collaboration", "service", "system", "lab"
      add :category, :string, default: "update"  # "chat", "update", "reminder", "alert"
      add :priority, :string, default: "normal"  # "low", "normal", "high", "urgent"
      add :metadata, :map, default: "{}"
      add :read_at, :utc_datetime
      add :expires_at, :utc_datetime

      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:notifications, [:user_id])
    create index(:notifications, [:type])
    create index(:notifications, [:category])
    create index(:notifications, [:read_at])
    create index(:notifications, [:inserted_at])
    create index(:notifications, [:expires_at])
  end
end
