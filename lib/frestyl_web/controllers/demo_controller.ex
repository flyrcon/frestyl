# Simple Demo Controller - Fixed Template Issues
# File: lib/frestyl_web/controllers/demo_controller.ex

defmodule FrestylWeb.DemoController do
  use FrestylWeb, :controller

  def index(conn, _params) do
    # Get demo status
    demo_info = get_demo_info()

    # Get CSRF token safely
    csrf_token = case conn.assigns[:csrf_token] do
      nil -> get_demo_csrf_token()
      token -> token
    end

    # Return simple HTML directly instead of using templates
    html(conn, """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Freestyle Demo</title>
        <script src="https://cdn.tailwindcss.com"></script>
        <meta name="csrf-token" content="#{csrf_token}">
    </head>
    <body class="bg-gray-50">
        <div class="min-h-screen py-12">
            <div class="max-w-4xl mx-auto px-4">
                <div class="text-center mb-12">
                    <h1 class="text-4xl font-bold text-gray-900 mb-4">
                        Team Collaboration Demo
                    </h1>
                    <p class="text-xl text-gray-600">
                        Visual vibe ratings, real-time supervision, and intelligent intervention systems
                    </p>
                </div>

                #{render_demo_status(demo_info)}
                #{render_demo_links(demo_info)}
            </div>
        </div>

        <script>
            // Get CSRF token from meta tag
            function getCSRFToken() {
                const meta = document.querySelector('meta[name="csrf-token"]');
                return meta ? meta.content : '';
            }

            async function setupDemoData() {
                const button = event.target;
                button.innerHTML = '⏳ Creating...';
                button.disabled = true;

                try {
                    const response = await fetch('/demo/setup', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json',
                            'X-CSRF-Token': getCSRFToken()
                        }
                    });

                    const data = await response.json();

                    if (data.success) {
                        window.location.reload();
                    } else {
                        alert('Setup failed: ' + (data.error || 'Unknown error'));
                        button.innerHTML = '🚀 Create Demo Data';
                        button.disabled = false;
                    }
                } catch (error) {
                    alert('Setup failed: ' + error.message);
                    button.innerHTML = '🚀 Create Demo Data';
                    button.disabled = false;
                }
            }

            async function resetDemoData() {
                if (!confirm('Reset all demo data?')) return;

                const button = event.target;
                button.innerHTML = '⏳ Resetting...';
                button.disabled = true;

                try {
                    const response = await fetch('/demo/reset', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json',
                            'X-CSRF-Token': getCSRFToken()
                        }
                    });

                    const data = await response.json();

                    if (data.success) {
                        window.location.reload();
                    } else {
                        alert('Reset failed: ' + (data.error || 'Unknown error'));
                        button.innerHTML = '🗑️ Reset Data';
                        button.disabled = false;
                    }
                } catch (error) {
                    alert('Reset failed: ' + error.message);
                    button.innerHTML = '🗑️ Reset Data';
                    button.disabled = false;
                }
            }
        </script>
    </body>
    </html>
    """)
  end

  def setup_data(conn, _params) do
    case Frestyl.Demo.create() do
      %{status: :success} = demo_data ->
        json(conn, %{
          success: true,
          message: "Demo data created!",
          team: demo_data.team.name,
          members: length(demo_data.users),
          sentiment: demo_data.sentiment.score
        })

      %{status: :error, error: error} ->
        json(conn, %{
          success: false,
          error: "Setup failed: #{inspect(error)}"
        })
    end
  end

  def reset_data(conn, _params) do
    try do
      Frestyl.DemoSimple.clean_demo_data()

      json(conn, %{
        success: true,
        message: "Demo data reset successfully"
      })
    rescue
      error ->
        json(conn, %{
          success: false,
          error: "Reset failed: #{inspect(error)}"
        })
    end
  end

  # Helper functions

  defp get_demo_csrf_token do
    try do
      # Try different approaches to get CSRF token
      cond do
        function_exported?(Plug.CSRFProtection, :get_csrf_token, 0) ->
          Plug.CSRFProtection.get_csrf_token()

        function_exported?(Phoenix.Controller, :get_csrf_token, 0) ->
          Phoenix.Controller.get_csrf_token()

        true ->
          "demo-csrf-token" # Fallback token for demo purposes
      end
    rescue
      _ -> "demo-csrf-token"
    end
  end

  defp get_demo_info do
    try do
      demo_data = Frestyl.Demo.create()

      case demo_data do
        %{status: :success, users: users, team: team, sentiment: sentiment} ->
          %{
            has_data: true,
            user_id: List.first(users).id,
            team_id: team.id,
            team_name: team.name,
            member_count: length(users),
            sentiment_score: sentiment.score,
            sentiment_color: sentiment.color
          }

        _ ->
          %{has_data: false}
      end
    rescue
      _ ->
        %{has_data: false}
    end
  end

  defp render_demo_status(%{has_data: true} = demo_info) do
    """
    <div class="bg-white rounded-xl shadow-lg p-6 mb-8">
        <div class="flex items-center text-green-600 mb-4">
            <svg class="w-6 h-6 mr-3" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
            </svg>
            <span class="text-lg font-semibold">Demo Data Active</span>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
            <div class="bg-blue-50 p-4 rounded-lg">
                <p class="font-medium text-blue-900">Team</p>
                <p class="text-blue-700">#{demo_info.team_name}</p>
            </div>
            <div class="bg-green-50 p-4 rounded-lg">
                <p class="font-medium text-green-900">Members</p>
                <p class="text-green-700">#{demo_info.member_count} users</p>
            </div>
            <div class="bg-purple-50 p-4 rounded-lg">
                <p class="font-medium text-purple-900">Sentiment</p>
                <p class="text-purple-700">#{demo_info.sentiment_score}/100</p>
            </div>
        </div>

        <div class="flex space-x-3">
            <button onclick="resetDemoData()"
                    class="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700">
                🗑️ Reset Data
            </button>
        </div>
    </div>
    """
  end

  defp render_demo_status(%{has_data: false}) do
    """
    <div class="bg-white rounded-xl shadow-lg p-6 mb-8">
        <div class="text-center">
            <h3 class="text-lg font-semibold text-gray-900 mb-4">Setup Required</h3>
            <p class="text-gray-600 mb-6">Create demo data to enable all features</p>

            <button onclick="setupDemoData()"
                    class="px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 font-medium">
                🚀 Create Demo Data
            </button>
        </div>
    </div>
    """
  end

  defp render_demo_links(%{has_data: true} = demo_info) do
    """
    <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
            <h3 class="text-lg font-semibold text-gray-900 mb-3">🎨 Vibe Rating Widget</h3>
            <p class="text-gray-600 mb-4 text-sm">Test the color-gradient rating interface</p>
            <a href="/demo/vibe-rating"
               class="inline-flex items-center px-4 py-2 bg-gray-900 text-white rounded-lg hover:bg-gray-800 text-sm font-medium">
                Open Demo
                <svg class="w-4 h-4 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
                </svg>
            </a>
        </div>

        <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
            <h3 class="text-lg font-semibold text-gray-900 mb-3">📊 Supervisor Dashboard</h3>
            <p class="text-gray-600 mb-4 text-sm">View team performance with real data</p>
            <a href="/demo/supervisor/#{demo_info.user_id}"
               class="inline-flex items-center px-4 py-2 bg-gray-900 text-white rounded-lg hover:bg-gray-800 text-sm font-medium">
                Open Demo
                <svg class="w-4 h-4 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
                </svg>
            </a>
        </div>

        <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
            <h3 class="text-lg font-semibold text-gray-900 mb-3">👥 Team Management</h3>
            <p class="text-gray-600 mb-4 text-sm">Manage team assignments</p>
            <a href="/demo/teams/1"
               class="inline-flex items-center px-4 py-2 bg-gray-900 text-white rounded-lg hover:bg-gray-800 text-sm font-medium">
                Open Demo
                <svg class="w-4 h-4 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
                </svg>
            </a>
        </div>
    </div>
    """
  end

  defp render_demo_links(%{has_data: false}) do
    """
    <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
            <h3 class="text-lg font-semibold text-gray-900 mb-3">🎨 Vibe Rating Widget</h3>
            <p class="text-gray-600 mb-4 text-sm">Test the color-gradient rating interface</p>
            <a href="/demo/vibe-rating"
               class="inline-flex items-center px-4 py-2 bg-gray-900 text-white rounded-lg hover:bg-gray-800 text-sm font-medium">
                Open Demo
                <svg class="w-4 h-4 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
                </svg>
            </a>
        </div>

        <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6 opacity-50">
            <h3 class="text-lg font-semibold text-gray-900 mb-3">📊 Supervisor Dashboard</h3>
            <p class="text-gray-600 mb-4 text-sm">Create demo data first</p>
            <div class="inline-flex items-center px-4 py-2 bg-gray-200 text-gray-500 rounded-lg text-sm font-medium cursor-not-allowed">
                Setup Required
            </div>
        </div>

        <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6 opacity-50">
            <h3 class="text-lg font-semibold text-gray-900 mb-3">👥 Team Management</h3>
            <p class="text-gray-600 mb-4 text-sm">Create demo data first</p>
            <div class="inline-flex items-center px-4 py-2 bg-gray-200 text-gray-500 rounded-lg text-sm font-medium cursor-not-allowed">
                Setup Required
            </div>
        </div>
    </div>
    """
  end
end

# Add these routes to your router.ex:
# File: lib/frestyl_web/router.ex (add to existing routes)

# scope "/demo", FrestylWeb do
#   pipe_through :browser
#
#   get "/", DemoController, :index
#   post "/setup", DemoController, :setup_data
#   post "/reset", DemoController, :reset_data
#
#   live "/vibe-rating", VibeRatingDemoLive, :index
#   live "/supervisor/:user_id", SupervisorDashboardLive, :index
#   live "/teams/:channel_id", ChannelTeamManagementLive, :index
# end
