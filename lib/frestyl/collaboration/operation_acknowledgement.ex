defmodule Frestyl.Collaboration.OperationAcknowledgment do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "operation_acknowledgments" do
    field :acknowledged_at, :utc_datetime

    belongs_to :operation, Frestyl.Collaboration.SessionOperation, type: :binary_id
    belongs_to :user, Frestyl.Accounts.User

    timestamps()
  end

  def changeset(acknowledgment, attrs) do
    acknowledgment
    |> cast(attrs, [:operation_id, :user_id, :acknowledged_at])
    |> validate_required([:operation_id, :user_id, :acknowledged_at])
    |> unique_constraint([:operation_id, :user_id])
    |> foreign_key_constraint(:operation_id)
    |> foreign_key_constraint(:user_id)
  end
end
