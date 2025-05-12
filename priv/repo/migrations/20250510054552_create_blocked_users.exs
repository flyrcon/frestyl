# priv/repo/migrations/YYYYMMDDHHMMSS_create_blocked_users.exs
defmodule Frestyl.Repo.Migrations.CreateBlockedUsers do
  use Ecto.Migration

  def change do
    create table(:blocked_users) do
      add :reason, :string
      add :expires_at, :utc_datetime
      add :block_level, :string, default: "channel"
      add :restrictions, {:array, :string}, default: ["all"]
      add :email, :string
      add :notes, :string

      add :channel_id, references(:channels, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :nilify_all)
      add :blocked_by_user_id, references(:users, on_delete: :nilify_all), null: false

      timestamps()
    end

    create index(:blocked_users, [:channel_id])
    create index(:blocked_users, [:user_id])
    create unique_index(:blocked_users, [:user_id, :channel_id])
    create unique_index(:blocked_users, [:email, :channel_id])
  end
end
