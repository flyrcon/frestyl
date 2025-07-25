defmodule Frestyl.MixProject do
  use Mix.Project

  def project do
    [
      app: :frestyl,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Frestyl.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:bcrypt_elixir, "~> 3.0"},
      {:phoenix, "~> 1.7.21"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.0"},
      {:floki, ">= 0.30.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2.0", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.1.1",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:mime, "~> 2.0"},
      {:stripity_stripe, "~> 2.0"},
      {:swoosh, "~> 1.5"},
      {:phoenix_swoosh, "~> 1.0"},
      {:mogrify, "~> 0.9.3"},
      {:gen_smtp, "~> 1.1"},
      {:finch, "~> 0.13"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.26"},
      {:uuid, "~> 1.1"},
      {:jason, "~> 1.4"},
      {:dns_cluster, "~> 0.1.1"},
      {:chromic_pdf, "~> 1.15"},
      {:plug_cowboy, "~> 2.5"},
      {:temp, "~> 0.4"},
      {:oban, "~> 2.17"},
      {:pbkdf2_elixir, "~> 2.0"},
      {:sweet_xml, "~> 0.7.0"},
      {:bandit, "~> 1.5"},
      {:timex, "~> 3.7"},
      {:tzdata, "~> 1.1"},
      {:waffle, "~> 1.1"},
      {:waffle_ecto, "~> 0.0.11"},
      {:ex_aws, "~> 2.4"},
      {:ex_aws_s3, "~> 2.3"},
      {:hackney, "~> 1.18"},
      {:poison, "~> 5.0"},
      {:nimble_totp, "~> 1.0.0"},
      {:eqrcode, "~> 0.1.10"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind frestyl", "esbuild frestyl"],
      "assets.deploy": [
        "tailwind frestyl --minify",
        "esbuild frestyl --minify",
        "phx.digest"
      ]
    ]
  end
end
