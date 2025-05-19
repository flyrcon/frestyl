# Create lib/frestyl_web/controllers/broadcast_controller.ex
defmodule FrestylWeb.BroadcastController do
  use FrestylWeb, :controller
  alias Phoenix.LiveView

  def show(conn, %{"id" => id}) do
    LiveView.Controller.live_render(conn, FrestylWeb.BroadcastLive.Show,
      session: %{"broadcast_id" => id}
    )
  end
end
