# Replace your migration content with this simpler version:

defmodule Frestyl.Repo.Migrations.MakeRoomIdNullable do
  use Ecto.Migration

  def change do
    # Just modify the column to allow NULL values
    execute "ALTER TABLE messages ALTER COLUMN room_id DROP NOT NULL;"
  end
end
