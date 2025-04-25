# Update the channel_memberships table
defmodule Frestyl.Repo.Migrations.UpdateChannelMemberships do
  use Ecto.Migration

  def change do
    alter table(:channel_memberships) do
      add :role_id, references(:roles, on_delete: :restrict)
      add :can_send_messages, :boolean, default: true, null: false
      add :can_manage_members, :boolean, default: false, null: false
      add :can_create_rooms, :boolean, default: false, null: false
      remove :role
    end
  end
end
