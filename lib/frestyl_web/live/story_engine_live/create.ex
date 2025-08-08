# lib/frestyl_web/live/story_engine_live/create.ex
defmodule FrestylWeb.StoryEngineLive.Create do
  use FrestylWeb, :live_view

  alias Frestyl.StoryEngine.{QuickStartTemplates, FormatManager}
  alias Frestyl.Stories

  @impl true
  def mount(%{"format" => format, "intent" => intent}, session, socket) do
    current_user = get_current_user_from_session(session)

    # Get template and format configuration
    template = QuickStartTemplates.get_template(format, intent)
    format_config = FormatManager.get_format_config(format)

    socket = socket
    |> assign(:current_user, current_user)
    |> assign(:format, format)
    |> assign(:intent, intent)
    |> assign(:template, template)
    |> assign(:format_config, format_config)
    |> assign(:current_section, 0)
    |> assign(:story_content, %{})
    |> assign(:collaboration_setup, false)
    |> assign(:ai_suggestions, [])
    |> assign(:show_ai_assistant, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("update_section", %{"section_index" => index, "content" => content}, socket) do
    section_index = String.to_integer(index)
    updated_content = Map.put(socket.assigns.story_content, section_index, content)

    # Get AI suggestions if enabled
    ai_suggestions = if content != "" and String.length(content) > 50 do
      get_ai_suggestions(socket.assigns.format, section_index, content)
    else
      []
    end

    {:noreply, socket
     |> assign(:story_content, updated_content)
     |> assign(:ai_suggestions, ai_suggestions)}
  end

  @impl true
  def handle_event("next_section", _params, socket) do
    current = socket.assigns.current_section
    max_section = length(socket.assigns.template.outline) - 1

    next_section = min(current + 1, max_section)

    {:noreply, assign(socket, :current_section, next_section)}
  end

  @impl true
  def handle_event("previous_section", _params, socket) do
    current = socket.assigns.current_section
    previous_section = max(current - 1, 0)

    {:noreply, assign(socket, :current_section, previous_section)}
  end

  @impl true
  def handle_event("save_story", _params, socket) do
    # Create the actual story record
    story_params = build_story_params(socket)

    case Stories.create_enhanced_story(story_params, socket.assigns.current_user) do
      {:ok, story} ->
        {:noreply, socket
         |> put_flash(:info, "Story created successfully!")
         |> redirect(to: ~p"/stories/#{story.id}/edit")}

      {:error, changeset} ->
        {:noreply, socket
         |> put_flash(:error, "Failed to create story")
         |> assign(:changeset, changeset)}
    end
  end

  @impl true
  def handle_event("setup_collaboration", _params, socket) do
    {:noreply, assign(socket, :collaboration_setup, true)}
  end

  @impl true
  def handle_event("toggle_ai_assistant", _params, socket) do
    {:noreply, assign(socket, :show_ai_assistant, !socket.assigns.show_ai_assistant)}
  end

  # Private helper functions

  defp get_current_user_from_session(session) do
    case session["user_token"] do
      nil -> nil
      token -> Frestyl.Accounts.get_user_by_session_token(token)
    end
  end

  defp build_story_params(socket) do
    %{
      title: get_story_title(socket),
      story_type: socket.assigns.format,
      intent_category: socket.assigns.intent,
      template_data: socket.assigns.template,
      creation_source: "story_engine_wizard",
      content: socket.assigns.story_content
    }
  end

  defp get_story_title(socket) do
    Map.get(socket.assigns.story_content, "title", socket.assigns.template.title)
  end

  defp get_ai_suggestions(format, section_index, content) do
    # Simple AI suggestion system - would integrate with real AI service
    [
      "Consider adding more specific details to make this section more engaging",
      "This section could benefit from a concrete example or anecdote",
      "Try varying your sentence structure for better flow"
    ]
  end

  defp humanize_feature(feature) when is_binary(feature) do
    feature
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
end
