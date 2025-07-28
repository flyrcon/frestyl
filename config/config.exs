# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :frestyl, :"Elixir.frestyl.repo",
  database: "frestyl_repo",
  username: "user",
  password: "pass",
  hostname: "localhost"

config :frestyl,
  ecto_repos: [Frestyl.Repo],
  generators: [timestamp_type: :utc_datetime]

config :frestyl,
  pdf_generator: :chromic_pdf


#config :frestyl, Oban,
#  repo: Frestyl.Repo,
#  plugins: [Oban.Plugins.Pruner],
#  queues: [
#    default: 10,
#    metrics: 5,
#    revenue: 3
#  ]

# Export configuration
config :frestyl,
  uploads_directory: "priv/static/uploads",
  exports_directory: "priv/static/exports",
  temp_file_retention_hours: 48

config :frestyl,
  upload_dir: Path.join(["priv", "static", "uploads"]),
  base_url: "http://localhost:4000"  # Change in production

# Configures the endpoint
config :frestyl, FrestylWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: FrestylWeb.ErrorHTML, json: FrestylWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Frestyl.PubSub,
  live_view: [signing_salt: "oI418hUt"]

# Configure Swoosh mailer
config :frestyl, Frestyl.Mailer, adapter: Swoosh.Adapters.Local

config :frestyl, FrestylWeb.Endpoint,
  url: [host: "localhost"]

# Configure Swoosh mailbox preview in development
if Mix.env() == :dev do
  config :swoosh, :preview_port, 4002
end

# config/config.exs
config :frestyl,
upload_path: "priv/static/uploads",
storage_type: "local",
max_upload_size: 100_000_000, # 100MB
thumbnail_sizes: [
  small: [width: 150, height: 150],
  medium: [width: 300, height: 300],
  large: [width: 600, height: 600]
]

# config/dev.exs
config :frestyl,
  upload_path: "priv/static/uploads",
  use_s3: false

# config/prod.exs
config :frestyl,
  use_s3: {:system, "USE_S3", false}, # Optional, defaults to false
  s3_bucket: {:system, "S3_BUCKET", nil},
  s3_region: {:system, "S3_REGION", nil}

# Optional S3 configuration, only loaded if use_s3 is true
config :ex_aws,
  access_key_id: {:system, "AWS_ACCESS_KEY_ID"},
  secret_access_key: {:system, "AWS_SECRET_ACCESS_KEY"}

# config/dev.exs
config :frestyl, Frestyl.Mailer,
  adapter: Swoosh.Adapters.Local

# media handling
  config :ex_aws,
json_codec: Jason,
http_client: ExAws.Http.Hackney

# config/dev.exs - local config
config :frestyl,
storage_type: :local,
upload_path: "priv/static/uploads"

# config/prod.exs - production config
config :frestyl,
storage_type: :s3,
aws_bucket: System.get_env("AWS_BUCKET"),
aws_region: System.get_env("AWS_REGION", "us-west-2")

config :ex_aws,
access_key_id: {:system, "AWS_ACCESS_KEY_ID"},
secret_access_key: {:system, "AWS_SECRET_ACCESS_KEY"}

config :mime, :types, %{
  "audio/mpeg" => ["mp3"],
  "audio/wav" => ["wav"],
  "audio/ogg" => ["ogg"],
  "video/mp4" => ["mp4"],
  "video/webm" => ["webm"],
  "video/ogg" => ["ogv"],
  "video/quicktime" => ["mov"],
  "application/ogg" => ["ogx"]
}

config :frestyl, :subscription_tiers,
  valid_tiers: ["personal", "creator", "professional", "enterprise"],
  default_tier: "creator",
  tier_hierarchy: ["personal", "creator", "professional", "enterprise"]

  # For production, you might use something like:
# config/prod.exs
# config :frestyl, Frestyl.Mailer,
#   adapter: Swoosh.Adapters.SMTP,
#   relay: "smtp.sendgrid.net",
#   username: System.get_env("SENDGRID_USERNAME"),
#   password: System.get_env("SENDGRID_PASSWORD"),
#   tls: :always,
#   auth: :always,
#   port: 587,
#   dkim: [
#     s: "default", d: "yourdomain.com",
#     h: [:from, :to, :cc, :bcc, :subject, :date, :mime_version, :content_type, :reply_to],
#     sha: :sha256,
#     b: File.read!("priv/keys/dkim_private.pem")
#   ],
#   retries: 2,
#   no_mx_lookups: false

# Ensure you add Swoosh to your dependencies in mix.exs:
# defp deps do
#   [
#     {:swoosh, "~> 1.0"},
#     # Include adapter and your selected email service adapter
#     {:finch, "~> 0.13"},  # For HTTP adapters like SendGrid
#     {:hackney, ">= 1.15.2"},  # For SMTP adapters
#     # For development mailbox preview
#     {:phoenix_swoosh, "~> 1.0"}
#   ]
# end

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  frestyl: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :chromic_pdf,
  chrome_executable: System.get_env("CHROME_EXECUTABLE") || "chromium-browser",
  chrome_args: ~w[
    --no-sandbox
    --disable-dev-shm-usage
    --disable-gpu
    --remote-debugging-port=0
    --disable-features=TranslateUI
    --disable-ipc-flooding-protection
  ],
  session_pool: [
    size: 3,
    init_timeout: :timer.seconds(10)
  ],
  # Increase timeout for large documents
  timeout: 30_000,  # 30 seconds instead of default 5 seconds

  # Optional: Disable sandbox mode if you're having issues
  sandbox: false,
  on_demand: true

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  frestyl: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)

  ]

config :frestyl, Frestyl.Repo,
username: "postgres",
password: "postgres",
database: "frestyl_dev",
hostname: "localhost",
show_sensitive_data_on_connection_error: true,
pool_size: 10


# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

#AI integration
config :frestyl, :ai_provider, :openai
config :frestyl, :openai_api_key, System.get_env("OPENAI_API_KEY")
config :frestyl, :anthropic_api_key, System.get_env("ANTHROPIC_API_KEY")

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

config :stripity_stripe,
  api_key: System.get_env("STRIPE_SECRET_KEY")

#   public_key: System.get_env("STRIPE_PUBLIC_KEY"),
#   secret_key: System.get_env("STRIPE_SECRET_KEY"),
#   webhook_secret: System.get_env("STRIPE_WEBHOOK_SECRET"),
#   professional_price_id: System.get_env("STRIPE_PROFESSIONAL_PRICE_ID"),
#   business_price_id: System.get_env("STRIPE_BUSINESS_PRICE_ID")




config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

# config/config.exs
config :mime, :types, %{
  "audio/x-flac" => ["flac"]


}
