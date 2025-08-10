defmodule Frestyl.Repo.Migrations.UpdateAccountTypeConstraint do
  use Ecto.Migration

  def up do
    # Drop the old constraint
    execute "ALTER TABLE accounts DROP CONSTRAINT IF EXISTS valid_type"

    # Update the data
    execute """
    UPDATE accounts
    SET type = CASE
      WHEN type = 'personal' THEN 'individual'
      WHEN type = 'work' THEN 'business'
      WHEN type = 'team' THEN 'organization'
      ELSE type
    END
    """

    # Add new constraint with updated values
    execute """
    ALTER TABLE accounts
    ADD CONSTRAINT valid_type
    CHECK (type IN ('individual', 'business', 'organization', 'enterprise'))
    """
  end

  def down do
    # Drop new constraint
    execute "ALTER TABLE accounts DROP CONSTRAINT IF EXISTS valid_type"

    # Revert the data
    execute """
    UPDATE accounts
    SET type = CASE
      WHEN type = 'individual' THEN 'personal'
      WHEN type = 'business' THEN 'work'
      WHEN type = 'organization' THEN 'team'
      ELSE type
    END
    """

    # Add old constraint
    execute """
    ALTER TABLE accounts
    ADD CONSTRAINT valid_type
    CHECK (type IN ('personal', 'work', 'team'))
    """
  end
end
