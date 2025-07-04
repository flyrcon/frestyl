defmodule FrestylWeb.PortfolioLive.Templates do
  use FrestylWeb, :live_view

  alias Frestyl.Portfolios.PortfolioTemplates

  @impl true
  def mount(_params, _session, socket) do
    templates = PortfolioTemplates.available_templates()

    socket = socket
    |> assign(:page_title, "Portfolio Templates")
    |> assign(:templates, templates)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <h1 class="text-3xl font-bold mb-8">Portfolio Templates</h1>

      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <div :for={{template_key, template_config} <- @templates} class="border rounded-lg p-6">
          <h3 class="text-xl font-semibold mb-2"><%= template_config.name %></h3>
          <p class="text-gray-600 mb-4"><%= template_config.description %></p>
          <.link
            navigate={~p"/portfolios/new?template=#{template_key}"}
            class="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700"
          >
            Use Template
          </.link>
        </div>
      </div>
    </div>
    """
  end
end
