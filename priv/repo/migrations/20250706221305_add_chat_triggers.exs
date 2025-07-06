# priv/repo/migrations/20250706_add_chat_triggers.exs

defmodule Frestyl.Repo.Migrations.AddChatTriggers do
  use Ecto.Migration

  def up do
    # Trigger to update conversation last_message_at when new message is added
    execute """
    CREATE OR REPLACE FUNCTION update_conversation_last_message()
    RETURNS TRIGGER AS $$
    BEGIN
      UPDATE conversations
      SET last_message_at = NEW.inserted_at,
          last_message_id = NEW.id,
          updated_at = NEW.inserted_at
      WHERE id = NEW.conversation_id;
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """

    execute """
    CREATE TRIGGER update_conversation_last_message_trigger
    AFTER INSERT ON messages
    FOR EACH ROW
    EXECUTE FUNCTION update_conversation_last_message();
    """

    # Trigger to update participant unread count
    execute """
    CREATE OR REPLACE FUNCTION update_participant_unread_count()
    RETURNS TRIGGER AS $$
    BEGIN
      UPDATE participants
      SET unread_count = unread_count + 1
      WHERE conversation_id = NEW.conversation_id
      AND user_id != NEW.user_id;
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """

    execute """
    CREATE TRIGGER update_participant_unread_count_trigger
    AFTER INSERT ON messages
    FOR EACH ROW
    EXECUTE FUNCTION update_participant_unread_count();
    """

    # Function to clean up expired notifications
    execute """
    CREATE OR REPLACE FUNCTION cleanup_expired_notifications()
    RETURNS void AS $$
    BEGIN
      DELETE FROM notifications
      WHERE expires_at IS NOT NULL
      AND expires_at < NOW();
    END;
    $$ LANGUAGE plpgsql;
    """
  end

  def down do
    execute "DROP TRIGGER IF EXISTS update_conversation_last_message_trigger ON messages;"
    execute "DROP TRIGGER IF EXISTS update_participant_unread_count_trigger ON messages;"
    execute "DROP FUNCTION IF EXISTS update_conversation_last_message();"
    execute "DROP FUNCTION IF EXISTS update_participant_unread_count();"
    execute "DROP FUNCTION IF EXISTS cleanup_expired_notifications();"
  end
end
