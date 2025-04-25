# lib/frestyl_web/controllers/search_controller.ex
defmodule FrestylWeb.SearchController do
  use FrestylWeb, :controller

  alias Frestyl.Search
  alias Frestyl.Channels

  def index(conn, params) do
    query = params["q"] || ""
    channel_id = params["channel_id"]
    room_id = params["room_id"]
    type = params["type"]

    user = conn.assigns[:current_user]

    # Get channel and room if IDs are provided for context
    channel = if channel_id, do: Channels.get_channel!(channel_id), else: nil
    room = if room_id, do: Channels.get_room!(room_id), else: nil

    # Perform search
    results = Search.search(%{
      query: query,
      user: user,
      channel_id: channel_id,
      room_id: room_id,
      type: type
    })

    render(conn, :index,
      query: query,
      channel: channel,
      room: room,
      type: type,
      results: results
    )
  end
end
