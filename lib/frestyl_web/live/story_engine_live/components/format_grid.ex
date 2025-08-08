# lib/frestyl_web/live/story_engine_live/components/format_grid.ex
defmodule FrestylWeb.StoryEngineLive.Components.FormatGrid do
  use FrestylWeb, :live_component

  import FrestylWeb.Live.Helpers.CommonHelpers
  alias Frestyl.StoryEngine.FormatManager
  alias Frestyl.Features.TierManager

  @impl true
  def render(assigns) do
    ~H"""
    <div class="format-grid space-y-4">
      <h2 class="text-xl font-semibold text-gray-900 mb-6">Choose your format</h2>

      <%= for format_key <- @formats do %>
        <% format_config = FormatManager.get_format_config(format_key) %>
        <% accessible = TierManager.has_tier_access?(@user_tier, format_config.required_tier) %>

        <div class={[
          "story-format-card bg-white rounded-xl p-6 shadow-sm border transition-all cursor-pointer",
          if(accessible, do: "hover:shadow-md", else: "opacity-60")
        ]}
        phx-click={if accessible, do: "create_story", else: "show_upgrade_modal"}
        phx-value-format={format_key}
        phx-target={@myself}>

          <div class="flex items-start space-x-4">
            <div class={[
              "format-preview w-16 h-16 rounded-xl flex items-center justify-center text-white text-2xl transition-transform",
              "bg-gradient-to-br #{format_config.gradient}"
            ]}>
              <%= format_config.icon %>
            </div>

            <div class="flex-1">
              <div class="flex items-center space-x-2 mb-2">
                <h3 class="font-bold text-gray-900"><%= format_config.name %></h3>

                <span class={[
                  "text-xs px-2 py-1 rounded-full",
                  tier_badge_class(format_config.required_tier)
                ]}>
                  <%= tier_display_name(format_config.required_tier) %>
                </span>

                <%= if Map.get(format_config, :beta) do %>
                  <span class="text-xs bg-purple-100 text-purple-700 px-2 py-1 rounded-full">BETA</span>
                <% end %>
              </div>

              <p class="text-sm text-gray-600 mb-3"><%= format_config.description %></p>

              <div class="flex items-center justify-between">
                <div class="flex space-x-2">
                  <%= for feature <- Enum.take(format_config.features, 3) do %>
                    <span class="text-xs bg-blue-100 text-blue-700 px-2 py-1 rounded-full">
                      <%= humanize_feature(feature) %>
                    </span>
                  <% end %>
                </div>

                <div class="flex items-center space-x-2">
                  <span class="text-xs text-gray-500"><%= format_config.estimated_time %></span>
                  <%= if accessible do %>
                    <button class="text-sm text-blue-600 font-medium hover:text-blue-700">
                      Start Creating →
                    </button>
                  <% else %>
                    <button class="text-sm text-amber-600 font-medium">
                      Upgrade to Access →
                    </button>
                  <% end %>
                </div>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("create_story", %{"format" => format}, socket) do
    send(self(), {:create_story, format})
    {:noreply, socket}
  end

  @impl true
  def handle_event("show_upgrade_modal", %{"format" => format}, socket) do
    format_config = FormatManager.get_format_config(format)

    send(self(), {:show_upgrade_modal, format_config.required_tier})
    {:noreply, socket}
  end

end
