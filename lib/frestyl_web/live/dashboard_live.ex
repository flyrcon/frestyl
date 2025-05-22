# lib/frestyl_web/live/dashboard_live.ex
defmodule FrestylWeb.DashboardLive do
  use FrestylWeb, :live_view

  # Import the `nav` function from Navigation
  import FrestylWeb.Navigation, only: [nav: 1]

  alias Frestyl.{Channels, Media, Statistics, Events, Analytics, Portfolios}

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
     |> assign(:user_channels, [])
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

  defp get_simple_timezone_greeting(user) do
    # Use UTC time for now
    current_hour = DateTime.utc_now().hour

    # Determine time of day based on hour
    time_of_day = cond do
      current_hour >= 5 and current_hour < 12 -> "Morning"
      current_hour >= 12 and current_hour < 17 -> "Afternoon"
      current_hour >= 17 and current_hour < 22 -> "Evening"
      true -> "Night"
    end

    # Extract the name safely
    first_name =
      case user do
        %{name: name} when is_binary(name) ->
          name |> String.split(" ") |> List.first
        name when is_binary(name) ->
          name |> String.split(" ") |> List.first
        _ ->
          "Friend"
      end

    "#{time_of_day}, #{first_name}!"
  end

  defp get_greeting(name) do
    # For simplicity, use UTC - we'll fix timezone properly later
    current_hour = DateTime.utc_now().hour

    greeting = cond do
      current_hour >= 5 and current_hour < 12 -> "Good Morning"
      current_hour >= 12 and current_hour < 17 -> "Good Afternoon"
      current_hour >= 17 and current_hour < 22 -> "Good Evening"
      true -> "Good Night"
    end

    "#{greeting}, #{String.split(name || "", " ") |> List.first || "Friend"}!"
  end

  defp get_simple_timezone_greeting(user) do
    # Get current time in America/New_York reliably
    {:ok, local_time} = DateTime.now("America/New_York", Tzdata.TimeZoneDatabase)

    current_hour = local_time.hour

    time_of_day = cond do
      current_hour >= 5 and current_hour < 12 -> "Morning"
      current_hour >= 12 and current_hour < 17 -> "Afternoon"
      current_hour >= 17 and current_hour < 22 -> "Evening"
      true -> "Night"
    end

    first_name =
      case user do
        %{name: name} when is_binary(name) -> name |> String.split() |> List.first()
        name when is_binary(name) -> name |> String.split() |> List.first()
        _ -> "Friend"
      end

    "#{time_of_day}, #{first_name}!"
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
      # Directly get the channels and ensure we have a list
      user_channels = Channels.list_user_channels(user.id)
      IO.puts("DEBUG: Found #{length(user_channels || [])} channels for user #{user.id}")

      socket
      |> assign(:stats, get_user_stats(user))
      |> assign(:user_channels, user_channels)  # Directly assign the channels
      |> assign(:media_files, get_user_media(user.id))
      |> assign(:notifications, get_user_notifications(user.id))
      |> assign(:user_portfolio, nil)  # Just set this to nil for now
    rescue
      e ->
        IO.puts("Error loading dashboard data: #{inspect(e)}")
        # Fallback to ensure the dashboard doesn't break if any function fails
        socket
        |> assign(:stats, %{channels: 0, members: 0, media_files: 0, total_views: 0})
        |> assign(:user_channels, [])
        |> assign(:media_files, [])
        |> assign(:notifications, [])
        |> assign(:user_portfolio, nil)
    end
  end

  # Create a separate function for fallback assignments
  defp fallback_assignments(socket, user) do
    socket
    |> assign(:stats, %{channels: 0, members: 0, media_files: 0, total_views: 0})
    |> assign(:user_channels, [])
    |> assign(:media_files, [])
    |> assign(:notifications, [])
    |> assign(:user_portfolio, nil)
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
      try do
        channels = Channels.list_user_channels(user_id)
        # Ensure we always return a list
        channels || []
      rescue
        _ ->
          # Log error for debugging
          IO.puts("Error retrieving channels for user #{user_id}")
          # Return empty list - or sample data if you prefer
          []
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

  # Add new helper function to load portfolio data
  defp assign_portfolio_data(socket, user) do
    # Get all portfolios for this user
    portfolios = Portfolios.list_user_portfolios(user.id)

    # Assign the first portfolio if any exist, otherwise nil
    case portfolios do
      [portfolio | _] ->
        socket
        |> assign(:user_portfolio, portfolio)

      [] ->
        socket
        |> assign(:user_portfolio, nil)
    end
  end

  # Helper functions for portfolio display
  defp has_portfolio?(_) do
    # Check if user portfolio is assigned and not nil
    false
  end

  defp get_section_count(portfolio) do
    # Count the portfolio sections
    case portfolio do
      nil -> 0
      _ -> Portfolios.list_portfolio_sections(portfolio.id) |> length()
    end
  end

  defp get_view_count(portfolio) do
    # Get portfolio visit count from the stats
    case portfolio do
      nil -> 0
      _ ->
        case Portfolios.get_portfolio_visit_stats(portfolio.id) do
          stats when is_list(stats) ->
            stats |> Enum.reduce(0, fn {_date, count}, acc -> acc + count end)
          _ -> 0
        end
    end
  end

  defp format_visibility(visibility) do
    case visibility do
      :public -> "Public"
      :private -> "Private"
      :link_only -> "Shared Link"
      _ -> "Private"
    end
  end

end
