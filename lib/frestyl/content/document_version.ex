defmodule Frestyl.Content.DocumentVersion do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "document_versions" do
    field :version_number, :string
    field :message, :string
    field :is_major, :boolean, default: false
    field :metadata, :map, default: %{}

    belongs_to :document, Frestyl.Content.Document, foreign_key: :document_id, type: :binary_id
    belongs_to :created_by, Frestyl.Accounts.User, foreign_key: :created_by_id, type: :binary_id

    timestamps()
  end

  def changeset(version, attrs) do
    version
    |> cast(attrs, [:version_number, :message, :is_major, :metadata, :document_id, :created_by_id])
    |> validate_required([:version_number, :document_id, :created_by_id])
  end
end
