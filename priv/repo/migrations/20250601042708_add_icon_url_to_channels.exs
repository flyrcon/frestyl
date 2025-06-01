# priv/repo/migrations/YOUR_TIMESTAMP_add_icon_url_to_channels.exs
defmodule Frestyl.Repo.Migrations.AddIconUrlToChannels do
  use Ecto.Migration

  def change do
    alter table(:channels) do
      modify :icon_url, :string
    end
  end
end
