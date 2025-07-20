# lib/frestyl_web/live/channel_live/index.ex
defmodule FrestylWeb.ChannelLive.Index do
  use FrestylWeb, :live_view

  on_mount {FrestylWeb.UserAuth, :ensure_authenticated}

  alias Frestyl.{Accounts, Channels, Community}
  alias Frestyl.Channels.Channel
  import FrestylWeb.Navigation, only: [nav: 1]


  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Frestyl.PubSub, "channels")
    end

    # Handle potential errors in fetching channels
    {user_channels, public_channels} = try do
      user_channels = Channels.list_user_channels(current_user.id)
      public_channels = Channels.list_public_channels()
      {user_channels, public_channels}
    rescue
      error ->
        IO.inspect(error, label: "Channel fetch error")
        {[], []}
    end

    socket = socket
      |> assign(:user_channels, user_channels)
      |> assign(:public_channels, public_channels)
      |> assign(:search, "")
      |> assign(:modal_visible, false)
      |> assign(:page_title, "Channels")
      |> assign(:channel, %Channel{})
      |> assign(:channel_recommendations, [])
      |> assign(:user_interests, nil)
      |> assign(:view_mode, "list")  # Add this
      |> assign(:sort_by, "pinned")  # Add this

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Channels")
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Channel")
    |> assign(:modal_title, "Create a New Channel")
    |> assign(:channel, %Channel{})
    |> assign(:modal_visible, true)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    channel = Channels.get_channel!(id)

    socket
    |> assign(:page_title, "Edit #{channel.name}")
    |> assign(:modal_title, "Edit Channel")
    |> assign(:channel, channel)
    |> assign(:modal_visible, true)
  end

  def handle_event("change_view", %{"view" => view}, socket) do
    {:noreply, assign(socket, :view_mode, view)}
  end

  def handle_event("change_sort", %{"sort_by" => sort_by}, socket) do
    {:noreply, assign(socket, :sort_by, sort_by)}
  end

  @impl true
  def handle_event("close_modal", _, socket) do
    {:noreply, push_patch(socket, to: ~p"/channels")}
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    public_channels =
      if search && search != "" do
        Channels.search_public_channels(search)
      else
        Channels.list_public_channels()
      end

    {:noreply, assign(socket, public_channels: public_channels, search: search)}
  end

  @impl true
  def handle_event("join_channel", %{"channel_id" => channel_id}, socket) do
    case Channels.join_channel(channel_id, socket.assigns.current_user.id) do
      {:ok, _membership} ->
        # Refresh the channels list
        user_channels = get_user_channels_with_official(socket.assigns.current_user.id)

        {:noreply,
         socket
         |> assign(:user_channels, user_channels)
         |> put_flash(:info, "Successfully joined channel!")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to join channel")}
    end
  end

  @impl true
  def handle_event("leave_channel", %{"channel_id" => channel_id}, socket) do
    # Prevent leaving Frestyl Official
    if channel_id == get_frestyl_official_channel().id do
      {:noreply, put_flash(socket, :error, "You cannot leave Frestyl Official")}
    else
      case Channels.leave_channel(channel_id, socket.assigns.current_user.id) do
        {:ok, _} ->
          user_channels = get_user_channels_with_official(socket.assigns.current_user.id)

          {:noreply,
           socket
           |> assign(:user_channels, user_channels)
           |> put_flash(:info, "Left channel successfully")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to leave channel")}
      end
    end
  end

  @impl true
  def handle_info({:channel_created, channel}, socket) do
    public_channels =
      if channel.visibility == "public" do
        [channel | socket.assigns.public_channels]
      else
        socket.assigns.public_channels
      end

    user_channels = Channels.list_user_channels(socket.assigns.current_user.id)

    {:noreply, assign(socket, public_channels: public_channels, user_channels: user_channels)}
  end

  @impl true
  def handle_info({:channel_updated, channel}, socket) do
    # Update the user channels list if needed
    user_channels = Channels.list_user_channels(socket.assigns.current_user.id)

    # Update the public channels list if needed
    public_channels =
      if channel.visibility == "public" do
        # Update the channel in the public list
        Enum.map(socket.assigns.public_channels, fn c ->
          if c.id == channel.id, do: channel, else: c
        end)
      else
        # Remove the channel from the public list if it's no longer public
        Enum.reject(socket.assigns.public_channels, fn c -> c.id == channel.id end)
      end

    {:noreply, assign(socket, public_channels: public_channels, user_channels: user_channels)}
  end

  @impl true
  def handle_info({:channel_deleted, channel}, socket) do
    # Remove the channel from both lists
    public_channels = Enum.reject(socket.assigns.public_channels, fn c -> c.id == channel.id end)
    user_channels = Enum.reject(socket.assigns.user_channels, fn c -> c.id == channel.id end)

    {:noreply, assign(socket, public_channels: public_channels, user_channels: user_channels)}
  end

  defp sort_channels(channels, sort_by) do
    case sort_by do
      "pinned" ->
        # Frestyl Official first, then others
        {official, regular} = Enum.split_with(channels, fn {channel, _} ->
          is_official_channel?(channel)
        end)
        official ++ Enum.sort_by(regular, fn {channel, _} -> channel.name end)

      "name" ->
        Enum.sort_by(channels, fn {channel, _} -> channel.name end)

      "members" ->
        Enum.sort_by(channels, fn {_, member_count} -> member_count end, :desc)

      "activity" ->
        Enum.sort_by(channels, fn {channel, _} ->
          case channel.updated_at do
            %NaiveDateTime{} = naive_dt ->
              DateTime.from_naive!(naive_dt, "Etc/UTC")
            %DateTime{} = dt ->
              dt
            _ ->
              ~U[2000-01-01 00:00:00Z]
          end
        end, {:desc, DateTime})

      "recent" ->
        Enum.sort_by(channels, fn {channel, _} ->
          case channel.updated_at do
            %NaiveDateTime{} = naive_dt ->
              DateTime.from_naive!(naive_dt, "Etc/UTC")
            %DateTime{} = dt ->
              dt
            _ ->
              ~U[2000-01-01 00:00:00Z]
          end
        end, {:desc, DateTime})

      "joined" ->
        # Sort by when user joined (would need to add this data)
        # For now, sort by channel creation date
        Enum.sort_by(channels, fn {channel, _} ->
          case channel.inserted_at do
            %NaiveDateTime{} = naive_dt ->
              DateTime.from_naive!(naive_dt, "Etc/UTC")
            %DateTime{} = dt ->
              dt
            _ ->
              ~U[2000-01-01 00:00:00Z]
          end
        end, {:desc, DateTime})

      _ ->
        channels
    end
  end

  # Update these helper functions to be more neutral

defp get_channel_header_style(channel) do
  if is_official_channel?(channel) do
    # Special treatment for official channels
    "bg-gradient-to-br from-blue-50 to-indigo-50"
  else
    # Future: channel.color_scheme || channel.customization.header_color
    case rem(channel.id, 6) do
      0 -> "bg-gradient-to-br from-gray-50 to-slate-50"
      1 -> "bg-gradient-to-br from-blue-50 to-cyan-50"
      2 -> "bg-gradient-to-br from-pink-50 to-purple-50"
      3 -> "bg-gradient-to-br from-green-50 to-emerald-50"
      4 -> "bg-gradient-to-br from-purple-50 to-violet-50"
      5 -> "bg-gradient-to-br from-orange-50 to-amber-50"
    end
  end
end

defp get_channel_icon_style(channel) do
  if is_official_channel?(channel) do
    "bg-gradient-to-br from-blue-600 to-indigo-600"
  else
    # Future: channel.color_scheme || channel.customization.primary_color
    case rem(channel.id, 6) do
      0 -> "bg-gradient-to-br from-gray-600 to-slate-700"
      1 -> "bg-gradient-to-br from-blue-600 to-cyan-700"
      2 -> "bg-gradient-to-br from-pink-600 to-purple-700"
      3 -> "bg-gradient-to-br from-green-600 to-emerald-700"
      4 -> "bg-gradient-to-br from-purple-600 to-violet-700"
      5 -> "bg-gradient-to-br from-orange-600 to-amber-700"
    end
  end
end

# Remove the old gradient and card style functions since we're using a cleaner approach
# defp get_channel_gradient(channel) - REMOVE THIS
# defp get_channel_card_style(channel) - REMOVE THIS

  # Color variation helpers inspired by dashboard
  defp get_channel_gradient(channel) do
    if is_official_channel?(channel) do
      "bg-gradient-to-br from-indigo-500 via-purple-600 to-pink-600"
    else
      case rem(channel.id, 8) do
        0 -> "bg-gradient-to-br from-blue-500 to-cyan-600"
        1 -> "bg-gradient-to-br from-purple-500 to-indigo-600"
        2 -> "bg-gradient-to-br from-pink-600 to-purple-700"
        3 -> "bg-gradient-to-br from-green-500 to-emerald-600"
        4 -> "bg-gradient-to-br from-orange-500 to-red-600"
        5 -> "bg-gradient-to-br from-teal-500 to-cyan-600"
        6 -> "bg-gradient-to-br from-violet-500 to-purple-600"
        7 -> "bg-gradient-to-br from-amber-500 to-orange-600"
      end
    end
  end

  defp get_channel_icon_style(channel) do
    if is_official_channel?(channel) do
      "bg-gradient-to-br from-indigo-600 to-purple-600 shadow-lg relative"
    else
      case rem(channel.id, 8) do
        0 -> "bg-gradient-to-br from-blue-600 to-cyan-700"
        1 -> "bg-gradient-to-br from-purple-600 to-indigo-700"
        2 -> "bg-gradient-to-br from-pink-600 to-purple-700"
        3 -> "bg-gradient-to-br from-green-600 to-emerald-700"
        4 -> "bg-gradient-to-br from-orange-600 to-red-700"
        5 -> "bg-gradient-to-br from-teal-600 to-cyan-700"
        6 -> "bg-gradient-to-br from-violet-600 to-purple-700"
        7 -> "bg-gradient-to-br from-amber-600 to-orange-700"
      end
    end
  end

  defp get_channel_card_style(channel) do
    if is_official_channel?(channel) do
      "ring-2 ring-indigo-200 hover:ring-indigo-300"
    else
      case rem(channel.id, 4) do
        0 -> "hover:shadow-blue-100"
        1 -> "hover:shadow-purple-100"
        2 -> "hover:shadow-pink-100"
        3 -> "hover:shadow-green-100"
      end
    end
  end

  # Keep all existing helper functions
  defp is_official_channel?(channel) when is_map(channel) do
    Map.get(channel.metadata || %{}, "is_official") == true
  end

  defp is_official_channel?(_), do: false

  defp get_channel_unread_count(_channel) do
    # For now, return 0 - implement this later when you have message tracking
    0
  end

  defp get_channel_activity_status(channel) when is_map(channel) do
    # Convert NaiveDateTime to DateTime if needed
    updated_at = case channel.updated_at do
      %NaiveDateTime{} = naive_dt ->
        DateTime.from_naive!(naive_dt, "Etc/UTC")
      %DateTime{} = dt ->
        dt
      _ ->
        DateTime.utc_now()
    end

    case DateTime.diff(DateTime.utc_now(), updated_at, :day) do
      days when days < 1 -> "Active"
      days when days < 7 -> "Recent"
      _ -> "Quiet"
    end
  end

  defp get_channel_activity_status(_), do: "Unknown"

  defp format_time_ago(datetime) when is_nil(datetime), do: "Never"
  defp format_time_ago(%DateTime{} = datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      diff < 2592000 -> "#{div(diff, 86400)}d ago"
      true -> "#{div(diff, 2592000)}mo ago"
    end
  end

  defp format_time_ago(%NaiveDateTime{} = naive_datetime) do
    datetime = DateTime.from_naive!(naive_datetime, "Etc/UTC")
    format_time_ago(datetime)
  end

  defp format_time_ago(_), do: "Unknown"

  defp count_active_channels(user_channels) do
    Enum.count(user_channels, fn
      {channel, _member_count} when is_map(channel) ->
        channel.show_live_activity == true
      _ ->
        false
    end)
  end

  defp total_unread_count(_user_channels) do
    # For now, return 0 - implement this later
    0
  end

  defp get_user_channels_with_official(user_id) do
    # Get user's regular channels
    regular_channels = Channels.list_user_channels(user_id)

    # Get Frestyl Official channel
    official_channel = get_frestyl_official_channel()

    # Ensure user is member of Frestyl Official
    Channels.ensure_user_in_frestyl_official(user_id)

    # Combine and sort with Frestyl Official first
    all_channels = [official_channel | regular_channels]
  end

  defp get_frestyl_official_channel do
    case Channels.get_channel_by_slug("frestyl-official") do
      nil ->
        {:ok, channel} = create_frestyl_official_if_missing()
        channel
      channel -> channel
    end
  end

  defp get_channel_activity_status(channel) when is_map(channel) do
    # Convert NaiveDateTime to DateTime if needed
    updated_at = case channel.updated_at do
      %NaiveDateTime{} = naive_dt ->
        DateTime.from_naive!(naive_dt, "Etc/UTC")
      %DateTime{} = dt ->
        dt
      _ ->
        DateTime.utc_now()
    end

    case DateTime.diff(DateTime.utc_now(), updated_at, :day) do
      days when days < 1 -> "Active"
      days when days < 7 -> "Recent"
      _ -> "Quiet"
    end
  end
  defp get_channel_activity_status(_), do: "Unknown"

  defp format_time_ago(datetime) when is_nil(datetime), do: "Never"
  defp format_time_ago(%DateTime{} = datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      diff < 2592000 -> "#{div(diff, 86400)}d ago"
      true -> "#{div(diff, 2592000)}mo ago"
    end
  end
  defp format_time_ago(%NaiveDateTime{} = naive_datetime) do
    datetime = DateTime.from_naive!(naive_datetime, "Etc/UTC")
    format_time_ago(datetime)
  end
  defp format_time_ago(_), do: "Unknown"

  # Add all the other helper functions
  defp is_official_channel?(channel) when is_map(channel) do
    Map.get(channel.metadata || %{}, "is_official") == true
  end
  defp is_official_channel?(_), do: false

  defp get_channel_unread_count(_channel) do
    # For now, return 0 - implement this later when you have message tracking
    0
  end

  defp count_active_channels(user_channels) do
    Enum.count(user_channels, fn
      {channel, _member_count} when is_map(channel) ->
        channel.show_live_activity == true
      _ ->
        false
    end)
  end

  defp total_unread_count(_user_channels) do
    # For now, return 0 - implement this later
    0
  end

  defp create_frestyl_official_if_missing do
    attrs = %{
      name: "Frestyl Official",
      slug: "frestyl-official",
      description: "Platform news, community highlights, and discovery hub",
      channel_type: "general",
      visibility: "public",
      metadata: %{
        "is_official" => true,
        "auto_join" => true,
        "discovery_enabled" => true,
        "pinned_position" => 1,
        "special_features" => ["discovery_feed", "platform_news", "community_highlights"]
      }
    }

    admin_user = Frestyl.Accounts.get_user!(get_system_user_id())
    Channels.create_channel(attrs, admin_user)
  end


  defp get_user_unread_count(channel_id) do
    # Mock implementation - replace with real unread message counting
    if channel_id == get_frestyl_official_channel().id do
      3 # Frestyl Official often has updates
    else
      Enum.random(0..5)
    end
  end

  defp get_last_activity_time(channel_id) do
    # Mock implementation - replace with real activity tracking
    DateTime.add(DateTime.utc_now(), -Enum.random(1..7200), :second)
  end

  defp get_channel_member_count(channel_id) do
    try do
      Channels.get_member_count(channel_id)
    rescue
      _ -> "1.2k" # fallback
    end
  end

  defp get_channel_recommendations(user_id) do
    user_interests = Community.get_user_interests(user_id)

    if user_interests do
      # Get personalized recommendations based on interests
      user_interests.genres
      |> Enum.flat_map(&Channels.find_popular_channels_by_genre(&1, limit: 2))
      |> Enum.uniq_by(& &1.id)
      |> Enum.take(6)
    else
      # Get general popular channels
      Channels.get_popular_channels(limit: 6)
    end
  end

  defp get_system_user_id do
    101  # Your admin user ID
  end

  defp get_system_user_id do
    101  # Replace with your actual admin user ID
  end

end
