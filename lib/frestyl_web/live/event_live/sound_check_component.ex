# lib/frestyl_web/live/event_live/sound_check_component.ex
defmodule FrestylWeb.EventLive.SoundCheckComponent do
  use FrestylWeb, :live_component

  alias Phoenix.LiveView.JS

  def mount(socket) do
    socket = assign(socket,
      microphone_connected: false,
      speaker_connected: false,
      microphone_level: 0,
      network_quality: "checking",
      show_advanced: false,
      ready: false,
      settings: %{
        echo_cancellation: true,
        noise_suppression: true,
        auto_gain_control: true,
        video_resolution: "720p"
      }
    )

    {:ok, socket}
  end

  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  def handle_event("toggle_advanced", _, socket) do
    {:noreply, assign(socket, show_advanced: !socket.assigns.show_advanced)}
  end

  def handle_event("set_ready", _, socket) do
    {:noreply, assign(socket, ready: true)}
  end

  def handle_event("update_setting", %{"key" => key, "value" => value}, socket) do
    updated_settings = Map.put(socket.assigns.settings, String.to_atom(key), value)
    {:noreply, assign(socket, settings: updated_settings)}
  end

  def handle_event("microphone_connected", %{"connected" => connected}, socket) do
    {:noreply, assign(socket, microphone_connected: connected)}
  end

  def handle_event("speaker_connected", %{"connected" => connected}, socket) do
    {:noreply, assign(socket, speaker_connected: connected)}
  end

  def handle_event("microphone_level", %{"level" => level}, socket) do
    {:noreply, assign(socket, microphone_level: level)}
  end

  def handle_event("network_quality", %{"quality" => quality}, socket) do
    {:noreply, assign(socket, network_quality: quality)}
  end

  def render(assigns) do
    ~H"""
    <div class="bg-gradient-to-br from-gray-900 to-indigo-900 min-h-screen flex items-center justify-center">
      <div class="max-w-2xl w-full mx-auto px-4 py-8">
        <div class="bg-gray-800 bg-opacity-70 rounded-xl shadow-xl overflow-hidden">
          <!-- Header -->
          <div class="p-6 border-b border-gray-700">
            <h1 class="text-2xl font-bold text-white">Sound Check</h1>
            <p class="text-gray-400 mt-1">Let's make sure your audio and video are working before you join the broadcast</p>
          </div>

          <!-- Main content -->
          <div class="p-6 space-y-6">
            <!-- Device status -->
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div class="bg-gray-900 rounded-lg p-4">
                <div class="flex items-center justify-between mb-3">
                  <h3 class="text-white font-medium">Microphone</h3>
                  <span class={[
                    "text-xs px-2 py-1 rounded-full",
                    @microphone_connected && "bg-green-500 bg-opacity-20 text-green-400",
                    !@microphone_connected && "bg-red-500 bg-opacity-20 text-red-400"
                  ]}>
                    <%= if @microphone_connected, do: "Connected", else: "Not Connected" %>
                  </span>
                </div>

                <div class="h-5 bg-gray-800 rounded-full overflow-hidden">
                  <div
                    class="h-full bg-gradient-to-r from-green-500 to-green-400 transition-all duration-200"
                    style={"width: #{@microphone_level}%"}
                  ></div>
                </div>
              </div>

              <div class="bg-gray-900 rounded-lg p-4">
                <div class="flex items-center justify-between mb-3">
                  <h3 class="text-white font-medium">Speakers</h3>
                  <span class={[
                    "text-xs px-2 py-1 rounded-full",
                    @speaker_connected && "bg-green-500 bg-opacity-20 text-green-400",
                    !@speaker_connected && "bg-red-500 bg-opacity-20 text-red-400"
                  ]}>
                    <%= if @speaker_connected, do: "Connected", else: "Not Connected" %>
                  </span>
                </div>

                <button class="w-full bg-indigo-500 hover:bg-indigo-600 text-white px-3 py-2 rounded-md text-sm">
                  Test Speakers
                </button>
              </div>
            </div>

            <!-- Network status -->
            <div class="bg-gray-900 rounded-lg p-4">
              <div class="flex items-center justify-between mb-3">
                <h3 class="text-white font-medium">Network Connection</h3>
                <span class={[
                  "text-xs px-2 py-1 rounded-full",
                  @network_quality == "good" && "bg-green-500 bg-opacity-20 text-green-400",
                  @network_quality == "fair" && "bg-yellow-500 bg-opacity-20 text-yellow-400",
                  @network_quality == "poor" && "bg-red-500 bg-opacity-20 text-red-400",
                  @network_quality == "checking" && "bg-blue-500 bg-opacity-20 text-blue-400"
                ]}>
                  <%= case @network_quality do
                    "good" -> "Good"
                    "fair" -> "Fair"
                    "poor" -> "Poor"
                    "checking" -> "Checking..."
                  end %>
                </span>
              </div>

              <%= if @network_quality != "checking" do %>
                <div class="flex space-x-1 mb-2">
                  <%= for i <- 1..5 do %>
                    <div
                      class={[
                        "h-5 w-full rounded-sm",
                        @network_quality == "good" && i <= 5 && "bg-green-500",
                        @network_quality == "fair" && i <= 3 && "bg-yellow-500",
                        @network_quality == "fair" && i > 3 && "bg-gray-700",
                        @network_quality == "poor" && i <= 1 && "bg-red-500",
                        @network_quality == "poor" && i > 1 && "bg-gray-700"
                      ]}
                    ></div>
                  <% end %>
                </div>

                <div class="text-sm text-gray-400">
                  <%= case @network_quality do
                    "good" -> "Your connection is excellent for broadcasting."
                    "fair" -> "Your connection may experience occasional issues."
                    "poor" -> "Your connection may affect broadcast quality. Consider using audio only."
                    _ -> ""
                  end %>
                </div>
              <% else %>
                <div class="flex justify-center items-center h-10">
                  <div class="animate-pulse text-blue-400">Testing connection speed...</div>
                </div>
              <% end %>
            </div>

            <!-- Video preview -->
            <div class="bg-gray-900 rounded-lg p-4">
              <h3 class="text-white font-medium mb-3">Video Preview</h3>

              <div class="bg-black rounded-lg h-48 w-full flex items-center justify-center" id="video-preview">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-12 w-12 text-gray-700" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z" />
                </svg>
              </div>
            </div>

            <!-- Advanced settings -->
            <div>
              <button
                phx-click="toggle_advanced"
                phx-target={@myself}
                class="text-indigo-400 hover:text-indigo-300 text-sm flex items-center"
              >
                <span>Advanced Settings</span>
                <svg xmlns="http://www.w3.org/2000/svg" class={["h-4 w-4 ml-1 transition-transform", @show_advanced && "transform rotate-180"]} viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z" clip-rule="evenodd" />
                </svg>
              </button>

              <%= if @show_advanced do %>
                <div class="mt-3 bg-gray-900 rounded-lg p-4 space-y-3">
                  <div class="flex items-center justify-between">
                    <label for="echo-cancellation" class="text-sm text-gray-400">Echo Cancellation</label>
                    <div class="relative inline-block w-10 align-middle select-none">
                      <input
                        type="checkbox"
                        id="echo-cancellation"
                        checked={@settings.echo_cancellation}
                        phx-click="update_setting"
                        phx-target={@myself}
                        phx-value-key="echo_cancellation"
                        phx-value-value={!@settings.echo_cancellation}
                        class="absolute block w-6 h-6 rounded-full bg-white border-4 appearance-none cursor-pointer"
                      />
                      <label for="echo-cancellation" class="block overflow-hidden h-6 rounded-full bg-gray-700 cursor-pointer"></label>
                    </div>
                  </div>

                  <div class="flex items-center justify-between">
                    <label for="noise-suppression" class="text-sm text-gray-400">Noise Suppression</label>
                    <div class="relative inline-block w-10 align-middle select-none">
                      <input
                        type="checkbox"
                        id="noise-suppression"
                        checked={@settings.noise_suppression}
                        phx-click="update_setting"
                        phx-target={@myself}
                        phx-value-key="noise_suppression"
                        phx-value-value={!@settings.noise_suppression}
                        class="absolute block w-6 h-6 rounded-full bg-white border-4 appearance-none cursor-pointer"
                      />
                      <label for="noise-suppression" class="block overflow-hidden h-6 rounded-full bg-gray-700 cursor-pointer"></label>
                    </div>
                  </div>

                  <div class="flex items-center justify-between">
                    <label for="auto-gain" class="text-sm text-gray-400">Auto Gain Control</label>
                    <div class="relative inline-block w-10 align-middle select-none">
                      <input
                        type="checkbox"
                        id="auto-gain"
                        checked={@settings.auto_gain_control}
                        phx-click="update_setting"
                        phx-target={@myself}
                        phx-value-key="auto_gain_control"
                        phx-value-value={!@settings.auto_gain_control}
                        class="absolute block w-6 h-6 rounded-full bg-white border-4 appearance-none cursor-pointer"
                      />
                      <label for="auto-gain" class="block overflow-hidden h-6 rounded-full bg-gray-700 cursor-pointer"></label>
                    </div>
                  </div>

                  <div>
                    <label for="video-resolution" class="text-sm text-gray-400 block mb-1">Video Resolution</label>
                    <select
                      id="video-resolution"
                      phx-change="update_setting"
                      phx-target={@myself}
                      phx-value-key="video_resolution"
                      class="w-full bg-gray-800 border border-gray-700 text-white rounded-md px-3 py-2 text-sm"
                    >
                      <option value="720p" selected={@settings.video_resolution == "720p"}>HD (720p)</option>
                      <option value="480p" selected={@settings.video_resolution == "480p"}>SD (480p)</option>
                      <option value="360p" selected={@settings.video_resolution == "360p"}>Low (360p)</option>
                      <option value="audio_only" selected={@settings.video_resolution == "audio_only"}>Audio Only</option>
                    </select>
                  </div>
                </div>
              <% end %>
            </div>

            <!-- Ready button -->
            <div class="flex justify-center pt-4">
              <button
                phx-click="set_ready"
                phx-target={@myself}
                disabled={!@microphone_connected || !@speaker_connected || @network_quality == "checking"}
                class={[
                  "px-6 py-3 rounded-lg font-medium text-white shadow-lg",
                  !@ready && "bg-gradient-to-r from-indigo-500 to-purple-600 hover:from-indigo-600 hover:to-purple-700",
                  @ready && "bg-green-500 hover:bg-green-600",
                  (!@microphone_connected || !@speaker_connected || @network_quality == "checking") && "opacity-50 cursor-not-allowed"
                ]}
              >
                <%= if @ready, do: "Ready to Join!", else: "I'm Ready" %>
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
