defmodule Frestyl.Repo.Migrations.FixPortfolioVisibility do
  use Ecto.Migration

  def up do
    # If you had any old boolean fields or need to set default values
    execute """
    UPDATE portfolios
    SET visibility = 'link_only'
    WHERE visibility IS NULL
    """
  end

  def down do
    # Rollback logic if needed
  end
end
