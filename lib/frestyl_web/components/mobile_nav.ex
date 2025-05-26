# lib/frestyl_web/components/mobile_nav.ex
defmodule FrestylWeb.MobileNav do
  use Phoenix.Component
  import FrestylWeb.CoreComponents

  @doc """
  Mobile bottom navigation for channel pages
  """
  attr :current_user, :any, required: true
  attr :channel, :any, required: true
  attr :active_tab, :string, default: "activity"
  attr :live_activities_count, :integer, default: 0
  attr :upcoming_events_count, :integer, default: 0
  attr :is_member, :boolean, default: false
  attr :can_create_session, :boolean, default: false

  def mobile_bottom_nav(assigns) do
    ~H"""
    <!-- Mobile Bottom Navigation -->
    <nav class="lg:hidden fixed bottom-0 left-0 right-0 bg-white/95 backdrop-blur-xl border-t border-gray-200/50 z-40">
      <div class="grid grid-cols-5 h-20">
        <!-- Activity Tab -->
        <button
          phx-click="switch_tab"
          phx-value-tab="activity"
          class={"flex flex-col items-center justify-center space-y-1 transition-all duration-200 #{if @active_tab == "activity", do: "text-[#00D4FF] bg-blue-50/50", else: "text-gray-500"}"}
        >
          <div class="relative">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
            </svg>
            <%= if @live_activities_count > 0 do %>
              <div class="absolute -top-2 -right-2 w-5 h-5 bg-gradient-to-r from-[#FF0080] to-[#FF4500] rounded-full flex items-center justify-center">
                <span class="text-white text-xs font-black"><%= @live_activities_count %></span>
              </div>
            <% end %>
          </div>
          <span class="text-xs font-bold">Activity</span>
        </button>

        <!-- Content Tab -->
        <button
          phx-click="switch_tab"
          phx-value-tab="content"
          class={"flex flex-col items-center justify-center space-y-1 transition-all duration-200 #{if @active_tab == "content", do: "text-[#8B5CF6] bg-purple-50/50", else: "text-gray-500"}"}
        >
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>
          </svg>
          <span class="text-xs font-bold">Content</span>
        </button>

        <!-- Create FAB -->
        <%= if @is_member and @can_create_session do %>
          <button
            phx-click="show_mobile_create_menu"
            class="relative flex flex-col items-center justify-center -mt-4"
          >
            <div class="w-14 h-14 bg-gradient-to-r from-[#00D4FF] to-[#8B5CF6] rounded-2xl shadow-xl flex items-center justify-center border-4 border-white">
              <svg class="w-7 h-7 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
              </svg>
            </div>
            <span class="text-xs font-bold text-gray-600 mt-1">Create</span>
          </button>
        <% else %>
          <div class="flex flex-col items-center justify-center">
            <div class="w-10 h-10 bg-gray-100 rounded-xl flex items-center justify-center">
              <svg class="w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
              </svg>
            </div>
            <span class="text-xs text-gray-400 font-semibold">Create</span>
          </div>
        <% end %>

        <!-- Members Tab -->
        <button
          phx-click="switch_tab"
          phx-value-tab="members"
          class={"flex flex-col items-center justify-center space-y-1 transition-all duration-200 #{if @active_tab == "members", do: "text-[#FF0080] bg-pink-50/50", else: "text-gray-500"}"}
        >
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.196-2.121M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 515.196-2.121M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 919.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"/>
          </svg>
          <span class="text-xs font-bold">Members</span>
        </button>

        <!-- Chat Tab -->
        <button
          phx-click="toggle_mobile_chat"
          class="flex flex-col items-center justify-center space-y-1 text-gray-500 transition-all duration-200"
        >
          <div class="relative">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"/>
            </svg>
            <!-- Unread message indicator -->
            <div class="absolute -top-1 -right-1 w-3 h-3 bg-[#FF0080] rounded-full"></div>
          </div>
          <span class="text-xs font-bold">Chat</span>
        </button>
      </div>
    </nav>

    <!-- Mobile spacing for fixed bottom nav -->
    <div class="lg:hidden h-20"></div>
    """
  end

  @doc """
  Mobile create action menu
  """
  attr :show, :boolean, default: false
  attr :can_create_session, :boolean, default: false
  attr :can_create_broadcast, :boolean, default: false

  def mobile_create_menu(assigns) do
    ~H"""
    <%= if @show do %>
      <!-- Mobile Create Menu Overlay -->
      <div class="lg:hidden fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-end justify-center pb-24">
        <div class="bg-white/95 backdrop-blur-xl rounded-t-3xl w-full max-w-sm mx-4 p-6 shadow-2xl border border-white/20">
          <div class="flex items-center justify-between mb-6">
            <h3 class="text-xl font-black text-gray-900">Create New</h3>
            <button phx-click="hide_mobile_create_menu" class="text-gray-400 hover:text-gray-600 p-2 rounded-lg hover:bg-gray-100 transition-colors">
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>

          <div class="space-y-4">
            <%= if @can_create_session do %>
              <button phx-click="show_session_form" class="w-full flex items-center gap-4 p-4 bg-gradient-to-r from-orange-50/80 to-red-50/80 hover:from-orange-100/80 hover:to-red-100/80 rounded-2xl transition-all duration-300 border border-orange-200/50">
                <div class="w-12 h-12 bg-gradient-to-br from-[#F59E0B] to-[#EF4444] rounded-2xl flex items-center justify-center shadow-lg">
                  <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"/>
                  </svg>
                </div>
                <div class="text-left">
                  <div class="font-black text-gray-900">Start Session</div>
                  <div class="text-sm text-gray-600 font-semibold">Begin collaborating now</div>
                </div>
              </button>
            <% end %>

            <%= if @can_create_broadcast do %>
              <button phx-click="show_broadcast_form" class="w-full flex items-center gap-4 p-4 bg-gradient-to-r from-purple-50/80 to-pink-50/80 hover:from-purple-100/80 hover:to-pink-100/80 rounded-2xl transition-all duration-300 border border-purple-200/50">
                <div class="w-12 h-12 bg-gradient-to-br from-[#8B5CF6] to-[#FF0080] rounded-2xl flex items-center justify-center shadow-lg">
                  <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
                  </svg>
                </div>
                <div class="text-left">
                  <div class="font-black text-gray-900">Go Live</div>
                  <div class="text-sm text-gray-600 font-semibold">Start broadcasting</div>
                </div>
              </button>
            <% end %>

            <button phx-click="show_media_upload" class="w-full flex items-center gap-4 p-4 bg-gradient-to-r from-blue-50/80 to-indigo-50/80 hover:from-blue-100/80 hover:to-indigo-100/80 rounded-2xl transition-all duration-300 border border-blue-200/50">
              <div class="w-12 h-12 bg-gradient-to-br from-[#00D4FF] to-[#8B5CF6] rounded-2xl flex items-center justify-center shadow-lg">
                <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/>
                </svg>
              </div>
              <div class="text-left">
                <div class="font-black text-gray-900">Upload Content</div>
                <div class="text-sm text-gray-600 font-semibold">Share files with the channel</div>
              </div>
            </button>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  @doc """
  Mobile chat overlay
  """
  attr :show, :boolean, default: false
  attr :chat_messages, :list, default: []
  attr :users_map, :map, default: %{}
  attr :online_members_count, :integer, default: 0
  attr :is_member, :boolean, default: false
  attr :message_text, :string, default: ""

  def mobile_chat_overlay(assigns) do
    ~H"""
    <%= if @show do %>
      <!-- Mobile Chat Overlay -->
      <div class="lg:hidden fixed inset-0 bg-white z-50 flex flex-col">
        <!-- Chat Header -->
        <div class="bg-gradient-to-r from-[#00D4FF] to-[#8B5CF6] px-4 py-4 flex items-center justify-between">
          <div class="flex items-center gap-3">
            <h3 class="text-xl font-black text-white">Live Chat</h3>
            <div class="flex items-center gap-2 text-sm text-white/90">
              <div class="w-2.5 h-2.5 bg-white rounded-full animate-pulse"></div>
              <span class="font-black"><%= @online_members_count %> online</span>
            </div>
          </div>
          <button phx-click="hide_mobile_chat" class="text-white/80 hover:text-white p-2 rounded-lg hover:bg-white/10 transition-colors">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </button>
        </div>

        <!-- Chat Messages -->
        <div class="flex-1 p-4 overflow-y-auto bg-gray-50">
          <div class="space-y-4">
            <%= for message <- Enum.reverse(@chat_messages) do %>
              <div class="flex gap-3">
                <div class="w-10 h-10 bg-gradient-to-br from-[#8B5CF6] to-[#FF0080] rounded-2xl flex items-center justify-center shadow-lg flex-shrink-0">
                  <span class="text-white font-black text-sm">
                    <%= String.first(get_user_name(message.user_id, @users_map)) %>
                  </span>
                </div>
                <div class="flex-1 min-w-0">
                  <div class="flex items-center gap-2 mb-1">
                    <span class="font-black text-sm text-gray-900 truncate"><%= get_user_name(message.user_id, @users_map) %></span>
                    <span class="text-xs text-gray-500 font-semibold flex-shrink-0"><%= time_ago(message.inserted_at) %></span>
                  </div>
                  <div class="bg-white rounded-2xl px-4 py-3 shadow-sm border border-gray-100">
                    <p class="text-sm text-gray-700 leading-relaxed break-words"><%= message.content %></p>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Chat Input -->
        <%= if @is_member do %>
          <div class="border-t border-gray-200 p-4 bg-white">
            <form phx-submit="send_message" class="flex gap-3">
              <input
                type="text"
                name="message"
                value={@message_text || ""}
                placeholder="Type a message..."
                class="flex-1 px-4 py-4 border-0 bg-gray-50 rounded-2xl text-gray-900 placeholder-gray-500 focus:bg-white focus:ring-2 focus:ring-[#00D4FF]/50 focus:outline-none transition-all duration-200 font-semibold"
              />
              <button type="submit" class="w-12 h-12 bg-gradient-to-r from-[#00D4FF] to-[#8B5CF6] text-white rounded-2xl flex items-center justify-center hover:shadow-lg transition-all duration-300 flex-shrink-0">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8"/>
                </svg>
              </button>
            </form>
          </div>
        <% else %>
          <div class="border-t border-gray-200 p-4 bg-gray-50">
            <div class="text-center py-4">
              <p class="text-sm text-gray-500 font-semibold">Join the channel to participate in chat</p>
            </div>
          </div>
        <% end %>

        <!-- Mobile safe area -->
        <div class="h-safe-area-inset-bottom bg-white"></div>
      </div>
    <% end %>
    """
  end

  # Helper function to get user name (would be imported from the main module)
  defp get_user_name(user_id, users_map) do
    case Map.get(users_map, user_id) do
      %{name: name} when not is_nil(name) -> name
      %{email: email} when not is_nil(email) -> email
      user when is_struct(user) ->
        user.name || user.email || user.username || "Unknown User"
      %{} = user_map ->
        user_map[:name] || user_map[:email] || user_map[:username] || "Unknown User"
      _ ->
        "Unknown User"
    end
  end

  # Helper function for time ago (would be imported from the main module)
  defp time_ago(datetime) do
    # Simplified version - in real implementation this would use proper time formatting
    diff = DateTime.diff(DateTime.utc_now(), datetime, :minute)

    cond do
      diff < 1 -> "now"
      diff < 60 -> "#{diff}m"
      diff < 1440 -> "#{div(diff, 60)}h"
      true -> "#{div(diff, 1440)}d"
    end
  end
end
