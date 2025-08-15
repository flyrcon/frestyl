# Enhanced Demo Setup with Better IDs
# File: lib/frestyl/demo_enhanced.ex
defmodule Frestyl.DemoEnhanced do
  @doc """
  Create demo and return the actual IDs for navigation.
  """
  def setup_with_ids do
    IO.puts("🚀 Setting up demo with trackable IDs...")

    result = Frestyl.Demo.create()

    case result do
      %{status: :success} = demo_data ->
        # Get the actual IDs we can use for navigation
        ids = %{
          user_id: List.first(demo_data.users).id,
          team_id: demo_data.team.id,
          channel_id: 1 # Mock for now
        }

        IO.puts("\n🎯 Demo URLs you can access:")
        IO.puts("Vibe Rating: http://localhost:4000/demo/vibe-rating")
        IO.puts("Supervisor Dashboard: http://localhost:4000/demo/supervisor/#{ids.user_id}")
        IO.puts("Team Management: http://localhost:4000/demo/teams/#{ids.channel_id}")
        IO.puts("Demo Home: http://localhost:4000/demo")

        Map.merge(demo_data, %{navigation_ids: ids})

      error ->
        IO.puts("❌ Setup failed: #{inspect(error)}")
        error
    end
  end
end
