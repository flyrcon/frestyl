# lib/frestyl_web/components/event_components.ex
defmodule FrestylWeb.EventComponents do
  use Phoenix.Component
  import FrestylWeb.CoreComponents

  # This is the critical line that adds the routing functionality
  use FrestylWeb, :verified_routes

  # Add Phoenix.HTML for raw/1
  import Phoenix.HTML, only: [raw: 1]

  attr :broadcast, :map, required: true
  attr :current_user, :map, required: true
  attr :is_host, :boolean, default: false

  def broadcast_card(assigns) do
    ~H"""
    <div class="bg-gray-800 rounded-lg overflow-hidden shadow-lg">
      <div class="relative">
        <%= if @broadcast.preview_image_url do %>
          <img
            src={@broadcast.preview_image_url}
            alt={@broadcast.title}
            class="w-full h-48 object-cover"
          />
        <% else %>
          <div class="w-full h-48 bg-gradient-to-br from-indigo-500 to-purple-600 flex items-center justify-center">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-16 w-16 text-white opacity-40" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z" />
            </svg>
          </div>
        <% end %>

        <div class="absolute bottom-0 left-0 right-0 bg-gradient-to-t from-gray-900 to-transparent px-4 py-3">
          <div class="flex items-center justify-between">
            <span class={[
              "text-xs px-2 py-1 rounded-full",
              @broadcast.status == "scheduled" && "bg-blue-500 bg-opacity-20 text-blue-400",
              @broadcast.status == "active" && "bg-green-500 bg-opacity-20 text-green-400",
              @broadcast.status == "ended" && "bg-gray-500 bg-opacity-20 text-gray-400"
            ]}>
              <%= String.capitalize(@broadcast.status) %>
            </span>

            <span class="text-white text-xs font-medium">
              <%= if @broadcast.status == "scheduled" do %>
                <%= broadcast_time_format(@broadcast.scheduled_for) %>
              <% else %>
                <%= if @broadcast.status == "active" do %>
                  LIVE
                <% else %>
                  <%= broadcast_duration(@broadcast) %>
                <% end %>
              <% end %>
            </span>
          </div>
        </div>
      </div>

      <div class="p-4">
        <h3 class="text-white font-semibold text-lg mb-1"><%= @broadcast.title %></h3>
        <p class="text-gray-400 text-sm mb-3 line-clamp-2"><%= @broadcast.description %></p>

        <div class="flex items-center justify-between">
          <div class="flex items-center">
            <div class="h-6 w-6 rounded-full bg-indigo-600 flex items-center justify-center text-white text-xs font-medium">
              <%= String.first(@broadcast.host_name) %>
            </div>
            <p class="ml-2 text-sm text-gray-400">Hosted by <%= @broadcast.host_name %></p>
          </div>

          <%= if @is_host do %>
            <.link
              navigate={~p"/broadcasts/#{@broadcast.id}/manage"}
              class="text-indigo-400 hover:text-indigo-300 text-sm"
            >
              Manage
            </.link>
          <% else %>
            <%= if @broadcast.status == "scheduled" do %>
              <.link
                navigate={~p"/broadcasts/#{@broadcast.id}/register"}
                class="text-indigo-400 hover:text-indigo-300 text-sm"
              >
                Register
              </.link>
            <% else %>
              <%= if @broadcast.status == "active" do %>
                <.link
                  navigate={~p"/broadcasts/#{@broadcast.id}/join"}
                  class="text-green-400 hover:text-green-300 text-sm"
                >
                  Join Now
                </.link>
              <% else %>
                <%= if @broadcast.recording_available do %>
                  <.link
                    navigate={~p"/broadcasts/#{@broadcast.id}/recording"}
                    class="text-gray-400 hover:text-gray-300 text-sm"
                  >
                    Watch Recording
                  </.link>
                <% end %>
              <% end %>
            <% end %>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  attr :session, :map, required: true
  attr :current_user, :map, required: true
  attr :is_creator, :boolean, default: false

  def session_card(assigns) do
    ~H"""
    <div class="bg-gray-800 rounded-lg overflow-hidden shadow-lg">
      <div class="px-4 py-4 border-b border-gray-700">
        <div class="flex items-center justify-between mb-1">
          <h3 class="text-white font-semibold text-lg truncate"><%= @session.title %></h3>
          <span class={[
            "text-xs px-2 py-1 rounded-full",
            @session.status == "active" && "bg-green-500 bg-opacity-20 text-green-400",
            @session.status == "ended" && "bg-gray-500 bg-opacity-20 text-gray-400"
          ]}>
            <%= String.capitalize(@session.status) %>
          </span>
        </div>
        <p class="text-gray-400 text-sm mb-3 line-clamp-2"><%= @session.description %></p>

        <div class="grid grid-cols-3 gap-2 mb-3">
          <div class="bg-gray-900 rounded-md px-3 py-2 text-center">
            <p class="text-sm text-gray-400">Type</p>
            <p class="text-white font-medium capitalize"><%= @session.session_type %></p>
          </div>
          <div class="bg-gray-900 rounded-md px-3 py-2 text-center">
            <p class="text-sm text-gray-400">Participants</p>
            <p class="text-white font-medium"><%= @session.participants_count || 0 %></p>
          </div>
          <div class="bg-gray-900 rounded-md px-3 py-2 text-center">
            <p class="text-sm text-gray-400">Duration</p>
            <p class="text-white font-medium"><%= session_duration(@session) %></p>
          </div>
        </div>

        <div class="flex items-center justify-between">
          <div class="flex items-center">
            <div class="h-6 w-6 rounded-full bg-indigo-600 flex items-center justify-center text-white text-xs font-medium">
              <%= String.first(@session.creator_name) %>
            </div>
            <p class="ml-2 text-sm text-gray-400">Created by <%= @session.creator_name %></p>
          </div>

          <%= if @is_creator do %>
            <.link
              navigate={~p"/channels/#{@session.channel_id}/studio/#{@session.id}/manage"}
              class="text-indigo-400 hover:text-indigo-300 text-sm"
            >
              Manage
            </.link>
          <% else %>
            <%= if @session.status == "active" do %>
              <.link
                navigate={~p"/channels/#{@session.channel_id}/studio/#{@session.id}"}
                class="text-green-400 hover:text-green-300 text-sm"
              >
                Join Now
              </.link>
            <% else %>
              <%= if @session.recording_available do %>
                <.link
                  navigate={~p"/sessions/#{@session.id}/recording"}
                  class="text-gray-400 hover:text-gray-300 text-sm"
                >
                  View Recording
                </.link>
              <% end %>
            <% end %>
          <% end %>
        </div>
      </div>

      <div class="px-4 py-3 bg-gray-900 bg-opacity-50">
        <div class="flex items-center justify-between text-sm">
          <span class="text-gray-400">Created <%= time_ago(@session.inserted_at) %></span>

          <div class="flex items-center">
            <%= for tool <- session_tools(@session.session_type) do %>
              <div
                class="h-6 w-6 flex items-center justify-center text-gray-400 mr-1"
                title={tool.name}
              >
                <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" viewBox="0 0 20 20" fill="currentColor">
                  <%= raw(tool.icon) %>
                </svg>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions

  defp broadcast_time_format(datetime) do
    today = Date.utc_today()
    broadcast_date = DateTime.to_date(datetime)

    cond do
      Date.compare(broadcast_date, today) == :eq ->
        "Today at #{Calendar.strftime(datetime, "%I:%M %p")}"
      Date.compare(broadcast_date, Date.add(today, 1)) == :eq ->
        "Tomorrow at #{Calendar.strftime(datetime, "%I:%M %p")}"
      Date.compare(broadcast_date, Date.add(today, 7)) == :lt ->
        "#{Calendar.strftime(datetime, "%A")} at #{Calendar.strftime(datetime, "%I:%M %p")}"
      true ->
        Calendar.strftime(datetime, "%b %d at %I:%M %p")
    end
  end

  defp broadcast_duration(broadcast) do
    if broadcast.ended_at && broadcast.scheduled_for do
      duration_seconds = DateTime.diff(broadcast.ended_at, broadcast.scheduled_for)

      hours = div(duration_seconds, 3600)
      minutes = div(rem(duration_seconds, 3600), 60)

      cond do
        hours > 0 ->
          "#{hours}h #{minutes}m"
        true ->
          "#{minutes}m"
      end
    else
      "Unknown"
    end
  end

  defp session_duration(session) do
    if session.ended_at && session.inserted_at do
      duration_seconds = DateTime.diff(session.ended_at, session.inserted_at)

      hours = div(duration_seconds, 3600)
      minutes = div(rem(duration_seconds, 3600), 60)

      cond do
        hours > 0 ->
          "#{hours}h #{minutes}m"
        true ->
          "#{minutes}m"
      end
    else
      if session.status == "active" do
        "Ongoing"
      else
        "Unknown"
      end
    end
  end

  defp session_tools("mixed") do
    [
      %{name: "Audio", icon: "<path d=\"M10 18a8 8 0 100-16 8 8 0 000 16zM9.555 7.168A1 1 0 008 8v4a1 1 0 001.555.832l3-2a1 1 0 000-1.664l-3-2z\" />"},
      %{name: "Text", icon: "<path d=\"M4 4a2 2 0 012-2h4.586A2 2 0 0112 2.586L15.414 6A2 2 0 0116 7.414V16a2 2 0 01-2 2H6a2 2 0 01-2-2V4z\" />"},
      %{name: "Visual", icon: "<path d=\"M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z\" />"},
      %{name: "MIDI", icon: "<path d=\"M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3\" />"}
    ]
  end

  defp session_tools("audio") do
    [
      %{name: "Audio", icon: "<path d=\"M10 18a8 8 0 100-16 8 8 0 000 16zM9.555 7.168A1 1 0 008 8v4a1 1 0 001.555.832l3-2a1 1 0 000-1.664l-3-2z\" />"}
    ]
  end

  defp session_tools("text") do
    [
      %{name: "Text", icon: "<path d=\"M4 4a2 2 0 012-2h4.586A2 2 0 0112 2.586L15.414 6A2 2 0 0116 7.414V16a2 2 0 01-2 2H6a2 2 0 01-2-2V4z\" />"}
    ]
  end

  defp session_tools("visual") do
    [
      %{name: "Visual", icon: "<path d=\"M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z\" />"}
    ]
  end

  defp session_tools("midi") do
    [
      %{name: "MIDI", icon: "<path d=\"M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3\" />"}
    ]
  end

  defp session_tools(_) do
    session_tools("mixed")
  end

  defp time_ago(datetime) do
    now = DateTime.utc_now()
    diff_seconds = DateTime.diff(now, datetime)

    cond do
      diff_seconds < 60 ->
        "just now"
      diff_seconds < 3600 ->
        "#{div(diff_seconds, 60)} minutes ago"
      diff_seconds < 86400 ->
        "#{div(diff_seconds, 3600)} hours ago"
      diff_seconds < 2_592_000 ->
        "#{div(diff_seconds, 86400)} days ago"
      diff_seconds < 31_536_000 ->
        "#{div(diff_seconds, 2_592_000)} months ago"
      true ->
        "#{div(diff_seconds, 31_536_000)} years ago"
    end
  end
end
