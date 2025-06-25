defmodule Frestyl.Accounts.UserAccount do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_accounts" do
    belongs_to :user, Frestyl.Accounts.User
    belongs_to :organization, Frestyl.Organizations.Organization

    field :account_type, Ecto.Enum, values: [:personal, :professional, :enterprise]
    field :account_name, :string
    field :subscription_tier, :string
    field :custom_domain, :string
    field :branding_settings, :map
    field :seo_settings, :map
    field :analytics_settings, :map

    has_many :portfolios, Frestyl.Portfolios.Portfolio, foreign_key: :account_id
    has_many :teams, Frestyl.Teams.Team

    timestamps()
  end

  def changeset(user_account, attrs) do
    user_account
    |> cast(attrs, [:account_type, :account_name, :subscription_tier, :custom_domain,
                    :branding_settings, :seo_settings, :analytics_settings])
    |> validate_required([:account_type, :account_name])
    |> validate_inclusion(:account_type, [:personal, :professional, :enterprise])
    |> validate_length(:account_name, min: 1, max: 100)
    |> validate_format(:custom_domain, ~r/^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$/,
                       message: "must be a valid domain name")
    |> unique_constraint(:custom_domain)
    |> unique_constraint([:user_id, :account_type])
  end
end
