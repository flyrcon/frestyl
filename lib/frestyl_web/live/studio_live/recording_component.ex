# lib/frestyl_web/live/studio_live/recording_component.ex
defmodule FrestylWeb.StudioLive.RecordingComponent do
  use FrestylWeb, :live_component
  alias Frestyl.Studio.RecordingEngine

  @impl true
  def update(assigns, socket) do
    socket = socket
      |> assign(assigns)
      |> assign(:recording_state, %{})
      |> assign(:active_track_recordings, %{})
      |> assign(:mix_mode, :individual)

    if connected?(socket) do
      # Subscribe to recording events
      Phoenix.PubSub.subscribe(Frestyl.PubSub, "recording_engine:#{assigns.session_id}")
    end

    {:ok, socket}
  end

  @impl true
  def handle_event("start_recording", %{"track_id" => track_id}, socket) do
    session_id = socket.assigns.session_id
    user_id = socket.assigns.current_user.id

    case RecordingEngine.start_recording(session_id, track_id, user_id) do
      {:ok, recording_session} ->
        # Start client-side recording
        send_update(__MODULE__,
          id: socket.assigns.id,
          action: :recording_started,
          track_id: track_id,
          recording_session: recording_session
        )

        {:noreply, push_event(socket, "start-recording", %{
          track_id: track_id,
          quality_settings: recording_session.quality_settings
        })}

      {:error, :recording_limit_exceeded} ->
        {:noreply, socket
          |> put_flash(:error, "Recording limit exceeded for your tier")
          |> push_event("show-upgrade-modal", %{})}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to start recording: #{reason}")}
    end
  end

  @impl true
  def handle_event("stop_recording", %{"track_id" => track_id}, socket) do
    session_id = socket.assigns.session_id
    user_id = socket.assigns.current_user.id

    case RecordingEngine.stop_recording(session_id, track_id, user_id) do
      {:ok, track_record} ->
        {:noreply, push_event(socket, "stop-recording", %{
          track_id: track_id,
          duration: track_record.duration
        })}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to stop recording: #{reason}")}
    end
  end

  @impl true
  def handle_event("audio_chunk", %{"track_id" => track_id, "audio_data" => audio_data, "timestamp" => timestamp}, socket) do
    session_id = socket.assigns.session_id
    user_id = socket.assigns.current_user.id

    # Decode base64 audio data
    decoded_audio = Base.decode64!(audio_data)

    RecordingEngine.add_audio_chunk(session_id, track_id, user_id, decoded_audio, timestamp)

    {:noreply, socket}
  end

  @impl true
  def handle_event("create_draft", %{"title" => title}, socket) do
    session_id = socket.assigns.session_id

    case RecordingEngine.create_draft(session_id, %{title: title}) do
      {:ok, draft} ->
        {:noreply, socket
          |> put_flash(:info, "Draft '#{title}' created successfully")
          |> push_event("draft-created", %{draft_id: draft.id})}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to create draft: #{reason}")}
    end
  end

  @impl true
  def handle_event("export_draft", %{"draft_id" => draft_id} = params, socket) do
    session_id = socket.assigns.session_id
    user = socket.assigns.current_user

    export_params = %{
      draft_id: draft_id,
      title: params["title"],
      channel_id: params["channel_id"],
      quality: params["quality"] || "standard",
      scenario: String.to_atom(params["scenario"] || "download")
    }

    case RecordingEngine.export_to_media(session_id, export_params, user) do
      {:ok, media_files} ->
        file_count = length(media_files)
        {:noreply, socket
          |> put_flash(:info, "Successfully exported #{file_count} file(s) to media library")
          |> push_event("export-completed", %{media_files: media_files})}

      {:error, :insufficient_credits} ->
        {:noreply, socket
          |> put_flash(:error, "Insufficient export credits")
          |> push_event("show-upgrade-modal", %{reason: "export_credits"})}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Export failed: #{reason}")}
    end
  end

  @impl true
  def handle_event("update_mix", %{"settings" => mix_settings}, socket) do
    session_id = socket.assigns.session_id
    user_id = socket.assigns.current_user.id

    RecordingEngine.update_mix_settings(session_id, user_id, mix_settings)

    {:noreply, assign(socket, :mix_settings, mix_settings)}
  end

  # Handle PubSub events
  @impl true
  def handle_info({:recording_started, track_id, user_id, recording_session}, socket) do
    if user_id != socket.assigns.current_user.id do
      # Another user started recording
      {:noreply, socket
        |> update(:active_track_recordings, &Map.put(&1, track_id, recording_session))
        |> push_event("other-user-recording", %{track_id: track_id, user_id: user_id})}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:recording_stopped, track_id, user_id, track_record}, socket) do
    {:noreply, socket
      |> update(:active_track_recordings, &Map.delete(&1, track_id))
      |> push_event("recording-complete", %{
        track_id: track_id,
        user_id: user_id,
        duration: track_record.duration
      })}
  end

  @impl true
  def handle_info({:draft_created, draft}, socket) do
    {:noreply, push_event(socket, "draft-available", %{
      draft_id: draft.id,
      title: draft.title,
      expires_at: draft.expires_at
    })}
  end

  @impl true
  def handle_info({:chunk_received, track_id, user_id, chunk}, socket) do
    # Update real-time recording indicators
    {:noreply, push_event(socket, "recording-activity", %{
      track_id: track_id,
      user_id: user_id,
      chunk_size: chunk.size
    })}
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="recording-workspace" id={"recording-#{@id}"} phx-hook="RecordingWorkspace">
      <!-- Recording Controls -->
      <div class="flex items-center justify-between p-4 bg-gray-900 border-b border-gray-700">
        <h3 class="text-white font-medium">Multi-Track Recording</h3>

        <div class="flex items-center space-x-3">
          <!-- Mix Mode Selector -->
          <select phx-change="update_mix" name="mix_mode" class="bg-gray-800 text-white rounded px-3 py-1">
            <option value="individual">Individual Mix</option>
            <option value="shared_mix">Shared Mix</option>
            <option value="follow_leader">Follow Leader</option>
          </select>

          <!-- Draft Controls -->
          <button
            phx-click="create_draft"
            phx-target={@myself}
            class="bg-blue-600 hover:bg-blue-700 text-white px-3 py-1 rounded"
          >
            Save Draft
          </button>
        </div>
      </div>

      <!-- Track Recording Interface -->
      <div class="flex-1 p-4">
        <%= if length(@workspace_state.audio.tracks) == 0 do %>
          <div class="text-center text-gray-400 py-8">
            <p>Add tracks to start recording</p>
          </div>
        <% else %>
          <div class="space-y-4">
            <%= for track <- @workspace_state.audio.tracks do %>
              <div class="bg-gray-800 rounded-lg p-4 relative">
                <div class="flex items-center justify-between mb-3">
                  <h4 class="text-white font-medium"><%= track.name %></h4>

                  <div class="flex items-center space-x-2">
                    <!-- Recording Status Indicator -->
                    <%= if Map.has_key?(@active_track_recordings, track.id) do %>
                      <div class="flex items-center space-x-1 text-red-400">
                        <div class="w-2 h-2 bg-red-500 rounded-full animate-pulse"></div>
                        <span class="text-xs">REC</span>
                      </div>
                    <% end %>

                    <!-- Recording Controls -->
                    <%= if Map.has_key?(@active_track_recordings, track.id) do %>
                      <button
                        phx-click="stop_recording"
                        phx-value-track_id={track.id}
                        phx-target={@myself}
                        class="bg-red-600 hover:bg-red-700 text-white px-3 py-1 rounded text-sm"
                      >
                        Stop
                      </button>
                    <% else %>
                      <button
                        phx-click="start_recording"
                        phx-value-track_id={track.id}
                        phx-target={@myself}
                        class="bg-red-600 hover:bg-red-700 text-white px-3 py-1 rounded text-sm"
                      >
                        Record
                      </button>
                    <% end %>
                  </div>
                </div>

                <!-- Audio Level Meters -->
                <div class="h-2 bg-gray-700 rounded-full overflow-hidden">
                  <div class="h-full bg-green-500 transition-all duration-100"
                       style="width: 0%"
                       data-track-meter={track.id}>
                  </div>
                </div>

                <!-- Waveform Display -->
                <div class="mt-3 h-16 bg-gray-900 rounded relative">
                  <canvas
                    class="w-full h-full"
                    data-waveform={track.id}
                    data-track-id={track.id}>
                  </canvas>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>

      <!-- Draft Management -->
      <div class="border-t border-gray-700 p-4">
        <h4 class="text-white font-medium mb-3">Session Drafts</h4>

        <div id="draft-list" class="space-y-2">
          <!-- Drafts will be populated via LiveView events -->
        </div>
      </div>

      <!-- Export Modal -->
      <div id="export-modal" class="hidden fixed inset-0 bg-black bg-opacity-50 z-50">
        <div class="flex items-center justify-center min-h-screen p-4">
          <div class="bg-white rounded-lg p-6 w-full max-w-md">
            <h3 class="text-lg font-medium mb-4">Export to Media Library</h3>

            <form phx-submit="export_draft" phx-target={@myself}>
              <input type="hidden" name="draft_id" id="export-draft-id" />

              <div class="mb-4">
                <label class="block text-sm font-medium mb-1">Title</label>
                <input type="text" name="title" class="w-full border rounded px-3 py-2" required />
              </div>

              <div class="mb-4">
                <label class="block text-sm font-medium mb-1">Channel (Optional)</label>
                <select name="channel_id" class="w-full border rounded px-3 py-2">
                  <option value="">Personal Media</option>
                  <%= for channel <- @user_channels do %>
                    <option value={channel.id}><%= channel.name %></option>
                  <% end %>
                </select>
              </div>

              <div class="mb-4">
                <label class="block text-sm font-medium mb-1">Quality</label>
                <select name="quality" class="w-full border rounded px-3 py-2">
                  <option value="standard">Standard (MP3 256kbps)</option>
                  <%= if @user_tier in [:premium, :pro] do %>
                    <option value="high">High Quality (WAV 44.1kHz)</option>
                  <% end %>
                  <%= if @user_tier == :pro do %>
                    <option value="lossless">Lossless + Stems</option>
                  <% end %>
                </select>
              </div>

              <div class="flex justify-end space-x-3">
                <button type="button" onclick="closeExportModal()" class="px-4 py-2 text-gray-600">
                  Cancel
                </button>
                <button type="submit" class="px-4 py-2 bg-blue-600 text-white rounded">
                  Export
                </button>
              </div>
            </form>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
