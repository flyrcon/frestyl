# priv/repo/migrations/20250108000003_add_missing_story_fields.exs
defmodule Frestyl.Repo.Migrations.AddMissingStoryFields do
  use Ecto.Migration

  def change do
    # Add any missing fields to stories table using direct SQL to avoid conflicts
    alter table(:enhanced_story_structures) do
      add_if_not_exists :collaborators, {:array, :string}, default: []
      add_if_not_exists :progress, :integer, default: 0
      add_if_not_exists :audio_quality, :string
      add_if_not_exists :sketch_strokes, {:array, :map}, default: []
      add_if_not_exists :export_formats, {:array, :string}, default: []
    end

    # Add missing fields to voice sketch sessions if table exists using conditional SQL
    execute """
    DO $$
    BEGIN
      -- Check if enhanced_story_structures table exists and add missing columns
      IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'enhanced_story_structures') THEN
        -- Add collaborators column if it doesn't exist
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                      WHERE table_name = 'enhanced_story_structures' AND column_name = 'collaborators') THEN
          ALTER TABLE enhanced_story_structures ADD COLUMN collaborators text[] DEFAULT '{}';
        END IF;

        -- Add progress column if it doesn't exist
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                      WHERE table_name = 'enhanced_story_structures' AND column_name = 'progress') THEN
          ALTER TABLE enhanced_story_structures ADD COLUMN progress integer DEFAULT 0;
        END IF;

        -- Add audio_quality column if it doesn't exist
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                      WHERE table_name = 'enhanced_story_structures' AND column_name = 'audio_quality') THEN
          ALTER TABLE enhanced_story_structures ADD COLUMN audio_quality varchar(255) DEFAULT 'standard';
        END IF;

        -- Add sketch_strokes column if it doesn't exist
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                      WHERE table_name = 'enhanced_story_structures' AND column_name = 'sketch_strokes') THEN
          ALTER TABLE enhanced_story_structures ADD COLUMN sketch_strokes jsonb[] DEFAULT '{}';
        END IF;

        -- Add export_formats column if it doesn't exist
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                      WHERE table_name = 'enhanced_story_structures' AND column_name = 'export_formats') THEN
          ALTER TABLE enhanced_story_structures ADD COLUMN export_formats text[] DEFAULT '{}';
        END IF;
      END IF;

      -- Handle voice_sketch_sessions table if it exists
      IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'voice_sketch_sessions') THEN
        -- Add collaborators column if it doesn't exist
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                      WHERE table_name = 'voice_sketch_sessions' AND column_name = 'collaborators') THEN
          ALTER TABLE voice_sketch_sessions ADD COLUMN collaborators jsonb DEFAULT '[]';
        END IF;

        -- Add progress column if it doesn't exist
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                      WHERE table_name = 'voice_sketch_sessions' AND column_name = 'progress') THEN
          ALTER TABLE voice_sketch_sessions ADD COLUMN progress integer DEFAULT 0;
        END IF;

        -- Add audio_quality column if it doesn't exist
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                      WHERE table_name = 'voice_sketch_sessions' AND column_name = 'audio_quality') THEN
          ALTER TABLE voice_sketch_sessions ADD COLUMN audio_quality varchar(255) DEFAULT 'standard';
        END IF;

        -- Add sketch_strokes column if it doesn't exist
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                      WHERE table_name = 'voice_sketch_sessions' AND column_name = 'sketch_strokes') THEN
          ALTER TABLE voice_sketch_sessions ADD COLUMN sketch_strokes jsonb DEFAULT '[]';
        END IF;
      END IF;
    END $$;
    """, ""

    # Create indexes for better performance (only if they don't exist)
    execute """
    DO $$
    BEGIN
      -- Create index on collaborators if table and column exist
      IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'enhanced_story_structures')
         AND EXISTS (SELECT FROM information_schema.columns WHERE table_name = 'enhanced_story_structures' AND column_name = 'collaborators') THEN
        IF NOT EXISTS (SELECT FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
                      WHERE c.relname = 'enhanced_story_structures_collaborators_index' AND n.nspname = 'public') THEN
          CREATE INDEX enhanced_story_structures_collaborators_index ON enhanced_story_structures USING gin(collaborators);
        END IF;
      END IF;

      -- Create index on progress if column exists
      IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'enhanced_story_structures')
         AND EXISTS (SELECT FROM information_schema.columns WHERE table_name = 'enhanced_story_structures' AND column_name = 'progress') THEN
        IF NOT EXISTS (SELECT FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
                      WHERE c.relname = 'enhanced_story_structures_progress_index' AND n.nspname = 'public') THEN
          CREATE INDEX enhanced_story_structures_progress_index ON enhanced_story_structures(progress);
        END IF;
      END IF;
    END $$;
    """, ""
  end

  def down do
    # Remove the added columns if rolling back
    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'enhanced_story_structures') THEN
        IF EXISTS (SELECT FROM information_schema.columns WHERE table_name = 'enhanced_story_structures' AND column_name = 'collaborators') THEN
          ALTER TABLE enhanced_story_structures DROP COLUMN collaborators;
        END IF;

        IF EXISTS (SELECT FROM information_schema.columns WHERE table_name = 'enhanced_story_structures' AND column_name = 'progress') THEN
          ALTER TABLE enhanced_story_structures DROP COLUMN progress;
        END IF;

        IF EXISTS (SELECT FROM information_schema.columns WHERE table_name = 'enhanced_story_structures' AND column_name = 'audio_quality') THEN
          ALTER TABLE enhanced_story_structures DROP COLUMN audio_quality;
        END IF;

        IF EXISTS (SELECT FROM information_schema.columns WHERE table_name = 'enhanced_story_structures' AND column_name = 'sketch_strokes') THEN
          ALTER TABLE enhanced_story_structures DROP COLUMN sketch_strokes;
        END IF;

        IF EXISTS (SELECT FROM information_schema.columns WHERE table_name = 'enhanced_story_structures' AND column_name = 'export_formats') THEN
          ALTER TABLE enhanced_story_structures DROP COLUMN export_formats;
        END IF;
      END IF;

      -- Handle voice_sketch_sessions table
      IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'voice_sketch_sessions') THEN
        IF EXISTS (SELECT FROM information_schema.columns WHERE table_name = 'voice_sketch_sessions' AND column_name = 'collaborators') THEN
          ALTER TABLE voice_sketch_sessions DROP COLUMN collaborators;
        END IF;

        IF EXISTS (SELECT FROM information_schema.columns WHERE table_name = 'voice_sketch_sessions' AND column_name = 'progress') THEN
          ALTER TABLE voice_sketch_sessions DROP COLUMN progress;
        END IF;

        IF EXISTS (SELECT FROM information_schema.columns WHERE table_name = 'voice_sketch_sessions' AND column_name = 'audio_quality') THEN
          ALTER TABLE voice_sketch_sessions DROP COLUMN audio_quality;
        END IF;

        IF EXISTS (SELECT FROM information_schema.columns WHERE table_name = 'voice_sketch_sessions' AND column_name = 'sketch_strokes') THEN
          ALTER TABLE voice_sketch_sessions DROP COLUMN sketch_strokes;
        END IF;
      END IF;
    END $$;
    """
  end
end
