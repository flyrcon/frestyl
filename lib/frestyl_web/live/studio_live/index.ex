# lib/frestyl_web/live/studio_live/index.ex
defmodule FrestylWeb.StudioLive.Index do
  use FrestylWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Studio")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-8">
      <h1 class="text-3xl font-bold">Studio</h1>
      <p>Welcome to the Studio!</p>
    </div>
    """
  end
end
