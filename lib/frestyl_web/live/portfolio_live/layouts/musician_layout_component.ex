# lib/frestyl_web/live/portfolio_live/layouts/musician_layout_component.ex

defmodule FrestylWeb.PortfolioLive.Layouts.MusicianLayoutComponent do
  @moduledoc """
  Playlist-style layout for musicians with audio showcase and discography
  """
  use FrestylWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="musician-portfolio bg-gradient-to-br from-purple-900 via-purple-800 to-indigo-900 min-h-screen text-white">
      <!-- Music player hero -->
      <section class="py-16">
        <div class="max-w-4xl mx-auto px-4 text-center">
          <h1 class="text-6xl font-bold mb-6"><%= @portfolio.title %></h1>
          <p class="text-xl text-purple-200 mb-8">Musician & Audio Creator</p>

          <!-- Featured track player -->
          <div class="bg-black bg-opacity-30 rounded-xl p-8 backdrop-blur-sm">
            <h3 class="text-2xl font-semibold mb-4">Latest Release</h3>
            <!-- Music player interface would go here -->
            <div class="bg-gray-800 rounded-lg p-4 flex items-center space-x-4">
              <button class="w-12 h-12 bg-white text-purple-900 rounded-full flex items-center justify-center">
                ▶
              </button>
              <div class="flex-1">
                <div class="text-left">
                  <div class="font-semibold">Track Title</div>
                  <div class="text-purple-200 text-sm">Album Name</div>
                </div>
              </div>
              <div class="text-purple-200 text-sm">3:45</div>
            </div>
          </div>
        </div>
      </section>

      <!-- Discography playlist -->
      <section class="py-12">
        <div class="max-w-4xl mx-auto px-4">
          <h2 class="text-3xl font-bold mb-8 text-center">Discography</h2>
          <div class="space-y-2">
            <%= for i <- 1..8 do %>
              <div class="bg-black bg-opacity-20 rounded-lg p-4 flex items-center space-x-4 hover:bg-opacity-40 transition-all cursor-pointer">
                <div class="w-12 h-12 bg-purple-600 rounded flex items-center justify-center text-white font-bold">
                  <%= i %>
                </div>
                <div class="flex-1">
                  <div class="font-semibold">Track Title <%= i %></div>
                  <div class="text-purple-200 text-sm">Album Name • 2023</div>
                </div>
                <div class="text-purple-200 text-sm">3:45</div>
                <button class="w-8 h-8 text-purple-200 hover:text-white">
                  ▶
                </button>
              </div>
            <% end %>
          </div>
        </div>
      </section>
    </div>
    """
  end
end
