# lib/frestyl_web/live/story_engine_live/components/intent_selector.ex
defmodule FrestylWeb.StoryEngineLive.Components.IntentSelector do
  use FrestylWeb, :live_component

  alias Frestyl.StoryEngine.IntentClassifier
  alias Frestyl.Features.TierManager

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-4">
      <h2 class="text-xl font-semibold text-gray-900 mb-6">What's your story goal?</h2>

      <%= for {intent_key, intent_config} <- @available_intents do %>
        <div
          class={[
            "intent-category cursor-pointer transition-all rounded-xl p-6 shadow-sm border hover:shadow-md",
            if(@selected_intent == intent_key, do: "ring-2 ring-blue-500 bg-blue-50", else: "bg-white")
          ]}
          phx-click="select_intent"
          phx-value-intent={intent_key}
          phx-target={@myself}
        >
          <div class="flex items-start space-x-4">
            <div class={[
              "w-12 h-12 rounded-xl flex items-center justify-center text-white text-xl",
              "bg-gradient-to-br #{intent_config.gradient}"
            ]}>
              <%= intent_config.icon %>
            </div>
            <div class="flex-1">
              <div class="flex items-center space-x-2 mb-2">
                <h3 class="font-bold text-gray-900"><%= intent_config.name %></h3>
                <%= if Map.get(intent_config, :beta) do %>
                  <span class="text-xs bg-purple-100 text-purple-700 px-2 py-1 rounded-full">BETA</span>
                <% end %>
                <%= if not TierManager.has_tier_access?(@user_tier, intent_config.tier_required) do %>
                  <span class="text-xs bg-amber-100 text-amber-700 px-2 py-1 rounded-full">
                    Upgrade Required
                  </span>
                <% end %>
              </div>
              <p class="text-sm text-gray-600 mb-3"><%= intent_config.description %></p>
              <div class="flex flex-wrap gap-2">
                <%= for format <- Enum.take(intent_config.formats, 3) do %>
                  <span class="text-xs bg-gray-100 text-gray-700 px-2 py-1 rounded-full">
                    <%= humanize_format(format) %>
                  </span>
                <% end %>
                <%= if length(intent_config.formats) > 3 do %>
                  <span class="text-xs text-gray-500">
                    +<%= length(intent_config.formats) - 3 %> more
                  </span>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("select_intent", %{"intent" => intent_key}, socket) do
    send(self(), {:intent_selected, intent_key})
    {:noreply, assign(socket, :selected_intent, intent_key)}
  end

  defp humanize_format(format) do
    format
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
end
