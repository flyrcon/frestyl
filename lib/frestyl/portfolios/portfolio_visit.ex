# lib/frestyl/portfolios/portfolio_visit.ex
defmodule Frestyl.Portfolios.PortfolioVisit do
  use Ecto.Schema
  import Ecto.Changeset

  schema "portfolio_visits" do
    field :ip_address, :string
    field :user_agent, :string
    field :referrer, :string

    belongs_to :portfolio, Frestyl.Portfolios.Portfolio
    belongs_to :share, Frestyl.Portfolios.PortfolioShare, foreign_key: :share_id

    timestamps()
  end

  def changeset(visit, attrs) do
    visit
    |> cast(attrs, [:ip_address, :user_agent, :referrer, :portfolio_id, :share_id])
    |> validate_required([:portfolio_id])
    |> foreign_key_constraint(:portfolio_id)
    |> foreign_key_constraint(:share_id)
  end
end
