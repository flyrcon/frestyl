defmodule Frestyl.Repo.Migrations.UpdatePortfolioSections do
  use Ecto.Migration

  def change do
    alter table(:portfolio_sections) do
      modify :section_type, :string  # Temporarily change to string
    end
  end

end
