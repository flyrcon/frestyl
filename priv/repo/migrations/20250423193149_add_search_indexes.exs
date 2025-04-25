# Create a migration for adding search functionality
# priv/repo/migrations/add_search_indexes.exs
defmodule Frestyl.Repo.Migrations.AddSearchIndexes do
  use Ecto.Migration

  def up do
    # Create text search configuration
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm;"

    # Add tsvector columns to our tables
    alter table(:channels) do
      add :search_vector, :tsvector
    end

    alter table(:rooms) do
      add :search_vector, :tsvector
    end

    alter table(:messages) do
      add :search_vector, :tsvector
    end

    alter table(:file_attachments) do
      add :search_vector, :tsvector
    end

    # Create functions to generate the search vectors
    execute """
    CREATE OR REPLACE FUNCTION channel_search_vector_update() RETURNS trigger AS $$
    BEGIN
      NEW.search_vector :=
        setweight(to_tsvector('english', coalesce(NEW.name, '')), 'A') ||
        setweight(to_tsvector('english', coalesce(NEW.description, '')), 'B') ||
        setweight(to_tsvector('english', coalesce(NEW.category, '')), 'C');
      RETURN NEW;
    END
    $$ LANGUAGE plpgsql;
    """

    execute """
    CREATE OR REPLACE FUNCTION room_search_vector_update() RETURNS trigger AS $$
    BEGIN
      NEW.search_vector :=
        setweight(to_tsvector('english', coalesce(NEW.name, '')), 'A') ||
        setweight(to_tsvector('english', coalesce(NEW.description, '')), 'B');
      RETURN NEW;
    END
    $$ LANGUAGE plpgsql;
    """

    execute """
    CREATE OR REPLACE FUNCTION message_search_vector_update() RETURNS trigger AS $$
    BEGIN
      NEW.search_vector := to_tsvector('english', coalesce(NEW.content, ''));
      RETURN NEW;
    END
    $$ LANGUAGE plpgsql;
    """

    execute """
    CREATE OR REPLACE FUNCTION file_attachment_search_vector_update() RETURNS trigger AS $$
    BEGIN
      NEW.search_vector :=
        setweight(to_tsvector('english', coalesce(NEW.filename, '')), 'A') ||
        setweight(to_tsvector('english', coalesce(NEW.description, '')), 'B');
      RETURN NEW;
    END
    $$ LANGUAGE plpgsql;
    """

    # Create triggers to update search vectors automatically
    execute """
    CREATE TRIGGER channel_search_vector_update BEFORE INSERT OR UPDATE
    ON channels FOR EACH ROW EXECUTE FUNCTION channel_search_vector_update();
    """

    execute """
    CREATE TRIGGER room_search_vector_update BEFORE INSERT OR UPDATE
    ON rooms FOR EACH ROW EXECUTE FUNCTION room_search_vector_update();
    """

    execute """
    CREATE TRIGGER message_search_vector_update BEFORE INSERT OR UPDATE
    ON messages FOR EACH ROW EXECUTE FUNCTION message_search_vector_update();
    """

    execute """
    CREATE TRIGGER file_attachment_search_vector_update BEFORE INSERT OR UPDATE
    ON file_attachments FOR EACH ROW EXECUTE FUNCTION file_attachment_search_vector_update();
    """

    # Create GIN indexes on the search vectors
    create index(:channels, [:search_vector], using: "GIN")
    create index(:rooms, [:search_vector], using: "GIN")
    create index(:messages, [:search_vector], using: "GIN")
    create index(:file_attachments, [:search_vector], using: "GIN")

    # Update existing data
    execute "UPDATE channels SET search_vector = setweight(to_tsvector('english', coalesce(name, '')), 'A') || setweight(to_tsvector('english', coalesce(description, '')), 'B') || setweight(to_tsvector('english', coalesce(category, '')), 'C');"
    execute "UPDATE rooms SET search_vector = setweight(to_tsvector('english', coalesce(name, '')), 'A') || setweight(to_tsvector('english', coalesce(description, '')), 'B');"
    execute "UPDATE messages SET search_vector = to_tsvector('english', coalesce(content, ''));"
    execute "UPDATE file_attachments SET search_vector = setweight(to_tsvector('english', coalesce(filename, '')), 'A') || setweight(to_tsvector('english', coalesce(description, '')), 'B');"
  end

  def down do
    # Drop triggers
    execute "DROP TRIGGER IF EXISTS channel_search_vector_update ON channels;"
    execute "DROP TRIGGER IF EXISTS room_search_vector_update ON rooms;"
    execute "DROP TRIGGER IF EXISTS message_search_vector_update ON messages;"
    execute "DROP TRIGGER IF EXISTS file_attachment_search_vector_update ON file_attachments;"

    # Drop functions
    execute "DROP FUNCTION IF EXISTS channel_search_vector_update();"
    execute "DROP FUNCTION IF EXISTS room_search_vector_update();"
    execute "DROP FUNCTION IF EXISTS message_search_vector_update();"
    execute "DROP FUNCTION IF EXISTS file_attachment_search_vector_update();"

    # Remove columns
    alter table(:channels) do
      remove :search_vector
    end

    alter table(:rooms) do
      remove :search_vector
    end

    alter table(:messages) do
      remove :search_vector
    end

    alter table(:file_attachments) do
      remove :search_vector
    end
  end
end
