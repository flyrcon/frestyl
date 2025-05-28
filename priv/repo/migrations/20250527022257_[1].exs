# Replace your migration with this simpler version:

defmodule Frestyl.Repo.Migrations.AddAllMissingPortfolioMediaFields do
  use Ecto.Migration

  def up do
    # Add missing columns to portfolio_media table
    # Note: If columns already exist, this will throw an error but won't break anything
    alter table(:portfolio_media) do
      add_if_not_exists :title, :string
      add_if_not_exists :description, :text
      add_if_not_exists :media_type, :string
      add_if_not_exists :file_path, :string
      add_if_not_exists :file_size, :integer
      add_if_not_exists :mime_type, :string
      add_if_not_exists :visible, :boolean, default: true
      add_if_not_exists :position, :integer, default: 0
      add_if_not_exists :media_file_id, references(:media_files, on_delete: :delete_all)
    end

    # Add template_theme to portfolios
    alter table(:portfolios) do
      modify :template_theme, :string, default: "creative"
    end

    # Create portfolio_shares table
    alter table(:portfolio_shares) do
      add_if_not_exists :name, :string
      add_if_not_exists :expires_at, :utc_datetime
      add_if_not_exists :view_count, :integer, default: 0

    end

    create_if_not_exists unique_index(:portfolio_shares, [:token])
    create_if_not_exists index(:portfolio_shares, [:portfolio_id])
  end

  def down do
    drop table(:portfolio_shares)

    alter table(:portfolios) do
      remove :template_theme
    end

    alter table(:portfolio_media) do
      remove :title
      remove :description
      remove :media_type
      remove :file_path
      remove :file_size
      remove :mime_type
      remove :visible
      remove :position
      remove :portfolio_id
      remove :section_id
      remove :media_file_id
    end
  end
end
