# lib/frestyl_web/live/story_engine_live/hub.ex
defmodule FrestylWeb.StoryEngineLive.Hub do
  use FrestylWeb, :live_view

  import FrestylWeb.Live.Helpers.CommonHelpers, except: [format_word_count: 1]
  alias Frestyl.StoryEngine.{CollaborationModes, IntentClassifier, UserPreferences, FormatManager, QuickStartTemplates}
  alias Frestyl.Features.TierManager
  alias Frestyl.{Stories, UserPreferences}
  alias Frestyl.Stories.Collaboration

  @impl true
  def mount(_params, session, socket) do
    current_user = get_current_user_from_session(session)

    if connected?(socket) do
      # Subscribe to story updates
      Phoenix.PubSub.subscribe(Frestyl.PubSub, "user_stories:#{current_user.id}")
    end

    user_tier = TierManager.get_user_tier(current_user)

    # Add error handling for dashboard_data
    dashboard_data = try do
      UserPreferences.get_personalized_dashboard(current_user.id, user_tier)
    rescue
      UndefinedFunctionError ->
        %{suggested_intent: "entertain"}
    end

    # Add error handling for available_intents
    available_intents = try do
      IntentClassifier.get_intents_for_user_tier(user_tier)
    rescue
      UndefinedFunctionError ->
        ["entertain", "educate", "persuade", "document"]
    end

    socket = socket
    |> assign(:current_user, current_user)
    |> assign(:user_tier, user_tier)
    |> assign(:selected_intent, dashboard_data.suggested_intent)
    |> assign(:available_intents, available_intents)
    |> assign(:available_formats, get_formats_for_intent(dashboard_data.suggested_intent, user_tier))
    |> assign(:recent_stories, load_recent_stories(current_user.id))
    |> assign(:dashboard_data, dashboard_data)
    |> assign(:story_stats, calculate_story_stats(current_user.id))
    |> assign(:show_template_modal, false)
    |> assign(:show_collaboration_modal, false)
    |> assign(:show_import_modal, false)
    |> assign(:show_format_selection_modal, false)
    |> assign(:selected_template_category, "popular")
    |> assign(:collaboration_code, "")
    |> assign(:open_collaborations, load_open_collaborations())

    {:ok, socket}
  end

  # ============================================================================
  # PUBLIC HELPER FUNCTIONS FOR TEMPLATE ACCESS
  # ============================================================================

  def format_time_ago(datetime) do
    case DateTime.diff(DateTime.utc_now(), datetime, :second) do
      seconds when seconds < 60 -> "just now"
      seconds when seconds < 3600 -> "#{div(seconds, 60)}m ago"
      seconds when seconds < 86400 -> "#{div(seconds, 3600)}h ago"
      seconds when seconds < 604800 -> "#{div(seconds, 86400)}d ago"
      _ -> "#{div(DateTime.diff(DateTime.utc_now(), datetime, :second), 604800)}w ago"
    end
  end

  def story_status_badge(status) do
    case status do
      "completed" -> %{class: "bg-green-100 text-green-800", text: "Complete"}
      "in_progress" -> %{class: "bg-blue-100 text-blue-800", text: "In Progress"}
      "collaborative" -> %{class: "bg-purple-100 text-purple-800", text: "Collaborative"}
      "draft" -> %{class: "bg-gray-100 text-gray-800", text: "Draft"}
      _ -> %{class: "bg-gray-100 text-gray-800", text: "Draft"}
    end
  end

  def format_word_count(count) when is_integer(count) do
    cond do
      count >= 1000 -> "#{Float.round(count / 1000, 1)}k"
      true -> to_string(count)
    end
  end
  def format_word_count(_), do: "0"

  # ============================================================================
  # EVENT HANDLERS
  # ============================================================================

  @impl true
  def handle_event("select_intent", %{"intent" => intent_key}, socket) do
    formats = get_formats_for_intent(intent_key, socket.assigns.user_tier)

    {:noreply, socket
     |> assign(:selected_intent, intent_key)
     |> assign(:available_formats, formats)
     |> push_event("intent_changed", %{intent: intent_key})}
  end

    @impl true
  def handle_event("create_story", %{"format" => format, "intent" => intent} = params, socket) do
    user = socket.assigns.current_user

    # Check tier requirements
    required_tier = QuickStartTemplates.get_required_tier(format, intent)

    unless TierManager.user_has_tier?(socket.assigns.user_tier, required_tier) do
      {:noreply, socket
      |> put_flash(:error, "Upgrade required to access this format")
      |> push_event("show_upgrade_modal", %{required_tier: required_tier})}
    else
      # Enhanced story creation with session support
      collaboration_requested = Map.get(params, "collaboration", "false") == "true"
      audio_features_requested = Map.get(params, "audio_features", "false") == "true"

      create_story_with_enhanced_features(socket, format, intent, %{
        collaboration_requested: collaboration_requested,
        audio_features_requested: audio_features_requested,
        template_key: Map.get(params, "template"),
        title: Map.get(params, "title")
      })
    end
  end

  @impl true
  def handle_event("create_story_with_format", %{"format" => format}, socket) do
    intent = socket.assigns.selected_intent
    user = socket.assigns.current_user

    # Check tier access - ADD NIL CHECK HERE
    format_config = FormatManager.get_format_config(format)

    # FIX: Handle case where format_config is nil
    required_tier = if format_config, do: format_config.required_tier, else: nil

    unless TierManager.has_tier_access?(socket.assigns.user_tier, required_tier) do
      {:noreply, socket
      |> put_flash(:error, "Upgrade required to access this format")
      |> push_event("show_upgrade_modal", %{required_tier: required_tier})}
    else
      # Continue with story creation...
      # Use your existing create_story_with_setup logic
      create_story_with_editor_state(socket, format, intent, %{})
    end
  end

  @impl true
  def handle_event("create_frestyl_original", %{"story_type" => story_type} = params, socket) do
    user = socket.assigns.current_user

    # Frestyl Originals always need collaboration/audio features
    create_story_with_enhanced_features(socket, story_type, "create", %{
      collaboration_requested: true,
      audio_features_requested: true,
      is_frestyl_original: true,
      title: Map.get(params, "title", get_default_frestyl_title(story_type))
    })
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
      editor_url = build_editor_url_with_state(story, format, intent, options)
        {:noreply, socket
         |> put_flash(:info, "Story created! Opening editor...")
         |> redirect(to: ~p"/stories/#{story.id}/edit")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create story. Please try again.")}
    end
  end

  @impl true
  def handle_event("continue_story", %{"story-id" => story_id}, socket) do
    case Stories.get_enhanced_story(story_id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Story not found")}
      story ->
        editor_url = build_continuation_url(story)
        {:noreply, redirect(socket, to: editor_url)}
    end
  end

  @impl true
  def handle_event("launch_studio", %{"mode" => mode}, socket) do
    create_story_with_editor_state(socket, "audio_story", "entertain", %{
      editor_mode: "studio",
      studio_mode: mode,
      focus_mode: "distraction_free"
    })
  end

  @impl true
  def handle_event("create_blank_story", _params, socket) do
    {:noreply, assign(socket, :show_format_selection_modal, true)}
  end

  @impl true
  def handle_event("show_templates_library", _params, socket) do
    {:noreply, push_event(socket, "show_modal", %{modal: "templates_library"})}
  end

  @impl true
  def handle_event("view_all_stories", _params, socket) do
    {:noreply, redirect(socket, to: ~p"/stories")}
  end

  @impl true
  def handle_event("create_from_template", %{"template" => template_key}, socket) do
    template = get_template_by_key(template_key)
    intent = socket.assigns.selected_intent || template.default_intent

    create_story_with_editor_state(socket, template.format, intent, %{
      template: template,
      template_key: template_key,
      title: template.default_title,
      focus_mode: template.recommended_focus_mode
    })
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
  def handle_event("show_template_modal", _params, socket) do
    {:noreply, assign(socket, :show_template_modal, true)}
  end

  @impl true
  def handle_event("close_template_modal", _params, socket) do
    {:noreply, assign(socket, :show_template_modal, false)}
  end

  # ============================================================================
  # ENHANCED EDITOR STATE FUNCTIONS
  # ============================================================================

    defp create_story_with_enhanced_features(socket, format, intent, options \\ %{}) do
    user = socket.assigns.current_user

    # Get template or use default
    template = case Map.get(options, :template_key) do
      nil -> QuickStartTemplates.get_template(format, intent)
      template_key -> QuickStartTemplates.get_template_by_key(template_key)
    end

    # Build enhanced story parameters
    story_params = %{
      title: Map.get(options, :title, template.title),
      story_type: format,
      intent_category: intent,
      template_data: template,
      creation_source: "story_engine_hub",
      quick_start_template: "#{format}_#{intent}",
      created_by_id: user.id,
      collaboration_mode: determine_initial_collaboration_mode(options),
      audio_features_enabled: Map.get(options, :audio_features_requested, false),
      editor_preferences: build_enhanced_editor_preferences(format, intent, options),
      initial_section_config: build_initial_section_config(format, intent)
    }

    # Track usage
    UserPreferences.track_format_usage(user.id, format, intent)

    # Create story with collaboration support
    case Stories.create_story_with_collaboration_support(story_params, user, [
      collaboration: Map.get(options, :collaboration_requested, false),
      audio_features: Map.get(options, :audio_features_requested, false)
    ]) do
      {:ok, story, session} ->
        editor_url = build_enhanced_editor_url(story, session, format, intent, options)

        {:noreply, socket
         |> put_flash(:info, get_creation_success_message(format, session != nil))
         |> redirect(to: editor_url)}

      {:error, changeset} when is_struct(changeset, Ecto.Changeset) ->
        {:noreply, put_flash(socket, :error, "Failed to create story. Please try again.")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Error: #{reason}")}
    end
  end

  defp determine_initial_collaboration_mode(options) do
    cond do
      Map.get(options, :collaboration_requested, false) -> "collaborative"
      Map.get(options, :is_frestyl_original, false) -> "collaborative"
      true -> "owner_only"
    end
  end

  defp build_enhanced_editor_url(story, session, format, intent, options) do
    base_url = ~p"/stories/#{story.id}/edit"

    params = [
      {"mode", determine_editor_mode_from_format(format)},
      {"intent", intent},
      {"source", "hub_creation"}
    ]

    # Add collaboration parameters if session exists
    params = if session do
      params ++ [
        {"collaboration", "true"},
        {"session_id", session.id}
      ]
    else
      params
    end

    # Add additional parameters
    params = params
    |> maybe_add_param("template", Map.get(options, :template_key))
    |> maybe_add_param("focus", Map.get(options, :focus_mode))
    |> maybe_add_param("audio", Map.get(options, :audio_features_requested, false))

    build_url_with_params(base_url, params)
  end

    defp build_enhanced_editor_preferences(format, intent, options) do
    base_preferences = %{
      auto_save_interval: 2000,
      ai_assistance_level: get_ai_assistance_level(intent),
      collaboration_enabled: Map.get(options, :collaboration_requested, false),
      focus_mode: get_default_focus_mode(format),
      audio_features_enabled: Map.get(options, :audio_features_requested, false)
    }

    format_preferences = case format do
      "novel" -> %{
        show_character_panel: true,
        show_plot_tracker: true,
        word_count_target: 50000,
        section_type: "chapter",
        editor_mode: "manuscript"
      }
      "screenplay" -> %{
        formatting_mode: "industry_standard",
        show_scene_breakdown: true,
        page_target: 120,
        section_type: "scene",
        editor_mode: "manuscript"
      }
      "case_study" -> %{
        show_data_panel: true,
        template_guided: true,
        structure_hints: true,
        section_type: "section",
        editor_mode: "business"
      }
      "blog_series" -> %{
        seo_mode: true,
        show_publishing_panel: true,
        social_preview: true,
        section_type: "post",
        editor_mode: "business"
      }
      "live_story" -> %{
        real_time_audience: true,
        branching_enabled: true,
        streaming_mode: true,
        section_type: "segment",
        editor_mode: "experimental"
      }
      "voice_sketch" -> %{
        audio_visual_sync: true,
        drawing_tools: true,
        timeline_mode: true,
        section_type: "sketch",
        editor_mode: "experimental"
      }
      "audio_portfolio" -> %{
        spatial_audio: true,
        navigation_mode: "immersive",
        visitor_analytics: true,
        section_type: "experience",
        editor_mode: "experimental"
      }
      "narrative_beats" -> %{
        beat_machine_integration: true,
        musical_structure: true,
        story_sync: true,
        section_type: "beat",
        editor_mode: "experimental"
      }
      _ -> %{
        section_type: "section",
        editor_mode: "standard"
      }
    end

    Map.merge(base_preferences, format_preferences)
  end

  defp get_creation_success_message(format, has_session) do
    base_message = "Story created! Opening editor..."

    case {format, has_session} do
      {format, true} when format in ["live_story", "voice_sketch", "audio_portfolio"] ->
        "#{base_message} Collaboration session started!"

      {_, true} ->
        "#{base_message} Collaboration features enabled!"

      {_, false} ->
        base_message
    end
  end

  defp get_default_frestyl_title(story_type) do
    case story_type do
      "live_story" -> "My Live Story"
      "voice_sketch" -> "Voice Sketch Project"
      "audio_portfolio" -> "Audio Portfolio"
      "data_jam" -> "Data Jam Session"
      "story_remix" -> "Story Remix"
      "narrative_beats" -> "Narrative Beats"
      _ -> "Untitled Frestyl Original"
    end
  end

  # ============================================================================
  # ENHANCED QUICK START OPTIONS
  # ============================================================================

  @impl true
  def handle_event("show_quick_start_options", _params, socket) do
    # Enhanced quick start with Frestyl Originals
    quick_start_options = get_enhanced_quick_start_options()

    {:noreply, socket
     |> assign(:show_quick_start_modal, true)
     |> assign(:quick_start_options, quick_start_options)}
  end

  defp get_enhanced_quick_start_options do
    %{
      traditional: [
        %{
          key: "novel_draft",
          title: "Novel Draft",
          description: "Chapter-based novel with character development",
          format: "novel",
          intent: "entertain",
          icon: "book-open",
          features: ["Character sheets", "Plot tracking", "Chapter organization"]
        },
        %{
          key: "screenplay_standard",
          title: "Screenplay",
          description: "Industry-standard screenplay format",
          format: "screenplay",
          intent: "entertain",
          icon: "film",
          features: ["Scene breakdown", "Character dialogue", "Action lines"]
        },
        %{
          key: "business_case_study",
          title: "Case Study",
          description: "Professional business analysis",
          format: "case_study",
          intent: "persuade",
          icon: "chart-bar",
          features: ["Data visualization", "Executive summary", "Stakeholder collaboration"]
        },
        %{
          key: "blog_article",
          title: "Blog Article",
          description: "SEO-optimized blog post or article",
          format: "blog_series",
          intent: "educate",
          icon: "newspaper",
          features: ["SEO optimization", "Social preview", "Publishing tools"]
        }
      ],
      frestyl_originals: [
        %{
          key: "live_story_interactive",
          title: "Live Story",
          description: "Real-time collaborative storytelling with audience",
          format: "live_story",
          intent: "entertain",
          icon: "broadcast",
          features: ["Live audience interaction", "Real-time branching", "Streaming integration"],
          requires_collaboration: true
        },
        %{
          key: "voice_sketch_tutorial",
          title: "Voice Sketch",
          description: "Voice narration with synchronized drawing",
          format: "voice_sketch",
          intent: "educate",
          icon: "microphone",
          features: ["Audio-visual sync", "Drawing tools", "Voice narration"],
          requires_audio: true
        },
        %{
          key: "audio_portfolio_showcase",
          title: "Audio Portfolio",
          description: "Interactive audio-first portfolio experience",
          format: "audio_portfolio",
          intent: "showcase",
          icon: "volume-up",
          features: ["Spatial audio", "Interactive navigation", "Immersive experience"],
          requires_audio: true
        },
        %{
          key: "narrative_beats_music",
          title: "Narrative Beats",
          description: "Music production driven by story structure",
          format: "narrative_beats",
          intent: "entertain",
          icon: "musical-note",
          features: ["Beat machine", "Story sync", "Musical storytelling"],
          requires_audio: true
        }
      ]
    }
  end


  defp create_story_with_editor_state(socket, format, intent, options \\ %{}) do
    user = socket.assigns.current_user

    # Get or create personal workspace
    case Frestyl.Channels.get_or_create_personal_workspace(user) do
      {:ok, personal_workspace} ->
        # Create session for story collaboration
        session_params = %{
          "title" => "Writing: #{Map.get(options, :title, get_default_title(format, intent))}",
          "session_type" => "regular",
          "channel_id" => personal_workspace.id,
          "creator_id" => user.id,
          "status" => "active"
        }

        case Frestyl.Sessions.create_session(session_params) do
          {:ok, session} ->
            # Create story with session reference
            story_params = %{
              title: Map.get(options, :title, get_default_title(format, intent)),
              story_type: format,
              intent_category: intent,
              session_id: session.id,
              creation_source: "story_engine_hub",
              created_by_id: user.id,
              collaboration_mode: Map.get(options, :collaboration_mode, "owner_only"),
              editor_preferences: build_editor_preferences(format, intent, options),
              initial_section_config: build_initial_section_config(format, intent),
              template_data: Map.get(options, :template, get_default_template(format, intent))
            }

            case Frestyl.Stories.create_story_for_engine(story_params, user) do
              {:ok, story} ->
                editor_url = build_editor_url_with_state(story, format, intent, options)

                {:noreply, socket
                |> put_flash(:info, "Story created! Opening editor...")
                |> redirect(to: editor_url)}

              {:error, story_changeset} ->
                {:noreply, put_flash(socket, :error, "Failed to create story. Please try again.")}
            end

          {:error, session_changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to create workspace session.")}
        end

      {:error, workspace_error} ->
        {:noreply, put_flash(socket, :error, "Failed to create personal workspace.")}
    end
  end

  @doc """
  Determine collaboration mode based on format and options
  """
  defp determine_collaboration_mode(format, options) do
    cond do
      Map.get(options, :collaboration_enabled, false) -> "story_development"
      format in ["screenplay", "case_study"] -> "business_workflow"
      format in ["novel", "short_story"] -> "narrative_workshop"
      true -> "content_review"
    end
  end

  @doc """
  Get initial workspace state for story creation
  """
  defp get_initial_story_workspace_state(format) do
    %{
      story: %{
        outline: %{template: get_default_outline_template(format), sections: []},
        characters: [],
        world_bible: %{},
        timeline: %{events: []},
        comments: [],
        format_specific: get_format_specific_state(format)
      },
      text: %{
        version: 0,
        content: "",
        pending_operations: [],
        cursors: %{},
        selection: nil
      },
      collaboration: %{
        active_users: [],
        last_activity: DateTime.utc_now()
      }
    }
  end

  defp get_format_specific_state(format) do
    case format do
      "novel" -> %{
        word_count_target: 50000,
        chapter_structure: "traditional",
        pov_style: "third_person"
      }
      "screenplay" -> %{
        page_target: 120,
        format_style: "feature",
        scene_numbering: true
      }
      "case_study" -> %{
        stakeholders: [],
        metrics: [],
        timeline_required: true
      }
      _ -> %{}
    end
  end


  defp get_default_outline_template(format) do
    case format do
      "novel" -> "three_act"
      "screenplay" -> "screenplay_structure"
      "case_study" -> "problem_solution"
      _ -> "basic"
    end
  end

  defp build_editor_preferences(format, intent, options) do
    base_preferences = %{
      auto_save_interval: 2000,
      ai_assistance_level: get_ai_assistance_level(intent),
      collaboration_enabled: Map.get(options, :collaboration_enabled, false),
      focus_mode: get_default_focus_mode(format),
      distraction_free: Map.get(options, :focus_mode) == "distraction_free"
    }

    format_preferences = case format do
      "novel" -> %{
        show_character_panel: true,
        show_plot_tracker: true,
        word_count_target: 50000,
        section_type: "chapter",
        manuscript_mode: true,
        auto_chapter_breaks: true
      }

      "screenplay" -> %{
        formatting_mode: "industry_standard",
        show_scene_breakdown: true,
        page_target: 120,
        section_type: "scene",
        screenplay_formatting: true,
        character_list_visible: true
      }

      "case_study" -> %{
        show_data_panel: true,
        template_guided: true,
        structure_hints: true,
        section_type: "section",
        business_mode: true,
        stakeholder_tracking: true
      }

      "blog_series" -> %{
        seo_mode: true,
        show_publishing_panel: true,
        social_preview: true,
        section_type: "post",
        keyword_tracking: true,
        readability_score: true
      }

      _ -> %{section_type: "section"}
    end

    Map.merge(base_preferences, format_preferences)
  end

    defp build_initial_section_config(format, intent) do
    case {format, intent} do
      {"novel", _} ->
        %{
          sections: [
            %{title: "Chapter 1", type: "chapter", order: 1, placeholder: get_novel_placeholder()}
          ]
        }
      {"screenplay", _} ->
        %{
          sections: [
            %{title: "FADE IN:", type: "scene", order: 1, placeholder: get_screenplay_placeholder()}
          ]
        }
      {"case_study", "persuade"} ->
        %{
          sections: [
            %{title: "Executive Summary", type: "section", order: 1, placeholder: get_case_study_placeholder()},
            %{title: "Problem Statement", type: "section", order: 2, placeholder: ""},
            %{title: "Solution Overview", type: "section", order: 3, placeholder: ""},
            %{title: "Results & Impact", type: "section", order: 4, placeholder: ""}
          ]
        }
      {"blog_series", "educate"} ->
        %{
          sections: [
            %{title: "Introduction", type: "post", order: 1, placeholder: get_blog_placeholder()}
          ]
        }
      {"live_story", _} ->
        %{
          sections: [
            %{title: "Opening Scene", type: "segment", order: 1, placeholder: get_live_story_placeholder()}
          ]
        }
      {"voice_sketch", _} ->
        %{
          sections: [
            %{title: "Sketch 1", type: "sketch", order: 1, placeholder: get_voice_sketch_placeholder()}
          ]
        }
      {"audio_portfolio", _} ->
        %{
          sections: [
            %{title: "Welcome Experience", type: "experience", order: 1, placeholder: get_audio_portfolio_placeholder()}
          ]
        }
      {"narrative_beats", _} ->
        %{
          sections: [
            %{title: "Opening Beat", type: "beat", order: 1, placeholder: get_narrative_beats_placeholder()}
          ]
        }
      _ ->
        %{
          sections: [
            %{title: "Getting Started", type: "section", order: 1, placeholder: get_default_placeholder()}
          ]
        }
    end
  end


  defp build_editor_url_with_state(story, format, intent, options) do
    base_url = ~p"/stories/#{story.id}/edit"

    # Core parameters
    params = [
      {"mode", determine_editor_mode_from_format(format)},
      {"intent", intent},
      {"source", "hub_creation"},
      {"format", format}
    ]

    # Add conditional parameters
    params = params
    |> maybe_add_param("template", Map.get(options, :template_key))
    |> maybe_add_param("focus", Map.get(options, :focus_mode))
    |> maybe_add_param("collab", Map.get(options, :collaboration_enabled, false))
    |> maybe_add_param("welcome", "true")
    |> maybe_add_param("setup", "guided")

    build_url_with_params(base_url, params)
  end

  defp build_format_metadata(format, intent, options) do
    base_metadata = %{
      creation_timestamp: DateTime.utc_now(),
      hub_intent: intent,
      creation_flow: "story_engine"
    }

    format_metadata = case format do
      "screenplay" -> %{
        industry_standard: true,
        page_numbering: true,
        scene_headings: true
      }
      "blog_series" -> %{
        seo_enabled: true,
        social_sharing: true,
        publication_ready: false
      }
      _ -> %{}
    end

    Map.merge(base_metadata, format_metadata)
  end


  defp determine_editor_mode_from_format(format) do
    case format do
      format when format in ["novel", "screenplay", "poetry"] -> "manuscript"
      format when format in ["case_study", "data_story", "report"] -> "business"
      format when format in ["blog_series", "article"] -> "publishing"
      format when format in ["live_story", "interactive"] -> "experimental"
      _ -> "standard"
    end
  end

  defp build_continuation_url(story) do
    base_url = ~p"/stories/#{story.id}/edit"

    params = [
      {"mode", determine_editor_mode_from_story(story)},
      {"continue", "true"}
    ]

    params = params
    |> maybe_add_param("section", get_current_section_id(story))
    |> maybe_add_param("focus", get_user_focus_preference(story))

    build_url_with_params(base_url, params)
  end

  defp determine_editor_mode_from_story(story) do
    cond do
      story.story_type in ["novel", "screenplay"] -> "manuscript"
      story.story_type in ["case_study", "data_story"] -> "business"
      story.story_type in ["live_story", "narrative_beats"] -> "experimental"
      true -> "standard"
    end
  end

  defp get_current_section_id(story) do
    case story.sections do
      [] -> nil
      [first | _] -> first.id
      sections when is_list(sections) ->
        sections
        |> Enum.max_by(& &1.updated_at, DateTime, fn -> List.first(sections) end)
        |> Map.get(:id)
    end
  end

  defp get_user_focus_preference(_story), do: nil

  defp get_ai_assistance_level(intent) do
    case intent do
      "entertain" -> "creative"
      "educate" -> "structured"
      "persuade" -> "analytical"
      "showcase" -> "polished"
      _ -> "balanced"
    end
  end

  defp get_default_focus_mode(format) do
    case format do
      format when format in ["novel", "screenplay"] -> "immersive"
      format when format in ["case_study", "report"] -> "analytical"
      format when format in ["live_story", "voice_sketch"] -> "collaborative"
      _ -> "balanced"
    end
  end

  # URL building helpers
  defp maybe_add_param(params, _key, nil), do: params
  defp maybe_add_param(params, _key, false), do: params
  defp maybe_add_param(params, key, value), do: params ++ [{key, to_string(value)}]


  defp build_url_with_params(base_url, []), do: base_url
  defp build_url_with_params(base_url, params) do
    query_string = params
    |> Enum.map(fn {key, value} -> "#{key}=#{URI.encode(value)}" end)
    |> Enum.join("&")

    "#{base_url}?#{query_string}"
  end

  # Placeholder content functions
  defp get_novel_placeholder do
    "Once upon a time...\n\nBegin your chapter here. Develop your characters, set the scene, and advance your plot."
  end

  defp get_screenplay_placeholder do
    "FADE IN:\n\nEXT. LOCATION - DAY\n\nAction line describing what we see...\n\nCHARACTER\nDialogue goes here."
  end

  defp get_case_study_placeholder do
    "Executive Summary\n\nProvide a brief overview of the key findings, recommendations, and business impact..."
  end

  defp get_blog_placeholder do
    "# Blog Post Title\n\nStart with a compelling introduction that hooks your readers..."
  end

  defp get_live_story_placeholder do
    "Welcome to your live story! This opening scene will be shared with your audience in real-time.\n\nSet the stage for interactive storytelling..."
  end

  defp get_voice_sketch_placeholder do
    "Voice Sketch Notes\n\nDescribe what you'll be drawing while you narrate. This will help synchronize your voice with visual elements..."
  end

  defp get_audio_portfolio_placeholder do
    "Welcome Experience\n\nDescribe the immersive audio journey visitors will experience. Consider spatial audio and interactive elements..."
  end

  defp get_narrative_beats_placeholder do
    "Opening Beat\n\nDescribe the musical and narrative elements for this beat. How does the story drive the musical composition?"
  end

  defp get_default_placeholder do
    "Start writing your story here...\n\nUse the sidebar tools to organize your thoughts and collaborate with others."
  end

  defp get_default_title(format, intent) do
    case {format, intent} do
      {"novel", _} -> "Untitled Novel"
      {"screenplay", _} -> "Untitled Screenplay"
      {"case_study", _} -> "New Case Study"
      {"blog_series", _} -> "New Blog Series"
      {format, _} -> "New #{String.capitalize(format)}"
    end
  end

  defp get_default_template(format, intent) do
    # This could be expanded with your existing template system
    %{
      format: format,
      intent: intent,
      structure: get_default_outline_template(format)
    }
  end

  defp get_template_by_key(template_key) do
    try do
      Templates.get_by_key(template_key) || get_default_template_for_key(template_key)
    rescue
      UndefinedFunctionError ->
        get_default_template_for_key(template_key)
    end
  end

  defp get_default_template_for_key(template_key) do
    %{
      key: template_key,
      format: "article",
      default_intent: "educate",
      default_title: "New Story",
      recommended_focus_mode: "balanced"
    }
  end

  # Helper functions with error handling
  defp get_formats_for_intent(intent_key, user_tier) when is_binary(intent_key) do
    try do
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
    rescue
      UndefinedFunctionError ->
        get_default_formats_for_intent(intent_key, user_tier)
    end
  end

  defp get_formats_for_intent(nil, _user_tier), do: %{}

  defp get_default_formats_for_intent(intent_key, user_tier) do
    formats = case intent_key do
      "entertain" -> ["short_story", "novel", "screenplay", "interactive"]
      "educate" -> ["blog_series", "case_study", "tutorial", "guide"]
      "persuade" -> ["case_study", "marketing_story", "testimonial"]
      "document" -> ["memoir", "journal", "report", "documentation"]
      "personal_professional" -> ["memoir", "case_study", "blog_series"]
      _ -> ["short_story", "blog_series", "case_study"]
    end

    available_formats = case user_tier do
      "creator" -> formats
      "professional" -> formats
      _ -> Enum.take(formats, 2)
    end

    available_formats
    |> Enum.map(fn format ->
      {format, %{
        key: format,
        name: String.capitalize(String.replace(format, "_", " ")),
        required_tier: if(format in ["novel", "screenplay"], do: "creator", else: nil)
      }}
    end)
    |> Enum.into(%{})
  end

  defp load_recent_stories(user_id) do
    try do
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
    rescue
      _ -> []
    end
  end

  defp calculate_story_stats(user_id) do
    try do
      stories = Stories.list_user_stories(user_id)
      %{
        total_stories: length(stories),
        active_collaborations: count_active_collaborations(stories),
        average_completion: calculate_average_completion(stories),
        words_this_week: calculate_words_this_week(stories)
      }
    rescue
      _ -> %{total_stories: 0, active_collaborations: 0, average_completion: 0, words_this_week: 0}
    end
  end

  defp load_open_collaborations do
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
        []
    end
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

  defp get_current_user_from_session(session) do
    case session["user_token"] do
      nil -> session["current_user"]
      token -> Frestyl.Accounts.get_user_by_session_token(token)
    end
  end

  # Handle info functions
  @impl true
  def handle_info({:story_created, story}, socket) do
    updated_recent = load_recent_stories(socket.assigns.current_user.id)
    updated_stats = calculate_story_stats(socket.assigns.current_user.id)

    {:noreply, socket
     |> assign(:recent_stories, updated_recent)
     |> assign(:story_stats, updated_stats)}
  end

  @impl true
  def handle_info({:story_updated, story}, socket) do
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
    handle_event("create_story_with_format", %{"format" => format}, socket)
  end

  @impl true
  def handle_info({:show_upgrade_modal, required_tier}, socket) do
    upgrade_info = Frestyl.Features.TierManager.get_upgrade_suggestion(
      socket.assigns.user_tier,
      :format_access
    )

    {:noreply, push_event(socket, "show_upgrade_modal", upgrade_info)}
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
end
