defmodule Frestyl.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages) do
      add_if_not_exists :content, :text, null: false
      add_if_not_exists :attachment_url, :string
      add_if_not_exists :message_type, :string, default: "text", null: false

      add_if_not_exists :user_id, references(:users, on_delete: :delete_all), null: false
      add_if_not_exists :room_id, references(:rooms, on_delete: :delete_all), null: false

      timestamps()
    end

    create_if_not_exists index(:messages, [:user_id])
    create_if_not_exists index(:messages, [:room_id])
    create_if_not_exists index(:messages, [:inserted_at])
  end
end
