# lib/frestyl/migration/user_to_account_migration.ex
defmodule Frestyl.Migration.UserToAccountMigration do
  import Ecto.Query
  alias Frestyl.Repo
  alias Frestyl.Accounts
  alias Frestyl.Accounts.User

  def migrate_all_users do
    users = Repo.all(User)

    Enum.each(users, fn user ->
      migrate_user_to_account(user)
    end)
  end

  def migrate_user_to_account(user) do
    # Check if user already has a personal account
    case Accounts.get_user_primary_account(user) do
      nil ->
        # Create personal account for user
        account_name = "#{user.name || user.email}'s Personal Account"

        case Accounts.create_account(user, %{
          name: account_name,
          type: :personal,
          subscription_tier: user.subscription_tier || :personal
        }) do
          {:ok, account} ->
            # Update all user's portfolios to belong to this account
            migrate_user_portfolios_to_account(user, account)
            IO.puts("✅ Migrated user #{user.id} to account #{account.id}")

          {:error, changeset} ->
            IO.puts("❌ Failed to migrate user #{user.id}: #{inspect(changeset.errors)}")
        end

      account ->
        IO.puts("⏭️  User #{user.id} already has account #{account.id}")
    end
  end

  defp migrate_user_portfolios_to_account(user, account) do
    from(p in Frestyl.Portfolios.Portfolio, where: p.user_id == ^user.id)
    |> Repo.update_all(set: [account_id: account.id])
  end
end
