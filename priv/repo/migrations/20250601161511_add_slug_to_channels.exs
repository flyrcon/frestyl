# priv/repo/migrations/YYYYMMDDHHMMSS_add_slug_to_channels.exs

defmodule Frestyl.Repo.Migrations.AddSlugToChannels do
  use Ecto.Migration

  def change do
    alter table(:channels) do
      modify :slug, :string
    end

    create_if_not_exists unique_index(:channels, [:slug])
  end
end
