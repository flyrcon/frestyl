defmodule Frestyl.Repo.Migrations.AddRequireApprovalToPoportfolios do
  use Ecto.Migration

  def change do
    alter table(:portfolios) do
      add :require_approval, :boolean, default: false
    end
  end
end
