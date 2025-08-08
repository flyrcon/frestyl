# lib/frestyl_web/live/helpers/common_helpers.ex
defmodule FrestylWeb.Live.Helpers.CommonHelpers do
  @moduledoc """
  Common helper functions that can be imported into LiveViews to avoid duplication.
  """

  # Remove the problematic imports and use Phoenix.HTML functions directly
  # import Phoenix.HTML
  # import Phoenix.HTML.Tag

  def status_badge_class(status) do
    case status do
      "active" -> "bg-green-100 text-green-700"
      "recording" -> "bg-red-100 text-red-700"
      "paused" -> "bg-yellow-100 text-yellow-700"
      "completed" -> "bg-blue-100 text-blue-700"
      "draft" -> "bg-gray-100 text-gray-700"
      "published" -> "bg-green-100 text-green-700"
      "archived" -> "bg-gray-100 text-gray-600"
      "in_progress" -> "bg-blue-100 text-blue-700"
      "collaborative" -> "bg-purple-100 text-purple-700"
      _ -> "bg-gray-100 text-gray-600"
    end
  end

  def format_duration(seconds) when is_number(seconds) do
    minutes = div(seconds, 60)
    remaining_seconds = rem(seconds, 60)
    "#{minutes}:#{String.pad_leading(to_string(remaining_seconds), 2, "0")}"
  end
  def format_duration(_), do: "0:00"

  def humanize_status(status) when is_binary(status) do
    status
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
  def humanize_status(_), do: "Unknown"

  def time_ago(datetime) do
    seconds_ago = DateTime.diff(DateTime.utc_now(), datetime, :second)

    cond do
      seconds_ago < 60 -> "#{seconds_ago}s ago"
      seconds_ago < 3600 -> "#{div(seconds_ago, 60)}m ago"
      seconds_ago < 86400 -> "#{div(seconds_ago, 3600)}h ago"
      seconds_ago < 604800 -> "#{div(seconds_ago, 86400)}d ago"
      true -> "#{div(seconds_ago, 604800)}w ago"
    end
  end

  def format_file_size(bytes) when is_number(bytes) do
    cond do
      bytes >= 1_073_741_824 -> "#{Float.round(bytes / 1_073_741_824, 1)} GB"
      bytes >= 1_048_576 -> "#{Float.round(bytes / 1_048_576, 1)} MB"
      bytes >= 1024 -> "#{Float.round(bytes / 1024, 1)} KB"
      true -> "#{bytes} B"
    end
  end
  def format_file_size(_), do: "Unknown"

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

  # Return CSS classes for user avatar instead of HTML elements
  def user_avatar_classes(size \\ "w-8 h-8") do
    "#{size} bg-gradient-to-br from-purple-500 to-pink-500 rounded-full flex items-center justify-center text-white font-semibold text-sm"
  end

  # Return initials for use in templates
  def user_initials(user) do
    case user do
      %{name: name} when is_binary(name) ->
        name
        |> String.split()
        |> Enum.take(2)
        |> Enum.map(&String.first/1)
        |> Enum.join()
        |> String.upcase()

      %{email: email} when is_binary(email) ->
        email
        |> String.first()
        |> String.upcase()

      _ -> "U"
    end
  end

  def collaboration_status(session_or_story) do
    collaborator_count = length(session_or_story.collaborators || [])

    cond do
      collaborator_count == 0 -> "Solo"
      collaborator_count == 1 -> "1 collaborator"
      true -> "#{collaborator_count} collaborators"
    end
  end

  def calculate_progress_percentage(item) do
    case item do
      %{completion_percentage: percentage} when is_number(percentage) ->
        percentage
      %{status: "completed"} ->
        100
      %{status: "recording", progress: progress} when is_number(progress) ->
        progress
      %{status: "paused", progress: progress} when is_number(progress) ->
        progress
      %{status: "draft"} ->
        10
      _ ->
        0
    end
  end

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

  def get_story_preview(story) do
    case story do
      %{content: content} when is_binary(content) and content != "" ->
        truncate_text(content, 100)
      %{template_data: %{subtitle: subtitle}} when is_binary(subtitle) ->
        subtitle
      %{description: description} when is_binary(description) ->
        description
      _ ->
        "No content yet - click to start writing"
    end
  end

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

  def format_currency(amount_cents, currency \\ "USD") do
    case currency do
      "USD" ->
        dollars = amount_cents / 100
        "$#{:erlang.float_to_binary(dollars, decimals: 2)}"
      "EUR" ->
        euros = amount_cents / 100
        "€#{:erlang.float_to_binary(euros, decimals: 2)}"
      _ ->
        "#{amount_cents / 100} #{currency}"
    end
  end

  def humanize_feature(feature) when is_atom(feature) do
    feature
    |> Atom.to_string()
    |> humanize_feature()
  end

  def humanize_feature(feature) when is_binary(feature) do
    feature
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  def color_for_status(status) do
    case status do
      "active" -> "green"
      "completed" -> "blue"
      "in_progress" -> "yellow"
      "draft" -> "gray"
      "error" -> "red"
      _ -> "gray"
    end
  end

  def get_initials(name) when is_binary(name) do
    name
    |> String.split()
    |> Enum.take(2)
    |> Enum.map(&String.first/1)
    |> Enum.join()
    |> String.upcase()
  end
  def get_initials(_), do: "U"

  def relative_time(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)

    cond do
      diff < 0 -> "in the future"
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)} minutes ago"
      diff < 86400 -> "#{div(diff, 3600)} hours ago"
      diff < 604800 -> "#{div(diff, 86400)} days ago"
      diff < 2592000 -> "#{div(diff, 604800)} weeks ago"
      true -> format_date(datetime)
    end
  end

  def progress_color(percentage) when is_number(percentage) do
    cond do
      percentage >= 90 -> "green"
      percentage >= 70 -> "blue"
      percentage >= 50 -> "yellow"
      percentage >= 25 -> "orange"
      true -> "red"
    end
  end
  def progress_color(_), do: "gray"

  # Return progress bar CSS classes instead of HTML elements
  def progress_bar_classes(percentage, opts \\ []) do
    color = Keyword.get(opts, :color, progress_color(percentage))
    size = Keyword.get(opts, :size, "h-2")

    %{
      container: "w-full bg-gray-200 rounded-full #{size}",
      bar: "bg-#{color}-500 #{size} rounded-full transition-all duration-300",
      width: "#{percentage}%"
    }
  end

  def format_list(items, separator \\ ", ", last_separator \\ " and ") do
    case items do
      [] -> ""
      [single] -> to_string(single)
      [first | rest] ->
        case rest do
          [last] -> "#{first}#{last_separator}#{last}"
          _ ->
            {middle, [last]} = Enum.split(rest, -1)
            middle_str = Enum.join([first | middle], separator)
            "#{middle_str}#{last_separator}#{last}"
        end
    end
  end

  def conditionally_wrap(content, condition, wrapper_class \\ "") do
    if condition do
      %{content: content, wrap: true, class: wrapper_class}
    else
      %{content: content, wrap: false, class: ""}
    end
  end

  def smart_truncate(text, max_length, opts \\ []) do
    suffix = Keyword.get(opts, :suffix, "...")
    break_on_word = Keyword.get(opts, :break_on_word, true)

    if String.length(text) <= max_length do
      text
    else
      if break_on_word do
        text
        |> String.slice(0, max_length - String.length(suffix))
        |> String.split()
        |> Enum.drop(-1)
        |> Enum.join(" ")
        |> Kernel.<>(suffix)
      else
        String.slice(text, 0, max_length - String.length(suffix)) <> suffix
      end
    end
  end

  def css_classes(class_list) when is_list(class_list) do
    class_list
    |> Enum.filter(&(&1 != nil and &1 != ""))
    |> Enum.join(" ")
  end

  def css_classes(class_string) when is_binary(class_string), do: class_string
  def css_classes(_), do: ""

  def conditional_class(condition, true_class, false_class \\ "") do
    if condition, do: true_class, else: false_class
  end

  def map_status_to_color(status) do
    %{
      "active" => "green",
      "inactive" => "gray",
      "pending" => "yellow",
      "completed" => "blue",
      "error" => "red",
      "warning" => "orange",
      "success" => "green",
      "info" => "blue"
    }[status] || "gray"
  end

  # Return badge CSS classes instead of HTML elements
  def badge_classes(color \\ "gray", opts \\ []) do
    size = Keyword.get(opts, :size, "sm")

    size_classes = case size do
      "xs" -> "px-2 py-0.5 text-xs"
      "sm" -> "px-2.5 py-1 text-xs"
      "md" -> "px-3 py-1.5 text-sm"
      "lg" -> "px-4 py-2 text-base"
    end

    "inline-flex items-center #{size_classes} font-medium rounded-full bg-#{color}-100 text-#{color}-700"
  end

  def generate_avatar_url(user, size \\ 40) do
    # Fallback avatar generation - could integrate with Gravatar or other services
    name = user.name || user.email || "User"
    initials = get_initials(name)

    # This would typically be a real avatar service URL
    "https://ui-avatars.com/api/?name=#{URI.encode(initials)}&size=#{size}&background=random"
  end
end
