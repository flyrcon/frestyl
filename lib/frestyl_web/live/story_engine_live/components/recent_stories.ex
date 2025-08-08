# lib/frestyl_web/live/story_engine_live/components/recent_stories.ex
defmodule FrestylWeb.StoryEngineLive.Components.RecentStories do
  use FrestylWeb, :live_component

  import FrestylWeb.Live.Helpers.CommonHelpers

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mb-12">
      <div class="flex items-center justify-between mb-6">
        <h2 class="text-xl font-semibold text-gray-900">Continue Writing</h2>
        <.link navigate={~p"/stories"} class="text-gray-600 hover:text-gray-900 font-medium">
          View All Stories
        </.link>
      </div>

      <%= if length(@recent_stories) > 0 do %>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          <%= for story <- @recent_stories do %>
            <.story_card story={story} />
          <% end %>
        </div>
      <% else %>
        <div class="text-center py-12 bg-white rounded-xl border border-gray-200">
          <div class="w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.746 0 3.332.477 4.5 1.253v13C19.832 18.477 18.246 18 16.5 18c-1.746 0-3.332.477-4.5 1.253"/>
            </svg>
          </div>
          <h3 class="text-lg font-medium text-gray-900 mb-2">No stories yet</h3>
          <p class="text-gray-600 mb-6">Start your first story to see it appear here.</p>
        </div>
      <% end %>
    </div>
    """
  end

  defp story_card(assigns) do
    ~H"""
    <.link navigate={~p"/stories/#{@story.id}/edit"}
          class="block bg-white rounded-xl p-6 shadow-sm border hover:shadow-md transition-all">

      <div class="flex items-center space-x-3 mb-4">
        <div class={[
          "w-10 h-10 rounded-lg flex items-center justify-center text-white",
          story_type_gradient(@story.story_type)
        ]}>
          <%= story_type_icon(@story.story_type) %>
        </div>
        <div class="flex items-center space-x-2">
          <span class="text-sm font-medium text-gray-900">
            <%= humanize_story_type(@story.story_type) %>
          </span>
          <span class={[
            "text-xs px-2 py-1 rounded-full",
            status_badge_class(@story.status)
          ]}>
            <%= String.capitalize(@story.status) %>
          </span>
        </div>
      </div>

      <h3 class="font-bold text-gray-900 mb-2 line-clamp-1"><%= @story.title %></h3>
      <p class="text-sm text-gray-600 mb-4 line-clamp-2">
        <%= get_story_preview(@story) %>
      </p>

      <div class="flex items-center justify-between">
        <div class="flex items-center space-x-4 text-xs text-gray-500">
          <%= if @story.word_count > 0 do %>
            <span><%= format_word_count(@story.word_count) %> words</span>
          <% end %>
          <span>Updated <%= time_ago(@story.updated_at) %></span>
          <%= if @story.collaboration_count > 0 do %>
            <span><%= @story.collaboration_count %> collaborators</span>
          <% end %>
        </div>

        <!-- Progress Bar -->
        <div class="w-16 h-2 bg-gray-200 rounded-full overflow-hidden">
          <div
            class="h-full bg-gradient-to-r from-blue-500 to-purple-500 rounded-full transition-all"
            style={"width: #{@story.completion_percentage}%"}
          ></div>
        </div>
      </div>
    </.link>
    """
  end
end
