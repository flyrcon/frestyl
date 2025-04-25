# lib/frestyl_web/live/event_live/show.ex
defmodule FrestylWeb.EventLive.Show do
  use FrestylWeb, :live_view

  alias Frestyl.Events

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(Frestyl.PubSub, "event_updates")

    {:ok, socket}
    {:ok, socket |> assign(:sound_check_needed, true)}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    event = Events.get_event_full!(id)
    current_user = socket.assigns.current_user

    is_host = Events.is_host?(event, current_user)
    attendee = Events.get_attendee_by_event_and_user(event.id, current_user.id)

    {:noreply,
     socket
     |> assign(:page_title, "Event: #{event.title}")
     |> assign(:event, event)
     |> assign(:is_host, is_host)
     |> assign(:attendee, attendee)
     |> assign(:current_tab, "details")}
  end

  @impl true
  def handle_event("change-tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :current_tab, tab)}
  end

  @impl true
  def handle_event("register", _, socket) do
    event = socket.assigns.event
    current_user = socket.assigns.current_user

    case Events.register_for_event(event, current_user) do
      {:ok, attendee} ->
        {:noreply,
         socket
         |> put_flash(:info, "Successfully registered for the event.")
         |> assign(:attendee, attendee)}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Error registering for the event: #{error_message(changeset)}")}
    end
  end

  @impl true
  def handle_event("start_event", _, socket) do
    if socket.assigns.is_host do
      {:ok, event} = Events.start_event(socket.assigns.event)
      Phoenix.PubSub.broadcast(Frestyl.PubSub, "event_updates", {:event_started, event})

      {:noreply,
       socket
       |> put_flash(:info, "Event started!")
       |> assign(:event, Events.get_event_full!(event.id))}
    else
      {:noreply, put_flash(socket, :error, "Only the host can start the event.")}
    end
  end

  @impl true
  def handle_event("end_event", _, socket) do
    if socket.assigns.is_host do
      {:ok, event} = Events.end_event(socket.assigns.event)
      Phoenix.PubSub.broadcast(Frestyl.PubSub, "event_updates", {:event_ended, event})

      {:noreply,
       socket
       |> put_flash(:info, "Event ended.")
       |> assign(:event, Events.get_event_full!(event.id))}
    else
      {:noreply, put_flash(socket, :error, "Only the host can end the event.")}
    end
  end

  @impl true
  def handle_event("cancel_event", _, socket) do
    if socket.assigns.is_host do
      {:ok, event} = Events.cancel_event(socket.assigns.event)
      Phoenix.PubSub.broadcast(Frestyl.PubSub, "event_updates", {:event_cancelled, event})

      {:noreply,
       socket
       |> put_flash(:info, "Event cancelled.")
       |> assign(:event, Events.get_event_full!(event.id))}
    else
      {:noreply, put_flash(socket, :error, "Only the host can cancel the event.")}
    end
  end

  @impl true
  def handle_event("join", _, socket) do
    attendee = socket.assigns.attendee

    if attendee && attendee.status == :admitted do
      {:ok, updated_attendee} = Events.join_event(attendee)

      {:noreply,
       socket
       |> assign(:attendee, updated_attendee)}
    else
      {:noreply, put_flash(socket, :error, "You are not admitted to this event.")}
    end
  end

  @impl true
  def handle_event("leave", _, socket) do
    attendee = socket.assigns.attendee

    if attendee && attendee.joined_at do
      {:ok, updated_attendee} = Events.leave_event(attendee)

      {:noreply,
       socket
       |> assign(:attendee, updated_attendee)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("admit_attendee", %{"id" => attendee_id}, socket) do
    if socket.assigns.is_host do
      attendee = Events.get_attendee!(attendee_id)
      {:ok, _attendee} = Events.admit_attendee(attendee)

      event = Events.get_event_full!(socket.assigns.event.id)

      {:noreply,
       socket
       |> put_flash(:info, "Attendee admitted.")
       |> assign(:event, event)}
    else
      {:noreply, put_flash(socket, :error, "Only the host can admit attendees.")}
    end
  end

  @impl true
  def handle_event("reject_attendee", %{"id" => attendee_id}, socket) do
    if socket.assigns.is_host do
      attendee = Events.get_attendee!(attendee_id)
      {:ok, _attendee} = Events.reject_attendee(attendee)

      event = Events.get_event_full!(socket.assigns.event.id)

      {:noreply,
       socket
       |> put_flash(:info, "Attendee rejected.")
       |> assign(:event, event)}
    else
      {:noreply, put_flash(socket, :error, "Only the host can reject attendees.")}
    end
  end

  @impl true
  def handle_event("run_lottery", _, socket) do
    if socket.assigns.is_host && socket.assigns.event.admission_type == :lottery do
      :ok = Events.run_admission_lottery(socket.assigns.event)

      event = Events.get_event_full!(socket.assigns.event.id)

      {:noreply,
       socket
       |> put_flash(:info, "Lottery completed.")
       |> assign(:event, event)}
    else
      {:noreply, put_flash(socket, :error, "Cannot run lottery for this event.")}
    end
  end

  @impl true
  def handle_event("invite", %{"email" => email}, socket) do
    if socket.assigns.is_host do
      case Events.create_invitation(socket.assigns.event, email) do
        {:ok, _invitation} ->
          # Here you would normally send an email with the invitation
          {:noreply, put_flash(socket, :info, "Invitation sent.")}

        {:error, changeset} ->
          {:noreply, put_flash(socket, :error, "Error creating invitation: #{error_message(changeset)}")}
      end
    else
      {:noreply, put_flash(socket, :error, "Only the host can send invitations.")}
    end
  end

  @impl true
  def handle_event("cast_vote", %{"creator_id" => creator_id, "score" => score, "comment" => comment}, socket) do
    event = socket.assigns.event
    current_user = socket.assigns.current_user
    creator = Frestyl.Accounts.get_user!(creator_id)

    # Convert score from string to integer
    {score, _} = Integer.parse(score)

    case Events.cast_vote(event, current_user, creator, score, comment) do
      {:ok, _vote} ->
        {:noreply, put_flash(socket, :info, "Vote recorded.")}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, "Error recording vote: #{error_message(changeset)}")}
    end
  end

  @impl true
  def handle_info({:event_started, event}, socket) do
    if socket.assigns.event.id == event.id do
      {:noreply,
       socket
       |> put_flash(:info, "This event has started!")
       |> assign(:event, Events.get_event_full!(event.id))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:event_ended, event}, socket) do
    if socket.assigns.event.id == event.id do
      {:noreply,
       socket
       |> put_flash(:info, "This event has ended.")
       |> assign(:event, Events.get_event_full!(event.id))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:event_cancelled, event}, socket) do
    if socket.assigns.event.id == event.id do
      {:noreply,
       socket
       |> put_flash(:info, "This event has been cancelled.")
       |> assign(:event, Events.get_event_full!(event.id))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:payment_processed, attendee}, socket) do
    {:noreply, assign(socket, :attendee, attendee)}
  end

  @impl true
  def handle_info(:sound_check_completed, socket) do
    {:noreply, assign(socket, :sound_check_needed, false)}
  end

  defp error_message(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map(fn {k, v} -> "#{k}: #{Enum.join(v, ", ")}" end)
    |> Enum.join("; ")
  end
end
