# lib/frestyl_web/live/channel_live/show.ex
defmodule FrestylWeb.ChannelLive.Show do
  use FrestylWeb, :live_view

  alias Frestyl.Channels
  alias Frestyl.Channels.Channel
  alias Frestyl.Chat
  alias Frestyl.Accounts
  alias Frestyl.Media
  alias Frestyl.Sessions
  alias Frestyl.Timezone
  import FrestylWeb.Navigation, only: [nav: 1]

  # Helper functions
  def can_edit_channel?(user_role) when is_atom(user_role) do
    user_role in [:owner, :admin, :moderator]
  end

  def can_edit_channel?(user_role) when is_binary(user_role) do
    user_role in ["owner", "admin", "moderator"]
  end

  def can_edit_channel?(_), do: false

  def can_create_broadcast?(user_role) when is_atom(user_role) do
    user_role in [:owner, :admin, :moderator, :content_creator]
  end

  def can_create_broadcast?(user_role) when is_binary(user_role) do
    user_role in ["owner", "admin", "moderator", "content_creator"]
  end

  def can_create_broadcast?(_), do: false

  def can_create_session?(user_role) when is_atom(user_role) do
    user_role in [:owner, :admin, :moderator, :content_creator]
  end

  def can_create_session?(user_role) when is_binary(user_role) do
    user_role in ["owner", "admin", "moderator", "content_creator"]
  end

  def can_create_session?(_), do: false

  def error_message(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {k, v} -> "#{k}: #{Enum.join(v, ", ")}" end)
    |> Enum.join("; ")
  end

  # Compact date format (e.g., "5.11.25")
  def compact_date(nil), do: ""
  def compact_date(datetime) do
    Calendar.strftime(datetime, "%-d.%-m.%y")
  end

  def compact_date(nil, _timezone), do: ""
  def compact_date(datetime, user_timezone) do
    local_datetime = Timezone.to_user_timezone(datetime, user_timezone || "UTC")
    Calendar.strftime(local_datetime, "%-d.%-m.%y")
  end

  def time_until(nil, _timezone), do: ""
  def time_until(datetime, user_timezone) do
    Timezone.time_until_with_timezone(datetime, user_timezone || "UTC")
  end

  # Helper function for proper pluralization
  defp pluralize(word, 1), do: word
  defp pluralize(word, _), do: word <> "s"

  def format_channel_datetime(nil), do: "Not scheduled"
  def format_channel_datetime(datetime) do
    Calendar.strftime(datetime, "%B %d, %Y at %I:%M %p")
  end

  def time_ago(nil), do: ""
  def time_ago(datetime) do
    Frestyl.Timezone.time_ago(datetime)
  end

  # Format date and time
  def format_date_time(nil), do: ""
  def format_date_time(datetime) do
    datetime
    |> Calendar.strftime("%b %d, %I:%M %p")
  end

  def format_date_time(nil, _timezone), do: ""
  def format_date_time(datetime, user_timezone) do
    Frestyl.Timezone.compact_format_with_timezone(datetime, user_timezone)
  end

  # Format date only
  def format_date(nil), do: ""
  def format_date(datetime) do
    datetime
    |> Calendar.strftime("%b %d, %Y")
  end

  # Format time only
  def format_time(nil), do: ""
  def format_time(datetime) do
    datetime
    |> Calendar.strftime("%I:%M %p")
  end

  # Format date with day of week (e.g., "Mon, 5.11.25")
  def format_date_with_day(nil, _timezone), do: ""
  def format_date_with_day(datetime, user_timezone) do
    local_datetime = Timezone.to_user_timezone(datetime, user_timezone || "UTC")
    Calendar.strftime(local_datetime, "%a, %-d.%-m.%y")
  end

  def get_user_name(user_id, users_map) do
    case Map.get(users_map, user_id) do
      %{name: name} when not is_nil(name) -> name
      %{email: email} when not is_nil(email) -> email
      user when is_struct(user) ->
        # Handle User struct
        user.name || user.email || user.username || "Unknown User"
      %{} = user_map ->
        # Handle map
        user_map[:name] || user_map[:email] || user_map[:username] || "Unknown User"
      _ ->
        "Unknown User"
    end
  end

  # Check if there are active sessions
  def has_active_sessions?(sessions) do
    Enum.any?(sessions, fn session -> session.status == "active" end)
  end

  # Check if there are active broadcasts
  def has_active_broadcasts?(broadcasts) do
    Enum.any?(broadcasts, fn broadcast -> broadcast.status == "active" end)
  end

  # Filter active sessions
  def active_sessions(sessions) do
    Enum.filter(sessions, fn session -> session.status == "active" end)
  end

  # Filter active broadcasts
  def active_broadcasts(broadcasts) do
    Enum.filter(broadcasts, fn broadcast -> broadcast.status == "active" end)
  end

  # Get upcoming/scheduled sessions
  def upcoming_sessions(sessions) do
    Enum.filter(sessions, fn session ->
      session.status == "scheduled" ||
      (session.status == "active" && session.participants_count == 0)
    end)
  end

  def calendar_string(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y")
  end

  def get_user_email(user) do
    case user do
      %{email: email} -> email
      _ -> nil
    end
  end

  def safe_get_field(struct, field, default \\ nil) do
    Map.get(struct, field, default)
  end

  # Helper function to get member role from channel
  defp get_member_role(channel, user) do
    case Channels.get_channel_membership(user, channel) do
      %{role: role} -> role
      _ -> "guest"
    end
  end

  defp list_channel_sessions(channel_id) do
    Sessions.list_active_sessions_for_channel(channel_id)
  end

  defp list_channel_broadcasts(channel_id) do
    Sessions.list_upcoming_broadcasts_for_channel(channel_id)
  end

  # Helper function to get channel members
  defp get_channel_members(channel) do
    Channels.list_channel_members(channel.id)
  end

  @impl true
  def mount(params, session, socket) do
    # Get current user from session
    current_user = session["user_token"] && Accounts.get_user_by_session_token(session["user_token"])

    # Get channel by id or slug
    channel_identifier = params["slug"] || params["id"]

    if is_nil(channel_identifier) do
      socket =
        socket
        |> put_flash(:error, "Channel not found")
        |> redirect(to: ~p"/dashboard")

      {:ok, socket}
    else
      # Try to get channel by slug first, then by id if that fails
      channel = get_channel_by_identifier(channel_identifier, params)

      case channel do
        nil ->
          socket =
            socket
            |> put_flash(:error, "Channel not found")
            |> redirect(to: ~p"/dashboard")

          {:ok, socket}

        channel ->
          # Check permissions and restrictions
          {restricted, is_member, is_admin, user_role} = check_user_permissions(channel, current_user)

          # Set initial tabs
          active_tab = "activity"  # Default tab
          activity_tab = "happening_now"  # Default activity tab

          socket = if !restricted do
            load_channel_data(socket, channel, current_user, user_role)
          else
            assign_restricted_defaults(socket)
          end

          # Common assigns for all users
          socket = socket
            |> assign(:current_user, current_user)
            |> assign(:channel, channel)
            |> assign(:restricted, restricted)
            |> assign(:is_member, is_member)
            |> assign(:is_admin, is_admin)
            |> assign(:user_role, user_role)
            |> assign(:can_edit, can_edit_channel?(user_role))
            |> assign(:can_view_branding, can_edit_channel?(user_role))
            |> assign(:show_invite_button, can_edit_channel?(user_role))
            |> assign(:can_customize, can_edit_channel?(user_role))
            |> assign(:active_tab, active_tab)
            |> assign(:activity_tab, activity_tab)
            |> assign(:show_block_modal, false)
            |> assign(:show_invite_modal, false)
            |> assign(:show_media_upload, false)
            |> assign(:show_options_panel, false)
            |> assign(:show_customization_panel, false)
            |> assign(:mobile_nav_active, false)
            |> assign(:mobile_chat_active, false)
            |> assign(:show_mobile_create_menu, false)
            |> assign(:viewing_media, nil)
            |> assign(:user_to_block, nil)
            |> assign(:blocking_member, false)
            |> setup_uploads()

          # If this is a connected mount, subscribe to the channel topic
          if connected?(socket) && !restricted do
            Channels.subscribe(channel.id)
            subscribe_to_live_activity(channel.id)
          end

          {:ok, socket}
      end
    end
  end

  # Enhanced data loading
  defp load_channel_data(socket, channel, current_user, user_role) do
    # Load all necessary data
    members = get_channel_members(channel)
    member_count = length(members)

    # Get blocked users
    blocked_users = if can_edit_channel?(user_role), do: Channels.list_blocked_users(channel.id), else: []
    blocked_emails = if can_edit_channel?(user_role), do: Channels.list_blocked_emails(channel.id), else: []

    # Get active media
    active_media = Channels.get_active_media(channel) || %{}

    # Get media files
    media_files = Media.list_channel_files(channel.id) || []

    # Get chat messages
    chat_messages = list_channel_messages(channel.id, limit: 50) || []

    # Load sessions and broadcasts
    sessions = Sessions.list_active_sessions_for_channel(channel.id)
    broadcasts = Sessions.list_active_sessions_for_channel(channel.id)
      |> Enum.filter(&(!is_nil(&1.broadcast_type)))
    upcoming_broadcasts = Sessions.list_upcoming_broadcasts_for_channel(channel.id)

    # Create users map for easier lookup
    users = get_users_for_messages(chat_messages)
    users_map = create_users_map(users, members)

    # Calculate stats and permissions
    stats = calculate_channel_stats(sessions, broadcasts, media_files, members)
    permissions = calculate_permissions(user_role)

    # Load featured content with proper structure
    featured_content = load_featured_content(channel, media_files)

    socket
    |> assign(:members, members)
    |> assign(:member_count, member_count)
    |> assign(:users_map, users_map)
    |> assign(:blocked_users, blocked_users)
    |> assign(:blocked_emails, blocked_emails)
    |> assign(:chat_messages, chat_messages)
    |> assign(:active_media, active_media)
    |> assign(:media_files, media_files)
    |> assign(:message_text, "")
    |> assign(:sessions, sessions)
    |> assign(:broadcasts, broadcasts)
    |> assign(:upcoming_broadcasts, upcoming_broadcasts)
    |> assign(:show_session_form, false)
    |> assign(:show_broadcast_form, false)
    |> assign(:session_changeset, nil)
    |> assign(:broadcast_changeset, nil)
    |> assign(:viewing_session, nil)
    |> assign(:viewing_broadcast, nil)
    |> assign(:online_members, [])
    |> assign(:upcoming_expanded, false)
    |> assign(:expanded_broadcast_id, nil)
    |> assign(:happening_expanded, false)
    |> assign(:expanded_session_id, nil)
    |> assign(:show_broadcast_edit_form, false)
    |> assign(:editing_broadcast, nil)
    |> assign(:featured_content, featured_content)
    |> assign(stats)
    |> assign(permissions)
  end

  defp load_featured_content(channel, media_files) do
    # Convert featured_content from database to proper format for template
    case channel.featured_content do
      content when is_list(content) and length(content) > 0 ->
        Enum.map(content, fn item ->
          case item do
            %{"type" => "media", "id" => media_id} ->
              case Enum.find(media_files, &(&1.id == media_id)) do
                nil -> nil
                media -> %{type: :media, data: media}
              end
            %{"type" => "session", "id" => session_id} ->
              case Sessions.get_session(session_id) do
                nil -> nil
                session -> %{type: :session, data: session}
              end
            %{"type" => "custom", "title" => title, "description" => desc, "image_url" => url} ->
              %{type: :custom, data: %{title: title, description: desc, image_url: url}}
            _ -> nil
          end
        end)
        |> Enum.reject(&is_nil/1)
      _ -> []
    end
  end

  defp calculate_channel_stats(sessions, broadcasts, media_files, members) do
    active_sessions_count = Enum.count(sessions, &(&1.status == "active"))
    active_broadcasts_count = Enum.count(broadcasts, &(&1.status == "active"))
    live_activities_count = active_sessions_count + active_broadcasts_count
    upcoming_events_count = length(broadcasts)
    online_members_count = length(members) # This would be calculated from presence data

    # Content stats
    audio_files_count = Enum.count(media_files, &(String.contains?(&1.content_type || "", "audio")))
    visual_files_count = Enum.count(media_files, &(String.contains?(&1.content_type || "", ["image", "video"])))
    project_files_count = Enum.count(media_files, &(String.contains?(&1.content_type || "", ["document", "application"])))
    total_creations = length(media_files)

    # Activity stats
    active_today = Enum.count(members, fn member ->
      member.last_activity_at &&
      DateTime.diff(DateTime.utc_now(), member.last_activity_at, :hour) < 24
    end)

    %{
      live_activities_count: live_activities_count,
      active_sessions_count: active_sessions_count,
      active_broadcasts_count: active_broadcasts_count,
      upcoming_events_count: upcoming_events_count,
      online_members_count: online_members_count,
      total_sessions: length(sessions),
      audio_files_count: audio_files_count,
      visual_files_count: visual_files_count,
      project_files_count: project_files_count,
      total_creations: total_creations,
      active_today: active_today
    }
  end

  defp calculate_permissions(user_role) do
    %{
      can_create_session: can_create_session?(user_role),
      can_create_broadcast: can_create_broadcast?(user_role)
    }
  end

  defp get_channel_by_identifier(identifier, params) do
    if params["slug"] do
      Channels.get_channel_by_slug(identifier)
    else
      Channels.get_channel(identifier)
    end
  end

  defp check_user_permissions(channel, current_user) do
    blocked = if current_user, do: Channels.is_blocked?(channel, current_user), else: false
    is_member = if current_user, do: Channels.user_member?(current_user, channel), else: false
    is_admin = if current_user, do: Channels.can_edit_channel?(channel, current_user), else: false
    user_role = if is_member, do: get_member_role(channel, current_user), else: "guest"

    restricted = cond do
      is_member -> false
      is_admin -> false
      blocked -> true
      channel.visibility == "public" -> false
      channel.visibility == "unlisted" -> false
      true -> true
    end

    {restricted, is_member, is_admin, user_role}
  end

  defp assign_restricted_defaults(socket) do
    socket
    |> assign(:member_count, 0)
    |> assign(:live_activities_count, 0)
    |> assign(:active_sessions_count, 0)
    |> assign(:upcoming_events_count, 0)
    |> assign(:online_members_count, 0)
    |> assign(:total_sessions, 0)
    |> assign(:audio_files_count, 0)
    |> assign(:visual_files_count, 0)
    |> assign(:project_files_count, 0)
    |> assign(:total_creations, 0)
    |> assign(:active_today, 0)
    |> assign(:sessions, [])
    |> assign(:broadcasts, [])
    |> assign(:upcoming_broadcasts, [])
    |> assign(:chat_messages, [])
    |> assign(:users_map, %{})
    |> assign(:featured_content, [])
  end

  defp setup_uploads(socket) do
    socket
    |> allow_upload(:media_files,
        accept: ~w(.jpg .jpeg .png .gif .mp4 .mov .avi .pdf .doc .docx),
        max_entries: 5,
        max_file_size: 50_000_000)
  end

  # Real-time activity subscription
  defp subscribe_to_live_activity(channel_id) do
    Phoenix.PubSub.subscribe(Frestyl.PubSub, "channel:#{channel_id}:activity")
  end

  defp create_users_map(users, members) do
    users_map = Enum.reduce(users, %{}, fn user, acc -> Map.put(acc, user.id, user) end)

    Enum.reduce(members, users_map, fn member, acc ->
      Map.put_new(acc, member.user_id, member.user)
    end)
  end

  # NEW: Customization event handlers
  @impl true
  def handle_event("toggle_customization_panel", _, socket) do
    {:noreply, assign(socket, :show_customization_panel, !socket.assigns.show_customization_panel)}
  end

  @impl true
  def handle_event("update_channel_customization", %{"channel" => attrs}, socket) do
    channel = socket.assigns.channel

    case Channels.update_channel_customization(channel, attrs) do
      {:ok, updated_channel} ->
        {:noreply,
         socket
         |> assign(:channel, updated_channel)
         |> put_flash(:info, "Channel customization updated successfully!")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to update customization: #{error_message(changeset)}")}
    end
  end

  @impl true
  def handle_event("toggle_mobile_nav", _, socket) do
    {:noreply, assign(socket, :mobile_nav_active, !socket.assigns.mobile_nav_active)}
  end

  @impl true
  def handle_event("toggle_mobile_chat", _, socket) do
    {:noreply, assign(socket, :mobile_chat_active, !socket.assigns.mobile_chat_active)}
  end

  @impl true
  def handle_event("show_mobile_create_menu", _, socket) do
    {:noreply, assign(socket, :show_mobile_create_menu, true)}
  end

  @impl true
  def handle_event("hide_mobile_create_menu", _, socket) do
    {:noreply, assign(socket, :show_mobile_create_menu, false)}
  end

  @impl true
  def handle_event("hide_mobile_chat", _, socket) do
    {:noreply, assign(socket, :mobile_chat_active, false)}
  end

  @impl true
  def handle_event("update_channel_type", %{"type" => type}, socket) do
    channel = socket.assigns.channel

    case Channels.update_channel(channel, %{channel_type: type, auto_detect_type: false}) do
      {:ok, updated_channel} ->
        {:noreply,
         socket
         |> assign(:channel, updated_channel)
         |> put_flash(:info, "Channel type updated to #{Channel.type_display_name(type)}")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to update channel type: #{error_message(changeset)}")}
    end
  end

  @impl true
  def handle_event("toggle_transparency_mode", _, socket) do
    channel = socket.assigns.channel
    new_value = !Map.get(channel, :enable_transparency_mode, false)

    case Channels.update_channel(channel, %{enable_transparency_mode: new_value}) do
      {:ok, updated_channel} ->
        message = if new_value, do: "Transparency mode enabled", else: "Transparency mode disabled"
        {:noreply,
         socket
         |> assign(:channel, updated_channel)
         |> put_flash(:info, message)}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to update transparency mode: #{error_message(changeset)}")}
    end
  end

  @impl true
  def handle_event("add_featured_content", %{"media_id" => media_id}, socket) do
    channel = socket.assigns.channel
    new_item = %{"type" => "media", "id" => String.to_integer(media_id)}
    updated_content = (Map.get(channel, :featured_content, []) || []) ++ [new_item]

    case Channels.update_channel(channel, %{featured_content: updated_content}) do
      {:ok, updated_channel} ->
        featured_content = load_featured_content(updated_channel, socket.assigns.media_files)

        {:noreply,
         socket
         |> assign(:channel, updated_channel)
         |> assign(:featured_content, featured_content)
         |> put_flash(:info, "Added to featured content")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to add featured content: #{error_message(changeset)}")}
    end
  end

  @impl true
  def handle_event("remove_featured_content", %{"index" => index}, socket) do
    channel = socket.assigns.channel
    index = String.to_integer(index)
    updated_content = List.delete_at(Map.get(channel, :featured_content, []) || [], index)

    case Channels.update_channel(channel, %{featured_content: updated_content}) do
      {:ok, updated_channel} ->
        featured_content = load_featured_content(updated_channel, socket.assigns.media_files)

        {:noreply,
         socket
         |> assign(:channel, updated_channel)
         |> assign(:featured_content, featured_content)
         |> put_flash(:info, "Removed from featured content")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to remove featured content: #{error_message(changeset)}")}
    end
  end

  # ALL YOUR EXISTING EVENT HANDLERS (keeping exactly as they are)

  @impl true
  def handle_event("toggle_upcoming_expanded", _, socket) do
    current_state = Map.get(socket.assigns, :upcoming_expanded, false)
    {:noreply, assign(socket, :upcoming_expanded, !current_state)}
  end

  @impl true
  def handle_event("toggle_broadcast_details", %{"id" => id}, socket) do
    current_id = Map.get(socket.assigns, :expanded_broadcast_id)
    new_id = if current_id == String.to_integer(id), do: nil, else: String.to_integer(id)
    {:noreply, assign(socket, :expanded_broadcast_id, new_id)}
  end

  @impl true
  def handle_event("toggle_happening_expanded", _, socket) do
    current_state = Map.get(socket.assigns, :happening_expanded, false)
    {:noreply, assign(socket, :happening_expanded, !current_state)}
  end

  @impl true
  def handle_event("toggle_session_details", %{"id" => id, "type" => "session"}, socket) do
    current_id = Map.get(socket.assigns, :expanded_session_id)
    new_id = if current_id == String.to_integer(id), do: nil, else: String.to_integer(id)
    {:noreply, assign(socket, :expanded_session_id, new_id)}
  end

  @impl true
  def handle_event("toggle_session_details", %{"id" => id, "type" => "broadcast"}, socket) do
    current_id = Map.get(socket.assigns, :expanded_broadcast_id)
    new_id = if current_id == String.to_integer(id), do: nil, else: String.to_integer(id)
    {:noreply, assign(socket, :expanded_broadcast_id, new_id)}
  end

  @impl true
  def handle_event("edit_session", %{"id" => id}, socket) do
    {:noreply, redirect(socket, to: ~p"/channels/#{socket.assigns.channel.slug}/sessions/#{id}/edit")}
  end

  @impl true
  def handle_event("edit_broadcast", %{"id" => id}, socket) do
    broadcast = Sessions.get_session(id)
    changeset = Sessions.change_session(broadcast, %{})

    {:noreply,
    socket
    |> assign(:editing_broadcast, broadcast)
    |> assign(:broadcast_changeset, changeset)
    |> assign(:show_broadcast_edit_form, true)}
  end

  @impl true
  def handle_event("manage_broadcast", %{"id" => id}, socket) do
    {:noreply, redirect(socket, to: ~p"/channels/#{socket.assigns.channel.slug}/broadcasts/#{id}/manage")}
  end

  @impl true
  def handle_event("register_for_broadcast", %{"id" => id}, socket) do
    broadcast_id = String.to_integer(id)
    current_user = socket.assigns.current_user

    case Sessions.join_session(broadcast_id, current_user.id) do
      {:ok, _} ->
        upcoming_broadcasts = Sessions.list_upcoming_broadcasts_for_channel(socket.assigns.channel.id)

        {:noreply,
        socket
        |> put_flash(:info, "Successfully registered for the broadcast!")
        |> assign(:upcoming_broadcasts, upcoming_broadcasts)}

      {:error, reason} ->
        {:noreply,
        socket
        |> put_flash(:error, "Could not register for broadcast: #{reason}")}
    end
  end

  @impl true
  def handle_event("switch_to_files_view", _params, socket) do
    {:noreply, assign(socket, :active_tab, "files")}
  end

  @impl true
  def handle_event("switch_to_members_view", _params, socket) do
    {:noreply, assign(socket, :active_tab, "members")}
  end

  @impl true
  def handle_event("manage_active_media", _params, socket) do
    {:noreply, assign(socket, :show_media_manager, true)}
  end

  @impl true
  def handle_event("join_session", %{"id" => id}, socket) do
    {:noreply, redirect(socket, to: ~p"/channels/#{socket.assigns.channel.slug}/sessions/#{id}")}
  end

  @impl true
  def handle_event("join_broadcast", %{"id" => id}, socket) do
    {:noreply, redirect(socket, to: ~p"/channels/#{socket.assigns.channel.slug}/broadcasts/#{id}")}
  end

  @impl true
  def handle_event("browse_media_for_category", %{"category" => category}, socket) do
    {:noreply,
    socket
    |> assign(:media_category, category)
    |> assign(:show_media_browser, true)}
  end

  @impl true
  def handle_event("validate_uploads", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("save_uploads", _params, socket) do
    uploaded_files =
      consume_uploaded_entries(socket, :media_files, fn %{path: path}, entry ->
        attrs = %{
          title: entry.client_name,
          original_filename: entry.client_name,
          filename: entry.client_name,
          content_type: entry.client_type,
          channel_id: socket.assigns.channel.id,
          user_id: socket.assigns.current_user.id,
          file_size: entry.client_size
        }

        case Media.create_file(attrs, path) do
          {:ok, media_file} ->
            {:ok, media_file}
          {:error, changeset} ->
            IO.inspect(changeset.errors, label: "Upload error")
            {:postpone, :error}
        end
      end)

    case uploaded_files do
      [] ->
        {:noreply, put_flash(socket, :error, "No files were uploaded")}
      files when is_list(files) ->
        media_files = if function_exported?(Media, :list_channel_uploaded_files, 2) do
          Media.list_channel_uploaded_files(socket.assigns.channel.id, [])
        else
          Map.get(socket.assigns, :media_files, [])
        end

        {:noreply,
        socket
        |> put_flash(:info, "#{length(files)} file(s) uploaded successfully!")
        |> assign(:media_files, media_files)
        |> assign(:show_media_upload, false)}
      _errors ->
        {:noreply, put_flash(socket, :error, "Some files failed to upload")}
    end
  end

  # UI Navigation Event Handlers
  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  @impl true
  def handle_event("switch_activity_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :activity_tab, tab)}
  end

  @impl true
  def handle_event("toggle_options", _, socket) do
    {:noreply, assign(socket, :show_options_panel, !socket.assigns.show_options_panel)}
  end

  @impl true
  def handle_event("show_invite_modal", _, socket) do
    {:noreply, assign(socket, :show_invite_modal, true)}
  end

  @impl true
  def handle_event("hide_invite_modal", _, socket) do
    {:noreply, assign(socket, :show_invite_modal, false)}
  end

  @impl true
  def handle_event("show_block_modal", _, socket) do
    {:noreply, assign(socket, :show_block_modal, true)}
  end

  @impl true
  def handle_event("hide_block_modal", _, socket) do
    {:noreply, assign(socket, :show_block_modal, false)}
  end

  @impl true
  def handle_event("show_media_upload", _, socket) do
    {:noreply, assign(socket, :show_media_upload, true)}
  end

  @impl true
  def handle_event("hide_media_upload", _, socket) do
    {:noreply, assign(socket, :show_media_upload, false)}
  end

  # Channel Membership Event Handlers
  @impl true
  def handle_event("join_channel", _, socket) do
    %{channel: channel, current_user: current_user} = socket.assigns

    case Channels.join_channel(current_user, channel) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "You have joined the channel.")
         |> redirect(to: ~p"/channels/#{channel.slug}")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Could not join channel: #{reason}")
         |> redirect(to: ~p"/channels/#{channel.slug}")}
    end
  end

  @impl true
  def handle_event("leave_channel", _, socket) do
    %{channel: channel, current_user: current_user} = socket.assigns

    case Channels.leave_channel(current_user, channel) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "You have left the channel.")
         |> redirect(to: ~p"/dashboard")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Could not leave channel: #{reason}")
         |> redirect(to: ~p"/channels/#{channel.slug}")}
    end
  end

  @impl true
  def handle_event("request_access", _, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Access request sent. You will be notified when approved.")
     |> redirect(to: ~p"/dashboard")}
  end

  # Broadcast management
  @impl true
  def handle_event("delete_session", %{"id" => id}, socket) do
    session = Sessions.get_session(id)

    if session && session.creator_id == socket.assigns.current_user.id do
      case Sessions.delete_session(session) do
        {:ok, _} ->
          updated_sessions = Enum.reject(socket.assigns.sessions, &(&1.id == String.to_integer(id)))

          {:noreply,
          socket
          |> put_flash(:info, "Session deleted successfully.")
          |> assign(:sessions, updated_sessions)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not delete session")}
      end
    else
      {:noreply, put_flash(socket, :error, "You can only delete your own sessions")}
    end
  end

  @impl true
  def handle_event("delete_broadcast", %{"id" => id}, socket) do
    session = Sessions.get_session(id)

    if session && session.host_id == socket.assigns.current_user.id do
      case Sessions.delete_session(session) do
        {:ok, _} ->
          updated_broadcasts = Enum.reject(socket.assigns.broadcasts, &(&1.id == String.to_integer(id)))
          updated_upcoming = Enum.reject(socket.assigns.upcoming_broadcasts, &(&1.id == String.to_integer(id)))

          {:noreply,
          socket
          |> put_flash(:info, "Broadcast deleted successfully.")
          |> assign(:broadcasts, updated_broadcasts)
          |> assign(:upcoming_broadcasts, updated_upcoming)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not delete broadcast")}
      end
    else
      {:noreply, put_flash(socket, :error, "You can only delete your own broadcasts")}
    end
  end

  # Chat Events
  @impl true
  def handle_event("send_message", %{"message" => content}, socket) do
    %{channel: channel, current_user: current_user} = socket.assigns

    case String.trim(content) do
      "" -> {:noreply, socket}

      message_content ->
        case Frestyl.Repo.insert(%Frestyl.Channels.Message{
          content: message_content,
          message_type: "text",
          user_id: current_user.id,
          room_id: channel.id
        }) do
          {:ok, _message} ->
            chat_messages = list_channel_messages(channel.id, limit: 50)

            {:noreply,
             socket
             |> assign(:message_text, "")
             |> assign(:chat_messages, chat_messages)}

          {:error, changeset} ->
            {:noreply,
             socket
             |> put_flash(:error, "Error sending message: #{error_message(changeset)}")
             |> assign(:message_text, content)}
        end
    end
  end

  @impl true
  def handle_event("delete_message", %{"id" => id}, socket) do
    %{current_user: current_user, is_admin: is_admin} = socket.assigns

    {message_id, _} = Integer.parse(id)
    message = Frestyl.Repo.get(Frestyl.Channels.Message, message_id)

    if message && (message.user_id == current_user.id || is_admin) do
      case Frestyl.Repo.delete(message) do
        {:ok, _} ->
          chat_messages = list_channel_messages(socket.assigns.channel.id, limit: 50)

          {:noreply,
           socket
           |> assign(:chat_messages, chat_messages)}

        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, "Could not delete message")}
      end
    else
      {:noreply, put_flash(socket, :error, "Not authorized to delete this message")}
    end
  end

  @impl true
  def handle_event("typing", _params, socket) do
    {:noreply, socket}
  end

  # Invitation Events
  @impl true
  def handle_event("invite_to_channel", %{"email" => email}, socket) do
    %{channel: channel, current_user: current_user} = socket.assigns

    case Channels.invite_to_channel(current_user.id, channel.id, email) do
      {:ok, _invitation} ->
        {:noreply,
         socket
         |> put_flash(:info, "Invitation sent to #{email}.")
         |> assign(:show_invite_modal, false)}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Could not send invitation: #{reason}")
         |> assign(:show_invite_modal, false)}
    end
  end

  # Member Management Events
  @impl true
  def handle_event("promote_member", %{"user-id" => user_id}, socket) do
    %{channel: channel} = socket.assigns

    membership = Channels.get_channel_membership(%{id: user_id}, channel)

    if membership do
      new_role = case membership.role do
        "member" -> "moderator"
        "moderator" -> "member"
        role -> role
      end

      case Channels.update_member_role(membership, new_role) do
        {:ok, _} ->
          members = get_channel_members(channel)

          {:noreply,
           socket
           |> put_flash(:info, "Member role updated.")
           |> assign(:members, members)}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Could not update member role: #{reason}")}
      end
    else
      {:noreply, put_flash(socket, :error, "Membership not found")}
    end
  end

  @impl true
  def handle_event("remove_member", %{"user-id" => user_id}, socket) do
    %{channel: channel} = socket.assigns

    membership = Channels.get_channel_membership(%{id: user_id}, channel)

    if membership do
      case Frestyl.Repo.delete(membership) do
        {:ok, _} ->
          members = get_channel_members(channel)

          {:noreply,
           socket
           |> put_flash(:info, "Member removed from channel.")
           |> assign(:members, members)}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Could not remove member: #{reason}")}
      end
    else
      {:noreply, put_flash(socket, :error, "Membership not found")}
    end
  end

  # User Blocking Events
  @impl true
  def handle_event("block_member", %{"user-id" => user_id}, socket) do
    %{channel: channel} = socket.assigns

    user = Accounts.get_user(user_id)

    if user do
      {:noreply,
       socket
       |> assign(:show_block_modal, true)
       |> assign(:blocking_member, true)
       |> assign(:user_to_block, user)}
    else
      {:noreply, put_flash(socket, :error, "User not found")}
    end
  end

  @impl true
  def handle_event("block_email", %{"email" => email, "reason" => reason, "duration" => duration}, socket) do
    %{channel: channel, current_user: current_user, blocking_member: blocking_member, user_to_block: user_to_block} = socket.assigns

    block_attrs = %{reason: reason}
    block_attrs = case duration do
      "permanent" -> block_attrs
      "1d" -> Map.put(block_attrs, :expires_at, DateTime.add(DateTime.utc_now(), 1, :day))
      "7d" -> Map.put(block_attrs, :expires_at, DateTime.add(DateTime.utc_now(), 7, :day))
      "30d" -> Map.put(block_attrs, :expires_at, DateTime.add(DateTime.utc_now(), 30, :day))
      "90d" -> Map.put(block_attrs, :expires_at, DateTime.add(DateTime.utc_now(), 90, :day))
      _ -> block_attrs
    end

    block_result = if blocking_member && user_to_block do
      Channels.block_user(channel, user_to_block, current_user, block_attrs)
    else
      Channels.block_email(channel, email, current_user, block_attrs)
    end

    case block_result do
      {:ok, _} ->
        blocked_users = Channels.list_blocked_users(channel.id)
        blocked_emails = Channels.list_blocked_emails(channel.id)

        {:noreply,
         socket
         |> put_flash(:info, "#{if blocking_member, do: user_to_block.email, else: email} has been blocked from the channel.")
         |> assign(:show_block_modal, false)
         |> assign(:blocking_member, false)
         |> assign(:user_to_block, nil)
         |> assign(:blocked_users, blocked_users)
         |> assign(:blocked_emails, blocked_emails)}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Could not block user: #{reason}")
         |> assign(:show_block_modal, false)
         |> assign(:blocking_member, false)
         |> assign(:user_to_block, nil)}
    end
  end

  @impl true
  def handle_event("unblock_user", %{"id" => id}, socket) do
    %{channel: channel} = socket.assigns

    block = Frestyl.Repo.get(Frestyl.Channels.BlockedUser, id)

    if block do
      case Frestyl.Repo.delete(block) do
        {:ok, _} ->
          blocked_users = Channels.list_blocked_users(channel.id)
          blocked_emails = Channels.list_blocked_emails(channel.id)

          {:noreply,
           socket
           |> put_flash(:info, "User has been unblocked.")
           |> assign(:blocked_users, blocked_users)
           |> assign(:blocked_emails, blocked_emails)}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Could not unblock user: #{reason}")}
      end
    else
      {:noreply, put_flash(socket, :error, "Block not found")}
    end
  end

  # Media Management Events
  @impl true
  def handle_event("start_broadcast", _, socket) do
    %{channel: channel} = socket.assigns
    {:noreply, redirect(socket, to: ~p"/channels/#{channel.slug}/broadcast")}
  end

  @impl true
  def handle_event("view_media", %{"id" => id}, socket) do
    {:noreply, assign(socket, :viewing_media, id)}
  end

  @impl true
  def handle_event("clear_active_media", %{"category" => category}, socket) do
    %{channel: channel} = socket.assigns

    category_atom = String.to_existing_atom(category)

    case Channels.clear_active_media(channel, category_atom) do
      {:ok, _} ->
        active_media = Channels.get_active_media(channel) || %{}
        {:noreply, assign(socket, :active_media, active_media)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Could not clear media: #{reason}")}
    end
  end

  @impl true
  def handle_event("schedule_broadcast", %{"broadcast" => broadcast_params}, socket) do
    %{channel: channel, current_user: current_user} = socket.assigns

    complete_params = broadcast_params
      |> Map.put("channel_id", channel.id)
      |> Map.put("host_id", current_user.id)
      |> Map.put("creator_id", current_user.id)
      |> Map.put("session_type", "broadcast")
      |> Map.put("status", "scheduled")

    complete_params = if Map.has_key?(complete_params, "scheduled_for") and
                        complete_params["scheduled_for"] != "" do
      user_timezone = Frestyl.Timezone.get_user_timezone(current_user)

      case NaiveDateTime.from_iso8601(complete_params["scheduled_for"] <> ":00") do
        {:ok, naive_dt} ->
          case Frestyl.Timezone.naive_to_utc(naive_dt, user_timezone) do
            {:ok, utc_datetime} ->
              truncated_datetime = DateTime.truncate(utc_datetime, :second)
              Map.put(complete_params, "scheduled_for", truncated_datetime)
            {:error, _} ->
              Map.delete(complete_params, "scheduled_for")
          end
        {:error, _} ->
          Map.delete(complete_params, "scheduled_for")
      end
    else
      complete_params
    end

    complete_params = complete_params
      |> convert_checkbox("is_public")
      |> convert_checkbox("waiting_room_enabled")

    case Sessions.create_session(complete_params) do
      {:ok, session} ->
        broadcasts = Sessions.list_channel_sessions(channel.id, %{session_type: "broadcast"})
        upcoming_broadcasts = Sessions.list_upcoming_broadcasts_for_channel(channel.id)

        {:noreply,
        socket
        |> assign(:broadcasts, broadcasts)
        |> assign(:upcoming_broadcasts, upcoming_broadcasts)
        |> assign(:show_broadcast_form, false)
        |> put_flash(:info, "Broadcast scheduled successfully!")}

      {:error, changeset} ->
        {:noreply,
        socket
        |> put_flash(:error, "Failed to schedule broadcast: #{error_message(changeset)}")
        |> assign(:broadcast_changeset, changeset)}
    end
  end

  defp convert_checkbox(params, key) do
    case Map.get(params, key) do
      "on" -> Map.put(params, key, true)
      nil -> Map.put(params, key, false)
      value -> Map.put(params, key, value)
    end
  end

  defp convert_broadcast_params(params) do
    params
    |> convert_checkbox("is_public")
    |> convert_checkbox("waiting_room_enabled")
    |> convert_datetime("scheduled_for")
  end

  defp convert_datetime(params, key) do
    case Map.get(params, key) do
      datetime_string when is_binary(datetime_string) ->
        user_timezone = Timezone.get_user_timezone(params["current_user"])

        case NaiveDateTime.from_iso8601(datetime_string <> ":00") do
          {:ok, naive_datetime} ->
            case Timezone.naive_to_utc(naive_datetime, user_timezone) do
              {:ok, utc_datetime} ->
                Map.put(params, key, utc_datetime)
              {:error, _} ->
                params
            end
          _ -> params
        end
      _ -> params
    end
  end

  @impl true
  def handle_event("create_session", %{"session" => session_params}, socket) do
    %{channel: channel, current_user: current_user} = socket.assigns

    converted_params = session_params
      |> Map.put("channel_id", channel.id)
      |> Map.put("creator_id", current_user.id)
      |> convert_session_params()

    case Sessions.create_session(converted_params) do
      {:ok, session} ->
        {:noreply,
        socket
        |> put_flash(:info, "Session created successfully.")
        |> assign(:show_session_form, false)
        |> assign(:sessions, [session | socket.assigns.sessions])}

      {:error, changeset} ->
        {:noreply,
        socket
        |> put_flash(:error, "Error creating session: #{error_message(changeset)}")
        |> assign(:session_changeset, changeset)
        |> assign(:show_session_form, true)}
    end
  end

  defp convert_session_params(params) do
    params
    |> convert_checkbox("is_public")
  end

  @impl true
  def handle_event("show_session_form", _, socket) do
    changeset = Channels.change_session(nil)

    {:noreply,
    socket
    |> assign(:show_session_form, true)
    |> assign(:session_changeset, changeset)}
  end

  @impl true
  def handle_event("show_broadcast_form", _, socket) do
    changeset = Channels.change_broadcast(nil)

    {:noreply,
    socket
    |> assign(:show_broadcast_form, true)
    |> assign(:broadcast_changeset, changeset)}
  end

  @impl true
  def handle_event("hide_session_form", _, socket) do
    {:noreply, assign(socket, :show_session_form, false)}
  end

  @impl true
  def handle_event("hide_broadcast_form", _, socket) do
    {:noreply, assign(socket, :show_broadcast_form, false)}
  end

  @impl true
  def handle_event("view_session", %{"id" => id}, socket) do
    session = Channels.get_session!(id)
    {:noreply, assign(socket, :viewing_session, session)}
  end

  @impl true
  def handle_event("view_broadcast", %{"id" => id}, socket) do
    broadcast = Channels.get_broadcast!(id)
    {:noreply, assign(socket, :viewing_broadcast, broadcast)}
  end

  @impl true
  def handle_event("close_session_view", _, socket) do
    {:noreply, assign(socket, :viewing_session, nil)}
  end

  @impl true
  def handle_event("close_broadcast_view", _, socket) do
    {:noreply, assign(socket, :viewing_broadcast, nil)}
  end

  @impl true
  def handle_event("start_session", %{"id" => id}, socket) do
    session = Channels.get_session!(id)

    case Channels.start_session(session) do
      {:ok, _} ->
        {:noreply,
        socket
        |> put_flash(:info, "Session started successfully.")
        |> redirect(to: ~p"/channels/#{socket.assigns.channel.slug}/sessions/#{id}")}

      {:error, reason} ->
        {:noreply,
        socket
        |> put_flash(:error, "Error starting session: #{reason}")}
    end
  end

  @impl true
  def handle_event("start_broadcast", %{"id" => id}, socket) do
    broadcast = Channels.get_broadcast!(id)

    case Channels.start_broadcast(broadcast) do
      {:ok, _} ->
        {:noreply,
        socket
        |> put_flash(:info, "Broadcast started successfully.")
        |> redirect(to: ~p"/channels/#{socket.assigns.channel.slug}/broadcasts/#{id}")}

      {:error, reason} ->
        {:noreply,
        socket
        |> put_flash(:error, "Error starting broadcast: #{reason}")}
    end
  end

  # Real-time activity handlers
  @impl true
  def handle_info({:live_activity_update, activity}, socket) do
    updated_socket = case activity.type do
      :session_started -> update_live_sessions(socket, activity.data)
      :broadcast_started -> update_live_broadcasts(socket, activity.data)
      :session_ended -> remove_live_session(socket, activity.data)
      :broadcast_ended -> remove_live_broadcast(socket, activity.data)
      _ -> socket
    end

    {:noreply, updated_socket}
  end

  # ALL YOUR EXISTING handle_info FUNCTIONS
  @impl true
  def handle_info({:session_created, session}, socket) do
    %{sessions: sessions} = socket.assigns
    updated_sessions = [session | sessions]
    {:noreply, assign(socket, :sessions, updated_sessions)}
  end

  @impl true
  def handle_info({:session_updated, session}, socket) do
    %{sessions: sessions} = socket.assigns

    updated_sessions = Enum.map(sessions, fn s ->
      if s.id == session.id, do: session, else: s
    end)

    {:noreply, assign(socket, :sessions, updated_sessions)}
  end

  @impl true
  def handle_info({:session_deleted, session_id}, socket) do
    %{sessions: sessions} = socket.assigns
    updated_sessions = Enum.reject(sessions, &(&1.id == session_id))
    {:noreply, assign(socket, :sessions, updated_sessions)}
  end

  @impl true
  def handle_info({:broadcast_created, broadcast}, socket) do
    %{broadcasts: broadcasts, upcoming_broadcasts: upcoming_broadcasts} = socket.assigns

    updated_broadcasts = [broadcast | broadcasts]

    updated_upcoming_broadcasts =
      if broadcast.scheduled_for && DateTime.compare(broadcast.scheduled_for, DateTime.utc_now()) == :gt do
        [broadcast | upcoming_broadcasts]
      else
        upcoming_broadcasts
      end

    {:noreply,
    socket
    |> assign(:broadcasts, updated_broadcasts)
    |> assign(:upcoming_broadcasts, updated_upcoming_broadcasts)}
  end

  @impl true
  def handle_info({:broadcast_updated, broadcast}, socket) do
    %{broadcasts: broadcasts, upcoming_broadcasts: upcoming_broadcasts} = socket.assigns

    updated_broadcasts = Enum.map(broadcasts, fn b ->
      if b.id == broadcast.id, do: broadcast, else: b
    end)

    is_upcoming = broadcast.scheduled_for && DateTime.compare(broadcast.scheduled_for, DateTime.utc_now()) == :gt
    already_in_upcoming = Enum.any?(upcoming_broadcasts, &(&1.id == broadcast.id))

    updated_upcoming_broadcasts = cond do
      is_upcoming && already_in_upcoming ->
        Enum.map(upcoming_broadcasts, fn b ->
          if b.id == broadcast.id, do: broadcast, else: b
        end)

      is_upcoming && !already_in_upcoming ->
        [broadcast | upcoming_broadcasts]

      !is_upcoming && already_in_upcoming ->
        Enum.reject(upcoming_broadcasts, &(&1.id == broadcast.id))

      true ->
        upcoming_broadcasts
    end

    {:noreply,
    socket
    |> assign(:broadcasts, updated_broadcasts)
    |> assign(:upcoming_broadcasts, updated_upcoming_broadcasts)}
  end

  @impl true
  def handle_info({:broadcast_deleted, broadcast_id}, socket) do
    %{broadcasts: broadcasts, upcoming_broadcasts: upcoming_broadcasts} = socket.assigns

    updated_broadcasts = Enum.reject(broadcasts, &(&1.id == broadcast_id))
    updated_upcoming_broadcasts = Enum.reject(upcoming_broadcasts, &(&1.id == broadcast_id))

    {:noreply,
    socket
    |> assign(:broadcasts, updated_broadcasts)
    |> assign(:upcoming_broadcasts, updated_upcoming_broadcasts)}
  end

  @impl true
  def handle_info({:message_created, message}, socket) do
    %{chat_messages: messages, users_map: users_map} = socket.assigns

    users_map = if Map.has_key?(users_map, message.user_id) do
      users_map
    else
      user = Accounts.get_user(message.user_id)
      Map.put(users_map, message.user_id, user)
    end

    updated_messages = [message | messages]

    {:noreply,
     socket
     |> assign(:chat_messages, updated_messages)
     |> assign(:users_map, users_map)}
  end

  @impl true
  def handle_info({:message_deleted, message_id}, socket) do
    updated_messages = Enum.reject(socket.assigns.chat_messages, &(&1.id == message_id))
    {:noreply, assign(socket, :chat_messages, updated_messages)}
  end

  @impl true
  def handle_info({:member_added, member}, socket) do
    %{members: members, users_map: users_map} = socket.assigns

    users_map = if Map.has_key?(users_map, member.user_id) do
      users_map
    else
      Map.put(users_map, member.user_id, member.user)
    end

    updated_members = if Enum.any?(members, &(&1.id == member.id)) do
      members
    else
      [member | members]
    end

    {:noreply,
     socket
     |> assign(:members, updated_members)
     |> assign(:users_map, users_map)}
  end

  @impl true
  def handle_info({:member_removed, member_id}, socket) do
    updated_members = Enum.reject(socket.assigns.members, &(&1.id == member_id))
    {:noreply, assign(socket, :members, updated_members)}
  end

  @impl true
  def handle_info({:media_updated}, socket) do
    media_files = Media.list_channel_files(socket.assigns.channel.id)
    {:noreply, assign(socket, :media_files, media_files)}
  end

  @impl true
  def handle_info({:close_media_viewer}, socket) do
    {:noreply, assign(socket, :viewing_media, nil)}
  end

  @impl true
  def handle_info({:close_media_upload}, socket) do
    {:noreply, assign(socket, :show_media_upload, false)}
  end

  @impl true
  def handle_info({:active_media_updated, category, media}, socket) do
    %{active_media: active_media} = socket.assigns
    updated_active_media = Map.put(active_media, category, media)
    {:noreply, assign(socket, :active_media, updated_active_media)}
  end

  @impl true
  def handle_info({:view_media, id}, socket) do
    {:noreply, assign(socket, :viewing_media, id)}
  end

  @impl true
  def handle_info(_, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  # Helper functions for live activity updates
  defp update_live_sessions(socket, session) do
    sessions = [session | socket.assigns.sessions]
    stats = recalculate_activity_stats(socket.assigns, sessions, socket.assigns.broadcasts)

    socket
    |> assign(:sessions, sessions)
    |> assign(stats)
  end

  defp update_live_broadcasts(socket, broadcast) do
    broadcasts = [broadcast | socket.assigns.broadcasts]
    stats = recalculate_activity_stats(socket.assigns, socket.assigns.sessions, broadcasts)

    socket
    |> assign(:broadcasts, broadcasts)
    |> assign(stats)
  end

  defp remove_live_session(socket, session_id) do
    sessions = Enum.reject(socket.assigns.sessions, &(&1.id == session_id))
    stats = recalculate_activity_stats(socket.assigns, sessions, socket.assigns.broadcasts)

    socket
    |> assign(:sessions, sessions)
    |> assign(stats)
  end

  defp remove_live_broadcast(socket, broadcast_id) do
    broadcasts = Enum.reject(socket.assigns.broadcasts, &(&1.id == broadcast_id))
    stats = recalculate_activity_stats(socket.assigns, socket.assigns.sessions, broadcasts)

    socket
    |> assign(:broadcasts, broadcasts)
    |> assign(stats)
  end

  defp recalculate_activity_stats(assigns, sessions, broadcasts) do
    active_sessions_count = Enum.count(sessions, &(&1.status == "active"))
    active_broadcasts_count = Enum.count(broadcasts, &(&1.status == "active"))
    live_activities_count = active_sessions_count + active_broadcasts_count

    %{
      active_sessions_count: active_sessions_count,
      active_broadcasts_count: active_broadcasts_count,
      live_activities_count: live_activities_count,
      total_sessions: length(sessions)
    }
  end

  # Fixed helper function for chat messages
  defp list_channel_messages(channel_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    import Ecto.Query, warn: false
    alias Frestyl.Channels.Message

    Message
    |> where([m], m.room_id == ^channel_id)
    |> order_by([m], desc: m.inserted_at)
    |> limit(^limit)
    |> Frestyl.Repo.all()
    |> Enum.map(fn message ->
      %{
        id: message.id,
        content: message.content,
        message_type: message.message_type,
        user_id: message.user_id,
        room_id: message.room_id,
        inserted_at: message.inserted_at,
        updated_at: message.updated_at,
        user: Frestyl.Repo.get(Frestyl.Accounts.User, message.user_id)
      }
    end)
  end

  # Helper to get users for messages
  defp get_users_for_messages(messages) do
    user_ids = Enum.map(messages, & &1.user_id)
    Accounts.get_users_by_ids(user_ids)
  end

  # Apply action functions for different routes
  defp apply_action(socket, :show, _params) do
    socket
    |> assign(:page_title, "Channel - #{socket.assigns.channel.name}")
  end

  defp apply_action(socket, :edit, _params) do
    if can_edit_channel?(socket.assigns.user_role) do
      socket
      |> assign(:page_title, "Edit Channel - #{socket.assigns.channel.name}")
    else
      socket
      |> put_flash(:error, "You don't have permission to edit this channel.")
      |> redirect(to: ~p"/channels/#{socket.assigns.channel.slug}")
    end
  end

  defp apply_action(socket, _action, _params) do
    socket
    |> assign(:page_title, "Channel - #{socket.assigns.channel.name}")
  end

  # Helper function for media type detection
  defp get_media_type(ext) do
    case String.downcase(ext) do
      ext when ext in [".jpg", ".jpeg", ".png", ".gif", ".webp"] -> "image"
      ext when ext in [".mp4", ".mov", ".avi", ".mkv", ".webm"] -> "video"
      ext when ext in [".mp3", ".wav", ".ogg", ".m4a", ".flac"] -> "audio"
      ext when ext in [".pdf", ".doc", ".docx", ".txt", ".rtf"] -> "document"
      _ -> "other"
    end
  end

  # Helper function for upload error messages
  defp error_to_string(:too_large), do: "File is too large"
  defp error_to_string(:too_many_files), do: "Too many files selected"
  defp error_to_string(:not_accepted), do: "File type not supported"
  defp error_to_string(error), do: "Upload error: #{inspect(error)}"
end
