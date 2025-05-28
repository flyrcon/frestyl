# lib/frestyl/portfolios/portfolio_feedback.ex
defmodule Frestyl.Portfolios.PortfolioFeedback do
  use Ecto.Schema
  import Ecto.Changeset

  schema "portfolio_feedback" do
    field :content, :string
    field :feedback_type, Ecto.Enum, values: [:comment, :suggestion, :highlight, :note], default: :comment
    field :section_reference, :string  # References specific portfolio section
    field :metadata, :map, default: %{}  # For storing position data, highlighted text, etc.
    field :status, Ecto.Enum, values: [:pending, :reviewed, :implemented, :dismissed], default: :pending

    belongs_to :portfolio, Frestyl.Portfolios.Portfolio
    belongs_to :section, Frestyl.Portfolios.PortfolioSection
    belongs_to :share, Frestyl.Portfolios.PortfolioShare
    belongs_to :reviewer, Frestyl.Accounts.User

    timestamps()
  end

  def changeset(feedback, attrs) do
    feedback
    |> cast(attrs, [:content, :feedback_type, :section_reference, :metadata, :status,
                    :portfolio_id, :section_id, :share_id, :reviewer_id])
    |> validate_required([:content, :feedback_type, :portfolio_id])
    |> validate_length(:content, min: 5, max: 2000)
    |> foreign_key_constraint(:portfolio_id)
    |> foreign_key_constraint(:section_id)
    |> foreign_key_constraint(:share_id)
    |> foreign_key_constraint(:reviewer_id)
  end

  def quick_note_changeset(feedback, attrs) do
    feedback
    |> cast(attrs, [:content, :section_reference, :metadata, :portfolio_id, :share_id, :reviewer_id])
    |> put_change(:feedback_type, :note)
    |> validate_required([:content, :portfolio_id])
    |> validate_length(:content, min: 3, max: 500)
  end

  def highlight_changeset(feedback, attrs) do
    feedback
    |> cast(attrs, [:content, :section_reference, :metadata, :portfolio_id, :share_id, :reviewer_id])
    |> put_change(:feedback_type, :highlight)
    |> validate_required([:content, :portfolio_id])
    |> validate_length(:content, min: 1, max: 1000)
  end
end
