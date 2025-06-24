# lib/frestyl/accounts/account_membership.ex
defmodule Frestyl.Accounts.AccountMembership do
  use Ecto.Schema
  import Ecto.Changeset

  schema "account_memberships" do
    field :role, Ecto.Enum, values: [:owner, :admin, :editor, :viewer]
    field :permissions, :map, default: %{}

    belongs_to :user, Frestyl.Accounts.User
    belongs_to :account, Frestyl.Accounts.Account

    timestamps()
  end

  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:role, :permissions, :user_id, :account_id])
    |> validate_required([:role, :user_id, :account_id])
    |> unique_constraint([:user_id, :account_id])
  end
end
