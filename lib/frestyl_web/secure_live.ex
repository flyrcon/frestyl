defmodule FrestylWeb.SecureLive do
  @moduledoc """
  Base module for secure LiveViews that require authentication.
  """

  defmacro __using__(opts) do
    quote do
      use FrestylWeb, :live_view
      import FrestylWeb.AuthHelpers

      @auth_required Keyword.get(unquote(opts), :auth, true)
      @role_required Keyword.get(unquote(opts), :role, nil)

      @impl true
      def mount(_params, session, socket) do
        socket = assign_current_user(socket, session)

        cond do
          @auth_required and is_nil(socket.assigns[:current_user]) ->
            {:ok,
             socket
             |> put_flash(:error, "Please log in to continue.")
             |> redirect(to: "/login")}

          @role_required and not authorized_role?(socket.assigns.current_user, @role_required) ->
            {:ok,
             socket
             |> put_flash(:error, "Access denied.")
             |> redirect(to: "/dashboard")}

          true ->
            {:ok, socket}
        end
      end

      defp assign_current_user(socket, session) do
        case session["current_user_id"] do
          nil -> assign(socket, :current_user, nil)
          user_id ->
            user = Frestyl.Accounts.get_user!(user_id)
            assign(socket, :current_user, user)
        end
      end

      defp authorized_role?(user, required_role) do
        case {user, required_role} do
          {nil, _} -> false
          {%{role: :admin}, _} -> true  # Admin can access everything
          {%{role: user_role}, required_role} when is_atom(required_role) ->
            user_role == required_role
          {%{role: user_role}, required_roles} when is_list(required_roles) ->
            user_role in required_roles
          _ -> false
        end
      end
    end
  end
end
