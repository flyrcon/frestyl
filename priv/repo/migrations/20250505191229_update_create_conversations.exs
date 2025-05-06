defmodule Frestyl.Repo.Migrations.CreateConversations do
  use Ecto.Migration

  def change do
    alter table(:conversations) do
      add_if_not_exists :title, :string
      add_if_not_exists :last_message_at, :utc_datetime
      add_if_not_exists :unread_count, :integer, default: 0

    end

    alter table(:conversation_participants) do
      add :last_read_at, :utc_datetime
      add :unread_count, :integer, default: 0

    end

    create index(:conversations, [:last_message_at])

  end
end
