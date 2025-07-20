# lib/frestyl_web/live/dashboard_live/show.ex - Enhanced dashboard with Frestyl Official
defmodule FrestylWeb.DashboardLive.Show do
  use FrestylWeb, :live_view

  alias Frestyl.{Portfolios, Community, Channels, Content}
  alias Frestyl.Community.{CollaborationEngine, GenreTaxonomy}
  import FrestylWeb.Navigation, only: [nav: 1]

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    # Get user interests for personalized content
    user_interests = Community.get_user_interests(user.id)

    socket =
      socket
      |> assign(:page_title, "Dashboard")
      |> assign(:user_interests, user_interests)
      |> assign(:portfolios, Portfolios.list_user_portfolios(user.id))
      |> assign(:show_frestyl_official, true) # Always show for everyone
      |> load_discovery_content()
      |> load_channel_recommendations()
      |> load_collaboration_opportunities()

    {:ok, socket}
  end

  @impl true
  def handle_event("join_channel", %{"channel_id" => channel_id}, socket) do
    case Channels.join_channel(channel_id, socket.assigns.current_user.id) do
      {:ok, _membership} ->
        # Refresh channel recommendations
        socket = load_channel_recommendations(socket)
        {:noreply, put_flash(socket, :info, "Successfully joined channel!")}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to join channel")}
    end
  end

  @impl true
  def handle_event("dismiss_discovery_item", %{"item_id" => item_id, "item_type" => type}, socket) do
    # Track dismissal for better recommendations
    Content.track_user_dismissal(socket.assigns.current_user.id, item_id, type)

    # Remove from current discovery content
    discovery_content = socket.assigns.discovery_content
    updated_content = remove_discovery_item(discovery_content, item_id, type)

    {:noreply, assign(socket, :discovery_content, updated_content)}
  end

  @impl true
  def handle_event("refresh_discovery", _params, socket) do
    {:noreply, load_discovery_content(socket)}
  end

  @impl true
  def handle_event("expand_frestyl_official", _params, socket) do
    # Navigate to full Frestyl Official channel view
    {:noreply, push_navigate(socket, to: "/channels/frestyl-official")}
  end

  # Load personalized discovery content for Frestyl Official
  defp load_discovery_content(socket) do
    user = socket.assigns.current_user
    user_interests = socket.assigns.user_interests

    discovery_content = if user_interests do
      # Personalized content based on user interests
      CollaborationEngine.get_frestyl_official_feed(user.id)
    else
      # Default content for users without interests set
      get_default_discovery_content()
    end

    assign(socket, :discovery_content, discovery_content)
  end

  defp load_channel_recommendations(socket) do
    user = socket.assigns.current_user
    user_interests = socket.assigns.user_interests

    recommendations = if user_interests do
      # Get recommendations based on user's genres and collaboration preferences
      GenreTaxonomy.recommend_learning_channels(user_interests.genres, user_interests.collaboration_preferences)
    else
      # Get popular channels for users without interests
      Channels.get_popular_channels(limit: 5)
    end

    assign(socket, :channel_recommendations, recommendations)
  end

  defp load_collaboration_opportunities(socket) do
    user = socket.assigns.current_user
    user_interests = socket.assigns.user_interests

    opportunities = if user_interests do
      user_profile = %{
        genres: user_interests.genres,
        skill_levels: user_interests.skill_levels,
        collaboration_preferences: user_interests.collaboration_preferences,
        engagement_level: user_interests.engagement_level
      }

      CollaborationEngine.find_collaboration_opportunities(user.id)
    else
      %{seeking_help: [], offering_expertise: [], peer_collaborations: []}
    end

    assign(socket, :collaboration_opportunities, opportunities)
  end

  defp get_default_discovery_content do
    %{
      featured_collaborations: Content.get_featured_collaborations(limit: 3),
      channel_spotlights: Content.get_channel_spotlights(limit: 2),
      platform_news: Content.get_latest_platform_news(limit: 2),
      trending_projects: Content.get_trending_projects(limit: 4),
      learning_opportunities: Content.get_popular_learning_content(limit: 3),
      community_challenges: Content.get_active_community_challenges(limit: 2)
    }
  end

  defp remove_discovery_item(discovery_content, item_id, type) do
    case type do
      "collaboration" ->
        %{discovery_content | featured_collaborations: filter_by_id(discovery_content.featured_collaborations, item_id)}
      "channel" ->
        %{discovery_content | channel_spotlights: filter_by_id(discovery_content.channel_spotlights, item_id)}
      "project" ->
        %{discovery_content | trending_projects: filter_by_id(discovery_content.trending_projects, item_id)}
      _ -> discovery_content
    end
  end

  defp filter_by_id(items, id_to_remove) do
    Enum.reject(items, &(&1.id == id_to_remove))
  end

  # Helper functions
  defp format_time_ago(datetime) do
    if datetime do
      diff = DateTime.diff(DateTime.utc_now(), datetime, :hour)

      cond do
        diff < 1 -> "Just now"
        diff < 24 -> "#{diff}h ago"
        diff < 168 -> "#{div(diff, 24)}d ago"
        true -> "#{div(diff, 168)}w ago"
      end
    else
      "Unknown"
    end
  end

  defp get_popular_categories do
    [
      %{icon: "🎵", name: "Music & Audio", description: "Music creation, instruments, podcasts"},
      %{icon: "🎨", name: "Visual Arts", description: "Graphics, UI/UX, photography"},
      %{icon: "💻", name: "Tech & Programming", description: "Web dev, mobile apps, AI"},
      %{icon: "✍️", name: "Writing & Content", description: "Creative writing, blogging"},
      %{icon: "💼", name: "Business & Finance", description: "Entrepreneurship, investing"},
      %{icon: "💪", name: "Health & Fitness", description: "Workouts, nutrition, wellness"}
    ]
  end
end
