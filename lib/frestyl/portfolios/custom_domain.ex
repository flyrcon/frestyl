# lib/frestyl/portfolios/custom_domain.ex
defmodule Frestyl.Portfolios.CustomDomain do
  use Ecto.Schema
  import Ecto.Changeset

  schema "custom_domains" do
    field :domain, :string
    field :status, :string, default: "pending"
    field :verification_code, :string
    field :verified_at, :utc_datetime
    field :ssl_status, :string, default: "pending"
    field :dns_configured, :boolean, default: false

    belongs_to :portfolio, Frestyl.Portfolios.Portfolio
    belongs_to :user, Frestyl.Accounts.User

    timestamps()
  end

  def changeset(custom_domain, attrs) do
    custom_domain
    |> cast(attrs, [:domain, :status, :verification_code, :verified_at, :ssl_status, :dns_configured, :portfolio_id, :user_id])
    |> validate_required([:domain, :portfolio_id, :user_id])
    |> validate_format(:domain, ~r/^[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]?\.[a-zA-Z]{2,}$/, message: "must be a valid domain")
    |> validate_inclusion(:status, ["pending", "active", "failed"])
    |> validate_inclusion(:ssl_status, ["pending", "active", "failed"])
    |> unique_constraint(:domain)
    |> put_verification_code()
  end

  defp put_verification_code(changeset) do
    if get_change(changeset, :domain) do
      put_change(changeset, :verification_code, generate_verification_code())
    else
      changeset
    end
  end

  defp generate_verification_code do
    :crypto.strong_rand_bytes(16) |> Base.encode32(case: :lower)
  end
end
