# lib/frestyl_web/live/enhanced_story_live/new.ex
defmodule FrestylWeb.EnhancedStoryLive.New do
  use FrestylWeb, :live_view

  alias Frestyl.Stories.{EnhancedTemplates, EnhancedStoryStructure}
  alias Frestyl.Accounts

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    accounts = try do
      Accounts.list_user_accounts(user.id)
    rescue
      _ -> []
    end

    current_account = List.first(accounts)

    socket = socket
    |> assign(:page_title, "Create Enhanced Story")
    |> assign(:accounts, accounts)
    |> assign(:current_account, current_account)
    |> assign(:step, :story_type)
    |> assign(:selected_story_type, nil)
    |> assign(:selected_narrative_structure, nil)
    |> assign(:template_preview, nil)
    |> assign(:story_data, %{})
    |> assign(:ai_suggestions, [])
    |> assign(:show_ai_panel, false)

    {:ok, socket}
  end

  def handle_event("select_story_type", %{"type" => type}, socket) do
    story_type = String.to_atom(type)
    available_structures = EnhancedTemplates.get_structures_for_type(story_type)

    socket = socket
    |> assign(:selected_story_type, story_type)
    |> assign(:available_structures, available_structures)
    |> assign(:selected_narrative_structure, nil)
    |> assign(:step, :narrative_structure)

    {:noreply, socket}
  end

  def handle_event("select_narrative_structure", %{"structure" => structure}, socket) do
    structure_atom = String.to_atom(structure)
    template = EnhancedTemplates.get_template(socket.assigns.selected_story_type, structure_atom)

    socket = socket
    |> assign(:selected_narrative_structure, structure_atom)
    |> assign(:template_preview, template)
    |> assign(:step, :template_preview)
    |> maybe_generate_ai_suggestions(template)

    {:noreply, socket}
  end

  def handle_event("create_story", %{"story" => story_params}, socket) do
    user = socket.assigns.current_user
    account = socket.assigns.current_account

    story_attrs = Map.merge(story_params, %{
      "story_type" => Atom.to_string(socket.assigns.selected_story_type),
      "narrative_structure" => Atom.to_string(socket.assigns.selected_narrative_structure),
      "account_id" => account.id
    })

    case create_enhanced_story(story_attrs, user) do
      {:ok, story} ->
        {:noreply,
         socket
         |> put_flash(:info, "Story created successfully!")
         |> redirect(to: ~p"/studio/stories/#{story.id}")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to create story")
         |> assign(:changeset, changeset)}
    end
  end

  def handle_event("toggle_ai_suggestions", _params, socket) do
    {:noreply, assign(socket, :show_ai_panel, !socket.assigns.show_ai_panel)}
  end

  def handle_event("generate_ai_content", %{"content_type" => content_type}, socket) do
    # Generate AI suggestions based on story type and current content
    suggestions = generate_ai_suggestions_for_type(
      socket.assigns.selected_story_type,
      content_type,
      socket.assigns.template_preview
    )

    socket = socket
    |> assign(:ai_suggestions, suggestions)
    |> assign(:show_ai_panel, true)

    {:noreply, socket}
  end

  defp maybe_generate_ai_suggestions(socket, template) do
    if template.features && :ai_suggestions in template.features do
      suggestions = generate_initial_ai_suggestions(template)
      assign(socket, :ai_suggestions, suggestions)
    else
      socket
    end
  end

  defp generate_initial_ai_suggestions(template) do
    case template.story_type do
      :novel -> [
        %{type: "character", content: "Consider developing a complex protagonist with internal conflict"},
        %{type: "world", content: "Build a vivid setting that supports your theme"},
        %{type: "plot", content: "Start with a compelling hook in the first chapter"}
      ]
      :screenplay -> [
        %{type: "structure", content: "Ensure your logline is clear and compelling"},
        %{type: "character", content: "Give each character a distinct voice"},
        %{type: "visual", content: "Think cinematically - show don't tell"}
      ]
      :comic_book -> [
        %{type: "visual", content: "Plan your splash pages for maximum impact"},
        %{type: "pacing", content: "Use panel size to control reading rhythm"},
        %{type: "character", content: "Design distinctive character silhouettes"}
      ]
      _ -> []
    end
  end

  defp generate_ai_suggestions_for_type(story_type, content_type, template) do
    # This would call the AI service to generate contextual suggestions
    case {story_type, content_type} do
      {:novel, "character"} -> [
        %{type: "character", content: "Create a character arc worksheet"},
        %{type: "character", content: "Develop character voice through dialogue"},
        %{type: "character", content: "Map character relationships and conflicts"}
      ]
      {:screenplay, "scene"} -> [
        %{type: "scene", content: "Every scene should advance plot or character"},
        %{type: "scene", content: "Enter scenes as late as possible"},
        %{type: "scene", content: "Create visual conflict in dialogue scenes"}
      ]
      {:comic_book, "panel"} -> [
        %{type: "panel", content: "Vary panel sizes for visual rhythm"},
        %{type: "panel", content: "Use close-ups for emotional moments"},
        %{type: "panel", content: "Plan page turns for dramatic reveals"}
      ]
      _ -> []
    end
  end

  defp create_enhanced_story(attrs, user) do
    # Create session first
    session_attrs = %{
      name: attrs["title"] || "Untitled Story",
      description: "Enhanced story session",
      session_type: "story_development"
    }

    with {:ok, session} <- Frestyl.Studio.create_session(session_attrs, user),
         {:ok, story} <- EnhancedStoryStructure.create_enhanced_story(attrs, user, session.id) do
      {:ok, story}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-indigo-50 via-white to-cyan-50">
      <div class="max-w-7xl mx-auto px-4 py-8">
        <!-- Header -->
        <div class="text-center mb-12">
          <h1 class="text-4xl font-bold text-gray-900 mb-4">Create Your Story</h1>
          <p class="text-xl text-gray-600">Choose your storytelling format and let AI help guide your creative process</p>
        </div>

        <!-- Progress Steps -->
        <div class="flex justify-center mb-12">
          <div class="flex items-center space-x-8">
            <%= for {step_name, step_label, index} <- [
              {:story_type, "Story Type", 1},
              {:narrative_structure, "Structure", 2},
              {:template_preview, "Template", 3},
              {:create, "Create", 4}
            ] do %>
              <div class="flex items-center">
                <div class={[
                  "w-10 h-10 rounded-full flex items-center justify-center font-semibold text-sm",
                  if(@step == step_name or completed_step?(@step, step_name),
                     do: "bg-indigo-600 text-white",
                     else: "bg-gray-200 text-gray-600")
                ]}>
                  <%= if completed_step?(@step, step_name) do %>
                    <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
                    </svg>
                  <% else %>
                    <%= index %>
                  <% end %>
                </div>
                <span class={[
                  "ml-3 font-medium",
                  if(@step == step_name, do: "text-indigo-600", else: "text-gray-500")
                ]}>
                  <%= step_label %>
                </span>
                <%= if index < 4 do %>
                  <div class="ml-8 w-8 h-px bg-gray-300"></div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Main Content Area -->
        <div class="grid grid-cols-1 lg:grid-cols-4 gap-8">
          <!-- Main Content -->
          <div class="lg:col-span-3">
            <%= case @step do %>
              <% :story_type -> %>
                <%= render_story_type_selection(assigns) %>
              <% :narrative_structure -> %>
                <%= render_narrative_structure_selection(assigns) %>
              <% :template_preview -> %>
                <%= render_template_preview(assigns) %>
            <% end %>
          </div>

          <!-- AI Assistance Panel -->
          <div class="lg:col-span-1">
            <%= if @show_ai_panel or length(@ai_suggestions) > 0 do %>
              <%= render_ai_panel(assigns) %>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp render_story_type_selection(assigns) do
    ~H"""
    <div class="bg-white rounded-2xl shadow-xl p-8">
      <h2 class="text-2xl font-bold text-gray-900 mb-6">What type of story do you want to create?</h2>

      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <%= for {type_key, config} <- story_type_configs() do %>
          <button
            phx-click="select_story_type"
            phx-value-type={type_key}
            class={[
              "group relative p-6 rounded-xl border-2 transition-all duration-300 text-left",
              "hover:shadow-lg hover:scale-105 transform",
              if(@selected_story_type == String.to_atom(type_key),
                 do: "border-indigo-500 bg-indigo-50 shadow-lg",
                 else: "border-gray-200 hover:border-indigo-300 bg-white")
            ]}
          >
            <!-- Icon -->
            <div class={[
              "w-14 h-14 rounded-lg flex items-center justify-center mb-4 transition-colors",
              if(@selected_story_type == String.to_atom(type_key),
                 do: "bg-indigo-500",
                 else: "bg-gradient-to-r #{config.gradient} group-hover:scale-110")
            ]}>
              <%= Phoenix.HTML.raw(config.icon) %>
            </div>

            <!-- Content -->
            <h3 class="text-lg font-semibold text-gray-900 mb-2"><%= config.name %></h3>
            <p class="text-gray-600 text-sm mb-3"><%= config.description %></p>

            <!-- Features -->
            <div class="text-xs text-gray-500">
              <div class="font-medium mb-1">Features:</div>
              <ul class="space-y-1">
                <%= for feature <- config.features do %>
                  <li class="flex items-center">
                    <svg class="w-3 h-3 text-green-500 mr-1" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
                    </svg>
                    <%= feature %>
                  </li>
                <% end %>
              </ul>
            </div>

            <!-- Tier Badge -->
            <%= if config.requires_tier do %>
              <div class="absolute top-3 right-3">
                <span class="px-2 py-1 text-xs font-medium bg-yellow-100 text-yellow-800 rounded-full">
                  <%= String.capitalize(config.requires_tier) %>
                </span>
              </div>
            <% end %>
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_narrative_structure_selection(assigns) do
    ~H"""
    <div class="bg-white rounded-2xl shadow-xl p-8">
      <h2 class="text-2xl font-bold text-gray-900 mb-6">
        Choose your narrative structure for <%= structure_display_name(@selected_story_type) %>
      </h2>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <%= for structure <- @available_structures do %>
          <button
            phx-click="select_narrative_structure"
            phx-value-structure={structure}
            class={[
              "p-6 rounded-xl border-2 transition-all text-left",
              "hover:shadow-lg hover:border-indigo-300",
              if(@selected_narrative_structure == structure,
                 do: "border-indigo-500 bg-indigo-50",
                 else: "border-gray-200 bg-white")
            ]}
          >
            <h3 class="text-lg font-semibold text-gray-900 mb-2">
              <%= structure_display_name(structure) %>
            </h3>
            <p class="text-gray-600 text-sm mb-4">
              <%= get_structure_description(@selected_story_type, structure) %>
            </p>

            <!-- Structure Benefits -->
            <div class="text-xs text-gray-500">
              <div class="font-medium mb-2">Best for:</div>
              <div class="text-gray-600">
                <%= get_structure_benefits(@selected_story_type, structure) %>
              </div>
            </div>
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_template_preview(assigns) do
    ~H"""
    <div class="bg-white rounded-2xl shadow-xl p-8">
      <div class="flex items-center justify-between mb-6">
        <h2 class="text-2xl font-bold text-gray-900">Template Preview</h2>
        <button
          phx-click="toggle_ai_suggestions"
          class="px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 transition-colors flex items-center space-x-2"
        >
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"/>
          </svg>
          <span>AI Assist</span>
        </button>
      </div>

      <%= if @template_preview do %>
        <!-- Template Overview -->
        <div class="mb-8 p-6 bg-gradient-to-r from-blue-50 to-indigo-50 rounded-xl">
          <h3 class="text-xl font-semibold text-gray-900 mb-2"><%= @template_preview.name %></h3>
          <p class="text-gray-700 mb-4"><%= @template_preview.description %></p>

          <!-- Template Features -->
          <%= if @template_preview.features do %>
            <div class="flex flex-wrap gap-2">
              <%= for feature <- @template_preview.features do %>
                <span class="px-3 py-1 bg-white text-indigo-700 text-sm font-medium rounded-full">
                  <%= feature_display_name(feature) %>
                </span>
              <% end %>
            </div>
          <% end %>
        </div>

        <!-- Chapter/Section Structure -->
        <div class="mb-8">
          <h4 class="text-lg font-semibold text-gray-900 mb-4">Story Structure</h4>
          <div class="space-y-4">
            <%= for {chapter, index} <- Enum.with_index(@template_preview.chapters) do %>
              <div class="p-4 border border-gray-200 rounded-lg">
                <div class="flex items-center justify-between mb-2">
                  <h5 class="font-medium text-gray-900">
                    <%= index + 1 %>. <%= chapter.title %>
                  </h5>
                  <%= if chapter[:target_word_count] do %>
                    <span class="text-sm text-gray-500">
                      ~<%= number_with_commas(chapter.target_word_count) %> words
                    </span>
                  <% end %>
                </div>

                <%= if chapter[:purpose] do %>
                  <p class="text-sm text-gray-600 mb-2">
                    Purpose: <%= purpose_display_name(chapter.purpose) %>
                  </p>
                <% end %>

                <!-- Format-specific details -->
                <%= case @selected_story_type do %>
                  <% :novel -> %>
                    <%= if chapter[:suggested_scenes] do %>
                      <div class="mt-3">
                        <div class="text-sm font-medium text-gray-700 mb-1">Suggested Scenes:</div>
                        <ul class="text-sm text-gray-600 space-y-1">
                          <%= for scene <- chapter.suggested_scenes do %>
                            <li class="flex items-start">
                              <span class="w-2 h-2 bg-indigo-400 rounded-full mt-2 mr-2 flex-shrink-0"></span>
                              <%= scene.title %> - <%= scene.purpose %>
                            </li>
                          <% end %>
                        </ul>
                      </div>
                    <% end %>

                  <% :screenplay -> %>
                    <%= if chapter[:target_pages] do %>
                      <div class="text-sm text-gray-600">
                        Target: <%= chapter.target_pages %> pages
                      </div>
                    <% end %>

                  <% :comic_book -> %>
                    <%= if chapter[:pages] do %>
                      <div class="text-sm text-gray-600">
                        Pages: <%= chapter.pages %>
                      </div>
                    <% end %>

                  <% :storyboard -> %>
                    <%= if chapter[:shots] do %>
                      <div class="text-sm text-gray-600">
                        <%= length(chapter.shots) %> shots planned
                      </div>
                    <% end %>

                  <% _ -> %>
                    <div></div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Create Story Form -->
        <.form :let={f} for={%{}} as={:story} phx-submit="create_story" class="space-y-6">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Story Title</label>
            <.input field={f[:title]}
              type="text"
              class="block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
              placeholder="Enter your story title" />
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Description (Optional)</label>
            <.input field={f[:description]}
              type="textarea"
              class="block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
              rows="3"
              placeholder="Brief description of your story" />
          </div>

          <%= if @selected_story_type == :novel do %>
            <div>
              <.input field={f[:target_word_count]}
                type="number"
                class="block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                placeholder="e.g. 1000" />
            </div>
          <% end %>

          <div class="flex items-center space-x-4">
            <.input field={f[:is_public]}
              type="checkbox"
              class="h-4 w-4 text-indigo-600 border-gray-300 rounded focus:ring-indigo-500" />
            <label class="text-sm text-gray-700">Make this story public</label>
          </div>

          <div class="flex justify-between">
            <button
              type="button"
              phx-click="select_narrative_structure"
              phx-value-structure=""
              class="px-6 py-3 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors"
            >
              Back to Structure
            </button>

            <button
              type="submit"
              class="px-8 py-3 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 transition-colors font-medium"
            >
              Create Story
            </button>
          </div>
        </.form>
      <% end %>
    </div>
    """
  end

  defp render_ai_panel(assigns) do
    ~H"""
    <div class="bg-white rounded-xl shadow-lg p-6 sticky top-8">
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-lg font-semibold text-gray-900">AI Assistant</h3>
        <button
          phx-click="toggle_ai_suggestions"
          class="text-gray-400 hover:text-gray-600"
        >
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
          </svg>
        </button>
      </div>

      <!-- AI Suggestions -->
      <%= if length(@ai_suggestions) > 0 do %>
        <div class="space-y-4">
          <%= for suggestion <- @ai_suggestions do %>
            <div class="p-4 bg-gradient-to-r from-purple-50 to-pink-50 rounded-lg border border-purple-100">
              <div class="flex items-start space-x-3">
                <div class="w-8 h-8 bg-gradient-to-r from-purple-500 to-pink-500 rounded-full flex items-center justify-center flex-shrink-0">
                  <svg class="w-4 h-4 text-white" fill="currentColor" viewBox="0 0 20 20">
                    <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z"/>
                  </svg>
                </div>
                <div class="flex-1">
                  <div class="text-xs font-medium text-purple-600 uppercase tracking-wide mb-1">
                    <%= suggestion.type %>
                  </div>
                  <p class="text-sm text-gray-700">
                    <%= suggestion.content %>
                  </p>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>

      <!-- AI Content Generation Options -->
      <%= if @selected_story_type do %>
        <div class="mt-6 pt-6 border-t border-gray-200">
          <h4 class="text-sm font-medium text-gray-900 mb-3">Generate AI Content</h4>
          <div class="space-y-2">
            <%= for content_type <- ai_content_types(@selected_story_type) do %>
              <button
                phx-click="generate_ai_content"
                phx-value-content_type={content_type}
                class="w-full text-left px-3 py-2 text-sm text-gray-700 hover:bg-gray-50 rounded-lg transition-colors"
              >
                <%= content_type_display_name(content_type) %>
              </button>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Helper functions
  defp completed_step?(current_step, target_step) do
    step_order = [:story_type, :narrative_structure, :template_preview, :create]
    current_index = Enum.find_index(step_order, &(&1 == current_step)) || 0
    target_index = Enum.find_index(step_order, &(&1 == target_step)) || 0
    current_index > target_index
  end

  defp story_type_configs do
    %{
      "novel" => %{
        name: "Novel",
        description: "Full-length fiction with deep character development and world-building",
        gradient: "from-purple-500 to-pink-500",
        features: ["Character Development", "World Building", "AI Writing Assistant", "Chapter Planning"],
        requires_tier: "creator",
        icon: """
        <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.746 0 3.332.477 4.5 1.253v13C19.832 18.477 18.246 18 16.5 18c-1.746 0-3.332.477-4.5 1.253"/>
        </svg>
        """
      },
      "screenplay" => %{
        name: "Screenplay",
        description: "Professional script format for film, TV, and web series",
        gradient: "from-blue-500 to-cyan-500",
        features: ["Industry Formatting", "Scene Breakdown", "Character Dialogue", "Collaboration"],
        requires_tier: "creator",
        icon: """
        <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 4V2a1 1 0 011-1h8a1 1 0 011 1v2m-9 0h10M7 4v16a1 1 0 001 1h8a1 1 0 001-1V4M7 4H5a1 1 0 00-1 1v16a1 1 0 001 1h2M17 4h2a1 1 0 011 1v16a1 1 0 01-1 1h-2"/>
        </svg>
        """
      },
      "comic_book" => %{
        name: "Comic Book",
        description: "Visual storytelling with panels, characters, and artist collaboration",
        gradient: "from-green-500 to-teal-500",
        features: ["Panel Layouts", "Artist Collaboration", "Character Design", "Visual Scripting"],
        requires_tier: "creator",
        icon: """
        <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
        </svg>
        """
      },
      "storyboard" => %{
        name: "Visual Storyboard",
        description: "Plan visual sequences with AI-generated imagery",
        gradient: "from-yellow-500 to-orange-500",
        features: ["AI Image Generation", "Shot Planning", "Camera Angles", "Sequence Timing"],
        requires_tier: "creator",
        icon: """
        <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
        </svg>
        """
      },
      "customer_story" => %{
        name: "Customer Story",
        description: "Document customer journeys and business outcomes",
        gradient: "from-indigo-500 to-purple-500",
        features: ["Journey Mapping", "Touchpoint Analysis", "Data Integration", "Success Metrics"],
        requires_tier: nil,
        icon: """
        <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
        </svg>
        """
      },
      "personal_narrative" => %{
        name: "Personal Story",
        description: "Share your personal journey and experiences",
        gradient: "from-pink-500 to-rose-500",
        features: ["Life Timeline", "Memory Integration", "Photo Sync", "Audio Recording"],
        requires_tier: nil,
        icon: """
        <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z"/>
        </svg>
        """
      }
    }
  end

  defp structure_display_name(atom) when is_atom(atom) do
    atom
    |> Atom.to_string()
    |> String.split("_")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp structure_display_name(string) when is_binary(string) do
    string
    |> String.split("_")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp get_structure_description(story_type, structure) do
    descriptions = %{
      novel: %{
        three_act: "Classic beginning, middle, end with detailed character arcs",
        hero_journey: "Campbell's monomyth - perfect for transformation stories",
        character_driven: "Focus on internal conflict and character growth",
        mystery: "Structured reveal of clues and red herrings",
        romance: "Relationship development with emotional beats"
      },
      screenplay: %{
        feature_film: "90-120 page three-act structure for theatrical release",
        short_film: "15-30 page condensed dramatic structure",
        tv_episode: "Episodic structure with commercial breaks",
        documentary: "Non-fiction storytelling with interview integration"
      },
      comic_book: %{
        single_issue: "22-page complete story with visual impact",
        story_arc: "Multi-issue narrative spanning several comics",
        graphic_novel: "Long-form visual narrative"
      }
    }

    get_in(descriptions, [story_type, structure]) || "Structured approach to your story"
  end

  defp get_structure_benefits(story_type, structure) do
    benefits = %{
      novel: %{
        three_act: "Proven structure, easy to follow, satisfying resolution",
        hero_journey: "Universal appeal, character transformation, mythic resonance",
        character_driven: "Deep emotional connection, literary merit, character focus"
      },
      screenplay: %{
        feature_film: "Industry standard, marketable, complete narrative",
        short_film: "Festival friendly, focused story, quick production"
      }
    }

    get_in(benefits, [story_type, structure]) || "Effective storytelling approach"
  end

  defp feature_display_name(feature) when is_atom(feature) do
    feature
    |> Atom.to_string()
    |> String.split("_")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp purpose_display_name(purpose) when is_atom(purpose) do
    case purpose do
      :setup -> "Establish characters and world"
      :development -> "Build conflict and tension"
      :resolution -> "Resolve conflicts and conclude"
      :hook -> "Grab reader attention"
      :escalation -> "Raise the stakes"
      :climax -> "Peak dramatic moment"
      _ -> purpose |> Atom.to_string() |> String.capitalize()
    end
  end

  defp ai_content_types(story_type) do
    case story_type do
      :novel -> ["character", "plot", "world", "dialogue"]
      :screenplay -> ["scene", "character", "dialogue", "action"]
      :comic_book -> ["panel", "character", "action", "dialogue"]
      :storyboard -> ["shot", "composition", "transition", "timing"]
      _ -> ["content", "structure", "ideas"]
    end
  end

  defp content_type_display_name(type) do
    case type do
      "character" -> "Character Development"
      "plot" -> "Plot Ideas"
      "world" -> "World Building"
      "dialogue" -> "Dialogue Enhancement"
      "scene" -> "Scene Suggestions"
      "panel" -> "Panel Layout Ideas"
      "shot" -> "Shot Composition"
      "composition" -> "Visual Composition"
      _ -> String.capitalize(type)
    end
  end

  defp number_with_commas(number) do
    number
    |> Integer.to_string()
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.join(",")
    |> String.reverse()
  end
end
