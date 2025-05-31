defmodule FrestylWeb.ThemeController do
  use FrestylWeb, :controller
  alias Frestyl.{Accounts, Media}

  @themes %{
    "cosmic_dreams" => %{
      name: "Cosmic Dreams",
      description: "Living sky with floating stars and glassmorphism",
      colors: %{
        primary: "#6366f1",
        secondary: "#8b5cf6",
        accent: "#06b6d4",
        background: "linear-gradient(135deg, #667eea 0%, #764ba2 100%)",
        glass: "rgba(255, 255, 255, 0.1)"
      },
      time_preference: "evening",
      music_genres: ["ambient", "electronic", "chill"]
    },
    "blueprint_industrial" => %{
      name: "Blueprint Industrial",
      description: "Iron Man-esque with components that come apart",
      colors: %{
        primary: "#ef4444",
        secondary: "#f97316",
        accent: "#fbbf24",
        background: "linear-gradient(135deg, #232526 0%, #414345 100%)",
        glass: "rgba(255, 255, 255, 0.05)"
      },
      time_preference: "work_hours",
      music_genres: ["rock", "metal", "industrial"]
    },
    "glass_morphism" => %{
      name: "Glass Morphism",
      description: "Semi-transparent cards with smooth sliding components",
      colors: %{
        primary: "#10b981",
        secondary: "#06b6d4",
        accent: "#8b5cf6",
        background: "linear-gradient(135deg, #ffecd2 0%, #fcb69f 100%)",
        glass: "rgba(255, 255, 255, 0.2)"
      },
      time_preference: "morning",
      music_genres: ["pop", "indie", "folk"]
    },
    "abstract_mosaic" => %{
      name: "Abstract Mosaic",
      description: "Pieces coming together like living artwork",
      colors: %{
        primary: "#f59e0b",
        secondary: "#ec4899",
        accent: "#14b8a6",
        background: "linear-gradient(135deg, #fa709a 0%, #fee140 100%)",
        glass: "rgba(255, 255, 255, 0.15)"
      },
      time_preference: "afternoon",
      music_genres: ["jazz", "classical", "experimental"]
    },
    "neon_cyberpunk" => %{
      name: "Neon Cyberpunk",
      description: "Electric colors with futuristic grid patterns",
      colors: %{
        primary: "#ff0080",
        secondary: "#00ffff",
        accent: "#ffff00",
        background: "linear-gradient(135deg, #0c0c0c 0%, #1a1a2e 100%)",
        glass: "rgba(0, 255, 255, 0.1)"
      },
      time_preference: "night",
      music_genres: ["edm", "synthwave", "techno"]
    },
    "organic_nature" => %{
      name: "Organic Nature",
      description: "Earth tones with flowing, natural animations",
      colors: %{
        primary: "#059669",
        secondary: "#0d9488",
        accent: "#84cc16",
        background: "linear-gradient(135deg, #74b9ff 0%, #0984e3 100%)",
        glass: "rgba(255, 255, 255, 0.12)"
      },
      time_preference: "morning",
      music_genres: ["folk", "acoustic", "world"]
    }
  }

  def switch_theme(conn, %{"theme" => theme_key, "user_id" => user_id}) do
    case Map.get(@themes, theme_key) do
      nil ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid theme"})

      theme ->
        # Save user theme preference
        Accounts.update_user_theme_preference(user_id, %{
          primary_theme: theme_key,
          auto_switch_enabled: false
        })

        conn
        |> put_status(:ok)
        |> json(%{
          theme: theme,
          message: "Theme switched successfully"
        })
    end
  end

  def get_dynamic_theme(conn, %{"user_id" => user_id}) do
    current_hour = DateTime.utc_now().hour
    user_preferences = Accounts.get_user_theme_preferences(user_id)

    # Get user's recently played music to determine genre
    recent_media = Media.get_recent_user_media(user_id, limit: 5)
    dominant_genre = extract_dominant_genre(recent_media)

    suggested_theme = determine_dynamic_theme(current_hour, dominant_genre, user_preferences)

    conn
    |> put_status(:ok)
    |> json(%{
      suggested_theme: suggested_theme,
      current_theme: user_preferences.primary_theme,
      reasoning: %{
        time_based: time_based_suggestion(current_hour),
        music_based: music_based_suggestion(dominant_genre),
        user_history: user_preferences.theme_history || []
      }
    })
  end

  def list(conn, _params) do
    conn
    |> put_status(:ok)
    |> json(%{themes: @themes})
  end

  def set_preference(conn, %{"user_id" => user_id, "preferences" => prefs}) do
    case Accounts.update_user_theme_preference(user_id, prefs) do
      {:ok, updated_prefs} ->
        conn
        |> put_status(:ok)
        |> json(%{preferences: updated_prefs})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: changeset.errors})
    end
  end

  def preview_all(conn, _params) do
    # Development route to preview all themes
    render(conn, :preview, themes: @themes)
  end

  # Private helper functions
  defp extract_dominant_genre(recent_media) do
    recent_media
    |> Enum.map(& &1.music_metadata.genre)
    |> Enum.filter(& &1)
    |> Enum.frequencies()
    |> Enum.max_by(fn {_genre, count} -> count end, fn -> {"electronic", 1} end)
    |> elem(0)
    |> String.downcase()
  end

  defp determine_dynamic_theme(hour, genre, user_prefs) do
    time_theme = time_based_suggestion(hour)
    genre_theme = music_based_suggestion(genre)

    # Weighted decision based on user preferences
    cond do
      user_prefs.auto_switch_enabled == false ->
        user_prefs.primary_theme

      user_prefs.time_based_switching ->
        time_theme

      user_prefs.music_based_switching ->
        genre_theme

      true ->
        # Smart blend of time and music
        if hour in 6..11, do: time_theme, else: genre_theme
    end
  end

  defp time_based_suggestion(hour) do
    case hour do
      h when h in 6..11 -> "organic_nature"     # Morning
      h when h in 12..17 -> "glass_morphism"    # Afternoon
      h when h in 18..21 -> "abstract_mosaic"   # Evening
      h when h in 22..23 or h in 0..2 -> "cosmic_dreams"  # Night
      h when h in 3..5 -> "neon_cyberpunk"     # Late night
      _ -> "glass_morphism"                     # Default
    end
  end

  defp music_based_suggestion(genre) when is_binary(genre) do
    @themes
    |> Enum.find(fn {_key, theme} ->
      Enum.any?(theme.music_genres, &String.contains?(genre, &1))
    end)
    |> case do
      {theme_key, _} -> theme_key
      nil -> "glass_morphism"  # Default if no match
    end
  end

  defp music_based_suggestion(_), do: "glass_morphism"
end
