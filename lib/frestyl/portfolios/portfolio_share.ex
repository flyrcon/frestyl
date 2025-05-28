# lib/frestyl/portfolios/portfolio_share.ex
defmodule Frestyl.Portfolios.PortfolioShare do
  use Ecto.Schema
  import Ecto.Changeset

  schema "portfolio_shares" do
    field :token, :string
    field :name, :string
    field :expires_at, :utc_datetime
    field :view_count, :integer, default: 0

    belongs_to :portfolio, Frestyl.Portfolios.Portfolio

    timestamps()
  end

  def changeset(share, attrs) do
    share
    |> cast(attrs, [:name, :expires_at, :portfolio_id])
    |> validate_required([:portfolio_id])
    |> put_change(:token, generate_token())
    |> foreign_key_constraint(:portfolio_id)
  end

  defp generate_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end
end
