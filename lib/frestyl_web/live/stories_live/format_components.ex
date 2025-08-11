# lib/frestyl_web/live/stories_live/format_components.ex

defmodule FrestylWeb.StoriesLive.FormatComponents do
  @moduledoc """
  Format-specific UI components for the story editor.
  Provides specialized panels and tools for different story formats.
  """

  use Phoenix.Component
  import FrestylWeb.CoreComponents

  @doc """
  Novel-specific editor components
  """
  def novel_editor_tools(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Character Panel -->
      <%= if @show_character_panel do %>
        <div class="bg-white rounded-lg border p-4">
          <div class="flex items-center justify-between mb-3">
            <h3 class="font-medium text-gray-900">Characters</h3>
            <button
              phx-click="add_character"
              class="text-sm text-blue-600 hover:text-blue-700">
              + Add Character
            </button>
          </div>

          <div class="space-y-2">
            <%= for character <- @characters do %>
              <div class="flex items-center justify-between p-2 bg-gray-50 rounded">
                <div>
                  <div class="font-medium text-sm"><%= character.name %></div>
                  <div class="text-xs text-gray-600"><%= character.role %></div>
                </div>
                <button
                  phx-click="edit_character"
                  phx-value-id={character.id}
                  class="text-xs text-gray-500 hover:text-gray-700">
                  Edit
                </button>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>

      <!-- Plot Tracker -->
      <%= if @show_plot_tracker do %>
        <div class="bg-white rounded-lg border p-4">
          <div class="flex items-center justify-between mb-3">
            <h3 class="font-medium text-gray-900">Plot Structure</h3>
            <div class="text-xs text-gray-500">
              <%= @completion_percentage %>% Complete
            </div>
          </div>

          <div class="space-y-2">
            <div class="flex items-center text-sm">
              <div class={[
                "w-3 h-3 rounded-full mr-2",
                if(@current_act >= 1, do: "bg-green-500", else: "bg-gray-300")
              ]}></div>
              <span>Act I - Setup</span>
            </div>
            <div class="flex items-center text-sm">
              <div class={[
                "w-3 h-3 rounded-full mr-2",
                if(@current_act >= 2, do: "bg-green-500", else: "bg-gray-300")
              ]}></div>
              <span>Act II - Confrontation</span>
            </div>
            <div class="flex items-center text-sm">
              <div class={[
                "w-3 h-3 rounded-full mr-2",
                if(@current_act >= 3, do: "bg-green-500", else: "bg-gray-300")
              ]}></div>
              <span>Act III - Resolution</span>
            </div>
          </div>

          <div class="mt-3 pt-3 border-t">
            <div class="text-xs text-gray-600">
              Target: <%= Number.Delimit.number_to_delimited(@word_count_target) %> words
            </div>
            <div class="text-xs text-gray-600">
              Current: <%= Number.Delimit.number_to_delimited(@current_word_count) %> words
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  Screenplay-specific editor components
  """
  def screenplay_editor_tools(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Scene Breakdown -->
      <%= if @show_scene_breakdown do %>
        <div class="bg-white rounded-lg border p-4">
          <div class="flex items-center justify-between mb-3">
            <h3 class="font-medium text-gray-900">Scene Breakdown</h3>
            <button
              phx-click="add_scene"
              class="text-sm text-blue-600 hover:text-blue-700">
              + Add Scene
            </button>
          </div>

          <div class="space-y-2">
            <%= for scene <- @scenes do %>
              <div class="flex items-center justify-between p-2 bg-gray-50 rounded">
                <div>
                  <div class="font-medium text-sm"><%= scene.heading %></div>
                  <div class="text-xs text-gray-600">
                    <%= scene.location %> - <%= scene.time %>
                  </div>
                </div>
                <div class="text-xs text-gray-500">
                  <%= scene.page_count %> pages
                </div>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>

      <!-- Character List -->
      <%= if @character_list_visible do %>
        <div class="bg-white rounded-lg border p-4">
          <h3 class="font-medium text-gray-900 mb-3">Characters</h3>

          <div class="space-y-1">
            <%= for character <- @screenplay_characters do %>
              <div class="flex items-center justify-between text-sm">
                <span class="font-medium"><%= character.name %></span>
                <span class="text-gray-500"><%= character.scene_count %> scenes</span>
              </div>
            <% end %>
          </div>

          <button
            phx-click="add_screenplay_character"
            class="w-full mt-3 py-2 text-sm text-blue-600 border border-blue-200 rounded hover:bg-blue-50">
            + Add Character
          </button>
        </div>
      <% end %>

      <!-- Page Count Tracker -->
      <div class="bg-white rounded-lg border p-4">
        <h3 class="font-medium text-gray-900 mb-3">Page Count</h3>
        <div class="text-center">
          <div class="text-2xl font-bold text-gray-900"><%= @current_page_count %></div>
          <div class="text-sm text-gray-600">of <%= @page_target %> pages</div>
          <div class="w-full bg-gray-200 rounded-full h-2 mt-2">
            <div
              class="bg-blue-600 h-2 rounded-full"
              style={"width: #{min(@current_page_count / @page_target * 100, 100)}%"}>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Case study-specific editor components
  """
  def case_study_editor_tools(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Data Panel -->
      <%= if @show_data_panel do %>
        <div class="bg-white rounded-lg border p-4">
          <div class="flex items-center justify-between mb-3">
            <h3 class="font-medium text-gray-900">Data Sources</h3>
            <button
              phx-click="add_data_source"
              class="text-sm text-blue-600 hover:text-blue-700">
              + Add Data
            </button>
          </div>

          <div class="space-y-2">
            <%= for data_source <- @data_sources do %>
              <div class="flex items-center justify-between p-2 bg-gray-50 rounded">
                <div>
                  <div class="font-medium text-sm"><%= data_source.name %></div>
                  <div class="text-xs text-gray-600"><%= data_source.type %></div>
                </div>
                <button
                  phx-click="view_data_source"
                  phx-value-id={data_source.id}
                  class="text-xs text-blue-600 hover:text-blue-700">
                  View
                </button>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>

      <!-- Stakeholder Panel -->
      <%= if @show_stakeholder_panel do %>
        <div class="bg-white rounded-lg border p-4">
          <div class="flex items-center justify-between mb-3">
            <h3 class="font-medium text-gray-900">Stakeholders</h3>
            <button
              phx-click="add_stakeholder"
              class="text-sm text-blue-600 hover:text-blue-700">
              + Add Stakeholder
            </button>
          </div>

          <div class="space-y-2">
            <%= for stakeholder <- @stakeholders do %>
              <div class="flex items-center justify-between p-2 bg-gray-50 rounded">
                <div>
                  <div class="font-medium text-sm"><%= stakeholder.name %></div>
                  <div class="text-xs text-gray-600"><%= stakeholder.role %></div>
                </div>
                <div class={[
                  "text-xs px-2 py-1 rounded",
                  stakeholder_impact_class(stakeholder.impact)
                ]}>
                  <%= stakeholder.impact %>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>

      <!-- Structure Guide -->
      <%= if @template_guided do %>
        <div class="bg-blue-50 rounded-lg border border-blue-200 p-4">
          <h3 class="font-medium text-blue-900 mb-2">Structure Guide</h3>
          <div class="text-sm text-blue-800 space-y-1">
            <div>✓ Executive Summary</div>
            <div>✓ Problem Statement</div>
            <div class="text-blue-600">→ Solution Overview</div>
            <div class="text-gray-500">• Results & Impact</div>
            <div class="text-gray-500">• Recommendations</div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  Blog series-specific editor components
  """
  def blog_editor_tools(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- SEO Panel -->
      <%= if @show_seo_panel do %>
        <div class="bg-white rounded-lg border p-4">
          <h3 class="font-medium text-gray-900 mb-3">SEO Optimization</h3>

          <div class="space-y-3">
            <div>
              <label class="text-sm font-medium text-gray-700">Focus Keyword</label>
              <input
                type="text"
                phx-blur="update_focus_keyword"
                value={@focus_keyword}
                class="mt-1 block w-full text-sm border-gray-300 rounded-md"
                placeholder="Enter focus keyword">
            </div>

            <div>
              <label class="text-sm font-medium text-gray-700">Meta Description</label>
              <textarea
                phx-blur="update_meta_description"
                rows="2"
                class="mt-1 block w-full text-sm border-gray-300 rounded-md"
                placeholder="Brief description for search results"><%= @meta_description %></textarea>
              <div class="text-xs text-gray-500 mt-1">
                <%= String.length(@meta_description || "") %>/160 characters
              </div>
            </div>

            <div class="grid grid-cols-2 gap-3">
              <div class="text-center">
                <div class="text-lg font-bold text-green-600"><%= @seo_score %></div>
                <div class="text-xs text-gray-600">SEO Score</div>
              </div>
              <div class="text-center">
                <div class="text-lg font-bold text-blue-600"><%= @readability_score %></div>
                <div class="text-xs text-gray-600">Readability</div>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Publishing Panel -->
      <%= if @show_publishing_panel do %>
        <div class="bg-white rounded-lg border p-4">
          <h3 class="font-medium text-gray-900 mb-3">Publishing</h3>

          <div class="space-y-3">
            <div>
              <label class="text-sm font-medium text-gray-700">Publication Status</label>
              <select
                phx-change="update_publication_status"
                class="mt-1 block w-full text-sm border-gray-300 rounded-md">
                <option value="draft" selected={@publication_status == "draft"}>Draft</option>
                <option value="review" selected={@publication_status == "review"}>Ready for Review</option>
                <option value="scheduled" selected={@publication_status == "scheduled"}>Scheduled</option>
                <option value="published" selected={@publication_status == "published"}>Published</option>
              </select>
            </div>

            <div>
              <label class="text-sm font-medium text-gray-700">Categories</label>
              <div class="mt-1 flex flex-wrap gap-1">
                <%= for category <- @categories do %>
                  <span class="inline-flex items-center px-2 py-1 rounded text-xs bg-blue-100 text-blue-800">
                    <%= category %>
                    <button
                      phx-click="remove_category"
                      phx-value-category={category}
                      class="ml-1 text-blue-600 hover:text-blue-800">
                      ×
                    </button>
                  </span>
                <% end %>
              </div>
              <input
                type="text"
                phx-keydown="add_category"
                phx-key="Enter"
                class="mt-2 block w-full text-sm border-gray-300 rounded-md"
                placeholder="Add category...">
            </div>

            <button
              phx-click="preview_social_post"
              class="w-full py-2 text-sm text-blue-600 border border-blue-200 rounded hover:bg-blue-50">
              Preview Social Media Post
            </button>
          </div>
        </div>
      <% end %>

      <!-- Keyword Tracking -->
      <%= if @keyword_tracking do %>
        <div class="bg-white rounded-lg border p-4">
          <h3 class="font-medium text-gray-900 mb-3">Keyword Density</h3>

          <div class="space-y-2">
            <%= for {keyword, density} <- @keyword_densities do %>
              <div class="flex items-center justify-between">
                <span class="text-sm text-gray-700"><%= keyword %></span>
                <div class="flex items-center">
                  <span class="text-sm text-gray-600 mr-2"><%= density %>%</span>
                  <div class="w-16 bg-gray-200 rounded-full h-2">
                    <div
                      class={[
                        "h-2 rounded-full",
                        keyword_density_color(density)
                      ]}
                      style={"width: #{min(density * 10, 100)}%"}>
                    </div>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Helper functions
  defp stakeholder_impact_class(impact) do
    case impact do
      "high" -> "bg-red-100 text-red-800"
      "medium" -> "bg-yellow-100 text-yellow-800"
      "low" -> "bg-green-100 text-green-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end

  defp keyword_density_color(density) when density > 3, do: "bg-red-500"
  defp keyword_density_color(density) when density > 1, do: "bg-green-500"
  defp keyword_density_color(_), do: "bg-yellow-500"
end
