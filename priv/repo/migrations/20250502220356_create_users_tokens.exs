defmodule Frestyl.Repo.Migrations.CreateUsersTokens do
  use Ecto.Migration

  def change do
    alter table(:users_tokens) do
      add_if_not_exists :token, :binary, null: false
      add_if_not_exists :context, :string, null: false
      add_if_not_exists :sent_to, :string
    end
  end
end
