# lib/frestyl_web/controllers/podcast_controller.ex
defmodule FrestylWeb.PodcastController do
  use FrestylWeb, :controller

  alias Frestyl.Podcasts

  def guest_access(conn, %{"token" => token}) do
    case Phoenix.Token.verify(FrestylWeb.Endpoint, "guest_access", token, max_age: 86400) do
      {:ok, guest_id} ->
        guest = Podcasts.get_guest!(guest_id)
        episode = Podcasts.get_episode!(guest.episode_id)

        conn
        |> assign(:guest, guest)
        |> assign(:episode, episode)
        |> render("guest_access.html")

      {:error, _} ->
        conn
        |> put_flash(:error, "Invalid or expired guest link")
        |> redirect(to: "/")
    end
  end
end
