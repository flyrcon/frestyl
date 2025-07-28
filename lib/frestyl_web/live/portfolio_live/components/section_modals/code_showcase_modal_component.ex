# lib/frestyl_web/live/portfolio_live/components/section_modals/code_showcase_modal_component.ex
defmodule FrestylWeb.PortfolioLive.Components.CodeShowcaseModalComponent do
  @moduledoc """
  Specialized modal for editing code showcase sections
  """
  use FrestylWeb, :live_component
  alias FrestylWeb.PortfolioLive.Components.BaseSectionModalComponent

  def update(assigns, socket) do
    content = get_section_content(assigns.editing_section)

    socket = socket
    |> assign(assigns)
    |> assign(:content, content)
    |> assign(:modal_title, "Edit Code Showcase")
    |> assign(:modal_description, "Showcase your coding skills and projects")
    |> assign(:section_type, :code_showcase)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <.live_component
      module={BaseSectionModalComponent}
      id="code-showcase-modal"
      editing_section={@editing_section}
      modal_title={@modal_title}
      modal_description={@modal_description}
      section_type={@section_type}
      myself={@myself}>

      <!-- Code Showcase Specific Fields -->
      <div class="space-y-6">

        <!-- Section Description -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Description</label>
          <textarea
            name="description"
            rows="3"
            class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            placeholder="Brief description of your coding expertise..."><%= Map.get(@content, "description", "") %></textarea>
        </div>

        <!-- Tech Stack -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Tech Stack</label>
          <input
            type="text"
            name="tech_stack"
            value={Enum.join(Map.get(@content, "tech_stack", []), ", ")}
            class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            placeholder="JavaScript, Python, React, Node.js..." />
          <p class="text-sm text-gray-500 mt-1">Separate technologies with commas</p>
        </div>

        <!-- Display Style -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Display Style</label>
          <select
            name="display_style"
            class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
            <option value="tabs" selected={Map.get(@content, "display_style") == "tabs"}>Tabs</option>
            <option value="accordion" selected={Map.get(@content, "display_style") == "accordion"}>Accordion</option>
            <option value="carousel" selected={Map.get(@content, "display_style") == "carousel"}>Carousel</option>
            <option value="grid" selected={Map.get(@content, "display_style") == "grid"}>Grid</option>
          </select>
        </div>

        <!-- Code Examples -->
        <div class="border rounded-lg p-4 bg-gray-50">
          <div class="flex items-center justify-between mb-4">
            <h4 class="font-medium text-gray-900">Code Examples</h4>
            <button
              type="button"
              phx-click="add_code_example"
              phx-target={@myself}
              class="px-3 py-1 bg-blue-600 text-white text-sm rounded-md hover:bg-blue-700 transition-colors">
              + Add Example
            </button>
          </div>

          <div class="space-y-4" id="code-examples-container">
            <%= for {example, index} <- Enum.with_index(Map.get(@content, "code_examples", [])) do %>
              <div class="border rounded-lg p-4 bg-white relative">
                <!-- Remove button -->
                <button
                  type="button"
                  phx-click="remove_code_example"
                  phx-target={@myself}
                  phx-value-index={index}
                  class="absolute top-2 right-2 p-1 text-red-500 hover:text-red-700">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                  </svg>
                </button>

                <!-- Example fields -->
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Example Title</label>
                    <input
                      type="text"
                      name={"code_examples[#{index}][title]"}
                      value={Map.get(example, "title", "")}
                      placeholder="Algorithm Implementation"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Language</label>
                    <select
                      name={"code_examples[#{index}][language]"}
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500">
                      <%= for lang <- get_programming_languages() do %>
                        <option value={lang} selected={Map.get(example, "language") == lang}><%= lang %></option>
                      <% end %>
                    </select>
                  </div>
                </div>

                <div class="mb-4">
                  <label class="block text-xs font-medium text-gray-700 mb-1">Code</label>
                  <textarea
                    name={"code_examples[#{index}][code]"}
                    rows="8"
                    class="w-full px-3 py-2 font-mono text-xs border border-gray-300 rounded focus:ring-1 focus:ring-blue-500 bg-gray-50"
                    placeholder="// Paste your code here..."><%= Map.get(example, "code", "") %></textarea>
                </div>

                <div class="mb-4">
                  <label class="block text-xs font-medium text-gray-700 mb-1">Explanation</label>
                  <textarea
                    name={"code_examples[#{index}][explanation]"}
                    rows="3"
                    class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500"
                    placeholder="Explain the code logic and key concepts..."><%= Map.get(example, "explanation", "") %></textarea>
                </div>

                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Demo URL (Optional)</label>
                    <input
                      type="url"
                      name={"code_examples[#{index}][demo_url]"}
                      value={Map.get(example, "demo_url", "")}
                      placeholder="https://demo.example.com"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">GitHub URL (Optional)</label>
                    <input
                      type="url"
                      name={"code_examples[#{index}][github_url]"}
                      value={Map.get(example, "github_url", "")}
                      placeholder="https://github.com/user/repo"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
                  </div>
                </div>
              </div>
            <% end %>

            <%= if length(Map.get(@content, "code_examples", [])) == 0 do %>
              <div class="text-center py-8 text-gray-500">
                <svg class="w-12 h-12 mx-auto mb-3 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4"/>
                </svg>
                <p>No code examples yet</p>
                <p class="text-sm">Click "Add Example" to showcase your code</p>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Difficulty Level -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Difficulty Level</label>
            <select
              name="difficulty_level"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
              <option value="beginner" selected={Map.get(@content, "difficulty_level") == "beginner"}>Beginner</option>
              <option value="intermediate" selected={Map.get(@content, "difficulty_level") == "intermediate"}>Intermediate</option>
              <option value="advanced" selected={Map.get(@content, "difficulty_level") == "advanced"}>Advanced</option>
              <option value="expert" selected={Map.get(@content, "difficulty_level") == "expert"}>Expert</option>
            </select>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Completion Time</label>
            <input
              type="text"
              name="completion_time"
              value={Map.get(@content, "completion_time", "")}
              placeholder="2-3 hours"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
          </div>
        </div>

      </div>
    </.live_component>
    """
  end

  def handle_event("add_code_example", _params, socket) do
    content = socket.assigns.content
    current_examples = Map.get(content, "code_examples", [])

    new_example = %{
      "title" => "",
      "language" => "javascript",
      "code" => "",
      "explanation" => "",
      "demo_url" => "",
      "github_url" => ""
    }

    updated_content = Map.put(content, "code_examples", current_examples ++ [new_example])

    {:noreply, assign(socket, :content, updated_content)}
  end

  def handle_event("remove_code_example", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    content = socket.assigns.content
    current_examples = Map.get(content, "code_examples", [])

    updated_examples = List.delete_at(current_examples, index)
    updated_content = Map.put(content, "code_examples", updated_examples)

    {:noreply, assign(socket, :content, updated_content)}
  end

  defp get_section_content(section) do
    case section.content do
      content when is_map(content) -> content
      content when is_binary(content) -> %{"description" => content}
      _ -> %{}
    end
  end

  defp get_programming_languages do
    [
      "JavaScript", "TypeScript", "Python", "Java", "C++", "C#", "Go",
      "Rust", "PHP", "Ruby", "Swift", "Kotlin", "Dart", "Elixir",
      "Clojure", "Haskell", "Scala", "R", "MATLAB", "SQL", "HTML", "CSS"
    ]
  end
end
