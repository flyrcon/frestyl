# lib/frestyl_web/live/event_live/index.ex
defmodule FrestylWeb.EventLive.Index do
  use FrestylWeb, :live_view

  alias Frestyl.Events
  alias Frestyl.Events.Event
  # Ensure Logger is required for logging statements
  require Logger

  @impl true
  def mount(_params, session, socket) do
    # This mount function is called when the LiveView is initially rendered
    # (either static or initial full mount). handle_params is called next.

    Logger.info("EventLive.Index mount called")

    # Get current user from session (ensure this function handles nil session token gracefully)
    current_user = Frestyl.Accounts.get_user_by_session_token(session["user_token"])

    # Fetch initial list of events for the index view
    events = Events.list_events() # Or filter by user if needed

    {:ok,
     socket
     |> assign(:current_user, current_user)
     |> assign(:events, events)
     |> assign(:page_title, "Events")
     # We don't assign live_action or event here initially.
     # handle_params will be called immediately after mount and will set these
     # based on the initial URL.
     |> assign(:live_action, nil)
     |> assign(:event, nil)}
  end

  @impl true
  # This clause handles paths like /events/new or /events/123/edit where
  # the router has explicitly added the 'live_action' parameter.
  def handle_params(%{"live_action" => live_action} = params, url, socket) do
    Logger.info("EventLive.Index handle_params called with URL: #{url}, live_action: #{live_action}")
    Logger.debug("Params: #{inspect(params)}")

    # Call apply_action with the live_action derived from the URL params
    {:noreply, apply_action(socket, String.to_atom(live_action), params)}
  end

  @impl true
  # This clause handles the base path /events where no 'live_action' is
  # typically present in the URL params, but the router might still set it.
  # We default to :index here.
  def handle_params(params, url, socket) do
    Logger.info("EventLive.Index handle_params called with URL: #{url}, no explicit live_action param.")
    Logger.debug("Params: #{inspect(params)}")

    # Default action for the base path
    action = :index
     Logger.info("Defaulting to action: #{action}")
    {:noreply, apply_action(socket, action, params)}
  end


  # --- Private helper to apply the action based on the live_action ---
  # This function updates the socket's assigns based on the current action.
  # Crucially, it assigns the @live_action back to the socket.

  defp apply_action(socket, :index, _params) do
    Logger.info("EventLive.Index applying action: :index")
    # Re-fetch events here if they should be updated when navigating back to the index view.
    # If your events list is large or fetching is expensive, consider a pub/sub approach
    # to update the list when events are created/updated/deleted by the component.
    events = Events.list_events()

    socket
    |> assign(:page_title, "Events")
    |> assign(:live_action, :index) # <--- IMPORTANT: Assign the action back
    |> assign(:event, nil)
    |> assign(:events, events) # Assign the potentially refreshed list
  end

  defp apply_action(socket, :new, _params) do
    Logger.info("EventLive.Index applying action: :new")
    socket
    |> assign(:page_title, "Create Event")
    |> assign(:live_action, :new) # <--- IMPORTANT: Assign the action back
    |> assign(:event, %Event{}) # Assign a new, empty Event struct for the form
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    Logger.info("EventLive.Index applying action: :edit for ID: #{id}")
    # Use get_event/1 (returns nil if not found) instead of get_event!/1
    # to prevent a crash if an invalid ID is in the URL.
    case Events.get_event(id) do
      nil ->
         Logger.error("Event with ID #{id} not found for editing.")
         # If the event is not found, redirect back to the index page
         # and optionally show a flash message.
         socket
         |> put_flash(:error, "Event not found.")
         |> push_navigate(to: ~p"/events") # Redirect requires a navigation message
      event ->
         # If the event is found, assign it for the form
         socket
         |> assign(:page_title, "Edit Event")
         |> assign(:live_action, :edit) # <--- IMPORTANT: Assign the action back
         |> assign(:event, event)
    end
  end

  # --- handle_event for the delete action ---
  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    Logger.info("EventLive.Index handling delete event for ID: #{id}")
    # Using get_event! here is more acceptable as it's a user-triggered action
    # where we expect the ID to be valid from the rendered list.
    event = Events.get_event!(id)
    {:ok, _} = Events.delete_event(event)
    Logger.info("Event #{id} deleted successfully.")

    # After deletion, refresh the list of events displayed on the index page.
    {:noreply, assign(socket, :events, Events.list_events())}
  end

  # Optional: handle_info to receive messages from the FormComponent
  # For example, if the component broadcasts {:event_saved, event}
  # @impl true
  # def handle_info({:event_saved, _event}, socket) do
  #   Logger.info("EventLive.Index received :event_saved info message")
  #   # If you want the index list to update automatically after saving
  #   {:noreply, assign(socket, :events, Events.list_events())}
  # end

end
