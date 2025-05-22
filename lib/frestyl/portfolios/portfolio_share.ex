# lib/frestyl/portfolios/portfolio_share.ex
defmodule Frestyl.Portfolios.PortfolioShare do
  use Ecto.Schema
  import Ecto.Changeset

  schema "portfolio_shares" do
    field :token, :string
    field :email, :string
    field :expires_at, :utc_datetime
    field :name, :string
    field :access_count, :integer, default: 0
    field :last_accessed_at, :utc_datetime
    field :approved, :boolean, default: false

    belongs_to :portfolio, Frestyl.Portfolios.Portfolio
    has_many :portfolio_visits, Frestyl.Portfolios.PortfolioVisit, foreign_key: :share_id

    timestamps()
  end

  def changeset(share, attrs) do
    share
    |> cast(attrs, [:email, :name, :expires_at, :portfolio_id, :approved])
    |> validate_required([:portfolio_id])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> validate_length(:name, max: 100)
    |> foreign_key_constraint(:portfolio_id)
    |> generate_token()
  end

  defp generate_token(changeset) do
    if get_field(changeset, :token), do: changeset, else: put_change(
      changeset,
      :token,
      :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    )
  end
end
