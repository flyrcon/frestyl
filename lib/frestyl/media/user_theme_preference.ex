# lib/frestyl/media/user_theme_preferences.ex
defmodule Frestyl.Media.UserThemePreferences do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @derive {Jason.Encoder, only: [:id, :current_theme, :theme_settings, :auto_switch_themes,
                                :preferred_view_mode, :animation_intensity, :enable_haptics,
                                :enable_sound_effects, :custom_colors, :user_id, :inserted_at, :updated_at]}

  alias Frestyl.Accounts.User

  schema "user_theme_preferences" do
    field :current_theme, :string, default: "cosmic" # cosmic, cyberpunk, liquid, crystal, organic, minimal
    field :theme_settings, :map, default: %{}
    field :auto_switch_themes, :boolean, default: false
    field :preferred_view_mode, :string, default: "discovery" # discovery, grid, list, canvas
    field :animation_intensity, :float, default: 1.0 # 0.0 to 2.0
    field :enable_haptics, :boolean, default: true
    field :enable_sound_effects, :boolean, default: false
    field :custom_colors, :map, default: %{}

    belongs_to :user, User, foreign_key: :user_id

    timestamps()
  end

  @required_fields [:user_id]
  @optional_fields [:current_theme, :theme_settings, :auto_switch_themes, :preferred_view_mode,
                   :animation_intensity, :enable_haptics, :enable_sound_effects, :custom_colors]

  def changeset(user_theme_preferences, attrs) do
    user_theme_preferences
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:current_theme, ["cosmic", "cyberpunk", "liquid", "crystal", "organic", "minimal"])
    |> validate_inclusion(:preferred_view_mode, ["discovery", "grid", "list", "canvas"])
    |> validate_number(:animation_intensity, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 2.0)
    |> validate_theme_settings()
    |> validate_custom_colors()
    |> unique_constraint(:user_id)
    |> foreign_key_constraint(:user_id)
  end

  # Query helpers
  def for_user(query \\ __MODULE__, user_id) do
    from(utp in query, where: utp.user_id == ^user_id)
  end

  def by_theme(query \\ __MODULE__, theme) do
    from(utp in query, where: utp.current_theme == ^theme)
  end

  def by_view_mode(query \\ __MODULE__, view_mode) do
    from(utp in query, where: utp.preferred_view_mode == ^view_mode)
  end

  def with_auto_switch(query \\ __MODULE__) do
    from(utp in query, where: utp.auto_switch_themes == true)
  end

  def with_haptics_enabled(query \\ __MODULE__) do
    from(utp in query, where: utp.enable_haptics == true)
  end

  def with_sounds_enabled(query \\ __MODULE__) do
    from(utp in query, where: utp.enable_sound_effects == true)
  end

  # Discovery interface helpers
  def get_or_create_for_user(user_id) do
    case Frestyl.Repo.get_by(__MODULE__, user_id: user_id) do
      nil ->
        %__MODULE__{user_id: user_id}
        |> changeset(%{})
        |> Frestyl.Repo.insert()
      preferences ->
        {:ok, preferences}
    end
  end

  def update_theme(user_id, theme) when theme in ["cosmic", "cyberpunk", "liquid", "crystal", "organic", "minimal"] do
    case get_or_create_for_user(user_id) do
      {:ok, preferences} ->
        preferences
        |> changeset(%{current_theme: theme})
        |> Frestyl.Repo.update()
      error -> error
    end
  end

  def update_view_mode(user_id, view_mode) when view_mode in ["discovery", "grid", "list", "canvas"] do
    case get_or_create_for_user(user_id) do
      {:ok, preferences} ->
        preferences
        |> changeset(%{preferred_view_mode: view_mode})
        |> Frestyl.Repo.update()
      error -> error
    end
  end

  def update_animation_intensity(user_id, intensity) when is_float(intensity) and intensity >= 0.0 and intensity <= 2.0 do
    case get_or_create_for_user(user_id) do
      {:ok, preferences} ->
        preferences
        |> changeset(%{animation_intensity: intensity})
        |> Frestyl.Repo.update()
      error -> error
    end
  end

  # Theme configuration helpers
  def get_theme_config(preferences) do
    base_config = get_base_theme_config(preferences.current_theme)

    # Apply any custom settings
    custom_settings = preferences.theme_settings || %{}
    custom_colors = preferences.custom_colors || %{}

    base_config
    |> Map.merge(custom_settings)
    |> put_in([:colors], Map.merge(base_config[:colors] || %{}, custom_colors))
    |> put_in([:animation_intensity], preferences.animation_intensity)
  end

  defp get_base_theme_config("cosmic") do
    %{
      name: "Cosmic Dreams",
      colors: %{
        primary: "#8B5CF6",
        secondary: "#06B6D4",
        background: "from-purple-900 via-blue-900 to-indigo-900",
        card: "bg-white/10 backdrop-blur-md",
        text: "text-white",
        accent: "text-cyan-300"
      },
      effects: %{
        particles: true,
        glow: true,
        floating: true
      }
    }
  end

  defp get_base_theme_config("cyberpunk") do
    %{
      name: "Neon Grid",
      colors: %{
        primary: "#10B981",
        secondary: "#06B6D4",
        background: "bg-black",
        card: "bg-gradient-to-br from-green-500/10 to-cyan-500/10",
        text: "text-green-300",
        accent: "text-cyan-300"
      },
      effects: %{
        scanlines: true,
        grid: true,
        hologram: true
      }
    }
  end

  defp get_base_theme_config("liquid") do
    %{
      name: "Liquid Flow",
      colors: %{
        primary: "#3B82F6",
        secondary: "#A855F7",
        background: "from-blue-400 via-purple-500 to-pink-500",
        card: "bg-white/10 backdrop-blur-xl",
        text: "text-white",
        accent: "text-blue-200"
      },
      effects: %{
        morphing: true,
        fluid: true,
        ripple: true
      }
    }
  end

  defp get_base_theme_config("crystal") do
    %{
      name: "Crystal Matrix",
      colors: %{
        primary: "#3B82F6",
        secondary: "#8B5CF6",
        background: "from-gray-900 via-blue-900 to-purple-900",
        card: "bg-gradient-to-br from-white/5 to-blue-500/10",
        text: "text-gray-100",
        accent: "text-blue-300"
      },
      effects: %{
        geometric: true,
        prismatic: true,
        faceted: true
      }
    }
  end

  defp get_base_theme_config("organic") do
    %{
      name: "Organic Growth",
      colors: %{
        primary: "#059669",
        secondary: "#10B981",
        background: "from-green-800 via-emerald-700 to-teal-800",
        card: "bg-gradient-to-br from-green-900/30 to-emerald-800/30",
        text: "text-green-100",
        accent: "text-emerald-300"
      },
      effects: %{
        branching: true,
        growth: true,
        organic: true
      }
    }
  end

  defp get_base_theme_config("minimal") do
    %{
      name: "Clean Paper",
      colors: %{
        primary: "#1F2937",
        secondary: "#6B7280",
        background: "bg-gray-50",
        card: "bg-white border border-gray-200",
        text: "text-gray-900",
        accent: "text-gray-600"
      },
      effects: %{
        clean: true,
        paper: true,
        fold: true
      }
    }
  end

  defp get_base_theme_config(_), do: get_base_theme_config("cosmic")

  # Statistics and analytics
  def theme_usage_stats do
    from(utp in __MODULE__,
      group_by: utp.current_theme,
      select: {utp.current_theme, count(utp.id)}
    )
  end

  def view_mode_stats do
    from(utp in __MODULE__,
      group_by: utp.preferred_view_mode,
      select: {utp.preferred_view_mode, count(utp.id)}
    )
  end

  def animation_intensity_average do
    from(utp in __MODULE__, select: avg(utp.animation_intensity))
  end

  # Helper functions
  def should_auto_switch?(preferences) do
    preferences.auto_switch_themes && preferences.theme_settings["auto_switch_schedule"]
  end

  def get_scheduled_theme(preferences, current_time \\ DateTime.utc_now()) do
    if should_auto_switch?(preferences) do
      schedule = preferences.theme_settings["auto_switch_schedule"]
      current_hour = current_time.hour

      # Simple time-based theme switching
      cond do
        current_hour >= 6 && current_hour < 12 -> "minimal"  # Morning: clean, focused
        current_hour >= 12 && current_hour < 18 -> "liquid"  # Afternoon: energetic
        current_hour >= 18 && current_hour < 22 -> "cosmic"  # Evening: creative
        true -> "cyberpunk"  # Night: intense
      end
    else
      preferences.current_theme
    end
  end

  # Private validation helpers
  defp validate_theme_settings(changeset) do
    case get_field(changeset, :theme_settings) do
      nil -> changeset
      settings when is_map(settings) -> changeset
      _ -> add_error(changeset, :theme_settings, "must be a valid map")
    end
  end

  defp validate_custom_colors(changeset) do
    case get_field(changeset, :custom_colors) do
      nil -> changeset
      colors when is_map(colors) ->
        # Validate that color values are valid hex codes
        invalid_colors = Enum.filter(colors, fn {_key, value} ->
          not is_binary(value) or not String.match?(value, ~r/^#[0-9A-Fa-f]{6}$/)
        end)

        if Enum.empty?(invalid_colors) do
          changeset
        else
          add_error(changeset, :custom_colors, "all color values must be valid hex codes (e.g., #8B5CF6)")
        end
      _ -> add_error(changeset, :custom_colors, "must be a valid map")
    end
  end
end
