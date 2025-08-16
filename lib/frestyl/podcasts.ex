# lib/frestyl/podcasts.ex
defmodule Frestyl.Podcasts do
  @moduledoc """
  Podcast creation and management context.
  Integrates with existing session and media infrastructure.
  """

  import Ecto.Query, warn: false
  alias Frestyl.Repo
  alias Frestyl.Podcasts.{Show, Episode, Guest, Analytics}
  alias Frestyl.{Sessions, Media, Accounts}
  alias Frestyl.Features.{FeatureGate, TierManager}
  alias Phoenix.PubSub

  @doc """
  Creates a podcast show with tier-aware features.
  """
  def create_show(attrs, user) do
    tier = TierManager.get_account_tier(user)

    # Validate tier permissions
    case validate_show_creation(attrs, tier) do
      {:ok, validated_attrs} ->
        %Show{}
        |> Show.changeset(Map.put(validated_attrs, :creator_id, user.id))
        |> Repo.insert()
        |> case do
          {:ok, show} ->
            setup_show_infrastructure(show, user, tier)
            {:ok, show}
          error -> error
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp validate_show_creation(attrs, tier) do
    limits = TierManager.get_tier_limits(tier)

    cond do
      not FeatureGate.feature_available?(tier, :podcast_creation) ->
        {:error, :tier_insufficient}

      attrs[:distribution_platforms] && length(attrs[:distribution_platforms]) > Map.get(limits, :max_distribution_platforms, 3) ->
        {:error, :too_many_platforms}

      true ->
        {:ok, attrs}
    end
  end

  defp setup_show_infrastructure(show, user, tier) do
    # Create RSS feed
    create_rss_feed(show)

    # Set up analytics tracking
    Analytics.initialize_show_tracking(show.id)

    # Create default episode template
    create_default_episode_template(show, tier)

    # Initialize collaboration workspace
    Frestyl.Collaboration.create_workspace(show.id, user.id, :podcast_show)
  end

  @doc """
  Creates a new episode with recording session integration.
  """
  def create_episode(show_id, attrs, user) do
    show = get_show!(show_id)
    tier = TierManager.get_account_tier(user)

    case validate_episode_creation(show, attrs, user, tier) do
      {:ok, validated_attrs} ->
        %Episode{}
        |> Episode.changeset(Map.merge(validated_attrs, %{
          show_id: show_id,
          creator_id: user.id,
          status: "draft"
        }))
        |> Repo.insert()
        |> case do
          {:ok, episode} ->
            # Create recording session for episode
            create_episode_recording_session(episode, user)
            {:ok, episode}
          error -> error
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp create_episode_recording_session(episode, user) do
    session_params = %{
      title: "Recording: #{episode.title}",
      description: "Podcast recording session for #{episode.title}",
      channel_id: episode.show.channel_id,
      creator_id: user.id,
      host_id: user.id,
      session_type: "podcast_recording",
      status: "scheduled",
      metadata: %{
        episode_id: episode.id,
        podcast_template: true,
        recording_format: "podcast"
      }
    }

    case Sessions.create_session(session_params) do
      {:ok, session} ->
        # Link episode to recording session
        episode
        |> Episode.changeset(%{recording_session_id: session.id})
        |> Repo.update()

        {:ok, session}

      error -> error
    end
  end

  @doc """
  Starts live podcast recording with guest management.
  """
  def start_live_recording(episode_id, host_user, options \\ []) do
    episode = get_episode_with_session!(episode_id)

    # Initialize specialized podcast session
    case Frestyl.Features.SessionManager.create_session(
      episode.recording_session_id,
      :podcast_recording,
      host_user,
      podcast_options(episode, options)
    ) do
      {:ok, session_manager} ->
        # Set up podcast-specific features
        setup_podcast_recording_features(episode, session_manager)

        # Notify guests if any
        notify_scheduled_guests(episode)

        {:ok, session_manager}

      error -> error
    end
  end

  defp podcast_options(episode, options) do
    Keyword.merge([
      audio_template: :podcast,
      auto_transcription: true,
      chapter_detection: true,
      noise_reduction: true,
      guest_management: true
    ], options)
  end

  defp setup_podcast_recording_features(episode, session_manager) do
    session_id = episode.recording_session_id

    # Enable podcast-specific audio processing
    setup_podcast_audio_chain(session_id)

    # Start transcription service
    start_episode_transcription(episode.id, session_id)

    # Initialize chapter detection
    start_chapter_detection(episode.id, session_id)
  end

  @doc """
  Processes completed recording into podcast episode.
  """
  def process_recording_to_episode(episode_id) do
    episode = get_episode_with_recording!(episode_id)

    # Get recording data from session
    case get_session_recording_data(episode.recording_session_id) do
      {:ok, recording_data} ->
        # Process audio for podcast
        process_podcast_audio(episode, recording_data)

        # Generate transcription
        generate_episode_transcription(episode, recording_data)

        # Create chapters
        generate_episode_chapters(episode, recording_data)

        # Update episode status
        update_episode_status(episode, "processed")

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp process_podcast_audio(episode, recording_data) do
    # Apply podcast-specific audio processing
    processed_audio = recording_data
    |> apply_noise_reduction()
    |> apply_eq_preset(:podcast_voice)
    |> apply_compression(:broadcast)
    |> normalize_levels()
    |> generate_chapters_from_audio()

    # Save processed audio as episode media
    create_episode_media_file(episode, processed_audio)
  end

  @doc """
  Publishes episode to configured distribution platforms.
  """
  def publish_episode(episode_id, user) do
    episode = get_episode_with_show!(episode_id)
    tier = TierManager.get_account_tier(user)

    # Validate publishing permissions
    if can_publish_episode?(episode, user, tier) do
      # Update RSS feed
      update_rss_feed(episode.show)

      # Distribute to platforms
      distribute_to_platforms(episode, episode.show.distribution_platforms)

      # Update episode status
      update_episode_status(episode, "published")

      # Track analytics
      Analytics.track_episode_published(episode.id)

      {:ok, episode}
    else
      {:error, :insufficient_permissions}
    end
  end

  defp distribute_to_platforms(episode, platforms) do
    Enum.each(platforms, fn platform ->
      Task.start(fn ->
        case platform do
          "spotify" -> distribute_to_spotify(episode)
          "apple_podcasts" -> distribute_to_apple(episode)
          "google_podcasts" -> distribute_to_google(episode)
          "youtube" -> distribute_to_youtube(episode)
          _ -> :skip
        end
      end)
    end)
  end

  @doc """
  Manages podcast guests and remote recording.
  """
  def invite_guest(episode_id, guest_attrs, inviter) do
    %Guest{}
    |> Guest.changeset(Map.merge(guest_attrs, %{
      episode_id: episode_id,
      invited_by: inviter.id,
      status: "invited"
    }))
    |> Repo.insert()
    |> case do
      {:ok, guest} ->
        send_guest_invitation(guest)
        {:ok, guest}
      error -> error
    end
  end

  defp send_guest_invitation(guest) do
    # Send email invitation with recording session link
    episode = get_episode!(guest.episode_id)

    invitation_data = %{
      guest: guest,
      episode: episode,
      recording_link: generate_guest_recording_link(guest),
      instructions: generate_guest_instructions(episode)
    }

    # Send via email service
    Frestyl.Emails.send_podcast_guest_invitation(invitation_data)

    # Track invitation
    Analytics.track_guest_invited(guest.id)
  end

  @doc """
  Gets podcast analytics and insights.
  """
  def get_show_analytics(show_id, timeframe \\ :month) do
    Analytics.get_show_analytics(show_id, timeframe)
  end

  def get_episode_analytics(episode_id) do
    Analytics.get_episode_analytics(episode_id)
  end

  # Private helper functions

  defp get_show!(id), do: Repo.get!(Show, id) |> Repo.preload([:creator, :episodes])
  defp get_episode!(id), do: Repo.get!(Episode, id) |> Repo.preload([:show, :guests])
  defp get_episode_with_session!(id), do: Repo.get!(Episode, id) |> Repo.preload([:show, :recording_session, :guests])
  defp get_episode_with_show!(id), do: Repo.get!(Episode, id) |> Repo.preload([:show])
  defp get_episode_with_recording!(id), do: Repo.get!(Episode, id) |> Repo.preload([:show, :recording_session, :media_files])

  defp can_publish_episode?(episode, user, tier) do
    episode.creator_id == user.id and
    FeatureGate.feature_available?(tier, :podcast_publishing) and
    episode.status in ["processed", "ready"]
  end

  defp update_episode_status(episode, status) do
    episode
    |> Episode.changeset(%{status: status, updated_at: DateTime.utc_now()})
    |> Repo.update()
  end

  defp setup_podcast_audio_chain(session_id) do
    # Configure audio processing chain for podcast recording
    audio_config = %{
      noise_gate: %{threshold: -40, ratio: 10},
      eq: %{preset: :podcast_voice},
      compressor: %{threshold: -18, ratio: 3, attack: 3, release: 100},
      limiter: %{threshold: -1, release: 50}
    }

    Frestyl.Studio.AudioEngine.apply_processing_chain(session_id, audio_config)
  end

  defp start_episode_transcription(episode_id, session_id) do
    # Start real-time transcription service
    Task.start(fn ->
      Frestyl.AI.TranscriptionService.start_session_transcription(
        session_id,
        %{
          episode_id: episode_id,
          speaker_detection: true,
          punctuation: true,
          format: :podcast
        }
      )
    end)
  end

  defp start_chapter_detection(episode_id, session_id) do
    # AI-powered chapter detection during recording
    Task.start(fn ->
      Frestyl.AI.ChapterDetection.monitor_session(
        session_id,
        %{
          episode_id: episode_id,
          detection_method: :topic_change,
          min_chapter_length: 120 # seconds
        }
      )
    end)
  end

  defp get_session_recording_data(session_id) do
    case Frestyl.Studio.RecordingEngine.get_session_recordings(session_id) do
      {:ok, recordings} when length(recordings) > 0 ->
        {:ok, recordings}
      {:ok, []} ->
        {:error, :no_recording_found}
      error ->
        error
    end
  end

  defp apply_noise_reduction(audio_data) do
    # Apply AI-powered noise reduction
    Frestyl.Audio.NoiseReduction.process(audio_data, %{
      algorithm: :spectral_subtraction,
      aggression: :moderate
    })
  end

  defp apply_eq_preset(audio_data, :podcast_voice) do
    # Apply podcast voice EQ preset
    Frestyl.Audio.EQ.apply_preset(audio_data, %{
      high_pass: 80,  # Remove low rumble
      presence_boost: %{freq: 2500, gain: 2}, # Voice clarity
      de_ess: %{freq: 8000, threshold: -12}   # Reduce sibilance
    })
  end

  defp apply_compression(audio_data, :broadcast) do
    # Apply broadcast-style compression
    Frestyl.Audio.Dynamics.compress(audio_data, %{
      threshold: -18,
      ratio: 3,
      attack: 3,
      release: 100,
      knee: :soft
    })
  end

  defp normalize_levels(audio_data) do
    # Normalize to broadcast standards
    Frestyl.Audio.Loudness.normalize(audio_data, %{
      target_lufs: -16,  # Podcast standard
      true_peak_limit: -1
    })
  end

  defp generate_chapters_from_audio(audio_data) do
    # AI-powered chapter detection from processed audio
    Frestyl.AI.ChapterDetection.detect_from_audio(audio_data, %{
      min_duration: 120,
      topic_change_threshold: 0.7
    })
  end

  defp generate_episode_transcription(episode, recording_data) do
    # Generate AI transcription from recording
    Task.start(fn ->
      case Frestyl.AI.TranscriptionService.transcribe_recording(recording_data, %{
        episode_id: episode.id,
        speaker_detection: true,
        punctuation: true,
        format: :podcast
      }) do
        {:ok, transcript} ->
          # Update episode with transcript
          episode
          |> Episode.changeset(%{transcript: transcript})
          |> Repo.update()

          # Broadcast transcript ready
          PubSub.broadcast(
            Frestyl.PubSub,
            "episode:#{episode.id}",
            {:transcript_ready, transcript}
          )

        {:error, reason} ->
          Logger.error("Failed to generate transcript for episode #{episode.id}: #{inspect(reason)}")
      end
    end)
  end

  defp generate_episode_chapters(episode, recording_data) do
    # Generate AI-powered chapter markers
    Task.start(fn ->
      case Frestyl.AI.ChapterDetection.detect_from_recording(recording_data, %{
        episode_id: episode.id,
        min_duration: 120, # 2 minutes minimum per chapter
        topic_change_threshold: 0.7
      }) do
        {:ok, chapters} ->
          # Update episode with chapters
          episode
          |> Episode.changeset(%{chapters: chapters})
          |> Repo.update()

          # Broadcast chapters ready
          PubSub.broadcast(
            Frestyl.PubSub,
            "episode:#{episode.id}",
            {:chapters_ready, chapters}
          )

        {:error, reason} ->
          Logger.error("Failed to generate chapters for episode #{episode.id}: #{inspect(reason)}")
      end
    end)
  end

  defp create_episode_media_file(episode, processed_audio) do
    # Create media file for episode
    Media.create_media_file(%{
      filename: "#{episode.slug}.mp3",
      content_type: "audio/mpeg",
      file_size: byte_size(processed_audio),
      metadata: %{
        episode_id: episode.id,
        duration: get_audio_duration(processed_audio),
        format: "podcast_audio"
      },
      channel_id: episode.show.channel_id,
      creator_id: episode.creator_id
    }, processed_audio)
  end

  defp create_rss_feed(show) do
    # Generate RSS feed for podcast distribution
    rss_content = generate_rss_content(show)

    # Save RSS feed
    File.write(rss_feed_path(show), rss_content)

    # Update show with RSS URL
    show
    |> Show.changeset(%{rss_feed_url: rss_feed_url(show)})
    |> Repo.update()
  end

  defp update_rss_feed(show) do
    episodes = list_published_episodes(show.id)
    rss_content = generate_rss_content(show, episodes)
    File.write(rss_feed_path(show), rss_content)
  end

  defp generate_rss_content(show, episodes \\ []) do
    # Generate podcast RSS feed following Apple Podcasts specification
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
      <channel>
        <title>#{show.title}</title>
        <description>#{show.description}</description>
        <link>#{show.website_url}</link>
        <language>#{show.language || "en"}</language>
        <itunes:author>#{show.author_name}</itunes:author>
        <itunes:category text="#{show.category}" />
        <itunes:image href="#{show.artwork_url}" />
        <itunes:explicit>#{show.explicit || false}</itunes:explicit>
        #{render_episodes_xml(episodes)}
      </channel>
    </rss>
    """
  end

  defp render_episodes_xml(episodes) do
    Enum.map(episodes, fn episode ->
      """
      <item>
        <title>#{episode.title}</title>
        <description>#{episode.description}</description>
        <pubDate>#{format_rfc2822(episode.published_at)}</pubDate>
        <enclosure url="#{episode.audio_url}" type="audio/mpeg" length="#{episode.file_size}" />
        <itunes:duration>#{format_duration(episode.duration)}</itunes:duration>
        <itunes:episode>#{episode.episode_number}</itunes:episode>
      </item>
      """
    end)
    |> Enum.join("\n")
  end

  defp distribute_to_spotify(episode) do
    # Spotify distribution integration
    Frestyl.Integrations.Spotify.submit_episode(episode)
  end

  defp distribute_to_apple(episode) do
    # Apple Podcasts distribution
    Frestyl.Integrations.ApplePodcasts.submit_episode(episode)
  end

  defp distribute_to_google(episode) do
    # Google Podcasts distribution
    Frestyl.Integrations.GooglePodcasts.submit_episode(episode)
  end

  defp distribute_to_youtube(episode) do
    # YouTube distribution for video podcasts
    Frestyl.Integrations.YouTube.upload_podcast_episode(episode)
  end

  defp generate_guest_recording_link(guest) do
    # Generate secure link for guest to join recording
    token = Phoenix.Token.sign(FrestylWeb.Endpoint, "guest_access", guest.id)
    "#{FrestylWeb.Endpoint.url()}/podcast/guest/#{token}"
  end

  defp generate_guest_instructions(episode) do
    """
    Thank you for joining #{episode.show.title}!

    Recording Instructions:
    1. Use headphones to prevent echo
    2. Find a quiet space for recording
    3. Test your microphone before we start
    4. Click the link 5 minutes before our scheduled time

    Technical Requirements:
    - Stable internet connection
    - Chrome or Firefox browser
    - Microphone (USB or headset recommended)
    """
  end

  defp notify_scheduled_guests(episode) do
    # Notify guests that recording is starting
    episode.guests
    |> Enum.filter(&(&1.status == "confirmed"))
    |> Enum.each(fn guest ->
      # Send notification via email/SMS
      Frestyl.Notifications.send_recording_starting_notification(guest)
    end)
  end

  defp create_default_episode_template(show, tier) do
    # Create episode template based on tier features
    template_features = %{
      intro_music: FeatureGate.feature_available?(tier, :podcast_intro_music),
      outro_music: FeatureGate.feature_available?(tier, :podcast_outro_music),
      automatic_chapters: FeatureGate.feature_available?(tier, :automatic_chapters),
      ai_show_notes: FeatureGate.feature_available?(tier, :ai_show_notes),
      custom_branding: FeatureGate.feature_available?(tier, :custom_branding)
    }

    # Save template for show
    Frestyl.Templates.create_podcast_template(show.id, template_features)
  end

  defp validate_episode_creation(show, attrs, user, tier) do
    limits = TierManager.get_tier_limits(tier)
    episodes_this_month = count_episodes_this_month(show.id)

    cond do
      show.creator_id != user.id ->
        {:error, :not_authorized}

      episodes_this_month >= Map.get(limits, :max_episodes_per_month, 10) ->
        {:error, :episode_limit_reached}

      true ->
        {:ok, attrs}
    end
  end

  defp count_episodes_this_month(show_id) do
    start_of_month = DateTime.utc_now() |> DateTime.beginning_of_month()

    from(e in Episode,
      where: e.show_id == ^show_id and e.created_at >= ^start_of_month,
      select: count(e.id)
    )
    |> Repo.one()
  end

  defp list_published_episodes(show_id) do
    from(e in Episode,
      where: e.show_id == ^show_id and e.status == "published",
      order_by: [desc: e.published_at],
      preload: [:media_files]
    )
    |> Repo.all()
  end

  defp rss_feed_path(show), do: "priv/static/rss/#{show.slug}.xml"
  defp rss_feed_url(show), do: "#{FrestylWeb.Endpoint.url()}/rss/#{show.slug}.xml"

  defp format_rfc2822(datetime) do
    datetime
    |> DateTime.to_naive()
    |> NaiveDateTime.to_erl()
    |> :calendar.universal_time_to_local_time()
    |> NaiveDateTime.from_erl!()
    |> Timex.format!("{RFC822}")
  end

  defp format_duration(seconds) do
    hours = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)
    seconds = rem(seconds, 60)

    if hours > 0 do
      "#{hours}:#{pad_zero(minutes)}:#{pad_zero(seconds)}"
    else
      "#{minutes}:#{pad_zero(seconds)}"
    end
  end

  defp pad_zero(num) when num < 10, do: "0#{num}"
  defp pad_zero(num), do: to_string(num)

  defp get_audio_duration(audio_data) do
    # Calculate audio duration from binary data
    # This would integrate with your audio processing library
    :audio_utils.get_duration(audio_data)
  end

    def get_rss_feed(show_id) do
    case Repo.get(Show, show_id) do
      nil ->
        {:error, :not_found}

      show ->
        rss_content = generate_rss_feed(show)
        {:ok, rss_content}
    end
  end

  def get_show_by_slug(slug) do
    Repo.get_by(Show, slug: slug)
  end

  defp generate_rss_feed(show) do
    episodes = Repo.all(
      from e in Episode,
      where: e.show_id == ^show.id and e.status == "published",
      order_by: [desc: e.published_at],
      limit: 50
    )

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
      <channel>
        <title>#{show.title}</title>
        <description>#{show.description}</description>
        <link>#{show.website_url}</link>
        <language>#{show.language || "en"}</language>
        <itunes:author>#{show.author_name}</itunes:author>
        <itunes:category text="#{show.category}" />
        <itunes:image href="#{show.artwork_url}" />
        <itunes:explicit>#{show.explicit || false}</itunes:explicit>
        #{render_episodes_rss(episodes)}
      </channel>
    </rss>
    """
  end

  defp render_episodes_rss(episodes) do
    Enum.map(episodes, fn episode ->
      """
      <item>
        <title>#{episode.title}</title>
        <description>#{episode.description}</description>
        <pubDate>#{format_rfc2822(episode.published_at)}</pubDate>
        <enclosure url="#{episode.audio_url}" type="audio/mpeg" length="#{episode.file_size}" />
        <itunes:duration>#{format_duration(episode.duration)}</itunes:duration>
        <itunes:episode>#{episode.episode_number}</itunes:episode>
      </item>
      """
    end)
    |> Enum.join("\n")
  end

  defp format_rfc2822(datetime) when is_nil(datetime), do: ""
  defp format_rfc2822(datetime) do
    datetime
    |> DateTime.to_naive()
    |> NaiveDateTime.to_erl()
    |> :calendar.universal_time_to_local_time()
    |> NaiveDateTime.from_erl!()
    |> Calendar.strftime("%a, %d %b %Y %H:%M:%S %z")
  end

  defp format_duration(nil), do: "00:00"
  defp format_duration(seconds) when is_integer(seconds) do
    hours = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)
    seconds = rem(seconds, 60)

    if hours > 0 do
      "#{pad_zero(hours)}:#{pad_zero(minutes)}:#{pad_zero(seconds)}"
    else
      "#{pad_zero(minutes)}:#{pad_zero(seconds)}"
    end
  end

  defp pad_zero(num) when num < 10, do: "0#{num}"
  defp pad_zero(num), do: to_string(num)
end
