# lib/frestyl_web/live/story_engine_live/hub.ex
defmodule FrestylWeb.StoryEngineLive.Hub do
  use FrestylWeb, :live_view

  import FrestylWeb.Live.Helpers.CommonHelpers
  alias Frestyl.StoryEngine.{IntentClassifier, UserPreferences, FormatManager}
  alias Frestyl.Features.TierManager
  alias Frestyl.Stories

  @impl true
  def mount(_params, session, socket) do
    current_user = get_current_user_from_session(session)

    if connected?(socket) do
      # Subscribe to story updates
      Phoenix.PubSub.subscribe(Frestyl.PubSub, "user_stories:#{current_user.id}")
    end

    user_tier = TierManager.get_user_tier(current_user)
    dashboard_data = UserPreferences.get_personalized_dashboard(current_user.id, user_tier)

    socket = socket
    |> assign(:current_user, current_user)
    |> assign(:user_tier, user_tier)
    |> assign(:selected_intent, dashboard_data.suggested_intent)
    |> assign(:available_intents, IntentClassifier.get_intents_for_user_tier(user_tier))
    |> assign(:available_formats, get_formats_for_intent(dashboard_data.suggested_intent, user_tier))
    |> assign(:recent_stories, load_recent_stories(current_user.id))
    |> assign(:dashboard_data, dashboard_data)
    |> assign(:show_intent_tooltip, false)
    |> assign(:story_stats, calculate_story_stats(current_user.id))

    {:ok, socket}
  end

  @impl true
  def handle_event("select_intent", %{"intent" => intent_key}, socket) do
    formats = get_formats_for_intent(intent_key, socket.assigns.user_tier)

    {:noreply, socket
     |> assign(:selected_intent, intent_key)
     |> assign(:available_formats, formats)
     |> push_event("intent_changed", %{intent: intent_key})}
  end

  @impl true
  def handle_event("create_story", %{"format" => format}, socket) do
    intent = socket.assigns.selected_intent
    user = socket.assigns.current_user

    # Check tier access
    format_config = FormatManager.get_format_config(format)

    unless TierManager.has_tier_access?(socket.assigns.user_tier, format_config.required_tier) do
      {:noreply, socket
       |> put_flash(:error, "Upgrade required to access this format")
       |> push_event("show_upgrade_modal", %{required_tier: format_config.required_tier})}
    else
      # Track usage
      UserPreferences.track_format_usage(user.id, format, intent)

      # Get quick start template
      template = Frestyl.StoryEngine.QuickStartTemplates.get_template(format, intent)

      # Create story
      story_params = %{
        title: template.title,
        story_type: format,
        intent_category: intent,
        template_data: template,
        creation_source: "story_engine",
        quick_start_template: "#{format}_#{intent}",
        created_by_id: user.id
      }

      case Stories.create_enhanced_story(story_params, user) do
        {:ok, story} ->
          {:noreply, redirect(socket, to: ~p"/stories/#{story.id}/edit")}
        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to create story")}
      end
    end
  end

  @impl true
  def handle_event("start_collaboration", %{"format" => format, "collaboration_type" => collab_type}, socket) do
    # Handle collaborative story creation
    intent = socket.assigns.selected_intent

    {:noreply, socket
     |> push_event("show_collaboration_modal", %{
       format: format,
       intent: intent,
       collaboration_type: collab_type
     })}
  end

  @impl true
  def handle_event("quick_create", %{"template" => template_key}, socket) do
    # Handle quick creation buttons
    case template_key do
      "article" -> create_quick_story(socket, "article", "personal_professional")
      "personal_story" -> create_quick_story(socket, "biography", "personal_professional")
      "case_study" -> create_quick_story(socket, "case_study", "business_growth")
      _ -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("show_templates_library", _params, socket) do
    {:noreply, push_event(socket, "show_modal", %{modal: "templates_library"})}
  end

  @impl true
  def handle_event("show_ai_assistant", _params, socket) do
    {:noreply, push_event(socket, "show_modal", %{modal: "ai_assistant_guide"})}
  end

  @impl true
  def handle_event("show_collaboration_guide", _params, socket) do
    {:noreply, push_event(socket, "show_modal", %{modal: "collaboration_guide"})}
  end

  @impl true
  def handle_event("show_examples_gallery", _params, socket) do
    {:noreply, redirect(socket, to: ~p"/story-examples")}
  end

  @impl true
  def handle_info({:story_created, story}, socket) do
    # Update recent stories when new story is created
    updated_recent = load_recent_stories(socket.assigns.current_user.id)

    {:noreply, assign(socket, :recent_stories, updated_recent)}
  end

  @impl true
  def handle_info({:intent_selected, intent_key}, socket) do
    formats = get_formats_for_intent(intent_key, socket.assigns.user_tier)

    {:noreply, socket
     |> assign(:selected_intent, intent_key)
     |> assign(:available_formats, formats)}
  end

  @impl true
  def handle_info({:create_story, format}, socket) do
    handle_event("create_story", %{"format" => format}, socket)
  end

  @impl true
  def handle_info({:quick_create, template_key}, socket) do
    handle_event("quick_create", %{"template" => template_key}, socket)
  end

  @impl true
  def handle_info({:show_upgrade_modal, required_tier}, socket) do
    upgrade_info = Frestyl.Features.TierManager.get_upgrade_suggestion(
      socket.assigns.user_tier,
      :format_access
    )

    {:noreply, push_event(socket, "show_upgrade_modal", upgrade_info)}
  end

  # Private Helper Functions

  defp get_current_user_from_session(session) do
    # Implementation depends on your auth system
    case session["user_token"] do
      nil -> nil
      token -> Frestyl.Accounts.get_user_by_session_token(token)
    end
  end

