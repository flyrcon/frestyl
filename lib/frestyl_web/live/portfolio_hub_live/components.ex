
defmodule FrestylWeb.PortfolioHubLive.Components do
  @moduledoc """
  Enhanced mobile-first components for the comprehensive Portfolio Hub.
  Supports all six feature sections with equal prominence and subscription-based UI.
  """

  use FrestylWeb, :live_component
  import Phoenix.HTML
  alias FrestylWeb.PortfolioHubLive.Helpers

  use Phoenix.Component

  # ============================================================================
  # NOTIFICATION TOAST
  # ============================================================================

  def notification_toast(assigns) do
    ~H"""
    <div role="alert" aria-live="polite" class={[
      "fixed top-4 right-4 z-50 max-w-sm w-full bg-white rounded-lg shadow-lg border-l-4 p-4 transform transition-all duration-300",
      border_color(@type),
      if(@show, do: "translate-x-0 opacity-100", else: "translate-x-full opacity-0")
    ]}>
      <div class="flex items-start">
        <div class={["w-5 h-5 mr-3 mt-0.5", text_color(@type)]}>
          <%= icon_svg(@type) %>
        </div>
        <div class="flex-1">
          <%= if @title do %>
            <p class="text-sm font-medium text-gray-900"><%= @title %></p>
          <% end %>
          <p class={["text-sm", if(@title, do: "text-gray-600 mt-1", else: "text-gray-900")]}>
            <%= @message %>
          </p>
        </div>
        <button phx-click="dismiss_notification" phx-value-id={@id}
          class="flex-shrink-0 ml-3 text-gray-400 hover:text-gray-600 transition-colors">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
          </svg>
        </button>
      </div>
    </div>
    """
  end

  # ============================================================================
  # COMPONENTS
  # ============================================================================

  def skeleton_card(assigns) do
    ~H"""
    <div class="bg-white rounded-lg border border-gray-200 p-6 animate-pulse">
      <div class="flex items-center mb-4">
        <div class="w-10 h-10 bg-gray-300 rounded-lg"></div>
        <div class="ml-4 flex-1">
          <div class="h-4 bg-gray-300 rounded w-3/4 mb-2"></div>
          <div class="h-3 bg-gray-300 rounded w-1/2"></div>
        </div>
      </div>
      <div class="space-y-2">
        <div class="h-3 bg-gray-300 rounded"></div>
        <div class="h-3 bg-gray-300 rounded w-5/6"></div>
        <div class="h-3 bg-gray-300 rounded w-4/6"></div>
      </div>
      <div class="flex justify-between items-center mt-4">
        <div class="h-8 bg-gray-300 rounded w-20"></div>
        <div class="h-8 bg-gray-300 rounded w-16"></div>
      </div>
    </div>
    """
  end

  def skeleton_grid(assigns) do
    ~H"""
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
      <%= for _ <- 1..(@count || 6) do %>
        <.skeleton_card />
      <% end %>
    </div>
    """
  end

  def progress_bar(assigns) do
    ~H"""
    <div class="w-full">
      <%= if @label do %>
        <div class="flex justify-between items-center mb-2">
          <span class="text-sm font-medium text-gray-700"><%= @label %></span>
          <span class="text-sm text-gray-500"><%= @percentage %>%</span>
        </div>
      <% end %>
      <div class="w-full bg-gray-200 rounded-full h-2">
        <div class={["h-2 rounded-full transition-all duration-300", progress_color(@color)]}
          style={"width: #{@percentage}%"}></div>
      </div>
      <%= if @subtitle do %>
        <p class="text-xs text-gray-500 mt-1"><%= @subtitle %></p>
      <% end %>
    </div>
    """
  end

  def stats_grid(assigns) do
    ~H"""
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
      <%= for stat <- @stats do %>
        <div class="bg-white rounded-xl p-6 border border-gray-200 hover:shadow-lg transition-all duration-300">
          <div class="flex items-center">
            <div class={["p-3 rounded-lg", bg_color(stat.color)]}>
              <%= if stat.icon do %><span class="text-2xl"><%= stat.icon %></span><% else %>
                <svg class={["w-6 h-6", text_color(stat.color)]} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <%= raw(stat.svg_path) %>
                </svg>
              <% end %>
            </div>
            <div class="ml-4 flex-1">
              <p class="text-sm font-medium text-gray-600"><%= stat.label %></p>
              <div class="flex items-baseline">
                <p class="text-2xl font-bold text-gray-900"><%= stat.value %></p>
                <%= if stat.change do %>
                  <span class={[
                    "ml-2 text-sm font-medium",
                    if(stat.change >= 0, do: "text-green-600", else: "text-red-600")
                  ]}><%= if stat.change >= 0, do: "+#{stat.change}%", else: "#{stat.change}%" %></span>
                <% end %>
              </div>
              <%= if stat.subtitle do %><p class="text-xs text-gray-500 mt-1"><%= stat.subtitle %></p><% end %>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # ... [Add the rest of the components from your file as needed, following this pattern.]

  # ============================================================================
  # HELPERS
  # ============================================================================

  defp border_color(type) do
    case type do
      :error -> "border-red-300"
      :warning -> "border-yellow-300"
      :success -> "border-green-300"
      :info -> "border-blue-300"
      _ -> "border-gray-300"
    end
  end

  defp text_color(type) do
    case type do
      :success -> "text-green-500"
      :error -> "text-red-500"
      :warning -> "text-yellow-500"
      :info -> "text-blue-500"
      _ -> "text-gray-500"
    end
  end

  defp progress_color(color) do
     case color do
      :purple -> "bg-purple-600"
      :blue -> "bg-blue-600"
      :green -> "bg-green-600"
      :yellow -> "bg-yellow-600"
      :red -> "bg-red-600"
      _ -> "bg-gray-600"
    end
  end

  defp bg_color(color) do
    case color do
      :purple -> "bg-purple-100"
      :blue -> "bg-blue-100"
      :green -> "bg-green-100"
      :yellow -> "bg-yellow-100"
      :red -> "bg-red-100"
      :indigo -> "bg-indigo-100"
      :pink -> "bg-pink-100"
      _ -> "bg-gray-100"
    end
  end

  defp icon_svg(type) do
    case type do
      "success" -> ~s"""
        <svg fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/></svg>
      """
      "error" -> ~s"""
        <svg fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/></svg>
      """
      "warning" -> ~s"""
        <svg fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"/></svg>
      """
      _ -> ~s"""
        <svg fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
      """
    end
  end
end
