defmodule Frestyl.Repo.Migrations.AddConfirmationFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      modify :confirmed_at, :naive_datetime
      add :confirmation_token, :string
      add :confirmation_sent_at, :naive_datetime
    end

    # You might also want to add unique indices for security and faster lookups,
    # especially for the confirmation_token.
    # create unique_index(:users, [:confirmation_token])
    # create unique_index(:users, [:email]) # If not already unique
    # create unique_index(:users, [:username]) # If not already unique, matches schema constraint
  end
end
