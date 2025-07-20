# lib/frestyl_web/live/enhanced_story_live/workspace.ex
defmodule FrestylWeb.EnhancedStoryLive.Workspace do
  use FrestylWeb, :live_view

  alias Frestyl.Stories.{EnhancedStoryStructure, VisualAIGenerator, EnhancedTemplates}
  alias Frestyl.Studio

  def mount(%{"id" => story_id}, _session, socket) do
    story = Frestyl.Repo.get!(EnhancedStoryStructure, story_id)

    socket = socket
    |> assign(:story, story)
    |> assign(:page_title, story.title)
    |> assign(:active_tool, "outline")
    |> assign(:workspace_mode, get_workspace_mode(story.story_type))
    |> assign(:ai_panel_open, false)
    |> assign(:collaboration_panel_open, false)
    |> assign(:current_content, "")
    |> assign(:ai_generations, [])
    |> assign(:word_count, story.current_word_count || 0)
    |> assign(:completion_percentage, story.completion_percentage || 0.0)
    |> load_story_content()

    {:ok, socket}
  end

  def handle_event("switch_tool", %{"tool" => tool}, socket) do
    {:noreply, assign(socket, :active_tool, tool)}
  end

  def handle_event("toggle_ai_panel", _params, socket) do
    {:noreply, assign(socket, :ai_panel_open, !socket.assigns.ai_panel_open)}
  end

  def handle_event("generate_ai_content", %{"content_type" => content_type, "prompt" => prompt}, socket) do
    user = socket.assigns.current_user
    story = socket.assigns.story

    case VisualAIGenerator.generate_storyboard_image(story.id, %{
      description: prompt,
      shot_type: :medium_shot,
      camera_movement: :static
    }, user) do
      {:ok, generation} ->
        {:noreply,
         socket
         |> assign(:ai_generations, [generation | socket.assigns.ai_generations])
         |> put_flash(:info, "AI content generated successfully!")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to generate content: #{reason}")}
    end
  end

  def handle_event("save_content", %{"content" => content}, socket) do
    story = socket.assigns.story

    # Update word count
    word_count = count_words(content)
    completion_percentage = calculate_completion(story, word_count)

    case update_story_content(story, content, word_count, completion_percentage) do
      {:ok, updated_story} ->
        {:noreply,
         socket
         |> assign(:story, updated_story)
         |> assign(:word_count, word_count)
         |> assign(:completion_percentage, completion_percentage)
         |> put_flash(:info, "Content saved successfully!")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to save content")}
    end
  end

  def handle_event("create_character", %{"character" => character_params}, socket) do
    story = socket.assigns.story

    case add_character_to_story(story, character_params) do
      {:ok, updated_story} ->
        {:noreply,
         socket
         |> assign(:story, updated_story)
         |> put_flash(:info, "Character created successfully!")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to create character: #{reason}")}
    end
  end

  def handle_event("generate_storyboard_shot", %{"shot_data" => shot_data}, socket) do
    user = socket.assigns.current_user
    story = socket.assigns.story

    shot_params = %{
      description: shot_data["description"],
      shot_type: String.to_atom(shot_data["shot_type"]),
      camera_movement: String.to_atom(shot_data["camera_movement"])
    }

    case VisualAIGenerator.generate_storyboard_image(story.id, shot_params, user) do
      {:ok, generation} ->
        {:noreply,
         socket
         |> assign(:ai_generations, [generation | socket.assigns.ai_generations])
         |> put_flash(:info, "Storyboard shot generated!")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to generate shot: #{reason}")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="h-screen flex bg-gray-50">
      <!-- Left Sidebar - Tools -->
      <div class="w-64 bg-white shadow-lg border-r border-gray-200 flex flex-col">
        <%= render_tool_sidebar(assigns) %>
      </div>

      <!-- Main Workspace -->
      <div class="flex-1 flex flex-col">
        <!-- Top Header -->
        <div class="h-16 bg-white border-b border-gray-200 flex items-center justify-between px-6">
          <%= render_workspace_header(assigns) %>
        </div>

        <!-- Content Area -->
        <div class="flex-1 flex">
          <!-- Main Content -->
          <div class={[
            "flex-1 overflow-hidden",
            if(@ai_panel_open, do: "mr-80", else: "mr-0")
          ]}>
            <%= render_workspace_content(assigns) %>
          </div>

          <!-- AI Assistant Panel -->
          <%= if @ai_panel_open do %>
            <div class="w-80 bg-white border-l border-gray-200 flex flex-col">
              <%= render_ai_assistant_panel(assigns) %>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp render_tool_sidebar(assigns) do
    ~H"""
    <div class="flex flex-col h-full">
      <!-- Story Info -->
      <div class="p-4 border-b border-gray-200">
        <h2 class="font-semibold text-gray-900 truncate"><%= @story.title %></h2>
        <p class="text-sm text-gray-500"><%= story_type_display(@story.story_type) %></p>

        <!-- Progress -->
        <div class="mt-3">
          <div class="flex justify-between text-sm text-gray-600 mb-1">
            <span>Progress</span>
            <span><%= Float.round(@completion_percentage, 1) %>%</span>
          </div>
          <div class="w-full bg-gray-200 rounded-full h-2">
            <div
              class="bg-indigo-600 h-2 rounded-full transition-all duration-300"
              style={"width: #{@completion_percentage}%"}
            ></div>
          </div>
        </div>

        <!-- Word Count (for applicable types) -->
        <%= if @story.story_type in ["novel", "screenplay"] do %>
          <div class="mt-2 text-sm text-gray-600">
            <%= number_with_commas(@word_count) %> words
            <%= if @story.target_word_count do %>
              / <%= number_with_commas(@story.target_word_count) %>
            <% end %>
          </div>
        <% end %>
      </div>

      <!-- Tool Navigation -->
      <nav class="flex-1 overflow-y-auto p-4 space-y-2">
        <%= for {tool_id, tool_config} <- get_tools_for_story_type(@story.story_type) do %>
          <button
            phx-click="switch_tool"
            phx-value-tool={tool_id}
            class={[
              "w-full flex items-center px-3 py-2 rounded-lg text-left transition-colors",
              if(@active_tool == tool_id,
                 do: "bg-indigo-100 text-indigo-700 border border-indigo-200",
                 else: "text-gray-700 hover:bg-gray-100")
            ]}
          >
            <div class="w-5 h-5 mr-3">
              <%= Phoenix.HTML.raw(tool_config.icon) %>
            </div>
            <span class="font-medium"><%= tool_config.name %></span>
          </button>
        <% end %>
      </nav>

      <!-- Bottom Actions -->
      <div class="p-4 border-t border-gray-200 space-y-2">
        <button
          phx-click="toggle_ai_panel"
          class={[
            "w-full flex items-center px-3 py-2 rounded-lg transition-colors",
            if(@ai_panel_open,
               do: "bg-purple-100 text-purple-700",
               else: "text-gray-700 hover:bg-gray-100")
          ]}
        >
          <svg class="w-5 h-5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"/>
          </svg>
          <span class="font-medium">AI Assistant</span>
        </button>

        <button class="w-full flex items-center px-3 py-2 rounded-lg text-gray-700 hover:bg-gray-100 transition-colors">
          <svg class="w-5 h-5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197m13.5-9a2.5 2.5 0 11-5 0 2.5 2.5 0 015 0z"/>
          </svg>
          <span class="font-medium">Collaborate</span>
        </button>
      </div>
    </div>
    """
  end

  defp render_workspace_header(assigns) do
    ~H"""
    <div class="flex items-center space-x-4">
      <h1 class="text-xl font-semibold text-gray-900">
        <%= tool_display_name(@active_tool) %>
      </h1>

      <%= if @active_tool == "storyboard" do %>
        <div class="flex items-center space-x-2">
          <button class="px-3 py-1 bg-indigo-600 text-white rounded-md text-sm hover:bg-indigo-700">
            Generate Shot
          </button>
          <button class="px-3 py-1 bg-green-600 text-white rounded-md text-sm hover:bg-green-700">
            Add Sequence
          </button>
        </div>
      <% end %>
    </div>

    <div class="flex items-center space-x-4">
      <!-- Auto-save indicator -->
      <div class="flex items-center text-sm text-gray-500">
        <div class="w-2 h-2 bg-green-400 rounded-full mr-2"></div>
        <span>Auto-saved</span>
      </div>

      <!-- Export Options -->
      <div class="relative">
        <select class="text-sm border border-gray-300 rounded-md px-3 py-1 bg-white">
          <option>Export...</option>
          <%= case @story.story_type do %>
            <% "novel" -> %>
              <option value="docx">Word Document</option>
              <option value="pdf">PDF Manuscript</option>
              <option value="epub">EPUB eBook</option>
            <% "screenplay" -> %>
              <option value="pdf">PDF Screenplay</option>
              <option value="fdx">Final Draft</option>
              <option value="fountain">Fountain</option>
            <% "comic_book" -> %>
              <option value="pdf">PDF Comic</option>
              <option value="cbz">CBZ Archive</option>
            <% "storyboard" -> %>
              <option value="pdf">PDF Storyboard</option>
              <option value="video">Video Preview</option>
            <% _ -> %>
              <option value="pdf">PDF</option>
              <option value="web">Web Story</option>
          <% end %>
        </select>
      </div>

      <!-- Share Button -->
      <button class="px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 transition-colors">
        Share
      </button>
    </div>
    """
  end

  defp render_workspace_content(assigns) do
    ~H"""
    <div class="h-full overflow-hidden">
      <%= case @active_tool do %>
        <% "outline" -> %>
          <%= render_outline_tool(assigns) %>
        <% "characters" -> %>
          <%= render_characters_tool(assigns) %>
        <% "world" -> %>
          <%= render_world_building_tool(assigns) %>
        <% "writing" -> %>
          <%= render_writing_tool(assigns) %>
        <% "screenplay" -> %>
          <%= render_screenplay_tool(assigns) %>
        <% "storyboard" -> %>
          <%= render_storyboard_tool(assigns) %>
        <% "comic_panels" -> %>
          <%= render_comic_tool(assigns) %>
        <% "customer_journey" -> %>
          <%= render_customer_journey_tool(assigns) %>
        <% _ -> %>
          <%= render_default_tool(assigns) %>
      <% end %>
    </div>
    """
  end

  defp render_default_tool(assigns) do
    ~H"""
    <div class="h-full flex items-center justify-center">
      <div class="text-center">
        <div class="w-24 h-24 mx-auto bg-gray-100 rounded-full flex items-center justify-center mb-4">
          <svg class="w-12 h-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"/>
          </svg>
        </div>
        <h3 class="text-lg font-medium text-gray-900 mb-2">Select a Tool</h3>
        <p class="text-gray-600">Choose a tool from the sidebar to start working on your story.</p>
      </div>
    </div>
    """
  end

  defp render_outline_tool(assigns) do
    ~H"""
    <div class="h-full flex flex-col">
      <!-- Outline Header -->
      <div class="p-6 bg-white border-b border-gray-200">
        <div class="flex items-center justify-between">
          <h2 class="text-lg font-semibold text-gray-900">Story Outline</h2>
          <button class="px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700">
            Add Chapter
          </button>
        </div>
      </div>

      <!-- Outline Content -->
      <div class="flex-1 overflow-y-auto p-6">
        <%= if @story.template_data && @story.template_data["chapters"] do %>
          <div class="space-y-6">
            <%= for {chapter, index} <- Enum.with_index(@story.template_data["chapters"]) do %>
              <div class="bg-white rounded-lg border border-gray-200 p-6 hover:shadow-md transition-shadow">
                <div class="flex items-center justify-between mb-4">
                  <h3 class="text-lg font-medium text-gray-900">
                    <%= index + 1 %>. <%= chapter["title"] %>
                  </h3>
                  <div class="flex items-center space-x-2">
                    <%= if chapter["target_word_count"] do %>
                      <span class="text-sm text-gray-500">
                        ~<%= number_with_commas(chapter["target_word_count"]) %> words
                      </span>
                    <% end %>
                    <button class="text-indigo-600 hover:text-indigo-800">
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
                      </svg>
                    </button>
                  </div>
                </div>

                <!-- Chapter Description -->
                <%= if chapter["description"] do %>
                  <p class="text-gray-700 mb-4"><%= chapter["description"] %></p>
                <% end %>

                <!-- Scenes (for applicable story types) -->
                <%= if chapter["suggested_scenes"] do %>
                  <div class="mt-4">
                    <h4 class="text-sm font-medium text-gray-700 mb-2">Scenes:</h4>
                    <div class="space-y-2">
                      <%= for scene <- chapter["suggested_scenes"] do %>
                        <div class="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                          <div>
                            <span class="font-medium text-gray-900"><%= scene["title"] %></span>
                            <span class="text-sm text-gray-600 ml-2">- <%= scene["purpose"] %></span>
                          </div>
                          <button class="text-green-600 hover:text-green-800 text-sm font-medium">
                            Start Writing
                          </button>
                        </div>
                      <% end %>
                    </div>
                  </div>
                <% end %>

                <!-- Progress Bar -->
                <div class="mt-4 pt-4 border-t border-gray-100">
                  <div class="flex justify-between text-sm text-gray-600 mb-1">
                    <span>Chapter Progress</span>
                    <span>0%</span>
                  </div>
                  <div class="w-full bg-gray-200 rounded-full h-2">
                    <div class="bg-green-500 h-2 rounded-full" style="width: 0%"></div>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        <% else %>
          <div class="text-center py-12">
            <div class="w-24 h-24 mx-auto bg-gray-100 rounded-full flex items-center justify-center mb-4">
              <svg class="w-12 h-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
              </svg>
            </div>
            <h3 class="text-lg font-medium text-gray-900 mb-2">No Outline Yet</h3>
            <p class="text-gray-600 mb-6">Create your story structure to get started.</p>
            <button class="px-6 py-3 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700">
              Create Outline
            </button>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_characters_tool(assigns) do
    ~H"""
    <div class="h-full flex flex-col">
      <!-- Characters Header -->
      <div class="p-6 bg-white border-b border-gray-200">
        <div class="flex items-center justify-between">
          <h2 class="text-lg font-semibold text-gray-900">Character Development</h2>
          <button class="px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700">
            Add Character
          </button>
        </div>
      </div>

      <!-- Characters Content -->
      <div class="flex-1 overflow-y-auto p-6">
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          <!-- Character Cards -->
          <%= for character <- get_story_characters(@story) do %>
            <div class="bg-white rounded-lg border border-gray-200 p-6 hover:shadow-md transition-shadow">
              <!-- Character Avatar -->
              <div class="w-16 h-16 bg-gradient-to-r from-indigo-500 to-purple-500 rounded-full mx-auto mb-4 flex items-center justify-center">
                <span class="text-white font-bold text-xl">
                  <%= String.first(character["name"] || "?") %>
                </span>
              </div>

              <!-- Character Info -->
              <h3 class="text-lg font-medium text-gray-900 text-center mb-2">
                <%= character["name"] || "Unnamed Character" %>
              </h3>

              <%= if character["role"] do %>
                <p class="text-sm text-gray-600 text-center mb-4">
                  <%= character["role"] %>
                </p>
              <% end %>

              <!-- Character Traits -->
              <%= if character["traits"] do %>
                <div class="mb-4">
                  <div class="text-xs font-medium text-gray-700 mb-2">Key Traits:</div>
                  <div class="flex flex-wrap gap-1">
                    <%= for trait <- character["traits"] do %>
                      <span class="px-2 py-1 bg-gray-100 text-gray-700 text-xs rounded-full">
                        <%= trait %>
                      </span>
                    <% end %>
                  </div>
                </div>
              <% end %>

              <!-- Quick Actions -->
              <div class="flex space-x-2">
                <button class="flex-1 px-3 py-2 bg-indigo-50 text-indigo-700 rounded-md text-sm hover:bg-indigo-100">
                  Edit
                </button>
                <button class="flex-1 px-3 py-2 bg-green-50 text-green-700 rounded-md text-sm hover:bg-green-100">
                  Arc
                </button>
              </div>
            </div>
          <% end %>

          <!-- Add Character Card -->
          <div class="bg-gray-50 border-2 border-dashed border-gray-300 rounded-lg p-6 flex flex-col items-center justify-center hover:border-gray-400 transition-colors cursor-pointer">
            <div class="w-16 h-16 bg-gray-200 rounded-full mb-4 flex items-center justify-center">
              <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
              </svg>
            </div>
            <span class="text-gray-600 font-medium">Add Character</span>
          </div>
        </div>

        <!-- Character Relationships -->
        <%= if length(get_story_characters(@story)) > 1 do %>
          <div class="mt-12">
            <h3 class="text-lg font-semibold text-gray-900 mb-6">Character Relationships</h3>
            <div class="bg-white rounded-lg border border-gray-200 p-6">
              <div class="text-center text-gray-500">
                <svg class="w-12 h-12 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"/>
                </svg>
                <p>Relationship mapping coming soon</p>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_storyboard_tool(assigns) do
    ~H"""
    <div class="h-full flex flex-col">
      <!-- Storyboard Header -->
      <div class="p-6 bg-white border-b border-gray-200">
        <div class="flex items-center justify-between">
          <h2 class="text-lg font-semibold text-gray-900">Visual Storyboard</h2>
          <div class="flex space-x-2">
            <button
              phx-click="generate_storyboard_shot"
              phx-value-shot_data={Jason.encode!(%{
                description: "Wide establishing shot of the scene",
                shot_type: "wide_shot",
                camera_movement: "static"
              })}
              class="px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700"
            >
              Generate Shot
            </button>
            <button class="px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700">
              Add Sequence
            </button>
          </div>
        </div>
      </div>

      <!-- Storyboard Content -->
      <div class="flex-1 overflow-y-auto p-6">
        <!-- Storyboard Grid -->
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          <!-- Generated Shots -->
          <%= for generation <- @ai_generations do %>
            <%= if generation.generation_type == "image" do %>
              <div class="bg-white rounded-lg border border-gray-200 overflow-hidden">
                <!-- Shot Image -->
                <div class="aspect-video bg-gray-100 relative">
                  <%= if generation.result && generation.result["image_url"] do %>
                    <img
                      src={generation.result["image_url"]}
                      alt="Storyboard shot"
                      class="w-full h-full object-cover"
                    />
                  <% else %>
                    <div class="w-full h-full flex items-center justify-center">
                      <svg class="w-12 h-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
                      </svg>
                    </div>
                  <% end %>

                  <!-- Shot Number -->
                  <div class="absolute top-2 left-2 bg-black bg-opacity-75 text-white px-2 py-1 rounded text-sm">
                    Shot 1
                  </div>
                </div>

                <!-- Shot Details -->
                <div class="p-4">
                  <h4 class="font-medium text-gray-900 mb-2">
                    <%= generation.context["shot_type"] || "Medium Shot" %>
                  </h4>
                  <p class="text-sm text-gray-600 mb-3">
                    <%= String.slice(generation.prompt, 0, 100) %><%= if String.length(generation.prompt) > 100, do: "..." %>
                  </p>

                  <!-- Shot Controls -->
                  <div class="flex space-x-2">
                    <button class="flex-1 px-3 py-2 bg-gray-100 text-gray-700 rounded text-sm hover:bg-gray-200">
                      Edit
                    </button>
                    <button class="flex-1 px-3 py-2 bg-indigo-100 text-indigo-700 rounded text-sm hover:bg-indigo-200">
                      Regenerate
                    </button>
                  </div>
                </div>
              </div>
            <% end %>
          <% end %>

          <!-- Add Shot Card -->
          <div class="bg-gray-50 border-2 border-dashed border-gray-300 rounded-lg aspect-video flex flex-col items-center justify-center hover:border-gray-400 transition-colors cursor-pointer">
            <div class="text-center">
              <svg class="w-12 h-12 text-gray-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
              </svg>
              <span class="text-gray-600 font-medium">Add Shot</span>
              <p class="text-gray-500 text-sm mt-1">Describe your scene</p>
            </div>
          </div>
        </div>

        <!-- Shot Planning Form -->
        <div class="mt-8 bg-white rounded-lg border border-gray-200 p-6">
          <h3 class="text-lg font-semibold text-gray-900 mb-4">Plan New Shot</h3>

          <.form :let={f} for={%{}} as={:shot} phx-submit="generate_storyboard_shot" class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Shot Description</label>
              <.input field={f[:description]}
                  type="text"
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-indigo-500 focus:border-indigo-500",
                  placeholder="Describe what happens in this shot...",
                  required="true" />
            </div>

            <div class="grid grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Shot Type</label>
                <.input field={f[:shot_type]}
                    type="select"
                    options={[
                      {"Close-up", "close_up"},
                      {"Medium Shot", "medium"},
                      {"Wide Shot", "wide"}
                    ]}
                    prompt="Select shot type"
                    class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-indigo-500 focus:border-indigo-500" />
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Camera Movement</label>
                <.input field={f[:camera_movement]}
                    type="select"
                    options={[
                      {"Static", "static"},
                      {"Pan", "pan"},
                      {"Zoom", "zoom"}
                    ]}
                    prompt="Select movement"
                    class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-indigo-500 focus:border-indigo-500" />
              </div>
            </div>

            <button
              type="submit"
              class="w-full px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 transition-colors"
            >
              Generate Storyboard Shot
            </button>
          </.form>
        </div>
      </div>
    </div>
    """
  end

  defp render_ai_assistant_panel(assigns) do
    ~H"""
    <div class="h-full flex flex-col">
      <!-- AI Panel Header -->
      <div class="p-4 bg-gradient-to-r from-purple-600 to-indigo-600 text-white">
        <div class="flex items-center justify-between">
          <h3 class="font-semibold">AI Assistant</h3>
          <button phx-click="toggle_ai_panel" class="text-purple-200 hover:text-white">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </button>
        </div>
        <p class="text-purple-100 text-sm mt-1">
          Smart suggestions for your <%= story_type_display(@story.story_type) %>
        </p>
      </div>

      <!-- AI Content -->
      <div class="flex-1 overflow-y-auto p-4 space-y-4">
        <!-- Context-Aware Suggestions -->
        <div class="bg-gradient-to-r from-blue-50 to-indigo-50 rounded-lg p-4 border border-indigo-100">
          <h4 class="font-medium text-indigo-900 mb-2">Smart Suggestions</h4>
          <div class="space-y-3">
            <%= for suggestion <- get_contextual_suggestions(@story, @active_tool) do %>
              <div class="bg-white rounded-md p-3 border border-indigo-100">
                <div class="flex items-start space-x-2">
                  <div class="w-6 h-6 bg-indigo-500 rounded-full flex items-center justify-center flex-shrink-0 mt-0.5">
                    <svg class="w-3 h-3 text-white" fill="currentColor" viewBox="0 0 20 20">
                      <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z"/>
                    </svg>
                  </div>
                  <div class="flex-1">
                    <p class="text-sm text-gray-700"><%= suggestion.content %></p>
                    <button class="text-xs text-indigo-600 hover:text-indigo-800 mt-1">
                      Apply suggestion
                    </button>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </div>

        <!-- AI Content Generation -->
        <div class="bg-white rounded-lg border border-gray-200 p-4">
          <h4 class="font-medium text-gray-900 mb-3">Generate Content</h4>

          <.form :let={f} for={%{}} as={:ai_request} phx-submit="generate_ai_content" class="space-y-3">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Content Type</label>
              <.input field={f[:content_type]}
                  type="select"
                  options={[
                    {"Story Outline", "outline"},
                    {"Character Description", "character"},
                    {"Scene Description", "scene"},
                    {"Dialogue", "dialogue"}
                  ]}
                  prompt="Content type"
                  class="w-full px-3 py-2 border border-gray-300 rounded-md text-sm focus:ring-indigo-500 focus:border-indigo-500" />
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Prompt</label>
              <.input field={f[:prompt]}
                  type="textarea"
                  rows="4"
                  class="..."
                  placeholder="Describe what you want to generate..." />
            </div>

            <button
              type="submit"
              class="w-full px-4 py-2 bg-purple-600 text-white rounded-md hover:bg-purple-700 transition-colors text-sm"
            >
              Generate with AI
            </button>
          </.form>
        </div>

        <!-- Recent AI Generations -->
        <%= if length(@ai_generations) > 0 do %>
          <div class="bg-white rounded-lg border border-gray-200 p-4">
            <h4 class="font-medium text-gray-900 mb-3">Recent Generations</h4>
            <div class="space-y-3">
              <%= for generation <- Enum.take(@ai_generations, 3) do %>
                <div class="border border-gray-100 rounded-md p-3">
                  <div class="flex items-center justify-between mb-2">
                    <span class="text-xs font-medium text-gray-500 uppercase">
                      <%= generation.generation_type %>
                    </span>
                    <span class="text-xs text-gray-400">
                      <%= format_time_ago(generation.inserted_at) %>
                    </span>
                  </div>

                  <%= if generation.generation_type == "image" && generation.result["image_url"] do %>
                    <img
                      src={generation.result["image_url"]}
                      alt="Generated content"
                      class="w-full h-20 object-cover rounded border mb-2"
                    />
                  <% end %>

                  <p class="text-sm text-gray-700">
                    <%= String.slice(generation.prompt, 0, 80) %><%= if String.length(generation.prompt) > 80, do: "..." %>
                  </p>

                  <div class="flex space-x-2 mt-2">
                    <button class="text-xs text-indigo-600 hover:text-indigo-800">Use</button>
                    <button class="text-xs text-gray-500 hover:text-gray-700">Edit</button>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>

        <!-- AI Writing Tools (for applicable story types) -->
        <%= if @story.story_type in ["novel", "screenplay"] do %>
          <div class="bg-white rounded-lg border border-gray-200 p-4">
            <h4 class="font-medium text-gray-900 mb-3">Writing Tools</h4>
            <div class="space-y-2">
              <button class="w-full text-left px-3 py-2 text-sm text-gray-700 hover:bg-gray-50 rounded-md">
                📝 Continue Writing
              </button>
              <button class="w-full text-left px-3 py-2 text-sm text-gray-700 hover:bg-gray-50 rounded-md">
                🎭 Improve Dialogue
              </button>
              <button class="w-full text-left px-3 py-2 text-sm text-gray-700 hover:bg-gray-50 rounded-md">
                🔍 Check Consistency
              </button>
              <button class="w-full text-left px-3 py-2 text-sm text-gray-700 hover:bg-gray-50 rounded-md">
                📊 Analyze Pacing
              </button>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Helper Functions
  defp get_workspace_mode(story_type) do
    case story_type do
      "novel" -> "manuscript"
      "screenplay" -> "script"
      "comic_book" -> "visual"
      "storyboard" -> "visual"
      "customer_story" -> "journey"
      _ -> "standard"
    end
  end

  defp load_story_content(socket) do
    # Load existing content, characters, etc.
    socket
  end

  defp get_tools_for_story_type(story_type) do
    base_tools = %{
      "outline" => %{
        name: "Outline",
        icon: """
        <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/>
        </svg>
        """
      },
      "characters" => %{
        name: "Characters",
        icon: """
        <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
        </svg>
        """
      }
    }

    story_specific_tools = case story_type do
      "novel" -> %{
        "world" => %{
          name: "World Building",
          icon: """
          <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3.055 11H5a2 2 0 012 2v1a2 2 0 002 2 2 2 0 012 2v2.945M8 3.935V5.5A2.5 2.5 0 0010.5 8h.5a2 2 0 012 2 2 2 0 104 0 2 2 0 012-2h1.064M15 20.488V18a2 2 0 012-2h3.064M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
          </svg>
          """
        },
        "writing" => %{
          name: "Manuscript",
          icon: """
          <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
          </svg>
          """
        }
      }
      "screenplay" -> %{
        "screenplay" => %{
          name: "Script",
          icon: """
          <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 4V2a1 1 0 011-1h8a1 1 0 011 1v2M7 4h10M7 4v16a1 1 0 001 1h8a1 1 0 001-1V4"/>
          </svg>
          """
        }
      }
      "comic_book" -> %{
        "comic_panels" => %{
          name: "Panels",
          icon: """
          <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 5a1 1 0 011-1h14a1 1 0 011 1v2a1 1 0 01-1 1H5a1 1 0 01-1-1V5zM4 13a1 1 0 011-1h6a1 1 0 011 1v6a1 1 0 01-1 1H5a1 1 0 01-1-1v-6zM16 13a1 1 0 011-1h2a1 1 0 011 1v6a1 1 0 01-1 1h-2a1 1 0 01-1-1v-6z"/>
          </svg>
          """
        }
      }
      "storyboard" -> %{
        "storyboard" => %{
          name: "Storyboard",
          icon: """
          <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
          </svg>
          """
        }
      }
      "customer_story" -> %{
        "customer_journey" => %{
          name: "Journey Map",
          icon: """
          <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/>
          </svg>
          """
        }
      }
      _ -> %{}
    end

    Map.merge(base_tools, story_specific_tools)
  end

  defp get_story_characters(story) do
    story.character_data["main_characters"] || []
  end

  defp get_contextual_suggestions(story, active_tool) do
    # Generate AI suggestions based on current context
    case {story.story_type, active_tool} do
      {"novel", "outline"} -> [
        %{type: "structure", content: "Consider adding a subplot to deepen character development"},
        %{type: "pacing", content: "Your second act could benefit from a stronger midpoint reversal"},
        %{type: "character", content: "Ensure each chapter advances character arcs"}
      ]
      {"screenplay", "screenplay"} -> [
        %{type: "formatting", content: "Remember to enter scenes as late as possible"},
        %{type: "dialogue", content: "Each character should have a distinct voice"},
        %{type: "visual", content: "Show don't tell - use action over exposition"}
      ]
      {"storyboard", "storyboard"} -> [
        %{type: "composition", content: "Use the rule of thirds for dynamic framing"},
        %{type: "pacing", content: "Vary shot sizes to control visual rhythm"},
        %{type: "continuity", content: "Check eyeline matches between shots"}
      ]
      _ -> [
        %{type: "general", content: "Focus on clear story structure"},
        %{type: "character", content: "Develop compelling character motivations"}
      ]
    end
  end

  defp get_ai_content_options(story_type) do
    case story_type do
      "novel" -> [
        {"Character Development", "character"},
        {"Plot Ideas", "plot"},
        {"World Building", "world"},
        {"Dialogue", "dialogue"}
      ]
      "screenplay" -> [
        {"Scene Ideas", "scene"},
        {"Character Development", "character"},
        {"Dialogue", "dialogue"},
        {"Action Lines", "action"}
      ]
      "storyboard" -> [
        {"Shot Composition", "shot"},
        {"Camera Movement", "camera"},
        {"Visual Effects", "effects"}
      ]
      _ -> [
        {"Content Ideas", "content"},
        {"Structure", "structure"}
      ]
    end
  end

  defp count_words(content) do
    content
    |> String.split(~r/\s+/)
    |> Enum.reject(&(&1 == ""))
    |> length()
  end

  defp calculate_completion(story, word_count) do
    if story.target_word_count && story.target_word_count > 0 do
      min(word_count / story.target_word_count * 100, 100)
    else
      # For non-word-count based stories, use different metrics
      case story.story_type do
        "comic_book" -> calculate_comic_completion(story)
        "storyboard" -> calculate_storyboard_completion(story)
        _ -> 0.0
      end
    end
  end

  defp calculate_comic_completion(story) do
    # Calculate based on completed panels/pages
    50.0 # Placeholder
  end

  defp calculate_storyboard_completion(story) do
    # Calculate based on completed shots
    30.0 # Placeholder
  end

  defp update_story_content(story, content, word_count, completion_percentage) do
    story
    |> EnhancedStoryStructure.changeset(%{
      current_word_count: word_count,
      completion_percentage: completion_percentage,
      version: story.version + 1
    })
    |> Frestyl.Repo.update()
  end

  defp add_character_to_story(story, character_params) do
    current_characters = story.character_data["main_characters"] || []
    new_character = Map.put(character_params, "id", Ecto.UUID.generate())
    updated_characters = [new_character | current_characters]

    updated_character_data = Map.put(story.character_data, "main_characters", updated_characters)

    story
    |> EnhancedStoryStructure.changeset(%{character_data: updated_character_data})
    |> Frestyl.Repo.update()
  end

  # Additional helper functions
  defp story_type_display(story_type) do
    story_type
    |> String.split("_")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp tool_display_name(tool) do
    tool
    |> String.split("_")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
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

  defp format_time_ago(datetime) do
    # Simple time ago formatting - you'd want to use a proper library
    "2h ago"
  end

  # Placeholder render functions for missing tools
  defp render_world_building_tool(assigns) do
    ~H"""
    <div class="h-full flex items-center justify-center">
      <div class="text-center">
        <h3 class="text-lg font-medium text-gray-900 mb-2">World Building Tool</h3>
        <p class="text-gray-600">Create rich, detailed worlds for your stories.</p>
      </div>
    </div>
    """
  end

  defp render_writing_tool(assigns) do
    ~H"""
    <div class="h-full flex items-center justify-center">
      <div class="text-center">
        <h3 class="text-lg font-medium text-gray-900 mb-2">Writing Tool</h3>
        <p class="text-gray-600">Focus on writing your manuscript.</p>
      </div>
    </div>
    """
  end

  defp render_screenplay_tool(assigns) do
    ~H"""
    <div class="h-full flex items-center justify-center">
      <div class="text-center">
        <h3 class="text-lg font-medium text-gray-900 mb-2">Screenplay Tool</h3>
        <p class="text-gray-600">Professional screenplay formatting and editing.</p>
      </div>
    </div>
    """
  end

  defp render_comic_tool(assigns) do
    ~H"""
    <div class="h-full flex items-center justify-center">
      <div class="text-center">
        <h3 class="text-lg font-medium text-gray-900 mb-2">Comic Panel Tool</h3>
        <p class="text-gray-600">Design comic book layouts and collaborate with artists.</p>
      </div>
    </div>
    """
  end

  defp render_customer_journey_tool(assigns) do
    ~H"""
    <div class="h-full flex items-center justify-center">
      <div class="text-center">
        <h3 class="text-lg font-medium text-gray-900 mb-2">Customer Journey Tool</h3>
        <p class="text-gray-600">Map customer experiences and touchpoints.</p>
      </div>
    </div>
    """
  end
end
