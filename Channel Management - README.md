# Frestyl Channel Management

This module provides real-time channel management and chat functionality for the Frestyl collaborative media platform.

## Features

- **Channel Management**
  - Create, edit and delete channels
  - Public, private, and invite-only visibility options
  - Member management with role-based permissions (admin, moderator, member)
  - Searchable channel directory

- **Real-time Chat**
  - Instant messaging with real-time updates
  - Typing indicators
  - User presence tracking
  - Message history
  - Auto-scrolling chat interface

- **Member Management**
  - User roles (admin, moderator, member)
  - Online status tracking
  - Member list with role management
  - Invite and remove members

## Installation

1. **Add the migrations to your database**:
   ```bash
   mix ecto.migrate
   ```

2. **Update your app.js to include the hooks**:
   ```javascript
   // assets/js/app.js
   import Hooks from "./hooks"
   
   let liveSocket = new LiveSocket("/live", Socket, {
     params: { _csrf_token: csrfToken },
     hooks: Hooks
   })
   ```

3. **Make sure the PubSub and Presence services are started**:
   Verify that `Frestyl.PubSub` and `Frestyl.Presence` are in your application supervision tree:
   ```elixir
   # lib/frestyl/application.ex
   children = [
     # ...other children
     {Phoenix.PubSub, name: Frestyl.PubSub},
     Frestyl.Presence,
     # ...
   ]
   ```

## Usage

### Channel Management

#### Creating a Channel

```elixir
alias Frestyl.Channels

{:ok, channel} = Channels.create_channel(%{
  name: "General Discussion",
  description: "A place for general discussion",
  visibility: "public"
}, current_user)
```

#### Joining a Channel

```elixir
alias Frestyl.Channels

# Join a channel
{:ok, membership} = Channels.join_channel(user, channel)

# Leave a channel
{:ok, _} = Channels.leave_channel(user, channel)
```

#### Managing Channel Members

```elixir
alias Frestyl.Channels

# List channel members
members = Channels.list_channel_members(channel_id)

# Update member role
{:ok, updated_membership} = Channels.update_member_role(membership, "moderator")
```

### Chat Functionality

#### Sending a Message

```elixir
alias Frestyl.Chat
