defmodule FrestylWeb.ChannelLive.FormComponent do
  use FrestylWeb, :live_component

  alias Frestyl.Channels
  alias Frestyl.Channels.Channel

  @impl true
  def update(%{channel: channel, action: action} = assigns, socket) do
    changeset = Channels.change_channel(channel)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)
     |> assign(:visibility_options, Channels.visibility_options())}
  end

  @impl true
  def handle_event("validate", %{"channel" => channel_params}, socket) do
    changeset =
      socket.assigns.channel
      |> Channels.change_channel(channel_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_event("save", %{"channel" => channel_params}, socket) do
    save_channel(socket, socket.assigns.action, channel_params)
  end

  defp save_channel(socket, :edit, channel_params) do
    case Channels.update_channel(socket.assigns.channel, channel_params) do
      {:ok, _channel} ->
        {:noreply,
         socket
         |> put_flash(:info, "Channel updated successfully")
         |> push_navigate(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp save_channel(socket, :new, channel_params) do
    case Channels.create_channel(channel_params, socket.assigns.current_user) do
      {:ok, _channel} ->
        {:noreply,
         socket
         |> put_flash(:info, "Channel created successfully")
         |> push_navigate(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  # Helper function to translate error
  def translate_error({msg, opts}) do
    if count = opts[:count] do
      Gettext.dngettext(FrestylWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(FrestylWeb.Gettext, "errors", msg, opts)
    end
  end
end
