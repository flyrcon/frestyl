# lib/frestyl/live_story.ex
defmodule Frestyl.LiveStory do
  @moduledoc """
  Context for Live Story - real-time collaborative storytelling with audience interaction.

  This context handles live streaming storytelling, audience voting, branching narratives,
  multi-narrator collaboration, and session recording.
  """

  import Ecto.Query, warn: false
  alias Frestyl.Repo

  alias Frestyl.LiveStory.{
    Session,
    StoryBranch,
    AudienceInteraction,
    NarratorCollaboration,
    LiveStoryEvent,
    SessionArchive,
    AudienceAnalytics,
    ChoiceTemplate,
    LiveChatMessage,
    StreamingIntegration
  }

  alias Frestyl.Accounts.User
  alias Phoenix.PubSub

  # ============================================================================
  # SESSION MANAGEMENT
  # ============================================================================

  @doc """
  Creates a new Live Story session.
  """
  def create_session(attrs, %User{} = user, studio_session_id) do
    session_attrs = Map.merge(attrs, %{
      "session_id" => studio_session_id,
      "created_by_id" => user.id,
      "story_concept" => initialize_story_concept(),
      "current_narrative_state" => initialize_narrative_state(),
      "streaming_config" => initialize_streaming_config(),
      "audience_interaction_settings" => initialize_audience_settings(),
      "recording_settings" => initialize_recording_settings()
    })

    case %Session{}
         |> Session.changeset(session_attrs)
         |> Repo.insert() do
      {:ok, session} ->
        # Add creator as primary narrator
        add_narrator(session.id, user.id, "primary", %{
          "can_control_story" => true,
          "can_moderate_chat" => true,
          "can_manage_session" => true
        })

        # Initialize main story branch
        create_main_story_branch(session)

        # Broadcast session created
        broadcast_session_event(session, :session_created)

        {:ok, session}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Gets a Live Story session by ID.
  """
  def get_session!(id) do
    Session
    |> preload([
      :story_branches,
      :narrator_collaborations,
      :audience_interactions,
      :live_story_events,
      :session_archives,
      :live_chat_messages
    ])
    |> Repo.get!(id)
  end

  @doc """
  Gets a session by studio session ID.
  """
  def get_session_by_studio_session(studio_session_id) do
    Session
    |> Session.for_session(studio_session_id)
    |> preload([
      :story_branches,
      :narrator_collaborations,
      :audience_interactions
    ])
    |> Repo.one()
  end

  @doc """
  Updates a Live Story session.
  """
  def update_session(%Session{} = session, attrs) do
    case session
         |> Session.changeset(attrs)
         |> Repo.update() do
      {:ok, updated_session} ->
        broadcast_session_event(updated_session, :session_updated)
        {:ok, updated_session}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Lists sessions for a user.
  """
  def list_user_sessions(user_id) do
    Session
    |> Session.for_user(user_id)
    |> order_by([s], desc: s.updated_at)
    |> Repo.all()
  end

  @doc """
  Lists public live sessions.
  """
  def list_public_live_sessions do
    Session
    |> Session.public_sessions()
    |> Session.live_sessions()
    |> order_by([s], desc: s.actual_start_time)
    |> limit(20)
    |> Repo.all()
  end

  # ============================================================================
  # SESSION STATE MANAGEMENT
  # ============================================================================

  @doc """
  Starts a live story session.
  """
  def start_session(session_id) do
    session = get_session!(session_id)

    case session.session_state do
      "preparing" ->
        update_session(session, %{
          "session_state" => "live",
          "actual_start_time" => DateTime.utc_now()
        })

      state ->
        {:error, "Cannot start session in state: #{state}"}
    end
  end

  @doc """
  Pauses a live story session.
  """
  def pause_session(session_id) do
    session = get_session!(session_id)

    case session.session_state do
      "live" ->
        update_session(session, %{"session_state" => "paused"})

      state ->
        {:error, "Cannot pause session in state: #{state}"}
    end
  end

  @doc """
  Ends a live story session.
  """
  def end_session(session_id) do
    session = get_session!(session_id)

    case session.session_state do
      state when state in ["live", "paused"] ->
        duration = calculate_session_duration(session)

        case update_session(session, %{
               "session_state" => "ended",
               "end_time" => DateTime.utc_now(),
               "duration_minutes" => duration
             }) do
          {:ok, updated_session} ->
            # Start archive processing if enabled
            if session.archive_enabled do
              start_archive_processing(updated_session)
            end

            {:ok, updated_session}

          error ->
            error
        end

      state ->
        {:error, "Cannot end session in state: #{state}"}
    end
  end

  # ============================================================================
  # STORY BRANCHING
  # ============================================================================

  @doc """
  Creates a story branch for audience choices.
  """
  def create_story_branch(session_id, attrs) do
    attrs = Map.put(attrs, "live_story_session_id", session_id)

    case %StoryBranch{}
         |> StoryBranch.changeset(attrs)
         |> Repo.insert() do
      {:ok, branch} ->
        broadcast_session_event(session_id, {:branch_created, branch})
        {:ok, branch}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Activates a story branch based on audience voting.
  """
  def activate_story_branch(branch_id) do
    branch = Repo.get!(StoryBranch, branch_id)
    session_id = branch.live_story_session_id

    # Deactivate other branches
    from(sb in StoryBranch,
      where: sb.live_story_session_id == ^session_id
    )
    |> Repo.update_all(set: [is_active: false])

    # Activate this branch
    case branch
         |> StoryBranch.changeset(%{
           "is_active" => true,
           "selection_timestamp" => DateTime.utc_now()
         })
         |> Repo.update() do
      {:ok, updated_branch} ->
        # Update session narrative state
        update_narrative_state_from_branch(session_id, updated_branch)

        # Create story event
        create_story_event(session_id, %{
          "event_type" => "choice_point",
          "event_data" => %{
            "selected_branch" => updated_branch.id,
            "branch_name" => updated_branch.branch_name,
            "votes" => updated_branch.audience_votes
          },
          "triggered_by" => "audience_vote"
        })

        broadcast_session_event(session_id, {:branch_activated, updated_branch})
        {:ok, updated_branch}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Lists active story branches for voting.
  """
  def list_active_branches(session_id) do
    StoryBranch
    |> where([sb], sb.live_story_session_id == ^session_id and sb.is_active == false)
    |> where([sb], not is_nil(sb.parent_branch_id)) # Only choice branches, not main branch
    |> order_by([sb], desc: sb.audience_votes)
    |> Repo.all()
  end

  # ============================================================================
  # AUDIENCE INTERACTION
  # ============================================================================

  @doc """
  Records audience interaction (vote, comment, suggestion).
  """
  def record_audience_interaction(session_id, attrs) do
    attrs = Map.merge(attrs, %{
      "live_story_session_id" => session_id,
      "timestamp" => DateTime.utc_now()
    })

    case %AudienceInteraction{}
         |> AudienceInteraction.changeset(attrs)
         |> Repo.insert() do
      {:ok, interaction} ->
        # Process interaction based on type
        process_interaction(interaction)

        broadcast_session_event(session_id, {:audience_interaction, interaction})
        {:ok, interaction}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Processes audience votes for story branches.
  """
  def cast_vote(session_id, branch_id, user_info) do
    # Check if user has already voted for this choice point
    existing_vote = get_existing_vote(session_id, branch_id, user_info)

    case existing_vote do
      nil ->
        # Cast new vote
        vote_attrs = %{
          "interaction_type" => "vote",
          "story_branch_id" => branch_id,
          "interaction_data" => %{"vote_type" => "branch_selection"},
          "weight" => calculate_vote_weight(user_info)
        }
        |> merge_user_info(user_info)

        case record_audience_interaction(session_id, vote_attrs) do
          {:ok, interaction} ->
            # Update branch vote count
            increment_branch_votes(branch_id, interaction.weight)
            {:ok, interaction}

          error ->
            error
        end

      _existing ->
        {:error, "User has already voted for this choice point"}
    end
  end

  @doc """
  Gets voting results for current choice point.
  """
  def get_voting_results(session_id) do
    branches = list_active_branches(session_id)
    total_votes = Enum.sum(Enum.map(branches, & &1.audience_votes))

    results = Enum.map(branches, fn branch ->
      percentage = if total_votes > 0, do: branch.audience_votes / total_votes * 100, else: 0

      %{
        branch_id: branch.id,
        branch_name: branch.branch_name,
        votes: branch.audience_votes,
        percentage: Float.round(percentage, 1)
      }
    end)

    %{
      total_votes: total_votes,
      results: results,
      voting_open: length(branches) > 0
    }
  end

  # ============================================================================
  # NARRATOR COLLABORATION
  # ============================================================================

  @doc """
  Adds a narrator to the session.
  """
  def add_narrator(session_id, user_id, role, permissions \\ %{}) do
    attrs = %{
      "live_story_session_id" => session_id,
      "user_id" => user_id,
      "narrator_role" => role,
      "permissions" => permissions,
      "last_activity_at" => DateTime.utc_now()
    }

    case %NarratorCollaboration{}
         |> NarratorCollaboration.changeset(attrs)
         |> Repo.insert() do
      {:ok, collaboration} ->
        broadcast_session_event(session_id, {:narrator_added, collaboration})
        {:ok, collaboration}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Updates narrator speaking status.
  """
  def update_narrator_speaking(session_id, user_id, is_speaking) do
    case get_narrator_collaboration(session_id, user_id) do
      nil ->
        {:error, :not_found}

      collaboration ->
        case collaboration
             |> NarratorCollaboration.changeset(%{
               "is_currently_speaking" => is_speaking,
               "last_activity_at" => DateTime.utc_now()
             })
             |> Repo.update() do
          {:ok, updated_collaboration} ->
            broadcast_session_event(session_id, {:narrator_speaking_changed, updated_collaboration})
            {:ok, updated_collaboration}

          {:error, changeset} ->
            {:error, changeset}
        end
    end
  end

  @doc """
  Lists narrators for a session.
  """
  def list_narrators(session_id) do
    NarratorCollaboration
    |> where([nc], nc.live_story_session_id == ^session_id)
    |> preload(:user)
    |> order_by([nc], nc.speaking_order)
    |> Repo.all()
  end

  # ============================================================================
  # LIVE CHAT
  # ============================================================================

  @doc """
  Sends a chat message.
  """
  def send_chat_message(session_id, attrs) do
    attrs = Map.merge(attrs, %{
      "live_story_session_id" => session_id,
      "timestamp" => DateTime.utc_now()
    })

    case %LiveChatMessage{}
         |> LiveChatMessage.changeset(attrs)
         |> Repo.insert() do
      {:ok, message} ->
        broadcast_session_event(session_id, {:chat_message, message})
        {:ok, message}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Gets recent chat messages.
  """
  def get_recent_chat_messages(session_id, limit \\ 50) do
    LiveChatMessage
    |> where([lcm], lcm.live_story_session_id == ^session_id)
    |> where([lcm], lcm.is_moderated == false)
    |> order_by([lcm], desc: lcm.timestamp)
    |> limit(^limit)
    |> preload(:user)
    |> Repo.all()
    |> Enum.reverse()
  end

  # ============================================================================
  # ANALYTICS AND INSIGHTS
  # ============================================================================

  @doc """
  Records audience analytics.
  """
  def record_audience_analytics(session_id, user_info) do
    attrs = %{
      "live_story_session_id" => session_id,
      "join_timestamp" => DateTime.utc_now()
    }
    |> merge_user_info(user_info)

    %AudienceAnalytics{}
    |> AudienceAnalytics.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates audience analytics when user leaves.
  """
  def update_audience_analytics_on_leave(session_id, user_info) do
    case get_audience_analytics(session_id, user_info) do
      nil ->
        {:error, :not_found}

      analytics ->
        duration = DateTime.diff(DateTime.utc_now(), analytics.join_timestamp, :second)
        engagement_score = calculate_engagement_score(analytics)

        analytics
        |> AudienceAnalytics.changeset(%{
          "leave_timestamp" => DateTime.utc_now(),
          "session_duration" => duration,
          "engagement_score" => engagement_score
        })
        |> Repo.update()
    end
  end

  @doc """
  Gets session analytics summary.
  """
  def get_session_analytics(session_id) do
    session = get_session!(session_id)

    analytics = AudienceAnalytics
    |> where([aa], aa.live_story_session_id == ^session_id)
    |> Repo.all()

    interactions = AudienceInteraction
    |> where([ai], ai.live_story_session_id == ^session_id)
    |> Repo.all()

    %{
      total_audience: length(analytics),
      average_duration: calculate_average_duration(analytics),
      total_interactions: length(interactions),
      interaction_breakdown: group_interactions_by_type(interactions),
      engagement_score: calculate_overall_engagement(analytics),
      peak_audience: calculate_peak_audience(session_id),
      session_duration: session.duration_minutes || 0
    }
  end

  # ============================================================================
  # CHOICE TEMPLATES
  # ============================================================================

  @doc """
  Creates a choice template.
  """
  def create_choice_template(attrs, %User{} = user) do
    attrs = Map.put(attrs, "created_by_id", user.id)

    %ChoiceTemplate{}
    |> ChoiceTemplate.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Lists public choice templates.
  """
  def list_public_choice_templates do
    ChoiceTemplate
    |> where([ct], ct.is_public == true)
    |> order_by([ct], desc: ct.community_rating)
    |> Repo.all()
  end

  @doc """
  Gets choice templates by genre.
  """
  def get_choice_templates_by_genre(genre) do
    ChoiceTemplate
    |> where([ct], ^genre in ct.genre_tags)
    |> where([ct], ct.is_public == true)
    |> order_by([ct], desc: ct.usage_count)
    |> Repo.all()
  end

  # ============================================================================
  # STREAMING INTEGRATION
  # ============================================================================

  @doc """
  Configures streaming for a session.
  """
  def configure_streaming(session_id, platform, config) do
    case StreamingIntegration.configure_streaming(get_session!(session_id), platform, config) do
      {:ok, streaming_config} ->
        update_session(get_session!(session_id), %{"streaming_config" => streaming_config})

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Gets supported streaming platforms.
  """
  def get_streaming_platforms do
    StreamingIntegration.get_supported_platforms()
  end

  # ============================================================================
  # PRIVATE FUNCTIONS
  # ============================================================================

  defp initialize_story_concept do
    %{
      "theme" => "",
      "genre" => "",
      "setting" => "",
      "main_characters" => [],
      "target_audience" => "general"
    }
  end

  defp initialize_narrative_state do
    %{
      "current_scene" => "",
      "active_characters" => [],
      "story_progress" => 0.0,
      "narrative_tension" => 0.5,
      "audience_mood" => "neutral"
    }
  end

  defp initialize_streaming_config do
    %{
      "platform" => "native",
      "quality" => "720p",
      "enable_chat" => true,
      "enable_voting" => true,
      "moderation_level" => "moderate"
    }
  end

  defp initialize_audience_settings do
    %{
      "voting_enabled" => true,
      "comments_enabled" => true,
      "suggestions_enabled" => true,
      "anonymous_participation" => true,
      "vote_time_limit" => 60,
      "moderation_required" => false
    }
  end

  defp initialize_recording_settings do
    %{
      "record_video" => true,
      "record_audio" => true,
      "record_chat" => true,
      "auto_archive" => true,
      "public_archive" => false
    }
  end

  defp create_main_story_branch(session) do
    create_story_branch(session.id, %{
      "branch_name" => "Main Story",
      "branch_description" => "The main narrative thread",
      "is_active" => true,
      "story_content" => %{"type" => "main_branch"}
    })
  end

  defp calculate_session_duration(session) do
    if session.actual_start_time do
      DateTime.diff(DateTime.utc_now(), session.actual_start_time, :minute)
    else
      0
    end
  end

  defp start_archive_processing(session) do
    # Start background job to process session archives
    # This would integrate with your job processing system
    Task.start(fn ->
      process_session_archives(session)
    end)
  end

  defp process_session_archives(session) do
    # Create different types of archives
    archive_types = ["transcript", "session_data", "chat_log"]

    Enum.each(archive_types, fn type ->
      create_session_archive(session.id, type)
    end)
  end

  defp create_session_archive(session_id, archive_type) do
    attrs = %{
      "live_story_session_id" => session_id,
      "archive_type" => archive_type,
      "processing_status" => "processing"
    }

    %SessionArchive{}
    |> SessionArchive.changeset(attrs)
    |> Repo.insert()
  end

  defp update_narrative_state_from_branch(session_id, branch) do
    session = get_session!(session_id)

    updated_state = Map.merge(session.current_narrative_state, %{
      "current_branch" => branch.id,
      "last_choice" => branch.branch_name,
      "choice_timestamp" => DateTime.utc_now()
    })

    update_session(session, %{"current_narrative_state" => updated_state})
  end

  defp create_story_event(session_id, attrs) do
    attrs = Map.merge(attrs, %{
      "live_story_session_id" => session_id,
      "timestamp" => DateTime.utc_now()
    })

    %LiveStoryEvent{}
    |> LiveStoryEvent.changeset(attrs)
    |> Repo.insert()
  end

  defp process_interaction(%AudienceInteraction{interaction_type: "vote"} = interaction) do
    # Update branch vote count
    if interaction.story_branch_id do
      increment_branch_votes(interaction.story_branch_id, interaction.weight)
    end
  end

  defp process_interaction(%AudienceInteraction{interaction_type: "comment"} = interaction) do
    # Update audience analytics
    if interaction.user_id do
      update_user_interaction_count(interaction.live_story_session_id, interaction.user_id, :comments)
    end
  end

  defp process_interaction(_interaction), do: :ok

  defp increment_branch_votes(branch_id, weight) do
    from(sb in StoryBranch, where: sb.id == ^branch_id)
    |> Repo.update_all(inc: [audience_votes: weight])
  end

  defp update_user_interaction_count(session_id, user_id, type) do
    case get_audience_analytics_by_user(session_id, user_id) do
      nil ->
        :ok

      analytics ->
        field = case type do
          :comments -> :comments_made
          :votes -> :votes_cast
          :interactions -> :interaction_count
        end

        from(aa in AudienceAnalytics, where: aa.id == ^analytics.id)
        |> Repo.update_all(inc: [{field, 1}])
    end
  end

  defp get_existing_vote(session_id, branch_id, user_info) do
    query = AudienceInteraction
    |> where([ai], ai.live_story_session_id == ^session_id)
    |> where([ai], ai.story_branch_id == ^branch_id)
    |> where([ai], ai.interaction_type == "vote")

    query = case user_info do
      %{"user_id" => user_id} when not is_nil(user_id) ->
        where(query, [ai], ai.user_id == ^user_id)

      %{"user_identifier" => identifier} ->
        where(query, [ai], ai.user_identifier == ^identifier)

      _ ->
        where(query, [ai], false) # No match for invalid user_info
    end

    Repo.one(query)
  end

  defp calculate_vote_weight(user_info) do
    # Basic vote weighting - could be enhanced with user reputation, etc.
    case user_info do
      %{"user_id" => user_id} when not is_nil(user_id) -> 1.0 # Registered users
      _ -> 0.8 # Anonymous users get slightly less weight
    end
  end

  defp merge_user_info(attrs, %{"user_id" => user_id}) when not is_nil(user_id) do
    Map.merge(attrs, %{
      "user_id" => user_id,
      "is_anonymous" => false
    })
  end

  defp merge_user_info(attrs, %{"user_identifier" => identifier}) do
    Map.merge(attrs, %{
      "user_identifier" => identifier,
      "is_anonymous" => true
    })
  end

  defp merge_user_info(attrs, _), do: attrs

  defp get_narrator_collaboration(session_id, user_id) do
    NarratorCollaboration
    |> where([nc], nc.live_story_session_id == ^session_id and nc.user_id == ^user_id)
    |> Repo.one()
  end

  defp get_audience_analytics(session_id, user_info) do
    query = AudienceAnalytics
    |> where([aa], aa.live_story_session_id == ^session_id)

    query = case user_info do
      %{"user_id" => user_id} when not is_nil(user_id) ->
        where(query, [aa], aa.user_id == ^user_id)

      %{"user_identifier" => identifier} ->
        where(query, [aa], aa.user_identifier == ^identifier)

      _ ->
        where(query, [aa], false)
    end

    Repo.one(query)
  end

  defp get_audience_analytics_by_user(session_id, user_id) do
    AudienceAnalytics
    |> where([aa], aa.live_story_session_id == ^session_id and aa.user_id == ^user_id)
    |> Repo.one()
  end

  defp calculate_engagement_score(analytics) do
    # Simple engagement scoring based on interactions
    base_score = 0.0
    base_score = base_score + (analytics.interaction_count * 0.1)
    base_score = base_score + (analytics.votes_cast * 0.2)
    base_score = base_score + (analytics.comments_made * 0.15)

    # Duration factor
    if analytics.session_duration > 0 do
      duration_factor = min(analytics.session_duration / 3600, 1.0) # Max 1 hour for full score
      base_score * duration_factor
    else
      base_score
    end
    |> min(1.0) # Cap at 1.0
  end

  defp calculate_average_duration(analytics_list) do
    if length(analytics_list) > 0 do
      total_duration = Enum.sum(Enum.map(analytics_list, & &1.session_duration || 0))
      round(total_duration / length(analytics_list))
    else
      0
    end
  end

  defp group_interactions_by_type(interactions) do
    interactions
    |> Enum.group_by(& &1.interaction_type)
    |> Enum.map(fn {type, list} -> {type, length(list)} end)
    |> Enum.into(%{})
  end

  defp calculate_overall_engagement(analytics_list) do
    if length(analytics_list) > 0 do
      total_engagement = Enum.sum(Enum.map(analytics_list, & &1.engagement_score))
      Float.round(total_engagement / length(analytics_list), 2)
    else
      0.0
    end
  end

  defp calculate_peak_audience(session_id) do
    # This would require time-series data tracking
    # For now, return total unique audience
    AudienceAnalytics
    |> where([aa], aa.live_story_session_id == ^session_id)
    |> Repo.aggregate(:count, :id)
  end

  defp broadcast_session_event(session_id, event) when is_binary(session_id) do
    PubSub.broadcast(Frestyl.PubSub, "live_story:#{session_id}", event)
  end

  defp broadcast_session_event(%Session{} = session, event) do
    broadcast_session_event(session.id, event)
  end
end
