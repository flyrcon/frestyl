# lib/frestyl_web/live/event_live/waiting_room_component.ex
defmodule FrestylWeb.EventLive.WaitingRoomComponent do
  use FrestylWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div class="text-center p-8 border rounded-lg">
      <h2 class="text-2xl font-bold mb-4">Waiting Room</h2>

      <p class="mb-4">
        The event "<%= @event.title %>" has not started yet.
      </p>

      <div class="mb-6">
        <p class="text-xl font-semibold">Starts in:</p>
        <div class="countdown text-3xl font-bold my-4" id={"countdown-#{@id}"} phx-hook="Countdown" data-starts-at={@event.starts_at}>
          <span class="hours">--</span>:<span class="minutes">--</span>:<span class="seconds">--</span>
        </div>
      </div>

      <%= if @waiting_room_open do %>
        <p class="mb-4 text-green-600 font-semibold">
          The waiting room is open. You'll be automatically admitted when the event starts.
        </p>
      <% else %>
        <p class="mb-4">
          The waiting room will open at <%= format_datetime(@event.waiting_room_opens_at || @event.starts_at) %>
        </p>
      <% end %>

      <div class="mt-8">
        <h3 class="font-semibold mb-2">Event Details</h3>
        <p><%= @event.description %></p>
      </div>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    now = DateTime.utc_now()
    waiting_room_open =
      if assigns.event.waiting_room_opens_at do
        DateTime.compare(now, assigns.event.waiting_room_opens_at) != :lt
      else
        false
      end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:waiting_room_open, waiting_room_open)}
  end
end
