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

    belongs_to :user, Frestyl.Accounts.User # This is the owner of the channel
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
      :name, :description, :visibility, :archived, :archived_at, :archived_by_id, :user_id, # Add :user_id here
      :fundraising_enabled, :enable_transparency_mode, :funding_goal,
      :current_funding, :funding_deadline, :transparency_level,
      # New fields:
      :hero_image_url, :color_scheme, :tagline, :channel_type, :show_live_activity,
      :auto_detect_type, :social_links, :featured_content,
      :active_branding_media_id, :active_presentation_media_id, :active_performance_media_id
    ])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_length(:description, max: 500)
    |> validate_inclusion(:visibility, ["public", "private", "invite_only"])
    |> validate_inclusion(:transparency_level, ["basic", "detailed", "full"])
    |> validate_inclusion(:channel_type, ~w(general gaming music education)a) # Example types, adjust as needed
    |> Ecto.Changeset.cast_embedding(:color_scheme, with: &color_scheme_changeset/2) # Validate color_scheme map
    |> Ecto.Changeset.cast_embedding(:social_links, with: &social_links_changeset/2) # Validate social_links map
    |> Ecto.Changeset.cast_embeds(:featured_content, with: &featured_content_changeset/2) # Validate featured_content array of maps
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
