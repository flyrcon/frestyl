# lib/frestyl_web/live/media_live/show.ex
defmodule FrestylWeb.MediaLive.Show do
  use FrestylWeb, :live_view

  alias Frestyl.Media
  alias Frestyl.Media.Collaboration

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Media.subscribe()

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    asset = Media.get_asset!(id)
    versions = Media.list_asset_versions(asset)
    comments = Collaboration.list_comments(asset)
    lock_status = Collaboration.get_lock_status(asset)

    # Check if user has permission to view
    if Media.user_can_access?(asset, socket.assigns.current_user.id, :view) do
      {:noreply,
       socket
       |> assign(:page_title, asset.name)
       |> assign(:asset, asset)
       |> assign(:versions, versions)
       |> assign(:comments, comments)
       |> assign(:lock_status, lock_status)
       |> assign(:comment_changeset, Media.change_comment(%Frestyl.Media.Comment{}))}
    else
      {:noreply,
       socket
       |> put_flash(:error, "You don't have permission to view this asset.")
       |> redirect(to: ~p"/media")}
    end
  end

  @impl true
  def handle_event("lock_for_editing", _, socket) do
    case Collaboration.lock_for_editing(socket.assigns.asset, socket.assigns.current_user.id) do
      {:ok, lock} ->
        {:noreply,
         socket
         |> assign(:lock_status, {:locked, socket.assigns.current_user.id, lock.expires_at})
         |> put_flash(:info, "Asset locked for editing.")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, reason)}
    end
  end

  @impl true
  def handle_event("release_lock", _, socket) do
    case Collaboration.release_lock(socket.assigns.asset, socket.assigns.current_user.id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:lock_status, {:unlocked, nil})
         |> put_flash(:info, "Lock released.")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, reason)}
    end
  end

  @impl true
  def handle_event("add_comment", %{"comment" => comment_params}, socket) do
    case Collaboration.create_comment(
      socket.assigns.asset,
      socket.assigns.current_user.id,
      comment_params["content"]
    ) do
      {:ok, comment} ->
        comments = [comment | socket.assigns.comments]

        {:noreply,
         socket
         |> assign(:comments, comments)
         |> assign(:comment_changeset, Media.change_comment(%Frestyl.Media.Comment{}))
         |> put_flash(:info, "Comment added.")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:comment_changeset, changeset)
         |> put_flash(:error, "Error adding comment.")}
    end
  end

  @impl true
  def handle_event("delete_comment", %{"id" => comment_id}, socket) do
    comment = Enum.find(socket.assigns.comments, &(&1.id == comment_id))

    if comment.user_id == socket.assigns.current_user.id do
      case Collaboration.delete_comment(comment) do
        {:ok, _} ->
          comments = Enum.reject(socket.assigns.comments, &(&1.id == comment_id))

          {:noreply,
           socket
           |> assign(:comments, comments)
           |> put_flash(:info, "Comment deleted.")}

        {:error, _} ->
          {:noreply,
           socket
           |> put_flash(:error, "Error deleting comment.")}
      end
    else
      {:noreply,
       socket
       |> put_flash(:error, "You can only delete your own comments.")}
    end
  end

  @impl true
  def handle_info({:comment_added, comment}, socket) do
    if comment.asset_id == socket.assigns.asset.id do
      {:noreply, update(socket, :comments, fn comments -> [comment | comments] end)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:comment_deleted, comment}, socket) do
    if comment.asset_id == socket.assigns.asset.id do
      {:noreply, update(socket, :comments, fn comments -> Enum.reject(comments, &(&1.id == comment.id)) end)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:version_added, version}, socket) do
    if version.asset_id == socket.assigns.asset.id do
      {:noreply, update(socket, :versions, fn versions -> [version | versions] end)}
    else
      {:noreply, socket}
    end
  end
end