defp get_formats_for_intent(intent_key, user_tier) do
  # Get formats for the intent (you'll need to implement this part)
  formats = get_formats_for_intent_key(intent_key) # or however you get the formats

  Enum.map(formats, fn format ->
    case format do
      nil ->
        nil
      %{} = format_map ->
        required_tier = Map.get(format_map, :required_tier, nil)
        %{format_map | accessible: user_has_access?(user_tier, required_tier)}
    end
  end)
  |> Enum.reject(&is_nil/1)
end

defp get_formats_for_intent_key(intent_key) do
  # Return the actual formats list based on intent_key
  # This depends on how your formats are structured
  case intent_key do
    "creative_writing" -> [
      %{name: "Novel", required_tier: "creator"},
      %{name: "Short Story", required_tier: nil}
    ]
    "business" -> [
      %{name: "Customer Story", required_tier: nil},
      %{name: "Case Study", required_tier: "creator"}
    ]
    _ -> []
  end
end

# Also make sure user_has_access? handles nil values:
defp user_has_access?(user_tier, nil), do: true  # No tier required
defp user_has_access?(user_tier, required_tier) do
  # Your existing logic here
  TierManager.has_access?(user_tier, required_tier)
end

  defp load_recent_stories(user_id) do
    Stories.list_user_stories(user_id)
    |> Enum.take(6)
    |> Enum.map(fn story ->
      %{
        id: story.id,
        title: story.title,
        story_type: story.story_type,
        updated_at: story.updated_at,
        completion_percentage: story.completion_percentage || 0,
        word_count: story.current_word_count || 0,
        collaboration_count: count_collaborators(story),
        status: determine_story_status(story)
      }
    end)
  end

  defp calculate_story_stats(user_id) do
    stories = Stories.list_user_stories(user_id)

    %{
      total_stories: length(stories),
      active_collaborations: count_active_collaborations(stories),
      average_completion: calculate_average_completion(stories),
      words_this_week: calculate_words_this_week(stories)
    }
  end

  defp create_quick_story(socket, format, intent) do
    handle_event("create_story", %{"format" => format},
                 assign(socket, :selected_intent, intent))
  end

  defp count_collaborators(story) do
    # Count unique collaborators on this story
    case story.collaborators do
      nil -> 0
      collaborators when is_list(collaborators) -> length(collaborators)
      _ -> 0
    end
  end

  defp determine_story_status(story) do
    completion = story.completion_percentage || 0

    cond do
      completion >= 90 -> "completed"
      completion >= 50 -> "in_progress"
      story.collaboration_mode == "active" -> "collaborative"
      true -> "draft"
    end
  end

  defp count_active_collaborations(stories) do
    Enum.count(stories, &(&1.collaboration_mode in ["active", "open"]))
  end

  defp calculate_average_completion(stories) do
    case stories do
      [] -> 0
      stories ->
        stories
        |> Enum.map(&(&1.completion_percentage || 0))
        |> Enum.sum()
        |> div(length(stories))
    end
  end

  defp calculate_words_this_week(stories) do
    one_week_ago = DateTime.add(DateTime.utc_now(), -7, :day)

    stories
    |> Enum.filter(&(DateTime.compare(&1.updated_at, one_week_ago) == :gt))
    |> Enum.map(&(&1.current_word_count || 0))
    |> Enum.sum()
  end
end
