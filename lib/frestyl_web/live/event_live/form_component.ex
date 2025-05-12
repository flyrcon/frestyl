# lib/frestyl_web/live/event_live/form_component.ex
defmodule FrestylWeb.EventLive.FormComponent do
  use FrestylWeb, :live_component

  alias Frestyl.Events
  import Frestyl.Sessions

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle>Use this form to manage event records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="event-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:title]} type="text" label="Title" />
        <.input field={@form[:description]} type="textarea" label="Description" />
        <.input field={@form[:starts_at]} type="datetime-local" label="Starts at" />
        <.input field={@form[:ends_at]} type="datetime-local" label="Ends at" />
        <.input
          field={@form[:status]}
          type="select"
          label="Status"
          options={[
            {"Draft", :draft},
            {"Scheduled", :scheduled},
            {"Live", :live},
            {"Completed", :completed},
            {"Cancelled", :cancelled}
          ]}
        />
        <.input
          field={@form[:admission_type]}
          type="select"
          label="Admission Type"
          options={[
            {"Open", :open},
            {"Invite Only", :invite_only},
            {"Paid", :paid},
            {"Lottery", :lottery}
          ]}
        />
        <.input
          field={@form[:price_in_cents]}
          type="number"
          label="Price (in cents)"
          phx-hook="ShowHidePrice"
          data-admission-type="paid"
        />
        <.input
          field={@form[:max_attendees]}
          type="number"
          label="Maximum Attendees"
          phx-hook="ShowHideMaxAttendees"
          data-admission-type="lottery"
        />
        <.input
          field={@form[:waiting_room_opens_at]}
          type="datetime-local"
          label="Waiting Room Opens At"
        />
        <.input
          field={@form[:session_id]}
          type="select"
          label="Session"
          options={@sessions}
          prompt="Select a session (optional)"
        />

        <:actions>
          <.button phx-disable-with="Saving...">Save Event</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{event: event} = assigns, socket) do
    # For a new event, initialize any needed fields
    event = if event.id == nil do
      # Set defaults for new events
      now = DateTime.utc_now()
      tomorrow = DateTime.add(now, 1, :day)
      next_week = DateTime.add(now, 7, :day)

      %{event |
        status: :draft,
        admission_type: :open,
        # Set some reasonable defaults for dates
        starts_at: next_week,
        ends_at: DateTime.add(next_week, 3, :hour)
      }
    else
      event
    end

    changeset = Frestyl.Events.change_event(event)

    # Get current_user from assigns or provide a fallback
    current_user = assigns[:current_user]

    # Get sessions list, safely handling nil current_user
    sessions =
      if current_user do
        list_sessions(current_user)
      else
        []
      end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:sessions, sessions)
     |> assign_form(changeset)}
  end

  defp list_sessions(current_user) do
    Frestyl.Sessions.list_user_sessions(current_user)
    |> Enum.map(fn session -> {session.title, session.id} end)
  end

  @impl true
  def handle_event("validate", %{"event" => event_params}, socket) do
    changeset =
      socket.assigns.event
      |> Events.change_event(event_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"event" => event_params}, socket) do
    save_event(socket, socket.assigns.action, event_params)
  end

  defp save_event(socket, :new, event_params) do
    current_user = socket.assigns.current_user

    case Events.create_event(event_params, current_user) do
      {:ok, _event} ->
        {:noreply,
         socket
         |> put_flash(:info, "Event created successfully")
         |> push_navigate(to: socket.assigns.navigate)}
      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp list_sessions(nil), do: []  # Handle the case when current_user is nil
  defp list_sessions(current_user) do
    Frestyl.Sessions.list_user_sessions(current_user)
    |> Enum.map(fn session -> {session.title, session.id} end)
  end

  defp save_event(socket, :new, event_params) do
    current_user = socket.assigns.current_user

    case Events.create_event(event_params, current_user) do
      {:ok, _event} ->
        {:noreply,
         socket
         |> put_flash(:info, "Event created successfully")
         |> push_navigate(to: socket.assigns.navigate)}
      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end
end
