# lib/frestyl_web/live/voice_sketch_live/session.ex
defmodule FrestylWeb.VoiceSketchLive.Session do
  use FrestylWeb, :live_view

    import FrestylWeb.Live.Helpers.CommonHelpers
  alias Frestyl.VoiceSketch
  alias Frestyl.Features.TierManager

  @impl true
  def mount(%{"id" => session_id}, session, socket) do
    current_user = get_current_user_from_session(session)

    # Check if user has access to Voice-Sketch
    user_tier = TierManager.get_user_tier(current_user)
    unless TierManager.has_tier_access?(user_tier, "professional") do
      {:ok, redirect(socket, to: ~p"/upgrade?feature=voice_sketch")}
    else
      voice_session = VoiceSketch.get_session_with_strokes(session_id)

      # Check permissions
      unless VoiceSketch.can_edit_session?(voice_session, current_user.id) do
        {:ok, redirect(socket, to: ~p"/voice-sketch")}
      else
        if connected?(socket) do
          Phoenix.PubSub.subscribe(Frestyl.PubSub, "voice_sketch:#{session_id}")
        end

        socket = socket
        |> assign(:current_user, current_user)
        |> assign(:session, voice_session)
        |> assign(:recording_state, "idle")  # idle, recording, playing
        |> assign(:current_tool, "pen")
        |> assign(:current_color, "#000000")
        |> assign(:current_stroke_width, 3.0)
        |> assign(:current_layer, "main")
        |> assign(:canvas_data, voice_session.canvas_data || %{})
        |> assign(:audio_position, 0)
        |> assign(:is_playing, false)
        |> assign(:collaborators_online, [])
        |> assign(:show_timeline, true)
        |> assign(:show_layers_panel, false)
        |> assign(:export_status, nil)

        {:ok, socket}
      end
    end
  end

  @impl true
  def handle_event("start_recording", _params, socket) do
    case VoiceSketch.start_recording(socket.assigns.session.id, socket.assigns.current_user.id) do
      {:ok, updated_session} ->
        {:noreply, socket
         |> assign(:session, updated_session)
         |> assign(:recording_state, "recording")
         |> push_event("start_voice_recording", %{})}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to start recording: #{reason}")}
    end
  end

  @impl true
  def handle_event("stop_recording", %{"recording_data" => recording_data}, socket) do
    case VoiceSketch.stop_recording(
      socket.assigns.session.id,
      socket.assigns.current_user.id,
      recording_data
    ) do
      {:ok, updated_session} ->
        {:noreply, socket
         |> assign(:session, updated_session)
         |> assign(:recording_state, "idle")
         |> push_event("stop_voice_recording", %{})}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to stop recording: #{reason}")}
    end
  end

  @impl true
  def handle_event("add_stroke", stroke_params, socket) do
    case VoiceSketch.add_stroke(
      socket.assigns.session.id,
      socket.assigns.current_user.id,
      stroke_params
    ) do
      {:ok, stroke} ->
        {:noreply, socket |> push_event("stroke_added", %{stroke: stroke})}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("update_tool", %{"tool" => tool}, socket) do
    {:noreply, assign(socket, :current_tool, tool)}
  end

  @impl true
  def handle_event("update_color", %{"color" => color}, socket) do
    {:noreply, assign(socket, :current_color, color)}
  end

  @impl true
  def handle_event("update_stroke_width", %{"width" => width}, socket) do
    {:noreply, assign(socket, :current_stroke_width, String.to_float(width))}
  end

  @impl true
  def handle_event("update_layer", %{"layer" => layer}, socket) do
    {:noreply, assign(socket, :current_layer, layer)}
  end

  @impl true
  def handle_event("add_sync_marker", marker_params, socket) do
    case VoiceSketch.add_sync_marker(
      socket.assigns.session.id,
      socket.assigns.current_user.id,
      marker_params
    ) do
      {:ok, updated_session} ->
        {:noreply, assign(socket, :session, updated_session)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to add sync marker: #{reason}")}
    end
  end

  @impl true
  def handle_event("export_session", export_options, socket) do
    case VoiceSketch.export_session(
      socket.assigns.session.id,
      socket.assigns.current_user.id,
      export_options
    ) do
      {:ok, updated_session} ->
        {:noreply, socket
         |> assign(:session, updated_session)
         |> assign(:export_status, "processing")
         |> push_event("export_started", %{})}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to start export: #{reason}")}
    end
  end

  @impl true
  def handle_event("toggle_timeline", _params, socket) do
    {:noreply, assign(socket, :show_timeline, !socket.assigns.show_timeline)}
  end

  @impl true
  def handle_event("toggle_layers_panel", _params, socket) do
    {:noreply, assign(socket, :show_layers_panel, !socket.assigns.show_layers_panel)}
  end

  @impl true
  def handle_event("audio_position_update", %{"position" => position}, socket) do
    {:noreply, assign(socket, :audio_position, position)}
  end

  # PubSub message handlers
  @impl true
  def handle_info({:stroke_added, stroke}, socket) do
    {:noreply, push_event(socket, "collaborator_stroke_added", %{stroke: stroke})}
  end

  @impl true
  def handle_info({:stroke_updated, stroke}, socket) do
    {:noreply, push_event(socket, "collaborator_stroke_updated", %{stroke: stroke})}
  end

  @impl true
  def handle_info({:stroke_deleted, stroke}, socket) do
    {:noreply, push_event(socket, "collaborator_stroke_deleted", %{stroke: stroke})}
  end

  @impl true
  def handle_info({:session_updated, updated_session}, socket) do
    {:noreply, assign(socket, :session, updated_session)}
  end

  @impl true
  def handle_info({:export_complete, export_url}, socket) do
    {:noreply, socket
     |> assign(:export_status, "complete")
     |> push_event("export_complete", %{url: export_url})}
  end

  @impl true
  def handle_info({:export_error, _error}, socket) do
    {:noreply, socket
     |> assign(:export_status, "error")
     |> put_flash(:error, "Export failed. Please try again.")}
  end

  # Helper functions
  defp get_current_user_from_session(session) do
    case session["user_token"] do
      nil -> nil
      token -> Frestyl.Accounts.get_user_by_session_token(token)
    end
  end

  defp tool_icon(tool) do
    case tool do
      "pen" -> "✏️"
      "brush" -> "🖌️"
      "eraser" -> "🧽"
      "highlighter" -> "🖍️"
      _ -> "✏️"
    end
  end

  defp format_time(milliseconds) when is_integer(milliseconds) do
    seconds = div(milliseconds, 1000)
    minutes = div(seconds, 60)
    remaining_seconds = rem(seconds, 60)

    "#{String.pad_leading(to_string(minutes), 2, "0")}:#{String.pad_leading(to_string(remaining_seconds), 2, "0")}"
  end

  defp format_time(_), do: "00:00"
end
