defmodule Frestyl.Repo.Migrations.FixConversationsNullType do
  use Ecto.Migration

  def up do
    alter table(:conversations) do
      add_if_not_exists :type, :string, default: "direct"
      add_if_not_exists :context, :string, default: "general"
      add_if_not_exists :context_id, :integer
      add_if_not_exists :metadata, :map, default: %{}
      add_if_not_exists :is_group, :boolean, default: false
      add_if_not_exists :is_archived, :boolean, default: false
    end

    # Update any NULL values
    execute """
    UPDATE conversations
    SET type = 'direct'
    WHERE type IS NULL
    """

    execute """
    UPDATE conversations
    SET context = 'general'
    WHERE context IS NULL
    """
  end

  def down do
    alter table(:conversations) do
      remove_if_exists :type, :string
      remove_if_exists :context, :string
      remove_if_exists :context_id, :integer
      remove_if_exists :metadata, :map
      remove_if_exists :is_group, :boolean
      remove_if_exists :is_archived, :boolean
    end
  end
end
