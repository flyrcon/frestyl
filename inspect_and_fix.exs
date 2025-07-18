# inspect_and_fix.exs
# Run with: elixir -S mix run inspect_and_fix.exs

Application.ensure_all_started(:frestyl)

defmodule DatabaseInspector do
  def run do
    IO.puts("=== DATABASE INSPECTION ===")

    # Check if subscription_tier column exists
    result = Frestyl.Repo.query!("""
    SELECT column_name, data_type, is_nullable, column_default
    FROM information_schema.columns
    WHERE table_name = 'users'
    AND column_name LIKE '%subscription%';
    """)

    IO.puts("Subscription-related columns in users table:")
    IO.inspect(result.rows, label: "Columns")

    # Check if enum type exists
    enum_result = Frestyl.Repo.query!("""
    SELECT typname FROM pg_type WHERE typname = 'subscription_tier_enum';
    """)

    IO.puts("Enum type exists:")
    IO.inspect(enum_result.rows, label: "Enum")

    # Check user schema structure
    schema_result = Frestyl.Repo.query!("""
    SELECT column_name, data_type
    FROM information_schema.columns
    WHERE table_name = 'users'
    ORDER BY ordinal_position;
    """)

    IO.puts("All columns in users table:")
    Enum.each(schema_result.rows, fn [name, type] ->
      IO.puts("  #{name}: #{type}")
    end)

    fix_database()
  end

  def fix_database do
    IO.puts("\n=== FIXING DATABASE ===")

    # Check if subscription_tier column exists
    column_exists = Frestyl.Repo.query!("""
    SELECT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_name = 'users' AND column_name = 'subscription_tier'
    );
    """)

    column_exists = List.first(List.first(column_exists.rows))

    if column_exists do
      IO.puts("Column exists, converting to enum...")
      convert_existing_column()
    else
      IO.puts("Column doesn't exist, creating new column...")
      create_new_column()
    end
  end

  def convert_existing_column do
    Frestyl.Repo.transaction(fn ->
      # Clean up any existing values first
      Frestyl.Repo.query!("""
      UPDATE users
      SET subscription_tier = 'personal'
      WHERE subscription_tier NOT IN ('personal', 'creator', 'professional', 'enterprise')
         OR subscription_tier IS NULL;
      """)

      # Convert the column type from string to enum
      Frestyl.Repo.query!("""
      ALTER TABLE users
      ALTER COLUMN subscription_tier TYPE subscription_tier_enum
      USING subscription_tier::subscription_tier_enum;
      """)

      # Set default value and constraints
      Frestyl.Repo.query!("ALTER TABLE users ALTER COLUMN subscription_tier SET DEFAULT 'personal'::subscription_tier_enum;")
      Frestyl.Repo.query!("ALTER TABLE users ALTER COLUMN subscription_tier SET NOT NULL;")

      IO.puts("✅ Successfully converted existing column to enum!")
    end)
  rescue
    error ->
      IO.puts("❌ Error converting column: #{inspect(error)}")
  end

  def create_new_column do
    Frestyl.Repo.transaction(fn ->
      # Create enum type if it doesn't exist
      Frestyl.Repo.query!("""
      DO $$
      BEGIN
          IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'subscription_tier_enum') THEN
              CREATE TYPE subscription_tier_enum AS ENUM ('personal', 'creator', 'professional', 'enterprise');
          END IF;
      END$$;
      """)

      # Add the new column
      Frestyl.Repo.query!("""
      ALTER TABLE users
      ADD COLUMN subscription_tier subscription_tier_enum
      DEFAULT 'personal'::subscription_tier_enum NOT NULL;
      """)

      # Migrate from primary_account_type if it exists
      migrate_result = Frestyl.Repo.query!("""
      UPDATE users
      SET subscription_tier = CASE
        WHEN primary_account_type = 'personal' THEN 'personal'::subscription_tier_enum
        WHEN primary_account_type = 'professional' THEN 'professional'::subscription_tier_enum
        WHEN primary_account_type = 'enterprise' THEN 'enterprise'::subscription_tier_enum
        ELSE 'personal'::subscription_tier_enum
      END
      WHERE primary_account_type IS NOT NULL;
      """)

      IO.puts("✅ Successfully created new subscription_tier column!")
      IO.puts("✅ Migrated #{migrate_result.num_rows} users from primary_account_type")
    end)
  rescue
    error ->
      IO.puts("❌ Error creating column: #{inspect(error)}")
  end
end

DatabaseInspector.run()
