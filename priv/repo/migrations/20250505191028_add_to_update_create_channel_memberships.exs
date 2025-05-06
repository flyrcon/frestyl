defmodule Frestyl.Repo.Migrations.CreateChannelMemberships do
  use Ecto.Migration

  def change do
    alter table(:channel_memberships) do
      modify :role, :string, default: "member", null: false
      add_if_not_exists :can_send_messages, :boolean, default: true
      add :can_upload_files, :boolean, default: true
      add :can_invite_users, :boolean, default: false
    end

    create index(:channel_memberships, [:status])
  end
end
