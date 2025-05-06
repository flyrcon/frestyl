defmodule FrestylWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, components, channels, and so on.

  This can be used in your application as:

      use FrestylWeb, :controller
      use FrestylWeb, :html

  The definitions below will be executed for every controller,
  component, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define additional modules and import
  those modules here.
  """

  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

  def router do
    quote do
      use Phoenix.Router, helpers: false

      # Import common connection and controller functions to use in pipelines
      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  def controller do
    quote do
      use Phoenix.Controller,
        formats: [:html, :json],
        layouts: [html: FrestylWeb.Layouts]

      use Gettext, backend: FrestylWeb.Gettext

      import Plug.Conn

      unquote(verified_routes())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {FrestylWeb.Layouts, :app}

      unquote(html_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      import Phoenix.HTML
      import Phoenix.HTML.Form

      # Include general helpers for rendering HTML
      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      # Translation
      use Gettext, backend: FrestylWeb.Gettext

      # HTML escaping functionality
      import Phoenix.HTML
      # Core UI components
      import FrestylWeb.CoreComponents
      # Events
      import FrestylWeb.EventHelpers

      # Shortcut for generating JS commands
      alias Phoenix.LiveView.JS

      # Routes generation with the ~p sigil
      unquote(verified_routes())

      def format_bytes(bytes), do: Frestyl.Media.FileHelpers.format_bytes(bytes)

      def media_icon(type) do
        case type do
          "document" -> "hero-document-text"
          "audio" -> "hero-musical-note"
          "video" -> "hero-video-camera"
          "image" -> "hero-photo"
          _ -> "hero-document"
        end
      end

      def can_play_in_browser?(mime_type) do
        playable_types = [
          "audio/mpeg", "audio/mp3", "audio/wav", "audio/ogg",
          "video/mp4", "video/webm", "video/ogg"
        ]

        Enum.member?(playable_types, mime_type)
      end
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: FrestylWeb.Endpoint,
        router: FrestylWeb.Router,
        statics: FrestylWeb.static_paths()
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/live_view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
