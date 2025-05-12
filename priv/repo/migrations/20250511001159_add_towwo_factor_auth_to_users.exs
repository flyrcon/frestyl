defmodule Frestyl.Repo.Migrations.AddTwoFactorAuthToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :totp_secret, :binary
      add :totp_enabled, :boolean, default: false
      add :backup_codes, {:array, :string}
    end
  end
end
