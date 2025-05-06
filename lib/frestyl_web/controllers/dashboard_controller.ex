defmodule FrestylWeb.DashboardController do
  use FrestylWeb, :controller
  require Logger

  def index(conn, _params) do
    user = conn.assigns.current_user
    Logger.info("Rendering dashboard for user #{user.email}")

    # Instead of raw HTML, render using the template system
    render(conn, :index, user: user)
  end
end
