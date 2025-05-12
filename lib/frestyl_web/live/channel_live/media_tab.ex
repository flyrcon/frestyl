# lib/frestyl_web/live/channel_live/media_tab.ex
defmodule FrestylWeb.ChannelLive.MediaTab do
  use FrestylWeb, :live_view

  alias Frestyl.Channels
  alias Frestyl.Media
  alias FrestylWeb.MediaLive.MediaDisplayComponent

  @impl true
  def mount(%{"id" => channel_id}, _session, socket) do
    if connected?(socket) do
      channel = Channels.get_channel!(channel_id)

      # Check if user can access this channel
      if Channels.user_can_access?(channel, socket.assigns.current_user.id) do
        media_files = Media.list_channel_media_files(channel_id)

        {:ok,
          socket
          |> assign(:channel, channel)
          |> assign(:channel_id, channel_id)
          |> assign(:media_files, media_files)
          |> assign(:filter, "all")
          |> assign(:show_upload_modal, false)
        }
      else
        {:ok,
          socket
          |> put_flash(:error, "You don't have access to this channel")
          |> push_navigate(to: ~p"/channels")
        }
      end
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_event("filter-media", %{"filter" => filter}, socket) do
    {:noreply, assign(socket, :filter, filter)}
  end

  @impl true
  def handle_event("show-upload-modal", _, socket) do
    {:noreply, assign(socket, :show_upload_modal, true)}
  end

  @impl true
  def handle_event("hide-upload-modal", _, socket) do
    {:noreply, assign(socket, :show_upload_modal, false)}
  end

  @impl true
  def handle_info({:media_updated}, socket) do
    # Refresh media files list
    media_files = Media.list_channel_media_files(socket.assigns.channel_id)
    {:noreply, assign(socket, :media_files, media_files)}
  end

  @impl true
  def handle_info({:media_deleted, _id}, socket) do
    # Refresh media files list
    media_files = Media.list_channel_media_files(socket.assigns.channel_id)
    {:noreply,
      socket
      |> assign(:media_files, media_files)
      |> put_flash(:info, "Media file deleted successfully")
    }
  end

  defp filter_media_files(media_files, "all"), do: media_files
  defp filter_media_files(media_files, filter) do
    Enum.filter(media_files, fn file -> file.media_type == filter end)
  end
end
