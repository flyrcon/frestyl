defmodule FrestylWeb.PageController do
  use FrestylWeb, :controller

  # In lib/frestyl_web/controllers/page_controller.ex
  def home(conn, _params) do
    render(conn, :home, layout: {FrestylWeb.Layouts, :app})  # Explicitly use app layout
  end

  def dashboard(conn, _params) do
    # Make sure you have access to the current_user
    user = conn.assigns.current_user

    # Pass user data explicitly to the template
    render(conn, "dashboard.html", user_id: user.id)
  end
end
