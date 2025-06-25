defmodule Frestyl.Portfolios.SharingPermission do
  use Ecto.Schema
  import Ecto.Changeset

  schema "portfolio_sharing_permissions" do
    belongs_to :portfolio, Frestyl.Portfolios.Portfolio
    belongs_to :shared_with_user, Frestyl.Accounts.User
    belongs_to :shared_by_user, Frestyl.Accounts.User

    field :permission_level, Ecto.Enum, values: [:view, :comment, :edit, :embed]
    field :expires_at, :utc_datetime
    field :access_token, :string
    field :embed_settings, :map

    timestamps()
  end

  def changeset(sharing_permission, attrs) do
    sharing_permission
    |> cast(attrs, [:permission_level, :expires_at, :access_token, :embed_settings])
    |> validate_required([:permission_level])
    |> validate_inclusion(:permission_level, [:view, :comment, :edit, :embed])
    |> unique_constraint([:portfolio_id, :shared_with_user_id])
    |> unique_constraint(:access_token)
  end

  def generate_access_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end
end
