defmodule FrestylWeb.UserLive.Profile do
  use FrestylWeb, :live_view

  alias Frestyl.Accounts

  @impl true
  def mount(_params, %{"user_token" => user_token}, socket) do
    user = Accounts.get_user_by_session_token(user_token)

    changeset = Accounts.change_user_profile(user)

    # Try to get user metrics, with fallbacks for missing data
    user_metrics = try do
      Accounts.get_user_metrics(user.id)
    rescue
      _ -> default_metrics()
    end

    # Default to 50th percentile if percentile data not available
    user_percentile = try do
      Accounts.get_user_activity_percentile(user.id)
    rescue
      _ -> 50
    end
      # Determine user engagement level
    engagement_level = calculate_engagement_level(user_metrics)

    # Track user presence
    if connected?(socket) do
      try do
        FrestylWeb.Presence.track_user(
          self(),
          "users:presence",
          user.id
        )
        Phoenix.PubSub.subscribe(Frestyl.PubSub, "users:presence")
      rescue
        e ->
          require Logger
          Logger.error("Error with Presence: #{inspect(e)}")
      end
    end

    # Safely get online users
    online_users = try do
      FrestylWeb.Presence.list_users_online("users:presence")
    rescue
      _ -> []
    end

    socket =
      socket
      |> assign(:page_title, "My Profile")
      |> assign(:user, user)
      |> assign(:online_users, online_users)
      |> assign(:changeset, changeset)
      |> assign(:username_status, :initial)
      |> assign(:user_metrics, user_metrics)
      |> assign(:user_percentile, user_percentile)
      |> assign(:engagement_level, engagement_level)
      |> allow_upload(:media,
          accept: ~w(.jpg .jpeg .png .gif .mp4 .mov .webm .mp3 .wav .ogg),
          max_entries: 1,
          max_file_size: 50_000_000) # 50MB

    {:ok, socket}
  end

  @impl true
  def handle_event("check_username", %{"value" => username}, socket) do
    validate_username(username, socket)
  end

  @impl true
  def handle_event("validate_username", %{"value" => username}, socket) do
    validate_username(username, socket)
  end

  defp validate_username(username, socket) do
    # Skip check if username is unchanged
    if username == socket.assigns.user.username do
      {:noreply, assign(socket, :username_status, :initial)}
    else
      # Validate format first
      status = cond do
        String.length(username) < 3 ->
          :too_short
        !Regex.match?(~r/^[a-zA-Z0-9_-]+$/, username) ->
          :invalid
        Accounts.username_available?(username) ->
          :available
        true ->
          :taken
      end

      {:noreply, assign(socket, :username_status, status)}
    end
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("save_profile", %{"user" => user_params}, socket) do
    {user_params, socket} = handle_media_uploads(user_params, socket)

    case Accounts.update_profile(socket.assigns.user, user_params) do
      {:ok, user} ->
        socket =
          socket
          |> assign(:user, user)
          |> assign(:changeset, Accounts.change_user_profile(user))
          |> put_flash(:info, "Profile updated successfully")

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  # Unified media upload handling
  defp handle_media_uploads(user_params, socket) do
    # Process the unified media upload
    case uploaded_entries(socket, :media) do
      {[entry], _} ->
        # Generate a unique filename
        ext = Path.extname(entry.client_name)
        content_type = entry.client_type

        # Determine the type of media based on content type
        media_type = cond do
          String.starts_with?(content_type, "image/") -> :avatar
          String.starts_with?(content_type, "video/") -> :video
          String.starts_with?(content_type, "audio/") -> :audio
          true -> :avatar # Default to avatar if content type is unclear
        end

        filename = "#{media_type}_#{socket.assigns.user.id}_#{:rand.uniform(1000)}#{ext}"

        # Get file upload directory from config or use a default
        upload_dir = Application.get_env(:frestyl, :upload_directory, "priv/static/uploads")

        # Create full path
        dest = Path.join(upload_dir, filename)

        # Make sure directory exists
        File.mkdir_p!(Path.dirname(dest))

        # Copy the file to destination
        File.cp!(entry.path, dest)

        # Return updated user_params based on media type
        file_url = "/uploads/#{filename}"
        case media_type do
          :avatar -> Map.put(user_params, "avatar_url", file_url)
          :video -> Map.put(user_params, "profile_video_url", file_url)
          :audio -> Map.put(user_params, "profile_audio_url", file_url)
        end

      _ ->
        user_params
    end

    {user_params, socket}
  end

  @impl true
  def handle_event("remove_avatar", _params, socket) do
    case Accounts.update_profile(socket.assigns.user, %{avatar_url: nil}) do
      {:ok, user} ->
        socket =
          socket
          |> assign(:user, user)
          |> assign(:changeset, Accounts.change_user_profile(user))
          |> put_flash(:info, "Profile photo removed")

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  @impl true
  def handle_event("remove_video", _params, socket) do
    case Accounts.update_profile(socket.assigns.user, %{profile_video_url: nil}) do
      {:ok, user} ->
        socket =
          socket
          |> assign(:user, user)
          |> assign(:changeset, Accounts.change_user_profile(user))
          |> put_flash(:info, "Profile video removed")

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  @impl true
  def handle_event("remove_audio", _params, socket) do
    case Accounts.update_profile(socket.assigns.user, %{profile_audio_url: nil}) do
      {:ok, user} ->
        socket =
          socket
          |> assign(:user, user)
          |> assign(:changeset, Accounts.change_user_profile(user))
          |> put_flash(:info, "Profile audio removed")

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

    @impl true
  def handle_event("view_detailed_metrics", _params, socket) do
    # Could add logic here to track that the user clicked on the metrics
    {:noreply, socket}
  end

  # Helper function to provide default metrics if real data not available
  defp default_metrics do
    %{
      hours_consumed: 0,
      total_engagements: 0,
      content_hours_created: 0,
      days_active: 1,
      unique_channels_visited: 0,
      comments_posted: 0,
      likes_given: 0,
      events_attended: 0
    }
  end

  # Helper to calculate engagement level based on user metrics
  defp calculate_engagement_level(metrics) do
    # Return a default if metrics is nil or not a map
    unless is_map(metrics) do
      # Using explicit return value instead of 'return' keyword
      %{name: "Getting Started", color: "blue", score: 10}
    else
      # Extract metrics with defaults for missing values
      hours_consumed = Map.get(metrics, :hours_consumed, 0)
      total_engagements = Map.get(metrics, :total_engagements, 0)
      content_hours_created = Map.get(metrics, :content_hours_created, 0)

      # Base score starts at 10
      base_score = 10

      # Add points based on content consumed (1 point per 5 hours)
      content_score = (hours_consumed / 5) |> floor()

      # Add points based on engagement (1 point per 10 engagements)
      engagement_score = (total_engagements / 10) |> floor()

      # Add points based on content created if applicable
      creation_score = (content_hours_created * 2) |> floor()

      # Calculate total score
      total_score = base_score + content_score + engagement_score + creation_score

      # Determine level
      cond do
        total_score >= 100 -> %{name: "On Fire! 🔥", color: "red", score: total_score}
        total_score >= 75 -> %{name: "Hot! 🔥", color: "orange", score: total_score}
        total_score >= 50 -> %{name: "Trending Up! 📈", color: "yellow", score: total_score}
        total_score >= 25 -> %{name: "Active 👍", color: "green", score: total_score}
        true -> %{name: "Getting Started", color: "blue", score: total_score}
      end
    end
  end

  # Helper to get the appropriate heat color based on score
  defp get_heat_color(score) when is_integer(score) or is_float(score) do
    cond do
      score >= 100 -> "background-color: #ef4444;" # Red (very hot)
      score >= 75 -> "background-color: #ec4899;"  # Hot pink
      score >= 50 -> "background-color: #8b5cf6;"  # Purple
      score >= 25 -> "background-color: #6366f1;"  # Indigo
      true -> "background-color: #3b82f6;"         # Blue (cool)
    end
  end
  defp get_heat_color(_), do: "background-color: #3b82f6;" # Default blue for invalid scores

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    # Update list of online users when presence changes
    online_users = FrestylWeb.Presence.list_users_online("users:presence")
    {:noreply, assign(socket, :online_users, online_users)}
  end

  defp error_to_string(:too_large), do: "File is too large"
  defp error_to_string(:too_many_files), do: "You've selected too many files"
  defp error_to_string(:not_accepted), do: "You've selected an unacceptable file type"
  defp error_to_string(err), do: "Error: #{inspect(err)}"
end
