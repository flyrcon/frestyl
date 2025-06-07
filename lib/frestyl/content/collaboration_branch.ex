defmodule Frestyl.Content.CollaborationBranch do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "collaboration_branches" do
    field :name, :string
    field :status, :string, default: "active"
    field :source_version, :string
    field :metadata, :map, default: %{}

    belongs_to :document, Frestyl.Content.Document, foreign_key: :document_id, type: :binary_id
    belongs_to :created_by, Frestyl.Accounts.User, foreign_key: :created_by_id, type: :binary_id

    timestamps()
  end

  def changeset(branch, attrs) do
    branch
    |> cast(attrs, [:name, :status, :source_version, :metadata, :document_id, :created_by_id])
    |> validate_required([:name, :document_id, :created_by_id])
    |> validate_inclusion(:status, ["active", "merged", "abandoned"])
    |> unique_constraint([:document_id, :name])
  end
end
