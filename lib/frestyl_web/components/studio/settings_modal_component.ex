defmodule FrestylWeb.Studio.SettingsModalComponent do
  use FrestylWeb, :live_component

  @impl true
  def mount(socket) do
    {:ok, assign(socket,
      show: false,
      active_tab: "audio",
      loading: false,
      error_message: nil,
      success_message: nil,
      # Audio settings
      audio_devices: [],
      selected_input_device: nil,
      selected_output_device: nil,
      input_volume: 80,
      output_volume: 80,
      monitoring_enabled: true,
      noise_suppression: true,
      echo_cancellation: true,
      sample_rate: 44100,
      buffer_size: 512,
      # General settings
      auto_save_interval: 30,
      show_notifications: true,
      dark_mode: true,
      # Mobile specific
      battery_optimization: false,
      reduced_quality: false,
      simplified_ui: false
    )}
  end

  @impl true
  def update(%{show: show} = assigns, socket) when is_boolean(show) do
    socket = assign(socket, assigns)

    if show and not socket.assigns.show do
      # Load current settings and available devices when modal opens
      send(self(), {:load_audio_devices})
      {:ok, assign(socket, show: show)}
    else
      {:ok, assign(socket, show: show)}
    end
  end

  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
 def handle_event("close_modal", _, socket) do
   send(self(), :close_settings_modal)
   {:noreply, assign(socket, show: false)}
 end

 @impl true
 def handle_event("switch_tab", %{"tab" => tab}, socket) do
   {:noreply, assign(socket, active_tab: tab)}
 end

 @impl true
 def handle_event("update_audio_setting", %{"setting" => setting, "value" => value}, socket) do
   case setting do
     "input_device" ->
       send(self(), {:update_audio_setting, :input_device, value})
       {:noreply, assign(socket, selected_input_device: value)}

     "output_device" ->
       send(self(), {:update_audio_setting, :output_device, value})
       {:noreply, assign(socket, selected_output_device: value)}

     "input_volume" ->
       volume = String.to_integer(value)
       send(self(), {:update_audio_setting, :input_volume, volume})
       {:noreply, assign(socket, input_volume: volume)}

     "output_volume" ->
       volume = String.to_integer(value)
       send(self(), {:update_audio_setting, :output_volume, volume})
       {:noreply, assign(socket, output_volume: volume)}

     "sample_rate" ->
       rate = String.to_integer(value)
       send(self(), {:update_audio_setting, :sample_rate, rate})
       {:noreply, assign(socket, sample_rate: rate)}

     "buffer_size" ->
       size = String.to_integer(value)
       send(self(), {:update_audio_setting, :buffer_size, size})
       {:noreply, assign(socket, buffer_size: size)}

     _ ->
       {:noreply, socket}
   end
 end

 @impl true
 def handle_event("toggle_audio_setting", %{"setting" => setting}, socket) do
   case setting do
     "monitoring" ->
       new_value = !socket.assigns.monitoring_enabled
       send(self(), {:update_audio_setting, :monitoring_enabled, new_value})
       {:noreply, assign(socket, monitoring_enabled: new_value)}

     "noise_suppression" ->
       new_value = !socket.assigns.noise_suppression
       send(self(), {:update_audio_setting, :noise_suppression, new_value})
       {:noreply, assign(socket, noise_suppression: new_value)}

     "echo_cancellation" ->
       new_value = !socket.assigns.echo_cancellation
       send(self(), {:update_audio_setting, :echo_cancellation, new_value})
       {:noreply, assign(socket, echo_cancellation: new_value)}

     "battery_optimization" ->
       new_value = !socket.assigns.battery_optimization
       send(self(), {:update_audio_setting, :battery_optimization, new_value})
       {:noreply, assign(socket, battery_optimization: new_value)}

     "reduced_quality" ->
       new_value = !socket.assigns.reduced_quality
       send(self(), {:update_audio_setting, :reduced_quality, new_value})
       {:noreply, assign(socket, reduced_quality: new_value)}

     "simplified_ui" ->
       new_value = !socket.assigns.simplified_ui
       send(self(), {:update_audio_setting, :simplified_ui, new_value})
       {:noreply, assign(socket, simplified_ui: new_value)}

     _ ->
       {:noreply, socket}
   end
 end

 @impl true
 def handle_event("test_audio_device", %{"type" => type}, socket) do
   device = case type do
     "input" -> socket.assigns.selected_input_device
     "output" -> socket.assigns.selected_output_device
     _ -> nil
   end

   if device do
     send(self(), {:test_audio_device, type, device})
     {:noreply, assign(socket, loading: true)}
   else
     {:noreply, assign(socket, error_message: "Please select a device first")}
   end
 end

 @impl true
 def handle_event("reset_to_defaults", _, socket) do
   defaults = get_default_settings(socket.assigns.is_mobile, socket.assigns.user_tier)

   # Send all defaults to audio engine
   Enum.each(defaults, fn {setting, value} ->
     send(self(), {:update_audio_setting, setting, value})
   end)

   {:noreply, assign(socket, Map.merge(socket.assigns, defaults))}
 end

 @impl true
 def handle_event("save_settings", _, socket) do
   settings = %{
     input_device: socket.assigns.selected_input_device,
     output_device: socket.assigns.selected_output_device,
     input_volume: socket.assigns.input_volume,
     output_volume: socket.assigns.output_volume,
     monitoring_enabled: socket.assigns.monitoring_enabled,
     noise_suppression: socket.assigns.noise_suppression,
     echo_cancellation: socket.assigns.echo_cancellation,
     sample_rate: socket.assigns.sample_rate,
     buffer_size: socket.assigns.buffer_size,
     battery_optimization: socket.assigns.battery_optimization,
     reduced_quality: socket.assigns.reduced_quality,
     simplified_ui: socket.assigns.simplified_ui
   }

   send(self(), {:save_audio_settings, settings})
   {:noreply, assign(socket, success_message: "Settings saved!", loading: true)}
 end

 # Handle messages from parent
 @impl true
 def handle_info({:audio_devices_loaded, devices}, socket) do
   {:noreply, assign(socket, audio_devices: devices, loading: false)}
 end

 @impl true
 def handle_info({:audio_device_test_result, success}, socket) do
   if success do
     {:noreply, assign(socket, success_message: "Device test successful!", loading: false)}
   else
     {:noreply, assign(socket, error_message: "Device test failed", loading: false)}
   end
 end

 @impl true
 def handle_info({:settings_saved}, socket) do
   {:noreply, assign(socket, success_message: "Settings saved successfully!", loading: false)}
 end

 defp get_default_settings(is_mobile, user_tier) do
   base_defaults = %{
     input_volume: 80,
     output_volume: 80,
     monitoring_enabled: true,
     noise_suppression: true,
     echo_cancellation: true,
     auto_save_interval: 30,
     show_notifications: true
   }

   mobile_defaults = if is_mobile do
     %{
       sample_rate: 44100,
       buffer_size: 1024,
       battery_optimization: true,
       reduced_quality: user_tier == :free,
       simplified_ui: true
     }
   else
     %{
       sample_rate: 48000,
       buffer_size: 256,
       battery_optimization: false,
       reduced_quality: false,
       simplified_ui: false
     }
   end

   Map.merge(base_defaults, mobile_defaults)
 end

 defp get_available_sample_rates(is_mobile) do
   if is_mobile do
     [22050, 44100, 48000]
   else
     [44100, 48000, 96000, 192000]
   end
 end

 defp get_available_buffer_sizes(is_mobile) do
   if is_mobile do
     [512, 1024, 2048]
   else
     [64, 128, 256, 512, 1024]
   end
 end

 @impl true
 def render(assigns) do
   ~H"""
   <%= if @show do %>
     <div class="fixed inset-0 z-50 overflow-y-auto" role="dialog" aria-modal="true" aria-labelledby="settings-modal-title">
       <!-- Backdrop -->
       <div class="fixed inset-0 bg-black/70 backdrop-blur-sm transition-opacity" phx-click="close_modal" phx-target={@myself}></div>

       <!-- Modal -->
       <div class="flex min-h-full items-center justify-center p-4">
         <div class={[
           "relative w-full bg-black/90 backdrop-blur-xl rounded-2xl shadow-2xl border border-white/20 overflow-hidden",
           @is_mobile && "max-w-sm" || "max-w-2xl"
         ]}>
           <!-- Header -->
           <div class="flex items-center justify-between p-6 border-b border-white/10">
             <h3 id="settings-modal-title" class="text-xl font-bold text-white">Studio Settings</h3>
             <button
               phx-click="close_modal"
               phx-target={@myself}
               class="text-white/60 hover:text-white p-2 rounded-lg hover:bg-white/10 transition-colors"
               aria-label="Close settings"
             >
               <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                 <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
               </svg>
             </button>
           </div>

           <!-- Tab Navigation -->
           <div class="flex border-b border-white/10 bg-black/20">
             <button
               phx-click="switch_tab"
               phx-value-tab="audio"
               phx-target={@myself}
               class={[
                 "flex-1 px-4 py-3 text-sm font-medium transition-colors relative",
                 @active_tab == "audio" && "text-white bg-white/10" || "text-white/60 hover:text-white hover:bg-white/5"
               ]}
             >
               <div class="flex items-center justify-center gap-2">
                 <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                   <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z" />
                 </svg>
                 Audio
               </div>
               <%= if @active_tab == "audio" do %>
                 <div class="absolute bottom-0 left-0 right-0 h-0.5 bg-gradient-to-r from-purple-500 to-pink-600"></div>
               <% end %>
             </button>

             <button
               phx-click="switch_tab"
               phx-value-tab="general"
               phx-target={@myself}
               class={[
                 "flex-1 px-4 py-3 text-sm font-medium transition-colors relative",
                 @active_tab == "general" && "text-white bg-white/10" || "text-white/60 hover:text-white hover:bg-white/5"
               ]}
             >
               <div class="flex items-center justify-center gap-2">
                 <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                   <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
                   <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                 </svg>
                 General
               </div>
               <%= if @active_tab == "general" do %>
                 <div class="absolute bottom-0 left-0 right-0 h-0.5 bg-gradient-to-r from-purple-500 to-pink-600"></div>
               <% end %>
             </button>

             <%= if @is_mobile do %>
               <button
                 phx-click="switch_tab"
                 phx-value-tab="mobile"
                 phx-target={@myself}
                 class={[
                   "flex-1 px-4 py-3 text-sm font-medium transition-colors relative",
                   @active_tab == "mobile" && "text-white bg-white/10" || "text-white/60 hover:text-white hover:bg-white/5"
                 ]}
               >
                 <div class="flex items-center justify-center gap-2">
                   <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                     <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 18h.01M8 21h8a2 2 0 002-2V5a2 2 0 00-2-2H8a2 2 0 00-2 2v14a2 2 0 002 2z" />
                   </svg>
                   Mobile
                 </div>
                 <%= if @active_tab == "mobile" do %>
                   <div class="absolute bottom-0 left-0 right-0 h-0.5 bg-gradient-to-r from-purple-500 to-pink-600"></div>
                 <% end %>
               </button>
             <% end %>
           </div>

           <!-- Content -->
           <div class="p-6 space-y-6 max-h-96 overflow-y-auto">
             <!-- Error/Success Messages -->
             <%= if @error_message do %>
               <div class="bg-red-900/30 border border-red-500/30 rounded-lg p-3 text-red-200 text-sm">
                 <%= @error_message %>
               </div>
             <% end %>

             <%= if @success_message do %>
               <div class="bg-green-900/30 border border-green-500/30 rounded-lg p-3 text-green-200 text-sm">
                 <%= @success_message %>
               </div>
             <% end %>

             <!-- Audio Settings Tab -->
             <%= if @active_tab == "audio" do %>
               <div class="space-y-6">
                 <!-- Audio Devices -->
                 <div>
                   <h4 class="text-white font-medium mb-4 flex items-center gap-2">
                     <svg class="h-5 w-5 text-purple-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                       <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3" />
                     </svg>
                     Audio Devices
                   </h4>

                   <div class="grid gap-4">
                     <!-- Input Device -->
                     <div>
                       <label class="block text-sm font-medium text-white mb-2">Input Device (Microphone)</label>
                       <div class="flex gap-2">
                         <select
                           phx-change="update_audio_setting"
                           phx-target={@myself}
                           name="setting"
                           value="input_device"
                           class="flex-1 bg-white/10 border border-white/20 rounded-lg px-3 py-2 text-white text-sm focus:outline-none focus:ring-2 focus:ring-purple-500"
                         >
                           <option value="">Select input device...</option>
                           <%= for device <- @audio_devices.inputs || [] do %>
                             <option value={device.id} selected={@selected_input_device == device.id}>
                               <%= device.name %>
                             </option>
                           <% end %>
                         </select>
                         <button
                           phx-click="test_audio_device"
                           phx-value-type="input"
                           phx-target={@myself}
                           disabled={is_nil(@selected_input_device) || @loading}
                           class="px-3 py-2 bg-blue-500/20 hover:bg-blue-500/30 disabled:bg-gray-500/20 disabled:cursor-not-allowed text-blue-300 disabled:text-gray-500 rounded-lg text-sm transition-colors"
                         >
                           Test
                         </button>
                       </div>
                     </div>

                     <!-- Output Device -->
                     <div>
                       <label class="block text-sm font-medium text-white mb-2">Output Device (Speakers/Headphones)</label>
                       <div class="flex gap-2">
                         <select
                           phx-change="update_audio_setting"
                           phx-target={@myself}
                           name="setting"
                           value="output_device"
                           class="flex-1 bg-white/10 border border-white/20 rounded-lg px-3 py-2 text-white text-sm focus:outline-none focus:ring-2 focus:ring-purple-500"
                         >
                           <option value="">Select output device...</option>
                           <%= for device <- @audio_devices.outputs || [] do %>
                             <option value={device.id} selected={@selected_output_device == device.id}>
                               <%= device.name %>
                             </option>
                           <% end %>
                         </select>
                         <button
                           phx-click="test_audio_device"
                           phx-value-type="output"
                           phx-target={@myself}
                           disabled={is_nil(@selected_output_device) || @loading}
                           class="px-3 py-2 bg-blue-500/20 hover:bg-blue-500/30 disabled:bg-gray-500/20 disabled:cursor-not-allowed text-blue-300 disabled:text-gray-500 rounded-lg text-sm transition-colors"
                         >
                           Test
                         </button>
                       </div>
                     </div>
                   </div>
                 </div>

                 <!-- Volume Controls -->
                 <div>
                   <h4 class="text-white font-medium mb-4 flex items-center gap-2">
                     <svg class="h-5 w-5 text-green-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                       <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.536 8.464a5 5 0 010 7.072m2.828-9.9a9 9 0 010 12.728M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z" />
                     </svg>
                     Volume & Levels
                   </h4>

                   <div class="grid gap-4">
                     <!-- Input Volume -->
                     <div>
                       <div class="flex justify-between items-center mb-2">
                         <label class="text-sm font-medium text-white">Input Volume</label>
                         <span class="text-sm text-white/70"><%= @input_volume %>%</span>
                       </div>
                       <input
                         type="range"
                         min="0"
                         max="100"
                         value={@input_volume}
                         phx-change="update_audio_setting"
                         phx-target={@myself}
                         name="setting"
                         value="input_volume"
                         class="w-full h-2 bg-white/20 rounded-lg appearance-none cursor-pointer slider"
                       />
                     </div>

                     <!-- Output Volume -->
                     <div>
                       <div class="flex justify-between items-center mb-2">
                         <label class="text-sm font-medium text-white">Output Volume</label>
                         <span class="text-sm text-white/70"><%= @output_volume %>%</span>
                       </div>
                       <input
                         type="range"
                         min="0"
                         max="100"
                         value={@output_volume}
                         phx-change="update_audio_setting"
                         phx-target={@myself}
                         name="setting"
                         value="output_volume"
                         class="w-full h-2 bg-white/20 rounded-lg appearance-none cursor-pointer slider"
                       />
                     </div>
                   </div>
                 </div>

                 <!-- Audio Processing -->
                 <div>
                   <h4 class="text-white font-medium mb-4 flex items-center gap-2">
                     <svg class="h-5 w-5 text-yellow-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                       <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z" />
                     </svg>
                     Audio Processing
                   </h4>

                   <div class="space-y-4">
                     <!-- Monitoring -->
                     <div class="flex items-center justify-between">
                       <div>
                         <label class="text-sm font-medium text-white">Input Monitoring</label>
                         <p class="text-xs text-white/60">Hear your input while recording</p>
                       </div>
                       <button
                         phx-click="toggle_audio_setting"
                         phx-value-setting="monitoring"
                         phx-target={@myself}
                         class={[
                           "relative inline-flex h-6 w-11 items-center rounded-full transition-colors",
                           @monitoring_enabled && "bg-purple-500" || "bg-white/20"
                         ]}
                       >
                         <span class={[
                           "inline-block h-4 w-4 transform rounded-full bg-white transition-transform",
                           @monitoring_enabled && "translate-x-6" || "translate-x-1"
                         ]}></span>
                       </button>
                     </div>

                     <!-- Noise Suppression -->
                     <div class="flex items-center justify-between">
                       <div>
                         <label class="text-sm font-medium text-white">Noise Suppression</label>
                         <p class="text-xs text-white/60">Reduce background noise</p>
                       </div>
                       <button
                         phx-click="toggle_audio_setting"
                         phx-value-setting="noise_suppression"
                         phx-target={@myself}
                         class={[
                           "relative inline-flex h-6 w-11 items-center rounded-full transition-colors",
                           @noise_suppression && "bg-green-500" || "bg-white/20"
                         ]}
                       >
                         <span class={[
                           "inline-block h-4 w-4 transform rounded-full bg-white transition-transform",
                           @noise_suppression && "translate-x-6" || "translate-x-1"
                         ]}></span>
                       </button>
                     </div>

                     <!-- Echo Cancellation -->
                     <div class="flex items-center justify-between">
                       <div>
                         <label class="text-sm font-medium text-white">Echo Cancellation</label>
                         <p class="text-xs text-white/60">Prevent audio feedback</p>
                       </div>
                       <button
                         phx-click="toggle_audio_setting"
                         phx-value-setting="echo_cancellation"
                         phx-target={@myself}
                         class={[
                           "relative inline-flex h-6 w-11 items-center rounded-full transition-colors",
                           @echo_cancellation && "bg-blue-500" || "bg-white/20"
                         ]}
                       >
                         <span class={[
                           "inline-block h-4 w-4 transform rounded-full bg-white transition-transform",
                           @echo_cancellation && "translate-x-6" || "translate-x-1"
                         ]}></span>
                       </button>
                     </div>
                   </div>
                 </div>

                 <!-- Advanced Audio Settings -->
                 <div>
                   <h4 class="text-white font-medium mb-4 flex items-center gap-2">
                     <svg class="h-5 w-5 text-red-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                       <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 100 4m0-4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 100 4m0-4v2m0-6V4" />
                     </svg>
                     Advanced Settings
                     <%= if @user_tier == :free do %>
                       <span class="text-xs bg-yellow-500/20 text-yellow-300 px-2 py-1 rounded-full">Pro Feature</span>
                     <% end %>
                   </h4>

                   <div class="grid gap-4">
                     <!-- Sample Rate -->
                     <div>
                       <label class="block text-sm font-medium text-white mb-2">Sample Rate</label>
                       <select
                         phx-change="update_audio_setting"
                         phx-target={@myself}
                         name="setting"
                         value="sample_rate"
                         disabled={@user_tier == :free}
                         class={[
                           "w-full bg-white/10 border border-white/20 rounded-lg px-3 py-2 text-white text-sm focus:outline-none focus:ring-2 focus:ring-purple-500",
                           @user_tier == :free && "opacity-50 cursor-not-allowed"
                         ]}
                       >
                         <%= for rate <- get_available_sample_rates(@is_mobile) do %>
                           <option value={rate} selected={@sample_rate == rate}>
                             <%= rate %> Hz
                           </option>
                         <% end %>
                       </select>
                       <%= if @user_tier == :free do %>
                         <p class="text-xs text-yellow-300 mt-1">Upgrade to Pro for high-quality audio</p>
                       <% end %>
                     </div>

                     <!-- Buffer Size -->
                     <div>
                       <label class="block text-sm font-medium text-white mb-2">Buffer Size</label>
                       <select
                         phx-change="update_audio_setting"
                         phx-target={@myself}
                         name="setting"
                         value="buffer_size"
                         disabled={@user_tier == :free}
                         class={[
                           "w-full bg-white/10 border border-white/20 rounded-lg px-3 py-2 text-white text-sm focus:outline-none focus:ring-2 focus:ring-purple-500",
                           @user_tier == :free && "opacity-50 cursor-not-allowed"
                         ]}
                       >
                         <%= for size <- get_available_buffer_sizes(@is_mobile) do %>
                           <option value={size} selected={@buffer_size == size}>
                             <%= size %> samples
                             <%= cond do %>
                               <% size <= 128 -> %>(Low Latency)
                               <% size <= 512 -> %>(Balanced)
                               <% true -> %>(High Stability)
                             <% end %>
                           </option>
                         <% end %>
                       </select>
                       <p class="text-xs text-white/60 mt-1">Lower = less delay, Higher = more stable</p>
                     </div>
                   </div>
                 </div>
               </div>
             <% end %>

             <!-- General Settings Tab -->
             <%= if @active_tab == "general" do %>
               <div class="space-y-6">
                 <!-- Auto-save -->
                 <div>
                   <h4 class="text-white font-medium mb-4 flex items-center gap-2">
                     <svg class="h-5 w-5 text-blue-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                       <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-3m-1 4l-3 3m0 0l-3-3m3 3V4" />
                     </svg>
                     Auto-save & Backup
                   </h4>

                   <div class="space-y-4">
                     <div>
                       <div class="flex justify-between items-center mb-2">
                         <label class="text-sm font-medium text-white">Auto-save Interval</label>
                         <span class="text-sm text-white/70"><%= @auto_save_interval %> seconds</span>
                       </div>
                       <input
                         type="range"
                         min="10"
                         max="300"
                         step="10"
                         value={@auto_save_interval}
                         phx-change="update_general_setting"
                         phx-target={@myself}
                         name="setting"
                         value="auto_save_interval"
                         class="w-full h-2 bg-white/20 rounded-lg appearance-none cursor-pointer slider"
                       />
                       <div class="flex justify-between text-xs text-white/50 mt-1">
                         <span>10s</span>
                         <span>5min</span>
                       </div>
                     </div>
                   </div>
                 </div>

                 <!-- Notifications -->
                 <div>
                   <h4 class="text-white font-medium mb-4 flex items-center gap-2">
                     <svg class="h-5 w-5 text-purple-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                       <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" />
                     </svg>
                     Notifications
                   </h4>

                   <div class="space-y-4">
                     <div class="flex items-center justify-between">
                       <div>
                         <label class="text-sm font-medium text-white">Show Notifications</label>
                         <p class="text-xs text-white/60">Get notified about activity</p>
                       </div>
                       <button
                         phx-click="toggle_general_setting"
                         phx-value-setting="notifications"
                         phx-target={@myself}
                         class={[
                           "relative inline-flex h-6 w-11 items-center rounded-full transition-colors",
                           @show_notifications && "bg-purple-500" || "bg-white/20"
                         ]}
                       >
                         <span class={[
                           "inline-block h-4 w-4 transform rounded-full bg-white transition-transform",
                           @show_notifications && "translate-x-6" || "translate-x-1"
                         ]}></span>
                       </button>
                     </div>
                   </div>
                 </div>

                 <!-- Keyboard Shortcuts -->
                 <div>
                   <h4 class="text-white font-medium mb-4 flex items-center gap-2">
                     <svg class="h-5 w-5 text-green-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                       <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 9l4-4 4 4m0 6l-4 4-4-4" />
                     </svg>
                     Keyboard Shortcuts
                   </h4>

                   <div class="bg-white/5 rounded-lg p-4 space-y-2 text-sm">
                     <div class="flex justify-between">
                       <span class="text-white/70">Play/Pause</span>
                       <kbd class="bg-white/10 px-2 py-1 rounded text-white text-xs">Space</kbd>
                     </div>
                     <div class="flex justify-between">
                       <span class="text-white/70">Record</span>
                       <kbd class="bg-white/10 px-2 py-1 rounded text-white text-xs">R</kbd>
                     </div>
                     <div class="flex justify-between">
                       <span class="text-white/70">Save</span>
                       <kbd class="bg-white/10 px-2 py-1 rounded text-white text-xs">Ctrl + S</kbd>
                     </div>
                     <div class="flex justify-between">
                       <span class="text-white/70">Undo</span>
                       <kbd class="bg-white/10 px-2 py-1 rounded text-white text-xs">Ctrl + Z</kbd>
                     </div>
                   </div>
                 </div>
               </div>
             <% end %>

             <!-- Mobile Settings Tab -->
             <%= if @active_tab == "mobile" and @is_mobile do %>
               <div class="space-y-6">
                 <!-- Performance Optimization -->
                 <div>
                   <h4 class="text-white font-medium mb-4 flex items-center gap-2">
                     <svg class="h-5 w-5 text-green-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                       <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
                     </svg>
                     Performance
                   </h4>

                   <div class="space-y-4">
                     <div class="flex items-center justify-between">
                       <div>
                         <label class="text-sm font-medium text-white">Battery Optimization</label>
                         <p class="text-xs text-white/60">Reduce power consumption</p>
                       </div>
                       <button
                         phx-click="toggle_audio_setting"
                         phx-value-setting="battery_optimization"
                         phx-target={@myself}
                         class={[
                           "relative inline-flex h-6 w-11 items-center rounded-full transition-colors",
                           @battery_optimization && "bg-green-500" || "bg-white/20"
                         ]}
                       >
                         <span class={[
                           "inline-block h-4 w-4 transform rounded-full bg-white transition-transform",
                           @battery_optimization && "translate-x-6" || "translate-x-1"
                         ]}></span>
                       </button>
                     </div>

                     <div class="flex items-center justify-between">
                       <div>
                         <label class="text-sm font-medium text-white">Reduced Quality Mode</label>
                         <p class="text-xs text-white/60">Lower quality for better performance</p>
                       </div>
                       <button
                         phx-click="toggle_audio_setting"
                         phx-value-setting="reduced_quality"
                         phx-target={@myself}
                         class={[
                           "relative inline-flex h-6 w-11 items-center rounded-full transition-colors",
                           @reduced_quality && "bg-yellow-500" || "bg-white/20"
                         ]}
                       >
                         <span class={[
                           "inline-block h-4 w-4 transform rounded-full bg-white transition-transform",
                           @reduced_quality && "translate-x-6" || "translate-x-1"
                         ]}></span>
                       </button>
                     </div>

                     <div class="flex items-center justify-between">
                       <div>
                         <label class="text-sm font-medium text-white">Simplified Interface</label>
                         <p class="text-xs text-white/60">Hide advanced controls</p>
                       </div>
                       <button
                         phx-click="toggle_audio_setting"
                         phx-value-setting="simplified_ui"
                         phx-target={@myself}
                         class={[
                           "relative inline-flex h-6 w-11 items-center rounded-full transition-colors",
                           @simplified_ui && "bg-blue-500" || "bg-white/20"
                         ]}
                       >
                         <span class={[
                           "inline-block h-4 w-4 transform rounded-full bg-white transition-transform",
                           @simplified_ui && "translate-x-6" || "translate-x-1"
                         ]}></span>
                       </button>
                     </div>
                   </div>
                 </div>

                 <!-- Mobile-specific Tips -->
                 <div>
                   <h4 class="text-white font-medium mb-4 flex items-center gap-2">
                     <svg class="h-5 w-5 text-yellow-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                       <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z" />
                     </svg>
                     Tips for Mobile Recording
                   </h4>

                   <div class="bg-yellow-500/10 border border-yellow-500/20 rounded-lg p-4 space-y-2 text-sm">
                     <div class="flex items-start gap-2">
                       <svg class="h-4 w-4 text-yellow-400 mt-0.5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                         <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                       </svg>
                       <p class="text-yellow-200">Use headphones to prevent feedback</p>
                     </div>
                     <div class="flex items-start gap-2">
                       <svg class="h-4 w-4 text-yellow-400 mt-0.5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                         <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                       </svg>
                       <p class="text-yellow-200">Close other apps for best performance</p>
                     </div>
                     <div class="flex items-start gap-2">
                       <svg class="h-4 w-4 text-yellow-400 mt-0.5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                         <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                       </svg>
                       <p class="text-yellow-200">Keep device charged during long sessions</p>
                     </div>
                   </div>
                 </div>
               </div>
             <% end %>
           </div>

           <!-- Footer -->
           <div class="flex items-center justify-between gap-3 px-6 py-4 border-t border-white/10 bg-black/30">
             <button
               phx-click="reset_to_defaults"
               phx-target={@myself}
               class="text-white/70 hover:text-white font-medium text-sm transition-colors"
               disabled={@loading}
             >
               Reset to Defaults
             </button>

             <div class="flex gap-3">
               <button
                 phx-click="close_modal"
                 phx-target={@myself}
                 class="px-4 py-2 text-white/70 hover:text-white font-medium transition-colors"
                 disabled={@loading}
               >
                 Cancel
               </button>

               <button
                 phx-click="save_settings"
                 phx-target={@myself}
                 disabled={@loading}
                 class={[
                   "px-6 py-2 rounded-lg font-medium transition-all duration-200",
                   !@loading && "bg-gradient-to-r from-purple-500 to-pink-600 hover:from-purple-600 hover:to-pink-700 text-white shadow-lg",
                   @loading && "bg-gray-600 text-gray-400 cursor-not-allowed"
                 ]}
               >
                 <%= if @loading do %>
                   <svg class="animate-spin h-4 w-4 mr-2 inline" fill="none" viewBox="0 0 24 24">
                     <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                     <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                   </svg>
                   Saving...
                 <% else %>
                   Save Settings
                 <% end %>
               </button>
             </div>
           </div>
         </div>
       </div>
     </div>
   <% end %>
   """
 end
end
