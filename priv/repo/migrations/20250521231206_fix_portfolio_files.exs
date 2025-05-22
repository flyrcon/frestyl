defmodule Frestyl.Repo.Migrations.FixPortfolioTables do
  use Ecto.Migration

  def change do
    # Create portfolios table if it doesn't exist
    create_if_not_exists table(:portfolios) do
      add :title, :string, null: false
      add :slug, :string, null: false
      add :description, :text
      add :visibility, :string, default: "link_only"
      add :expires_at, :utc_datetime
      add :approval_required, :boolean, default: false
      add :theme, :string, default: "default"
      add :custom_css, :text
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    # Create portfolio_sections table if it doesn't exist
    create_if_not_exists table(:portfolio_sections) do
      add :title, :string, null: false
      add :section_type, :string, null: false
      add :content, :map, default: %{}
      add :position, :integer, default: 0
      add :visible, :boolean, default: true
      add :portfolio_id, references(:portfolios, on_delete: :delete_all), null: false

      timestamps()
    end

    # Create portfolio_media table if it doesn't exist
    create_if_not_exists table(:portfolio_media) do
      add :title, :string
      add :description, :string
      add :media_type, :string, null: false
      add :file_path, :string, null: false
      add :file_size, :integer
      add :mime_type, :string
      add :visible, :boolean, default: true
      add :position, :integer, default: 0
      add :portfolio_id, references(:portfolios, on_delete: :delete_all), null: false
      add :section_id, references(:portfolio_sections, on_delete: :nilify_all)
      add :media_file_id, references(:media_files, on_delete: :nilify_all)

      timestamps()
    end

    # Create portfolio_shares table if it doesn't exist
    create_if_not_exists table(:portfolio_shares) do
      add :token, :string, null: false
      add :email, :string
      add :name, :string
      add :expires_at, :utc_datetime
      add :access_count, :integer, default: 0
      add :last_accessed_at, :utc_datetime
      add :approved, :boolean, default: false
      add :portfolio_id, references(:portfolios, on_delete: :delete_all), null: false

      timestamps()
    end

    # Create portfolio_visits table if it doesn't exist
    create_if_not_exists table(:portfolio_visits) do
      add :ip_address, :string
      add :user_agent, :string
      add :referrer, :string
      add :portfolio_id, references(:portfolios, on_delete: :delete_all), null: false
      add :share_id, references(:portfolio_shares, on_delete: :nilify_all)

      timestamps()
    end

    # Add missing columns to existing tables
    alter table(:portfolio_shares) do
      add_if_not_exists :approved, :boolean, default: false
      add_if_not_exists :name, :string
      add_if_not_exists :expires_at, :utc_datetime
      add_if_not_exists :access_count, :integer, default: 0
      add_if_not_exists :last_accessed_at, :utc_datetime
    end

    # Create indexes if they don't exist
    create_if_not_exists index(:portfolios, [:user_id])
    create_if_not_exists unique_index(:portfolios, [:slug, :user_id])
    create_if_not_exists index(:portfolio_sections, [:portfolio_id])
    create_if_not_exists index(:portfolio_sections, [:portfolio_id, :position])
    create_if_not_exists index(:portfolio_media, [:portfolio_id])
    create_if_not_exists index(:portfolio_media, [:section_id])
    create_if_not_exists index(:portfolio_shares, [:portfolio_id])
    create_if_not_exists unique_index(:portfolio_shares, [:token])
    create_if_not_exists index(:portfolio_visits, [:portfolio_id])
    create_if_not_exists index(:portfolio_visits, [:share_id])
  end
end
