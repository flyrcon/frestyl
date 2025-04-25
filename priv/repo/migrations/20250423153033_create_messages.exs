defmodule Frestyl.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages) do
      add :content, :text, null: false
      add :attachment_url, :string
      add :message_type, :string, default: "text", null: false

      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :room_id, references(:rooms, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:messages, [:user_id])
    create index(:messages, [:room_id])
    create index(:messages, [:inserted_at])
  end
end
