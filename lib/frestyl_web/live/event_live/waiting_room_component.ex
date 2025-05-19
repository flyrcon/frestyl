# lib/frestyl_web/live/event_live/waiting_room_component.ex
defmodule FrestylWeb.EventLive.WaitingRoomComponent do
  use FrestylWeb, :live_component

  alias Phoenix.LiveView.JS
  alias Frestyl.Sessions

  def mount(socket) do
    # Initialize countdown timer state
    socket = assign(socket,
      time_remaining: nil,
      timer_ref: nil,
      show_trivia: false,
      current_trivia_index: 0,
      trivia_items: get_trivia_items(),
      poll_results: %{},
      current_poll_id: nil,
      attendee_showcase: [],
      chat_messages: [],
      user_showcase_visible: false,
      community_feed_visible: false
    )

    {:ok, socket}
  end

  def update(%{broadcast: broadcast} = assigns, socket) do
    socket = socket
      |> assign(assigns)
      |> start_countdown_timer(broadcast)
      |> maybe_show_trivia()

    {:ok, socket}
  end

  def handle_event("show_trivia", _, socket) do
    {:noreply, assign(socket, show_trivia: true)}
  end

  def handle_event("next_trivia", _, socket) do
    new_index = rem(socket.assigns.current_trivia_index + 1, length(socket.assigns.trivia_items))
    {:noreply, assign(socket, current_trivia_index: new_index)}
  end

  def handle_event("previous_trivia", _, socket) do
    new_index =
      if socket.assigns.current_trivia_index == 0 do
        length(socket.assigns.trivia_items) - 1
      else
        socket.assigns.current_trivia_index - 1
      end

    {:noreply, assign(socket, current_trivia_index: new_index)}
  end

  # Add these functions to WaitingRoomComponent

  def handle_event("create_poll", %{"question" => question, "options" => options}, socket) do
    # Only hosts can create polls
    if socket.assigns.is_host do
      # Options should be a comma-separated string
      option_list = String.split(options, ",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))

      # Create a new poll
      poll_id = Ecto.UUID.generate()

      poll = %{
        id: poll_id,
        question: question,
        options: option_list,
        votes: Map.new(option_list, &{&1, 0}),
        participants: MapSet.new()
      }

      # Broadcast the poll to all participants
      Phoenix.PubSub.broadcast(
        Frestyl.PubSub,
        "broadcast:#{socket.assigns.broadcast.id}",
        {:new_poll, poll}
      )

      {:noreply, assign(socket, current_poll_id: poll_id, poll_results: Map.put(socket.assigns.poll_results, poll_id, poll))}
    else
      {:noreply, socket}
    end
  end

  defp relative_time(datetime) do
    now = DateTime.utc_now()
    diff_seconds = DateTime.diff(now, datetime)

    cond do
      diff_seconds < 60 -> "just now"
      diff_seconds < 3600 -> "#{div(diff_seconds, 60)}m ago"
      diff_seconds < 86400 -> "#{div(diff_seconds, 3600)}h ago"
      true -> Calendar.strftime(datetime, "%b %d")
    end
  end

  def handle_event("vote", %{"poll_id" => poll_id, "option" => option}, socket) do
    # Check if poll exists and user hasn't voted yet
    user_id = socket.assigns.current_user.id

    case Map.get(socket.assigns.poll_results, poll_id) do
      nil ->
        {:noreply, socket}

      poll ->
        if MapSet.member?(poll.participants, user_id) do
          # User already voted
          {:noreply, socket}
        else
          # Update vote count
          updated_votes = Map.update(poll.votes, option, 1, &(&1 + 1))
          updated_participants = MapSet.put(poll.participants, user_id)

          updated_poll = %{
            poll |
            votes: updated_votes,
            participants: updated_participants
          }

          # Broadcast the updated poll results
          Phoenix.PubSub.broadcast(
            Frestyl.PubSub,
            "broadcast:#{socket.assigns.broadcast.id}",
            {:poll_updated, updated_poll}
          )

          {:noreply, assign(socket, poll_results: Map.put(socket.assigns.poll_results, poll_id, updated_poll))}
        end
    end
  end

  def handle_event("end_poll", %{"poll_id" => poll_id}, socket) do
    # Only hosts can end polls
    if socket.assigns.is_host do
      # Broadcast that the poll has ended
      Phoenix.PubSub.broadcast(
        Frestyl.PubSub,
        "broadcast:#{socket.assigns.broadcast.id}",
        {:poll_ended, poll_id}
      )

      # Remove poll from current_poll_id, but keep results in poll_results
      {:noreply, assign(socket, current_poll_id: nil)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("submit_showcase", %{"name" => name, "content" => content, "type" => type}, socket) do
    user = socket.assigns.current_user

    # Create a showcase entry
    showcase = %{
      id: Ecto.UUID.generate(),
      user_id: user.id,
      username: user.username,
      name: name,
      content: content,
      type: type,
      submitted_at: DateTime.utc_now(),
      approved: false  # Requires host approval
    }

    # Send to host for approval
    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "broadcast:#{socket.assigns.broadcast.id}:host",
      {:showcase_submission, showcase}
    )

    {:noreply, socket}
  end

  def handle_event("approve_showcase", %{"id" => id}, socket) do
    # Only hosts can approve
    if socket.assigns.is_host do
      showcase = Enum.find(socket.assigns.pending_showcases, &(&1.id == id))

      if showcase do
        # Mark as approved
        approved_showcase = %{showcase | approved: true}

        # Add to the showcase list and broadcast
        Phoenix.PubSub.broadcast(
          Frestyl.PubSub,
          "broadcast:#{socket.assigns.broadcast.id}",
          {:showcase_approved, approved_showcase}
        )

        # Update local state
        updated_showcases = socket.assigns.attendee_showcase ++ [approved_showcase]
        pending = Enum.reject(socket.assigns.pending_showcases, &(&1.id == id))

        {:noreply,
        socket
        |> assign(:attendee_showcase, updated_showcases)
        |> assign(:pending_showcases, pending)}
      else
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("toggle_user_showcase", _, socket) do
    {:noreply, assign(socket, user_showcase_visible: !socket.assigns.user_showcase_visible)}
  end

  def handle_event("toggle_community_feed", _, socket) do
    {:noreply, assign(socket, community_feed_visible: !socket.assigns.community_feed_visible)}
  end

  def handle_info({:new_poll, poll}, socket) do
    # Add the new poll to our state
    {:noreply,
    socket
    |> assign(:poll_results, Map.put(socket.assigns.poll_results, poll.id, poll))
    |> assign(:current_poll_id, poll.id)}
  end

  def handle_info({:poll_updated, poll}, socket) do
    # Update the poll results
    {:noreply, assign(socket, :poll_results, Map.put(socket.assigns.poll_results, poll.id, poll))}
  end

  def handle_info({:poll_ended, poll_id}, socket) do
    if socket.assigns.current_poll_id == poll_id do
      {:noreply, assign(socket, :current_poll_id, nil)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:showcase_submission, showcase}, socket) do
    # Only hosts receive this
    if socket.assigns.is_host do
      pending = socket.assigns.pending_showcases || []
      {:noreply, assign(socket, :pending_showcases, pending ++ [showcase])}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:showcase_approved, showcase}, socket) do
    # Add the approved showcase to our list
    showcases = socket.assigns.attendee_showcase || []
    {:noreply, assign(socket, :attendee_showcase, showcases ++ [showcase])}
  end

  def handle_info(:tick, socket) do
    now = DateTime.utc_now()
    broadcast = socket.assigns.broadcast

    # Check if it's time to start the broadcast
    if DateTime.compare(now, broadcast.scheduled_for) in [:eq, :gt] do
      # Broadcast has started, redirect to live broadcast
      send(self(), {:broadcast_started, broadcast.id})

      if socket.assigns.timer_ref do
        Process.cancel_timer(socket.assigns.timer_ref)
      end

      {:noreply, assign(socket, timer_ref: nil)}
    else
      # Update the countdown
      time_remaining = DateTime.diff(broadcast.scheduled_for, now)

      # Schedule next tick
      timer_ref = Process.send_after(self(), :tick, 1000)

      {:noreply, assign(socket, time_remaining: time_remaining, timer_ref: timer_ref)}
    end
  end

  # Helper functions

  defp start_countdown_timer(socket, broadcast) do
    # Cancel any existing timer
    if socket.assigns.timer_ref do
      Process.cancel_timer(socket.assigns.timer_ref)
    end

    # Start a new countdown
    now = DateTime.utc_now()

    if DateTime.compare(now, broadcast.scheduled_for) in [:eq, :gt] do
      # Broadcast has already started, redirect to live broadcast
      send(self(), {:broadcast_started, broadcast.id})
      assign(socket, time_remaining: 0, timer_ref: nil)
    else
      # Calculate initial time remaining
      time_remaining = DateTime.diff(broadcast.scheduled_for, now)

      # Start timer
      timer_ref = Process.send_after(self(), :tick, 1000)

      assign(socket, time_remaining: time_remaining, timer_ref: timer_ref)
    end
  end

  defp maybe_show_trivia(socket) do
    # Show trivia automatically if waiting time is more than 5 minutes
    if socket.assigns.time_remaining && socket.assigns.time_remaining > 300 do
      assign(socket, show_trivia: true)
    else
      socket
    end
  end

  defp get_trivia_items do
    # This would normally come from the database or context
    [
      %{
        title: "Did you know?",
        content: "Collaborative music sessions can improve creativity by up to 70% compared to solo work.",
        image_url: "/images/trivia/collaboration.jpg"
      },
      %{
        title: "Fun Fact",
        content: "The average song on streaming platforms is now 3 minutes and 42 seconds, down from 4:30 in the 1990s.",
        image_url: "/images/trivia/streaming.jpg"
      },
      %{
        title: "Tech Tip",
        content: "Using headphones during a live session reduces echo and feedback for other participants.",
        image_url: "/images/trivia/headphones.jpg"
      },
      %{
        title: "Quick History",
        content: "The first online collaborative music session happened in 1998 between musicians in New York and London.",
        image_url: "/images/trivia/history.jpg"
      },
      %{
        title: "Platform Feature",
        content: "You can save and export your collaboration sessions for later editing in most DAW software.",
        image_url: "/images/trivia/export.jpg"
      }
    ]
  end

  defp format_time_remaining(seconds) do
    hours = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)
    seconds = rem(seconds, 60)

    cond do
      hours > 0 ->
        "#{hours}h #{minutes}m #{seconds}s"
      minutes > 0 ->
        "#{minutes}m #{seconds}s"
      true ->
        "#{seconds}s"
    end
  end

  def render(assigns) do
    ~H"""
    <div class="bg-gradient-to-br from-gray-900 to-indigo-900 min-h-screen flex items-center justify-center">
      <div class="max-w-4xl w-full mx-auto px-4 py-8">
        <div class="bg-gray-800 bg-opacity-70 rounded-xl shadow-xl overflow-hidden">
          <!-- Header -->
          <div class="p-6 border-b border-gray-700">
            <div class="flex items-center justify-between">
              <h1 class="text-2xl font-bold text-white"><%= @broadcast.title %></h1>

              <div class="flex items-center">
                <div class="bg-yellow-500 bg-opacity-20 text-yellow-400 text-sm px-3 py-1 rounded-full flex items-center">
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 mr-1" viewBox="0 0 20 20" fill="currentColor">
                    <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-12a1 1 0 10-2 0v4a1 1 0 00.293.707l2.828 2.829a1 1 0 101.415-1.415L11 9.586V6z" clip-rule="evenodd" />
                  </svg>
                  <span>Starting in <%= format_time_remaining(@time_remaining) %></span>
                </div>
              </div>
            </div>

            <div class="mt-2 text-gray-400"><%= @broadcast.description %></div>
          </div>

          <!-- Main content -->
          <div class="p-6">
            <div class="grid grid-cols-1 md:grid-cols-5 gap-6">
              <!-- Left column - Host info and details -->
              <div class="md:col-span-2 space-y-6">
                <div class="bg-gray-900 bg-opacity-70 rounded-lg p-4">
                  <h2 class="text-lg font-semibold text-white mb-4">Host</h2>

                  <div class="flex items-center">
                    <div class="h-16 w-16 rounded-full bg-gradient-to-r from-indigo-500 to-purple-600 flex items-center justify-center text-white text-2xl font-bold">
                      <%= String.first(@host.username) %>
                    </div>

                    <div class="ml-4">
                      <h3 class="text-white font-medium"><%= @host.username %></h3>
                      <p class="text-gray-400 text-sm"><%= @host.bio || "No bio available" %></p>
                    </div>
                  </div>
                </div>

                <div class="bg-gray-900 bg-opacity-70 rounded-lg p-4">
                  <h2 class="text-lg font-semibold text-white mb-4">Broadcast Details</h2>

                  <div class="space-y-3">
                    <div class="flex items-center">
                      <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-gray-400 mr-2" viewBox="0 0 20 20" fill="currentColor">
                        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-12a1 1 0 10-2 0v4a1 1 0 00.293.707l2.828 2.829a1 1 0 101.415-1.415L11 9.586V6z" clip-rule="evenodd" />
                      </svg>
                      <div>
                        <p class="text-white text-sm">Starts at</p>
                        <p class="text-gray-400 text-sm"><%= Calendar.strftime(@broadcast.scheduled_for, "%A, %B %d, %Y at %I:%M %p") %></p>
                      </div>
                    </div>

                    <div class="flex items-center">
                      <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-gray-400 mr-2" viewBox="0 0 20 20" fill="currentColor">
                        <path d="M13 6a3 3 0 11-6 0 3 3 0 016 0zM18 8a2 2 0 11-4 0 2 2 0 014 0zM14 15a4 4 0 00-8 0v1h8v-1zM6 8a2 2 0 11-4 0 2 2 0 014 0zM16 18v-1a5.972 5.972 0 00-.75-2.906A3.005 3.005 0 0119 15v1h-3zM4.75 12.094A5.973 5.973 0 004 15v1H1v-1a3 3 0 013.75-2.906z" />
                      </svg>
                      <div>
                        <p class="text-white text-sm">Attendees</p>
                        <p class="text-gray-400 text-sm"><%= @participant_count %> registered</p>
                      </div>
                    </div>

                    <div class="flex items-center">
                      <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-gray-400 mr-2" viewBox="0 0 20 20" fill="currentColor">
                        <path fill-rule="evenodd" d="M4 4a2 2 0 012-2h4.586A2 2 0 0112 2.586L15.414 6A2 2 0 0116 7.414V16a2 2 0 01-2 2H6a2 2 0 01-2-2V4zm2 6a1 1 0 011-1h6a1 1 0 110 2H7a1 1 0 01-1-1zm1 3a1 1 0 100 2h6a1 1 0 100-2H7z" clip-rule="evenodd" />
                      </svg>
                      <div>
                        <p class="text-white text-sm">Type</p>
                        <p class="text-gray-400 text-sm"><%= String.capitalize(@broadcast.broadcast_type) %></p>
                      </div>
                    </div>
                  </div>
                </div>

                <div class="bg-gray-900 bg-opacity-70 rounded-lg p-4">
                  <h2 class="text-lg font-semibold text-white mb-4">Countdown</h2>

                  <div class="flex justify-center">
                    <div class="grid grid-cols-4 gap-2 text-center">
                      <div class="bg-gray-800 rounded-lg p-3">
                        <div class="text-2xl font-bold text-white"><%= div(@time_remaining, 3600) %></div>
                        <div class="text-xs text-gray-400">Hours</div>
                      </div>
                      <div class="bg-gray-800 rounded-lg p-3">
                        <div class="text-2xl font-bold text-white"><%= div(rem(@time_remaining, 3600), 60) %></div>
                        <div class="text-xs text-gray-400">Minutes</div>
                      </div>
                      <div class="bg-gray-800 rounded-lg p-3">
                        <div class="text-2xl font-bold text-white"><%= rem(@time_remaining, 60) %></div>
                        <div class="text-xs text-gray-400">Seconds</div>
                      </div>
                      <div class="bg-gradient-to-r from-indigo-500 to-purple-600 rounded-lg p-3">
                        <div class="text-2xl font-bold text-white"><%= @participant_count %></div>
                        <div class="text-xs text-white">Waiting</div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>

              <!-- Right column - Preview and trivia -->
              <div class="md:col-span-3 space-y-6">
                <div class="bg-gray-900 bg-opacity-70 rounded-lg p-4 flex flex-col items-center justify-center min-h-[300px]">
                  <%= if @broadcast.preview_image_url do %>
                    <img
                      src={@broadcast.preview_image_url}
                      alt={@broadcast.title}
                      class="rounded-lg max-h-[300px] object-cover"
                    />
                  <% else %>
                    <div class="text-center">
                      <svg xmlns="http://www.w3.org/2000/svg" class="h-16 w-16 mx-auto text-indigo-500 mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z" />
                      </svg>
                      <h3 class="text-white text-lg mb-1">Broadcast Preview</h3>
                      <p class="text-gray-400 text-sm">The broadcast will appear here when it starts</p>
                    </div>
                  <% end %>
                </div>

                <%= if @show_trivia do %>
                  <div class="bg-gray-900 bg-opacity-70 rounded-lg p-4">
                    <div class="flex items-center justify-between mb-4">
                      <h2 class="text-lg font-semibold text-white">While You Wait...</h2>

                      <div class="flex space-x-2">
                        <button
                          phx-click="previous_trivia"
                          phx-target={@myself}
                          class="bg-gray-800 hover:bg-gray-700 text-gray-400 rounded-full p-1"
                        >
                          <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                            <path fill-rule="evenodd" d="M12.707 5.293a1 1 0 010 1.414L9.414 10l3.293 3.293a1 1 0 01-1.414 1.414l-4-4a1 1 0 010-1.414l4-4a1 1 0 011.414 0z" clip-rule="evenodd" />
                          </svg>
                        </button>
                        <button
                          phx-click="next_trivia"
                          phx-target={@myself}
                          class="bg-gray-800 hover:bg-gray-700 text-gray-400 rounded-full p-1"
                        >
                          <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                            <path fill-rule="evenodd" d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z" clip-rule="evenodd" />
                          </svg>
                        </button>
                      </div>
                    </div>

                    <% current_trivia = Enum.at(@trivia_items, @current_trivia_index) %>

                    <div class="bg-gray-800 rounded-lg overflow-hidden">
                      <%= if current_trivia.image_url do %>
                        <img
                          src={current_trivia.image_url}
                          alt={current_trivia.title}
                          class="w-full h-48 object-cover"
                        />
                      <% end %>

                      <div class="p-4">
                        <h3 class="text-white font-medium text-lg mb-2"><%= current_trivia.title %></h3>
                        <p class="text-gray-400"><%= current_trivia.content %></p>
                      </div>
                    </div>
                  </div>
                <% else %>
                  <div class="bg-gray-900 bg-opacity-70 rounded-lg p-4 flex flex-col items-center justify-center">
                    <button
                      phx-click="show_trivia"
                      phx-target={@myself}
                      class="bg-indigo-500 hover:bg-indigo-600 text-white px-4 py-2 rounded-md text-sm font-medium"
                    >
                      Show Trivia & Facts
                    </button>
                  </div>
                <% end %>

                <div class="bg-gray-900 bg-opacity-70 rounded-lg p-4">
                  <div class="flex items-center justify-between mb-4">
                    <h2 class="text-lg font-semibold text-white">Chat</h2>

                    <div class="text-sm text-gray-500">
                      Chat will be enabled when the broadcast starts
                    </div>
                  </div>

                  <div class="bg-gray-800 rounded-lg p-4 min-h-[100px] flex items-center justify-center">
                    <p class="text-gray-500 text-center">The chat will be available when the broadcast begins</p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
