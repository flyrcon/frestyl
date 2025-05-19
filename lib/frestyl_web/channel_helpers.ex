defmodule FrestylWeb.ChannelHelpers do
  @moduledoc """
  Helper functions for channel-related views and live views.
  """

  @doc """
  Checks if a user with the given role can edit a channel.
  """
  def can_edit_channel?(user_role) do
    # Implement your permission logic here
    # Example implementation:
    user_role in [:admin, :owner, :manager]
  end

  @doc """
  Checks if a user with the given role can create a broadcast.
  """
  def can_create_broadcast?(user_role) do
    # Implement your permission logic here
    # Example implementation:
    user_role in [:admin, :owner, :manager, :content_creator]
  end

  @doc """
  Checks if a user with the given role can create a session.
  """
  def can_create_session?(user_role) do
    # Implement your permission logic here
    # Example implementation:
    user_role in [:admin, :owner, :manager, :content_creator]
  end

  @doc """
  Formats error messages from a changeset.
  """
  def error_message(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {k, v} -> "#{k}: #{Enum.join(v, ", ")}" end)
    |> Enum.join("; ")
  end

  @doc """
  Formats a datetime for display in channel context.
  """
  def format_channel_datetime(datetime) do
    # Implement your datetime formatting logic
    # Example implementation (adjust the format as needed):
    Calendar.strftime(datetime, "%B %d, %Y at %I:%M %p")
  end

  @doc """
  Returns a human-readable relative time string.
  """
  def time_ago(datetime) do
    # Implement time-ago logic
    # Example implementation (adjust based on your needs):
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)} minutes ago"
      diff < 86400 -> "#{div(diff, 3600)} hours ago"
      diff < 2_592_000 -> "#{div(diff, 86400)} days ago"
      diff < 31_536_000 -> "#{div(diff, 2_592_000)} months ago"
      true -> "#{div(diff, 31_536_000)} years ago"
    end
  end
end
