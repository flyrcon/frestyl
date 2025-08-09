# lib/frestyl_web/live/stories_live/components/editor_tools.ex
defmodule FrestylWeb.StoriesLive.Components.EditorTools do
  use Phoenix.Component
  import FrestylWeb.CoreComponents

  # Manuscript Tools (Novel, Screenplay)
  def render_manuscript_tools(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Character Tracker -->
      <div>
        <h4 class="text-sm font-medium text-gray-900 mb-3">Characters</h4>
        <div class="space-y-2">
          <%= for character <- (@story.character_data["characters"] || []) do %>
            <div class="flex items-center justify-between p-2 bg-gray-50 rounded-lg">
              <span class="text-sm text-gray-700"><%= character["name"] %></span>
              <button class="text-xs text-blue-600 hover:text-blue-700">Edit</button>
            </div>
          <% end %>

          <%= if @permissions.can_edit do %>
            <button class="w-full text-left p-2 text-sm text-gray-500 hover:text-gray-700 hover:bg-gray-50 rounded-lg border-2 border-dashed border-gray-300"
                    phx-click="add_character">
              <svg class="w-4 h-4 inline mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
              </svg>
              Add Character
            </button>
          <% end %>
        </div>
      </div>

      <!-- Plot Timeline -->
      <div>
        <h4 class="text-sm font-medium text-gray-900 mb-3">Plot Points</h4>
        <div class="space-y-2">
          <%= for plot_point <- (@story.timeline_data["plot_points"] || []) do %>
            <div class="flex items-start space-x-2">
              <div class="w-2 h-2 bg-blue-500 rounded-full mt-2"></div>
              <div class="flex-1">
                <p class="text-sm text-gray-700"><%= plot_point["title"] %></p>
                <p class="text-xs text-gray-500"><%= plot_point["description"] %></p>
              </div>
            </div>
          <% end %>

          <%= if @permissions.can_edit do %>
            <button class="w-full text-left p-2 text-sm text-gray-500 hover:text-gray-700 hover:bg-gray-50 rounded-lg border-2 border-dashed border-gray-300"
                    phx-click="add_plot_point">
              Add Plot Point
            </button>
          <% end %>
        </div>
      </div>

      <!-- Writing Goals -->
      <div>
        <h4 class="text-sm font-medium text-gray-900 mb-3">Goals</h4>
        <div class="space-y-3">
          <!-- Word Count Goal -->
          <div class="bg-gray-50 rounded-lg p-3">
            <div class="flex justify-between items-center mb-1">
              <span class="text-sm text-gray-700">Daily Goal</span>
              <span class="text-xs text-gray-500">500 words</span>
            </div>
            <div class="w-full bg-gray-200 rounded-full h-2">
              <div class="bg-blue-600 h-2 rounded-full" style="width: 60%"></div>
            </div>
            <p class="text-xs text-gray-500 mt-1">300 / 500 words today</p>
          </div>

          <!-- Chapter Progress -->
          <div class="bg-gray-50 rounded-lg p-3">
            <div class="flex justify-between items-center mb-1">
              <span class="text-sm text-gray-700">Chapter Progress</span>
              <span class="text-xs text-gray-500">Chapter 3</span>
            </div>
            <div class="w-full bg-gray-200 rounded-full h-2">
              <div class="bg-green-600 h-2 rounded-full" style="width: 80%"></div>
            </div>
            <p class="text-xs text-gray-500 mt-1">4,000 / 5,000 words</p>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Business Tools (Case Study, Data Story)
  def render_business_tools(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Data Sources -->
      <div>
        <h4 class="text-sm font-medium text-gray-900 mb-3">Data Sources</h4>
        <div class="space-y-2">
          <%= for source <- (@story.research_data["data_sources"] || []) do %>
            <div class="flex items-center justify-between p-2 bg-gray-50 rounded-lg">
              <div class="flex items-center space-x-2">
                <div class="w-2 h-2 bg-green-500 rounded-full"></div>
                <span class="text-sm text-gray-700"><%= source["name"] %></span>
              </div>
              <span class="text-xs text-gray-500"><%= source["type"] %></span>
            </div>
          <% end %>

          <%= if @permissions.can_edit do %>
            <button class="w-full text-left p-2 text-sm text-gray-500 hover:text-gray-700 hover:bg-gray-50 rounded-lg border-2 border-dashed border-gray-300"
                    phx-click="add_data_source">
              Connect Data Source
            </button>
          <% end %>
        </div>
      </div>

      <!-- Key Metrics -->
      <div>
        <h4 class="text-sm font-medium text-gray-900 mb-3">Key Metrics</h4>
        <div class="grid grid-cols-2 gap-3">
          <div class="bg-blue-50 rounded-lg p-3 text-center">
            <p class="text-lg font-bold text-blue-600">+47%</p>
            <p class="text-xs text-blue-600">Growth</p>
          </div>
          <div class="bg-green-50 rounded-lg p-3 text-center">
            <p class="text-lg font-bold text-green-600">$2.4M</p>
            <p class="text-xs text-green-600">Revenue</p>
          </div>
          <div class="bg-purple-50 rounded-lg p-3 text-center">
            <p class="text-lg font-bold text-purple-600">1,247</p>
            <p class="text-xs text-purple-600">Users</p>
          </div>
          <div class="bg-orange-50 rounded-lg p-3 text-center">
            <p class="text-lg font-bold text-orange-600">94%</p>
            <p class="text-xs text-orange-600">Satisfaction</p>
          </div>
        </div>
      </div>

      <!-- Stakeholders -->
      <div>
        <h4 class="text-sm font-medium text-gray-900 mb-3">Stakeholders</h4>
        <div class="space-y-2">
          <%= for stakeholder <- (@story.format_metadata["stakeholders"] || []) do %>
            <div class="flex items-center space-x-3 p-2 bg-gray-50 rounded-lg">
              <div class="w-6 h-6 bg-purple-100 rounded-full flex items-center justify-center">
                <span class="text-xs text-purple-600 font-medium">
                  <%= String.first(stakeholder["name"]) %>
                </span>
              </div>
              <div>
                <p class="text-sm text-gray-700"><%= stakeholder["name"] %></p>
                <p class="text-xs text-gray-500"><%= stakeholder["role"] %></p>
              </div>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Business Framework -->
      <div>
        <h4 class="text-sm font-medium text-gray-900 mb-3">Framework</h4>
        <div class="space-y-2">
          <div class="flex items-center justify-between p-2 bg-gray-50 rounded-lg">
            <span class="text-sm text-gray-700">Problem</span>
            <div class="w-2 h-2 bg-red-500 rounded-full"></div>
          </div>
          <div class="flex items-center justify-between p-2 bg-gray-50 rounded-lg">
            <span class="text-sm text-gray-700">Solution</span>
            <div class="w-2 h-2 bg-yellow-500 rounded-full"></div>
          </div>
          <div class="flex items-center justify-between p-2 bg-gray-50 rounded-lg">
            <span class="text-sm text-gray-700">Results</span>
            <div class="w-2 h-2 bg-green-500 rounded-full"></div>
          </div>
          <div class="flex items-center justify-between p-2 bg-gray-50 rounded-lg">
            <span class="text-sm text-gray-700">Next Steps</span>
            <div class="w-2 h-2 bg-blue-500 rounded-full"></div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Experimental Tools (Live Story, Narrative Beats)
  def render_experimental_tools(assigns) do
    ~H"""
    <div class="space-y-6">
      <%= if @story.story_type == "live_story" do %>
        <!-- Live Story Controls -->
        <div>
          <h4 class="text-sm font-medium text-gray-900 mb-3">Live Session</h4>
          <div class="space-y-3">
            <button class="w-full bg-red-600 text-white py-2 px-3 rounded-lg text-sm font-medium hover:bg-red-700"
                    phx-click="start_live_session">
              🔴 Go Live
            </button>

            <div class="bg-gray-50 rounded-lg p-3">
              <div class="flex justify-between items-center mb-2">
                <span class="text-sm text-gray-700">Audience</span>
                <span class="text-sm font-medium text-gray-900">0 viewers</span>
              </div>
              <div class="flex justify-between items-center">
                <span class="text-sm text-gray-700">Duration</span>
                <span class="text-sm font-medium text-gray-900">00:00</span>
              </div>
            </div>
          </div>
        </div>

        <!-- Audience Choices -->
        <div>
          <h4 class="text-sm font-medium text-gray-900 mb-3">Story Choices</h4>
          <div class="space-y-2">
            <%= for choice <- (@story.format_metadata["story_choices"] || []) do %>
              <div class="p-3 bg-blue-50 rounded-lg border border-blue-200">
                <p class="text-sm text-blue-800 mb-2"><%= choice["text"] %></p>
                <div class="flex justify-between text-xs text-blue-600">
                  <span>Option A: <%= choice["option_a_votes"] || 0 %> votes</span>
                  <span>Option B: <%= choice["option_b_votes"] || 0 %> votes</span>
                </div>
              </div>
            <% end %>

            <%= if @permissions.can_edit do %>
              <button class="w-full text-left p-2 text-sm text-blue-600 hover:text-blue-700 hover:bg-blue-50 rounded-lg border-2 border-dashed border-blue-300"
                      phx-click="add_story_choice">
                Add Choice Point
              </button>
            <% end %>
          </div>
        </div>

      <% else %>
        <!-- Narrative Beats Controls -->
        <div>
          <h4 class="text-sm font-medium text-gray-900 mb-3">Musical Elements</h4>
          <div class="space-y-3">
            <!-- Character Instruments -->
            <div class="bg-purple-50 rounded-lg p-3">
              <h5 class="text-xs font-medium text-purple-900 mb-2">Character Themes</h5>
              <%= for character <- (@story.character_data["characters"] || []) do %>
                <div class="flex justify-between items-center text-sm">
                  <span class="text-purple-700"><%= character["name"] %></span>
                  <span class="text-purple-600"><%= character["instrument"] || "Unassigned" %></span>
                </div>
              <% end %>
            </div>

            <!-- Beat Machine -->
            <button class="w-full bg-green-600 text-white py-2 px-3 rounded-lg text-sm font-medium hover:bg-green-700"
                    phx-click="open_beat_machine">
              🎵 Open Beat Machine
            </button>

            <!-- Audio Timeline -->
            <div class="bg-gray-50 rounded-lg p-3">
              <h5 class="text-xs font-medium text-gray-900 mb-2">Audio Timeline</h5>
              <div class="h-8 bg-gray-200 rounded relative">
                <div class="absolute top-0 left-4 w-8 h-full bg-blue-500 rounded"></div>
                <div class="absolute top-0 left-16 w-12 h-full bg-green-500 rounded"></div>
                <div class="absolute top-0 left-32 w-6 h-full bg-purple-500 rounded"></div>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Collaboration Modes -->
      <div>
        <h4 class="text-sm font-medium text-gray-900 mb-3">Collaboration Mode</h4>
        <div class="space-y-2">
          <label class="flex items-center space-x-2">
            <input type="radio" name="collab_mode" value="real_time" class="text-blue-600" checked />
            <span class="text-sm text-gray-700">Real-time</span>
          </label>
          <label class="flex items-center space-x-2">
            <input type="radio" name="collab_mode" value="asynchronous" class="text-blue-600" />
            <span class="text-sm text-gray-700">Asynchronous</span>
          </label>
          <label class="flex items-center space-x-2">
            <input type="radio" name="collab_mode" value="review_only" class="text-blue-600" />
            <span class="text-sm text-gray-700">Review Only</span>
          </label>
        </div>
      </div>
    </div>
    """
  end

  # Standard Tools (Articles, Blogs, Basic formats)
  def render_standard_tools(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Outline -->
      <div>
        <h4 class="text-sm font-medium text-gray-900 mb-3">Outline</h4>
        <div class="space-y-2">
          <%= for item <- (@story.outline["items"] || []) do %>
            <div class="flex items-center space-x-2 p-2 bg-gray-50 rounded-lg">
              <div class="w-2 h-2 bg-gray-400 rounded-full"></div>
              <span class="text-sm text-gray-700 flex-1"><%= item["title"] %></span>
              <%= if @permissions.can_edit do %>
                <button class="text-xs text-gray-500 hover:text-gray-700">⋮</button>
              <% end %>
            </div>
          <% end %>

          <%= if @permissions.can_edit do %>
            <button class="w-full text-left p-2 text-sm text-gray-500 hover:text-gray-700 hover:bg-gray-50 rounded-lg border-2 border-dashed border-gray-300"
                    phx-click="add_outline_item">
              Add Outline Item
            </button>
          <% end %>
        </div>
      </div>

      <!-- Research Notes -->
      <div>
        <h4 class="text-sm font-medium text-gray-900 mb-3">Research</h4>
        <div class="space-y-2">
          <%= for note <- (@story.research_data["notes"] || []) do %>
            <div class="p-3 bg-yellow-50 rounded-lg border-l-4 border-yellow-400">
              <p class="text-sm text-yellow-800"><%= note["content"] %></p>
              <%= if note["source"] do %>
                <p class="text-xs text-yellow-600 mt-1">Source: <%= note["source"] %></p>
              <% end %>
            </div>
          <% end %>

          <%= if @permissions.can_edit do %>
            <button class="w-full text-left p-2 text-sm text-gray-500 hover:text-gray-700 hover:bg-gray-50 rounded-lg border-2 border-dashed border-gray-300"
                    phx-click="add_research_note">
              Add Research Note
            </button>
          <% end %>
        </div>
      </div>

      <!-- Media Library -->
      <div>
        <h4 class="text-sm font-medium text-gray-900 mb-3">Media</h4>
        <div class="grid grid-cols-2 gap-2">
          <%= for media <- (@story.attached_media || []) do %>
            <div class="aspect-square bg-gray-100 rounded-lg flex items-center justify-center">
              <%= if media["type"] == "image" do %>
                <img src={media["url"]} alt={media["alt"]} class="w-full h-full object-cover rounded-lg" />
              <% else %>
                <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                </svg>
              <% end %>
            </div>
          <% end %>

          <%= if @permissions.can_edit do %>
            <button class="aspect-square border-2 border-dashed border-gray-300 rounded-lg flex items-center justify-center text-gray-400 hover:text-gray-600 hover:border-gray-400"
                    phx-click="upload_media">
              <svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
              </svg>
            </button>
          <% end %>
        </div>
      </div>

      <!-- Publishing Settings -->
      <div>
        <h4 class="text-sm font-medium text-gray-900 mb-3">Publishing</h4>
        <div class="space-y-3">
          <div>
            <label class="text-xs text-gray-500">Visibility</label>
            <select class="w-full mt-1 text-sm border-gray-300 rounded-md">
              <option value="private">Private</option>
              <option value="unlisted">Unlisted</option>
              <option value="public">Public</option>
            </select>
          </div>

          <div>
            <label class="text-xs text-gray-500">Category</label>
            <select class="w-full mt-1 text-sm border-gray-300 rounded-md">
              <option value="personal">Personal</option>
              <option value="professional">Professional</option>
              <option value="creative">Creative</option>
            </select>
          </div>

          <%= if @permissions.can_publish do %>
            <button class="w-full bg-blue-600 text-white py-2 px-3 rounded-lg text-sm font-medium hover:bg-blue-700"
                    phx-click="publish_story">
              Publish Story
            </button>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions for the template
  def get_section_label(editor_mode) do
    case editor_mode do
      :manuscript -> "Chapters"
      :business -> "Sections"
      :experimental -> "Segments"
      _ -> "Sections"
    end
  end

  def get_section_type(editor_mode) do
    case editor_mode do
      :manuscript -> "Chapter"
      :business -> "Section"
      :experimental -> "Segment"
      _ -> "Section"
    end
  end

  def get_export_formats(format_config) do
    case format_config.export_formats do
      formats when is_list(formats) ->
        Enum.map(formats, fn format ->
          %{
            key: format,
            name: format_name(format)
          }
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
      "fdx" -> "Final Draft"
      "fountain" -> "Fountain Script"
      "mp3" -> "Audio (MP3)"
      "wav" -> "Audio (WAV)"
      _ -> String.upcase(format)
    end
  end

  def get_placeholder_content(editor_mode) do
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
end
