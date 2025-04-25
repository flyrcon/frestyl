# lib/frestyl_web/controllers/room_controller.ex

defmodule FrestylWeb.RoomController do
  use FrestylWeb, :controller
  alias Frestyl.Streaming
  alias Frestyl.Streaming.Room

  action_fallback FrestylWeb.FallbackController

  def index(conn, _params) do
    rooms = Streaming.list_active_rooms()
    render(conn, :index, rooms: rooms)
  end

  def create(conn, %{"room" => room_params}) do
    user_id = get_session(conn, :user_id)

    room_params = Map.put(room_params, "creator_id", user_id)

    with {:ok, %Room{} = room} <- Streaming.create_room(room_params) do
      conn
      |> put_status(:created)
      |> render(:show, room: room)
    end
  end

  def show(conn, %{"id" => id}) do
    room = Streaming.get_room(id)
    render(conn, :show, room: room)
  end

  def join(conn, %{"id" => room_id, "password" => password}) do
    user_id = get_session(conn, :user_id)

    with {:ok, room} <- Streaming.join_room(room_id, user_id, password) do
      conn
      |> put_status(:ok)
      |> render(:show, room: room)
    end
  end

  def leave(conn, %{"id" => room_id}) do
    user_id = get_session(conn, :user_id)

    with :ok <- Streaming.leave_room(room_id, user_id) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Left room successfully"})
    end
  end
end
