defmodule Frestyl.Repo.Migrations.InspectChannels do
  use Ecto.Migration

  def up do
    execute """
    SELECT column_name, data_type
    FROM information_schema.columns
    WHERE table_name = 'channels'
    ORDER BY ordinal_position;
    """
  end

  def down, do: :ok
end
