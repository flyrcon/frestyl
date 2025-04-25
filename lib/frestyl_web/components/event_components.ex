# lib/frestyl_web/components/event_components.ex
defmodule FrestylWeb.EventComponents do
  use Phoenix.Component

  alias Phoenix.LiveView.JS

  def waiting_room(assigns) do
    ~H"""
    <div class="bg-white shadow overflow-hidden sm:rounded-lg">
      <div class="px-4 py-5 sm:px-6 flex justify-between items-center">
        <div>
          <h3 class="text-lg leading-6 font-medium text-gray-900">
            <%= @event.title %>
          </h3>
          <p class="mt-1 max-w-2xl text-sm text-gray-500">
            Starting <%= format_start_time(@event.starts_at) %>
          </p>
        </div>
        <div class="text-right">
          <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-yellow-100 text-yellow-800">
            Waiting Room
          </span>
        </div>
      </div>

      <div class="border-t border-gray-200 px-4 py-5 sm:p-6">
        <div class="sm:flex sm:items-start sm:justify-between">
          <div class="sm:flex sm:items-center">
            <div class="flex-shrink-0">
              <img class="h-16 w-16 rounded-full" src={@event.host_avatar || "https://via.placeholder.com/150"} alt={@event.host_name}>
            </div>
            <div class="mt-3 sm:mt-0 sm:ml-4">
              <h3 class="text-lg leading-6 font-medium text-gray-900">
                Hosted by <%= @event.host_name %>
              </h3>
              <p class="mt-1 max-w-2xl text-sm text-gray-500">
                <%= @attendees_count %> people waiting
              </p>
            </div>
          </div>

          <div class="mt-5 sm:mt-0 sm:ml-6 sm:flex-shrink-0 sm:flex sm:items-center">
            <div class="inline-flex items-center px-4 py-2 border border-transparent text-sm leading-5 font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-500 focus:outline-none focus:border-indigo-700 focus:shadow-outline-indigo active:bg-indigo-700 transition ease-in-out duration-150">
              You're in line
            </div>
          </div>
        </div>

        <!-- Chat while waiting -->
        <div class="mt-6">
          <h4 class="text-sm font-medium text-gray-500">Chat while you wait</h4>
          <div class="mt-2 bg-gray-50 rounded-lg p-4 h-64 overflow-y-auto">
            <div class="space-y-4">
              <%= for message <- @waiting_room_messages do %>
                <div class="flex">
                  <div class="flex-shrink-0 mr-3">
                    <img class="h-8 w-8 rounded-full" src={message.avatar || "https://via.placeholder.com/150"} alt={message.username}>
                  </div>
                  <div>
                    <div class="flex items-center">
                      <h5 class="text-sm font-medium text-gray-900"><%= message.username %></h5>
                      <span class="ml-2 text-xs text-gray-500"><%= format_message_time(message.timestamp) %></span>
                    </div>
                    <p class="text-sm text-gray-500"><%= message.content %></p>
                  </div>
                </div>
              <% end %>
            </div>
          </div>

          <div class="mt-4">
            <form phx-submit="send_waiting_room_message">
              <div class="flex rounded-md shadow-sm">
                <input type="text" name="message" id="message" class="focus:ring-indigo-500 focus:border-indigo-500 flex-1 block w-full rounded-none rounded-l-md sm:text-sm border-gray-300" placeholder="Type a message...">
                <button type="submit" class="-ml-px relative inline-flex items-center space-x-2 px-4 py-2 border border-transparent text-sm font-medium rounded-r-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500">
                  Send
                </button>
              </div>
            </form>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def event_card(assigns) do
    ~H"""
    <div class="bg-white overflow-hidden shadow rounded-lg">
      <div class="px-4 py-5 sm:p-6">
        <div class="flex items-center">
          <div class="flex-shrink-0 bg-indigo-500 rounded-md p-3">
            <svg class="h-6 w-6 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5.882V19.24a1.76 1.76 0 01-3.417.592l-2.147-6.15M18 13a3 3 0 100-6M5.436 13.683A4.001 4.001 0 017 6h1.832c4.1 0 7.625-1.234 9.168-3v14c-1.543-1.766-5.067-3-9.168-3H7a3.988 3.988 0 01-1.564-.317z" />
            </svg>
          </div>
          <div class="ml-5 w-0 flex-1">
            <dl>
              <dt class="text-sm font-medium text-gray-500 truncate">
                <%= @event.title %>
              </dt>
              <dd>
                <div class="text-lg font-medium text-gray-900">
                  <%= @event.description %>
                </div>
              </dd>
            </dl>
          </div>
        </div>
        <div class="mt-5">
          <div class="flex items-center justify-between">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <img class="h-10 w-10 rounded-full" src={@event.host_avatar || "https://via.placeholder.com/150"} alt={@event.host_name}>
              </div>
              <div class="ml-3">
                <p class="text-sm font-medium text-gray-900">
                  <%= @event.host_name %>
                </p>
                <p class="text-sm text-gray-500">
                  <%= format_date(@event.starts_at) %>
                </p>
              </div>
            </div>
            <button type="button" phx-click="register_for_event" phx-value-id={@event.id} class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500">
              Register
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions
  defp format_start_time(datetime) do
    # Format the datetime for display
    Calendar.strftime(datetime, "%B %d, %Y at %I:%M %p")
  end

  defp format_message_time(timestamp) do
    # Format the timestamp for chat messages
    Calendar.strftime(timestamp, "%I:%M %p")
  end

  defp format_date(datetime) do
    # Format just the date
    Calendar.strftime(datetime, "%B %d, %Y")
  end
end
