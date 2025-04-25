# lib/frestyl_web/live/media_live/index.ex
defmodule FrestylWeb.MediaLive.Index do
  use FrestylWeb, :live_view

  alias Frestyl.Media
  alias Frestyl.Media.Asset

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Media.subscribe()

    {:ok, assign(socket, :assets, list_assets()), temporary_assigns: [assets: []]}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Media Library")
    |> assign(:asset, nil)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Asset")
    |> assign(:asset, %Asset{})
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Asset")
    |> assign(:asset, Media.get_asset!(id))
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    asset = Media.get_asset!(id)

    # Check if user has permission to delete
    if Media.user_can_access?(asset, socket.assigns.current_user.id, :owner) do
      {:ok, _} = Media.delete_asset(asset)

      {:noreply, socket |> assign(:assets, list_assets())}
    else
      {:noreply,
       socket
       |> put_flash(:error, "You don't have permission to delete this asset.")
      }
    end
  end

  @impl true
  def handle_info({:asset_created, asset}, socket) do
    {:noreply, update(socket, :assets, fn assets -> [asset | assets] end)}
  end

  @impl true
  def handle_info({:asset_updated, asset}, socket) do
    {:noreply, update(socket, :assets, fn assets -> [asset | assets] end)}
  end

  @impl true
  def handle_info({:asset_deleted, asset}, socket) do
    {:noreply, update(socket, :assets, fn assets -> Enum.reject(assets, &(&1.id == asset.id)) end)}
  end

  defp list_assets do
    Media.list_assets()
  end
end
