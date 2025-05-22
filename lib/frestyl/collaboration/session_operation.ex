defmodule Frestyl.Collaboration.SessionOperation do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "session_operations" do
    field :operation_type, :string
    field :action, :string
    field :data, :map
    field :version, :integer
    field :transformed_by, {:array, :binary_id}, default: []
    field :acknowledged, :boolean, default: false
    field :conflict_resolution, :map

    belongs_to :session, Frestyl.Sessions.Session
    belongs_to :user, Frestyl.Accounts.User

    has_many :acknowledgments, Frestyl.Collaboration.OperationAcknowledgment, foreign_key: :operation_id

    timestamps()
  end

  def changeset(operation, attrs) do
    operation
    |> cast(attrs, [:session_id, :user_id, :operation_type, :action, :data, :version, :transformed_by, :acknowledged, :conflict_resolution])
    |> validate_required([:session_id, :user_id, :operation_type, :action, :data, :version])
    |> validate_inclusion(:operation_type, ["text", "audio", "visual", "midi"])
    |> foreign_key_constraint(:session_id)
    |> foreign_key_constraint(:user_id)
  end
end
