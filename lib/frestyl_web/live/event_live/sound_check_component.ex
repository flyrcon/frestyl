# lib/frestyl_web/live/event_live/sound_check_component.ex
defmodule FrestylWeb.EventLive.SoundCheckComponent do
  use FrestylWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-4 border rounded-lg">
      <h2 class="text-lg font-semibold mb-4">Sound Check</h2>

      <div class="mb-4">
        <p class="mb-2">Make sure your audio and video are working properly before joining the event.</p>

        <div class="flex space-x-4 mt-4">
          <button
            phx-click="test_microphone"
            phx-target={@myself}
            class="bg-zinc-800 text-white px-4 py-2 rounded-lg hover:bg-zinc-700"
          >
            Test Microphone
          </button>

          <button
            phx-click="test_speakers"
            phx-target={@myself}
            class="bg-zinc-800 text-white px-4 py-2 rounded-lg hover:bg-zinc-700"
          >
            Test Speakers
          </button>
        </div>
      </div>

      <div class="mt-6 mb-4">
        <label class="block font-medium mb-1">Audio Input</label>
        <select class="w-full border rounded py-2 px-3">
          <option>Default Microphone</option>
          <!-- JavaScript would populate available devices here -->
        </select>
      </div>

      <div class="mt-4 mb-6">
        <label class="block font-medium mb-1">Audio Output</label>
        <select class="w-full border rounded py-2 px-3">
          <option>Default Speakers</option>
          <!-- JavaScript would populate available devices here -->
        </select>
      </div>

      <div class="mt-4">
        <button
          phx-click="complete_sound_check"
          phx-target={@myself}
          class="w-full bg-zinc-900 text-white py-2 px-4 rounded-lg hover:bg-zinc-700"
        >
          Complete Sound Check
        </button>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("test_microphone", _, socket) do
    # In a real implementation, this would interact with browser APIs
    # to test the microphone. Here we just simulate success.
    {:noreply, put_flash(socket, :info, "Microphone is working!")}
  end

  @impl true
  def handle_event("test_speakers", _, socket) do
    # In a real implementation, this would play a test sound
    # Here we just simulate success
    {:noreply, put_flash(socket, :info, "Audio playback is working!")}
  end

  @impl true
  def handle_event("complete_sound_check", _, socket) do
    send(self(), :sound_check_completed)
    {:noreply, socket}
  end
end
