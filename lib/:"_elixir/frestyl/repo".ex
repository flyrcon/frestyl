defmodule :"Elixir.Frestyl.Repo" do
  use Ecto.Repo,
    otp_app: :frestyl,
    adapter: Ecto.Adapters.Postgres
end
