# Save this as: lib/mix/tasks/create_admin.ex

defmodule Mix.Tasks.CreateAdmin do
  @moduledoc "Creates the first admin user"

  use Mix.Task

  @shortdoc "Create admin user"

  def run(args) do
    Mix.Task.run("app.start")

    case args do
      [email, password] ->
        create_admin_user(email, password)
      _ ->
        Mix.shell().error("Usage: mix create_admin your@email.com your_password")
    end
  end

  defp create_admin_user(email, password) do
    alias Frestyl.{Accounts, Repo}

    Mix.shell().info("Creating admin user...")

    # Create user
    user_attrs = %{
      email: email,
      password: password,
      name: "Admin User",
      confirmed_at: DateTime.utc_now()
    }

    case Accounts.register_user(user_attrs) do
      {:ok, user} ->
        # Set admin flag
        Accounts.update_user(user, %{is_admin: true})

        # Create enterprise account if needed
        unless user.account do
          Accounts.create_account(user, %{
            subscription_tier: "enterprise",
            subscription_status: "active"
          })
        end

        Mix.shell().info("✅ Admin user created successfully!")
        Mix.shell().info("📧 Email: #{email}")
        Mix.shell().info("🌐 Admin dashboard: http://localhost:4000/admin")

      {:error, changeset} ->
        Mix.shell().error("❌ Failed to create user:")
        Enum.each(changeset.errors, fn {field, {message, _}} ->
          Mix.shell().error("  #{field}: #{message}")
        end)
    end
  end
end
