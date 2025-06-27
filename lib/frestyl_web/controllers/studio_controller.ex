# lib/frestyl_web/controllers/studio_controller.ex
defmodule FrestylWeb.StudioController do
  use FrestylWeb, :controller

  def index(conn, _params) do
    # Redirect to studio live view or render studio page
    redirect(conn, to: "/studio")
  end
end
