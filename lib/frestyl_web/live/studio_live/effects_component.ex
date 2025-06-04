# lib/frestyl_web/live/studio_live/effects_component.ex

defmodule FrestylWeb.StudioLive.EffectsComponent do
  use FrestylWeb, :live_component
  alias FrestylWeb.AccessibilityComponents, as: A11y

  @impl true
  def mount(socket) do
    {:ok, assign(socket,
      selected_effect: nil,
      effect_presets: get_effect_presets(),
      show_advanced: false,
      automation_recording: false,
      cpu_usage: 0,
      effects_processing_active: false
    )}
  end

  @impl true
  def update(assigns, socket) do
    # Update CPU usage and processing status from assigns
    socket =
      socket
      |> assign(assigns)
      |> assign(:cpu_usage, Map.get(assigns, :cpu_usage, 0))
      |> assign(:effects_processing_active, Map.get(assigns, :effects_processing_active, false))

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-black/40 backdrop-blur-xl border border-white/20 rounded-3xl p-6">
      <!-- Effects Header -->
      <div class="flex items-center justify-between mb-6">
        <div class="flex items-center gap-3">
          <div class="p-2 bg-gradient-to-r from-purple-500 to-pink-600 rounded-xl">
            <svg class="h-5 w-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3" />
            </svg>
          </div>
          <div>
            <h3 class="text-white font-semibold text-lg">Audio Effects</h3>
            <p class="text-white/60 text-sm">Track <%= @track.name %></p>
          </div>
        </div>

        <div class="flex items-center gap-2">
          <!-- CPU Usage Indicator -->
          <%= if @cpu_usage do %>
            <div class="flex items-center gap-2 text-xs">
              <span class="text-white/60">CPU: </span>
              <div class="w-16 h-2 bg-white/10 rounded-full overflow-hidden">
                <div
                  class={[
                    "h-full transition-all duration-200",
                    if @cpu_usage > 80 do
                      "bg-red-500"
                    else
                      if @cpu_usage > 60 do
                        "bg-yellow-500"
                      else
                        "bg-green-500"
                      end
                    end
                  ]}
                  style={"width: #{@cpu_usage}%"}
                ></div>
              </div>
              <span class="text-white/80"><%= @cpu_usage %>%</span>
            </div>
          <% end %>

          <!-- Automation Recording -->
          <A11y.a11y_button
            variant="outline"
            size="sm"
            class={[
              "text-xs border-white/20",
              if @automation_recording do
                "bg-red-500/20 border-red-500/40 text-red-300"
              else
                "text-white/70 hover:text-white hover:bg-white/10"
              end
            ]}
            phx-click="toggle_automation_recording"
            phx-target={@myself}
          >
            <%= if @automation_recording do %>
              <div class="w-2 h-2 bg-red-500 rounded-full animate-pulse mr-1"></div>
              Auto
            <% else %>
              Auto
            <% end %>
          </A11y.a11y_button>

          <!-- Advanced Toggle -->
          <A11y.a11y_button
            variant="outline"
            size="sm"
            class={[
              "text-xs border-white/20",
              if @show_advanced do
                "bg-white/20 text-white border-white/40"
              else
                "text-white/70 hover:text-white hover:bg-white/10"
              end
            ]}
            phx-click="toggle_advanced"
            phx-target={@myself}
          >
            Advanced
          </A11y.a11y_button>
        </div>
      </div>

      <!-- Effect Presets -->
      <div class="mb-6">
        <div class="flex items-center justify-between mb-3">
          <h4 class="text-white/80 font-medium text-sm">Quick Presets</h4>
          <A11y.a11y_button
            variant="outline"
            size="sm"
            class="text-xs border-white/20 text-white/70 hover:text-white hover:bg-white/10"
            phx-click="save_custom_preset"
            phx-target={@myself}
          >
            Save Preset
          </A11y.a11y_button>
        </div>

        <div class="grid grid-cols-2 md:grid-cols-3 gap-2">
          <%= for {preset_name, preset} <- @effect_presets do %>
            <A11y.a11y_button
              variant="outline"
              size="sm"
              class="p-3 text-xs border-white/20 text-white/70 hover:text-white hover:bg-white/10 text-left"
              phx-click="apply_preset"
              phx-value-preset={preset_name}
              phx-target={@myself}
            >
              <div class="font-medium"><%= preset.name %></div>
              <div class="text-white/50 text-xs"><%= preset.description %></div>
            </A11y.a11y_button>
          <% end %>
        </div>
      </div>

      <!-- Current Effects Chain -->
      <%= if length(@track.effects || []) > 0 do %>
        <div class="mb-6">
          <h4 class="text-white/80 font-medium text-sm mb-3">Effects Chain</h4>
          <div class="space-y-3">
            <%= for {effect, index} <- Enum.with_index(@track.effects || []) do %>
              <div class={[
                "bg-white/5 border border-white/10 rounded-2xl p-4 transition-all duration-200",
                if @selected_effect == effect.id do
                  "border-purple-500/50 bg-purple-500/10"
                else
                  "hover:bg-white/10"
                end
              ]}>
                <div class="flex items-center justify-between mb-3">
                  <div class="flex items-center gap-3">
                    <!-- Drag Handle -->
                    <div class="cursor-move text-white/40 hover:text-white/60">
                      <svg class="h-4 w-4" fill="currentColor" viewBox="0 0 24 24">
                        <path d="M9 5h2v2H9V5zm0 4h2v2H9V9zm0 4h2v2H9v-2zm0 4h2v2H9v-2zm4-12h2v2h-2V5zm0 4h2v2h-2V9zm0 4h2v2h-2v-2zm0 4h2v2h-2v-2z"/>
                      </svg>
                    </div>

                    <!-- Effect Info -->
                    <div>
                      <div class="text-white font-medium text-sm">
                        <%= format_effect_name(effect.type) %>
                      </div>
                      <div class="text-white/50 text-xs">
                        <%= if effect.enabled, do: "Active", else: "Bypassed" %>
                      </div>
                    </div>
                  </div>

                  <div class="flex items-center gap-2">
                    <!-- Bypass Toggle -->
                    <A11y.a11y_button
                      variant="outline"
                      size="sm"
                      class={[
                        "text-xs border-white/20",
                        if effect.enabled do
                          "text-white/70 hover:text-white hover:bg-white/10"
                        else
                          "bg-yellow-500/20 border-yellow-500/40 text-yellow-300"
                        end
                      ]}
                      phx-click="toggle_effect_bypass"
                      phx-value-effect-id={effect.id}
                      phx-target={@myself}
                    >
                      <%= if effect.enabled, do: "Bypass", else: "Enable" %>
                    </A11y.a11y_button>

                    <!-- Remove Effect -->
                    <A11y.a11y_button
                      variant="outline"
                      size="sm"
                      class="text-xs border-red-500/30 text-red-400 hover:bg-red-500/20 hover:border-red-500/50"
                      phx-click="remove_effect"
                      phx-value-effect-id={effect.id}
                      phx-target={@myself}
                    >
                      &times;
                    </A11y.a11y_button>
                  </div>
                </div>

                <!-- Effect Parameters -->
                <%= if @selected_effect == effect.id or @show_advanced do %>
                  <div class="space-y-3">
                    <%= render_effect_controls(assigns, effect) %>
                  </div>
                <% else %>
                  <A11y.a11y_button
                    variant="ghost"
                    size="sm"
                    class="w-full text-white/60 hover:text-white text-xs"
                    phx-click="select_effect"
                    phx-value-effect-id={effect.id}
                    phx-target={@myself}
                  >
                    Click to edit parameters
                  </A11y.a11y_button>
                <% end %>

                <!-- Effect Visualization -->
                <%= if effect.type in ["parametric_eq", "convolution_reverb", "multiband_compressor"] do %>
                  <div class="mt-3">
                    <canvas
                      id={"effect-viz-#{effect.id}"}
                      class="w-full h-16 bg-black/20 rounded-lg"
                      phx-hook="EffectVisualization"
                      data-effect-id={effect.id}
                      data-effect-type={effect.type}
                    ></canvas>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>

      <!-- Add New Effect -->
      <div>
        <h4 class="text-white/80 font-medium text-sm mb-3">Add Effect</h4>
        <div class="grid grid-cols-2 md:grid-cols-4 gap-2">
          <%= for effect_type <- get_available_effects() do %>
            <A11y.a11y_button
              variant="outline"
              size="sm"
              class="p-3 text-xs border-white/20 text-white/70 hover:text-white hover:bg-white/10 text-center"
              phx-click="add_effect"
              phx-value-effect-type={effect_type}
              phx-target={@myself}
            >
              <%= format_effect_name(effect_type) %>
            </A11y.a11y_button>
          <% end %>
        </div>
      </div>

      <!-- Real-time Effect Processing Status -->
      <%= if @effects_processing_active do %>
        <div class="mt-4 p-3 bg-green-500/10 border border-green-500/30 rounded-xl">
          <div class="flex items-center gap-2 text-green-300 text-sm">
            <div class="w-2 h-2 bg-green-500 rounded-full animate-pulse"></div>
            Real-time effects processing active
            <span class="text-green-400/60">
              (<%= length(@track.effects || []) %> effects loaded)
            </span>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Event Handlers
  @impl true
  def handle_event("apply_preset", %{"preset" => preset_name}, socket) do
    send(self(), {:apply_effect_preset, socket.assigns.track.id, preset_name})
    {:noreply, socket}
  end

  def handle_event("add_effect", %{"effect-type" => effect_type}, socket) do
    send(self(), {:add_effect_to_track, socket.assigns.track.id, effect_type, %{}})
    {:noreply, socket}
  end

  def handle_event("remove_effect", %{"effect-id" => effect_id}, socket) do
    send(self(), {:remove_effect_from_track, socket.assigns.track.id, effect_id})
    {:noreply, socket}
  end

  def handle_event("toggle_effect_bypass", %{"effect-id" => effect_id}, socket) do
    send(self(), {:toggle_effect_bypass, socket.assigns.track.id, effect_id})
    {:noreply, socket}
  end

  def handle_event("update_effect_param", params, socket) do
    %{
      "effect-id" => effect_id,
      "param" => param_name,
      "value" => value
    } = params

    # Convert string value to appropriate type
    parsed_value = parse_param_value(param_name, value)

    send(self(), {:update_effect_parameter, socket.assigns.track.id, effect_id, param_name, parsed_value})

    # If automation is recording, record this parameter change
    if socket.assigns.automation_recording do
      send(self(), {:record_automation, socket.assigns.track.id, effect_id, param_name, parsed_value})
    end

    {:noreply, socket}
  end

  def handle_event("select_effect", %{"effect-id" => effect_id}, socket) do
    {:noreply, assign(socket, selected_effect: effect_id)}
  end

  def handle_event("toggle_advanced", _, socket) do
    {:noreply, assign(socket, show_advanced: !socket.assigns.show_advanced)}
  end

  def handle_event("toggle_automation_recording", _, socket) do
    {:noreply, assign(socket, automation_recording: !socket.assigns.automation_recording)}
  end

  def handle_event("save_custom_preset", _, socket) do
    # Create preset from current effects
    preset_data = %{
      name: "Custom Preset #{System.unique_integer([:positive])}",
      effects: Enum.map(socket.assigns.track.effects || [], fn effect ->
        %{type: effect.type, params: effect.params}
      end)
    }

    send(self(), {:save_effect_preset, preset_data})
    {:noreply, socket}
  end

  # Effect parameter controls rendering
  defp render_effect_controls(assigns, effect) do
    case effect.type do
      "parametric_eq" -> render_eq_controls(assigns, effect)
      "multiband_compressor" -> render_multiband_compressor_controls(assigns, effect)
      "convolution_reverb" -> render_reverb_controls(assigns, effect)
      "tape_saturation" -> render_tape_saturation_controls(assigns, effect)
      "auto_tune" -> render_auto_tune_controls(assigns, effect)
      "vocoder" -> render_vocoder_controls(assigns, effect)
      "stereo_widener" -> render_stereo_widener_controls(assigns, effect)
      "vintage_delay" -> render_vintage_delay_controls(assigns, effect)
      "phaser" -> render_phaser_controls(assigns, effect)
      "flanger" -> render_flanger_controls(assigns, effect)
      "bitcrusher" -> render_bitcrusher_controls(assigns, effect)
      "spectral_gate" -> render_spectral_gate_controls(assigns, effect)
      _ -> render_generic_controls(assigns, effect)
    end
  end

  defp render_eq_controls(assigns, effect) do
    assigns = assign(assigns, :effect, effect)

    ~H"""
    <div class="grid grid-cols-2 gap-3">
      <!-- Low Band -->
      <div>
        <label class="block text-white/60 text-xs mb-1">Low</label>
        <input
          type="range"
          min="-12"
          max="12"
          step="0.1"
          value={get_effect_param(@effect, "low_gain", 0)}
          class="w-full h-2 bg-white/10 rounded-lg slider"
          phx-change="update_effect_param"
          phx-value-effect-id={@effect.id}
          phx-value-param="low_gain"
          phx-target={@myself}
        />
        <div class="text-white/40 text-xs text-center">
          <%= format_db_value(get_effect_param(@effect, "low_gain", 0)) %>
        </div>
      </div>

      <!-- Mid Band -->
      <div>
        <label class="block text-white/60 text-xs mb-1">Mid</label>
        <input
          type="range"
          min="-12"
          max="12"
          step="0.1"
          value={get_effect_param(@effect, "mid_gain", 0)}
          class="w-full h-2 bg-white/10 rounded-lg slider"
          phx-change="update_effect_param"
          phx-value-effect-id={@effect.id}
          phx-value-param="mid_gain"
          phx-target={@myself}
        />
        <div class="text-white/40 text-xs text-center">
          <%= format_db_value(get_effect_param(@effect, "mid_gain", 0)) %>
        </div>
      </div>

      <!-- High Band -->
      <div>
        <label class="block text-white/60 text-xs mb-1">High</label>
        <input
          type="range"
          min="-12"
          max="12"
          step="0.1"
          value={get_effect_param(@effect, "high_gain", 0)}
          class="w-full h-2 bg-white/10 rounded-lg slider"
          phx-change="update_effect_param"
          phx-value-effect-id={@effect.id}
          phx-value-param="high_gain"
          phx-target={@myself}
        />
        <div class="text-white/40 text-xs text-center">
          <%= format_db_value(get_effect_param(@effect, "high_gain", 0)) %>
        </div>
      </div>

      <!-- Q Factor -->
      <div>
        <label class="block text-white/60 text-xs mb-1">Q</label>
        <input
          type="range"
          min="0.1"
          max="10"
          step="0.1"
          value={get_effect_param(@effect, "q", 1)}
          class="w-full h-2 bg-white/10 rounded-lg slider"
          phx-change="update_effect_param"
          phx-value-effect-id={@effect.id}
          phx-value-param="q"
          phx-target={@myself}
        />
        <div class="text-white/40 text-xs text-center">
          <%= Float.round(get_effect_param(@effect, "q", 1), 1) %>
        </div>
      </div>
    </div>
    """
  end

  defp render_multiband_compressor_controls(assigns, effect) do
    assigns = assign(assigns, :effect, effect)

    ~H"""
    <div class="space-y-4">
      <!-- Low Band -->
      <div class="border border-white/10 rounded-lg p-3">
        <h5 class="text-white/80 text-xs font-medium mb-2">Low Band</h5>
        <div class="grid grid-cols-3 gap-2">
          <div>
            <label class="block text-white/60 text-xs mb-1">Threshold</label>
            <input
              type="range"
              min="-60"
              max="0"
              step="1"
              value={get_effect_param(@effect, "low_threshold", -24)}
              class="w-full h-2 bg-white/10 rounded-lg slider"
              phx-change="update_effect_param"
              phx-value-effect-id={@effect.id}
              phx-value-param="low_threshold"
              phx-target={@myself}
            />
            <div class="text-white/40 text-xs text-center">
              <%= get_effect_param(@effect, "low_threshold", -24) %>dB
            </div>
          </div>
          <div>
            <label class="block text-white/60 text-xs mb-1">Ratio</label>
            <input
              type="range"
              min="1"
              max="20"
              step="0.1"
              value={get_effect_param(@effect, "low_ratio", 4)}
              class="w-full h-2 bg-white/10 rounded-lg slider"
              phx-change="update_effect_param"
              phx-value-effect-id={@effect.id}
              phx-value-param="low_ratio"
              phx-target={@myself}
            />
            <div class="text-white/40 text-xs text-center">
              <%= Float.round(get_effect_param(@effect, "low_ratio", 4), 1) %>:1
            </div>
          </div>
          <div>
            <label class="block text-white/60 text-xs mb-1">Gain</label>
            <input
              type="range"
              min="0"
              max="4"
              step="0.1"
              value={get_effect_param(@effect, "low_gain", 1)}
              class="w-full h-2 bg-white/10 rounded-lg slider"
              phx-change="update_effect_param"
              phx-value-effect-id={@effect.id}
              phx-value-param="low_gain"
              phx-target={@myself}
            />
            <div class="text-white/40 text-xs text-center">
              <%= format_db_value(20 * :math.log10(get_effect_param(@effect, "low_gain", 1))) %>
            </div>
          </div>
        </div>
      </div>

      <!-- Mid Band -->
      <div class="border border-white/10 rounded-lg p-3">
        <h5 class="text-white/80 text-xs font-medium mb-2">Mid Band</h5>
        <div class="grid grid-cols-3 gap-2">
          <div>
            <label class="block text-white/60 text-xs mb-1">Threshold</label>
            <input
              type="range"
              min="-60"
              max="0"
              step="1"
              value={get_effect_param(@effect, "mid_threshold", -18)}
              class="w-full h-2 bg-white/10 rounded-lg slider"
              phx-change="update_effect_param"
              phx-value-effect-id={@effect.id}
              phx-value-param="mid_threshold"
              phx-target={@myself}
            />
            <div class="text-white/40 text-xs text-center">
              <%= get_effect_param(@effect, "mid_threshold", -18) %>dB
            </div>
          </div>
          <div>
            <label class="block text-white/60 text-xs mb-1">Ratio</label>
            <input
              type="range"
              min="1"
              max="20"
              step="0.1"
              value={get_effect_param(@effect, "mid_ratio", 3)}
              class="w-full h-2 bg-white/10 rounded-lg slider"
              phx-change="update_effect_param"
              phx-value-effect-id={@effect.id}
              phx-value-param="mid_ratio"
              phx-target={@myself}
            />
            <div class="text-white/40 text-xs text-center">
              <%= Float.round(get_effect_param(@effect, "mid_ratio", 3), 1) %>:1
            </div>
          </div>
          <div>
            <label class="block text-white/60 text-xs mb-1">Gain</label>
            <input
              type="range"
              min="0"
              max="4"
              step="0.1"
              value={get_effect_param(@effect, "mid_gain", 1)}
              class="w-full h-2 bg-white/10 rounded-lg slider"
              phx-change="update_effect_param"
              phx-value-effect-id={@effect.id}
              phx-value-param="mid_gain"
              phx-target={@myself}
            />
            <div class="text-white/40 text-xs text-center">
              <%= format_db_value(20 * :math.log10(get_effect_param(@effect, "mid_gain", 1))) %>
            </div>
          </div>
        </div>
      </div>

      <!-- High Band -->
      <div class="border border-white/10 rounded-lg p-3">
        <h5 class="text-white/80 text-xs font-medium mb-2">High Band</h5>
        <div class="grid grid-cols-3 gap-2">
          <div>
            <label class="block text-white/60 text-xs mb-1">Threshold</label>
            <input
              type="range"
              min="-60"
              max="0"
              step="1"
              value={get_effect_param(@effect, "high_threshold", -12)}
              class="w-full h-2 bg-white/10 rounded-lg slider"
              phx-change="update_effect_param"
              phx-value-effect-id={@effect.id}
              phx-value-param="high_threshold"
              phx-target={@myself}
            />
            <div class="text-white/40 text-xs text-center">
              <%= get_effect_param(@effect, "high_threshold", -12) %>dB
            </div>
          </div>
          <div>
            <label class="block text-white/60 text-xs mb-1">Ratio</label>
            <input
              type="range"
              min="1"
              max="20"
              step="0.1"
              value={get_effect_param(@effect, "high_ratio", 2)}
              class="w-full h-2 bg-white/10 rounded-lg slider"
              phx-change="update_effect_param"
              phx-value-effect-id={@effect.id}
              phx-value-param="high_ratio"
              phx-target={@myself}
            />
            <div class="text-white/40 text-xs text-center">
              <%= Float.round(get_effect_param(@effect, "high_ratio", 2), 1) %>:1
            </div>
          </div>
          <div>
            <label class="block text-white/60 text-xs mb-1">Gain</label>
            <input
              type="range"
              min="0"
              max="4"
              step="0.1"
              value={get_effect_param(@effect, "high_gain", 1)}
              class="w-full h-2 bg-white/10 rounded-lg slider"
              phx-change="update_effect_param"
              phx-value-effect-id={@effect.id}
              phx-value-param="high_gain"
              phx-target={@myself}
            />
            <div class="text-white/40 text-xs text-center">
              <%= format_db_value(20 * :math.log10(get_effect_param(@effect, "high_gain", 1))) %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp render_reverb_controls(assigns, effect) do
    assigns = assign(assigns, :effect, effect)

    ~H"""
    <div class="grid grid-cols-2 gap-3">
      <div>
        <label class="block text-white/60 text-xs mb-1">Room Type</label>
        <select
          class="w-full bg-white/10 border border-white/20 rounded-lg px-3 py-2 text-white text-xs"
          phx-change="update_effect_param"
          phx-value-effect-id={@effect.id}
          phx-value-param="room_type"
          phx-target={@myself}
        >
          <%= for room_type <- ["hall", "cathedral", "plate", "spring", "chamber"] do %>
            <option value={room_type} selected={get_effect_param(@effect, "room_type", "hall") == room_type}>
              <%= String.capitalize(room_type) %>
            </option>
          <% end %>
        </select>
      </div>

      <div>
        <label class="block text-white/60 text-xs mb-1">Wet Level</label>
        <input
          type="range"
          min="0"
          max="1"
          step="0.01"
          value={get_effect_param(@effect, "wet", 0.3)}
          class="w-full h-2 bg-white/10 rounded-lg slider"
          phx-change="update_effect_param"
          phx-value-effect-id={@effect.id}
          phx-value-param="wet"
          phx-target={@myself}
        />
        <div class="text-white/40 text-xs text-center">
          <%= round(get_effect_param(@effect, "wet", 0.3) * 100) %>%
        </div>
      </div>

      <div>
        <label class="block text-white/60 text-xs mb-1">Pre-delay</label>
        <input
          type="range"
          min="0"
          max="0.2"
          step="0.001"
          value={get_effect_param(@effect, "predelay", 0.03)}
          class="w-full h-2 bg-white/10 rounded-lg slider"
          phx-change="update_effect_param"
          phx-value-effect-id={@effect.id}
          phx-value-param="predelay"
          phx-target={@myself}
        />
        <div class="text-white/40 text-xs text-center">
          <%= round(get_effect_param(@effect, "predelay", 0.03) * 1000) %>ms
        </div>
      </div>

      <div>
        <label class="block text-white/60 text-xs mb-1">Dampening</label>
        <input
          type="range"
          min="1000"
          max="20000"
          step="100"
          value={get_effect_param(@effect, "dampening", 5000)}
          class="w-full h-2 bg-white/10 rounded-lg slider"
          phx-change="update_effect_param"
          phx-value-effect-id={@effect.id}
          phx-value-param="dampening"
          phx-target={@myself}
        />
        <div class="text-white/40 text-xs text-center">
          <%= format_frequency(get_effect_param(@effect, "dampening", 5000)) %>
        </div>
      </div>
    </div>
    """
  end

  defp render_auto_tune_controls(assigns, effect) do
    assigns = assign(assigns, :effect, effect)

    ~H"""
    <div class="grid grid-cols-2 gap-3">
      <div>
        <label class="block text-white/60 text-xs mb-1">Key</label>
        <select
          class="w-full bg-white/10 border border-white/20 rounded-lg px-3 py-2 text-white text-xs"
          phx-change="update_effect_param"
          phx-value-effect-id={@effect.id}
          phx-value-param="key"
          phx-target={@myself}
        >
          <%= for key <- ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"] do %>
            <option value={key} selected={get_effect_param(@effect, "key", "C") == key}>
              <%= key %>
            </option>
          <% end %>
        </select>
      </div>

      <div>
        <label class="block text-white/60 text-xs mb-1">Scale</label>
        <select
          class="w-full bg-white/10 border border-white/20 rounded-lg px-3 py-2 text-white text-xs"
          phx-change="update_effect_param"
          phx-value-effect-id={@effect.id}
          phx-value-param="scale"
          phx-target={@myself}
        >
          <%= for scale <- ["major", "minor", "pentatonic", "blues"] do %>
            <option value={scale} selected={get_effect_param(@effect, "scale", "major") == scale}>
              <%= String.capitalize(scale) %>
            </option>
          <% end %>
        </select>
      </div>

      <div>
        <label class="block text-white/60 text-xs mb-1">Correction</label>
        <input
          type="range"
          min="0"
          max="1"
          step="0.01"
          value={get_effect_param(@effect, "correction", 0.8)}
          class="w-full h-2 bg-white/10 rounded-lg slider"
          phx-change="update_effect_param"
          phx-value-effect-id={@effect.id}
          phx-value-param="correction"
          phx-target={@myself}
        />
        <div class="text-white/40 text-xs text-center">
          <%= round(get_effect_param(@effect, "correction", 0.8) * 100) %>%
        </div>
      </div>

      <div>
        <label class="block text-white/60 text-xs mb-1">Speed</label>
        <input
          type="range"
          min="0.01"
          max="1"
          step="0.01"
          value={get_effect_param(@effect, "speed", 0.1)}
          class="w-full h-2 bg-white/10 rounded-lg slider"
          phx-change="update_effect_param"
          phx-value-effect-id={@effect.id}
          phx-value-param="speed"
          phx-target={@myself}
        />
        <div class="text-white/40 text-xs text-center">
          <%= round(get_effect_param(@effect, "speed", 0.1) * 100) %>%
        </div>
      </div>
    </div>
    """
  end

  defp render_vocoder_controls(assigns, effect) do
    assigns = assign(assigns, :effect, effect)

    ~H"""
    <div class="grid grid-cols-2 gap-3">
      <div>
        <label class="block text-white/60 text-xs mb-1">Bands</label>
        <input
          type="range"
          min="8"
          max="32"
          step="1"
          value={get_effect_param(@effect, "bands", 16)}
          class="w-full h-2 bg-white/10 rounded-lg slider"
          phx-change="update_effect_param"
          phx-value-effect-id={@effect.id}
          phx-value-param="bands"
          phx-target={@myself}
        />
        <div class="text-white/40 text-xs text-center">
          <%= get_effect_param(@effect, "bands", 16) %> bands
        </div>
      </div>

      <div>
        <label class="block text-white/60 text-xs mb-1">Attack</label>
        <input
          type="range"
          min="0.001"
          max="0.1"
          step="0.001"
          value={get_effect_param(@effect, "attack", 0.01)}
          class="w-full h-2 bg-white/10 rounded-lg slider"
          phx-change="update_effect_param"
          phx-value-effect-id={@effect.id}
          phx-value-param="attack"
          phx-target={@myself}
        />
        <div class="text-white/40 text-xs text-center">
          <%= round(get_effect_param(@effect, "attack", 0.01) * 1000) %>ms
        </div>
      </div>

      <div>
        <label class="block text-white/60 text-xs mb-1">Release</label>
        <input
          type="range"
          min="0.01"
          max="1"
          step="0.01"
          value={get_effect_param(@effect, "release", 0.1)}
          class="w-full h-2 bg-white/10 rounded-lg slider"
          phx-change="update_effect_param"
          phx-value-effect-id={@effect.id}
          phx-value-param="release"
          phx-target={@myself}
        />
        <div class="text-white/40 text-xs text-center">
          <%= round(get_effect_param(@effect, "release", 0.1) * 1000) %>ms
        </div>
      </div>

      <div>
        <label class="block text-white/60 text-xs mb-1">Carrier Freq</label>
        <input
          type="range"
          min="50"
          max="1000"
          step="10"
          value={get_effect_param(@effect, "carrier_freq", 200)}
          class="w-full h-2 bg-white/10 rounded-lg slider"
          phx-change="update_effect_param"
          phx-value-effect-id={@effect.id}
          phx-value-param="carrier_freq"
          phx-target={@myself}
        />
        <div class="text-white/40 text-xs text-center">
          <%= get_effect_param(@effect, "carrier_freq", 200) %>Hz
        </div>
      </div>
    </div>
    """
  end

  defp render_stereo_widener_controls(assigns, effect) do
    assigns = assign(assigns, :effect, effect)

    ~H"""
    <div class="grid grid-cols-2 gap-3">
      <div>
        <label class="block text-white/60 text-xs mb-1">Width</label>
        <input
          type="range"
          min="0"
          max="3"
          step="0.1"
          value={get_effect_param(@effect, "width", 1.0)}
          class="w-full h-2 bg-white/10 rounded-lg slider"
          phx-change="update_effect_param"
          phx-value-effect-id={@effect.id}
          phx-value-param="width"
          phx-target={@myself}
        />
        <div class="text-white/40 text-xs text-center">
          <%= Float.round(get_effect_param(@effect, "width", 1.0) * 100) %>%
        </div>
      </div>

      <div>
        <label class="block text-white/60 text-xs mb-1">Bass Mono Freq</label>
        <input
          type="range"
          min="60"
          max="300"
          step="10"
          value={get_effect_param(@effect, "bass_mono_freq", 120)}
          class="w-full h-2 bg-white/10 rounded-lg slider"
          phx-change="update_effect_param"
          phx-value-effect-id={@effect.id}
          phx-value-param="bass_mono_freq"
          phx-target={@myself}
        />
        <div class="text-white/40 text-xs text-center">
          <%= get_effect_param(@effect, "bass_mono_freq", 120) %>Hz
        </div>
      </div>
    </div>
    """
  end

  defp render_tape_saturation_controls(assigns, effect) do
    assigns = assign(assigns, :effect, effect)

    ~H"""
    <div class="grid grid-cols-2 gap-3">
      <div>
        <label class="block text-white/60 text-xs mb-1">Drive</label>
        <input
          type="range"
          min="1"
          max="5"
          step="0.1"
          value={get_effect_param(@effect, "drive", 2)}
          class="w-full h-2 bg-white/10 rounded-lg slider"
          phx-change="update_effect_param"
          phx-value-effect-id={@effect.id}
          phx-value-param="drive"
          phx-target={@myself}
        />
        <div class="text-white/40 text-xs text-center">
          <%= Float.round(get_effect_param(@effect, "drive", 2), 1) %>
        </div>
      </div>

      <div>
        <label class="block text-white/60 text-xs mb-1">Warmth</label>
        <input
          type="range"
          min="0"
          max="6"
          step="0.1"
          value={get_effect_param(@effect, "warmth", 2)}
          class="w-full h-2 bg-white/10 rounded-lg slider"
          phx-change="update_effect_param"
          phx-value-effect-id={@effect.id}
          phx-value-param="warmth"
          phx-target={@myself}
        />
        <div class="text-white/40 text-xs text-center">
          <%= format_db_value(get_effect_param(@effect, "warmth", 2)) %>
        </div>
      </div>

      <div>
        <label class="block text-white/60 text-xs mb-1">High Cut</label>
        <input
          type="range"
          min="3000"
          max="15000"
          step="100"
          value={get_effect_param(@effect, "high_cut", 8000)}
          class="w-full h-2 bg-white/10 rounded-lg slider"
          phx-change="update_effect_param"
          phx-value-effect-id={@effect.id}
          phx-value-param="high_cut"
          phx-target={@myself}
        />
        <div class="text-white/40 text-xs text-center">
          <%= format_frequency(get_effect_param(@effect, "high_cut", 8000)) %>
        </div>
      </div>

      <div>
        <label class="block text-white/60 text-xs mb-1">Wow & Flutter</label>
        <input
          type="range"
          min="0"
          max="0.01"
          step="0.0001"
          value={get_effect_param(@effect, "wow_flutter", 0.002)}
          class="w-full h-2 bg-white/10 rounded-lg slider"
          phx-change="update_effect_param"
          phx-value-effect-id={@effect.id}
          phx-value-param="wow_flutter"
          phx-target={@myself}
        />
        <div class="text-white/40 text-xs text-center">
          <%= round(get_effect_param(@effect, "wow_flutter", 0.002) * 1000) / 10 %>%
        </div>
      </div>
    </div>
    """
  end

  defp render_vintage_delay_controls(assigns, effect) do
    assigns = assign(assigns, :effect, effect)

    ~H"""
    <div class="grid grid-cols-2 gap-3">
      <div>
        <label class="block text-white/60 text-xs mb-1">Time</label>
        <input
          type="range"
          min="0.01"
          max="1"
          step="0.001"
          value={get_effect_param(@effect, "time", 0.25)}
          class="w-full h-2 bg-white/10 rounded-lg slider"
          phx-change="update_effect_param"
          phx-value-effect-id={@effect.id}
          phx-value-param="time"
          phx-target={@myself}
        />
        <div class="text-white/40 text-xs text-center">
          <%= round(get_effect_param(@effect, "time", 0.25) * 1000) %>ms
        </div>
      </div>

      <div>
        <label class="block text-white/60 text-xs mb-1">Feedback</label>
        <input
          type="range"
          min="0"
          max="0.95"
          step="0.01"
          value={get_effect_param(@effect, "feedback", 0.4)}
          class="w-full h-2 bg-white/10 rounded-lg slider"
          phx-change="update_effect_param"
          phx-value-effect-id={@effect.id}
          phx-value-param="feedback"
          phx-target={@myself}
        />
        <div class="text-white/40 text-xs text-center">
          <%= round(get_effect_param(@effect, "feedback", 0.4) * 100) %>%
        </div>
      </div>

      <div>
        <label class="block text-white/60 text-xs mb-1">Tone</label>
        <input
          type="range"
          min="500"
          max="8000"
          step="50"
          value={get_effect_param(@effect, "tone", 3000)}
          class="w-full h-2 bg-white/10 rounded-lg slider"
          phx-change="update_effect_param"
          phx-value-effect-id={@effect.id}
          phx-value-param="tone"
          phx-target={@myself}
        />
        <div class="text-white/40 text-xs text-center">
          <%= format_frequency(get_effect_param(@effect, "tone", 3000)) %>
        </div>
      </div>

      <div>
        <label class="block text-white/60 text-xs mb-1">Wet Level</label>
        <input
          type="range"
          min="0"
          max="1"
          step="0.01"
          value={get_effect_param(@effect, "wet", 0.3)}
          class="w-full h-2 bg-white/10 rounded-lg slider"
          phx-change="update_effect_param"
          phx-value-effect-id={@effect.id}
          phx-value-param="wet"
          phx-target={@myself}
        />
        <div class="text-white/40 text-xs text-center">
          <%= round(get_effect_param(@effect, "wet", 0.3) * 100) %>%
        </div>
      </div>
    </div>
    """
  end

  defp render_phaser_controls(assigns, effect) do
    assigns = assign(assigns, :effect, effect)

    ~H"""
    <div class="grid grid-cols-2 gap-3">
      <div>
        <label class="block text-white/60 text-xs mb-1">Rate</label>
        <input
          type="range"
          min="0.1"
          max="10"
          step="0.1"
          value={get_effect_param(@effect, "rate", 0.5)}
          class="w-full h-2 bg-white/10 rounded-lg slider"
          phx-change="update_effect_param"
          phx-value-effect-id={@effect.id}
          phx-value-param="rate"
          phx-target={@myself}
        />
        <div class="text-white/40 text-xs text-center">
          <%= Float.round(get_effect_param(@effect, "rate", 0.5), 1) %>Hz
        </div>
      </div>

      <div>
        <label class="block text-white/60 text-xs mb-1">Depth</label>
        <input
          type="range"
          min="100"
          max="3000"
          step="50"
          value={get_effect_param(@effect, "depth", 1000)}
          class="w-full h-2 bg-white/10 rounded-lg slider"
          phx-change="update_effect_param"
          phx-value-effect-id={@effect.id}
          phx-value-param="depth"
          phx-target={@myself}
        />
        <div class="text-white/40 text-xs text-center">
          <%= get_effect_param(@effect, "depth", 1000) %>Hz
        </div>
      </div>

      <div>
        <label class="block text-white/60 text-xs mb-1">Feedback</label>
        <input
          type="range"
          min="0"
          max="0.95"
          step="0.01"
          value={get_effect_param(@effect, "feedback", 0.7)}
          class="w-full h-2 bg-white/10 rounded-lg slider"
          phx-change="update_effect_param"
          phx-value-effect-id={@effect.id}
          phx-value-param="feedback"
          phx-target={@myself}
        />
        <div class="text-white/40 text-xs text-center">
          <%= round(get_effect_param(@effect, "feedback", 0.7) * 100) %>%
        </div>
      </div>

      <div>
        <label class="block text-white/60 text-xs mb-1">Wet Level</label>
        <input
          type="range"
          min="0"
          max="1"
          step="0.01"
          value={get_effect_param(@effect, "wet", 0.3)}
          class="w-full h-2 bg-white/10 rounded-lg slider"
          phx-change="update_effect_param"
          phx-value-effect-id={@effect.id}
          phx-value-param="wet"
          phx-target={@myself}
        />
        <div class="text-white/40 text-xs text-center">
          <%= round(get_effect_param(@effect, "wet", 0.3) * 100) %>%
        </div>
      </div>
    </div>
    """
  end

  defp render_flanger_controls(assigns, effect) do
    assigns = assign(assigns, :effect, effect)

    ~H"""
    <div class="grid grid-cols-2 gap-3">
      <div>
        <label class="block text-white/60 text-xs mb-1">Rate</label>
        <input
          type="range"
          min="0.05"
          max="5"
          step="0.05"
          value={get_effect_param(@effect, "rate", 0.3)}
          class="w-full h-2 bg-white/10 rounded-lg slider"
          phx-change="update_effect_param"
          phx-value-effect-id={@effect.id}
          phx-value-param="rate"
          phx-target={@myself}
        />
        <div class="text-white/40 text-xs text-center">
          <%= Float.round(get_effect_param(@effect, "rate", 0.3), 2) %>Hz
        </div>
      </div>

      <div>
        <label class="block text-white/60 text-xs mb-1">Depth</label>
        <input
          type="range"
          min="0.001"
          max="0.01"
          step="0.0001"
          value={get_effect_param(@effect, "depth", 0.005)}
          class="w-full h-2 bg-white/10 rounded-lg slider"
          phx-change="update_effect_param"
          phx-value-effect-id={@effect.id}
          phx-value-param="depth"
          phx-target={@myself}
        />
        <div class="text-white/40 text-xs text-center">
          <%= round(get_effect_param(@effect, "depth", 0.005) * 10000) / 10 %>ms
        </div>
      </div>

      <div>
        <label class="block text-white/60 text-xs mb-1">Feedback</label>
        <input
          type="range"
          min="0"
          max="0.95"
          step="0.01"
          value={get_effect_param(@effect, "feedback", 0.6)}
          class="w-full h-2 bg-white/10 rounded-lg slider"
          phx-change="update_effect_param"
          phx-value-effect-id={@effect.id}
          phx-value-param="feedback"
          phx-target={@myself}
        />
        <div class="text-white/40 text-xs text-center">
          <%= round(get_effect_param(@effect, "feedback", 0.6) * 100) %>%
        </div>
      </div>

      <div>
        <label class="block text-white/60 text-xs mb-1">Mix</label>
        <input
          type="range"
          min="0"
          max="1"
          step="0.01"
          value={get_effect_param(@effect, "mix", 0.5)}
          class="w-full h-2 bg-white/10 rounded-lg slider"
          phx-change="update_effect_param"
          phx-value-effect-id={@effect.id}
          phx-value-param="mix"
          phx-target={@myself}
        />
        <div class="text-white/40 text-xs text-center">
          <%= round(get_effect_param(@effect, "mix", 0.5) * 100) %>%
        </div>
      </div>
    </div>
    """
  end

  defp render_bitcrusher_controls(assigns, effect) do
    assigns = assign(assigns, :effect, effect)

    ~H"""
    <div class="grid grid-cols-2 gap-3">
      <div>
        <label class="block text-white/60 text-xs mb-1">Bit Depth</label>
        <input
          type="range"
          min="1"
          max="16"
          step="1"
          value={get_effect_param(@effect, "bits", 8)}
          class="w-full h-2 bg-white/10 rounded-lg slider"
          phx-change="update_effect_param"
          phx-value-effect-id={@effect.id}
          phx-value-param="bits"
          phx-target={@myself}
        />
        <div class="text-white/40 text-xs text-center">
          <%= get_effect_param(@effect, "bits", 8) %> bit
        </div>
      </div>

      <div>
        <label class="block text-white/60 text-xs mb-1">Sample Rate</label>
        <input
          type="range"
          min="0.1"
          max="1"
          step="0.01"
          value={get_effect_param(@effect, "sample_rate", 0.5)}
          class="w-full h-2 bg-white/10 rounded-lg slider"
          phx-change="update_effect_param"
          phx-value-effect-id={@effect.id}
          phx-value-param="sample_rate"
          phx-target={@myself}
        />
        <div class="text-white/40 text-xs text-center">
          <%= round(get_effect_param(@effect, "sample_rate", 0.5) * 100) %>%
        </div>
      </div>
    </div>
    """
  end

  defp render_spectral_gate_controls(assigns, effect) do
    assigns = assign(assigns, :effect, effect)

    ~H"""
    <div class="grid grid-cols-2 gap-3">
      <div>
        <label class="block text-white/60 text-xs mb-1">Threshold</label>
        <input
          type="range"
          min="-60"
          max="0"
          step="1"
          value={get_effect_param(@effect, "threshold", -40)}
          class="w-full h-2 bg-white/10 rounded-lg slider"
          phx-change="update_effect_param"
          phx-value-effect-id={@effect.id}
          phx-value-param="threshold"
          phx-target={@myself}
        />
        <div class="text-white/40 text-xs text-center">
          <%= get_effect_param(@effect, "threshold", -40) %>dB
        </div>
      </div>

      <div>
        <label class="block text-white/60 text-xs mb-1">Ratio</label>
        <input
          type="range"
          min="1"
          max="20"
          step="0.1"
          value={get_effect_param(@effect, "ratio", 10)}
          class="w-full h-2 bg-white/10 rounded-lg slider"
          phx-change="update_effect_param"
          phx-value-effect-id={@effect.id}
          phx-value-param="ratio"
          phx-target={@myself}
        />
        <div class="text-white/40 text-xs text-center">
          <%= Float.round(get_effect_param(@effect, "ratio", 10), 1) %>:1
        </div>
      </div>

      <div>
        <label class="block text-white/60 text-xs mb-1">Attack</label>
        <input
          type="range"
          min="0.001"
          max="0.1"
          step="0.001"
          value={get_effect_param(@effect, "attack", 0.001)}
          class="w-full h-2 bg-white/10 rounded-lg slider"
          phx-change="update_effect_param"
          phx-value-effect-id={@effect.id}
          phx-value-param="attack"
          phx-target={@myself}
        />
        <div class="text-white/40 text-xs text-center">
          <%= round(get_effect_param(@effect, "attack", 0.001) * 1000) %>ms
        </div>
      </div>

      <div>
        <label class="block text-white/60 text-xs mb-1">Release</label>
        <input
          type="range"
          min="0.01"
          max="1"
          step="0.01"
          value={get_effect_param(@effect, "release", 0.1)}
          class="w-full h-2 bg-white/10 rounded-lg slider"
          phx-change="update_effect_param"
          phx-value-effect-id={@effect.id}
          phx-value-param="release"
          phx-target={@myself}
        />
        <div class="text-white/40 text-xs text-center">
          <%= round(get_effect_param(@effect, "release", 0.1) * 1000) %>ms
        </div>
      </div>
    </div>
    """
  end

  defp render_generic_controls(assigns, effect) do
    assigns = assign(assigns, :effect, effect)

    ~H"""
    <div class="grid grid-cols-2 gap-3">
      <%= for {param_name, param_value} <- (@effect.params || %{}) do %>
        <div>
          <label class="block text-white/60 text-xs mb-1"><%= format_param_name(param_name) %></label>
          <input
            type="range"
            min={get_param_min(param_name)}
            max={get_param_max(param_name)}
            step={get_param_step(param_name)}
            value={param_value}
            class="w-full h-2 bg-white/10 rounded-lg slider"
            phx-change="update_effect_param"
            phx-value-effect-id={@effect.id}
            phx-value-param={param_name}
            phx-target={@myself}
          />
          <div class="text-white/40 text-xs text-center">
            <%= format_param_value(param_name, param_value) %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Configuration Functions
  defp get_effect_presets do
    %{
      "vocal_chain" => %{
        name: "Vocal Chain",
        description: "Professional vocal processing",
        effects: [
          %{type: "parametric_eq", params: %{"low_gain" => 2, "mid_gain" => 1.2, "high_gain" => 1.5}},
          %{type: "compressor", params: %{"threshold" => -18, "ratio" => 3, "attack" => 0.003, "release" => 0.1}},
          %{type: "convolution_reverb", params: %{"room_type" => "vocal_hall", "wet" => 0.2}}
        ]
      },
      "guitar_amp" => %{
        name: "Guitar Amp",
        description: "Vintage guitar amplifier sound",
        effects: [
          %{type: "tape_saturation", params: %{"drive" => 0.6, "warmth" => 0.8}},
          %{type: "parametric_eq", params: %{"low_gain" => 1.1, "mid_gain" => 1.3, "high_gain" => 0.9}},
          %{type: "vintage_delay", params: %{"time" => 0.25, "feedback" => 0.3, "tone" => 0.7}}
        ]
      },
      "drum_punch" => %{
        name: "Drum Punch",
        description: "Punchy drum processing",
        effects: [
          %{type: "multiband_compressor", params: %{"low_ratio" => 4, "mid_ratio" => 2, "high_ratio" => 3}},
          %{type: "parametric_eq", params: %{"low_gain" => 1.3, "mid_gain" => 0.9, "high_gain" => 1.2}},
          %{type: "stereo_widener", params: %{"width" => 1.2, "bass_mono" => true}}
        ]
      },
      "creative_vocal" => %{
        name: "Creative Vocal",
        description: "Auto-tuned and vocoded vocals",
        effects: [
          %{type: "auto_tune", params: %{"correction" => 0.8, "key" => "C", "scale" => "major"}},
          %{type: "vocoder", params: %{"bands" => 16, "attack" => 0.01, "release" => 0.1}},
          %{type: "convolution_reverb", params: %{"room_type" => "cathedral", "wet" => 0.4}}
        ]
      },
      "lo_fi_texture" => %{
        name: "Lo-Fi Texture",
        description: "Vintage lo-fi character",
        effects: [
          %{type: "bitcrusher", params: %{"bits" => 8, "sample_rate" => 0.5}},
          %{type: "tape_saturation", params: %{"drive" => 0.8, "wow_flutter" => 0.3}},
          %{type: "vintage_delay", params: %{"time" => 0.12, "feedback" => 0.6, "dirt" => 0.4}}
        ]
      },
      "space_ambient" => %{
        name: "Space Ambient",
        description: "Atmospheric space effects",
        effects: [
          %{type: "convolution_reverb", params: %{"room_type" => "cathedral", "wet" => 0.6}},
          %{type: "phaser", params: %{"rate" => 0.2, "depth" => 2000, "feedback" => 0.8}},
          %{type: "stereo_widener", params: %{"width" => 2.0}}
        ]
      }
    }
  end

  defp get_available_effects do
    [
      "parametric_eq",
      "multiband_compressor",
      "convolution_reverb",
      "stereo_widener",
      "tape_saturation",
      "vintage_delay",
      "phaser",
      "flanger",
      "bitcrusher",
      "vocoder",
      "auto_tune",
      "spectral_gate",
      "compressor",
      "limiter",
      "chorus",
      "distortion",
      "filter"
    ]
  end

  # Helper Functions
  defp format_effect_name(effect_type) do
    effect_type
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp format_param_name(param_name) do
    param_name
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp get_effect_param(effect, param_name, default) do
    Map.get(effect.params || %{}, param_name, default)
  end

  defp format_db_value(value) when is_number(value) do
    cond do
      value > 0 -> "+#{Float.round(value, 1)}dB"
      value == 0 -> "0dB"
      true -> "#{Float.round(value, 1)}dB"
    end
  end

  defp format_frequency(freq) when freq >= 1000 do
    "#{Float.round(freq / 1000, 1)}kHz"
  end

  defp format_frequency(freq) do
    "#{round(freq)}Hz"
  end

  defp get_param_min(param_name) do
    case param_name do
      name when name in ["threshold", "low_threshold", "mid_threshold", "high_threshold"] -> "-60"
      name when name in ["ratio", "low_ratio", "mid_ratio", "high_ratio"] -> "1"
      name when name in ["gain", "low_gain", "mid_gain", "high_gain"] -> "-12"
      name when name in ["wet", "dry", "mix", "correction", "speed"] -> "0"
      name when name in ["frequency", "dampening", "tone", "high_cut"] -> "20"
      name when name in ["q"] -> "0.1"
      name when name in ["time", "delay", "predelay"] -> "0"
      name when name in ["bits"] -> "1"
      name when name in ["sample_rate", "sampleRateReduction"] -> "0.1"
      name when name in ["attack"] -> "0.001"
      name when name in ["release"] -> "0.01"
      name when name in ["rate"] -> "0.05"
      name when name in ["depth"] -> "0.001"
      name when name in ["feedback"] -> "0"
      name when name in ["drive"] -> "1"
      name when name in ["warmth"] -> "0"
      name when name in ["width"] -> "0"
      name when name in ["bands"] -> "8"
      name when name in ["carrier_freq", "bass_mono_freq"] -> "50"
      name when name in ["wow_flutter"] -> "0"
      _ -> "0"
    end
  end

  defp get_param_max(param_name) do
    case param_name do
      name when name in ["threshold", "low_threshold", "mid_threshold", "high_threshold"] -> "0"
      name when name in ["ratio", "low_ratio", "mid_ratio", "high_ratio"] -> "20"
      name when name in ["gain", "low_gain", "mid_gain", "high_gain"] -> "12"
      name when name in ["wet", "dry", "mix", "correction", "speed"] -> "1"
      name when name in ["frequency", "dampening"] -> "20000"
      name when name in ["tone", "high_cut"] -> "15000"
      name when name in ["q"] -> "10"
      name when name in ["time", "delay"] -> "2"
      name when name in ["predelay"] -> "0.2"
      name when name in ["bits"] -> "16"
      name when name in ["sample_rate", "sampleRateReduction"] -> "1"
      name when name in ["attack"] -> "0.1"
      name when name in ["release"] -> "1"
      name when name in ["rate"] -> "10"
      name when name in ["depth"] -> "3000"
      name when name in ["feedback"] -> "0.95"
      name when name in ["drive"] -> "5"
      name when name in ["warmth"] -> "6"
      name when name in ["width"] -> "3"
      name when name in ["bands"] -> "32"
      name when name in ["carrier_freq"] -> "1000"
      name when name in ["bass_mono_freq"] -> "300"
      name when name in ["wow_flutter"] -> "0.01"
      _ -> "100"
    end
  end

  defp get_param_step(param_name) do
    case param_name do
      name when name in ["threshold", "low_threshold", "mid_threshold", "high_threshold"] -> "1"
      name when name in ["gain", "low_gain", "mid_gain", "high_gain"] -> "0.1"
      name when name in ["ratio", "low_ratio", "mid_ratio", "high_ratio"] -> "0.1"
      name when name in ["wet", "dry", "mix", "correction", "speed"] -> "0.01"
      name when name in ["frequency", "dampening", "tone", "high_cut"] -> "10"
      name when name in ["q"] -> "0.1"
      name when name in ["time", "delay", "predelay"] -> "0.001"
      name when name in ["bits", "bands"] -> "1"
      name when name in ["sample_rate", "sampleRateReduction"] -> "0.01"
      name when name in ["attack"] -> "0.001"
      name when name in ["release"] -> "0.01"
      name when name in ["rate"] -> "0.1"
      name when name in ["depth"] -> "50"
      name when name in ["feedback"] -> "0.01"
      name when name in ["drive"] -> "0.1"
      name when name in ["warmth"] -> "0.1"
      name when name in ["width"] -> "0.1"
      name when name in ["carrier_freq", "bass_mono_freq"] -> "10"
      name when name in ["wow_flutter"] -> "0.0001"
      _ -> "0.1"
    end
  end

  defp parse_param_value(param_name, value) do
    case param_name do
      name when name in ["bits", "bands"] ->
        String.to_integer(value)
      name when name in ["key", "scale", "room_type"] ->
        value
      _ ->
        String.to_float(value)
    end
  end

  defp format_param_value(param_name, value) do
    case param_name do
      name when name in ["threshold", "low_threshold", "mid_threshold", "high_threshold", "gain", "low_gain", "mid_gain", "high_gain", "warmth"] ->
        format_db_value(value)
      name when name in ["ratio", "low_ratio", "mid_ratio", "high_ratio"] ->
        "#{Float.round(value, 1)}:1"
      name when name in ["wet", "dry", "mix", "correction", "speed", "feedback", "sample_rate", "width"] ->
        "#{round(value * 100)}%"
      name when name in ["frequency", "dampening", "tone", "high_cut", "depth", "carrier_freq", "bass_mono_freq"] ->
        format_frequency(value)
      name when name in ["time", "delay", "predelay", "attack", "release"] ->
        "#{round(value * 1000)}ms"
      name when name in ["q", "drive", "rate"] ->
        "#{Float.round(value, 1)}"
      name when name in ["bits"] ->
        "#{value} bit"
      name when name in ["bands"] ->
        "#{value} bands"
      name when name in ["wow_flutter"] ->
        "#{round(value * 10000) / 100}%"
      name when name in ["key", "scale", "room_type"] ->
        String.capitalize(to_string(value))
      _ ->
        to_string(value)
    end
  end
end
