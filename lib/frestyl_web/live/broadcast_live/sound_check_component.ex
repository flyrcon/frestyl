defmodule FrestylWeb.BroadcastLive.SoundCheckComponent do
  use FrestylWeb, :live_component

  def mount(socket) do
    socket = assign(socket,
      microphone_connected: false,
      speaker_connected: false,
      microphone_level: 0,
      network_quality: "checking",
      show_advanced: false,
      ready: false,
      device_permissions_granted: false,
      testing_microphone: false,
      testing_speakers: false,
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

  def handle_event("request_permissions", _, socket) do
    {:noreply,
     socket
     |> assign(:testing_microphone, true)
     |> push_event("request_media_permissions", %{})}
  end

  def handle_event("permissions_granted", %{"audio" => audio, "video" => video}, socket) do
    {:noreply,
     socket
     |> assign(:device_permissions_granted, true)
     |> assign(:microphone_connected, audio)
     |> assign(:testing_microphone, false)
     |> check_ready_state()}
  end

  def handle_event("permissions_denied", _, socket) do
    {:noreply,
     socket
     |> assign(:testing_microphone, false)
     |> put_flash(:error, "Media permissions are required for the sound check")}
  end

  def handle_event("microphone_level_update", %{"level" => level}, socket) do
    {:noreply, assign(socket, :microphone_level, level)}
  end

  def handle_event("test_speakers", _, socket) do
    {:noreply,
     socket
     |> assign(:testing_speakers, true)
     |> push_event("test_speaker_audio", %{})}
  end

  def handle_event("speakers_test_complete", %{"success" => success}, socket) do
    {:noreply,
     socket
     |> assign(:speaker_connected, success)
     |> assign(:testing_speakers, false)
     |> check_ready_state()}
  end

  def handle_event("network_test_complete", %{"quality" => quality}, socket) do
    {:noreply,
     socket
     |> assign(:network_quality, quality)
     |> check_ready_state()}
  end

  def handle_event("toggle_advanced", _, socket) do
    {:noreply, assign(socket, :show_advanced, !socket.assigns.show_advanced)}
  end

  def handle_event("update_setting", %{"key" => key, "value" => value}, socket) do
    parsed_value = case value do
      "true" -> true
      "false" -> false
      other -> other
    end

    updated_settings = Map.put(socket.assigns.settings, String.to_atom(key), parsed_value)
    {:noreply, assign(socket, :settings, updated_settings)}
  end

  def handle_event("complete_sound_check", _, socket) do
    send(self(), {:sound_check_complete, :completed})
    {:noreply, socket}
  end

  # Check if user is ready based on their requirements
  defp check_ready_state(socket) do
    is_host = Map.get(socket.assigns, :is_host, false)

    ready = cond do
      is_host ->
        # Hosts need both mic and speakers working, plus good network
        socket.assigns.microphone_connected &&
        socket.assigns.speaker_connected &&
        socket.assigns.network_quality != "checking"

      true ->
        # Participants just need speakers and network
        socket.assigns.speaker_connected &&
        socket.assigns.network_quality != "checking"
    end

    assign(socket, :ready, ready)
  end

  def handle_event("skip_sound_check", _, socket) do
    send(self(), {:sound_check_complete, :skipped})
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="bg-gradient-to-br from-gray-900 to-indigo-900 min-h-screen flex items-center justify-center">
      <div class="max-w-2xl w-full mx-auto px-4 py-8">
        <div class="bg-gray-800 bg-opacity-70 rounded-xl shadow-xl overflow-hidden" id="sound-check-container" phx-hook="SoundCheck">
          <!-- Header -->
          <div class="p-6 border-b border-gray-700">
            <h1 class="text-2xl font-bold text-white mb-2">Sound Check</h1>
            <p class="text-gray-400">Let's make sure everything is working before you join</p>
            <div class="mt-4 text-lg font-medium text-gray-300">
              <%= if Map.get(assigns, :is_host, false) do %>
                Joining as Host: <span class="text-indigo-400"><%= @broadcast.title %></span>
              <% else %>
                Joining: <span class="text-indigo-400"><%= @broadcast.title %></span>
              <% end %>
            </div>
          </div>

          <!-- Main content -->
          <div class="p-6 space-y-6">
            <!-- Device Permissions -->
            <%= if not @device_permissions_granted do %>
              <div class="bg-amber-900 bg-opacity-50 rounded-lg p-4 border border-amber-700">
                <div class="flex items-center mb-3">
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-amber-400 mr-2" viewBox="0 0 20 20" fill="currentColor">
                    <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
                  </svg>
                  <h3 class="text-amber-300 font-medium">Permissions Required</h3>
                </div>
                <p class="text-amber-200 text-sm mb-4">
                  <%= if Map.get(assigns, :is_host, false) do %>
                    As the host, you'll need to grant camera and microphone access to broadcast.
                  <% else %>
                    You'll need to grant microphone access to participate and speaker access to hear audio.
                  <% end %>
                </p>
                <button
                  phx-click="request_permissions"
                  phx-target={@myself}
                  disabled={@testing_microphone}
                  class="w-full bg-amber-600 hover:bg-amber-500 text-white font-medium py-2 px-4 rounded-md transition-colors"
                >
                  <%= if @testing_microphone do %>
                    Requesting permissions...
                  <% else %>
                    Grant Permissions
                  <% end %>
                </button>
              </div>
            <% end %>

            <!-- Device status -->
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <!-- Microphone (for hosts and after permissions) -->
              <%= if Map.get(assigns, :is_host, false) || @device_permissions_granted do %>
                <div class="bg-gray-900 rounded-lg p-4">
                  <div class="flex items-center justify-between mb-3">
                    <h3 class="text-white font-medium">Microphone</h3>
                    <span class={[
                      "text-xs px-2 py-1 rounded-full font-medium",
                      @microphone_connected && "bg-green-500 bg-opacity-20 text-green-400",
                      !@microphone_connected && "bg-red-500 bg-opacity-20 text-red-400"
                    ]}>
                      <%= if @microphone_connected, do: "Connected", else: "Not Connected" %>
                    </span>
                  </div>

                  <%= if @microphone_connected do %>
                    <div class="h-5 bg-gray-800 rounded-full overflow-hidden mb-2">
                      <div
                        class="h-full bg-gradient-to-r from-green-500 to-green-400 transition-all duration-200"
                        style={"width: #{@microphone_level}%"}
                      ></div>
                    </div>
                    <p class="text-xs text-gray-400">Speak to test your microphone level</p>
                  <% else %>
                    <p class="text-sm text-gray-400">Click "Grant Permissions" above to test your microphone</p>
                  <% end %>
                </div>
              <% end %>

              <!-- Speakers -->
              <div class="bg-gray-900 rounded-lg p-4">
                <div class="flex items-center justify-between mb-3">
                  <h3 class="text-white font-medium">Speakers</h3>
                  <span class={[
                    "text-xs px-2 py-1 rounded-full font-medium",
                    @speaker_connected && "bg-green-500 bg-opacity-20 text-green-400",
                    !@speaker_connected && "bg-red-500 bg-opacity-20 text-red-400"
                  ]}>
                    <%= if @speaker_connected, do: "Working", else: "Not Tested" %>
                  </span>
                </div>

                <button
                  phx-click="test_speakers"
                  phx-target={@myself}
                  disabled={@testing_speakers}
                  class="w-full bg-indigo-500 hover:bg-indigo-600 text-white px-3 py-2 rounded-md text-sm font-medium transition-colors"
                >
                  <%= if @testing_speakers do %>
                    Testing...
                  <% else %>
                    Test Speakers
                  <% end %>
                </button>
              </div>
            </div>

            <!-- Network status -->
            <div class="bg-gray-900 rounded-lg p-4">
              <div class="flex items-center justify-between mb-3">
                <h3 class="text-white font-medium">Network Connection</h3>
                <span class={[
                  "text-xs px-2 py-1 rounded-full font-medium",
                  @network_quality == "good" && "bg-green-500 bg-opacity-20 text-green-400",
                  @network_quality == "fair" && "bg-yellow-500 bg-opacity-20 text-yellow-400",
                  @network_quality == "poor" && "bg-red-500 bg-opacity-20 text-red-400",
                  @network_quality == "checking" && "bg-blue-500 bg-opacity-20 text-blue-400"
                ]}>
                  <%= case @network_quality do
                    "good" -> "Excellent"
                    "fair" -> "Good"
                    "poor" -> "Poor"
                    "checking" -> "Testing..."
                  end %>
                </span>
              </div>

              <%= if @network_quality != "checking" do %>
                <div class="flex space-x-1 mb-2">
                  <%= for i <- 1..5 do %>
                    <div
                      class={[
                        "h-5 w-full rounded-sm transition-colors",
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
                    "fair" -> "Your connection should work well for most broadcasts."
                    "poor" -> "Your connection may affect broadcast quality. Consider using audio only."
                    _ -> ""
                  end %>
                </div>
              <% else %>
                <div class="flex justify-center items-center h-10">
                  <div class="flex space-x-1">
                    <div class="w-2 h-2 bg-blue-400 rounded-full animate-bounce"></div>
                    <div class="w-2 h-2 bg-blue-400 rounded-full animate-bounce" style="animation-delay: 0.1s"></div>
                    <div class="w-2 h-2 bg-blue-400 rounded-full animate-bounce" style="animation-delay: 0.2s"></div>
                  </div>
                  <span class="ml-3 text-blue-400">Testing connection speed...</span>
                </div>
              <% end %>
            </div>

            <!-- Action buttons -->
            <div class="flex justify-center space-x-4 pt-4">
              <button
                phx-click="complete_sound_check"
                phx-target={@myself}
                disabled={!@ready}
                class={[
                  "px-8 py-3 rounded-lg font-medium transition-colors",
                  @ready && "bg-gradient-to-r from-indigo-500 to-purple-600 hover:from-indigo-600 hover:to-purple-700 text-white" ||
                  "bg-gray-700 text-gray-400 cursor-not-allowed"
                ]}
              >
                <%= if @ready do %>
                  <%= if Map.get(assigns, :is_host, false), do: "Start Broadcast!", else: "Join Broadcast!" %>
                <% else %>
                  Complete Tests Above
                <% end %>
              </button>

              <button
                phx-click="skip_sound_check"
                phx-target={@myself}
                class="px-6 py-3 bg-gray-700 hover:bg-gray-600 text-white rounded-lg font-medium transition-colors"
              >
                Skip Sound Check
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
