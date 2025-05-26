# lib/frestyl_web/live/channel_live/index.ex
defmodule FrestylWeb.ChannelLive.Index do
  use FrestylWeb, :live_view

  on_mount {FrestylWeb.UserAuth, :ensure_authenticated}

  alias Frestyl.Channels
  alias Frestyl.Channels.Channel
  import FrestylWeb.Navigation, only: [nav: 1]

  @impl true
  def mount(_params, _session, socket) do
    # User should now be assigned in socket by the on_mount callback
    current_user = socket.assigns.current_user

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Frestyl.PubSub, "channels")
    end

    socket = socket
      |> assign(:user_channels, Channels.list_user_channels(current_user.id))
      |> assign(:public_channels, Channels.list_public_channels())
      |> assign(:search, "")
      |> assign(:modal_visible, false)
      |> assign(:page_title, "Channels")
      |> assign(:channel, %Channel{})

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Channels")
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Channel")
    |> assign(:modal_title, "Create a New Channel")
    |> assign(:channel, %Channel{})
    |> assign(:modal_visible, true)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    channel = Channels.get_channel!(id)

    socket
    |> assign(:page_title, "Edit #{channel.name}")
    |> assign(:modal_title, "Edit Channel")
    |> assign(:channel, channel)
    |> assign(:modal_visible, true)
  end

  @impl true
  def handle_event("close_modal", _, socket) do
    {:noreply, push_patch(socket, to: ~p"/channels")}
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    public_channels =
      if search && search != "" do
        Channels.search_public_channels(search)
      else
        Channels.list_public_channels()
      end

    {:noreply, assign(socket, public_channels: public_channels, search: search)}
  end

  @impl true
  def handle_event("join_channel", %{"id" => id}, socket) do
    channel = Channels.get_channel!(id)
    current_user = socket.assigns.current_user

    case Channels.join_channel(current_user, channel) do
      {:ok, _membership} ->
        user_channels = Channels.list_user_channels(current_user.id)

        {:noreply, socket
          |> put_flash(:info, "Joined channel #{channel.name}")
          |> assign(user_channels: user_channels)}

      {:error, reason} ->
        {:noreply, socket |> put_flash(:error, reason)}
    end
  end

  @impl true
  def handle_info({:channel_created, channel}, socket) do
    public_channels =
      if channel.visibility == "public" do
        [channel | socket.assigns.public_channels]
      else
        socket.assigns.public_channels
      end

    user_channels = Channels.list_user_channels(socket.assigns.current_user.id)

    {:noreply, assign(socket, public_channels: public_channels, user_channels: user_channels)}
  end

  @impl true
  def handle_info({:channel_updated, channel}, socket) do
    # Update the user channels list if needed
    user_channels = Channels.list_user_channels(socket.assigns.current_user.id)

    # Update the public channels list if needed
    public_channels =
      if channel.visibility == "public" do
        # Update the channel in the public list
        Enum.map(socket.assigns.public_channels, fn c ->
          if c.id == channel.id, do: channel, else: c
        end)
      else
        # Remove the channel from the public list if it's no longer public
        Enum.reject(socket.assigns.public_channels, fn c -> c.id == channel.id end)
      end

    {:noreply, assign(socket, public_channels: public_channels, user_channels: user_channels)}
  end

  @impl true
  def handle_info({:channel_deleted, channel}, socket) do
    # Remove the channel from both lists
    public_channels = Enum.reject(socket.assigns.public_channels, fn c -> c.id == channel.id end)
    user_channels = Enum.reject(socket.assigns.user_channels, fn c -> c.id == channel.id end)

    {:noreply, assign(socket, public_channels: public_channels, user_channels: user_channels)}
  end
end
