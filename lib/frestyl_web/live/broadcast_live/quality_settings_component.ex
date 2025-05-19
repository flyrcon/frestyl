defmodule FrestylWeb.BroadcastLive.QualitySettingsComponent do
  use FrestylWeb, :live_component

  def mount(socket) do
    socket = assign(socket,
      current_quality: "auto",
      available_qualities: [
        %{id: "auto", name: "Auto", description: "Automatically adjust based on connection"},
        %{id: "low", name: "Low", description: "240p - Good for slow connections"},
        %{id: "medium", name: "Medium", description: "360p - Balanced quality"},
        %{id: "high", name: "High", description: "720p - Better video quality"},
        %{id: "hd", name: "HD", description: "1080p - Best video quality"},
        %{id: "ultra", name: "Ultra HD", description: "1440p - For high-end devices"}
      ],
      bandwidth_stats: nil,
      show_settings: false,
      audio_only: false,
      stats_visible: false
    )

    {:ok, socket}
  end

  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  def handle_event("toggle_settings", _, socket) do
    {:noreply, assign(socket, :show_settings, !socket.assigns.show_settings)}
  end

  def handle_event("set_quality", %{"quality" => quality}, socket) do
    # Send the quality change to the JS client via push_event
    {:noreply,
     socket
     |> assign(:current_quality, quality)
     |> push_event("set-stream-quality", %{quality: quality})}
  end

  def handle_event("toggle_audio_only", _, socket) do
    new_state = !socket.assigns.audio_only

    {:noreply,
     socket
     |> assign(:audio_only, new_state)
     |> push_event("set-audio-only", %{enabled: new_state})}
  end

  def handle_event("toggle_stats", _, socket) do
    {:noreply, assign(socket, :stats_visible, !socket.assigns.stats_visible)}
  end

  def handle_event("update_bandwidth_stats", %{"stats" => stats}, socket) do
    {:noreply, assign(socket, :bandwidth_stats, stats)}
  end

  def render(assigns) do
      ~H"""
      <div class="relative">
        <!-- Settings toggle button -->
        <button
          phx-click="toggle_settings"
          phx-target={@myself}
          class="flex items-center space-x-1 text-white bg-black bg-opacity-50 hover:bg-opacity-70 px-3 py-1.5 rounded-md text-sm transition-colors"
        >
          <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
          </svg>
          <span>Quality</span>
        </button>

        <!-- Settings dropdown -->
        <%= if @show_settings do %>
          <div
            class="absolute bottom-full right-0 mb-2 w-64 bg-gray-900 border border-gray-700 rounded-lg shadow-lg z-10"
            phx-click-away={JS.push("toggle_settings", target: @myself)}
          >
            <div class="p-3 border-b border-gray-800">
              <h3 class="text-sm font-medium text-white">Quality Settings</h3>
            </div>

            <div class="p-3">
              <div class="mb-4">
                <label class="block text-sm font-medium text-gray-300 mb-2">Video Quality</label>
                <div class="space-y-2">
                  <%= for quality <- @available_qualities do %>
                    <label class="flex items-center">
                      <input
                        type="radio"
                        name="quality"
                        value={quality.id}
                        checked={@current_quality == quality.id}
                        class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-600 bg-gray-700"
                        phx-click="set_quality"
                        phx-value-quality={quality.id}
                        phx-target={@myself}
                      />
                      <div class="ml-3">
                        <div class="text-sm text-white"><%= quality.name %></div>
                        <div class="text-xs text-gray-400"><%= quality.description %></div>
                      </div>
                    </label>
                  <% end %>
                </div>
              </div>

              <div class="border-t border-gray-800 pt-3">
                <label class="flex items-center justify-between">
                  <span class="text-sm font-medium text-gray-300">Audio Only Mode</span>
                  <label class="relative inline-flex items-center cursor-pointer">
                    <input
                      type="checkbox"
                      checked={@audio_only}
                      class="sr-only peer"
                      phx-click="toggle_audio_only"
                      phx-target={@myself}
                    />
                    <div class="w-9 h-5 bg-gray-700 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-0.5 after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:bg-indigo-600"></div>
                  </label>
                </label>
                <div class="text-xs text-gray-400 mt-1">Save bandwidth by disabling video</div>
              </div>

              <div class="border-t border-gray-800 pt-3 mt-3">
                <button
                  phx-click="toggle_stats"
                  phx-target={@myself}
                  class="text-sm text-gray-300 hover:text-white flex items-center"
                >
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
                  </svg>
                  <%= if @stats_visible, do: "Hide Connection Stats", else: "Show Connection Stats" %>
                </button>
              </div>

              <%= if @stats_visible && @bandwidth_stats do %>
                <div class="mt-3 p-2 bg-gray-800 rounded text-xs">
                  <div class="grid grid-cols-2 gap-2">
                    <div>
                      <div class="text-gray-400">Download</div>
                      <div class="text-white"><%= format_bandwidth(@bandwidth_stats.download) %></div>
                    </div>
                    <div>
                      <div class="text-gray-400">Upload</div>
                      <div class="text-white"><%= format_bandwidth(@bandwidth_stats.upload) %></div>
                    </div>
                    <div>
                      <div class="text-gray-400">Latency</div>
                      <div class="text-white"><%= @bandwidth_stats.latency %> ms</div>
                    </div>
                    <div>
                      <div class="text-gray-400">Packet Loss</div>
                      <div class="text-white"><%= @bandwidth_stats.packet_loss %>%</div>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
      """
    end

    defp format_bandwidth(kbps) do
      cond do
        kbps >= 1024 -> "#{Float.round(kbps / 1024, 1)} Mbps"
        true -> "#{round(kbps)} Kbps"
      end
    end
  end
