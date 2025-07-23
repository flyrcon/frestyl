# lib/frestyl/content/contribution_session.ex
defmodule Frestyl.Content.ContributionSession do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "contribution_sessions" do
    field :session_start, :utc_datetime
    field :session_end, :utc_datetime
    field :words_contributed, :integer, default: 0
    field :edits_count, :integer, default: 0
    field :sections_edited, {:array, :string}, default: []
    field :contribution_metadata, :map, default: %{}

    belongs_to :document, Frestyl.Content.Document, type: :binary_id  # documents uses UUID
    belongs_to :user, Frestyl.Accounts.User, type: :id  # users uses bigint

    timestamps()
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [
      :session_start, :session_end, :words_contributed, :edits_count,
      :sections_edited, :contribution_metadata, :document_id, :user_id
    ])
    |> validate_required([:document_id, :user_id])
    |> validate_number(:words_contributed, greater_than_or_equal_to: 0)
    |> validate_number(:edits_count, greater_than_or_equal_to: 0)
  end
end
