# lib/frestyl_web/controllers/api/media_controller.ex
defmodule FrestylWeb.Api.MediaController do
  use FrestylWeb, :controller
  alias Frestyl.Media
  alias Frestyl.Accounts

  action_fallback FrestylWeb.FallbackController

  def discover(conn, params) do
    user = get_current_user(conn)
    filters = extract_filters(params)
    page = String.to_integer(params["page"] || "1")
    per_page = min(String.to_integer(params["per_page"] || "20"), 100)

    user_id = if user, do: user.id, else: nil

    case Media.list_intelligent_groups(user_id, filters, page: page, per_page: per_page) do
      {groups, total_count} ->
        json(conn, %{
          success: true,
          data: %{
            groups: groups,
            pagination: %{
              page: page,
              per_page: per_page,
              total_count: total_count,
              has_more: total_count > (page * per_page)
            }
          }
        })

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{success: false, error: reason})
    end
  end

  def show(conn, %{"id" => id}) do
    user = get_current_user(conn)

    case Media.get_media_file(id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{success: false, error: "Media file not found"})

      media_file ->
        # Record view if user is present
        if user do
          Media.record_view(media_file.id, user.id)
        end

        json(conn, %{
          success: true,
          data: media_file
        })
    end
  end

  def react(conn, %{"id" => media_file_id, "reaction_type" => reaction_type}) do
    user = get_current_user(conn)

    case user do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{success: false, error: "Authentication required"})

      user ->
        theme = get_user_theme(user)

        case Media.add_reaction(media_file_id, user.id, reaction_type, theme) do
          {:ok, reaction} ->
            json(conn, %{
              success: true,
              data: reaction
            })

          {:error, changeset} ->
            conn
            |> put_status(:bad_request)
            |> json(%{
              success: false,
              error: "Failed to add reaction",
              details: format_changeset_errors(changeset)
            })
        end
    end
  end

  # Private helper functions
  defp get_current_user(conn) do
    # For now, return nil to avoid authentication issues
    # You can implement proper user fetching once your User schema is stable
    case get_session(conn, :user_id) do
      nil -> nil
      user_id when is_integer(user_id) ->
        try do
          Frestyl.Repo.get(Frestyl.Accounts.User, user_id)
        rescue
          _ -> nil
        end
      _ -> nil
    end
  rescue
    _ -> nil
  end

  defp get_user_from_auth_header(_conn) do
    # Placeholder for future API token authentication
    nil
  end

  defp get_user_theme(user) do
    case Media.get_user_theme_preference(user.id) do
      %{current_theme: theme} -> theme
      _ -> "cosmic_dreams"
    end
  rescue
    _ -> "cosmic_dreams"
  end

  defp extract_filters(params) do
    %{}
    |> maybe_add_filter("type", params["type"])
    |> maybe_add_filter("tag", params["tag"])
    |> maybe_add_filter("genre", params["genre"])
    |> maybe_add_filter("mood", params["mood"])
    |> maybe_add_filter("energy_min", params["energy_min"])
    |> maybe_add_filter("energy_max", params["energy_max"])
    |> maybe_add_filter("duration_min", params["duration_min"])
    |> maybe_add_filter("duration_max", params["duration_max"])
    |> maybe_add_filter("date_from", params["date_from"])
    |> maybe_add_filter("date_to", params["date_to"])
  end

  defp maybe_add_filter(filters, _key, nil), do: filters
  defp maybe_add_filter(filters, _key, ""), do: filters
  defp maybe_add_filter(filters, key, value), do: Map.put(filters, key, value)

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
