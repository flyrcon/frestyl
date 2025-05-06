# lib/frestyl_web/live/media_live/upload.ex
defmodule FrestylWeb.MediaLive.Upload do
  use FrestylWeb, :live_view

  alias Frestyl.Media
  alias Frestyl.Channels

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    user_channels = Channels.list_user_channels(user.id)

    {:ok,
     socket
     |> assign(:uploaded_files, [])
     |> assign(:user_channels, user_channels)
     |> assign(:selected_channel, nil)
     |> allow_upload(:media_files,
       accept: :any,
       max_entries: 10,
       max_file_size: 100_000_000, # 100MB
       auto_upload: true,
       progress: &handle_progress/3
     )}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("save", %{"channel" => channel_id}, socket) do
    user = socket.assigns.current_user

    channel = if channel_id != "", do: Channels.get_channel!(channel_id), else: nil

    uploaded_files =
      consume_uploaded_entries(socket, :media_files, fn %{path: path}, entry ->
        # Create media file record
        case Media.create_file(%{
          filename: entry.client_name,
          content_type: entry.client_type,
          file_size: entry.client_size,
          user_id: user.id,
          channel_id: channel && channel.id,
          file_path: path
        }, path) do
          {:ok, file} -> {:ok, file}
          {:error, reason} -> {:postpone, reason}
        end
      end)

    uploaded_count = length(uploaded_files)

    destination = if channel, do: ~p"/channels/#{channel}", else: ~p"/media"

    {:noreply,
     socket
     |> put_flash(:info, "Successfully uploaded #{uploaded_count} file(s)")
     |> push_navigate(to: destination)}
  end

  @impl true
  def handle_event("change-channel", %{"channel" => channel_id}, socket) do
    selected_channel = if channel_id != "", do: channel_id, else: nil
    {:noreply, assign(socket, selected_channel: selected_channel)}
  end

  @impl true
  def handle_event("remove-entry", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :media_files, ref)}
  end

  defp handle_progress(:media_files, entry, socket) do
    if entry.done? do
      case Media.process_upload(entry, socket.assigns.current_user) do
        {:ok, file} ->
          {:noreply, update(socket, :uploaded_files, &[file | &1])}
        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Failed to process #{entry.client_name}: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  # Now let's add the helper functions properly
  def format_bytes(bytes) when is_number(bytes) do
    cond do
      bytes >= 1_000_000_000 -> "#{Float.round(bytes / 1_000_000_000, 1)} GB"
      bytes >= 1_000_000 -> "#{Float.round(bytes / 1_000_000, 1)} MB"
      bytes >= 1_000 -> "#{Float.round(bytes / 1_000, 1)} KB"
      true -> "#{bytes} B"
    end
  end

  def error_to_string(:too_large), do: "File is too large"
  def error_to_string(:not_accepted), do: "File type not accepted"
  def error_to_string(:too_many_files), do: "Too many files"
  def error_to_string(_), do: "Unknown error"
end
