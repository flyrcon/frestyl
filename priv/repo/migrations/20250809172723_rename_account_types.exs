defmodule Frestyl.Repo.Migrations.RenameAccountTypes do
  use Ecto.Migration

  def up do
    execute """
    UPDATE accounts
    SET type = CASE
      WHEN type = 'personal' THEN 'individual'
      WHEN type = 'work' THEN 'business'
      WHEN type = 'team' THEN 'organization'
      ELSE type
    END
    """
  end

  def down do
    execute """
    UPDATE accounts
    SET type = CASE
      WHEN type = 'individual' THEN 'personal'
      WHEN type = 'business' THEN 'work'
      WHEN type = 'organization' THEN 'team'
      ELSE type
    END
    """
  end
end
