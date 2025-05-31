defmodule FrestylWeb.SupremeDiscoveryController do
  use FrestylWeb, :controller
  alias Frestyl.{Media, Accounts}

  def index(conn, params) do
    user_id = get_current_user_id(conn)

    # Parse query parameters
    opts = %{
      limit: Map.get(params, "limit", "20") |> String.to_integer(),
      offset: Map.get(params, "offset", "0") |> String.to_integer(),
      filter_type: Map.get(params, "type"),
      sort_by: Map.get(params, "sort", "recent"),
      search: Map.get(params, "search"),
      theme: Map.get(params, "theme", "cosmic_dreams")
    }

    # Get discovery data with planetary grouping
    planetary_data = get_discovery_planetary_data(user_id, opts)

    conn
    |> put_status(:ok)
    |> json(%{
      planets: planetary_data.planets,
      total_count: planetary_data.total_count,
      has_more: planetary_data.has_more,
      current_page: div(opts.offset, opts.limit) + 1,
      theme_config: get_theme_config(opts.theme),
      metadata: %{
        user_preferences: get_user_discovery_preferences(user_id),
        suggested_theme: get_suggested_theme(user_id),
        horizon_preview: planetary_data.horizon_preview
      }
    })
  end

  def show(conn, %{"id" => planet_id} = params) do
    user_id = get_current_user_id(conn)
    expand_mode = Map.get(params, "expand", "false") == "true"

    case Media.get_media_group_with_planetary_data(planet_id, user_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Planet not found"})

      planet_data ->
        # Record view
        Media.record_view(planet_data.primary_file.id, user_id)

        response_data = %{
          planet: format_planet_data(planet_data, expand_mode),
          satellites: format_satellites_data(planet_data.satellites, expand_mode),
          interactions: get_planet_interactions(planet_id, user_id),
          navigation: get_planet_navigation(planet_id, user_id),
          theme_suggestions: get_planet_theme_suggestions(planet_data)
        }

        if expand_mode do
          response_data = Map.merge(response_data, %{
            detailed_metadata: get_detailed_metadata(planet_data),
            discussion_threads: get_discussion_threads(planet_id, user_id),
            collaboration_data: get_collaboration_data(planet_data),
            analytics: get_planet_analytics(planet_id, user_id)
          })
        end

        conn
        |> put_status(:ok)
        |> json(response_data)
    end
  end

  # Private helper functions
  defp get_discovery_planetary_data(user_id, opts) do
    # Get media groups with their primary files and satellites
    query_result = Media.list_media_groups_for_discovery(user_id, opts)

    planets = Enum.map(query_result.groups, &format_planet_summary/1)

    # Get horizon preview (next/previous planets in the axis)
    horizon_preview = get_horizon_preview(planets, opts)

    %{
      planets: planets,
      total_count: query_result.total_count,
      has_more: query_result.has_more,
      horizon_preview: horizon_preview
    }
  end

  defp format_planet_summary(media_group) do
    primary_file = media_group.primary_file
    satellites = media_group.media_group_files

    %{
      id: media_group.id,
      type: determine_planet_type(primary_file),
      title: primary_file.title || primary_file.original_filename,
      description: media_group.description,
      primary_file: %{
        id: primary_file.id,
        file_type: primary_file.file_type,
        file_url: generate_file_url(primary_file),
        thumbnail_url: generate_thumbnail_url(primary_file),
        duration: get_file_duration(primary_file),
        size: primary_file.size
      },
      satellites: %{
        count: length(satellites),
        types: satellites |> Enum.map(& &1.media_file.file_type) |> Enum.uniq(),
        preview: satellites |> Enum.take(3) |> Enum.map(&format_satellite_preview/1)
      },
      interactions: %{
        reaction_count: media_group.reaction_summary.total_count,
        view_count: media_group.view_count,
        comment_count: media_group.discussion_count,
        recent_reactions: media_group.reaction_summary.recent_reactions
      },
      metadata: %{
        created_at: media_group.inserted_at,
        updated_at: media_group.updated_at,
        creator: format_creator_info(media_group.creator),
        collaborators: format_collaborators(media_group.collaborators),
        tags: media_group.tags || []
      },
      theme_hints: generate_theme_hints(primary_file, media_group)
    }
  end

  defp format_planet_data(planet_data, expand_mode) do
    base_data = format_planet_summary(planet_data)

    if expand_mode do
      Map.merge(base_data, %{
        expanded: true,
        full_description: planet_data.description,
        detailed_metadata: get_detailed_metadata(planet_data),
        file_structure: get_file_structure(planet_data),
        version_history: get_version_history(planet_data),
        related_planets: get_related_planets(planet_data)
      })
    else
      base_data
    end
  end

  defp format_satellites_data(satellites, expand_mode) do
    satellites
    |> Enum.map(fn satellite ->
      base_data = format_satellite_preview(satellite)

      if expand_mode do
        Map.merge(base_data, %{
          expanded: true,
          full_metadata: get_satellite_metadata(satellite),
          relationships: get_satellite_relationships(satellite),
          edit_history: get_satellite_edit_history(satellite)
        })
      else
        base_data
      end
    end)
    |> Enum.group_by(& &1.category)
  end

  defp format_satellite_preview(satellite_file) do
    file = satellite_file.media_file

    %{
      id: file.id,
      title: file.title || file.original_filename,
      type: file.file_type,
      category: categorize_satellite(file),
      file_url: generate_file_url(file),
      thumbnail_url: generate_thumbnail_url(file),
      size: file.size,
      relationship: satellite_file.relationship_type,
      position: satellite_file.position || 0
    }
  end

  defp determine_planet_type(primary_file) do
    case primary_file.file_type do
      type when type in ["mp3", "wav", "flac", "m4a"] -> "audio"
      type when type in ["mp4", "mov", "avi", "mkv"] -> "video"
      type when type in ["jpg", "jpeg", "png", "gif", "webp"] -> "image"
      type when type in ["pdf", "doc", "docx", "txt", "md"] -> "document"
      type when type in ["ppt", "pptx", "key"] -> "presentation"
      _ -> "file"
    end
  end

  defp categorize_satellite(file) do
    case file.file_type do
      type when type in ["jpg", "jpeg", "png", "gif", "webp"] -> "visual"
      type when type in ["txt", "md", "pdf", "doc", "docx"] -> "text"
      type when type in ["mp3", "wav", "flac"] -> "audio"
      type when type in ["mp4", "mov", "avi"] -> "video"
      _ -> "other"
    end
  end

  defp get_horizon_preview(planets, opts) do
    current_index = opts.offset
    total_planets = length(planets)

    %{
      previous: if(current_index > 0, do: Enum.at(planets, current_index - 1)),
      current: Enum.at(planets, current_index),
      next: if(current_index < total_planets - 1, do: Enum.at(planets, current_index + 1)),
      upcoming: planets |> Enum.drop(current_index + 1) |> Enum.take(3)
    }
  end

  defp get_planet_interactions(planet_id, user_id) do
    %{
      user_reaction: Media.get_user_reaction(planet_id, user_id),
      reaction_summary: Media.get_reaction_summary(planet_id),
      is_saved: Media.is_saved_by_user?(planet_id, user_id),
      is_following: Media.is_following_planet?(planet_id, user_id),
      collaboration_status: Media.get_collaboration_status(planet_id, user_id)
    }
  end

  defp get_planet_navigation(planet_id, user_id) do
    user_history = Media.get_user_navigation_history(user_id)
    current_index = Enum.find_index(user_history, & &1.id == planet_id)

    %{
      can_go_back: current_index && current_index > 0,
      can_go_forward: current_index && current_index < length(user_history) - 1,
      history_position: current_index,
      suggested_next: Media.get_suggested_next_planets(planet_id, user_id, limit: 5)
    }
  end

  defp get_planet_theme_suggestions(planet_data) do
    primary_file = planet_data.primary_file

    case determine_planet_type(primary_file) do
      "audio" ->
        music_metadata = primary_file.music_metadata
        suggest_theme_for_music(music_metadata)

      "image" ->
        suggest_theme_for_image(primary_file)

      "video" ->
        suggest_theme_for_video(primary_file)

      _ ->
        ["glass_morphism"]  # Default theme
    end
  end

  defp suggest_theme_for_music(music_metadata) when not is_nil(music_metadata) do
    genre = String.downcase(music_metadata.genre || "")
    bpm = music_metadata.bpm || 120

    cond do
      String.contains?(genre, "electronic") or bpm > 140 -> ["neon_cyberpunk", "cosmic_dreams"]
      String.contains?(genre, "rock") or String.contains?(genre, "metal") -> ["blueprint_industrial"]
      String.contains?(genre, "ambient") or String.contains?(genre, "chill") -> ["cosmic_dreams", "organic_nature"]
      String.contains?(genre, "jazz") or String.contains?(genre, "classical") -> ["abstract_mosaic", "glass_morphism"]
      true -> ["glass_morphism", "cosmic_dreams"]
    end
  end

  defp suggest_theme_for_music(_), do: ["glass_morphism"]

  defp suggest_theme_for_image(_file) do
    # Could analyze image colors/content in the future
    ["glass_morphism", "abstract_mosaic"]
  end

  defp suggest_theme_for_video(_file) do
    ["cosmic_dreams", "neon_cyberpunk"]
  end

  defp generate_theme_hints(primary_file, media_group) do
    %{
      suggested_themes: get_planet_theme_suggestions(%{primary_file: primary_file}),
      color_palette: extract_color_palette(primary_file),
      animation_style: determine_animation_style(primary_file),
      interaction_hints: get_interaction_hints(media_group)
    }
  end

  defp extract_color_palette(file) do
    # Placeholder - could implement actual color extraction
    case determine_planet_type(file) do
      "audio" -> ["#6366f1", "#8b5cf6", "#06b6d4"]
      "image" -> ["#f59e0b", "#ec4899", "#14b8a6"]
      "video" -> ["#ef4444", "#f97316", "#fbbf24"]
      _ -> ["#10b981", "#06b6d4", "#8b5cf6"]
    end
  end

  defp determine_animation_style(file) do
    case determine_planet_type(file) do
      "audio" -> "pulse_with_music"
      "image" -> "gentle_float"
      "video" -> "dynamic_preview"
      _ -> "subtle_glow"
    end
  end

  defp get_interaction_hints(media_group) do
    %{
      primary_action: determine_primary_action(media_group),
      satellite_actions: determine_satellite_actions(media_group),
      collaboration_available: media_group.collaboration_enabled || false
    }
  end

  defp determine_primary_action(media_group) do
    case determine_planet_type(media_group.primary_file) do
      "audio" -> "play"
      "video" -> "play"
      "image" -> "view"
      _ -> "open"
    end
  end

  defp determine_satellite_actions(media_group) do
    media_group.media_group_files
    |> Enum.map(fn satellite ->
      %{
        id: satellite.media_file.id,
        action: determine_primary_action(%{primary_file: satellite.media_file})
      }
    end)
  end

  # Utility functions
  defp get_current_user_id(conn) do
    # Extract from session, token, or authentication system
    # This is a placeholder - implement based on your auth system
    case conn.assigns[:current_user] do
      %{id: id} -> id
      _ -> "anonymous"
    end
  end

  defp generate_file_url(file) do
    # Generate appropriate file URL based on storage system
    FrestylWeb.Router.Helpers.media_url(FrestylWeb.Endpoint, :download, file.id)
  end

  defp generate_thumbnail_url(file) do
    # Generate thumbnail URL if available
    case Map.get(file, :thumbnail_path) do
      nil -> generate_file_url(file)
      thumbnail_path -> FrestylWeb.Router.Helpers.static_url(FrestylWeb.Endpoint, thumbnail_path)
    end
  end

  defp get_file_duration(file) do
    case file.music_metadata do
      %{duration_seconds: duration} -> duration
      _ -> nil
    end
  end

  defp format_creator_info(creator) when not is_nil(creator) do
    %{
      id: creator.id,
      name: creator.name || creator.username,
      avatar_url: Map.get(creator, :avatar_url)
    }
  end

  defp format_creator_info(_), do: nil

  defp format_collaborators(collaborators) when is_list(collaborators) do
    Enum.map(collaborators, &format_creator_info/1)
  end

  defp format_collaborators(_), do: []

  # Placeholder functions for expanded mode data
  defp get_detailed_metadata(_planet_data), do: %{}
  defp get_discussion_threads(_planet_id, _user_id), do: []
  defp get_collaboration_data(_planet_data), do: %{}
  defp get_planet_analytics(_planet_id, _user_id), do: %{}
  defp get_file_structure(_planet_data), do: %{}
  defp get_version_history(_planet_data), do: []
  defp get_related_planets(_planet_data), do: []
  defp get_satellite_metadata(_satellite), do: %{}
  defp get_satellite_relationships(_satellite), do: []
  defp get_satellite_edit_history(_satellite), do: []
  defp get_user_discovery_preferences(_user_id), do: %{}
  defp get_suggested_theme(_user_id), do: "glass_morphism"
  defp get_theme_config(theme), do: FrestylWeb.ThemeController.get_theme_config(theme)
end
