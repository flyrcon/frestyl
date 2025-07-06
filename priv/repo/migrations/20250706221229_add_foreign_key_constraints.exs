defmodule Frestyl.Repo.Migrations.FixConversationParticipantsTable do
  use Ecto.Migration

  def up do
    # First, let's see what columns exist
    execute """
    DO $$
    DECLARE
        col_exists boolean;
    BEGIN
        -- Check if role column exists
        SELECT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_name = 'conversation_participants' AND column_name = 'role'
        ) INTO col_exists;

        IF NOT col_exists THEN
            ALTER TABLE conversation_participants ADD COLUMN role VARCHAR DEFAULT 'member';
        END IF;

        -- Check if joined_at column exists
        SELECT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_name = 'conversation_participants' AND column_name = 'joined_at'
        ) INTO col_exists;

        IF NOT col_exists THEN
            ALTER TABLE conversation_participants ADD COLUMN joined_at TIMESTAMP;
        END IF;

        -- Check if last_read_at column exists
        SELECT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_name = 'conversation_participants' AND column_name = 'last_read_at'
        ) INTO col_exists;

        IF NOT col_exists THEN
            ALTER TABLE conversation_participants ADD COLUMN last_read_at TIMESTAMP;
        END IF;

        -- Check if unread_count column exists
        SELECT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_name = 'conversation_participants' AND column_name = 'unread_count'
        ) INTO col_exists;

        IF NOT col_exists THEN
            ALTER TABLE conversation_participants ADD COLUMN unread_count INTEGER DEFAULT 0;
        END IF;

        -- Check if notifications_enabled column exists
        SELECT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_name = 'conversation_participants' AND column_name = 'notifications_enabled'
        ) INTO col_exists;

        IF NOT col_exists THEN
            ALTER TABLE conversation_participants ADD COLUMN notifications_enabled BOOLEAN DEFAULT TRUE;
        END IF;

        -- Check if timestamps exist
        SELECT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_name = 'conversation_participants' AND column_name = 'inserted_at'
        ) INTO col_exists;

        IF NOT col_exists THEN
            ALTER TABLE conversation_participants ADD COLUMN inserted_at TIMESTAMP DEFAULT NOW();
        END IF;

        SELECT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_name = 'conversation_participants' AND column_name = 'updated_at'
        ) INTO col_exists;

        IF NOT col_exists THEN
            ALTER TABLE conversation_participants ADD COLUMN updated_at TIMESTAMP DEFAULT NOW();
        END IF;
    END $$;
    """

    # Now add the check constraint for role
    execute """
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM information_schema.check_constraints
        WHERE constraint_name = 'valid_participant_role'
      ) THEN
        ALTER TABLE conversation_participants ADD CONSTRAINT valid_participant_role
        CHECK (role IN ('member', 'admin', 'moderator'));
      END IF;
    END $$;
    """
  end

  def down do
    alter table(:conversation_participants) do
      remove_if_exists :role, :string
      remove_if_exists :joined_at, :utc_datetime
      remove_if_exists :last_read_at, :utc_datetime
      remove_if_exists :unread_count, :integer
      remove_if_exists :notifications_enabled, :boolean
    end

    execute "ALTER TABLE conversation_participants DROP CONSTRAINT IF EXISTS valid_participant_role;"
  end
end
