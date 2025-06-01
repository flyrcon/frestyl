# Create a new migration:
# mix ecto.gen.migration add_last_activity_to_channel_memberships

defmodule Frestyl.Repo.Migrations.AddLastActivityToChannelMemberships do
  use Ecto.Migration

  def change do
    alter table(:channel_memberships) do
      modify :last_activity_at, :utc_datetime
    end
  end
end

# Then update your ChannelMembership schema to include:
# field :last_activity_at, :utc_datetime

# And update functions that create memberships to set this field
