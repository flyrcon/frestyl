# lib/frestyl/accounts/account.ex
defmodule Frestyl.Accounts.Account do
  use Ecto.Schema
  import Ecto.Changeset

  schema "accounts" do
    field :name, :string
    field :type, Ecto.Enum, values: [:individual, :business, :organization, :enterprise]
    field :subscription_tier, Ecto.Enum, values: [:personal, :creator, :professional, :enterprise]
    field :subscription_status, Ecto.Enum, values: [:active, :past_due, :canceled, :paused]

    field :current_usage, :map, default: %{}
    field :billing_cycle_usage, :map, default: %{}
    field :settings, :map, default: %{}
    field :branding_config, :map, default: %{}
    field :feature_flags, :map, default: %{}

    belongs_to :owner, Frestyl.Accounts.User
    has_many :memberships, Frestyl.Accounts.AccountMembership
    has_many :users, through: [:memberships, :user]
    has_many :portfolios, Frestyl.Portfolios.Portfolio

    timestamps()
  end

  def changeset(account, attrs) do
    account
    |> cast(attrs, [:name, :type, :subscription_tier, :subscription_status, :settings, :branding_config])
    |> validate_required([:name, :type, :owner_id])
    |> validate_length(:name, min: 1, max: 255)
  end
end
