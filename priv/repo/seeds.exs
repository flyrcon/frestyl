# priv/repo/seeds.exs
# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Frestyl.Repo.insert!(%Frestyl.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Frestyl.Repo
alias Frestyl.Channels.{Permission, Role}

# Create permissions
permissions = [
  %{name: "view_channel", description: "Can view the channel and its content"},
  %{name: "manage_channel", description: "Can update channel settings"},
  %{name: "delete_channel", description: "Can delete the channel"},
  %{name: "create_room", description: "Can create new rooms"},
  %{name: "manage_room", description: "Can update room settings"},
  %{name: "delete_room", description: "Can delete rooms"},
  %{name: "send_messages", description: "Can send messages in rooms"},
  %{name: "delete_messages", description: "Can delete any message (not just own)"},
  %{name: "manage_members", description: "Can add/remove members"},
  %{name: "assign_roles", description: "Can assign roles to members"}
]

# Insert permissions
inserted_permissions = Enum.map(permissions, fn perm ->
  Repo.insert!(%Permission{
    name: perm.name,
    description: perm.description
  })
end)

# Create a lookup map for permissions by name
perm_map = Enum.reduce(inserted_permissions, %{}, fn p, acc ->
  Map.put(acc, p.name, p)
end)

# Create roles with their permissions
roles = [
  %{
    name: "owner",
    description: "Channel owner with full permissions",
    permissions: [
      "view_channel", "manage_channel", "delete_channel",
      "create_room", "manage_room", "delete_room",
      "send_messages", "delete_messages",
      "manage_members", "assign_roles"
    ]
  },
  %{
    name: "admin",
    description: "Administrator with almost full permissions",
    permissions: [
      "view_channel", "manage_channel",
      "create_room", "manage_room", "delete_room",
      "send_messages", "delete_messages",
      "manage_members"
    ]
  },
  %{
    name: "moderator",
    description: "Can moderate content and members",
    permissions: [
      "view_channel",
      "create_room", "manage_room",
      "send_messages", "delete_messages",
      "manage_members"
    ]
  },
  %{
    name: "member",
    description: "Regular member with basic permissions",
    permissions: [
      "view_channel",
      "send_messages"
    ]
  },
  %{
    name: "read_only",
    description: "Can only view content, cannot post",
    permissions: [
      "view_channel"
    ]
  }
]

# Insert roles with their permissions
Enum.each(roles, fn role_data ->
  role = Repo.insert!(%Role{
    name: role_data.name,
    description: role_data.description
  })

  # Associate permissions with the role
  Enum.each(role_data.permissions, fn perm_name ->
    perm = perm_map[perm_name]
    Repo.insert_all("role_permissions", [
      %{role_id: role.id, permission_id: perm.id}
    ])
  end)
end)

# Create test users if they don't exist
{:ok, host} =
  case Frestyl.Accounts.get_user_by_email("host@example.com") do
    nil -> Frestyl.Accounts.register_user(%{
      email: "host@example.com",
      password: "password123",
      username: "eventhoster"
    })
    user -> {:ok, user}
  end

{:ok, attendee} =
  case Frestyl.Accounts.get_user_by_email("attendee@example.com") do
    nil -> Frestyl.Accounts.register_user(%{
      email: "attendee@example.com",
      password: "password123",
      username: "eventattendee"
    })
    user -> {:ok, user}
  end

  # Create test user with Creator tier
{:ok, user} = Frestyl.Accounts.create_user(%{
  email: "test@example.com",
  # ... other user fields
})

{:ok, account} = Frestyl.Accounts.create_account(user, %{
  subscription_tier: :creator,  # This gives access to Creator Lab
  name: "Test Account"
})

# Create sample events
now = DateTime.utc_now()
tomorrow = DateTime.add(now, 60 * 60 * 24, :second)
next_week = DateTime.add(now, 60 * 60 * 24 * 7, :second)

# Open event
{:ok, open_event} = Frestyl.Events.create_event(%{
  title: "Open Jam Session",
  description: "Join our open jam session. Everyone is welcome!",
  starts_at: tomorrow,
  status: :scheduled,
  admission_type: :open
}, host)

# Invite-only event
{:ok, invite_event} = Frestyl.Events.create_event(%{
  title: "Private Listening Party",
  description: "An exclusive listening party for our new album.",
  starts_at: next_week,
  status: :scheduled,
  admission_type: :invite_only
}, host)

# Paid event
{:ok, paid_event} = Frestyl.Events.create_event(%{
  title: "Masterclass: Mixing Techniques",
  description: "Learn professional mixing techniques from industry experts.",
  starts_at: DateTime.add(tomorrow, 60 * 60 * 2, :second),
  status: :scheduled,
  admission_type: :paid,
  price_in_cents: 1999
}, host)

# Lottery event
{:ok, lottery_event} = Frestyl.Events.create_event(%{
  title: "Surprise Concert with Special Guest",
  description: "A limited capacity event with a surprise special guest.",
  starts_at: DateTime.add(next_week, 60 * 60 * 24, :second),
  status: :scheduled,
  admission_type: :lottery,
  max_attendees: 10
}, host)

# Register sample attendee for the open event
Frestyl.Events.register_for_event(open_event, attendee)

IO.puts "Roles and permissions seeded successfully!"
