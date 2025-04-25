# lib/frestyl_web/live/event_attendance_live.ex
defmodule FrestylWeb.EventAttendanceLive do
  use FrestylWeb, :live_view

  alias FrestylWeb.EventComponents

  @impl true
  def mount(%{"id" => event_id}, _session, socket) do
    if connected?(socket) do
      # Subscribe to necessary topics for real-time updates
      Phoenix.PubSub.subscribe(Frestyl.PubSub, "event:#{event_id}")
      Phoenix.PubSub.subscribe(Frestyl.PubSub, "event:#{event_id}:chat")
    end

    # In a real app, you'd fetch this from a context
    event = %{
      id: event_id,
      title: "Live Music Workshop",
      description: "Learn techniques from industry professionals",
      host_name: "DJ Producer",
      host_avatar: nil,
      starts_at: DateTime.add(DateTime.utc_now(), 3600, :second),
      status: "waiting_room" # Could be waiting_room, live, ended
    }

    attendees = [
      %{id: "1", name: "User 1", avatar: nil, role: "attendee"},
      %{id: "2", name: "User 2", avatar: nil, role: "attendee"},
      %{id: "3", name: "User 3", avatar: nil, role: "attendee"},
      %{id: "4", name: "User 4", avatar: nil, role: "attendee"},
      %{id: "5", name: "User 5", avatar: nil, role: "attendee"}
    ]

    waiting_room_messages = [
      %{id: "1", username: "User 1", content: "Hello everyone!", timestamp: DateTime.utc_now(), avatar: nil},
      %{id: "2", username: "User 2", content: "Looking forward to this event!", timestamp: DateTime.utc_now(), avatar: nil},
      %{id: "3", username: "DJ Producer", content: "We'll be starting soon, thanks for your patience.", timestamp: DateTime.utc_now(), avatar: nil}
    ]

    chat_messages = []

    {:ok, assign(socket,
      page_title: event.title,
      event: event,
      attendees: attendees,
      waiting_room_messages: waiting_room_messages,
      chat_messages: chat_messages,
      message_input: "",
      is_muted: false,
      is_video_on: true
    )}
  end

  @impl true
  def handle_event("send_message", %{"message" => message}, socket) when message != "" do
    # In a real app, you'd broadcast this to the channel via PubSub
    new_message = %{
      id: System.unique_integer([:positive]) |> to_string(),
      username: "Current User", # Would come from authentication
      content: message,
      timestamp: DateTime.utc_now(),
      avatar: nil
    }

    messages = if socket.assigns.event.status == "waiting_room" do
      socket.assigns.waiting_room_messages ++ [new_message]
    else
      socket.assigns.chat_messages ++ [new_message]
    end

    socket = if socket.assigns.event.status == "waiting_room" do
      assign(socket, waiting_room_messages: messages, message_input: "")
    else
      assign(socket, chat_messages: messages, message_input: "")
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("send_message", _, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_message_input", %{"value" => value}, socket) do
    {:noreply, assign(socket, message_input: value)}
  end

  @impl true
  def handle_event("toggle_mute", _, socket) do
    {:noreply, assign(socket, is_muted: !socket.assigns.is_muted)}
  end

  @impl true
  def handle_event("toggle_video", _, socket) do
    {:noreply, assign(socket, is_video_on: !socket.assigns.is_video_on)}
  end

  @impl true
  def handle_event("start_event", _, socket) do
    # This would transition the event from waiting room to live
    updated_event = %{socket.assigns.event | status: "live"}
    {:noreply, assign(socket, event: updated_event)}
  end

  @impl true
  def handle_event("end_event", _, socket) do
    # This would transition the event from live to ended
    updated_event = %{socket.assigns.event | status: "ended"}
    {:noreply, assign(socket, event: updated_event)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-[calc(100vh-56px)] flex flex-col">
      <%= case @event.status do %>
        <% "waiting_room" -> %>
          <div class="flex-1 overflow-y-auto p-6">
            <EventComponents.waiting_room
              event={@event}
              attendees_count={length(@attendees)}
              waiting_room_messages={@waiting_room_messages}
            />

            <!-- Host controls (only visible to host) -->
            <div class="mt-6 flex justify-end">
              <button
                type="button"
                phx-click="start_event"
                class="inline-flex justify-center py-2 px-4 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-green-600 hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500"
              >
                Start Event
              </button>
            </div>
          </div>

        <% "live" -> %>
          <div class="flex-1 flex flex-col lg:flex-row overflow-hidden">
            <!-- Main content area (video/screen sharing) -->
            <div class="flex-1 bg-gray-900 flex flex-col">
              <div class="flex-1 flex items-center justify-center">
                <div class="text-white text-center">
                  <svg xmlns="http://www.w3.org/2000/svg" class="mx-auto h-24 w-24 text-gray-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z" />
                  </svg>
                  <p class="mt-4 text-xl font-medium">Video stream will appear here</p>
                  <p class="mt-2 text-gray-400">This is a placeholder for the actual video stream component</p>
                </div>
              </div>

              <!-- Controls -->
              <div class="h-16 px-4 bg-gray-800 border-t border-gray-700 flex items-center justify-between">
                <div class="flex space-x-4">
                  <button
                    type="button"
                    phx-click="toggle_mute"
                    class={[
                      "p-2 rounded-full focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-gray-800 focus:ring-indigo-500",
                      @is_muted && "bg-red-500 hover:bg-red-600",
                      !@is_muted && "bg-gray-600 hover:bg-gray-700"
                    ]}
                  >
                    <%= if @is_muted do %>
                      <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-white" viewBox="0 0 20 20" fill="currentColor">
                        <path fill-rule="evenodd" d="M5.586 15H4a1 1 0 01-1-1V6a1 1 0 011-1h1.586l4.707-4.707C10.923.093 12 .469 12 1.586v16.828c0 1.117-1.077 1.493-1.707.793L5.586 15z" clip-rule="evenodd" />
                        <path fill-rule="evenodd" d="M17 14l2-2-2-2V9.414l3.293 3.293a1 1 0 010 1.414L17 14.586V14zm0-4V8.414l-2-2-2 2V10l2-2 2 2z" clip-rule="evenodd" />
                      </svg>
                    <% else %>
                      <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-white" viewBox="0 0 20 20" fill="currentColor">
                        <path fill-rule="evenodd" d="M9.383 3.076A1 1 0 0110 4v12a1 1 0 01-1.707.707L4.586 13H2a1 1 0 01-1-1V8a1 1 0 011-1h2.586l3.707-3.707a1 1 0 011.09-.217zM14.657 2.929a1 1 0 011.414 0A9.972 9.972 0 0119 10a9.972 9.972 0 01-2.929 7.071 1 1 0 01-1.414-1.414A7.971 7.971 0 0017 10c0-2.21-.894-4.208-2.343-5.657a1 1 0 010-1.414zm-2.829 2.828a1 1 0 011.415 0A5.983 5.983 0 0115 10a5.984 5.984 0 01-1.757 4.243 1 1 0 01-1.415-1.415A3.984 3.984 0 0013 10a3.983 3.983 0 00-1.172-2.828 1 1 0 010-1.415z" clip-rule="evenodd" />
                      </svg>
                    <% end %>
                  </button>

                  <button
                    type="button"
                    phx-click="toggle_video"
                    class={[
                      "p-2 rounded-full focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-gray-800 focus:ring-indigo-500",
                      !@is_video_on && "bg-red-500 hover:bg-red-600",
                      @is_video_on && "bg-gray-600 hover:bg-gray-700"
                    ]}
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-white" viewBox="0 0 20 20" fill="currentColor">
                      <path d="M2 6a2 2 0 012-2h6a2 2 0 012 2v8a2 2 0 01-2 2H4a2 2 0 01-2-2V6z" />
                      <path d="M14 6a2 2 0 012-2h2a2 2 0 012 2v8a2 2 0 01-2 2h-2a2 2 0 01-2-2V6z" />
                    </svg>
                  </button>
                </div>

                <div>
                  <!-- Host controls -->
                  <button
                    type="button"
                    phx-click="end_event"
                    class="inline-flex items-center px-3 py-1.5 border border-transparent text-xs font-medium rounded-full shadow-sm text-white bg-red-600 hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500"
                  >
                    End Event
                  </button>
                </div>
              </div>
            </div>

            <!-- Sidebar (chat & participants) -->
            <div class="w-full lg:w-80 border-t lg:border-t-0 lg:border-l border-gray-200 flex flex-col bg-white">
              <div class="flex-none border-b border-gray-200">
                <div class="flex">
                  <button
                    type="button"
                    class="flex-1 py-2 px-4 text-center text-sm font-medium border-b-2 border-indigo-500 text-indigo-600"
                  >
                    Chat
                  </button>
                  <button
                    type="button"
                    class="flex-1 py-2 px-4 text-center text-sm font-medium text-gray-500 hover:text-gray-700"
                  >
                    Participants (<%= length(@attendees) %>)
                  </button>
                </div>
              </div>

              <!-- Chat messages -->
              <div class="flex-1 overflow-y-auto p-4">
                <div class="space-y-4">
                  <%= for message <- @chat_messages do %>
                    <div class="flex">
                      <div class="flex-shrink-0 mr-3">
                        <img class="h-8 w-8 rounded-full" src={message.avatar || "https://via.placeholder.com/150"} alt={message.username}>
                      </div>
                      <div>
                        <div class="flex items-center">
                          <h5 class="text-sm font-medium text-gray-900"><%= message.username %></h5>
                          <span class="ml-2 text-xs text-gray-500"><%= Calendar.strftime(message.timestamp, "%I:%M %p") %></span>
                        </div>
                        <p class="text-sm text-gray-500"><%= message.content %></p>
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>

              <!-- Chat input -->
              <div class="flex-none p-4 border-t border-gray-200">
                <form phx-submit="send_message" class="flex">
                  <input
                    type="text"
                    name="message"
                    value={@message_input}
                    phx-keyup="update_message_input"
                    placeholder="Type a message..."
                    class="block w-full rounded-l-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                  >
                  <button
                    type="submit"
                    class="inline-flex items-center rounded-r-md border border-l-0 border-gray-300 bg-gray-50 px-3 text-gray-500 sm:text-sm"
                  >
                    Send
                  </button>
                </form>
              </div>
            </div>
          </div>

        <% "ended" -> %>
          <div class="flex-1 overflow-y-auto p-6">
            <div class="bg-white shadow overflow-hidden sm:rounded-lg">
              <div class="px-4 py-5 sm:px-6">
                <h3 class="text-lg leading-6 font-medium text-gray-900">
                  Event Ended
                </h3>
                <p class="mt-1 max-w-2xl text-sm text-gray-500">
                  Thank you for attending <%= @event.title %>
                </p>
              </div>

              <div class="border-t border-gray-200 px-4 py-5 sm:p-6">
                <div class="text-center">
                  <svg xmlns="http://www.w3.org/2000/svg" class="mx-auto h-12 w-12 text-green-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                  <h3 class="mt-2 text-lg font-medium text-gray-900">Successfully Completed</h3>
                  <p class="mt-1 text-sm text-gray-500">
                    We hope you enjoyed the event. A recording may be available soon.
                  </p>

                  <div class="mt-6">
                    <a href="/" class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500">
                      Return to Dashboard
                    </a>
                  </div>
                </div>
              </div>
            </div>
          </div>
      <% end %>
    </div>
    """
  end
end
