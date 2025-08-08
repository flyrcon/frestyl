# lib/frestyl_web/live/helpers/error_helpers.ex
defmodule FrestylWeb.Live.Helpers.ErrorHelpers do
  @moduledoc """
  Error handling helpers for LiveViews.
  """

  def safe_assign(socket, key, value_fn) when is_function(value_fn, 0) do
    try do
      Phoenix.LiveView.assign(socket, key, value_fn.())
    rescue
      error ->
        require Logger
        Logger.error("Error in safe_assign for #{key}: #{inspect(error)}")
        Phoenix.LiveView.assign(socket, key, nil)
    end
  end

  def safe_assign(socket, key, value) do
    Phoenix.LiveView.assign(socket, key, value)
  end

  def handle_error(socket, error, context \\ "") do
    require Logger
    Logger.error("LiveView error #{context}: #{inspect(error)}")

    Phoenix.LiveView.put_flash(socket, :error, "Something went wrong. Please try again.")
  end

  def with_error_handling(socket, fun) when is_function(fun, 1) do
    try do
      fun.(socket)
    rescue
      error ->
        handle_error(socket, error)
    end
  end
end
