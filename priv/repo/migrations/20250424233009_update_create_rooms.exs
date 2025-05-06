# priv/repo/migrations/20250424000001_create_rooms.exs

defmodule Frestyl.Repo.Migrations.CreateRooms do
  use Ecto.Migration

  def change do
    alter table(:rooms) do
      add_if_not_exists :status, :string, default: "active"
      add_if_not_exists :max_participants, :integer, default: 50
      add_if_not_exists :is_private, :boolean, default: false
      add_if_not_exists :password_hash, :string

    end

    create_if_not_exists index(:rooms, [:creator_id])
    create_if_not_exists index(:rooms, [:status])
    create_if_not_exists index(:rooms, [:is_private])
  end
end
