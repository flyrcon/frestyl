defmodule FrestylWeb.Api.SearchController do
  use FrestylWeb, :controller

  def index(conn, params) do
    # TODO: Replace with actual search logic
    results = [
      %{id: 1, type: "channel", name: "Demo Channel"},
      %{id: 2, type: "event", name: "Sample Event"},
      %{id: 3, type: "user", name: "Jane Doe"}
    ]

    json(conn, %{results: results, query: params["q"]})
  end
end
