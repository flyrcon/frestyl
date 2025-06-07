# lib/frestyl/content/schemas.ex - Document Schemas
defmodule Frestyl.Content.Document do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "documents" do
    field :title, :string
    field :document_type, :string
    field :status, :string, default: "draft"
    field :metadata, :map, default: %{}
    field :collaboration_settings, :map, default: %{}
    field :session_id, :binary_id

    belongs_to :user, Frestyl.Accounts.User, foreign_key: :user_id, type: :binary_id
    has_many :blocks, Frestyl.Content.DocumentBlock, foreign_key: :document_id
    has_many :versions, Frestyl.Content.DocumentVersion, foreign_key: :document_id
    has_many :collaboration_branches, Frestyl.Content.CollaborationBranch, foreign_key: :document_id

    timestamps()
  end

  def changeset(document, attrs) do
    document
    |> cast(attrs, [:title, :document_type, :status, :metadata, :collaboration_settings, :user_id, :session_id])
    |> validate_required([:title, :document_type, :user_id])
    |> validate_inclusion(:status, ["draft", "published", "archived"])
    |> validate_inclusion(:document_type, [
      "thought_leadership", "content_marketing", "investigative_journalism",
      "literary_fiction", "business_book", "children_picture_book", "technical_manual",
      "screenwriting", "academic_paper", "poetry_collection"
    ])
  end
end
