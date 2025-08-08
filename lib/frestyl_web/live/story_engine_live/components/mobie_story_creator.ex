# lib/frestyl_web/live/story_engine_live/components/mobile_story_creator.ex
defmodule FrestylWeb.StoryEngineLive.Components.MobileStoryCreator do
  use FrestylWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <!-- Mobile-Optimized Story Creation Interface -->
    <div class="lg:hidden">
      <!-- Mobile Header -->
      <div class="sticky top-0 bg-white border-b border-gray-200 p-4 z-10">
        <div class="flex items-center justify-between">
          <h2 class="text-lg font-semibold text-gray-900">Story Engine</h2>
          <button class="text-gray-600">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h8m-8 6h16"/>
            </svg>
          </button>
        </div>
      </div>

      <!-- Mobile Intent Selector -->
      <div class="p-4">
        <h3 class="font-semibold text-gray-900 mb-4">What do you want to create?</h3>

        <!-- Swipeable Intent Cards -->
        <div class="flex space-x-4 overflow-x-auto pb-4 mb-6">
          <%= for {intent_key, intent_config} <- @available_intents do %>
            <div
              class={[
                "flex-shrink-0 w-64 p-4 rounded-xl border cursor-pointer transition-all",
                if(@selected_intent == intent_key, do: "border-blue-500 bg-blue-50", else: "border-gray-200 bg-white")
              ]}
              phx-click="select_intent"
              phx-value-intent={intent_key}
              phx-target={@myself}
            >
              <div class="flex items-center space-x-3 mb-3">
                <div class={[
                  "w-10 h-10 rounded-lg flex items-center justify-center text-white",
                  "bg-gradient-to-br #{intent_config.gradient}"
                ]}>
                  <%= intent_config.icon %>
                </div>
                <h4 class="font-semibold text-gray-900"><%= intent_config.name %></h4>
              </div>
              <p class="text-sm text-gray-600"><%= intent_config.description %></p>
            </div>
          <% end %>
        </div>

        <!-- Mobile Format Grid -->
        <div class="space-y-3">
          <%= for format_key <- @available_formats do %>
            <% format_config = FormatManager.get_format_config(format_key) %>
            <% accessible = TierManager.has_tier_access?(@user_tier, format_config.required_tier) %>

            <div class={[
              "p-4 rounded-xl border transition-all",
              if(accessible, do: "border-gray-200 bg-white active:bg-gray-50", else: "border-gray-200 bg-gray-50 opacity-60")
            ]}
            phx-click={if accessible, do: "create_story", else: "show_upgrade_modal"}
            phx-value-format={format_key}
            phx-target={@myself}>

              <div class="flex items-center space-x-3">
                <div class={[
                  "w-12 h-12 rounded-lg flex items-center justify-center text-white",
                  "bg-gradient-to-br #{format_config.gradient}"
                ]}>
                  <%= format_config.icon %>
                </div>

                <div class="flex-1">
                  <div class="flex items-center space-x-2 mb-1">
                    <h4 class="font-semibold text-gray-900"><%= format_config.name %></h4>
                    <%= if not accessible do %>
                      <span class="text-xs bg-amber-100 text-amber-700 px-2 py-1 rounded-full">
                        Upgrade Required
                      </span>
                    <% end %>
                  </div>
                  <p class="text-sm text-gray-600 mb-2"><%= format_config.description %></p>
                  <div class="flex items-center justify-between">
                    <span class="text-xs text-gray-500"><%= format_config.estimated_time %></span>
                    <%= if accessible do %>
                      <span class="text-xs text-blue-600 font-medium">Start →</span>
                    <% else %>
                      <span class="text-xs text-amber-600 font-medium">Upgrade →</span>
                    <% end %>
                  </div>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("select_intent", %{"intent" => intent_key}, socket) do
    send(self(), {:intent_selected, intent_key})
    {:noreply, assign(socket, :selected_intent, intent_key)}
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
