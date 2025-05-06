# priv/repo/migrations/20250424000002_create_messages.exs

defmodule Frestyl.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add_if_not_exists :type, :string, default: "text"

    end
  end
end
