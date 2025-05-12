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

  # Add this to your existing form_component.ex file
  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <form phx-change="validate" phx-submit="save" phx-target={@myself} class="space-y-6">
        <!-- Channel Name -->
        <div>
          <label for="channel_name" class="block text-sm font-medium text-gray-700">Channel Name</label>
          <input
            type="text"
            name="channel[name]"
            id="channel_name"
            value={Ecto.Changeset.get_field(@changeset, :name) || ""}
            placeholder="My awesome channel"
            required
            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
          />
          <%= if error = @changeset.errors[:name] do %>
            <p class="mt-2 text-sm text-red-600"><%= translate_error(error) %></p>
          <% end %>
        </div>

        <!-- Rest of your form fields... -->

        <!-- Submit Button -->
        <div class="flex justify-end">
          <button
            type="submit"
            phx-disable-with="Saving..."
            class="inline-flex justify-center py-2 px-6 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-[#DD1155] hover:bg-[#C4134E] focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-[#DD1155]"
          >
            <%= if @channel.id, do: "Update Channel", else: "Create Channel" %>
          </button>
        </div>
      </form>
    </div>
    """
  end
end
