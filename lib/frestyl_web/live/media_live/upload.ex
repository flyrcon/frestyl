# lib/frestyl_web/live/media_live/upload.ex
# (No changes needed for the drag-and-drop functionality)

defmodule FrestylWeb.MediaLive.Upload do
  use FrestylWeb, :live_view

  alias Frestyl.Media
  alias Frestyl.Channels
  alias Frestyl.Media.FolderContext

  # Add this require at the top of your module
  require Logger

  @impl true
  def handle_event("validate", params, socket) do
    Logger.info("Validate event: #{inspect(params)}")
    {:noreply, socket}
  end

  @impl true
  def handle_event("compress-images", params, socket) do
    Logger.info("Compress images event: #{inspect(params)}")
    {:noreply, push_event(socket, "phx:compress-images", params)}
  end

  defp handle_progress(:media_files, entry, socket) do
    Logger.info("Upload progress: #{entry.client_name}, done: #{entry.done?}")

    if entry.done? do
      Logger.info("Upload complete for #{entry.client_name}")

      # Add the file to uploaded_files without further processing for now
      # This simplifies testing to isolate drag-and-drop issues
      {:noreply, update(socket, :uploaded_files, &[entry | &1])}
    else
      {:noreply, socket}
    end
  end

@impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    user_channels = Channels.list_user_channels(user.id)

    # Get user folders if the FolderContext module exists
    user_folders = if Code.ensure_loaded?(FolderContext) and
                     function_exported?(FolderContext, :list_user_folders, 1) do
      FolderContext.list_user_folders(user.id)
    else
      []
    end

    {:ok,
     socket
     |> assign(:uploaded_files, [])
     |> assign(:user_channels, user_channels)
     |> assign(:user_folders, user_folders)
     |> assign(:selected_channel, nil)
     |> allow_upload(:media_files,
       accept: :any,
       max_entries: 10,
       max_file_size: 100_000_000, # 100MB
       auto_upload: true, # LiveView automatically uploads when files are added
       progress: &handle_progress/3 # Callback for upload progress
     )}
  end

  # Keep your existing handle_event and handle_progress functions
  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("compress-images", %{"inputId" => input_id}, socket) do
    # This event is triggered by the JS hook after files are added
    # Push event back to client to trigger image compression JS if needed
    {:noreply, push_event(socket, "phx:compress-images", %{inputId: input_id})}
  end

  @impl true
  def handle_event("save", params, socket) do
    user = socket.assigns.current_user

    # Extract channel_id and folder_id safely
    channel_id = params["channel"] || ""
    folder_id = params["folder"] || ""

    channel = if channel_id != "", do: Channels.get_channel!(channel_id), else: nil

    # Get folder if FolderContext is available
    folder = if folder_id != "" and Code.ensure_loaded?(FolderContext) and
               function_exported?(FolderContext, :get_folder!, 1) do
      FolderContext.get_folder!(folder_id)
    else
      nil
    end

    # Consume uploaded entries - This processes the files LiveView has finished uploading
    uploaded_files =
      consume_uploaded_entries(socket, :media_files, fn %{path: path}, entry ->
        # Create media file record in your database
        case Media.create_file(%{
          filename: entry.client_name,
          original_filename: entry.client_name,
          content_type: entry.client_type,
          file_size: entry.client_size,
          user_id: user.id,
          channel_id: channel && channel.id,
          folder_id: folder && folder.id
        }, path) do
          {:ok, file} -> {:ok, file} # Return {:ok, value} for success
          {:error, reason} -> {:postpone, reason} # Use {:postpone, reason} to retry or handle error later
        end
      end)

    uploaded_count = length(uploaded_files)

    # Determine redirect destination based on context
    destination = cond do
      channel -> ~p"/channels/#{channel}"
      folder -> ~p"/media/folders/#{folder}"
      true -> ~p"/media"
    end

    # Redirect after processing files
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
    # Cancel the upload entry by its reference
    {:noreply, cancel_upload(socket, :media_files, ref)}
  end

  # Callback for upload progress updates
  defp handle_progress(:media_files, entry, socket) do
     # You can use this to update the UI with progress bars (client-side push)
     # or perform actions when an individual file upload is done?
     # Your current implementation seems to handle processing when entry.done?
     # This is fine, but often final processing is done in handle_event("save").
     # Ensure Media.process_upload is needed/correct here vs in handle_event("save").

    if entry.done? do
      Logger.info("File upload finished for #{entry.client_name}. Processing...")
      # Example: Process the file data after it's fully uploaded
      case Media.process_upload(entry, socket.assigns.current_user) do
        {:ok, file} ->
           Logger.info("Processing successful for #{entry.client_name}.")
           # Optional: Update a list of *successfully processed* files
           {:noreply, update(socket, :uploaded_files, &[file | &1])}
        {:error, reason} ->
           Logger.error("Processing failed for #{entry.client_name}: #{inspect(reason)}")
           # Handle processing failure (e.g., show error next to file entry in UI)
           # You might update the entry status or add an error message to the assigns
           {:noreply, put_flash(socket, :error, "Failed to process #{entry.client_name}: #{inspect(reason)}") } # Flash message might not be ideal per file
      end
    else
       # Update progress for the entry in assigns if you have progress bars in the UI
       # Example: {:noreply, update_progress_assign(socket, :media_files, entry)}
       # This would require updating a data structure in socket.assigns that tracks progress per entry ref
       {:noreply, socket}
    end
  end

  # Helper functions (keep as is)
  def format_bytes(bytes) when is_number(bytes) do
    # ... your existing format_bytes function ...
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
  def error_to_string(reason), do: "Upload error: #{inspect(reason)}" # Added inspect for unknown reasons
end
