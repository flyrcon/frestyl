# Create this file: priv/repo/migrations/XXXXXX_add_missing_user_fields.exs
# Run: mix ecto.gen.migration add_missing_user_fields

defmodule Frestyl.Repo.Migrations.AddMissingUserFields do
  use Ecto.Migration

  def up do
    # Get current columns to check what exists
    existing_columns = query_existing_columns()

    alter table(:users) do
      # Add missing authentication fields
      unless "hashed_password" in existing_columns do
        add :hashed_password, :string
      end

      unless "confirmed_at" in existing_columns do
        add :confirmed_at, :utc_datetime
      end

      # Add missing profile fields
      unless "username" in existing_columns do
        add :username, :string
      end

      unless "display_name" in existing_columns do
        add :display_name, :string
      end

      unless "avatar_url" in existing_columns do
        add :avatar_url, :string
      end

      unless "bio" in existing_columns do
        add :bio, :text
      end

      unless "preferences" in existing_columns do
        add :preferences, :map, default: %{}
      end
    end

    # Add indexes for performance (only if columns were added)
    unless "username" in existing_columns do
      create unique_index(:users, [:username])
    end

    create index(:users, [:confirmed_at])
  end

  def down do
    drop_if_exists index(:users, [:confirmed_at])
    drop_if_exists index(:users, [:username])

    alter table(:users) do
      remove :preferences
      remove :bio
      remove :avatar_url
      remove :display_name
      remove :username
      remove :confirmed_at
      remove :hashed_password
    end
  end

  defp query_existing_columns do
    result = Frestyl.Repo.query!("""
      SELECT column_name
      FROM information_schema.columns
      WHERE table_name = 'users'
      AND table_schema = 'public'
    """)

    Enum.map(result.rows, fn [column_name] -> column_name end)
  end
end
