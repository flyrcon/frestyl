# priv/repo/migrations/create_portfolio_feedback.exs
defmodule Frestyl.Repo.Migrations.CreatePortfolioFeedback do
  use Ecto.Migration

  def change do
    create table(:portfolio_feedback) do
      add :content, :text, null: false
      add :feedback_type, :string, null: false, default: "comment"
      add :section_reference, :string  # Can store section ID or specific element reference
      add :metadata, :map, default: %{}  # For position data, highlighted text, etc.
      add :status, :string, null: false, default: "pending"

      add :portfolio_id, references(:portfolios, on_delete: :delete_all), null: false
      add :section_id, references(:portfolio_sections, on_delete: :delete_all), null: true
      add :share_id, references(:portfolio_shares, on_delete: :delete_all), null: true
      add :reviewer_id, references(:users, on_delete: :delete_all), null: true

      timestamps()
    end

    create index(:portfolio_feedback, [:portfolio_id])
    create index(:portfolio_feedback, [:section_id])
    create index(:portfolio_feedback, [:share_id])
    create index(:portfolio_feedback, [:reviewer_id])
    create index(:portfolio_feedback, [:status])
    create index(:portfolio_feedback, [:feedback_type])
    create index(:portfolio_feedback, [:inserted_at])
  end
end
