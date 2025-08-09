# lib/frestyl_web/live/stories_live/edit.ex
defmodule FrestylWeb.StoriesLive.Edit do
  use FrestylWeb, :live_view

  alias Frestyl.Stories
  alias Frestyl.Stories.{EnhancedStoryStructure, Collaboration}
  alias Frestyl.StoryEngine.{FormatManager, AIIntegration}
  alias Frestyl.Features.TierManager
  alias Phoenix.PubSub

  # Add the missing helper functions inline for now
  defp get_export_formats(format_config) do
    case format_config do
      %{export_formats: formats} when is_list(formats) ->
        Enum.map(formats, fn format ->
          %{key: format, name: format_name(format)}
        end)
      _ ->
        [%{key: "pdf", name: "PDF"}, %{key: "html", name: "HTML"}]
    end
  end

  defp format_name(format) do
    case format do
      "pdf" -> "PDF Document"
      "html" -> "Web Page"
      "epub" -> "eBook (EPUB)"
      "docx" -> "Word Document"
      _ -> String.upcase(format)
    end
  end

  defp get_section_label(editor_mode) do
    case editor_mode do
      :manuscript -> "Chapters"
      :business -> "Sections"
      :experimental -> "Segments"
      _ -> "Sections"
    end
  end

  defp get_section_type(editor_mode) do
    case editor_mode do
      :manuscript -> "Chapter"
      :business -> "Section"
      :experimental -> "Segment"
      _ -> "Section"
    end
  end

  defp get_placeholder_content(editor_mode) do
    case editor_mode do
      :manuscript ->
        "<p>Once upon a time...</p><p>Start writing your story here. Use the tools on the left to develop characters and plot points.</p>"

      :business ->
        "<h2>Executive Summary</h2><p>Provide a brief overview of the key findings...</p><h2>Problem Statement</h2><p>Describe the challenge or opportunity...</p>"

      :experimental ->
        "<p>Welcome to your experimental story space!</p><p>This is where creativity meets technology. Start writing and explore the unique features available for this format.</p>"

      _ ->
        "<p>Start writing your story here...</p><p>Use the sidebar tools to organize your thoughts and collaborate with others.</p>"
    end
  end

  @impl true
  def mount(%{"id" => story_id}, session, socket) do
    current_user = get_current_user_from_session(session)

    case Stories.get_enhanced_story_with_permissions(story_id, current_user.id) do
      {:ok, story, permissions} ->
        if connected?(socket) do
          # Subscribe to story updates and collaboration
          PubSub.subscribe(Frestyl.PubSub, "story:#{story_id}")
          PubSub.subscribe(Frestyl.PubSub, "story_collaboration:#{story_id}")
        end

        format_config = FormatManager.get_format_config(story.story_type)
        user_tier = TierManager.get_user_tier(current_user)

        socket = socket
        |> assign(:story, story)
        |> assign(:current_user, current_user)
        |> assign(:permissions, permissions)
        |> assign(:format_config, format_config)
        |> assign(:user_tier, user_tier)
        |> assign(:editor_mode, determine_editor_mode(story, format_config))
        |> assign(:active_section, get_current_section(story))
        |> assign(:collaborators, get_active_collaborators(story_id))
        |> assign(:ai_enabled, permissions.can_use_ai)
        |> assign(:ai_suggestions, [])
        |> assign(:word_count, calculate_word_count(story))
        |> assign(:save_status, :saved)
        |> assign(:show_ai_panel, false)
        |> assign(:show_collaboration_panel, false)
        |> assign(:mobile_view, false)

        {:ok, socket}

      {:error, :not_found} ->
        {:ok, socket |> put_flash(:error, "Story not found") |> redirect(to: ~p"/stories")}

      {:error, :access_denied} ->
        {:ok, socket |> put_flash(:error, "Access denied") |> redirect(to: ~p"/stories")}
    end
  end

  @impl true
  def handle_event("content_changed", %{"content" => content, "section_id" => section_id}, socket) do
    story = socket.assigns.story

    # Update content optimistically
    updated_story = update_story_section(story, section_id, content)

    # Auto-save after typing stops
    Process.send_after(self(), {:auto_save, section_id, content}, 2000)

    # Broadcast to collaborators
    broadcast_content_change(story.id, section_id, content, socket.assigns.current_user)

    # Get AI suggestions if enabled
    ai_suggestions = if socket.assigns.ai_enabled do
      AIIntegration.get_writing_suggestions(content, story.story_type)
    else
      []
    end

    {:noreply, socket
     |> assign(:story, updated_story)
     |> assign(:word_count, calculate_word_count(updated_story))
     |> assign(:save_status, :saving)
     |> assign(:ai_suggestions, ai_suggestions)}
  end

  @impl true
  def handle_event("voice_input_start", _params, socket) do
    if socket.assigns.permissions.can_use_voice do
      {:noreply, push_event(socket, "start_voice_recording", %{})}
    else
      {:noreply, put_flash(socket, :error, "Voice input requires Creator tier")}
    end
  end

  @impl true
  def handle_event("voice_input_complete", %{"transcript" => transcript, "section_id" => section_id}, socket) do
    # Process voice input and insert into content
    current_content = get_section_content(socket.assigns.story, section_id)
    updated_content = current_content <> " " <> transcript

    # Trigger content update
    send(self(), {:voice_content_update, section_id, updated_content})

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_ai_panel", _params, socket) do
    {:noreply, assign(socket, :show_ai_panel, !socket.assigns.show_ai_panel)}
  end

  @impl true
  def handle_event("apply_ai_suggestion", %{"suggestion" => suggestion, "section_id" => section_id}, socket) do
    if socket.assigns.permissions.can_use_ai do
      current_content = get_section_content(socket.assigns.story, section_id)
      improved_content = AIIntegration.apply_suggestion(current_content, suggestion)

      send(self(), {:ai_content_update, section_id, improved_content})
      {:noreply, socket}
    else
      {:noreply, put_flash(socket, :error, "AI features require Creator tier")}
    end
  end

  @impl true
  def handle_event("add_collaborator", %{"email" => email}, socket) do
    if socket.assigns.permissions.can_invite do
      case Collaboration.invite_collaborator(socket.assigns.story.id, email, socket.assigns.current_user.id) do
        {:ok, _collaboration} ->
          {:noreply, put_flash(socket, :info, "Collaborator invited successfully")}
        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Failed to invite collaborator: #{reason}")}
      end
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to invite collaborators")}
    end
  end

  @impl true
  def handle_event("export_story", %{"format" => export_format}, socket) do
    if socket.assigns.permissions.can_export do
      case Stories.export_story(socket.assigns.story, export_format) do
        {:ok, file_path} ->
          {:noreply, push_event(socket, "download_file", %{url: file_path})}
        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Export failed: #{reason}")}
      end
    else
      {:noreply, put_flash(socket, :error, "Export requires Creator tier")}
    end
  end

  @impl true
  def handle_info({:auto_save, section_id, content}, socket) do
    case Stories.update_story_section(socket.assigns.story.id, section_id, content) do
      {:ok, _updated_story} ->
        {:noreply, assign(socket, :save_status, :saved)}
      {:error, _reason} ->
        {:noreply, assign(socket, :save_status, :error)}
    end
  end

  @impl true
  def handle_info({:voice_content_update, section_id, content}, socket) do
    send(self(), {:content_changed, %{"content" => content, "section_id" => section_id}})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:ai_content_update, section_id, content}, socket) do
    send(self(), {:content_changed, %{"content" => content, "section_id" => section_id}})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:collaborator_joined, collaborator}, socket) do
    updated_collaborators = [collaborator | socket.assigns.collaborators]
    {:noreply, assign(socket, :collaborators, updated_collaborators)}
  end

  @impl true
  def handle_info({:content_updated_by, user_id, section_id, content}, socket) do
    if user_id != socket.assigns.current_user.id do
      updated_story = update_story_section(socket.assigns.story, section_id, content)
      {:noreply, assign(socket, :story, updated_story)
       |> push_event("external_content_update", %{section_id: section_id, content: content})}
    else
      {:noreply, socket}
    end
  end

  # Helper Functions

  defp determine_editor_mode(story, format_config) do
    cond do
      story.story_type in ["novel", "screenplay"] -> :manuscript
      story.story_type in ["case_study", "data_story"] -> :business
      story.story_type in ["live_story", "narrative_beats"] -> :experimental
      true -> :standard
    end
  end

  defp get_current_section(story) do
    case story.sections do
      [] -> create_initial_section(story)
      [first | _] -> first
    end
  end

  defp create_initial_section(story) do
    %{
      id: System.unique_integer([:positive]),
      type: get_initial_section_type(story.story_type),
      title: get_initial_section_title(story.story_type),
      content: "",
      order: 1
    }
  end

  defp get_initial_section_type(story_type) do
    case story_type do
      "novel" -> "chapter"
      "screenplay" -> "scene"
      "case_study" -> "overview"
      "article" -> "introduction"
      _ -> "section"
    end
  end

  defp get_initial_section_title(story_type) do
    case story_type do
      "novel" -> "Chapter 1"
      "screenplay" -> "Scene 1"
      "case_study" -> "Executive Summary"
      "article" -> "Introduction"
      _ -> "Getting Started"
    end
  end

  defp get_active_collaborators(story_id) do
    # This would fetch from your collaboration system
    Collaboration.get_active_collaborators(story_id)
  end

  defp calculate_word_count(story) do
    story.sections
    |> Enum.map(& &1.content || "")
    |> Enum.join(" ")
    |> String.split()
    |> length()
  end

  defp update_story_section(story, section_id, content) do
    updated_sections = Enum.map(story.sections, fn section ->
      if section.id == String.to_integer(section_id) do
        %{section | content: content}
      else
        section
      end
    end)

    %{story | sections: updated_sections}
  end

  defp get_section_content(story, section_id) do
    story.sections
    |> Enum.find(fn section -> section.id == String.to_integer(section_id) end)
    |> case do
      nil -> ""
      section -> section.content || ""
    end
  end

  defp broadcast_content_change(story_id, section_id, content, user) do
    PubSub.broadcast(Frestyl.PubSub, "story_collaboration:#{story_id}",
      {:content_updated_by, user.id, section_id, content})
  end

  defp get_current_user_from_session(session) do
    # Your existing session handling
    session["current_user"]
  end

  # Render functions (simplified versions)
  defp render_manuscript_tools(assigns) do
    ~H"""
    <div class="space-y-4">
      <div>
        <h4 class="text-sm font-medium text-gray-900 mb-2">Characters</h4>
        <button class="text-sm text-blue-600">Add Character</button>
      </div>
      <div>
        <h4 class="text-sm font-medium text-gray-900 mb-2">Plot Points</h4>
        <button class="text-sm text-blue-600">Add Plot Point</button>
      </div>
    </div>
    """
  end

  defp render_business_tools(assigns) do
    ~H"""
    <div class="space-y-4">
      <div>
        <h4 class="text-sm font-medium text-gray-900 mb-2">Data Sources</h4>
        <button class="text-sm text-blue-600">Connect Data</button>
      </div>
      <div>
        <h4 class="text-sm font-medium text-gray-900 mb-2">Stakeholders</h4>
        <button class="text-sm text-blue-600">Add Stakeholder</button>
      </div>
    </div>
    """
  end

  defp render_experimental_tools(assigns) do
    ~H"""
    <div class="space-y-4">
      <div>
        <h4 class="text-sm font-medium text-gray-900 mb-2">Live Features</h4>
        <button class="text-sm text-red-600">🔴 Go Live</button>
      </div>
    </div>
    """
  end

  defp render_standard_tools(assigns) do
    ~H"""
    <div class="space-y-4">
      <div>
        <h4 class="text-sm font-medium text-gray-900 mb-2">Outline</h4>
        <button class="text-sm text-blue-600">Add Item</button>
      </div>
      <div>
        <h4 class="text-sm font-medium text-gray-900 mb-2">Research</h4>
        <button class="text-sm text-blue-600">Add Note</button>
      </div>
    </div>
    """
  end
end
