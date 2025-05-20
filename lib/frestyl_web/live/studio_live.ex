# lib/frestyl_web/live/studio_live.ex
defmodule FrestylWeb.StudioLive do
  use FrestylWeb, :live_view

  alias Frestyl.Accounts
  alias Frestyl.Channels
  alias Frestyl.Media
  alias Frestyl.Sessions
  alias Frestyl.Presence
  alias FrestylWeb.AccessibilityComponents, as: A11y
  alias Phoenix.PubSub

  @default_workspace_state %{
    audio: %{
      tracks: [],
      selected_track: nil,
      recording: false,
      playing: false,
      current_time: 0,
      zoom_level: 1.0
    },
    midi: %{
      notes: [],
      selected_notes: [],
      current_instrument: "piano",
      octave: 4,
      grid_size: 16
    },
    text: %{
      content: "",
      cursors: %{},
      selection: nil
    },
    visual: %{
      elements: [],
      selected_element: nil,
      tool: "brush",
      brush_size: 5,
      color: "#4f46e5"
    }
  }

  def mount(%{"channel_slug" => channel_slug, "session_id" => session_id} = params, session, socket) do
    current_user = session["user_token"] && Accounts.get_user_by_session_token(session["user_token"])

    if current_user do
      # Use get_channel_by_slug instead of get_channel!
      channel = Channels.get_channel_by_slug(channel_slug)

      if channel do
        # Try to get the session (using get_session instead of get_session!)
        session_data = Sessions.get_session(session_id)

        if session_data do
          # Rest of the function
          if connected?(socket) do
            # Subscribe to necessary topics for real-time updates
            PubSub.subscribe(Frestyl.PubSub, "studio:#{session_id}")
            PubSub.subscribe(Frestyl.PubSub, "user:#{current_user.id}")

            # Join the channel for real-time presence updates
            {:ok, _} = Presence.track(self(), "studio:#{session_id}", current_user.id, %{
              user_id: current_user.id,
              username: current_user.username,
              avatar_url: current_user.avatar_url,
              joined_at: DateTime.utc_now(),
              active_tool: "audio",
              is_typing: false,
              last_activity: DateTime.utc_now()
            })
          end

          role = determine_user_role(session_data, current_user)
          permissions = get_permissions_for_role(role, session_data.session_type)

          # Get or initialize workspace state
          workspace_state = get_workspace_state(session_id) || @default_workspace_state

          # Load collaborators via Presence
          collaborators = list_collaborators(session_id)

          # Load chat messages
          chat_messages = Sessions.list_session_messages(session_id)

          active_tool = case session_data.session_type do
            "audio" -> "audio"
            "text" -> "text"
            "visual" -> "visual"
            "midi" -> "midi"
            _ -> "audio" # Default
          end

          socket = socket
            |> assign(:current_user, current_user)
            |> assign(:channel, channel)
            |> assign(:session, session_data)
            |> assign(:role, role)
            |> assign(:permissions, permissions)
            |> assign(:page_title, session_data.title || "Untitled Session")
            |> assign(:workspace_state, workspace_state)
            |> assign(:active_tool, active_tool)
            |> assign(:collaborators, collaborators)
            |> assign(:chat_messages, chat_messages)
            |> assign(:message_input, "")
            |> assign(:show_invite_modal, false)
            |> assign(:show_settings_modal, false)
            |> assign(:show_export_modal, false)
            |> assign(:media_items, list_media_items(session_id))
            |> assign(:tools, get_available_tools(permissions))
            |> assign(:rtc_token, generate_rtc_token(current_user.id, session_id))
            |> assign(:connection_status, "connecting")
            |> assign(:notifications, [])
            |> assign(:recorded_chunks, [])
            |> assign(:show_end_session_modal, false)

          {:ok, socket}
        else
          {:ok, socket
            |> put_flash(:error, "Session not found")
            |> push_redirect(to: ~p"/channels/#{channel_slug}")}
        end
      else
        {:ok, socket
          |> put_flash(:error, "Channel not found")
          |> push_redirect(to: ~p"/dashboard")}
      end
    else
      # Handle case when user is not authenticated
      {:ok, socket
        |> put_flash(:error, "You must be logged in to access this page")
        |> push_redirect(to: ~p"/users/log_in")}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :show, _params) do
    socket
    |> assign(:page_title, "#{socket.assigns.session.title} | Studio")
  end

  defp apply_action(socket, :edit_session, _params) do
    if can_edit_session?(socket.assigns.permissions) do
      socket
      |> assign(:page_title, "Edit Session | #{socket.assigns.session.title}")
    else
      socket
      |> put_flash(:error, "You don't have permission to edit this session")
      |> push_redirect(to: Routes.channel_path(socket, :show, socket.assigns.channel))
    end
  end

  @impl true
  def handle_event("set_active_tool", %{"tool" => tool}, socket) do
    # Update user presence with active tool
    update_presence(socket.assigns.session.id, socket.assigns.current_user.id, %{active_tool: tool})

    {:noreply, assign(socket, active_tool: tool)}
  end

  @impl true
  def handle_event("toggle_invite_modal", _, socket) do
    {:noreply, assign(socket, show_invite_modal: !socket.assigns.show_invite_modal)}
  end

  @impl true
  def handle_event("toggle_settings_modal", _, socket) do
    {:noreply, assign(socket, show_settings_modal: !socket.assigns.show_settings_modal)}
  end

  @impl true
  def handle_event("toggle_export_modal", _, socket) do
    {:noreply, assign(socket, show_export_modal: !socket.assigns.show_export_modal)}
  end

  @impl true
  def handle_event("send_invite", %{"email" => email, "role" => role}, socket) when email != "" do
    session_id = socket.assigns.session.id

    # Check if user has permission to invite
    if can_invite_users?(socket.assigns.permissions) do
      case Sessions.invite_user_to_session(session_id, email, role, socket.assigns.current_user) do
        {:ok, invitation} ->
          # Broadcast notification about new invitation
          PubSub.broadcast(Frestyl.PubSub, "studio:#{session_id}",
            {:invitation_sent, %{inviter: socket.assigns.current_user.username, invitee_email: email}})

          {:noreply, socket
            |> assign(show_invite_modal: false)
            |> put_flash(:info, "Invitation sent to #{email}")}

        {:error, reason} ->
          {:noreply, socket
            |> put_flash(:error, "Failed to send invitation: #{reason}")}
      end
    else
      {:noreply, socket
        |> put_flash(:error, "You don't have permission to invite users")}
    end
  end

  @impl true
  def handle_event("send_message", %{"message" => message}, socket) when message != "" do
    user = socket.assigns.current_user
    session_id = socket.assigns.session.id

    # Create the new message through the context
    message_params = %{
      content: message,
      user_id: user.id,
      session_id: session_id
    }

    case Sessions.create_message(message_params) do
      {:ok, new_message} ->
        # Broadcast the message to all users in the session
        message_data = %{
          id: new_message.id,
          content: new_message.content,
          user_id: new_message.user_id,
          username: user.username,
          avatar_url: user.avatar_url,
          inserted_at: new_message.inserted_at
        }

        PubSub.broadcast(Frestyl.PubSub, "studio:#{session_id}", {:new_message, message_data})

        # Update the presence to show the user is not typing anymore
        update_presence(session_id, user.id, %{is_typing: false})

        {:noreply, assign(socket, message_input: "")}

      {:error, _changeset} ->
        {:noreply, socket
          |> put_flash(:error, "Could not send message, please try again")}
    end
  end

  @impl true
  def handle_event("update_message_input", %{"value" => value}, socket) do
    user = socket.assigns.current_user
    session_id = socket.assigns.session.id

    # Update presence to show user is typing if the input is not empty
    is_typing = value != ""
    update_presence(session_id, user.id, %{is_typing: is_typing, last_activity: DateTime.utc_now()})

    {:noreply, assign(socket, message_input: value)}
  end

  @impl true
  def handle_event("update_session_title", %{"value" => value}, socket) do
    if can_edit_session?(socket.assigns.permissions) do
      session = socket.assigns.session

      case Sessions.update_session(session, %{title: value}) do
        {:ok, updated_session} ->
          # Broadcast the title change to all participants
          PubSub.broadcast(Frestyl.PubSub, "studio:#{session.id}",
            {:session_updated, %{title: updated_session.title}})

          {:noreply, socket |> assign(session: updated_session)}

        {:error, _changeset} ->
          {:noreply, socket
            |> put_flash(:error, "Failed to update session title")}
      end
    else
      {:noreply, socket}
    end
  end

  # Audio workspace events

  @impl true
  def handle_event("audio_toggle_play", _, socket) do
    # Toggle the play state
    audio_state = socket.assigns.workspace_state.audio
    playing = !audio_state.playing

    # Update the workspace state
    new_audio_state = Map.put(audio_state, :playing, playing)
    new_workspace_state = Map.put(socket.assigns.workspace_state, :audio, new_audio_state)

    # Broadcast the change to all participants
    PubSub.broadcast(
      Frestyl.PubSub,
      "studio:#{socket.assigns.session.id}",
      {:workspace_updated, %{type: :audio, action: :toggle_play, playing: playing}}
    )

    # Save the workspace state
    save_workspace_state(socket.assigns.session.id, new_workspace_state)

    {:noreply, assign(socket, workspace_state: new_workspace_state)}
  end

  @impl true
  def handle_event("audio_toggle_record", _, socket) do
    if can_record_audio?(socket.assigns.permissions) do
      audio_state = socket.assigns.workspace_state.audio
      recording = !audio_state.recording

      # Update the workspace state
      new_audio_state = Map.put(audio_state, :recording, recording)
      new_workspace_state = Map.put(socket.assigns.workspace_state, :audio, new_audio_state)

      # Broadcast the change to all participants
      PubSub.broadcast(
        Frestyl.PubSub,
        "studio:#{socket.assigns.session.id}",
        {:workspace_updated, %{type: :audio, action: :toggle_record, recording: recording}}
      )

      save_workspace_state(socket.assigns.session.id, new_workspace_state)

      {:noreply, assign(socket, workspace_state: new_workspace_state)}
    else
      {:noreply, socket |> put_flash(:error, "You don't have permission to record audio")}
    end
  end

  @impl true
  def handle_event("audio_add_track", _, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      audio_state = socket.assigns.workspace_state.audio

      # Create a new track
      new_track = %{
        id: "track-#{System.unique_integer([:positive])}",
        name: "Track #{length(audio_state.tracks) + 1}",
        clips: [],
        muted: false,
        solo: false,
        volume: 0.8,
        pan: 0.0
      }

      new_tracks = audio_state.tracks ++ [new_track]
      new_audio_state = Map.put(audio_state, :tracks, new_tracks)
      new_workspace_state = Map.put(socket.assigns.workspace_state, :audio, new_audio_state)

      # Broadcast the change to all participants
      PubSub.broadcast(
        Frestyl.PubSub,
        "studio:#{socket.assigns.session.id}",
        {:workspace_updated, %{type: :audio, action: :add_track, track: new_track}}
      )

      save_workspace_state(socket.assigns.session.id, new_workspace_state)

      {:noreply, assign(socket, workspace_state: new_workspace_state)}
    else
      {:noreply, socket |> put_flash(:error, "You don't have permission to add tracks")}
    end
  end

  @impl true
  def handle_event("audio_save_recording", %{"data" => encoded_data}, socket) do
    if can_edit_audio?(socket.assigns.permissions) do
      # Process the audio data
      case Media.create_audio_clip(
        encoded_data,
        socket.assigns.session.id,
        socket.assigns.current_user.id
      ) do
        {:ok, audio_clip} ->
          # Add the new clip to the selected track
          audio_state = socket.assigns.workspace_state.audio

          if audio_state.selected_track do
            # Find the selected track
            updated_tracks = Enum.map(audio_state.tracks, fn track ->
              if track.id == audio_state.selected_track do
                new_clip = %{
                  id: "clip-#{System.unique_integer([:positive])}",
                  audio_clip_id: audio_clip.id,
                  name: "Recording #{DateTime.utc_now() |> Calendar.strftime("%H:%M:%S")}",
                  start_time: audio_state.current_time,
                  url: audio_clip.url
                }

                Map.update!(track, :clips, fn clips -> clips ++ [new_clip] end)
              else
                track
              end
            end)

            new_audio_state = %{audio_state | tracks: updated_tracks, recording: false}
            new_workspace_state = Map.put(socket.assigns.workspace_state, :audio, new_audio_state)

            # Broadcast the change to all participants
            PubSub.broadcast(
              Frestyl.PubSub,
              "studio:#{socket.assigns.session.id}",
              {:workspace_updated, %{
                type: :audio,
                action: :add_clip,
                track_id: audio_state.selected_track,
                clip: List.last(hd(Enum.filter(updated_tracks, & &1.id == audio_state.selected_track)).clips)
              }}
            )

            save_workspace_state(socket.assigns.session.id, new_workspace_state)

            {:noreply, socket
              |> assign(workspace_state: new_workspace_state)
              |> put_flash(:info, "Recording saved successfully")}
          else
            {:noreply, socket |> put_flash(:error, "No track selected for recording")}
          end

        {:error, reason} ->
          {:noreply, socket |> put_flash(:error, "Failed to save recording: #{reason}")}
      end
    else
      {:noreply, socket |> put_flash(:error, "You don't have permission to save recordings")}
    end
  end

  # MIDI workspace events

  @impl true
  def handle_event("midi_add_note", %{"note" => note_params}, socket) do
    if can_edit_midi?(socket.assigns.permissions) do
      midi_state = socket.assigns.workspace_state.midi

      # Create a new note
      new_note = %{
        id: "note-#{System.unique_integer([:positive])}",
        pitch: note_params["pitch"],
        start: note_params["start"],
        duration: note_params["duration"],
        velocity: note_params["velocity"] || 100
      }

      new_notes = midi_state.notes ++ [new_note]
      new_midi_state = Map.put(midi_state, :notes, new_notes)
      new_workspace_state = Map.put(socket.assigns.workspace_state, :midi, new_midi_state)

      # Broadcast the change to all participants
      PubSub.broadcast(
        Frestyl.PubSub,
        "studio:#{socket.assigns.session.id}",
        {:workspace_updated, %{type: :midi, action: :add_note, note: new_note}}
      )

      save_workspace_state(socket.assigns.session.id, new_workspace_state)

      {:noreply, assign(socket, workspace_state: new_workspace_state)}
    else
      {:noreply, socket |> put_flash(:error, "You don't have permission to edit MIDI")}
    end
  end

  # Text workspace events

  @impl true
  def handle_event("text_update", %{"content" => content, "selection" => selection}, socket) do
    if can_edit_text?(socket.assigns.permissions) do
      text_state = socket.assigns.workspace_state.text
      user_id = socket.assigns.current_user.id

      # Update cursors with the user's current selection
      new_cursors = Map.put(text_state.cursors, user_id, selection)

      # Update the text content and cursors
      new_text_state = %{text_state | content: content, cursors: new_cursors}
      new_workspace_state = Map.put(socket.assigns.workspace_state, :text, new_text_state)

      # Broadcast the change to all participants
      PubSub.broadcast(
        Frestyl.PubSub,
        "studio:#{socket.assigns.session.id}",
        {:workspace_updated, %{
          type: :text,
          action: :update,
          content: content,
          cursor: %{user_id: user_id, selection: selection}
        }}
      )

      save_workspace_state(socket.assigns.session.id, new_workspace_state)

      {:noreply, assign(socket, workspace_state: new_workspace_state)}
    else
      {:noreply, socket}
    end
  end

  # Visual workspace events

  @impl true
  def handle_event("visual_add_element", %{"element" => element_params}, socket) do
    if can_edit_visual?(socket.assigns.permissions) do
      visual_state = socket.assigns.workspace_state.visual

      # Create a new visual element
      new_element = %{
        id: "element-#{System.unique_integer([:positive])}",
        type: element_params["type"],
        x: element_params["x"],
        y: element_params["y"],
        width: element_params["width"],
        height: element_params["height"],
        color: element_params["color"] || visual_state.color,
        created_by: socket.assigns.current_user.id
      }

      new_elements = visual_state.elements ++ [new_element]
      new_visual_state = Map.put(visual_state, :elements, new_elements)
      new_workspace_state = Map.put(socket.assigns.workspace_state, :visual, new_visual_state)

      # Broadcast the change to all participants
      PubSub.broadcast(
        Frestyl.PubSub,
        "studio:#{socket.assigns.session.id}",
        {:workspace_updated, %{type: :visual, action: :add_element, element: new_element}}
      )

      save_workspace_state(socket.assigns.session.id, new_workspace_state)

      {:noreply, assign(socket, workspace_state: new_workspace_state)}
    else
      {:noreply, socket |> put_flash(:error, "You don't have permission to edit visual content")}
    end
  end

  @impl true
  def handle_event("visual_update_tool", %{"tool" => tool}, socket) do
    visual_state = socket.assigns.workspace_state.visual
    new_visual_state = Map.put(visual_state, :tool, tool)
    new_workspace_state = Map.put(socket.assigns.workspace_state, :visual, new_visual_state)

    {:noreply, assign(socket, workspace_state: new_workspace_state)}
  end

  @impl true
  def handle_event("visual_update_color", %{"color" => color}, socket) do
    visual_state = socket.assigns.workspace_state.visual
    new_visual_state = Map.put(visual_state, :color, color)
    new_workspace_state = Map.put(socket.assigns.workspace_state, :visual, new_visual_state)

    {:noreply, assign(socket, workspace_state: new_workspace_state)}
  end

  @impl true
  def handle_event("end_session", _, socket) do
    # We'll handle this in the UI with a confirmation dialog using JavaScript
    # and then call the actual end_session_confirmed event
    {:noreply, socket}
  end

  @impl true
  def handle_event("end_session_confirmed", _, socket) do
    session_data = socket.assigns.session

    # First save the current workspace state to media based on session type
    save_result = case session_data.session_type do
      "audio" ->
        # Save audio content to the channel's media
        save_audio_to_channel_media(socket.assigns.workspace_state.audio, socket.assigns.channel.id, socket.assigns.current_user.id, session_data.title)

      "text" ->
        # Save text content to the channel's media
        save_text_to_channel_media(socket.assigns.workspace_state.text, socket.assigns.channel.id, socket.assigns.current_user.id, session_data.title)

      "visual" ->
        # Save visual content to the channel's media
        save_visual_to_channel_media(socket.assigns.workspace_state.visual, socket.assigns.channel.id, socket.assigns.current_user.id, session_data.title)

      "midi" ->
        # Save MIDI content to the channel's media
        save_midi_to_channel_media(socket.assigns.workspace_state.midi, socket.assigns.channel.id, socket.assigns.current_user.id, session_data.title)

      _ -> {:ok, nil}  # Default case, nothing to save
    end

    # Then end the session
    case Sessions.end_session(session_data.id, socket.assigns.current_user.id) do
      {:ok, _updated_session} ->
        # Add a success message based on whether media was saved
        message = case save_result do
          {:ok, _} -> "Session ended and work saved to channel media."
          _ -> "Session ended successfully."
        end

        {:noreply, socket
          |> put_flash(:info, message)
          |> push_redirect(to: ~p"/channels/#{socket.assigns.channel.slug}")}

      {:error, reason} ->
        {:noreply, socket |> put_flash(:error, "Could not end session: #{reason}")}
    end
  end

  # Helper functions to save different content types to channel media
  defp save_audio_to_channel_media(audio_state, channel_id, user_id, title) do
    # Implementation to save audio tracks to channel media
    if length(audio_state.tracks) > 0 do
      # For now, we'll just create a placeholder media entry
      # In a real implementation, you would export the audio data
      Media.create_channel_media(%{
        channel_id: channel_id,
        user_id: user_id,
        title: "#{title} - Audio Recording",
        media_type: "audio",
        description: "Audio saved from session: #{title}",
        content_type: "audio/mp3",
        size: 0  # This would be the actual file size
      })
    else
      {:ok, nil}  # No tracks to save
    end
  end

  defp save_text_to_channel_media(text_state, channel_id, user_id, title) do
    # Only save if there's content
    if text_state.content && String.trim(text_state.content) != "" do
      # Create a text file media entry
      Media.create_channel_media(%{
        channel_id: channel_id,
        user_id: user_id,
        title: "#{title} - Text",
        media_type: "document",
        description: "Text saved from session: #{title}",
        content_type: "text/plain",
        content: text_state.content,
        size: byte_size(text_state.content)
      })
    else
      {:ok, nil}  # No content to save
    end
  end

  defp save_visual_to_channel_media(visual_state, channel_id, user_id, title) do
    # Only save if there are elements
    if length(visual_state.elements) > 0 do
      # Serialize the visual elements to JSON
      json_content = Jason.encode!(visual_state)

      # Create a visual file media entry
      Media.create_channel_media(%{
        channel_id: channel_id,
        user_id: user_id,
        title: "#{title} - Visual",
        media_type: "image",
        description: "Visual saved from session: #{title}",
        content_type: "application/json",
        content: json_content,
        size: byte_size(json_content)
      })
    else
      {:ok, nil}  # No elements to save
    end
  end

  defp save_midi_to_channel_media(midi_state, channel_id, user_id, title) do
    # Only save if there are notes
    if length(midi_state.notes) > 0 do
      # Serialize the MIDI data to JSON
      json_content = Jason.encode!(midi_state)

      # Create a MIDI file media entry
      Media.create_channel_media(%{
        channel_id: channel_id,
        user_id: user_id,
        title: "#{title} - MIDI",
        media_type: "audio",
        description: "MIDI saved from session: #{title}",
        content_type: "application/json",
        content: json_content,
        size: byte_size(json_content)
      })
    else
      {:ok, nil}  # No notes to save
    end
  end


  # Handle real-time collaboration events from PubSub

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff", payload: diff}, socket) do
    collaborators = list_collaborators(socket.assigns.session.id)

    # Generate notification for users who joined
    notifications = Enum.reduce(Map.get(diff, :joins, %{}), socket.assigns.notifications, fn {user_id, user_data}, acc ->
      if user_id != to_string(socket.assigns.current_user.id) do
        meta_data = List.first(user_data.metas)
        [%{
          id: System.unique_integer([:positive]),
          type: :user_joined,
          message: "#{meta_data.username} joined the session",
          timestamp: DateTime.utc_now()
        } | acc]
      else
        acc
      end
    end)

    # Generate notification for users who left
    notifications = Enum.reduce(Map.get(diff, :leaves, %{}), notifications, fn {user_id, user_data}, acc ->
      if user_id != to_string(socket.assigns.current_user.id) do
        meta_data = List.first(user_data.metas)
        [%{
          id: System.unique_integer([:positive]),
          type: :user_left,
          message: "#{meta_data.username} left the session",
          timestamp: DateTime.utc_now()
        } | acc]
      else
        acc
      end
    end)

    {:noreply, socket
      |> assign(collaborators: collaborators)
      |> assign(notifications: notifications)}
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    # Add the new message to the list
    updated_messages = socket.assigns.chat_messages ++ [message]

    # Add a notification if the message is from someone else
    notifications = if message.user_id != socket.assigns.current_user.id do
      [%{
        id: System.unique_integer([:positive]),
        type: :new_message,
        message: "New message from #{message.username}",
        timestamp: DateTime.utc_now()
      } | socket.assigns.notifications]
    else
      socket.assigns.notifications
    end

    {:noreply, socket
      |> assign(chat_messages: updated_messages)
      |> assign(notifications: notifications)}
  end

  @impl true
  def handle_info({:workspace_updated, update}, socket) do
    # Handle different types of workspace updates
    new_workspace_state = case update.type do
      :audio -> handle_audio_update(socket.assigns.workspace_state, update)
      :midi -> handle_midi_update(socket.assigns.workspace_state, update)
      :text -> handle_text_update(socket.assigns.workspace_state, update)
      :visual -> handle_visual_update(socket.assigns.workspace_state, update)
      _ -> socket.assigns.workspace_state
    end

    # Add a notification about the update
    message = get_update_notification_message(update, socket.assigns.collaborators)
    notifications = if message do
      [%{
        id: System.unique_integer([:positive]),
        type: :workspace_updated,
        message: message,
        timestamp: DateTime.utc_now()
      } | socket.assigns.notifications]
    else
      socket.assigns.notifications
    end

    {:noreply, socket
      |> assign(workspace_state: new_workspace_state)
      |> assign(notifications: notifications)}
  end

  @impl true
  def handle_info({:session_updated, updates}, socket) do
    # Update the session with the new data
    updated_session = Map.merge(socket.assigns.session, updates)

    {:noreply, socket |> assign(session: updated_session)}
  end

  @impl true
  def handle_info({:invitation_sent, invitation}, socket) do
    # Add a notification about the invitation
    notifications = [%{
      id: System.unique_integer([:positive]),
      type: :invitation_sent,
      message: "#{invitation.inviter} invited #{invitation.invitee_email} to the session",
      timestamp: DateTime.utc_now()
    } | socket.assigns.notifications]

    {:noreply, socket |> assign(notifications: notifications)}
  end

  @impl true
  def handle_info({:rtc_connection_status, status}, socket) do
    {:noreply, socket |> assign(connection_status: status)}
  end

  # Helper functions for updates

  defp handle_audio_update(workspace_state, update) do
    # First normalize the workspace state to ensure we have a consistent structure
    workspace_state = normalize_workspace_state(workspace_state)

    # Extract the action (handle both atom and string keys)
    action = cond do
      is_atom(update[:action]) -> update[:action]
      is_binary(update["action"]) -> String.to_existing_atom(update["action"])
      true -> nil
    end

    # Handle the action
    audio_state = workspace_state.audio

    new_audio_state = case action do
      :toggle_play ->
        # Get playing value (handle both atom and string keys)
        playing = update[:playing] || update["playing"] || false
        Map.put(audio_state, :playing, playing)

      :toggle_record ->
        # Get recording value (handle both atom and string keys)
        recording = update[:recording] || update["recording"] || false
        Map.put(audio_state, :recording, recording)

      :add_track ->
        # Get track data (handle both atom and string keys)
        track = normalize_track(update[:track] || update["track"] || %{})
        # Update tracks
        Map.update!(audio_state, :tracks, fn tracks -> tracks ++ [track] end)

      :add_clip ->
        # Get track_id and clip data (handle both atom and string keys)
        track_id = update[:track_id] || update["track_id"]
        clip = normalize_clip(update[:clip] || update["clip"] || %{})

        # Update the tracks with the new clip
        new_tracks = Enum.map(audio_state.tracks, fn track ->
          if track.id == track_id do
            Map.update!(track, :clips, fn clips -> clips ++ [clip] end)
          else
            track
          end
        end)
        Map.put(audio_state, :tracks, new_tracks)

      _ -> audio_state
    end

    # Update the workspace state
    Map.put(workspace_state, :audio, new_audio_state)
  end

  # Helper to normalize a single track when received from an update
  defp normalize_track(track) when is_map(track) do
    %{
      id: track[:id] || track["id"] || "track-#{System.unique_integer([:positive])}",
      name: track[:name] || track["name"] || "Untitled Track",
      clips: normalize_clips(track[:clips] || track["clips"] || []),
      muted: track[:muted] || track["muted"] || false,
      solo: track[:solo] || track["solo"] || false,
      volume: track[:volume] || track["volume"] || 0.8,
      pan: track[:pan] || track["pan"] || 0.0
    }
  end
  defp normalize_track(_), do: %{
    id: "track-#{System.unique_integer([:positive])}",
    name: "Untitled Track",
    clips: [],
    muted: false,
    solo: false,
    volume: 0.8,
    pan: 0.0
  }

  # Helper to normalize a single clip when received from an update
  defp normalize_clip(clip) when is_map(clip) do
    %{
      id: clip[:id] || clip["id"] || "clip-#{System.unique_integer([:positive])}",
      audio_clip_id: clip[:audio_clip_id] || clip["audio_clip_id"],
      name: clip[:name] || clip["name"] || "Unnamed Clip",
      start_time: clip[:start_time] || clip["start_time"] || 0,
      url: clip[:url] || clip["url"]
    }
  end
  defp normalize_clip(_), do: %{
    id: "clip-#{System.unique_integer([:positive])}",
    name: "Unnamed Clip",
    start_time: 0,
    url: nil
  }

  defp handle_midi_update(workspace_state, update) do
    # First normalize the workspace state to ensure we have a consistent structure
    workspace_state = normalize_workspace_state(workspace_state)

    # Extract the action (handle both atom and string keys)
    action = cond do
      is_atom(update[:action]) -> update[:action]
      is_binary(update["action"]) -> String.to_existing_atom(update["action"])
      true -> nil
    end

    # Handle the action
    midi_state = workspace_state.midi

    new_midi_state = case action do
      :add_note ->
        # Get note data (handle both atom and string keys)
        note = normalize_note(update[:note] || update["note"] || %{})
        # Update notes
        Map.update!(midi_state, :notes, fn notes -> notes ++ [note] end)

      :delete_note ->
        # Get note id (handle both atom and string keys)
        note_id = update[:note_id] || update["note_id"]
        # Remove note
        Map.update!(midi_state, :notes, fn notes ->
          Enum.reject(notes, &(&1.id == note_id))
        end)

      :update_note ->
        # Get note data (handle both atom and string keys)
        note_data = update[:note] || update["note"] || %{}
        note_id = note_data[:id] || note_data["id"]

        # Update the note
        if note_id do
          Map.update!(midi_state, :notes, fn notes ->
            Enum.map(notes, fn note ->
              if note.id == note_id do
                normalize_note(Map.merge(note, normalize_note(note_data)))
              else
                note
              end
            end)
          end)
        else
          midi_state
        end

      :change_instrument ->
        # Get instrument (handle both atom and string keys)
        instrument = update[:instrument] || update["instrument"] || "piano"
        Map.put(midi_state, :current_instrument, instrument)

      :change_octave ->
        # Get octave (handle both atom and string keys)
        octave = update[:octave] || update["octave"] || 4
        Map.put(midi_state, :octave, octave)

      _ -> midi_state
    end

    # Update the workspace state
    Map.put(workspace_state, :midi, new_midi_state)
  end

  # Helper to normalize a single note when received from an update
  defp normalize_note(note) when is_map(note) do
    %{
      id: note[:id] || note["id"] || "note-#{System.unique_integer([:positive])}",
      pitch: note[:pitch] || note["pitch"] || 60,
      start: note[:start] || note["start"] || 0,
      duration: note[:duration] || note["duration"] || 1,
      velocity: note[:velocity] || note["velocity"] || 100
    }
  end
  defp normalize_note(_), do: %{
    id: "note-#{System.unique_integer([:positive])}",
    pitch: 60,
    start: 0,
    duration: 1,
    velocity: 100
  }

  defp handle_text_update(workspace_state, update) do
    text_state = workspace_state.text

    new_text_state = case update.action do
      :update ->
        # Update content and cursor position
        new_cursors = Map.put(text_state.cursors, update.cursor.user_id, update.cursor.selection)
        %{text_state | content: update.content, cursors: new_cursors}

      _ -> text_state
    end

    Map.put(workspace_state, :text, new_text_state)
  end

  defp handle_visual_update(workspace_state, update) do
    visual_state = workspace_state.visual

    new_visual_state = case update.action do
      :add_element ->
        Map.update!(visual_state, :elements, fn elements -> elements ++ [update.element] end)

      _ -> visual_state
    end

    Map.put(workspace_state, :visual, new_visual_state)
  end

  defp get_update_notification_message(update, collaborators) do
    # Find the username of the user who made the update
    user_id = case update do
      %{element: %{created_by: user_id}} -> user_id
      %{cursor: %{user_id: user_id}} -> user_id
      _ -> nil
    end

    username = if user_id do
      collaborator = Enum.find(collaborators, fn c -> c.user_id == user_id end)
      if collaborator, do: collaborator.username, else: "Someone"
    else
      "Someone"
    end

    case update.type do
      :audio ->
        case update.action do
          :add_track -> "#{username} added a new audio track"
          :add_clip -> "#{username} added a new audio clip"
          _ -> nil  # No notification for other audio actions
        end

      :midi ->
        case update.action do
          :add_note -> nil  # Too many notifications for individual notes
          _ -> nil
        end

      :text ->
        nil  # No notifications for text updates to avoid spam

      :visual ->
        case update.action do
          :add_element -> "#{username} added a new visual element"
          _ -> nil
        end
    end
  end

  # Permission and role helper functions

  defp determine_user_role(session, user) do
    cond do
      session.creator_id == user.id -> "owner"
      Sessions.is_session_moderator?(session.id, user.id) -> "moderator"
      Sessions.is_session_participant?(session.id, user.id) -> "participant"
      true -> "viewer"
    end
  end

  defp get_permissions_for_role(role, session_type) do
    # Base permissions based on role
    base_permissions = case role do
      "owner" -> [
        :view, :edit, :delete, :invite, :kick,
        :edit_audio, :record_audio, :edit_midi, :edit_text, :edit_visual
      ]
      "moderator" -> [
        :view, :edit, :invite,
        :edit_audio, :record_audio, :edit_midi, :edit_text, :edit_visual
      ]
      "participant" ->
        [
          :view,
          :edit_audio, :record_audio, :edit_midi, :edit_text, :edit_visual
        ]
      "viewer" -> [:view]
      _ -> []
    end

    # Add session type specific permissions
    type_permissions = case session_type do
      "audio" ->
        if role in ["owner", "moderator", "participant"], do: [:edit_audio, :record_audio], else: []
      "visual" ->
        if role in ["owner", "moderator", "participant"], do: [:edit_visual], else: []
      "text" ->
        if role in ["owner", "moderator", "participant"], do: [:edit_text], else: []
      "midi" ->
        if role in ["owner", "moderator", "participant"], do: [:edit_midi], else: []
      "mixed" -> []  # All permissions defined by role
      _ -> []
    end
    Enum.uniq(base_permissions ++ type_permissions)
  end

  defp can_edit_session?(permissions) do
    :edit in permissions
  end

  defp can_invite_users?(permissions) do
    :invite in permissions
  end

  defp can_edit_audio?(permissions) do
    :edit_audio in permissions
  end

  defp can_record_audio?(permissions) do
    :record_audio in permissions
  end

  defp can_edit_midi?(permissions) do
    :edit_midi in permissions
  end

  defp can_edit_text?(permissions) do
    :edit_text in permissions
  end

  defp can_edit_visual?(permissions) do
    :edit_visual in permissions
  end

  # Presence and collaborator helpers

  defp list_collaborators(session_id) do
    # Get the raw presence list
    presence_list = Presence.list("studio:#{session_id}")

    # Transform it into a format the view expects
    Enum.flat_map(presence_list, fn {user_id, %{metas: metas}} ->
      # Take the first meta entry for each user
      meta = List.first(metas)
      if meta do
        # Add user_id to meta data if not present
        [Map.put_new(meta, :user_id, user_id)]
      else
        []
      end
    end)
  end

  defp update_presence(session_id, user_id, updates) do
    # Check if the user is already tracked
    user_data = Presence.get_by_key("studio:#{session_id}", to_string(user_id))

    # Fix for KeyError key :metas not found
    case user_data do
      nil ->
        # If the user isn't tracked yet, track them with our updates
        default_data = %{
          user_id: user_id,
          username: @current_user.username,
          avatar_url: @current_user.avatar_url,
          joined_at: DateTime.utc_now(),
          active_tool: updates[:active_tool] || "audio",
          is_typing: updates[:is_typing] || false,
          last_activity: DateTime.utc_now()
        }

        Presence.track(self(), "studio:#{session_id}", to_string(user_id), default_data)

      %{metas: [meta | _]} ->
        # Update the existing presence data
        new_meta = Map.merge(meta, updates)
        Presence.update(self(), "studio:#{session_id}", to_string(user_id), new_meta)

      _ ->
        # Handle other unexpected formats
        nil
    end
  end

  # Workspace state persistence

  defp get_workspace_state(session_id) do
    case Sessions.get_workspace_state(session_id) do
      nil -> @default_workspace_state
      workspace_state -> normalize_workspace_state(workspace_state)
    end
  end

  # This function safely converts string keys to atoms for known keys
  defp normalize_workspace_state(workspace_state) when is_map(workspace_state) do
    # Define the expected structure with default values
    %{
      audio: normalize_audio_state(Map.get(workspace_state, "audio") || Map.get(workspace_state, :audio) || %{}),
      midi: normalize_midi_state(Map.get(workspace_state, "midi") || Map.get(workspace_state, :midi) || %{}),
      text: normalize_text_state(Map.get(workspace_state, "text") || Map.get(workspace_state, :text) || %{}),
      visual: normalize_visual_state(Map.get(workspace_state, "visual") || Map.get(workspace_state, :visual) || %{})
    }
  end
  defp normalize_workspace_state(_), do: @default_workspace_state

  # Normalize audio state
  defp normalize_audio_state(audio_state) when is_map(audio_state) do
    %{
      tracks: normalize_tracks(Map.get(audio_state, "tracks") || Map.get(audio_state, :tracks) || []),
      selected_track: Map.get(audio_state, "selected_track") || Map.get(audio_state, :selected_track),
      recording: Map.get(audio_state, "recording") || Map.get(audio_state, :recording) || false,
      playing: Map.get(audio_state, "playing") || Map.get(audio_state, :playing) || false,
      current_time: Map.get(audio_state, "current_time") || Map.get(audio_state, :current_time) || 0,
      zoom_level: Map.get(audio_state, "zoom_level") || Map.get(audio_state, :zoom_level) || 1.0
    }
  end
  defp normalize_audio_state(_), do: @default_workspace_state.audio

  # Normalize tracks
  defp normalize_tracks(tracks) when is_list(tracks) do
    Enum.map(tracks, fn track when is_map(track) ->
      %{
        id: Map.get(track, "id") || Map.get(track, :id) || "track-#{System.unique_integer([:positive])}",
        name: Map.get(track, "name") || Map.get(track, :name) || "Untitled Track",
        clips: normalize_clips(Map.get(track, "clips") || Map.get(track, :clips) || []),
        muted: Map.get(track, "muted") || Map.get(track, :muted) || false,
        solo: Map.get(track, "solo") || Map.get(track, :solo) || false,
        volume: Map.get(track, "volume") || Map.get(track, :volume) || 0.8,
        pan: Map.get(track, "pan") || Map.get(track, :pan) || 0.0
      }
    end)
  end
  defp normalize_tracks(_), do: []

  # Normalize clips
  defp normalize_clips(clips) when is_list(clips) do
    Enum.map(clips, fn clip when is_map(clip) ->
      %{
        id: Map.get(clip, "id") || Map.get(clip, :id) || "clip-#{System.unique_integer([:positive])}",
        audio_clip_id: Map.get(clip, "audio_clip_id") || Map.get(clip, :audio_clip_id),
        name: Map.get(clip, "name") || Map.get(clip, :name) || "Unnamed Clip",
        start_time: Map.get(clip, "start_time") || Map.get(clip, :start_time) || 0,
        url: Map.get(clip, "url") || Map.get(clip, :url)
      }
    end)
  end
  defp normalize_clips(_), do: []

  # Normalize MIDI state
  defp normalize_midi_state(midi_state) when is_map(midi_state) do
    %{
      notes: normalize_notes(Map.get(midi_state, "notes") || Map.get(midi_state, :notes) || []),
      selected_notes: Map.get(midi_state, "selected_notes") || Map.get(midi_state, :selected_notes) || [],
      current_instrument: Map.get(midi_state, "current_instrument") || Map.get(midi_state, :current_instrument) || "piano",
      octave: Map.get(midi_state, "octave") || Map.get(midi_state, :octave) || 4,
      grid_size: Map.get(midi_state, "grid_size") || Map.get(midi_state, :grid_size) || 16
    }
  end
  defp normalize_midi_state(_), do: @default_workspace_state.midi

  # Normalize notes
  defp normalize_notes(notes) when is_list(notes) do
    Enum.map(notes, fn note when is_map(note) ->
      %{
        id: Map.get(note, "id") || Map.get(note, :id) || "note-#{System.unique_integer([:positive])}",
        pitch: Map.get(note, "pitch") || Map.get(note, :pitch) || 60,
        start: Map.get(note, "start") || Map.get(note, :start) || 0,
        duration: Map.get(note, "duration") || Map.get(note, :duration) || 1,
        velocity: Map.get(note, "velocity") || Map.get(note, :velocity) || 100
      }
    end)
  end
  defp normalize_notes(_), do: []

  # Normalize text state
  defp normalize_text_state(text_state) when is_map(text_state) do
    %{
      content: Map.get(text_state, "content") || Map.get(text_state, :content) || "",
      cursors: Map.get(text_state, "cursors") || Map.get(text_state, :cursors) || %{},
      selection: Map.get(text_state, "selection") || Map.get(text_state, :selection)
    }
  end
  defp normalize_text_state(_), do: @default_workspace_state.text

  # Normalize visual state
  defp normalize_visual_state(visual_state) when is_map(visual_state) do
    %{
      elements: normalize_elements(Map.get(visual_state, "elements") || Map.get(visual_state, :elements) || []),
      selected_element: Map.get(visual_state, "selected_element") || Map.get(visual_state, :selected_element),
      tool: Map.get(visual_state, "tool") || Map.get(visual_state, :tool) || "brush",
      brush_size: Map.get(visual_state, "brush_size") || Map.get(visual_state, :brush_size) || 5,
      color: Map.get(visual_state, "color") || Map.get(visual_state, :color) || "#4f46e5"
    }
  end
  defp normalize_visual_state(_), do: @default_workspace_state.visual

  # Normalize visual elements
  defp normalize_elements(elements) when is_list(elements) do
    Enum.map(elements, fn element when is_map(element) ->
      %{
        id: Map.get(element, "id") || Map.get(element, :id) || "element-#{System.unique_integer([:positive])}",
        type: Map.get(element, "type") || Map.get(element, :type) || "shape",
        x: Map.get(element, "x") || Map.get(element, :x) || 0,
        y: Map.get(element, "y") || Map.get(element, :y) || 0,
        width: Map.get(element, "width") || Map.get(element, :width) || 100,
        height: Map.get(element, "height") || Map.get(element, :height) || 100,
        color: Map.get(element, "color") || Map.get(element, :color) || "#4f46e5",
        created_by: Map.get(element, "created_by") || Map.get(element, :created_by)
      }
    end)
  end
  defp normalize_elements(_), do: []

  defp save_workspace_state(session_id, workspace_state) do
    # Ensure the workspace state is normalized before saving
    normalized_state = normalize_workspace_state(workspace_state)
    Sessions.save_workspace_state(session_id, normalized_state)
  end

  # Media item helpers

  defp list_media_items(session_id) do
    Media.list_session_media_items(session_id)
  end

  # Tool availability based on permissions

  defp get_available_tools(permissions) do
    tools = [
      %{id: "audio", name: "Audio", icon: "microphone", enabled: :edit_audio in permissions},
      %{id: "midi", name: "MIDI", icon: "music-note", enabled: :edit_midi in permissions},
      %{id: "text", name: "Lyrics", icon: "document-text", enabled: :edit_text in permissions},
      %{id: "visual", name: "Visual", icon: "pencil", enabled: :edit_visual in permissions}
    ]

    # Always show all tools, but disable some based on permissions
    tools
  end

  # WebRTC token generation

  defp generate_rtc_token(user_id, session_id) do
    Phoenix.Token.sign(FrestylWeb.Endpoint, "user session", %{
      user_id: user_id,
      session_id: session_id,
      timestamp: :os.system_time(:second)
    })
  end

  @impl true
  def handle_event("end_session", _, socket) do
    # Show the confirmation modal
    {:noreply, assign(socket, show_end_session_modal: true)}
  end

  @impl true
  def handle_event("cancel_end_session", _, socket) do
    # Hide the confirmation modal
    {:noreply, assign(socket, show_end_session_modal: false)}
  end

  @impl true
  def handle_event("end_session_confirmed", _, socket) do
    session_data = socket.assigns.session

    # First try to save the current workspace state to media based on session type
    save_result = case session_data.session_type do
      "audio" ->
        # Save audio content to the channel's media
        save_audio_to_channel_media(socket.assigns.workspace_state.audio, socket.assigns.channel.id, socket.assigns.current_user.id, session_data.title)

      "text" ->
        # Save text content to the channel's media
        save_text_to_channel_media(socket.assigns.workspace_state.text, socket.assigns.channel.id, socket.assigns.current_user.id, session_data.title)

      "visual" ->
        # Save visual content to the channel's media
        save_visual_to_channel_media(socket.assigns.workspace_state.visual, socket.assigns.channel.id, socket.assigns.current_user.id, session_data.title)

      "midi" ->
        # Save midi content to the channel's media
        save_midi_to_channel_media(socket.assigns.workspace_state.midi, socket.assigns.channel.id, socket.assigns.current_user.id, session_data.title)

      _ -> {:ok, nil}  # Default case, nothing to save
    end

    # Then end the session
    case Sessions.end_session(session_data.id, socket.assigns.current_user.id) do
      {:ok, _updated_session} ->
        # Add a success message based on whether media was saved
        message = case save_result do
          {:ok, _} -> "Session ended and work saved to channel media."
          _ -> "Session ended successfully."
        end

        {:noreply, socket
          |> put_flash(:info, message)
          |> push_redirect(to: ~p"/channels/#{socket.assigns.channel.slug}")}

      {:error, reason} ->
        {:noreply, socket
          |> assign(show_end_session_modal: false)
          |> put_flash(:error, "Could not end session: #{reason}")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-screen flex flex-col bg-gradient-to-br from-gray-900 to-indigo-900">
      <A11y.skip_to_content />

      <!-- Header -->
      <header class="flex items-center justify-between px-4 py-2 bg-gray-900 bg-opacity-70 border-b border-gray-800">
        <div class="flex items-center">
          <div class="mr-4">
            <.link navigate={~p"/channels/#{@channel.slug}"} class="text-white hover:text-indigo-300">
              <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                <path fill-rule="evenodd" d="M12.707 5.293a1 1 0 010 1.414L9.414 10l3.293 3.293a1 1 0 01-1.414 1.414l-4-4a1 1 0 010-1.414l4-4a1 1 0 011.414 0z" clip-rule="evenodd" />
              </svg>
            </.link>
          </div>

          <div class="flex items-center space-x-2">
            <div class="text-sm text-gray-400 uppercase tracking-wider">
              <%= @channel.name %>
            </div>
            <span class="text-gray-600">/</span>
            <input
              type="text"
              value={@session.title || "Untitled Session"}
              phx-blur="update_session_title"
              class={[
                "bg-transparent border-b border-gray-700 focus:border-indigo-500 text-white focus:outline-none",
                !can_edit_session?(@permissions) && "cursor-not-allowed"
              ]}
              readonly={!can_edit_session?(@permissions)}
              aria-label="Session name"
            />
          </div>
        </div>

        <div class="flex items-center space-x-3">
          <!-- Connection status dot only (no text) -->
          <span class={[
            "h-2 w-2 rounded-full",
            cond do
              @connection_status == "connected" -> "bg-green-500"
              @connection_status == "connecting" -> "bg-yellow-500"
              true -> "bg-red-500"
            end
          ]} title={String.capitalize(@connection_status)}></span>

          <!-- Members indicator -->
          <div class="relative"
            onmouseenter="this.querySelector('.collaborators-dropdown').classList.remove('hidden')"
            onmouseleave="this.querySelector('.collaborators-dropdown').classList.add('hidden')"
          >
            <button
              type="button"
              class="flex items-center text-gray-400 hover:text-white"
              aria-label="Collaborators"
            >
              <span class="text-sm"><%= length(@collaborators) %></span>
              <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                <path d="M13 6a3 3 0 11-6 0 3 3 0 016 0zM18 8a2 2 0 11-4 0 2 2 0 014 0zM14 15a4 4 0 00-8 0v1h8v-1zM6 8a2 2 0 11-4 0 2 2 0 014 0zM16 18v-1a5.972 5.972 0 00-.75-2.906A3.005 3.005 0 0119 15v1h-3zM4.75 12.094A5.973 5.973 0 004 15v1H1v-1a3 3 0 013.75-2.906z" />
              </svg>
            </button>

            <!-- Dropdown content remains the same -->
            <div class="collaborators-dropdown absolute right-0 mt-2 w-60 bg-gray-800 rounded-lg shadow-lg p-2 z-10 hidden">
              <!-- Same content as before -->
            </div>
          </div>

          <!-- Invite button (icon only) -->
          <%= if can_invite_users?(@permissions) do %>
            <button
              type="button"
              phx-click="toggle_invite_modal"
              class="p-2 bg-indigo-500 hover:bg-indigo-600 text-white rounded-full shadow-sm"
              aria-label="Invite collaborators"
            >
              <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" viewBox="0 0 20 20" fill="currentColor">
                <path d="M8 9a3 3 0 100-6 3 3 0 000 6zM8 11a6 6 0 016 6H2a6 6 0 016-6zM16 7a1 1 0 10-2 0v1h-1a1 1 0 100 2h1v1a1 1 0 102 0v-1h1a1 1 0 100-2h-1V7z" />
              </svg>
            </button>
          <% end %>

          <!-- Settings button (unchanged) -->
          <button
            type="button"
            phx-click="toggle_settings_modal"
            class="text-gray-400 hover:text-white"
            aria-label="Settings"
          >
            <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
              <path fill-rule="evenodd" d="M11.49 3.17c-.38-1.56-2.6-1.56-2.98 0a1.532 1.532 0 01-2.286.948c-1.372-.836-2.942.734-2.106 2.106.54.886.061 2.042-.947 2.287-1.561.379-1.561 2.6 0 2.978a1.532 1.532 0 01.947 2.287c-.836 1.372.734 2.942 2.106 2.106a1.532 1.532 0 012.287.947c.379 1.561 2.6 1.561 2.978 0a1.533 1.533 0 012.287-.947c1.372.836 2.942-.734 2.106-2.106a1.533 1.533 0 01.947-2.287c1.561-.379 1.561-2.6 0-2.978a1.532 1.532 0 01-.947-2.287c.836-1.372-.734-2.942-2.106-2.106a1.532 1.532 0 01-2.287-.947zM10 13a3 3 0 100-6 3 3 0 000 6z" clip-rule="evenodd" />
            </svg>
          </button>

          <!-- End Session button (simplified to just "End") -->
          <%= if @current_user.id == @session.creator_id || @current_user.id == @session.host_id do %>
            <button
              type="button"
              phx-click="end_session"
              class="bg-red-500 hover:bg-red-600 text-white rounded-md px-3 py-1"
            >
              End
            </button>
          <% end %>

          <!-- User avatar same as before -->
          <div class="relative ml-2">
            <!-- User avatar section as before -->
          </div>
        </div>
      </header>

      <!-- Main content area -->
      <div class="flex flex-1 overflow-hidden" id="main-content">
        <!-- Left sidebar - Tools -->
        <div class="w-16 bg-gray-900 bg-opacity-70 flex flex-col items-center py-4 space-y-4">
          <%= for tool <- @tools do %>
            <button
              type="button"
              phx-click="set_active_tool"
              phx-value-tool={tool.id}
              class={[
                "p-2 rounded-md transition-all duration-200",
                @active_tool == tool.id && "bg-gradient-to-r from-indigo-500 to-purple-600 text-white shadow-md",
                @active_tool != tool.id && "text-gray-400 hover:text-white",
                !tool.enabled && "opacity-50 cursor-not-allowed"
              ]}
              disabled={!tool.enabled}
              aria-label={tool.name}
              aria-pressed={@active_tool == tool.id}
              title={tool.name}
            >
              <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <%= case tool.icon do %>
                  <% "microphone" -> %>
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z" />
                  <% "music-note" -> %>
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3" />
                  <% "document-text" -> %>
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                  <% "pencil" -> %>
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" />
                <% end %>
              </svg>
            </button>
          <% end %>
        </div>

        <!-- Workspace area -->
        <div class="flex-1 overflow-hidden">
          <%= case @active_tool do %>
            <% "audio" -> %>
              <div class="h-full flex flex-col bg-gray-900 bg-opacity-50">
                <div class="flex items-center justify-between p-4 border-b border-gray-800">
                  <h2 class="text-white text-lg font-medium">Audio Workspace</h2>

                  <div class="flex items-center space-x-3">
                    <!-- Playback controls -->
                    <button
                      type="button"
                      phx-click="audio_toggle_play"
                      class={[
                        "rounded-full p-2 focus:outline-none",
                        @workspace_state.audio.playing && "bg-red-500 hover:bg-red-600",
                        !@workspace_state.audio.playing && "bg-indigo-500 hover:bg-indigo-600"
                      ]}
                      aria-label={if @workspace_state.audio.playing, do: "Stop", else: "Play"}
                    >
                      <%= if @workspace_state.audio.playing do %>
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-white" viewBox="0 0 20 20" fill="currentColor">
                          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8 7a1 1 0 00-1 1v4a1 1 0 001 1h4a1 1 0 001-1V8a1 1 0 00-1-1H8z" clip-rule="evenodd" />
                        </svg>
                      <% else %>
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-white" viewBox="0 0 20 20" fill="currentColor">
                          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM9.555 7.168A1 1 0 008 8v4a1 1 0 001.555.832l3-2a1 1 0 000-1.664l-3-2z" clip-rule="evenodd" />
                        </svg>
                      <% end %>
                    </button>

                    <!-- Record button (conditionally shown based on permissions) -->
                    <%= if can_record_audio?(@permissions) do %>
                      <button
                        type="button"
                        phx-click="audio_toggle_record"
                        class={[
                          "rounded-full p-2 focus:outline-none",
                          @workspace_state.audio.recording && "bg-red-500 hover:bg-red-600 animate-pulse",
                          !@workspace_state.audio.recording && "bg-gray-700 hover:bg-gray-600"
                        ]}
                        aria-label={if @workspace_state.audio.recording, do: "Stop recording", else: "Start recording"}
                      >
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-white" viewBox="0 0 20 20" fill="currentColor">
                          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM10 9a1 1 0 00-1 1v2.586l-1.293-1.293a1 1 0 10-1.414 1.414l3 3a.997.997 0 001.414 0l3-3a1 1 0 00-1.414-1.414L11 12.586V10a1 1 0 00-1-1z" clip-rule="evenodd" />
                        </svg>
                      </button>
                    <% end %>

                    <!-- Add track button -->
                    <%= if can_edit_audio?(@permissions) do %>
                      <button
                        type="button"
                        phx-click="audio_add_track"
                        class="bg-indigo-500 hover:bg-indigo-600 rounded-md p-1.5 text-white"
                        aria-label="Add track"
                      >
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                          <path fill-rule="evenodd" d="M10 3a1 1 0 011 1v5h5a1 1 0 110 2h-5v5a1 1 0 11-2 0v-5H4a1 1 0 110-2h5V4a1 1 0 011-1z" clip-rule="evenodd" />
                        </svg>
                      </button>
                    <% end %>
                  </div>
                </div>

                <div class="flex-1 overflow-y-auto p-4">
                  <%= if length(@workspace_state.audio.tracks) == 0 do %>
                    <div class="h-full flex flex-col items-center justify-center text-gray-400">
                      <svg xmlns="http://www.w3.org/2000/svg" class="h-16 w-16 mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z" />
                      </svg>
                      <p class="text-lg">No audio tracks yet</p>
                      <%= if can_edit_audio?(@permissions) do %>
                        <button
                          phx-click="audio_add_track"
                          class="mt-4 px-4 py-2 bg-gradient-to-r from-indigo-500 to-purple-600 hover:from-indigo-600 hover:to-purple-700 text-white rounded-lg shadow-lg"
                        >
                          Add your first track
                        </button>
                      <% else %>
                        <p class="mt-2 text-sm">You don't have permission to add tracks</p>
                      <% end %>
                    </div>
                  <% else %>
                    <div class="space-y-4">
                      <%= for track <- @workspace_state.audio.tracks do %>
                        <div class="bg-gray-800 rounded-lg p-4">
                          <div class="flex items-center justify-between mb-2">
                            <div class="flex items-center">
                              <span class="text-white font-medium"><%= track.name %></span>
                              <%= if track.muted do %>
                                <span class="ml-2 text-xs px-2 py-0.5 bg-gray-700 text-gray-400 rounded-full">Muted</span>
                              <% end %>
                              <%= if track.solo do %>
                                <span class="ml-2 text-xs px-2 py-0.5 bg-indigo-600 text-white rounded-full">Solo</span>
                              <% end %>
                            </div>
                            <div class="flex items-center space-x-2">
                              <input
                                type="range"
                                min="0"
                                max="1"
                                step="0.01"
                                value={track.volume}
                                class="w-24"
                                disabled={!can_edit_audio?(@permissions)}
                                aria-label="Volume"
                              />
                            </div>
                          </div>

                          <!-- Waveform visualization -->
                          <div class="h-20 bg-gray-900 rounded-md relative overflow-hidden">
                            <%= if length(track.clips) > 0 do %>
                              <%= for clip <- track.clips do %>
                                <div class="absolute top-0 h-full" style={"left: #{clip.start_time * 50}px; width: 200px;"}>
                                  <div class="h-full w-full bg-gradient-to-r from-indigo-500 to-indigo-400 rounded-md opacity-60"></div>
                                  <div class="absolute top-0 left-0 w-full h-full flex items-center justify-center">
                                    <span class="text-xs text-white font-medium px-2 py-0.5 bg-gray-800 bg-opacity-70 rounded-md">
                                      <%= clip.name %>
                                    </span>
                                  </div>
                                </div>
                              <% end %>
                            <% else %>
                              <div class="flex items-center justify-center h-full text-gray-500 text-sm">
                                No clips in this track
                              </div>
                            <% end %>
                          </div>
                        </div>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              </div>

            <% "midi" -> %>
              <div class="h-full flex flex-col bg-gray-900 bg-opacity-50">
                <div class="flex items-center justify-between p-4 border-b border-gray-800">
                  <h2 class="text-white text-lg font-medium">MIDI Sequencer</h2>

                  <div class="flex items-center space-x-3">
                    <!-- Playback controls -->
                    <button
                      type="button"
                      class="rounded-full p-2 bg-indigo-500 hover:bg-indigo-600 focus:outline-none"
                      aria-label="Play"
                    >
                      <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-white" viewBox="0 0 20 20" fill="currentColor">
                        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM9.555 7.168A1 1 0 008 8v4a1 1 0 001.555.832l3-2a1 1 0 000-1.664l-3-2z" clip-rule="evenodd" />
                      </svg>
                    </button>

                    <!-- Instrument selection -->
                    <select
                      class="bg-gray-800 border-gray-700 text-white rounded-md text-sm focus:ring-indigo-500 focus:border-indigo-500"
                      disabled={!can_edit_midi?(@permissions)}
                    >
                      <option value="piano">Piano</option>
                      <option value="synth">Synth</option>
                      <option value="bass">Bass</option>
                      <option value="drums">Drums</option>
                    </select>
                  </div>
                </div>

                <div class="flex-1 overflow-auto p-4">
                  <div class="h-full flex flex-col items-center justify-center text-gray-400">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-16 w-16 mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3" />
                    </svg>
                    <p class="text-lg">MIDI sequencer will be implemented soon</p>
                    <p class="mt-2 text-sm max-w-md text-center">The MIDI editor will allow you to create and edit notes, adjust velocity, and work with multiple tracks.</p>
                  </div>
                </div>
              </div>

            <% "text" -> %>
              <div class="h-full flex flex-col bg-gray-900 bg-opacity-50">
                <div class="p-4 border-b border-gray-800">
                  <h2 class="text-white text-lg font-medium">Lyrics Editor</h2>
                </div>

                <div class="flex-1 overflow-y-auto p-4">
                  <div class="h-full">
                    <%= if can_edit_text?(@permissions) do %>
                      <textarea
                        id="text-editor"
                        phx-hook="TextEditor"
                        class="w-full h-full bg-gray-800 text-white p-4 rounded-lg border border-gray-700 focus:border-indigo-500 focus:ring-indigo-500"
                        placeholder="Write your lyrics here..."
                        aria-label="Lyrics editor"
                        phx-update="ignore"
                      ><%= @workspace_state.text.content %></textarea>
                    <% else %>
                      <div
                        class="w-full h-full bg-gray-800 text-white p-4 rounded-lg border border-gray-700 overflow-auto"
                      >
                        <%= if @workspace_state.text.content != "" do %>
                          <%= @workspace_state.text.content %>
                        <% else %>
                          <p class="text-gray-500 italic">No content yet</p>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                </div>
              </div>

            <% "visual" -> %>
              <div class="h-full flex flex-col bg-gray-900 bg-opacity-50">
                <div class="flex items-center justify-between p-4 border-b border-gray-800">
                  <h2 class="text-white text-lg font-medium">Visual Editor</h2>

                  <%= if can_edit_visual?(@permissions) do %>
                    <div class="flex items-center space-x-3">
                      <!-- Tools -->
                      <div class="flex bg-gray-800 rounded-md p-1">
                        <button
                          phx-click="visual_update_tool"
                          phx-value-tool="brush"
                          class={[
                            "p-1.5 rounded-md",
                            @workspace_state.visual.tool == "brush" && "bg-indigo-500 text-white",
                            @workspace_state.visual.tool != "brush" && "text-gray-400 hover:text-white"
                          ]}
                          aria-label="Brush tool"
                        >
                          <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                          </svg>
                        </button>

                        <button
                          phx-click="visual_update_tool"
                          phx-value-tool="shape"
                          class={[
                            "p-1.5 rounded-md",
                            @workspace_state.visual.tool == "shape" && "bg-indigo-500 text-white",
                            @workspace_state.visual.tool != "shape" && "text-gray-400 hover:text-white"
                          ]}
                          aria-label="Shape tool"
                        >
                          <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                            <path d="M11 17a1 1 0 001.447.894l4-2A1 1 0 0017 15V9.236a1 1 0 00-1.447-.894l-4 2a1 1 0 00-.553.894V17zM15.211 6.276a1 1 0 000-1.788l-4.764-2.382a1 1 0 00-.894 0L4.789 4.488a1 1 0 000 1.788l4.764 2.382a1 1 0 00.894 0l4.764-2.382zM4.447 8.342A1 1 0 003 9.236V15a1 1 0 00.553.894l4 2A1 1 0 009 17v-5.764a1 1 0 00-.553-.894l-4-2z" />
                          </svg>
                        </button>

                        <button
                          phx-click="visual_update_tool"
                          phx-value-tool="text"
                          class={[
                            "p-1.5 rounded-md",
                            @workspace_state.visual.tool == "text" && "bg-indigo-500 text-white",
                            @workspace_state.visual.tool != "text" && "text-gray-400 hover:text-white"
                          ]}
                          aria-label="Text tool"
                        >
                          <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7.25 6.033C8.624 8.154 10.56 9.5 12.5 9.5s3.876-1.346 5.25-3.467c0 0-3.5-3.5-5.25-3.5-1.75 0-5.25 3.5-5.25 3.5zm0 0v1.008m0 0c1.374 2.12 3.31 3.466 5.25 3.466s3.876-1.345 5.25-3.466m-10.5 0-1.045 1.613C4.677 10.459 4 13.306 4 16.22V18c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2v-1.78c0-2.915-.677-5.762-1.955-8.566L17 7.041M4 12h2.5m11.5 0h2"/>
                          </svg>
                        </button>
                      </div>

                      <!-- Color picker -->
                      <div class="flex items-center">
                        <input
                          type="color"
                          value={@workspace_state.visual.color}
                          phx-blur="visual_update_color"
                          class="h-8 w-8 bg-transparent rounded cursor-pointer"
                          aria-label="Select color"
                        />
                      </div>
                    </div>
                  <% end %>
                </div>

                <div class="flex-1 overflow-auto p-4">
                  <div id="visual-canvas" phx-update="ignore" class="h-full w-full bg-gray-800 rounded-lg">
                    <!-- Canvas for drawing will be initialized by JavaScript -->
                    <div class="h-full flex flex-col items-center justify-center text-gray-400">
                      <svg xmlns="http://www.w3.org/2000/svg" class="h-16 w-16 mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" />
                      </svg>
                      <p class="text-lg">Visual editor will be implemented soon</p>
                      <p class="mt-2 text-sm max-w-md text-center">The visual editor will allow you to create and edit graphics, add text, and collaborate in real-time.</p>
                    </div>
                  </div>
                </div>
              </div>
          <% end %>
        </div>

        <!-- Right sidebar - Chat & Notifications -->
        <div class="w-64 bg-gray-900 bg-opacity-70 flex flex-col border-l border-gray-800">
          <!-- Tabs for Chat and Notifications -->
          <div class="flex border-b border-gray-800">
            <button
              class="flex-1 py-3 text-center text-sm font-medium text-white bg-indigo-500 bg-opacity-20"
              aria-selected="true"
            >
              Chat
            </button>
            <button
              class="flex-1 py-3 text-center text-sm font-medium text-gray-400 hover:text-white"
              aria-selected="false"
            >
              Media
            </button>
          </div>

          <!-- Chat messages -->
          <div class="flex-1 overflow-y-auto p-4" id="chat-messages">
            <div class="space-y-4">
              <%= if length(@chat_messages) == 0 do %>
                <div class="text-center text-gray-500 text-sm my-4">
                  No messages yet
                </div>
              <% end %>

              <%= for message <- @chat_messages do %>
                <div class={[
                  "flex",
                  message.user_id == @current_user.id && "justify-end"
                ]}>
                  <%= if message.user_id != @current_user.id do %>
                    <div class="flex-shrink-0 mr-3">
                      <%= if Map.get(message, :avatar_url) do %>
                        <img src={message.avatar_url} class="h-8 w-8 rounded-full" alt={message.username} />
                      <% else %>
                        <div class="h-8 w-8 rounded-full bg-gradient-to-br from-indigo-500 to-purple-600 flex items-center justify-center text-white font-medium text-sm">
                          <%= String.at(message.username, 0) %>
                        </div>
                      <% end %>
                    </div>
                  <% end %>

                  <div class={[
                    "rounded-lg px-4 py-2 max-w-[80%]",
                    message.user_id == @current_user.id && "bg-indigo-500 text-white",
                    message.user_id != @current_user.id && "bg-gray-800 text-white"
                  ]}>
                    <%= if message.user_id != @current_user.id do %>
                      <p class="text-xs font-medium text-gray-400 mb-1"><%= message.username %></p>
                    <% end %>
                    <p class="text-sm whitespace-pre-wrap"><%= message.content %></p>
                    <p class="text-xs text-right mt-1 opacity-60">
                      <%= if Map.has_key?(message, :inserted_at) do %>
                        <%= Calendar.strftime(message.inserted_at, "%I:%M %p") %>
                      <% else %>
                        <%= Calendar.strftime(message.timestamp, "%I:%M %p") %>
                      <% end %>
                    </p>
                  </div>

                  <%= if message.user_id == @current_user.id do %>
                    <div class="flex-shrink-0 ml-3">
                      <%= if Map.get(message, :avatar_url) do %>
                        <img src={message.avatar_url} class="h-8 w-8 rounded-full" alt={message.username} />
                      <% else %>
                        <div class="h-8 w-8 rounded-full bg-gradient-to-br from-indigo-500 to-purple-600 flex items-center justify-center text-white font-medium text-sm">
                          <%= String.at(message.username, 0) %>
                        </div>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>
          </div>

          <!-- Chat input -->
          <div class="p-4 border-t border-gray-800">
            <form phx-submit="send_message" class="flex">
              <input
                type="text"
                name="message"
                value={@message_input}
                phx-keyup="update_message_input"
                placeholder="Type a message..."
                class="block w-full bg-gray-800 border-gray-700 rounded-l-md text-white text-sm focus:border-indigo-500 focus:ring-indigo-500"
                aria-label="Chat message"
              >
              <button
                type="submit"
                class="bg-indigo-500 hover:bg-indigo-600 text-white rounded-r-md px-3"
                aria-label="Send message"
              >
                <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                  <path d="M10.894 2.553a1 1 0 00-1.788 0l-7 14a1 1 0 001.169 1.409l5-1.429A1 1 0 009 15.571V11a1 1 0 112 0v4.571a1 1 0 00.725.962l5 1.428a1 1 0 001.17-1.408l-7-14z" />
                </svg>
              </button>
            </form>
          </div>
        </div>
      </div>

      <!-- Notification toast container -->
      <div class="fixed bottom-4 right-4 space-y-2 z-50">
        <%= for notification <- Enum.take(@notifications, 3) do %>
          <div
            class="bg-gray-900 bg-opacity-90 border border-gray-800 text-white rounded-lg shadow-lg p-4 max-w-xs"
            role="alert"
          >
            <div class="flex items-start">
              <div class="flex-shrink-0 mr-3 mt-0.5">
                <%= case notification.type do %>
                  <% :user_joined -> %>
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-green-400" viewBox="0 0 20 20" fill="currentColor">
                      <path d="M8 9a3 3 0 100-6 3 3 0 000 6zM8 11a6 6 0 016 6H2a6 6 0 016-6zM16 7a1 1 0 10-2 0v1h-1a1 1 0 100 2h1v1a1 1 0 102 0v-1h1a1 1 0 100-2h-1V7z" />
                    </svg>
                  <% :user_left -> %>
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor">
                      <path d="M11 6a3 3 0 11-6 0 3 3 0 016 0zM14 17a6 6 0 00-12 0h12z" />
                      <path d="M13 8a1 1 0 100 2h4a1 1 0 100-2h-4z" />
                    </svg>
                  <% :new_message -> %>
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-indigo-400" viewBox="0 0 20 20" fill="currentColor">
                      <path d="M2 5a2 2 0 012-2h7a2 2 0 012 2v4a2 2 0 01-2 2H9l-3 3v-3H4a2 2 0 01-2-2V5z" />
                      <path d="M15 7v2a4 4 0 01-4 4H9.828l-1.766 1.767c.28.149.599.233.938.233h2l3 3v-3h2a2 2 0 002-2V9a2 2 0 00-2-2h-1z" />
                    </svg>
                  <% :workspace_updated -> %>
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-blue-400" viewBox="0 0 20 20" fill="currentColor">
                      <path d="M13.586 3.586a2 2 0 112.828 2.828l-.793.793-2.828-2.828.793-.793zM11.379 5.793L3 14.172V17h2.828l8.38-8.379-2.83-2.828z" />
                    </svg>
                  <% :invitation_sent -> %>
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-yellow-400" viewBox="0 0 20 20" fill="currentColor">
                      <path d="M2.003 5.884L10 9.882l7.997-3.998A2 2 0 0016 4H4a2 2 0 00-1.997 1.884z" />
                      <path d="M18 8.118l-8 4-8-4V14a2 2 0 002 2h12a2 2 0 002-2V8.118z" />
                    </svg>
                  <% _ -> %>
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-white" viewBox="0 0 20 20" fill="currentColor">
                      <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd" />
                    </svg>
                <% end %>
              </div>
              <div>
                <p class="text-sm"><%= notification.message %></p>
                <p class="text-xs text-gray-400 mt-1">
                  <%= Calendar.strftime(notification.timestamp, "%I:%M %p") %>
                </p>
              </div>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Invite Modal -->
      <A11y.a11y_dialog
        id="invite-modal"
        show={@show_invite_modal}
        title="Invite Collaborators"
        on_cancel="toggle_invite_modal"
        confirm_label="Send Invitation"
        cancel_label="Cancel"
        on_confirm="send_invite"
      >
        <div class="mt-2">
          <p class="text-sm text-gray-500">
            Enter the email address of the person you want to invite to collaborate on this session.
          </p>
          <div class="mt-4">
            <label for="email" class="block text-sm font-medium text-gray-700">Email address</label>
            <div class="mt-1">
              <input
                type="email"
                name="email"
                id="email"
                class="shadow-sm focus:ring-indigo-500 focus:border-indigo-500 block w-full sm:text-sm border-gray-300 rounded-md"
                placeholder="collaborator@example.com"
              />
            </div>
          </div>

          <div class="mt-4">
            <label for="role" class="block text-sm font-medium text-gray-700">Role</label>
            <div class="mt-1">
              <select
                name="role"
                id="role"
                class="shadow-sm focus:ring-indigo-500 focus:border-indigo-500 block w-full sm:text-sm border-gray-300 rounded-md"
              >
                <option value="participant">Participant (can collaborate)</option>
                <option value="moderator">Moderator (can collaborate and moderate)</option>
                <option value="viewer">Viewer (can only view)</option>
              </select>
            </div>
          </div>
        </div>
      </A11y.a11y_dialog>

      <!-- Settings Modal -->
      <A11y.a11y_dialog
        id="settings-modal"
        show={@show_settings_modal}
        title="Session Settings"
        on_cancel="toggle_settings_modal"
        confirm_label="Save Settings"
        cancel_label="Cancel"
        on_confirm="save_settings"
      >
        <div class="mt-2">
          <div>
            <h3 class="text-sm font-medium text-gray-900">Session Details</h3>

            <div class="mt-3">
              <label for="session-title" class="block text-sm font-medium text-gray-700">Title</label>
              <div class="mt-1">
                <input
                  type="text"
                  name="title"
                  id="session-title"
                  value={@session.title}
                  class="shadow-sm focus:ring-indigo-500 focus:border-indigo-500 block w-full sm:text-sm border-gray-300 rounded-md"
                  disabled={!can_edit_session?(@permissions)}
                />
              </div>
            </div>

            <div class="mt-3">
              <label for="session-description" class="block text-sm font-medium text-gray-700">Description</label>
              <div class="mt-1">
                <textarea
                  name="description"
                  id="session-description"
                  rows="3"
                  class="shadow-sm focus:ring-indigo-500 focus:border-indigo-500 block w-full sm:text-sm border-gray-300 rounded-md"
                  disabled={!can_edit_session?(@permissions)}
                ><%= @session.description %></textarea>
              </div>
            </div>
          </div>

          <div class="mt-6">
            <h3 class="text-sm font-medium text-gray-900">Audio Settings</h3>

            <div class="mt-3 space-y-4">
              <div class="flex items-center">
                <input
                  id="auto-normalize"
                  name="auto_normalize"
                  type="checkbox"
                  class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded"
                  disabled={!can_edit_session?(@permissions)}
                />
                <label for="auto-normalize" class="ml-3 block text-sm font-medium text-gray-700">
                  Automatically normalize audio levels
                </label>
              </div>

              <div class="flex items-center">
                <input
                  id="auto-record"
                  name="auto_record"
                  type="checkbox"
                  class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded"
                  disabled={!can_edit_session?(@permissions)}
                />
                <label for="auto-record" class="ml-3 block text-sm font-medium text-gray-700">
                  Automatically save session recordings
                </label>
              </div>
            </div>
          </div>

          <div class="mt-6">
            <h3 class="text-sm font-medium text-gray-900">Your Settings</h3>

            <div class="mt-3">
              <label for="display-name" class="block text-sm font-medium text-gray-700">Display Name</label>
              <div class="mt-1">
                <input
                  type="text"
                  name="display_name"
                  id="display-name"
                  value={@current_user.username}
                  class="shadow-sm focus:ring-indigo-500 focus:border-indigo-500 block w-full sm:text-sm border-gray-300 rounded-md"
                />
              </div>
            </div>
          </div>
        </div>
      </A11y.a11y_dialog>

      <!-- End Session Confirmation Modal -->
      <%= if @show_end_session_modal do %>
        <div class="fixed z-50 inset-0 overflow-y-auto" role="dialog" aria-modal="true">
          <div class="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
            <!-- Background overlay -->
            <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity" aria-hidden="true"></div>

            <span class="hidden sm:inline-block sm:align-middle sm:h-screen" aria-hidden="true">&#8203;</span>

            <!-- Modal panel -->
            <div class="inline-block align-bottom bg-white rounded-xl text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-lg sm:w-full">
              <div class="bg-gradient-to-r from-red-500 to-red-600 px-4 py-4 sm:px-6 flex items-center justify-between">
                <h3 class="text-lg leading-6 font-medium text-white flex items-center">
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-2" viewBox="0 0 20 20" fill="currentColor">
                    <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
                  </svg>
                  End Session
                </h3>
                <button
                  type="button"
                  phx-click="cancel_end_session"
                  class="text-white hover:text-gray-200 focus:outline-none"
                >
                  <span class="sr-only">Close</span>
                  <svg class="h-6 w-6" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </div>

              <div class="bg-white px-4 pt-5 pb-4 sm:p-6 sm:pb-4">
                <div class="sm:flex sm:items-start">
                  <div class="mt-3 text-center sm:mt-0 sm:ml-4 sm:text-left">
                    <h3 class="text-lg leading-6 font-medium text-gray-900" id="modal-title">
                      Are you sure?
                    </h3>
                    <div class="mt-2">
                      <p class="text-sm text-gray-500">
                        This will end the session for all participants. Your work will be saved to the channel's media library.
                      </p>
                    </div>
                  </div>
                </div>
              </div>

              <div class="bg-gray-50 px-4 py-3 sm:px-6 sm:flex sm:flex-row-reverse">
                <button
                  type="button"
                  phx-click="end_session_confirmed"
                  class="w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 bg-red-600 text-base font-medium text-white hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500 sm:ml-3 sm:w-auto sm:text-sm"
                >
                  End Session
                </button>
                <button
                  type="button"
                  phx-click="cancel_end_session"
                  class="mt-3 w-full inline-flex justify-center rounded-md border border-gray-300 shadow-sm px-4 py-2 bg-white text-base font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 sm:mt-0 sm:ml-3 sm:w-auto sm:text-sm"
                >
                  Cancel
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
