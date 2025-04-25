# lib/frestyl_web/controllers/stream_controller.ex

defmodule FrestylWeb.StreamController do
  use FrestylWeb, :controller
  alias Frestyl.Streaming
  alias Frestyl.Streaming.Stream

  action_fallback FrestylWeb.FallbackController

  def create(conn, %{"stream" => stream_params}) do
    user_id = get_session(conn, :user_id)

    stream_params = Map.put(stream_params, "user_id", user_id)

    with {:ok, %Stream{} = stream} <- Streaming.start_stream(stream_params) do
      conn
      |> put_status(:created)
      |> render(:show, stream: stream)
    end
  end

  def show(conn, %{"id" => id}) do
    stream = Streaming.get_stream(id)
    render(conn, :show, stream: stream)
  end

  def end_stream(conn, %{"id" => id}) do
    with {:ok, %Stream{} = stream} <- Streaming.end_stream(id) do
      conn
      |> put_status(:ok)
      |> render(:show, stream: stream)
    end
  end
end
