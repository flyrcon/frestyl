# lib/frestyl_web/controllers/api/editing_controller.ex
defmodule FrestylWeb.Api.EditingController do
  use FrestylWeb, :controller

  alias Frestyl.ContentEditing

  def get_project_state(conn, %{"project_id" => project_id}) do
    case ContentEditing.get_project_state(project_id) do
      {:ok, state} ->
        json(conn, %{status: "success", data: state})
      {:error, reason} ->
        conn
        |> put_status(:not_found)
        |> json(%{status: "error", error: to_string(reason)})
    end
  end

  def apply_operation(conn, %{"project_id" => project_id, "operation" => operation}) do
    user = conn.assigns.current_user

    case ContentEditing.handle_collaboration_operation(project_id, operation, user) do
      {:ok, result} ->
        json(conn, %{status: "success", data: result})
      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{status: "error", error: to_string(reason)})
    end
  end

  def get_render_status(conn, %{"project_id" => project_id, "job_id" => job_id}) do
    case ContentEditing.get_render_job_status(job_id) do
      {:ok, status} ->
        json(conn, %{status: "success", data: status})
      {:error, reason} ->
        conn
        |> put_status(:not_found)
        |> json(%{status: "error", error: to_string(reason)})
    end
  end

  def export_project(conn, %{"project_id" => project_id} = params) do
    user = conn.assigns.current_user
    export_format = Map.get(params, "format", "json")

    case ContentEditing.export_project(project_id, user, export_format) do
      {:ok, export_data} ->
        json(conn, %{status: "success", data: export_data})
      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{status: "error", error: to_string(reason)})
    end
  end
end
