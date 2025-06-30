# lib/frestyl/portfolios/access_request.ex
defmodule Frestyl.Portfolios.AccessRequest do
  use Ecto.Schema
  import Ecto.Changeset

  schema "access_requests" do
    field :requester_email, :string
    field :requester_name, :string
    field :message, :string
    field :status, Ecto.Enum, values: [:pending, :approved, :denied], default: :pending
    field :approved_at, :utc_datetime
    field :expires_at, :utc_datetime
    field :access_token, :string
    field :ip_address, :string
    field :user_agent, :string
    field :referrer, :string

    # Admin response
    field :admin_response, :string
    field :reviewed_by_user_id, :id
    field :reviewed_at, :utc_datetime

    belongs_to :portfolio, Frestyl.Portfolios.Portfolio
    belongs_to :requester_user, Frestyl.Accounts.User, foreign_key: :requester_user_id

    timestamps()
  end

  def changeset(access_request, attrs) do
    access_request
    |> cast(attrs, [
      :requester_email, :requester_name, :message, :status, :approved_at,
      :expires_at, :access_token, :ip_address, :user_agent, :referrer,
      :admin_response, :reviewed_by_user_id, :reviewed_at, :portfolio_id, :requester_user_id
    ])
    |> validate_required([:requester_email, :portfolio_id])
    |> validate_format(:requester_email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/, message: "must be a valid email")
    |> validate_length(:requester_name, max: 100)
    |> validate_length(:message, max: 1000)
    |> validate_length(:admin_response, max: 500)
    |> put_access_token()
    |> put_expires_at()
    |> foreign_key_constraint(:portfolio_id)
  end

  def approval_changeset(access_request, attrs) do
    access_request
    |> cast(attrs, [:status, :admin_response, :reviewed_by_user_id, :reviewed_at, :approved_at])
    |> validate_required([:status, :reviewed_by_user_id, :reviewed_at])
    |> validate_inclusion(:status, [:approved, :denied])
    |> put_approved_at()
  end

  defp put_access_token(changeset) do
    if get_change(changeset, :status) == :approved do
      put_change(changeset, :access_token, generate_access_token())
    else
      changeset
    end
  end

  defp put_expires_at(changeset) do
    if get_change(changeset, :status) == :approved do
      expires_at = DateTime.utc_now() |> DateTime.add(30, :day) # 30 days access
      put_change(changeset, :expires_at, expires_at)
    else
      changeset
    end
  end

  defp put_approved_at(changeset) do
    if get_change(changeset, :status) == :approved do
      put_change(changeset, :approved_at, DateTime.utc_now())
    else
      changeset
    end
  end

  defp generate_access_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end
end
