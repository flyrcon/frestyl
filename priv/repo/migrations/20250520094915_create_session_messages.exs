defmodule Frestyl.Repo.Migrations.CreateSessionMessages do
  use Ecto.Migration

  def change do
    create table(:session_messages) do
      add :content, :text, null: false
      add :user_id, references(:users, on_delete: :restrict), null: false
      add :session_id, references(:sessions, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:session_messages, [:session_id])
    create index(:session_messages, [:user_id])
  end
end
