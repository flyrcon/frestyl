# lib/frestyl_web/channels/user_socket.ex
defmodule FrestylWeb.UserSocket do
  use Phoenix.Socket

  ## Channels
  channel "room:*", FrestylWeb.RoomChannel

  ## Transports
  transport :websocket, Phoenix.Transports.WebSocket, timeout: 45_000

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    case Phoenix.Token.verify(FrestylWeb.Endpoint, "user socket", token, max_age: 86400) do
      {:ok, user_id} ->
        {:ok, assign(socket, :user_id, user_id)}
      {:error, _reason} ->
        :error
    end
  end

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.user_id}"
end
