# lib/frestyl_web/live/voice_sketch_live/index.ex
defmodule FrestylWeb.VoiceSketchLive.Index do
  use FrestylWeb, :live_view

  import FrestylWeb.Live.Helpers.CommonHelpers
  alias Frestyl.VoiceSketch
  alias Frestyl.Features.TierManager

  @impl true
  def mount(_params, session, socket) do
    current_user = get_current_user_from_session(session)
    user_tier = TierManager.get_user_tier(current_user)

    # Check access
    unless TierManager.has_tier_access?(user_tier, "professional") do
      {:ok, redirect(socket, to: ~p"/upgrade?feature=voice_sketch")}
    else
      sessions = VoiceSketch.list_user_sessions(current_user.id)

      socket = socket
      |> assign(:current_user, current_user)
      |> assign(:sessions, sessions)
      |> assign(:user_tier, user_tier)

      {:ok, socket}
    end
  end

  @impl true
  def handle_event("create_session", %{"title" => title}, socket) do
    case VoiceSketch.create_session(%{title: title}, socket.assigns.current_user) do
      {:ok, session} ->
        {:noreply, redirect(socket, to: ~p"/voice-sketch/#{session.id}")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create session")}
    end
  end

  defp get_current_user_from_session(session) do
    case session["user_token"] do
      nil -> nil
      token -> Frestyl.Accounts.get_user_by_session_token(token)
    end
  end

  # Helper functions

  def format_word_count(count) when is_number(count) and count >= 1000 do
    "#{Float.round(count / 1000, 1)}k"
  end
  def format_word_count(count) when is_number(count), do: to_string(count)
  def format_word_count(_), do: "0"

  def format_number(num) when is_number(num) and num >= 1000 do
    "#{Float.round(num / 1000, 1)}k"
  end
  def format_number(num) when is_number(num), do: to_string(num)
  def format_number(_), do: "0"

  def story_type_gradient(story_type) do
    case story_type do
      "biography" -> "from-green-400 to-blue-500"
      "article" -> "from-purple-400 to-pink-500"
      "case_study" -> "from-emerald-400 to-teal-500"
      "novel" -> "from-purple-500 to-indigo-600"
      "screenplay" -> "from-orange-500 to-red-500"
      "comic_book" -> "from-orange-400 to-red-500"
      "song" -> "from-pink-400 to-rose-500"
      "data_story" -> "from-blue-400 to-cyan-500"
      "live_story" -> "from-purple-500 to-pink-600"
      "voice_sketch" -> "from-indigo-500 to-purple-600"
      "narrative_beats" -> "from-pink-500 to-orange-500"
      _ -> "from-gray-400 to-gray-600"
    end
  end

  def story_type_icon(story_type) do
    case story_type do
      "biography" -> "📖"
      "article" -> "📝"
      "case_study" -> "📊"
      "novel" -> "📚"
      "screenplay" -> "🎬"
      "comic_book" -> "💥"
      "song" -> "🎵"
      "data_story" -> "📈"
      "live_story" -> "🎪"
      "voice_sketch" -> "🎨🎙️"
      "narrative_beats" -> "🎵📖"
      "audiobook" -> "🎧"
      "storyboard" -> "🎨"
      _ -> "📄"
    end
  end

  def humanize_story_type(story_type) when is_binary(story_type) do
    story_type
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
  def humanize_story_type(_), do: "Unknown"

  def tier_badge_class(tier) do
    case tier do
      "personal" -> "bg-gray-100 text-gray-700"
      "creator" -> "bg-purple-100 text-purple-700"
      "professional" -> "bg-blue-100 text-blue-700"
      "enterprise" -> "bg-green-100 text-green-700"
      _ -> "bg-gray-100 text-gray-600"
    end
  end

  def tier_display_name(tier) do
    case tier do
      "personal" -> "Free"
      "creator" -> "Creator"
      "professional" -> "Professional"
      "enterprise" -> "Enterprise"
      _ -> "Unknown"
    end
  end

  def session_gradient(session_type) do
    case session_type do
      "voice_sketch" -> "from-indigo-500 to-purple-600"
      "tutorial" -> "from-blue-500 to-cyan-600"
      "presentation" -> "from-green-500 to-emerald-600"
      "collaboration" -> "from-purple-500 to-pink-600"
      "recording" -> "from-red-500 to-pink-600"
      _ -> "from-gray-500 to-gray-600"
    end
  end

  def get_session_icon(session_type) do
    case session_type do
      "voice_sketch" -> "🎨🎙️"
      "tutorial" -> "📚"
      "presentation" -> "📊"
      "collaboration" -> "👥"
      "recording" -> "🎙️"
      "live_story" -> "🎪"
      _ -> "🎙️"
    end
  end

  def truncate_text(text, length \\ 100) when is_binary(text) do
    if String.length(text) <= length do
      text
    else
      text
      |> String.slice(0, length)
      |> Kernel.<>("...")
    end
  end
  def truncate_text(_, _), do: ""

  def pluralize(count, singular, plural \\ nil) do
    plural = plural || "#{singular}s"

    case count do
      1 -> "1 #{singular}"
      n -> "#{n} #{plural}"
    end
  end

  def format_percentage(value) when is_number(value) do
    "#{Float.round(value, 1)}%"
  end
  def format_percentage(_), do: "0%"

  def safe_get(map, key, default \\ nil) do
    case map do
      %{} -> Map.get(map, key, default)
      _ -> default
    end
  end

  def format_date(datetime) do
    case datetime do
      %DateTime{} ->
        datetime
        |> DateTime.to_date()
        |> Date.to_string()

      %Date{} ->
        Date.to_string(datetime)

      _ ->
        "Unknown"
    end
  end

  def format_datetime(datetime) do
    case datetime do
      %DateTime{} ->
        datetime
        |> DateTime.truncate(:second)
        |> DateTime.to_string()
        |> String.replace("T", " ")
        |> String.replace("Z", "")

      _ ->
        "Unknown"
    end
  end

  def empty_state_message(type) do
    case type do
      :stories ->
        "No stories yet. Create your first story to get started!"

      :collaborations ->
        "No active collaborations. Invite others to work together!"

      :sessions ->
        "No sessions found. Start a new session to begin."

      :templates ->
        "No templates available for your current tier."

      _ ->
        "No items found."
    end
  end

  def loading_state(loading?) do
    if loading? do
      "opacity-50 pointer-events-none"
    else
      ""
    end
  end

  def validation_error_class(changeset, field) do
    if changeset.errors[field] do
      "border-red-300 focus:border-red-500 focus:ring-red-500"
    else
      "border-gray-300 focus:border-blue-500 focus:ring-blue-500"
    end
  end

  def get_error_message(changeset, field) do
    case changeset.errors[field] do
      {message, _} -> message
      _ -> nil
    end
  end

    defp voice_sketch_quality(session) do
    case session.audio_quality || "standard" do
      "high" -> "HD Audio"
      "studio" -> "Studio Quality"
      "broadcast" -> "Broadcast Quality"
      _ -> "Standard"
    end
  end

  defp sketch_complexity(session) do
    stroke_count = length(session.sketch_strokes || [])

    cond do
      stroke_count > 1000 -> "Complex"
      stroke_count > 500 -> "Detailed"
      stroke_count > 100 -> "Moderate"
      stroke_count > 0 -> "Simple"
      true -> "No Drawing"
    end
  end

  defp export_format_badge(format) do
    case format do
      "mp4" -> "bg-blue-100 text-blue-700"
      "webm" -> "bg-green-100 text-green-700"
      "gif" -> "bg-purple-100 text-purple-700"
      "pdf" -> "bg-red-100 text-red-700"
      _ -> "bg-gray-100 text-gray-700"
    end
  end
end
