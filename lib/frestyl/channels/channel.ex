defmodule Frestyl.Channels.Channel do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query # Added for `from` in detect_channel_type example

  schema "channels" do
    field :name, :string
    field :description, :string
    field :visibility, :string, default: "public"
    field :slug, :string
    field :archived, :boolean, default: false
    field :archived_at, :utc_datetime

    # Financial/Fundraising fields
    field :fundraising_enabled, :boolean, default: false
    field :enable_transparency_mode, :boolean, default: false
    field :funding_goal, :decimal
    field :current_funding, :decimal, default: Decimal.new("0.00")
    field :funding_deadline, :date
    field :icon_url, :string
    field :transparency_level, :string, default: "basic" # "basic", "detailed", "full"
    field :metadata, :map, default: %{}

    # Customization Fields (NEWLY ADDED)
    field :hero_image_url, :string
    field :color_scheme, :map, default: %{"primary" => "#8B5CF6", "secondary" => "#00D4FF", "accent" => "#FF0080"}
    field :tagline, :string
    field :channel_type, :string, default: "general" # e.g., "general", "gaming", "music", "education"
    field :show_live_activity, :boolean, default: true
    field :auto_detect_type, :boolean, default: false # For automatically setting channel_type
    field :social_links, :map, default: %{} # e.g., %{twitter: "...", youtube: "..."}
    field :featured_content, {:array, :map}, default: [] # [{type: "session", id: 1}, {type: "media", id: 5}]

    # Media settings fields (NEWLY ADDED, assuming these are distinct from customization)
    field :active_branding_media_id, :integer # Foreign key to a MediaItem
    field :active_presentation_media_id, :integer
    field :active_performance_media_id, :integer

    belongs_to :owner, Frestyl.Accounts.User, foreign_key: :owner_id # This uses owner_id
    belongs_to :archived_by, Frestyl.Accounts.User

    # Associations for active media (NEWLY ADDED, if you want to preload the actual media items)
    # You'll need MediaItem schema defined for these to work
    # belongs_to :active_branding_media, Frestyl.Media.MediaItem, foreign_key: :active_branding_media_id
    # belongs_to :active_presentation_media, Frestyl.Media.MediaItem, foreign_key: :active_presentation_media_id
    # belongs_to :active_performance_media, Frestyl.Media.MediaItem, foreign_key: :active_performance_media_id


    has_many :channel_memberships, Frestyl.Channels.ChannelMembership
    has_many :members, through: [:channel_memberships, :user]
    has_many :media_files, Frestyl.Media.MediaFile # Assuming this is for files *uploaded to* the channel

    timestamps()
  end

  @doc false
  def changeset(channel, attrs) do
    channel
    |> cast(attrs, [
      :name, :slug, :description, :visibility, :archived, :archived_at, :archived_by_id, :owner_id, # Add :user_id here
      :fundraising_enabled, :enable_transparency_mode, :funding_goal,
      :current_funding, :funding_deadline, :transparency_level,
      # New fields:
      :hero_image_url, :color_scheme, :tagline, :channel_type, :show_live_activity,
      :auto_detect_type, :social_links, :featured_content,
      :active_branding_media_id, :active_presentation_media_id, :active_performance_media_id
    ])
    |> validate_required([:name, :slug, :owner_id])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_length(:description, max: 500)
    |> validate_inclusion(:visibility, ["public", "private", "invite_only"])
    |> validate_inclusion(:transparency_level, ["basic", "detailed", "full"])
    |> validate_inclusion(:channel_type, ~w(
      general gaming music education
      portfolio_voice_over portfolio_writing portfolio_music portfolio_design
      portfolio_quarterly_update portfolio_feedback portfolio_collaboration
    )a)
    #|> Ecto.Changeset.cast_embed(:color_scheme, with: &color_scheme_changeset/2) # Validate color_scheme map
    #|> Ecto.Changeset.cast_embedding(:social_links, with: &social_links_changeset/2) # Validate social_links map
    #|> Ecto.Changeset.cast_embeds(:featured_content, with: &featured_content_changeset/2) # Validate featured_content array of maps
    |> validate_funding_fields()
    |> validate_archived_fields()
    |> validate_inclusion(:channel_type, ~w(
      general gaming music education
      portfolio_voice_over portfolio_writing portfolio_music portfolio_design
      portfolio_quarterly_update portfolio_feedback portfolio_collaboration
    )a)
  end

  @doc """
  Changeset specifically for archiving/unarchiving.
  """
  def archive_changeset(channel, attrs) do
    channel
    |> cast(attrs, [:archived, :archived_at, :archived_by_id])
    |> validate_archived_fields()
  end

  @doc """
  Changeset for media settings fields.
  """
  def media_changeset(channel, attrs) do
    channel
    |> cast(attrs, [
      :active_branding_media_id,
      :active_presentation_media_id,
      :active_performance_media_id
    ])
  end

  @doc """
  Changeset for overall media settings.
  (If you have other global media settings beyond just active media IDs)
  """
  def media_settings_changeset(channel, attrs) do
    # Assuming this changeset is for other media-related settings
    # For now, it will just use the general changeset if no specific media settings are needed
    changeset(channel, attrs)
  end


  @doc """
  Changeset for channel customization fields.
  """
  def customization_changeset(channel, attrs) do
    channel
    |> cast(attrs, [
      :hero_image_url, :color_scheme, :tagline, :channel_type, :show_live_activity,
      :auto_detect_type, :social_links, :fundraising_enabled, :fundraising_goal,
      :fundraising_description # This was mentioned in get_channel_customization
    ])
    |> Ecto.Changeset.cast_embedding(:color_scheme, with: &color_scheme_changeset/2)
    |> Ecto.Changeset.cast_embedding(:social_links, with: &social_links_changeset/2)
    |> validate_inclusion(:channel_type, ~w(general gaming music education)a) # Example types
    |> validate_funding_fields() # Re-apply if fundraising can be set here
  end

  @doc """
  Enhanced channel type detection including portfolio collaboration types.
  """
  def detect_channel_type(channel_id) do
    channel = Frestyl.Repo.get(Channel, channel_id)

    cond do
      String.contains?(channel.name || "", "Voice") ||
      String.contains?(channel.description || "", "voice") ||
      String.contains?(channel.description || "", "introduction") ->
        "portfolio_voice_over"

      String.contains?(channel.name || "", "Writing") ||
      String.contains?(channel.description || "", "writing") ||
      String.contains?(channel.description || "", "description") ->
        "portfolio_writing"

      String.contains?(channel.name || "", "Music") ||
      String.contains?(channel.description || "", "music") ||
      String.contains?(channel.description || "", "background") ->
        "portfolio_music"

      String.contains?(channel.name || "", "Update") ||
      String.contains?(channel.description || "", "quarterly") ||
      String.contains?(channel.description || "", "progress") ->
        "portfolio_quarterly_update"

      String.contains?(channel.description || "", "portfolio") ->
        "portfolio_collaboration"

      true ->
        "general"
    end
  end

    @doc """
  Create a channel (basic channel creation function)
  """
  def create_channel(attrs \\ %{}) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Update a channel
  """
  def update_channel(%__MODULE__{} = channel, attrs) do
    channel
    |> changeset(attrs)
    |> Repo.update()
  end

  def create_portfolio_enhancement_channel(portfolio, enhancement_type, user) do
    channel_name = "#{portfolio.title} - #{String.capitalize(enhancement_type)}"

    channel_attrs = %{
      name: channel_name,
      description: get_enhancement_description(enhancement_type),
      channel_type: "portfolio_#{enhancement_type}",
      visibility: "private",
      user_id: user.id,
      # Link to portfolio for context
      metadata: %{
        portfolio_id: portfolio.id,
        enhancement_type: enhancement_type,
        created_from: "portfolio_editor"
      }
    }

    with {:ok, channel} <- create_channel(channel_attrs),
        :ok <- setup_channel_tools(channel, enhancement_type) do
      {:ok, channel}
    end
  end

  defp update_channel_tools(channel, tools_config) do
    # Update the channel with the new tools configuration
    channel
    |> Ecto.Changeset.change(tools: tools_config)
    |> Repo.update()
  end

  # Add portfolio-specific tool configurations
  defp setup_channel_tools(channel, "story_enhancement") do
    tools_config = get_portfolio_channel_tools("portfolio_writing")
    update_channel_tools(channel, tools_config)
  end

  defp setup_channel_tools(channel, "music_integration") do
    tools_config = get_portfolio_channel_tools("portfolio_music")
    update_channel_tools(channel, tools_config)
  end

  defp get_enhancement_description(enhancement_type) do
    case enhancement_type do
      :ai_assistant -> "AI-powered assistant for enhanced productivity"
      :analytics -> "Advanced analytics and reporting tools"
      :automation -> "Automated workflow and task management"
      :collaboration -> "Enhanced team collaboration features"
      :integration -> "Third-party service integrations"
      _ -> "Enhanced channel functionality"
    end
  end

  @doc """
  Gets the default Studio tools configuration for portfolio channel types.
  """
  def get_portfolio_channel_tools(channel_type) do
    case channel_type do
      "portfolio_voice_over" -> %{
        primary_tools: ["recorder", "script", "chat"],
        secondary_tools: ["effects", "mixer"],
        collaboration_mode: "audio_with_script",
        default_layout: %{
          left_dock: ["script"],
          right_dock: ["chat"],
          bottom_dock: ["recorder"],
          floating: [],
          minimized: ["effects", "mixer"]
        },
        welcome_message: "Welcome to your voice introduction workspace! Use the script editor to write your intro, then record it with professional quality."
      }

      "portfolio_writing" -> %{
        primary_tools: ["editor", "chat"],
        secondary_tools: ["recorder"],
        collaboration_mode: "content_review",
        default_layout: %{
          left_dock: ["editor"],
          right_dock: ["chat"],
          bottom_dock: [],
          floating: [],
          minimized: ["recorder"]
        },
        welcome_message: "Collaborate with writers to enhance your portfolio content! Share drafts and get real-time feedback."
      }

      "portfolio_music" -> %{
        primary_tools: ["recorder", "mixer", "effects"],
        secondary_tools: ["chat", "editor"],
        collaboration_mode: "multimedia_creation",
        default_layout: %{
          left_dock: ["mixer"],
          right_dock: ["chat"],
          bottom_dock: ["recorder", "effects"],
          floating: [],
          minimized: ["editor"]
        },
        welcome_message: "Create custom background music for your portfolio! Collaborate with musicians to set the perfect mood."
      }

      "portfolio_design" -> %{
        primary_tools: ["visual", "chat"],
        secondary_tools: ["editor"],
        collaboration_mode: "content_review",
        default_layout: %{
          left_dock: ["visual"],
          right_dock: ["chat"],
          bottom_dock: [],
          floating: [],
          minimized: ["editor"]
        },
        welcome_message: "Design and refine your portfolio's visual elements with collaborative feedback!"
      }

      "portfolio_quarterly_update" -> %{
        primary_tools: ["editor", "chat"],
        secondary_tools: ["recorder"],
        collaboration_mode: "content_review",
        default_layout: %{
          left_dock: ["editor"],
          right_dock: ["chat"],
          bottom_dock: [],
          floating: [],
          minimized: ["recorder"]
        },
        welcome_message: "Time to update your portfolio! Document your recent achievements and get feedback on your progress."
      }

      "portfolio_feedback" -> %{
        primary_tools: ["chat", "editor"],
        secondary_tools: ["recorder"],
        collaboration_mode: "content_review",
        default_layout: %{
          left_dock: ["editor"],
          right_dock: ["chat"],
          bottom_dock: [],
          floating: [],
          minimized: ["recorder"]
        },
        welcome_message: "Get comprehensive feedback on your portfolio! Invite mentors, peers, or industry experts to review and suggest improvements."
      }

      _ -> %{
        primary_tools: ["chat", "editor"],
        secondary_tools: ["recorder"],
        collaboration_mode: "content_review",
        default_layout: %{
          left_dock: ["editor"],
          right_dock: ["chat"],
          bottom_dock: [],
          floating: [],
          minimized: ["recorder"]
        },
        welcome_message: "Welcome to your portfolio collaboration workspace!"
      }
    end
  end

  @doc """
  Gets channel limits based on account type for portfolio channels.
  """
  def get_portfolio_channel_limits(subscription_tier) do
    case subscription_tier do
      "storyteller" -> %{
        max_portfolio_channels: 2,
        max_collaborators_per_channel: 3,
        can_create_quarterly_updates: false,
        can_invite_external_collaborators: false
      }

      "professional" -> %{
        max_portfolio_channels: 10,
        max_collaborators_per_channel: 10,
        can_create_quarterly_updates: true,
        can_invite_external_collaborators: true
      }

      "business" -> %{
        max_portfolio_channels: :unlimited,
        max_collaborators_per_channel: :unlimited,
        can_create_quarterly_updates: true,
        can_invite_external_collaborators: true
      }

      _ -> %{
        max_portfolio_channels: 1,
        max_collaborators_per_channel: 2,
        can_create_quarterly_updates: false,
        can_invite_external_collaborators: false
      }
    end
  end

    @doc """
  Generate enhancement channel name
  """
  defp generate_enhancement_channel_name(portfolio, enhancement_type) do
    enhancement_names = %{
      "voice_over" => "Voice Introduction",
      "writing" => "Content Enhancement",
      "design" => "Visual Design",
      "music" => "Background Music",
      "quarterly_update" => "Portfolio Update",
      "feedback" => "Portfolio Review"
    }

    enhancement_name = Map.get(enhancement_names, enhancement_type, "Enhancement")
    "#{portfolio.title} - #{enhancement_name}"
  end

  @doc """
  Generate enhancement description
  """
  defp generate_enhancement_description(enhancement_type) do
    case enhancement_type do
      "voice_over" ->
        "Collaborative workspace for creating professional voice introductions"
      "writing" ->
        "Collaborative content enhancement and writing improvement workspace"
      "design" ->
        "Visual design collaboration space for portfolio improvements"
      "music" ->
        "Music creation and audio enhancement collaboration workspace"
      "quarterly_update" ->
        "Quarterly portfolio update and progress documentation space"
      "feedback" ->
        "Professional feedback and portfolio review collaboration space"
      _ ->
        "Portfolio enhancement collaboration workspace"
    end
  end

  @doc """
  Calculate portfolio quality score
  """
  defp calculate_portfolio_quality_score(portfolio) do
    # Use the existing helper function or implement basic scoring
    sections = Portfolios.list_portfolio_sections(portfolio.id)

    # Basic scoring algorithm
    content_score = calculate_content_score(sections)
    visual_score = calculate_visual_score(portfolio, sections)
    engagement_score = calculate_engagement_score(portfolio)

    total_score = content_score + visual_score + engagement_score

    %{
      total: min(total_score, 100),
      content: content_score,
      visual: visual_score,
      engagement: engagement_score,
      breakdown: %{
        has_voice_intro: has_voice_introduction?(portfolio),
        content_quality: content_score,
        visual_consistency: visual_score > 20,
        professional_media: has_media_content?(sections),
        engagement_elements: engagement_score / 10
      }
    }
  end

  @doc """
  Get enhancement duration estimate
  """
  defp get_enhancement_duration(enhancement_type) do
    case enhancement_type do
      "voice_over" -> "30-45 minutes"
      "writing" -> "2-3 hours"
      "design" -> "1-2 hours"
      "music" -> "45-60 minutes"
      "quarterly_update" -> "1-2 hours"
      "feedback" -> "45 minutes"
      _ -> "1-2 hours"
    end
  end

  @doc """
  Get enhancement milestones
  """
  defp get_enhancement_milestones(enhancement_type) do
    case enhancement_type do
      "voice_over" -> [
        %{name: "Script Preparation", percentage: 25},
        %{name: "Recording Session", percentage: 60},
        %{name: "Audio Editing", percentage: 85},
        %{name: "Integration", percentage: 100}
      ]
      "writing" -> [
        %{name: "Content Audit", percentage: 20},
        %{name: "Outline Creation", percentage: 40},
        %{name: "Writing & Revision", percentage: 80},
        %{name: "Final Polish", percentage: 100}
      ]
      "design" -> [
        %{name: "Design Analysis", percentage: 25},
        %{name: "Concept Development", percentage: 50},
        %{name: "Visual Implementation", percentage: 85},
        %{name: "Final Refinement", percentage: 100}
      ]
      "music" -> [
        %{name: "Music Selection", percentage: 30},
        %{name: "Audio Recording", percentage: 70},
        %{name: "Mixing & Editing", percentage: 90},
        %{name: "Integration", percentage: 100}
      ]
      "quarterly_update" -> [
        %{name: "Progress Review", percentage: 25},
        %{name: "Content Update", percentage: 65},
        %{name: "Quality Check", percentage: 85},
        %{name: "Publishing", percentage: 100}
      ]
      "feedback" -> [
        %{name: "Review Setup", percentage: 20},
        %{name: "Feedback Collection", percentage: 60},
        %{name: "Analysis & Discussion", percentage: 85},
        %{name: "Action Planning", percentage: 100}
      ]
      _ -> [
        %{name: "Planning", percentage: 25},
        %{name: "Execution", percentage: 75},
        %{name: "Completion", percentage: 100}
      ]
    end
  end

  @doc """
  Suggest final polish when enhancement is 75% complete
  """
  defp suggest_final_polish(channel) do
    enhancement_type = get_in(channel.metadata, ["enhancement_type"])
    portfolio_id = get_in(channel.metadata, ["portfolio_id"])

    # Create suggestion for final polish
    polish_suggestion = %{
      type: "final_polish",
      enhancement_type: enhancement_type,
      portfolio_id: portfolio_id,
      title: "Ready for Final Polish",
      description: "Your #{enhancement_type} enhancement is almost complete. Time for final review and polish!",
      actions: get_final_polish_actions(enhancement_type)
    }

    # Broadcast to channel participants
    broadcast_to_channel(channel.id, "final_polish_suggestion", polish_suggestion)
  end

  @doc """
  Calculate session duration from channel metadata
  """
  defp calculate_session_duration(channel) do
    started_at = get_in(channel.metadata, ["started_at"])

    if started_at do
      case DateTime.from_iso8601(started_at) do
        {:ok, start_time, _} ->
          DateTime.diff(DateTime.utc_now(), start_time, :minute)
        _ ->
          0
      end
    else
      0
    end
  end

  @doc """
  Consider channel transition after completion
  """
  defp consider_channel_transition(channel, status) do
    case status do
      :completed ->
        # Archive the enhancement channel or convert to feedback channel
        transition_options = %{
          archive: "Archive the enhancement channel",
          convert_to_feedback: "Convert to ongoing feedback channel",
          create_showcase: "Create portfolio showcase channel"
        }

        # For now, archive the channel
        update_channel(channel, %{
          archived: true,
          archived_at: DateTime.utc_now(),
          metadata: Map.put(channel.metadata || %{}, "completion_status", "completed")
        })

      :paused ->
        update_channel(channel, %{
          metadata: Map.put(channel.metadata || %{}, "status", "paused")
        })

      _ ->
        :ok
    end
  end

  @doc """
  Broadcast enhancement suggestions to user
  """
  defp broadcast_enhancement_suggestions(user_id, portfolio_id, suggestions) do
    message = %{
      type: "enhancement_suggestions",
      portfolio_id: portfolio_id,
      suggestions: suggestions,
      timestamp: DateTime.utc_now()
    }

    # Use Phoenix PubSub to broadcast to user
    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "user:#{user_id}",
      {:enhancement_suggestions, message}
    )
  end

  # ============================================================================
  # HELPER FUNCTIONS FOR QUALITY SCORING
  # ============================================================================

  defp calculate_content_score(sections) do
    # Score based on number and completeness of sections
    base_score = length(sections) * 8

    # Bonus for content quality
    content_bonus = Enum.reduce(sections, 0, fn section, acc ->
      content_length = get_section_content_length(section)
      if content_length > 100, do: acc + 5, else: acc
    end)

    min(base_score + content_bonus, 40)
  end

  defp calculate_visual_score(portfolio, sections) do
    score = 0

    # Hero image
    score = if portfolio.hero_image_url, do: score + 10, else: score

    # Theme consistency
    score = if portfolio.theme, do: score + 8, else: score

    # Media content in sections
    media_count = Enum.count(sections, &has_media_content?/1)
    media_score = min(media_count * 4, 12)

    score + media_score
  end

  defp calculate_engagement_score(portfolio) do
    score = 0

    # Social links
    score = if has_social_links?(portfolio), do: score + 8, else: score

    # Contact information
    score = if has_contact_info?(portfolio), do: score + 7, else: score

    # Interactive elements (mock check)
    score = if has_interactive_elements?(portfolio), do: score + 5, else: score

    score
  end

  defp get_section_content_length(section) do
    case section.content do
      nil -> 0
      content when is_map(content) ->
        content
        |> Map.values()
        |> Enum.reduce(0, fn value, acc ->
          if is_binary(value), do: acc + String.length(value), else: acc
        end)
      _ -> 0
    end
  end

  defp has_voice_introduction?(portfolio) do
    # Check if portfolio has voice introduction
    # This would check for voice files in sections or metadata
    false # Mock implementation
  end

  defp has_media_content?(section) do
    content = section.content || %{}
    Map.has_key?(content, "images") ||
    Map.has_key?(content, "media") ||
    Map.has_key?(content, "hero_image")
  end

  defp has_social_links?(portfolio) do
    social_links = portfolio.social_links || %{}
    map_size(social_links) > 0
  end

  defp has_contact_info?(portfolio) do
    contact_info = portfolio.contact_info || %{}
    map_size(contact_info) > 0
  end

  defp has_interactive_elements?(portfolio) do
    # Mock check for interactive elements
    false
  end

  defp get_final_polish_actions(enhancement_type) do
    case enhancement_type do
      "voice_over" -> [
        "Review audio quality",
        "Check synchronization",
        "Test on different devices",
        "Final integration"
      ]
      "writing" -> [
        "Proofread content",
        "Check grammar and spelling",
        "Verify consistency",
        "Final formatting"
      ]
      "design" -> [
        "Review visual consistency",
        "Check responsive design",
        "Optimize images",
        "Final styling"
      ]
      "music" -> [
        "Audio level check",
        "Test with portfolio",
        "Optimize file size",
        "Final integration"
      ]
      _ -> [
        "Final review",
        "Quality check",
        "Test functionality",
        "Publish changes"
      ]
    end
  end

  defp broadcast_to_channel(channel_id, event_type, data) do
    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "channel:#{channel_id}",
      {event_type, data}
    )
  end

  # ============================================================================
  # ENHANCED ENHANCEMENT FUNCTIONS (from original artifact)
  # ============================================================================

  @doc """
  Enhanced portfolio channel creation with completion tracking
  """
  def create_portfolio_enhancement_channel(portfolio, enhancement_type, user) do
    channel_attrs = %{
      name: generate_enhancement_channel_name(portfolio, enhancement_type),
      description: generate_enhancement_description(enhancement_type),
      channel_type: "portfolio_#{enhancement_type}",
      visibility: "private",
      user_id: user.id,
      featured_content: [%{
        "type" => "portfolio",
        "id" => portfolio.id,
        "enhancement_type" => enhancement_type,
        "started_at" => DateTime.utc_now()
      }],
      # Portfolio-specific metadata
      metadata: %{
        portfolio_id: portfolio.id,
        enhancement_type: enhancement_type,
        quality_score_at_start: calculate_portfolio_quality_score(portfolio),
        expected_duration: get_enhancement_duration(enhancement_type),
        milestone_targets: get_enhancement_milestones(enhancement_type)
      }
    }

    create_channel(channel_attrs)
  end

  @doc """
  Track portfolio enhancement completion progress
  """
  def update_enhancement_progress(channel, progress_data) do
    current_metadata = channel.metadata || %{}

    updated_metadata = Map.merge(current_metadata, %{
      progress_percentage: progress_data.percentage,
      milestones_completed: progress_data.milestones,
      last_activity: DateTime.utc_now(),
      collaborator_contributions: progress_data.contributions
    })

    # Check for completion triggers
    cond do
      progress_data.percentage >= 100 ->
        trigger_enhancement_completion(channel, progress_data)
      progress_data.percentage >= 75 ->
        suggest_final_polish(channel)
      true ->
        :ok
    end

    update_channel(channel, %{metadata: updated_metadata})
  end

  defp trigger_enhancement_completion(channel, progress_data) do
    portfolio_id = get_in(channel.metadata, ["portfolio_id"])
    enhancement_type = get_in(channel.metadata, ["enhancement_type"])

    # Update portfolio with enhancement completion
    Portfolios.mark_enhancement_completed(portfolio_id, enhancement_type, %{
      completed_at: DateTime.utc_now(),
      channel_id: channel.id,
      final_score: progress_data.final_quality_score,
      collaborators: progress_data.collaborators
    })

    # Trigger new enhancement suggestions
    suggest_next_enhancements(portfolio_id, enhancement_type)

    # Archive enhancement channel or convert to feedback channel
    consider_channel_transition(channel, :completed)

    # Track completion for billing/analytics
    Billing.UsageTracker.track_usage(channel.user.account, :enhancement_completion, 1, %{
      enhancement_type: enhancement_type,
      duration_minutes: calculate_session_duration(channel),
      collaborator_count: length(progress_data.collaborators || [])
    })
  end

  defp suggest_next_enhancements(portfolio_id, completed_enhancement_type) do
    portfolio = Portfolios.get_portfolio(portfolio_id)
    updated_quality_score = calculate_portfolio_quality_score(portfolio)

    # Smart suggestion logic based on what was just completed
    next_suggestions = case completed_enhancement_type do
      "voice_over" ->
        if updated_quality_score.visual < 70, do: ["design"], else: ["music"]
      "writing" ->
        ["voice_over", "design"]
      "design" ->
        if updated_quality_score.engagement < 60, do: ["music", "voice_over"], else: ["quarterly_update"]
      "music" ->
        ["quarterly_update", "feedback"]
      _ ->
        []
    end

    # Send suggestions to user
    broadcast_enhancement_suggestions(portfolio.user_id, portfolio_id, next_suggestions)
  end

  defp trigger_enhancement_completion(channel, progress_data) do
    portfolio_id = get_in(channel.metadata, ["portfolio_id"])
    enhancement_type = get_in(channel.metadata, ["enhancement_type"])

    # Update portfolio with enhancement completion
    Portfolios.mark_enhancement_completed(portfolio_id, enhancement_type, %{
      completed_at: DateTime.utc_now(),
      channel_id: channel.id,
      final_score: progress_data.final_quality_score,
      collaborators: progress_data.collaborators
    })

    # Trigger new enhancement suggestions
    suggest_next_enhancements(portfolio_id, enhancement_type)

    # Archive enhancement channel or convert to feedback channel
    consider_channel_transition(channel, :completed)

    # Track completion for billing/analytics
    Billing.UsageTracker.track_usage(channel.user.account, :enhancement_completion, 1, %{
      enhancement_type: enhancement_type,
      duration_minutes: calculate_session_duration(channel),
      collaborator_count: length(progress_data.collaborators)
    })
  end

  defp suggest_next_enhancements(portfolio_id, completed_enhancement_type) do
    portfolio = Portfolios.get_portfolio(portfolio_id)
    updated_quality_score = calculate_portfolio_quality_score(portfolio)

    # Smart suggestion logic based on what was just completed
    next_suggestions = case completed_enhancement_type do
      "voice_over" ->
        if updated_quality_score.visual < 70, do: ["design"], else: ["music"]
      "writing" ->
        ["voice_over", "design"]
      "design" ->
        if updated_quality_score.engagement < 60, do: ["music", "voice_over"], else: ["quarterly_update"]
      "music" ->
        ["quarterly_update", "feedback"]
      _ ->
        []
    end

    # Send suggestions to user
    broadcast_enhancement_suggestions(portfolio.user_id, portfolio_id, next_suggestions)
  end

  # --- Embedded Changesets ---
  # For `color_scheme` map
  defp color_scheme_changeset(changeset, attrs) do
    changeset
    |> cast(attrs, [:primary, :secondary, :accent])
    # Add validation for color format if needed, e.g., Regex.match?(~r/^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$/, color_string)
  end

  # For `social_links` map
  defp social_links_changeset(changeset, attrs) do
    changeset
    |> cast(attrs, [:twitter, :youtube, :instagram, :facebook, :website]) # Example social links
    # Add URL validation here if needed
  end

  # For `featured_content` array of maps
  defp featured_content_changeset(changeset, attrs) do
    changeset
    |> cast(attrs, [:type, :id]) # Assuming each featured item has a type (e.g., "session", "media") and an ID
    |> validate_required([:type, :id])
    |> validate_inclusion(:type, ~w(session media post)a) # Example types
  end

  # --- Custom Validations ---

  # Custom validation for funding fields
  defp validate_funding_fields(changeset) do
    fundraising_enabled = get_change(changeset, :fundraising_enabled) || get_field(changeset, :fundraising_enabled)

    if fundraising_enabled do
      changeset
      |> validate_required([:funding_goal])
      |> validate_number(:funding_goal, greater_than: 0)
      |> validate_number(:current_funding, greater_than_or_equal_to: 0)
      # Validate funding_deadline if required when enabled
      # |> validate_required(:funding_deadline)
    else
      changeset
    end
  end

  # Custom validation to ensure archived_at is set when archived is true
  # and cleared when archived is false.
  defp validate_archived_fields(changeset) do
    archived = get_change(changeset, :archived) || get_field(changeset, :archived)
    archived_at = get_change(changeset, :archived_at) || get_field(changeset, :archived_at)
    archived_by_id = get_change(changeset, :archived_by_id) || get_field(changeset, :archived_by_id)

    cond do
      # If becoming archived and archived_at is not set
      archived && is_nil(archived_at) ->
        put_change(changeset, :archived_at, DateTime.utc_now() |> DateTime.truncate(:second))
        # archived_by_id should be handled by the calling function (e.g., Channels.archive_channel)

      # If becoming unarchived and archived_at or archived_by_id are set
      !archived && (archived_at || archived_by_id) ->
        changeset
        |> put_change(:archived_at, nil)
        |> put_change(:archived_by_id, nil)

      true ->
        changeset
    end
  end

  # --- Auto-detection Logic (Example) ---
  @doc """
  Detects channel type based on its content or activity (example).
  """
  def detect_channel_type(channel_id) do
    # This is a placeholder for your actual logic.
    # You might analyze messages, sessions, or associated tags.
    # For demonstration, let's say:
    # If the channel has many messages, it's 'active'.
    # If it has specific keywords in description, it's 'education'.
    # Otherwise, 'general'.

    channel_messages_count = Frestyl.Repo.aggregate(from m in Frestyl.Channels.Message,
                                                     where: m.channel_id == ^channel_id,
                                                     select: count(m.id))

    channel = Frestyl.Repo.get(Channel, channel_id)

    cond do
      channel_messages_count > 100 -> "active_community"
      String.contains?(channel.description || "", "learning") -> "education"
      true -> "general"
    end
  end


end
