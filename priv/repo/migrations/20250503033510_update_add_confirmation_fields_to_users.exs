defmodule Frestyl.Repo.Migrations.AddConfirmationFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      modify :confirmed_at, :naive_datetime
      add_if_not_exists :confirmation_token, :string
      add_if_not_exists :confirmation_sent_at, :naive_datetime
    end
  end
end
