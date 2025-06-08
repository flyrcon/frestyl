# lib/frestyl/portfolios/portfolio_visit.ex

defmodule Frestyl.Portfolios.PortfolioVisit do
  use Ecto.Schema
  import Ecto.Changeset

  schema "portfolio_visits" do
    field :ip_address, :string
    field :user_agent, :string

    belongs_to :portfolio, Frestyl.Portfolios.Portfolio

    timestamps(type: :naive_datetime)
  end

  @doc false
  def changeset(portfolio_visit, attrs) do
    portfolio_visit
    |> cast(attrs, [:portfolio_id, :ip_address, :user_agent])
    |> validate_required([:portfolio_id, :ip_address])
    |> validate_length(:ip_address, max: 45) # Support IPv6
    |> validate_length(:user_agent, max: 500)
  end
end
