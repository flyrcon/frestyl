defmodule Frestyl.Repo.Migrations.AddChatIndexes do
  use Ecto.Migration

  # Disable transaction for this migration to allow CONCURRENTLY
  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    # Composite indexes for better query performance
    create_if_not_exists index(:conversations, [:context, :context_id, :last_message_at])
    create_if_not_exists index(:participants, [:user_id, :last_read_at])
    create_if_not_exists index(:messages, [:conversation_id, :inserted_at])

    # Check if notifications table exists before creating index
    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'notifications') THEN
        IF NOT EXISTS (
          SELECT 1 FROM pg_indexes
          WHERE tablename = 'notifications' AND indexname = 'notifications_user_id_read_at_inserted_at_index'
        ) THEN
          CREATE INDEX notifications_user_id_read_at_inserted_at_index
          ON notifications (user_id, read_at, inserted_at);
        END IF;
      END IF;
    END $$;
    """

    # Partial indexes for unread items (check if tables exist first)
    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'conversation_participants') THEN
        IF NOT EXISTS (
          SELECT 1 FROM pg_indexes
          WHERE tablename = 'conversation_participants' AND indexname = 'participants_with_unread_messages'
        ) THEN
          CREATE INDEX participants_with_unread_messages
          ON conversation_participants (user_id) WHERE unread_count > 0;
        END IF;
      END IF;
    END $$;
    """

    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'notifications') THEN
        IF NOT EXISTS (
          SELECT 1 FROM pg_indexes
          WHERE tablename = 'notifications' AND indexname = 'unread_notifications_by_type'
        ) THEN
          CREATE INDEX unread_notifications_by_type
          ON notifications (user_id, type) WHERE read_at IS NULL;
        END IF;
      END IF;
    END $$;
    """

    # Text search indexes (check if tables exist)
    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'messages') THEN
        IF NOT EXISTS (
          SELECT 1 FROM pg_indexes
          WHERE tablename = 'messages' AND indexname = 'messages_content_search'
        ) THEN
          CREATE INDEX messages_content_search
          ON messages USING gin(to_tsvector('english', content));
        END IF;
      END IF;
    END $$;
    """

    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'conversations') THEN
        IF NOT EXISTS (
          SELECT 1 FROM pg_indexes
          WHERE tablename = 'conversations' AND indexname = 'conversations_title_search'
        ) THEN
          CREATE INDEX conversations_title_search
          ON conversations USING gin(to_tsvector('english', title))
          WHERE title IS NOT NULL;
        END IF;
      END IF;
    END $$;
    """
  end

  def down do
    drop_if_exists index(:conversations, [:context, :context_id, :last_message_at])
    drop_if_exists index(:participants, [:user_id, :last_read_at])
    drop_if_exists index(:messages, [:conversation_id, :inserted_at])

    execute "DROP INDEX IF EXISTS notifications_user_id_read_at_inserted_at_index;"
    execute "DROP INDEX IF EXISTS participants_with_unread_messages;"
    execute "DROP INDEX IF EXISTS unread_notifications_by_type;"
    execute "DROP INDEX IF EXISTS messages_content_search;"
    execute "DROP INDEX IF EXISTS conversations_title_search;"
  end
end
