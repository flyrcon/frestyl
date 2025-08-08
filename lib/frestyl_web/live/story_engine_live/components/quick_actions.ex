# lib/frestyl_web/live/story_engine_live/components/quick_actions.ex
defmodule FrestylWeb.StoryEngineLive.Components.QuickActions do
  use FrestylWeb, :live_component

  alias Frestyl.Features.TierManager

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-gradient-to-br from-indigo-500 via-purple-600 to-pink-600 rounded-xl p-8 text-white">
      <h3 class="text-lg font-semibold mb-6">Ready to Start?</h3>
      <p class="mb-6 opacity-90">
        Choose a quick option to begin writing immediately, or explore our full range of storytelling tools.
      </p>

      <div class="space-y-3">
        <button
          phx-click="quick_create"
          phx-value-template="article"
          phx-target={@myself}
          class="w-full bg-white bg-opacity-20 backdrop-blur-sm text-white font-semibold py-3 rounded-lg border border-white border-opacity-30 hover:bg-opacity-30 transition-all">
          📝 Quick Article
        </button>

        <button
          phx-click="quick_create"
          phx-value-template="personal_story"
          phx-target={@myself}
          class="w-full bg-white bg-opacity-20 backdrop-blur-sm text-white font-semibold py-3 rounded-lg border border-white border-opacity-30 hover:bg-opacity-30 transition-all">
          📖 Personal Story
        </button>

        <button
          phx-click="quick_create"
          phx-value-template="case_study"
          phx-target={@myself}
          class="w-full bg-white bg-opacity-20 backdrop-blur-sm text-white font-semibold py-3 rounded-lg border border-white border-opacity-30 hover:bg-opacity-30 transition-all">
          📊 Case Study
        </button>

        <%= if TierManager.has_tier_access?(@user_tier, "professional") do %>
          <button
            phx-click="quick_create"
            phx-value-template="experimental"
            phx-target={@myself}
            class="w-full bg-white bg-opacity-20 backdrop-blur-sm text-white font-semibold py-3 rounded-lg border border-white border-opacity-30 hover:bg-opacity-30 transition-all">
            🧪 Try Something New
          </button>
        <% end %>
      </div>

      <!-- Resources Section -->
      <div class="mt-8 pt-6 border-t border-white border-opacity-20">
        <h4 class="font-semibold mb-4">Resources & Help</h4>
        <div class="space-y-2">
          <button class="w-full text-left text-sm opacity-90 hover:opacity-100 transition-opacity">
            📋 Story Templates Library
          </button>
          <button class="w-full text-left text-sm opacity-90 hover:opacity-100 transition-opacity">
            🤖 AI Writing Assistant Guide
          </button>
          <button class="w-full text-left text-sm opacity-90 hover:opacity-100 transition-opacity">
            👥 Collaboration Best Practices
          </button>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("quick_create", %{"template" => template_key}, socket) do
    send(self(), {:quick_create, template_key})
    {:noreply, socket}
  end
end
