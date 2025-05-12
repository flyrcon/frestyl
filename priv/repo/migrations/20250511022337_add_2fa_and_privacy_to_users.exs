# Create a new migration file with mix ecto.gen.migration add_2fa_and_privacy_to_users
# priv/repo/migrations/YYYYMMDDHHMMSS_add_2fa_and_privacy_to_users.exs

defmodule Frestyl.Repo.Migrations.Add2faAndPrivacyToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add_if_not_exists :totp_secret, :binary
      add_if_not_exists :totp_enabled, :boolean, default: false
      add_if_not_exists :backup_codes, {:array, :string}
      add :privacy_settings, :map, default: %{}
    end

    # Add an index on totp_enabled for faster queries
    create index(:users, [:totp_enabled])
  end
end
