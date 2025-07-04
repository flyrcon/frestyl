defmodule FrestylWeb.PortfolioLive.Stories do
  use FrestylWeb, :live_view

  alias Frestyl.Portfolios

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    stories = Portfolios.list_user_portfolios(user.id)

    socket = socket
    |> assign(:page_title, "Your Stories")
    |> assign(:stories, stories)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="flex justify-between items-center mb-8">
        <h1 class="text-3xl font-bold">Your Stories</h1>
        <.link
          navigate={~p"/portfolios/stories/new"}
          class="bg-green-600 text-white px-4 py-2 rounded hover:bg-green-700"
        >
          Create New Story
        </.link>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <div :for={story <- @stories} class="border rounded-lg p-6">
          <h3 class="text-xl font-semibold mb-2"><%= story.title %></h3>
          <p class="text-gray-600 mb-4"><%= story.description || "No description" %></p>
          <div class="flex space-x-2">
            <.link
              navigate={~p"/portfolios/#{story.id}/edit"}
              class="bg-blue-600 text-white px-3 py-1 rounded text-sm hover:bg-blue-700"
            >
              Edit
            </.link>
            <.link
              navigate={~p"/p/#{story.slug}"}
              class="bg-gray-600 text-white px-3 py-1 rounded text-sm hover:bg-gray-700"
            >
              View
            </.link>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
