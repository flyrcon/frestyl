# lib/frestyl_web/channels/lab_channel.ex

defmodule FrestylWeb.LabChannel do
  @moduledoc """
  Creator Lab chat channel for experiment feedback, feature requests, and AI interactions
  """

  use Phoenix.Channel
  alias Frestyl.{Chat, Lab, Accounts, Features}
  alias FrestylWeb.Presence

  def join("lab", _params, socket) do
    user_id = socket.assigns.user_id
    user = Accounts.get_user!(user_id)

    # Check if user has lab access
    case Features.FeatureGate.can_access_feature?(user.account, :creator_lab) do
      true ->
        send(self(), :after_join)
        {:ok, socket}
      false ->
        {:error, %{reason: "Creator Lab access required"}}
    end
  end

  def handle_info(:after_join, socket) do
    user = Accounts.get_user!(socket.assigns.user_id)

    # Track presence in lab
    {:ok, _} = Presence.track(socket, socket.assigns.user_id, %{
      online_at: inspect(System.system_time(:second)),
      user_id: user.id,
      username: user.username,
      avatar_url: user.avatar_url,
      activity: "creator_lab",
      current_experiment: nil
    })

    push(socket, "presence_state", Presence.list(socket))

    # Get lab conversations
    conversations = Chat.get_contextual_conversations(user.id, :lab)
    push(socket, "lab_conversations", %{conversations: conversations})

    # Get active experiments
    experiments = Lab.get_user_active_experiments(user.id)
    push(socket, "active_experiments", %{experiments: experiments})

    {:noreply, socket}
  end

  def handle_in("experiment_feedback", %{"experiment_id" => experiment_id, "feedback" => feedback}, socket) do
    user = Accounts.get_user!(socket.assigns.user_id)

    case Lab.submit_experiment_feedback(experiment_id, user.id, feedback) do
      {:ok, feedback_record} ->
        # Create or find experiment feedback conversation
        case Chat.find_or_create_conversation(
          [user.id],
          :lab,
          experiment_id,
          %{title: "Experiment Feedback", metadata: %{experiment_id: experiment_id}}
        ) do
          {:ok, conversation} ->
            Chat.send_message(conversation.id, user.id, feedback, type: "experiment_feedback")

            broadcast!(socket, "new_experiment_feedback", %{
              experiment_id: experiment_id,
              feedback: feedback_record,
              user: user
            })

            {:reply, :ok, socket}

          {:error, _} ->
            {:reply, {:error, %{reason: "Failed to create feedback conversation"}}, socket}
        end

      {:error, _} ->
        {:reply, {:error, %{reason: "Failed to submit feedback"}}, socket}
    end
  end

  def handle_in("feature_request", %{"title" => title, "description" => description, "priority" => priority}, socket) do
    user = Accounts.get_user!(socket.assigns.user_id)

    case Lab.create_feature_request(user.id, %{
      title: title,
      description: description,
      priority: priority
    }) do
      {:ok, feature_request} ->
        # Create feature request conversation for community discussion
        case Chat.find_or_create_conversation(
          [user.id],
          :lab,
          feature_request.id,
          %{title: "Feature Request: #{title}", metadata: %{type: "feature_request"}}
        ) do
          {:ok, conversation} ->
            Chat.send_message(conversation.id, user.id, description, type: "feature_request")

            broadcast!(socket, "new_feature_request", %{
              feature_request: feature_request,
              conversation_id: conversation.id,
              user: user
            })

            {:reply, {:ok, %{feature_request: feature_request}}, socket}

          {:error, _} ->
            {:reply, {:error, %{reason: "Failed to create discussion"}}, socket}
        end

      {:error, changeset} ->
        {:reply, {:error, %{errors: format_changeset_errors(changeset)}}, socket}
    end
  end

  def handle_in("ai_chat_message", %{"message" => message, "context" => context}, socket) do
    user = Accounts.get_user!(socket.assigns.user_id)

    # Create or find AI chat conversation
    case Chat.find_or_create_conversation(
      [user.id],
      :lab,
      nil,
      %{title: "AI Assistant", metadata: %{type: "ai_chat", context: context}}
    ) do
      {:ok, conversation} ->
        # Save user message
        case Chat.send_message(conversation.id, user.id, message, type: "ai_query") do
          {:ok, user_message} ->
            # Process with AI assistant
            case Lab.process_ai_query(user.id, message, context) do
              {:ok, ai_response} ->
                # Save AI response (using system user ID or special AI user)
                ai_user_id = get_ai_user_id()
                Chat.send_message(conversation.id, ai_user_id, ai_response.content, type: "ai_response")

                push(socket, "ai_response", %{
                  conversation_id: conversation.id,
                  response: ai_response,
                  user_message_id: user_message.id
                })

                {:reply, :ok, socket}

              {:error, reason} ->
                {:reply, {:error, %{reason: reason}}, socket}
            end

          {:error, _} ->
            {:reply, {:error, %{reason: "Failed to save message"}}, socket}
        end

      {:error, _} ->
        {:reply, {:error, %{reason: "Failed to create AI conversation"}}, socket}
    end
  end

  def handle_in("join_beta_program", %{"feature_name" => feature_name}, socket) do
    user = Accounts.get_user!(socket.assigns.user_id)

    case Lab.join_beta_program(user.id, feature_name) do
      {:ok, beta_participation} ->
        broadcast!(socket, "beta_program_joined", %{
          feature_name: feature_name,
          user: user,
          participation: beta_participation
        })

        {:reply, :ok, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  def handle_in("lab_chat_message", %{"conversation_id" => conversation_id, "content" => content}, socket) do
    user = Accounts.get_user!(socket.assigns.user_id)

    case Chat.send_message(conversation_id, user.id, content, type: "lab") do
      {:ok, message} ->
        broadcast!(socket, "new_lab_message", format_lab_message(message, user))
        {:reply, :ok, socket}

      {:error, _} ->
        {:reply, {:error, %{reason: "Failed to send message"}}, socket}
    end
  end

  defp get_ai_user_id do
    # Return a special AI assistant user ID, or create one if needed
    # This could be a system user specifically for AI responses
    case Accounts.get_ai_assistant_user() do
      nil ->
        {:ok, ai_user} = Accounts.create_ai_assistant_user()
        ai_user.id
      ai_user ->
        ai_user.id
    end
  end

  defp format_lab_message(message, user) do
    %{
      id: message.id,
      content: message.content,
      message_type: message.message_type,
      user_id: user.id,
      username: user.username,
      avatar_url: user.avatar_url,
      inserted_at: message.inserted_at,
      lab_context: true
    }
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  defp get_ai_user_id do
    # Option 1: Return a fixed AI user ID if you have one
    case Frestyl.Repo.get_by(Frestyl.Accounts.User, username: "AI_Assistant") do
      nil ->
        # Option 2: Create an AI user if it doesn't exist
        create_ai_user()
      user ->
        user.id
    end
  end

  defp create_ai_user do
    case Frestyl.Accounts.create_user(%{
      username: "AI_Assistant",
      email: "ai@frestyl.com",
      name: "AI Assistant"
    }) do
      {:ok, user} -> user.id
      {:error, _} ->
        # Fallback to a system user ID or return 1
        1
    end
  end

end
