defmodule Frestyl.Repo.Migrations.AddFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      # Add all the missing columns
      add :confirmed_at, :utc_datetime
      add_if_not_exists :status, :string, default: "active"
      add_if_not_exists :role, :string, default: "user"
      add_if_not_exists :subscription_tier, :string, default: "free"
      add :full_name, :string
      add_if_not_exists :bio, :text
      add_if_not_exists :avatar_url, :string
      add_if_not_exists :website, :string
      add_if_not_exists :social_links, :map, default: "'{}'::jsonb"
      add_if_not_exists :last_active_at, :utc_datetime
    end
  end
end
