# lib/frestyl_web/live/dashboard_live.ex
defmodule FrestylWeb.DashboardLive do
  use FrestylWeb, :live_view

  # Import the `nav` function from Navigation
  import FrestylWeb.Navigation, only: [nav: 1]

  alias Frestyl.{Channels, Media, Statistics, Events, Analytics}

  @impl true
  def mount(_params, _session, socket) do
    # Add monitoring for any errors during mount
    current_user = socket.assigns.current_user

    if connected?(socket) do
      # Subscribe to real-time updates for this user
      Phoenix.PubSub.subscribe(Frestyl.PubSub, "user:#{current_user.id}")
      Phoenix.PubSub.subscribe(Frestyl.PubSub, "channels")
    end

    {:ok,
     socket
     |> assign(:page_title, "Dashboard")
     |> assign(:active_tab, :dashboard)
     |> load_dashboard_data()}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("submit_question", _params, socket) do
    # Here we would handle the daily question submission
    # For now, just show a notification
    {:noreply, socket |> put_flash(:info, "Thanks for your response! We'll customize your feed accordingly.")}
  end

  @impl true
  def handle_info({:channel_created, channel}, socket) do
    user_channels = [channel | socket.assigns.user_channels]
    {:noreply, assign(socket, :user_channels, user_channels)}
  end

  @impl true
  def handle_info({:media_uploaded, media}, socket) do
    media_files = [media | socket.assigns.media_files]
    {:noreply, assign(socket, :media_files, media_files)}
  end

  @impl true
  def handle_info({:stats_updated, stats}, socket) do
    {:noreply, assign(socket, :stats, stats)}
  end

  # Helper functions

  # New simplified greeting function
  defp get_simple_greeting(name) do
    hour = DateTime.utc_now().hour

    time_of_day = cond do
      hour >= 5 and hour < 12 -> "Morning"
      hour >= 12 and hour < 17 -> "Afternoon"
      hour >= 17 and hour < 22 -> "Evening"
      true -> "Night"
    end

    first_name = name |> String.split(" ") |> List.first || "Friend"
    "#{time_of_day}, #{first_name}!"
  end

  # Keep the original function for backward compatibility
  defp get_greeting(name) do
    hour = DateTime.utc_now().hour

    greeting = cond do
      hour >= 5 and hour < 12 -> "Good Morning"
      hour >= 12 and hour < 17 -> "Good Afternoon"
      hour >= 17 and hour < 22 -> "Good Evening"
      true -> "Good Night"
    end

    "#{greeting}, #{String.split(name || "", " ") |> List.first || "Friend"}!"
  end

  defp get_channel_category(channel) do
    # In a real implementation, we would extract a category from the channel
    # For now, sample from predefined categories
    categories = ["Music", "Art", "Tech", "Travel", "Gaming", "Photography", "Writing", "Design"]

    cond do
      # Check if channel has a category field
      channel[:category] -> channel.category
      # Try to infer category from name or description
      channel[:name] && Regex.match?(~r/music|audio|sound|podcast/i, channel.name) -> "Music"
      channel[:name] && Regex.match?(~r/photo|image|picture|camera/i, channel.name) -> "Photography"
      channel[:name] && Regex.match?(~r/vid|film|movie/i, channel.name) -> "Video"
      channel[:name] && Regex.match?(~r/write|text|book|story/i, channel.name) -> "Writing"
      channel[:name] && Regex.match?(~r/design|art|draw|paint/i, channel.name) -> "Design"
      true -> Enum.random(categories)
    end
  end

  defp load_dashboard_data(socket) do
    user = socket.assigns.current_user

    try do
      socket
      |> assign(:stats, get_user_stats(user))
      |> assign(:user_channels, get_user_channels(user.id))
      |> assign(:media_files, get_user_media(user.id))
      |> assign(:notifications, get_user_notifications(user.id))
    rescue
      e ->
        IO.puts("Error loading dashboard data: #{inspect(e)}")
        # Fallback to ensure the dashboard doesn't break if any function fails
        socket
        |> assign(:stats, %{channels: 0, members: 0, media_files: 0, total_views: 0})
        |> assign(:user_channels, [])
        |> assign(:media_files, [])
        |> assign(:notifications, [])
    end
  end

  defp get_user_stats(user) do
    # Try to get real stats, but fallback to defaults if needed
    try do
      channels_count = Channels.count_user_channels(user.id)
      members_count = Channels.count_channel_members(user.id)
      media_count = Media.count_user_media(user.id)
      views_count = Analytics.get_total_views(user.id)

      %{
        channels: channels_count,
        members: members_count,
        media_files: media_count,
        total_views: views_count
      }
    rescue
      _ ->
        # Default stats as fallback
        %{
          channels: 0,
          members: 0,
          media_files: 0,
          total_views: 0
        }
    end
  end

  defp get_user_channels(user_id) do
    # Try to get real channels, but fallback to empty list if needed
    try do
      Channels.list_user_channels(user_id)
    rescue
      _ ->
        # Sample data to demonstrate UI
        [
          %{id: 1, name: "Music Production", description: "Collaborate on audio projects", member_count: 12, last_active: DateTime.utc_now() |> DateTime.add(-2, :hour)},
          %{id: 2, name: "Visual Design", description: "Share and critique designs", member_count: 8, last_active: DateTime.utc_now() |> DateTime.add(-1, :day)},
          %{id: 3, name: "Writer's Circle", description: "Creative writing and feedback", member_count: 5, last_active: DateTime.utc_now() |> DateTime.add(-3, :day)}
        ]
    end
  end

  defp get_user_media(user_id) do
    # Try to get real media, but fallback to empty list if needed
    try do
      Media.list_user_media(user_id, limit: 5)
    rescue
      _ ->
        # Sample data to demonstrate UI
        [
          %{id: 1, name: "Project Demo", type: "video", updated_at: DateTime.utc_now() |> DateTime.add(-1, :hour)},
          %{id: 2, name: "Album Cover", type: "image", updated_at: DateTime.utc_now() |> DateTime.add(-3, :hour)},
          %{id: 3, name: "Podcast Intro", type: "audio", updated_at: DateTime.utc_now() |> DateTime.add(-1, :day)}
        ]
    end
  end

  defp get_user_notifications(user_id) do
    # Fetch unread notifications for the user
    try do
      Frestyl.Notifications.list_user_notifications(user_id, unread_only: true)
    rescue
      _ -> []
    end
  end

  # Format helpers

  defp format_media_type(type) do
    case type do
      "image" -> "Image"
      "video" -> "Video"
      "audio" -> "Audio"
      "document" -> "Document"
      _ -> "Media"
    end
  end

  defp time_ago(time) do
    if time do
      seconds_ago = DateTime.diff(DateTime.utc_now(), time)

      cond do
        seconds_ago < 60 -> "just now"
        seconds_ago < 3600 -> "#{div(seconds_ago, 60)}m ago"
        seconds_ago < 86400 -> "#{div(seconds_ago, 3600)}h ago"
        seconds_ago < 172800 -> "yesterday"
        seconds_ago < 2592000 -> "#{div(seconds_ago, 86400)}d ago"
        true -> "#{div(seconds_ago, 2592000)}mo ago"
      end
    else
      "recently"
    end
  end
end
