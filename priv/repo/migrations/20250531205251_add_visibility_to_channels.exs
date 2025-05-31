defmodule Frestyl.Repo.Migrations.AddVisibilityToChannels do
  use Ecto.Migration

  def change do
    alter table(:channels) do
      add_if_not_exists :visibility, :string, default: "private"
    end
  end
end
