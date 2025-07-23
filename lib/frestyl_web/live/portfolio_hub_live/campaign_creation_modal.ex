# File: lib/frestyl_web/live/portfolio_hub_live/campaign_creation_modal.ex

defmodule FrestylWeb.PortfolioHubLive.CampaignCreationModal do
  use Phoenix.Component
  import FrestylWeb.CoreComponents

  @doc """
  Campaign creation modal with quality gates configuration.
  """
  def campaign_creation_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50">
      <div class="relative top-20 mx-auto p-5 border w-11/12 md:w-3/4 lg:w-1/2 shadow-lg rounded-md bg-white">
        <!-- Modal Header -->
        <div class="flex items-center justify-between mb-6">
          <h3 class="text-lg font-semibold text-gray-900">Create Content Campaign</h3>
          <button phx-click="close_campaign_modal" class="text-gray-400 hover:text-gray-600">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </button>
        </div>

        <!-- Campaign Form -->
        <form phx-submit="create_campaign_with_gates">
          <!-- Basic Campaign Info -->
          <div class="space-y-4 mb-6">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Campaign Title</label>
              <input
                type="text"
                name="title"
                required
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-purple-500 focus:border-purple-500"
                placeholder="Enter campaign title..." />
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Description</label>
              <textarea
                name="description"
                rows="3"
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-purple-500 focus:border-purple-500"
                placeholder="Describe your campaign..."></textarea>
            </div>

            <div class="grid grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Content Type</label>
                <select
                  name="content_type"
                  required
                  phx-change="update_quality_gates_preview"
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-purple-500 focus:border-purple-500">
                  <option value="">Select type...</option>
                  <option value="data_story">Data Story</option>
                  <option value="book">Book</option>
                  <option value="podcast">Podcast</option>
                  <option value="music_track">Music Track</option>
                  <option value="blog_post">Blog Post</option>
                  <option value="video_content">Video Content</option>
                </select>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Max Contributors</label>
                <input
                  type="number"
                  name="max_contributors"
                  min="2"
                  max="20"
                  value="5"
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-purple-500 focus:border-purple-500" />
              </div>
            </div>
          </div>

          <!-- Quality Gates Configuration -->
          <div class="mb-6">
            <h4 class="text-md font-medium text-gray-900 mb-3">Quality Gates</h4>
            <div class="bg-gray-50 rounded-lg p-4">
              <div id="quality-gates-preview">
                <%= if @selected_content_type do %>
                  <.quality_gates_preview content_type={@selected_content_type} />
                <% else %>
                  <p class="text-sm text-gray-500">Select content type to see quality gates</p>
                <% end %>
              </div>
            </div>
          </div>

          <!-- Revenue Settings -->
          <div class="mb-6">
            <h4 class="text-md font-medium text-gray-900 mb-3">Revenue Settings</h4>
            <div class="grid grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Revenue Target</label>
                <div class="relative">
                  <span class="absolute left-3 top-2 text-gray-500">$</span>
                  <input
                    type="number"
                    name="revenue_target"
                    min="0"
                    step="0.01"
                    class="w-full pl-7 pr-3 py-2 border border-gray-300 rounded-md focus:ring-purple-500 focus:border-purple-500"
                    placeholder="0.00" />
                </div>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Platform Share</label>
                <select
                  name="platform_share"
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-purple-500 focus:border-purple-500">
                  <option value="30">30% (Standard)</option>
                  <option value="25">25% (Premium)</option>
                  <option value="20">20% (Enterprise)</option>
                </select>
              </div>
            </div>
          </div>

          <!-- Advanced Options -->
          <div class="mb-6">
            <h4 class="text-md font-medium text-gray-900 mb-3">Advanced Options</h4>
            <div class="space-y-3">
              <label class="flex items-center">
                <input type="checkbox" name="enable_peer_review" checked class="rounded text-purple-600" />
                <span class="ml-2 text-sm text-gray-700">Enable peer review system</span>
              </label>

              <label class="flex items-center">
                <input type="checkbox" name="enable_improvement_periods" checked class="rounded text-purple-600" />
                <span class="ml-2 text-sm text-gray-700">Enable 30-day improvement periods</span>
              </label>

              <label class="flex items-center">
                <input type="checkbox" name="public_collaboration" class="rounded text-purple-600" />
                <span class="ml-2 text-sm text-gray-700">Make collaboration process public</span>
              </label>
            </div>
          </div>

          <!-- Form Actions -->
          <div class="flex justify-end space-x-3">
            <button
              type="button"
              phx-click="close_campaign_modal"
              class="px-4 py-2 border border-gray-300 text-gray-700 rounded-md hover:bg-gray-50">
              Cancel
            </button>
            <button
              type="submit"
              class="px-4 py-2 bg-purple-600 text-white rounded-md hover:bg-purple-700">
              Create Campaign
            </button>
          </div>
        </form>
      </div>
    </div>
    """
  end

  defp quality_gates_preview(assigns) do
    gates = get_quality_gates_for_preview(assigns.content_type)

    ~H"""
    <div class="space-y-3">
      <p class="text-sm text-gray-600">Quality gates for <%= format_content_type(@content_type) %>:</p>

      <%= for gate <- gates do %>
        <div class="flex items-center justify-between p-3 bg-white rounded border">
          <div>
            <h5 class="font-medium text-gray-900"><%= gate.display_name %></h5>
            <p class="text-sm text-gray-600"><%= gate.description %></p>
          </div>
          <div class="text-right">
            <span class="text-sm font-medium text-purple-600"><%= format_threshold(gate.threshold) %></span>
            <p class="text-xs text-gray-500">Weight: <%= gate.weight %>%</p>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp get_quality_gates_for_preview(content_type) do
    case content_type do
      "book" ->
        [
          %{display_name: "Minimum Word Count", description: "At least 5,000 words required", threshold: "5,000 words", weight: 20},
          %{display_name: "Chapter Completion", description: "Complete at least 15% of chapters", threshold: "15%", weight: 30},
          %{display_name: "Peer Review Score", description: "Average rating of 3.5/5.0 or higher", threshold: "3.5/5.0", weight: 30},
          %{display_name: "Narrative Coherence", description: "Story flow and consistency", threshold: "70%", weight: 20}
        ]

      "podcast" ->
        [
          %{display_name: "Minimum Audio Duration", description: "At least 10 minutes of content", threshold: "10 minutes", weight: 25},
          %{display_name: "Audio Quality Score", description: "Clear sound, no distortion", threshold: "80%", weight: 25},
          %{display_name: "Speaking Time Ratio", description: "At least 20% speaking time", threshold: "20%", weight: 25},
          %{display_name: "Peer Review Score", description: "Average rating of 3.5/5.0 or higher", threshold: "3.5/5.0", weight: 25}
        ]

      "music_track" ->
        [
          %{display_name: "Track Contribution Ratio", description: "At least 15% of track elements", threshold: "15%", weight: 40},
          %{display_name: "Audio Quality Score", description: "Professional audio quality", threshold: "75%", weight: 30},
          %{display_name: "Mixing Contribution", description: "Contribute to final mix", threshold: "10%", weight: 30}
        ]

      "data_story" ->
        [
          %{display_name: "Research Contribution", description: "At least 3 key insights", threshold: "3 insights", weight: 40},
          %{display_name: "Data Visualization Quality", description: "Clear and engaging visuals", threshold: "70%", weight: 30},
          %{display_name: "Narrative Clarity", description: "Story tells clear message", threshold: "75%", weight: 30}
        ]

      "blog_post" ->
        [
          %{display_name: "Minimum Word Count", description: "At least 1,500 words", threshold: "1,500 words", weight: 30},
          %{display_name: "Unique Insights", description: "At least 2 original insights", threshold: "2 insights", weight: 40},
          %{display_name: "Peer Review Score", description: "Average rating of 3.0/5.0 or higher", threshold: "3.0/5.0", weight: 30}
        ]

      "video_content" ->
        [
          %{display_name: "Minimum Duration", description: "At least 5 minutes of content", threshold: "5 minutes", weight: 25},
          %{display_name: "Video Quality", description: "HD quality, stable footage", threshold: "720p+", weight: 25},
          %{display_name: "Content Contribution", description: "Meaningful content contribution", threshold: "20%", weight: 25},
          %{display_name: "Peer Review Score", description: "Average rating of 3.5/5.0 or higher", threshold: "3.5/5.0", weight: 25}
        ]

      _ ->
        [
          %{display_name: "Minimum Contribution", description: "Meet basic contribution threshold", threshold: "5%", weight: 50},
          %{display_name: "Peer Review Score", description: "Average rating of 3.0/5.0 or higher", threshold: "3.0/5.0", weight: 50}
        ]
    end
  end

  defp format_content_type("data_story"), do: "Data Story"
  defp format_content_type("book"), do: "Book"
  defp format_content_type("podcast"), do: "Podcast"
  defp format_content_type("music_track"), do: "Music Track"
  defp format_content_type("blog_post"), do: "Blog Post"
  defp format_content_type("video_content"), do: "Video Content"
  defp format_content_type(type), do: String.capitalize(type)

  defp format_threshold(threshold), do: threshold
end
