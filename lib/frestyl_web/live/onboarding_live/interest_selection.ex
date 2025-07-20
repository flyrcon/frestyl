# lib/frestyl_web/live/onboarding_live/interest_selection.ex
defmodule FrestylWeb.OnboardingLive.InterestSelection do
  use FrestylWeb, :live_view

  alias Frestyl.{Accounts, Community, Channels}
  alias Frestyl.Community.GenreTaxonomy

  @impl true
  def mount(_params, _session, socket) do
    if socket.assigns.current_user.onboarding_completed do
      {:ok, push_navigate(socket, to: "/dashboard")}
    else
      socket =
        socket
        |> assign(:page_title, "What Interests You?")
        |> assign(:step, 1) # New step 1: Interest selection
        |> assign(:selected_genres, [])
        |> assign(:selected_sub_genres, [])
        |> assign(:skill_levels, %{})
        |> assign(:collaboration_preferences, [])
        |> assign(:current_category, nil)
        |> assign(:show_sub_genres, false)
        |> assign(:popular_categories, get_popular_categories())
        |> assign(:all_categories, GenreTaxonomy.get_full_taxonomy())
        |> assign(:show_all_categories, false)
        |> assign(:can_continue, false)

      {:ok, socket}
    end
  end

  @impl true
  def handle_event("toggle_category", %{"category" => category}, socket) do
    selected_genres = socket.assigns.selected_genres

    new_selection = if category in selected_genres do
      List.delete(selected_genres, category)
    else
      [category | selected_genres] |> Enum.take(5) # Limit to 5 categories
    end

    can_continue = length(new_selection) >= 1

    {:noreply,
     socket
     |> assign(:selected_genres, new_selection)
     |> assign(:can_continue, can_continue)
     |> maybe_show_sub_genres(category)}
  end

  @impl true
  def handle_event("toggle_sub_genre", %{"sub_genre" => sub_genre, "parent" => parent}, socket) do
    selected_sub_genres = socket.assigns.selected_sub_genres

    new_selection = if sub_genre in selected_sub_genres do
      List.delete(selected_sub_genres, sub_genre)
    else
      [sub_genre | selected_sub_genres] |> Enum.take(15) # Allow more sub-genres
    end

    {:noreply, assign(socket, :selected_sub_genres, new_selection)}
  end

  @impl true
  def handle_event("set_skill_level", %{"genre" => genre, "level" => level}, socket) do
    skill_levels = Map.put(socket.assigns.skill_levels, genre, level)
    {:noreply, assign(socket, :skill_levels, skill_levels)}
  end

  @impl true
  def handle_event("toggle_collaboration", %{"type" => type}, socket) do
    collab_prefs = socket.assigns.collaboration_preferences

    new_prefs = if type in collab_prefs do
      List.delete(collab_prefs, type)
    else
      [type | collab_prefs]
    end

    {:noreply, assign(socket, :collaboration_preferences, new_prefs)}
  end

  @impl true
  def handle_event("show_all_categories", _params, socket) do
    {:noreply, assign(socket, :show_all_categories, !socket.assigns.show_all_categories)}
  end

  @impl true
  def handle_event("continue_onboarding", _params, socket) do
    # Save user interests and create community profile
    user_interests = %{
      genres: socket.assigns.selected_genres,
      sub_genres: socket.assigns.selected_sub_genres,
      skill_levels: socket.assigns.skill_levels,
      collaboration_preferences: socket.assigns.collaboration_preferences
    }

    case Community.create_user_interests(socket.assigns.current_user.id, user_interests) do
      {:ok, _interests} ->
        # Auto-join Frestyl Official channel
        {:ok, official_channel} = ensure_frestyl_official_exists()
        Channels.join_channel(official_channel.id, socket.assigns.current_user.id)

        # Auto-join relevant community channels
        auto_join_community_channels(socket.assigns.current_user.id, socket.assigns.selected_genres)

        # Continue to next step (resume upload or skip)
        {:noreply, push_navigate(socket, to: "/onboarding/resume")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to save interests. Please try again.")}
    end
  end

  # Helper functions
  defp get_popular_categories do
    # Start with 8 most popular/versatile categories
    [
      %{
        key: "music_audio",
        name: "Music & Audio",
        description: "Music creation, instruments, podcasts",
        icon: "🎵",
        member_count: "15.2k"
      },
      %{
        key: "visual_arts",
        name: "Visual Arts & Design",
        description: "Graphics, UI/UX, photography, illustration",
        icon: "🎨",
        member_count: "22.1k"
      },
      %{
        key: "tech_development",
        name: "Tech & Programming",
        description: "Web dev, mobile apps, AI, coding",
        icon: "💻",
        member_count: "31.5k"
      },
      %{
        key: "writing_content",
        name: "Writing & Content",
        description: "Creative writing, blogging, copywriting",
        icon: "✍️",
        member_count: "18.7k"
      },
      %{
        key: "business_finance",
        name: "Business & Finance",
        description: "Entrepreneurship, investing, startups",
        icon: "💼",
        member_count: "12.8k"
      },
      %{
        key: "health_fitness",
        name: "Health & Fitness",
        description: "Workouts, nutrition, wellness",
        icon: "💪",
        member_count: "9.4k"
      },
      %{
        key: "food_culinary",
        name: "Food & Cooking",
        description: "Cooking, baking, culinary arts",
        icon: "🍳",
        member_count: "8.9k"
      },
      %{
        key: "languages_communication",
        name: "Languages & Communication",
        description: "Language learning, public speaking",
        icon: "🗣️",
        member_count: "11.2k"
      }
    ]
  end

  defp maybe_show_sub_genres(socket, category) do
    if category in socket.assigns.selected_genres do
      socket
      |> assign(:current_category, category)
      |> assign(:show_sub_genres, true)
    else
      socket
    end
  end

  defp ensure_frestyl_official_exists do
    case Channels.get_channel_by_slug("frestyl-official") do
      nil -> create_frestyl_official_channel()
      channel -> {:ok, channel}
    end
  end

  defp create_frestyl_official_channel do
    attrs = %{
      name: "Frestyl Official",
      slug: "frestyl-official",
      description: "Platform news, community highlights, and discovery hub",
      channel_type: "official",
      visibility: "public",
      user_id: get_system_user_id(),
      metadata: %{
        "is_official" => true,
        "auto_join" => true,
        "discovery_enabled" => true,
        "content_types" => ["platform_news", "community_highlights", "channel_promotion", "marketplace"]
      },
      color_scheme: %{
        "primary" => "#6366f1",
        "secondary" => "#8b5cf6",
        "accent" => "#06b6d4"
      },
      featured_content: %{
        "welcome_message" => "Welcome to Frestyl! Discover amazing creators and collaborate on exciting projects.",
        "community_guidelines" => "/community-guidelines",
        "getting_started" => "/getting-started"
      }
    }

    Channels.create_channel(attrs)
  end

  defp auto_join_community_channels(user_id, selected_genres) do
    # Find and auto-join up to 3 popular channels for each selected genre
    selected_genres
    |> Enum.take(3) # Limit to prevent overwhelming
    |> Enum.each(fn genre ->
      channels = Channels.find_popular_channels_by_genre(genre, limit: 2)
      Enum.each(channels, fn channel ->
        Channels.join_channel(channel.id, user_id)
      end)
    end)
  end

  defp get_system_user_id do
    # Get or create system user for official content
    case Accounts.get_user_by_email("system@frestyl.com") do
      nil ->
        {:ok, user} = Accounts.create_user(%{
          email: "system@frestyl.com",
          name: "Frestyl System",
          primary_account_type: :enterprise
        })
        user.id
      user -> user.id
    end
  end
end
