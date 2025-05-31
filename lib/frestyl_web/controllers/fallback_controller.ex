# lib/frestyl_web/controllers/fallback_controller.ex
defmodule FrestylWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use FrestylWeb, :controller

  # This clause handles errors returned by Ecto's insert/update/delete.
  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: FrestylWeb.ChangesetJSON)
    |> render(:error, changeset: changeset)
  end

  # This clause is an example of how to handle resources that cannot be found.
  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(html: FrestylWeb.ErrorHTML, json: FrestylWeb.ErrorJSON)
    |> render(:"404")
  end

  # Handle unauthorized access
  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:unauthorized)
    |> json(%{success: false, error: "Unauthorized access"})
  end

  # Handle forbidden access
  def call(conn, {:error, :forbidden}) do
    conn
    |> put_status(:forbidden)
    |> json(%{success: false, error: "Access forbidden"})
  end

  # Handle validation errors
  def call(conn, {:error, :validation_failed, details}) do
    conn
    |> put_status(:bad_request)
    |> json(%{success: false, error: "Validation failed", details: details})
  end

  # Handle general errors with messages
  def call(conn, {:error, message}) when is_binary(message) do
    conn
    |> put_status(:bad_request)
    |> json(%{success: false, error: message})
  end

  # Handle unexpected errors
  def call(conn, {:error, reason}) do
    conn
    |> put_status(:internal_server_error)
    |> json(%{success: false, error: "Internal server error", details: inspect(reason)})
  end
end
