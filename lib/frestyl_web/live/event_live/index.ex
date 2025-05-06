# lib/frestyl_web/live/event_live/index.ex
defmodule FrestylWeb.EventLive.Index do
  use FrestylWeb, :live_view

  alias Frestyl.Events
  alias Frestyl.Events.Event

  @impl true
  def mount(_params, _session, socket) do
    events = Events.list_events()

    {:ok,
     socket
     |> assign(:page_title, "Events")
     |> assign(:events, events)
     |> assign(:live_action, socket.assigns.live_action)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Events")
    |> assign(:event, nil)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "Create Event")
    |> assign(:event, %Event{})
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    event = Events.get_event!(id)

    socket
    |> assign(:page_title, "Edit Event")
    |> assign(:event, event)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    event = Events.get_event!(id)
    {:ok, _} = Events.delete_event(event)

    {:noreply, assign(socket, :events, Events.list_events())}
  end
end
