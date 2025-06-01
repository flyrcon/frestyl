# Create this file: priv/repo/migrations/YYYYMMDDHHMMSS_add_fundraising_fields_to_channels.exs

defmodule Frestyl.Repo.Migrations.AddFundraisingFieldsToChannels do
  use Ecto.Migration

  def change do
    alter table(:channels) do
      # Fundraising fields
      add_if_not_exists :fundraising_enabled, :boolean, default: false, null: false
      add :funding_goal, :decimal, precision: 10, scale: 2
      add :current_funding, :decimal, precision: 10, scale: 2, default: 0.00, null: false
      add :funding_deadline, :date

      # Transparency fields
      add_if_not_exists :enable_transparency_mode, :boolean, default: false, null: false
      add :transparency_level, :string, default: "basic", null: false
    end

    create_if_not_exists index(:channels, [:fundraising_enabled])
    create_if_not_exists index(:channels, [:enable_transparency_mode])
    create index(:channels, [:funding_deadline])
  end
end
