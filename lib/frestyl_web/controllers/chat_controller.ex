# lib/frestyl_web/controllers/chat_controller.ex

defmodule FrestylWeb.ChatController do
  use FrestylWeb, :controller
  alias Frestyl.Chat

  def conversations(conn, params) do
    user_id = conn.assigns.current_user.id
    context = Map.get(params, "context", :general)

    conversations = Chat.get_contextual_conversations(user_id, context)

    json(conn, %{conversations: conversations})
  end

  def messages(conn, %{"conversation_id" => conversation_id} = params) do
    limit = Map.get(params, "limit", 50)
    offset = Map.get(params, "offset", 0)

    messages = Chat.get_conversation_messages(conversation_id,
      limit: limit, offset: offset)

    json(conn, %{messages: messages})
  end

  def send_message(conn, %{"conversation_id" => conversation_id, "content" => content}) do
    user_id = conn.assigns.current_user.id

    case Chat.send_message(conversation_id, user_id, content) do
      {:ok, message} ->
        json(conn, %{message: message})
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: changeset})
    end
  end

  def mark_read(conn, %{"id" => conversation_id}) do
    user_id = conn.assigns.current_user.id

    Chat.mark_conversation_read(conversation_id, user_id)

    json(conn, %{status: "ok"})
  end
end
