# Migration for Enhanced Text Editor Tables
defmodule Frestyl.Repo.Migrations.CreateEnhancedTextEditor do
  use Ecto.Migration

  def change do
    # Documents table
    create table(:documents, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :document_type, :string, null: false
      add :status, :string, default: "draft"
      add :metadata, :map, default: %{}
      add :collaboration_settings, :map, default: %{}
      # Changed to :bigint to match users table
      add :user_id, references(:users, type: :bigint, on_delete: :delete_all), null: false
      # Changed to :bigint to match sessions table
      add :session_id, references(:sessions, type: :bigint, on_delete: :nilify_all)

      timestamps()
    end

    create index(:documents, [:user_id])
    create index(:documents, [:session_id])
    create index(:documents, [:document_type])
    create index(:documents, [:status])

    # Document blocks table
    create table(:document_blocks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :block_type, :string, null: false
      add :content, :string, default: ""
      add :position, :integer, null: false
      add :metadata, :map, default: %{}
      add :document_id, references(:documents, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:document_blocks, [:document_id])
    create index(:document_blocks, [:document_id, :position])
    create index(:document_blocks, [:block_type])

    # Media attachments table
    create table(:media_attachments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :attachment_type, :string, null: false
      add :position, :map, null: false # JSON: {type, offset, size, alignment}
      add :relationship, :string, null: false # illustrates, narrates, supports, etc.
      add :metadata, :map, default: %{}
      add :block_id, references(:document_blocks, type: :binary_id, on_delete: :delete_all), null: false
      # Changed to :bigint to match media_files table
      add :media_file_id, references(:media_files, type: :bigint, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:media_attachments, [:block_id])
    create index(:media_attachments, [:media_file_id])
    create index(:media_attachments, [:attachment_type])

    # Document versions table
    create table(:document_versions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :version_number, :string, null: false
      add :message, :string
      add :is_major, :boolean, default: false
      add :metadata, :map, default: %{}
      add :document_id, references(:documents, type: :binary_id, on_delete: :delete_all), null: false
      # Changed to :bigint to match users table
      add :created_by_id, references(:users, type: :bigint, on_delete: :nilify_all), null: false

      timestamps()
    end

    create index(:document_versions, [:document_id])
    create index(:document_versions, [:created_by_id])
    create unique_index(:document_versions, [:document_id, :version_number])

    # Collaboration branches table
    create table(:collaboration_branches, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :status, :string, default: "active"
      add :source_version, :string
      add :metadata, :map, default: %{}
      add :document_id, references(:documents, type: :binary_id, on_delete: :delete_all), null: false
      # Changed to :bigint to match users table
      add :created_by_id, references(:users, type: :bigint, on_delete: :nilify_all), null: false

      timestamps()
    end

    create index(:collaboration_branches, [:document_id])
    create index(:collaboration_branches, [:created_by_id])
    create unique_index(:collaboration_branches, [:document_id, :name])
  end
end
