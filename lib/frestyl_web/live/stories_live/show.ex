# lib/frestyl_web/live/stories_live/show.ex

defmodule FrestylWeb.StoriesLive.Show do
  use FrestylWeb, :live_view

  alias Frestyl.Stories

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => story_id}, _uri, socket) do
    current_user = socket.assigns.current_user

    case Stories.get_enhanced_story_with_permissions(story_id, current_user.id) do
      {:ok, story, permissions} ->
        socket = socket
        |> assign(:story, story)
        |> assign(:permissions, permissions)
        |> assign(:page_title, story.title)

        {:noreply, socket}

      {:error, :not_found} ->
        {:noreply, socket
         |> put_flash(:error, "Story not found")
         |> redirect(to: ~p"/stories")}

      {:error, :access_denied} ->
        {:noreply, socket
         |> put_flash(:error, "You don't have permission to view this story")
         |> redirect(to: ~p"/stories")}
    end
  end

  @impl true
  def handle_event("delete_story", _params, socket) do
    story = socket.assigns.story

    case Stories.delete_enhanced_story(story) do
      {:ok, _} ->
        {:noreply, socket
         |> put_flash(:info, "Story deleted successfully")
         |> redirect(to: ~p"/stories")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Unable to delete story")}
    end
  end

  @impl true
  def handle_event("export_story", %{"format" => format}, socket) do
    story = socket.assigns.story

    case Stories.export_story(story, format) do
      {:ok, file_path} ->
        # In a real implementation, you'd trigger a download
        {:noreply, put_flash(socket, :info, "Story exported successfully")}

      {:error, message} ->
        {:noreply, put_flash(socket, :error, "Export failed: #{message}")}
    end
  end
end
