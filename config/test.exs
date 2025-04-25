import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :frestyl, Frestyl.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "frestyl_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :frestyl, FrestylWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "lwLrDUHJlAHGJA0qzFT1e3fWa+yla5/NsX/5RiIEiwsNwajqL0s2FU3gs7Tjb/jM",
  server: false

# In test we don't send emails
config :frestyl, Frestyl.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

#Payment handling
config :stripity_stripe,
  api_key: "sk_test_your_test_key"
