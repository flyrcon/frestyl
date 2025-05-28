defmodule Frestyl.Repo.Migrations.AddMissingPortfolioMediaFields do
  use Ecto.Migration

  def change do
    # Add missing columns to portfolio_media table that the template expects
    alter table(:portfolio_media) do
      add_if_not_exists :title, :string
      add_if_not_exists :description, :text
    end

    # Make sure we have the portfolio_media table if it doesn't exist
    create_if_not_exists table(:portfolio_media) do
      add :title, :string
      add :description, :text
      add :media_type, :string
      add :file_path, :string
      add :file_size, :integer
      add :mime_type, :string
      add :visible, :boolean, default: true
      add :position, :integer, default: 0
      add :portfolio_id, references(:portfolios, on_delete: :delete_all)
      add :section_id, references(:portfolio_sections, on_delete: :delete_all)
      add :media_file_id, references(:media_files, on_delete: :delete_all), null: true

      timestamps()
    end

    create_if_not_exists index(:portfolio_media, [:portfolio_id])
    create_if_not_exists index(:portfolio_media, [:section_id])
    create_if_not_exists index(:portfolio_media, [:position])

    # Add template_theme field to portfolios if it doesn't exist
    alter table(:portfolios) do
      add_if_not_exists :template_theme, :string, default: "creative"
    end

    # Create portfolio_shares table if it doesn't exist (for sharing functionality)
    create_if_not_exists table(:portfolio_shares) do
      add :token, :string, null: false
      add :name, :string
      add :expires_at, :utc_datetime
      add :view_count, :integer, default: 0
      add :portfolio_id, references(:portfolios, on_delete: :delete_all), null: false

      timestamps()
    end

    create_if_not_exists unique_index(:portfolio_shares, [:token])
    create_if_not_exists index(:portfolio_shares, [:portfolio_id])
  end
end
