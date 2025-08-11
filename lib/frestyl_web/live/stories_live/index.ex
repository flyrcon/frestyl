# lib/frestyl_web/live/stories_live/index.ex

defmodule FrestylWeb.StoriesLive.Index do
  use FrestylWeb, :live_view

  alias Frestyl.Stories

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user
    stories = Stories.list_user_stories(current_user.id)

    socket = socket
    |> assign(:stories, stories)
    |> assign(:page_title, "My Stories")

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    assign(socket, :page_title, "My Stories")
  end

  @impl true
  def handle_event("delete_story", %{"id" => id}, socket) do
    story = Stories.get_enhanced_story!(id)

    case Stories.delete_enhanced_story(story) do
      {:ok, _} ->
        stories = Stories.list_user_stories(socket.assigns.current_user.id)
        {:noreply, socket
         |> put_flash(:info, "Story deleted successfully")
         |> assign(:stories, stories)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Unable to delete story")}
    end
  end
end
