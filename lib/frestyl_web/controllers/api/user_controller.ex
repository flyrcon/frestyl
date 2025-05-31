# lib/frestyl_web/controllers/api/user_controller.ex
defmodule FrestylWeb.Api.UserController do
  use FrestylWeb, :controller
  alias Frestyl.Media
  alias Frestyl.Accounts

  action_fallback FrestylWeb.FallbackController

  def get_theme(conn, _params) do
    case get_current_user(conn) do
      nil ->
        json(conn, %{
          success: true,
          data: %{
            theme: "cosmic_dreams",
            is_guest: true
          }
        })

      user ->
        theme_preference = Media.get_user_theme_preference(user.id)

        json(conn, %{
          success: true,
          data: %{
            theme: theme_preference.current_theme || "cosmic_dreams",
            theme_history: theme_preference.theme_history || [],
            switch_count: theme_preference.switch_count || 0,
            is_guest: false
          }
        })
    end
  end

  def set_theme(conn, %{"theme" => theme}) do
    case get_current_user(conn) do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{success: false, error: "Authentication required"})

      user ->
        case Media.update_user_theme_preference(user, theme) do
          {:ok, theme_preference} ->
            json(conn, %{
              success: true,
              data: %{
                theme: theme_preference.current_theme,
                theme_history: theme_preference.theme_history,
                switch_count: theme_preference.switch_count
              }
            })

          {:error, changeset} ->
            conn
            |> put_status(:bad_request)
            |> json(%{
              success: false,
              error: "Failed to update theme",
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

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
