# lib/frestyl/events/event_invitation.ex
defmodule Frestyl.Events.EventInvitation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "event_invitations" do
    field :email, :string
    field :token, :string
    field :status, Ecto.Enum, values: [:pending, :accepted, :declined], default: :pending
    field :expires_at, :utc_datetime

    belongs_to :event, Frestyl.Events.Event
    belongs_to :invitee, Frestyl.Accounts.User

    timestamps()
  end

  def changeset(invitation, attrs) do
    invitation
    |> cast(attrs, [:email, :status, :expires_at, :event_id, :invitee_id])
    |> validate_required([:email, :event_id])
    |> validate_format(:email, ~r/@/)
    |> put_token()
    |> put_expires_at()
    |> foreign_key_constraint(:event_id)
    |> foreign_key_constraint(:invitee_id)
    |> unique_constraint([:event_id, :email])
  end

  defp put_token(changeset) do
    if changeset.valid? do
      put_change(changeset, :token, generate_token())
    else
      changeset
    end
  end

  defp generate_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64()
  end

  defp put_expires_at(changeset) do
    if changeset.valid? && !get_field(changeset, :expires_at) do
      expires_at = DateTime.utc_now() |> DateTime.add(7 * 24 * 60 * 60, :second)
      put_change(changeset, :expires_at, expires_at)
    else
      changeset
    end
  end
end
