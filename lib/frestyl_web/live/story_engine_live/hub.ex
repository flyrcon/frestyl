# lib/frestyl_web/live/story_engine_live/hub.ex
defmodule FrestylWeb.StoryEngineLive.Hub do
  use FrestylWeb, :live_view

  import FrestylWeb.Live.Helpers.CommonHelpers
  alias Frestyl.StoryEngine.{IntentClassifier, UserPreferences, FormatManager}
  alias Frestyl.Features.TierManager
  alias Frestyl.Stories
  alias Frestyl.Stories.Collaboration

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
    |> assign(:story_stats, calculate_story_stats(current_user.id))
    |> assign(:show_template_modal, false)
    |> assign(:show_collaboration_modal, false)
    |> assign(:show_import_modal, false)
    |> assign(:selected_template_category, "popular")
    |> assign(:collaboration_code, "")
    |> assign(:open_collaborations, load_open_collaborations())

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

      case Stories.create_story_for_engine(story_params, user) do
        {:ok, story} ->
          {:noreply, redirect(socket, to: ~p"/stories/#{story.id}/edit")}
        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to create story")}
      end
    end
  end

    @impl true
  def handle_event("create_story_direct", %{"format" => format, "intent" => intent}, socket) do
    user = socket.assigns.current_user
    format_config = FormatManager.get_format_config(format)

    # Check tier access
    unless TierManager.has_tier_access?(socket.assigns.user_tier, format_config.required_tier) do
      {:noreply, socket
       |> put_flash(:error, "Upgrade required to access this format")
       |> push_event("show_upgrade_modal", %{required_tier: format_config.required_tier})}
    else
      # Create story directly
      create_story_with_setup(socket, format, intent, %{})
    end
  end

  @impl true
  def handle_event("create_blank_story", _params, socket) do
    # Show format selection for blank story
    {:noreply, assign(socket, :show_format_selection_modal, true)}
  end

  @impl true
  def handle_event("continue_story", %{"story-id" => story_id}, socket) do
    {:noreply, redirect(socket, to: ~p"/stories/#{story_id}/edit")}
  end

  @impl true
  def handle_event("create_story_from_recommendation", %{"format" => format, "template" => template}, socket) do
    user = socket.assigns.current_user
    intent = socket.assigns.selected_intent || "personal_professional"

    create_story_with_setup(socket, format, intent, %{template: template})
  end

    @impl true
  def handle_event("show_collaboration_modal", _params, socket) do
    open_collaborations = load_open_collaborations()

    {:noreply, socket
     |> assign(:show_collaboration_modal, true)
     |> assign(:open_collaborations, open_collaborations)}
  end

  @impl true
  def handle_event("close_collaboration_modal", _params, socket) do
    {:noreply, assign(socket, :show_collaboration_modal, false)}
  end

  @impl true
  def handle_event("join_by_code", _params, socket) do
    collaboration_code = socket.assigns.collaboration_code

    case Collaboration.join_by_invitation_code(collaboration_code, socket.assigns.current_user) do
      {:ok, story} ->
        {:noreply, socket
         |> put_flash(:info, "Successfully joined collaboration!")
         |> redirect(to: ~p"/stories/#{story.id}/edit")}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Invalid invitation code")}

      {:error, :expired} ->
        {:noreply, put_flash(socket, :error, "Invitation code has expired")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to join: #{reason}")}
    end
  end

  @impl true
  def handle_event("join_collaboration", %{"collaboration-id" => collaboration_id}, socket) do
    case Collaboration.join_open_collaboration(collaboration_id, socket.assigns.current_user) do
      {:ok, story} ->
        {:noreply, socket
         |> put_flash(:info, "Successfully joined collaboration!")
         |> redirect(to: ~p"/stories/#{story.id}/edit")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to join collaboration: #{reason}")}
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
  def handle_event("show_template_modal", _params, socket) do
    {:noreply, assign(socket, :show_template_modal, true)}
  end

  @impl true
  def handle_event("close_template_modal", _params, socket) do
    {:noreply, assign(socket, :show_template_modal, false)}
  end

  @impl true
  def handle_event("select_template_category", %{"category" => category}, socket) do
    {:noreply, assign(socket, :selected_template_category, category)}
  end

  @impl true
  def handle_event("select_template", %{"template-id" => template_id}, socket) do
    template = get_template_by_id(template_id)

    # Create story with selected template
    create_story_with_setup(socket, template.format, template.intent, %{
      template: template,
      title: template.default_title
    })
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
  def handle_event("show_import_modal", _params, socket) do
    {:noreply, assign(socket, :show_import_modal, true)}
  end

  @impl true
  def handle_event("close_import_modal", _params, socket) do
    {:noreply, assign(socket, :show_import_modal, false)}
  end

  @impl true
  def handle_event("import_document", _params, socket) do
    # Handle document import - this would process uploaded files
    {:noreply, socket
     |> put_flash(:info, "Document import feature coming soon!")
     |> assign(:show_import_modal, false)}
  end

    @impl true
  def handle_event("show_upgrade_modal", _params, socket) do
    {:noreply, push_event(socket, "show_upgrade_modal", %{current_tier: socket.assigns.user_tier})}
  end

  @impl true
  def handle_info({:story_created, story}, socket) do
    # Update recent stories when new story is created
    updated_recent = load_recent_stories(socket.assigns.current_user.id)
    updated_stats = calculate_story_stats(socket.assigns.current_user.id)

    {:noreply, socket
     |> assign(:recent_stories, updated_recent)
     |> assign(:story_stats, updated_stats)}
  end

  @impl true
  def handle_info({:story_updated, story}, socket) do
    # Update specific story in recent list
    updated_recent = update_story_in_list(socket.assigns.recent_stories, story)

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

    defp create_story_with_setup(socket, format, intent, options \\ %{}) do
    user = socket.assigns.current_user

    # Get template or use default
    template = case Map.get(options, :template) do
      nil -> QuickStartTemplates.get_template(format, intent)
      custom_template -> custom_template
    end

    # Build story parameters
    story_params = %{
      title: Map.get(options, :title, template.title),
      story_type: format,
      intent_category: intent,
      template_data: template,
      creation_source: "story_engine_hub",
      quick_start_template: "#{format}_#{intent}",
      created_by_id: user.id,
      collaboration_mode: Map.get(options, :collaboration_mode, "owner_only")
    }

    # Track usage
    UserPreferences.track_format_usage(user.id, format, intent)

    case Stories.create_story_for_engine(story_params, user) do
      {:ok, story} ->
        {:noreply, socket
         |> put_flash(:info, "Story created! Opening editor...")
         |> redirect(to: ~p"/stories/#{story.id}/edit")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create story. Please try again.")}
    end
  end

  defp get_formats_for_intent(intent_key, user_tier) when is_binary(intent_key) do
    intent_config = IntentClassifier.get_intent_config(intent_key)

    case intent_config do
      nil -> %{}
      config ->
        config.formats
        |> Enum.map(&FormatManager.get_format_config/1)
        |> Enum.filter(&(&1 != nil))
        |> Enum.filter(&TierManager.has_tier_access?(user_tier, &1.required_tier))
        |> Enum.into(%{}, fn format -> {format.key, format} end)
    end
  end

  defp get_formats_for_intent(nil, _user_tier), do: %{}

  defp load_recent_stories(user_id) do
    Stories.list_user_stories(user_id, limit: 6)
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

  defp load_open_collaborations do
    # Load open collaborations that users can join
    # For now, return empty list until collaboration system is fully implemented
    try do
      Collaboration.list_open_collaborations()
      |> Enum.map(fn collab ->
        %{
          id: collab.id,
          title: collab.story.title,
          description: collab.description || "Join this collaborative story",
          creator_name: collab.story.created_by.name,
          collaborator_count: length(collab.story.collaborators || []),
          story_type: collab.story.story_type
        }
      end)
    rescue
      UndefinedFunctionError ->
        # Return sample data for now
        [
          %{
            id: "sample-1",
            title: "Community Novel Project",
            description: "Join our collaborative fantasy novel",
            creator_name: "Story Creator",
            collaborator_count: 3,
            story_type: "novel"
          },
          %{
            id: "sample-2",
            title: "Business Case Study",
            description: "Help document this success story",
            creator_name: "Business Lead",
            collaborator_count: 5,
            story_type: "case_study"
          }
        ]
    end
  end

  defp template_categories do
    [
      %{key: "popular", name: "Popular"},
      %{key: "business", name: "Business"},
      %{key: "creative", name: "Creative"},
      %{key: "personal", name: "Personal"},
      %{key: "educational", name: "Educational"},
      %{key: "experimental", name: "Experimental"}
    ]
  end

  defp get_templates_for_category(category) do
    # This would fetch templates from your template system
    case category do
      "popular" ->
        [
          %{
            id: "novel_hero_journey",
            name: "Hero's Journey Novel",
            description: "Classic storytelling structure for novels",
            category: "Creative",
            icon: "📚",
            gradient: "bg-gradient-to-br from-purple-500 to-indigo-600",
            estimated_time: "3-6 months",
            sections_count: 12,
            format: "novel",
            intent: "creative_expression"
          },
          %{
            id: "case_study_business",
            name: "Business Case Study",
            description: "Professional case study template",
            category: "Business",
            icon: "📊",
            gradient: "bg-gradient-to-br from-blue-500 to-cyan-500",
            estimated_time: "2-4 hours",
            sections_count: 6,
            format: "case_study",
            intent: "business_growth"
          },
          %{
            id: "personal_memoir",
            name: "Personal Memoir",
            description: "Share your life story with rich detail",
            category: "Personal",
            icon: "📖",
            gradient: "bg-gradient-to-br from-green-500 to-teal-500",
            estimated_time: "1-3 months",
            sections_count: 8,
            format: "memoir",
            intent: "personal_professional"
          }
        ]

      "business" ->
        [
          %{
            id: "marketing_story",
            name: "Marketing Story",
            description: "Compelling brand narrative template",
            category: "Business",
            icon: "📈",
            gradient: "bg-gradient-to-br from-green-500 to-emerald-500",
            estimated_time: "1-2 hours",
            sections_count: 5,
            format: "marketing_story",
            intent: "business_growth"
          }
        ]

      _ -> []
    end
  end

  defp get_template_by_id(template_id) do
    # Find template by ID across all categories
    template_categories()
    |> Enum.flat_map(&get_templates_for_category(&1.key))
    |> Enum.find(&(&1.id == template_id))
  end

  defp count_collaborators(story) do
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
      story.collaboration_mode in ["active", "open"] -> "collaborative"
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

  defp update_story_in_list(stories, updated_story) do
    Enum.map(stories, fn story ->
      if story.id == updated_story.id do
        %{story |
          title: updated_story.title,
          completion_percentage: updated_story.completion_percentage || 0,
          word_count: updated_story.current_word_count || 0
        }
      else
        story
      end
    end)
  end

  defp get_current_user_from_session(session) do
    # Your existing session handling
    session["current_user"]
  end

  # Helper functions for the template
  defp format_time_ago(datetime) do
    case DateTime.diff(DateTime.utc_now(), datetime, :second) do
      seconds when seconds < 60 -> "just now"
      seconds when seconds < 3600 -> "#{div(seconds, 60)}m ago"
      seconds when seconds < 86400 -> "#{div(seconds, 3600)}h ago"
      seconds when seconds < 604800 -> "#{div(seconds, 86400)}d ago"
      _ -> "#{div(DateTime.diff(DateTime.utc_now(), datetime, :second), 604800)}w ago"
    end
  end

  defp story_status_badge(status) do
    case status do
      "completed" -> %{class: "bg-green-100 text-green-800", text: "Complete"}
      "in_progress" -> %{class: "bg-blue-100 text-blue-800", text: "In Progress"}
      "collaborative" -> %{class: "bg-purple-100 text-purple-800", text: "Collaborative"}
      "draft" -> %{class: "bg-gray-100 text-gray-800", text: "Draft"}
      _ -> %{class: "bg-gray-100 text-gray-800", text: "Draft"}
    end
  end

end
