# priv/repo/migrations/xxx_create_user_blocks.exs
defmodule Frestyl.Repo.Migrations.CreateUserBlocks do
  use Ecto.Migration

  def change do
    create table(:user_blocks) do
      add :reason, :string
      add :blocked_until, :utc_datetime
      add :is_permanent, :boolean, default: false

      add :blocker_id, references(:users, on_delete: :delete_all), null: false
      add :blocked_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:user_blocks, [:blocker_id, :blocked_id])
    create index(:user_blocks, [:blocked_id])
  end
end
