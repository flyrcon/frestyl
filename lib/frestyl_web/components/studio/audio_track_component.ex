defmodule FrestylWeb.Studio.AudioTrackComponent do
 use FrestylWeb, :live_component

 @impl true
 def mount(socket) do
   {:ok, assign(socket,
     # UI state
     expanded: false,
     show_effects: false,
     show_automation: false,
     selected_clip: nil,
     dragging_clip: nil,
     zoom_level: 1.0,
     # Audio state
     input_level: 0,
     output_level: 0,
     peak_level: 0,
     is_recording: false,
     is_monitoring: false,
     # Track settings
     track_color: generate_track_color(),
     waveform_data: [],
     # Mobile specific
     mobile_view_mode: "simple", # simple, detailed, waveform
     touch_start: nil,
     last_touch_time: 0
   )}
 end

 @impl true
 def update(assigns, socket) do
   track = assigns.track

   # Update track-specific state
   socket = socket
     |> assign(assigns)
     |> assign_track_state(track)
     |> maybe_update_waveform(track)

   {:ok, socket}
 end

 @impl true
 def handle_event("toggle_mute", _, socket) do
   if can_edit_audio?(socket.assigns.permissions) do
     track_id = socket.assigns.track.id
     new_muted = !socket.assigns.track.muted

     send(self(), {:update_track_property, track_id, :muted, new_muted})
     {:noreply, socket}
   else
     {:noreply, socket}
   end
 end

 @impl true
 def handle_event("toggle_solo", _, socket) do
   if can_edit_audio?(socket.assigns.permissions) do
     track_id = socket.assigns.track.id
     new_solo = !socket.assigns.track.solo

     send(self(), {:update_track_property, track_id, :solo, new_solo})
     {:noreply, socket}
   else
     {:noreply, socket}
   end
 end

 @impl true
 def handle_event("update_volume", %{"volume" => volume}, socket) do
   if can_edit_audio?(socket.assigns.permissions) do
     track_id = socket.assigns.track.id
     volume_float = String.to_float(volume) / 100.0

     send(self(), {:update_track_property, track_id, :volume, volume_float})
     {:noreply, socket}
   else
     {:noreply, socket}
   end
 end

 @impl true
 def handle_event("update_pan", %{"pan" => pan}, socket) do
   if can_edit_audio?(socket.assigns.permissions) do
     track_id = socket.assigns.track.id
     pan_float = String.to_float(pan) / 100.0

     send(self(), {:update_track_property, track_id, :pan, pan_float})
     {:noreply, socket}
   else
     {:noreply, socket}
   end
 end

 @impl true
 def handle_event("toggle_expanded", _, socket) do
   {:noreply, assign(socket, expanded: !socket.assigns.expanded)}
 end

 @impl true
 def handle_event("toggle_effects", _, socket) do
   {:noreply, assign(socket, show_effects: !socket.assigns.show_effects)}
 end

 @impl true
 def handle_event("start_recording", _, socket) do
   if can_record_audio?(socket.assigns.permissions) do
     track_id = socket.assigns.track.id
     user_id = socket.assigns.current_user.id

     send(self(), {:start_recording, track_id, user_id})
     {:noreply, assign(socket, is_recording: true)}
   else
     {:noreply, socket}
   end
 end

 @impl true
 def handle_event("stop_recording", _, socket) do
   track_id = socket.assigns.track.id
   user_id = socket.assigns.current_user.id

   send(self(), {:stop_recording, track_id, user_id})
   {:noreply, assign(socket, is_recording: false)}
 end

 @impl true
 def handle_event("delete_track", _, socket) do
   if can_edit_audio?(socket.assigns.permissions) do
     track_id = socket.assigns.track.id
     send(self(), {:delete_track, track_id})
     {:noreply, socket}
   else
     {:noreply, socket}
   end
 end

 @impl true
 def handle_event("select_clip", %{"clip_id" => clip_id}, socket) do
   {:noreply, assign(socket, selected_clip: clip_id)}
 end

 @impl true
 def handle_event("delete_clip", %{"clip_id" => clip_id}, socket) do
   if can_edit_audio?(socket.assigns.permissions) do
     track_id = socket.assigns.track.id
     send(self(), {:delete_clip, track_id, clip_id})
     {:noreply, assign(socket, selected_clip: nil)}
   else
     {:noreply, socket}
   end
 end

 # Mobile-specific events
 @impl true
 def handle_event("mobile_switch_view", %{"mode" => mode}, socket) do
   {:noreply, assign(socket, mobile_view_mode: mode)}
 end

 @impl true
 def handle_event("mobile_track_action", %{"action" => action}, socket) do
   case action do
     "record" -> handle_event("start_recording", %{}, socket)
     "stop" -> handle_event("stop_recording", %{}, socket)
     "mute" -> handle_event("toggle_mute", %{}, socket)
     "solo" -> handle_event("toggle_solo", %{}, socket)
     _ -> {:noreply, socket}
   end
 end

 # Touch events for mobile waveform interaction
 @impl true
 def handle_event("waveform_touch_start", %{"x" => x, "timestamp" => timestamp}, socket) do
   {:noreply, assign(socket, touch_start: x, last_touch_time: timestamp)}
 end

 @impl true
 def handle_event("waveform_touch_end", %{"x" => x, "timestamp" => timestamp}, socket) do
   # Handle tap vs drag
   time_diff = timestamp - socket.assigns.last_touch_time
   distance = abs(x - (socket.assigns.touch_start || x))

   if time_diff < 300 && distance < 10 do
     # Quick tap - seek to position
     position = calculate_time_from_position(x, socket.assigns.track, socket.assigns.zoom_level)
     send(self(), {:seek_to_position, position})
   end

   {:noreply, assign(socket, touch_start: nil)}
 end

 # Level updates from audio engine
 @impl true
 def handle_info({:audio_levels, track_id, input_level, output_level}, socket) do
   if track_id == socket.assigns.track.id do
     peak_level = max(socket.assigns.peak_level * 0.95, output_level)

     {:noreply, assign(socket,
       input_level: input_level,
       output_level: output_level,
       peak_level: peak_level
     )}
   else
     {:noreply, socket}
   end
 end

 defp assign_track_state(socket, track) do
   assign(socket,
     is_recording: socket.assigns.recording_track == track.id,
     is_monitoring: Map.get(track, :monitoring, false)
   )
 end

 defp maybe_update_waveform(socket, track) do
   # Only update waveform if clips have changed
   current_clips = Enum.map(track.clips || [], & &1.id)
   previous_clips = Enum.map(socket.assigns.waveform_data, & &1.clip_id)

   if current_clips != previous_clips do
     # Request waveform data for new clips
     Enum.each(track.clips || [], fn clip ->
       if not Enum.any?(socket.assigns.waveform_data, &(&1.clip_id == clip.id)) do
         send(self(), {:request_waveform, track.id, clip.id})
       end
     end)

     socket
   else
     socket
   end
 end

 defp can_edit_audio?(permissions), do: :edit_audio in permissions
 defp can_record_audio?(permissions), do: :record_audio in permissions

 defp generate_track_color do
   colors = [
     "#3B82F6", "#8B5CF6", "#EF4444", "#10B981",
     "#F59E0B", "#EC4899", "#06B6D4", "#84CC16"
   ]
   Enum.random(colors)
 end

 defp calculate_time_from_position(x, track, zoom_level) do
   # Convert pixel position to time based on track length and zoom
   track_duration = get_track_duration(track)
   viewport_width = 800 # Default viewport width

   (x / viewport_width) * track_duration / zoom_level
 end

 defp get_track_duration(track) do
   case track.clips do
     [] -> 60.0 # Default 60 seconds for empty track
     clips ->
       clips
       |> Enum.map(fn clip -> (clip.start_time || 0) + (clip.duration || 0) end)
       |> Enum.max()
   end
 end

 defp format_time(seconds) when is_number(seconds) do
   minutes = div(trunc(seconds), 60)
   seconds = rem(trunc(seconds), 60)
   "#{minutes}:#{String.pad_leading(Integer.to_string(seconds), 2, "0")}"
 end
 defp format_time(_), do: "0:00"

 defp format_db_level(level) when is_number(level) and level > 0 do
   db = 20 * :math.log10(level)
   "#{Float.round(db, 1)} dB"
 end
 defp format_db_level(_), do: "-∞ dB"

 @impl true
 def render(assigns) do
   ~H"""
   <div
     class={[
       "bg-black/20 backdrop-blur-sm border border-white/10 rounded-xl transition-all duration-300",
       @expanded && "bg-black/40",
       @is_recording && "ring-2 ring-red-500/50",
       @track.solo && "ring-2 ring-yellow-500/50"
     ]}
     style={"border-left: 4px solid #{@track_color};"}
     id={"track-#{@track.id}"}
     phx-hook="AudioTrack"
     data-track-id={@track.id}
   >
     <!-- Desktop Layout -->
     <%= if not @is_mobile do %>
       <!-- Track Header -->
       <div class="flex items-center gap-3 p-4">
         <!-- Track Number & Color -->
         <div
           class="w-8 h-8 rounded-lg flex items-center justify-center text-white font-bold text-sm shadow-lg"
           style={"background: #{@track_color};"}
         >
           <%= @track.number %>
         </div>

         <!-- Track Name -->
         <div class="flex-1 min-w-0">
           <h3 class="text-white font-semibold truncate"><%= @track.name %></h3>
           <p class="text-white/60 text-sm">
             <%= length(@track.clips || []) %> clips • <%= format_time(get_track_duration(@track)) %>
           </p>
         </div>

         <!-- Level Meters -->
         <div class="flex items-center gap-2">
           <!-- Input Level -->
           <%= if @input_level > 0 do %>
             <div class="w-16 h-2 bg-black/30 rounded-full overflow-hidden">
               <div
                 class={[
                   "h-full transition-all duration-75 rounded-full",
                   @input_level > 0.8 && "bg-red-500" || @input_level > 0.6 && "bg-yellow-500" || "bg-green-500"
                 ]}
                 style={"width: #{@input_level * 100}%;"}
               ></div>
             </div>
           <% end %>

           <!-- Output Level -->
           <div class="w-16 h-2 bg-black/30 rounded-full overflow-hidden">
             <div
               class={[
                 "h-full transition-all duration-75 rounded-full",
                 @output_level > 0.8 && "bg-red-500" || @output_level > 0.6 && "bg-yellow-500" || "bg-green-500"
               ]}
               style={"width: #{@output_level * 100}%;"}
             ></div>
           </div>

           <!-- Peak Indicator -->
           <%= if @peak_level > 0.95 do %>
             <div class="w-2 h-2 bg-red-500 rounded-full animate-pulse" title="Peak clipping detected"></div>
           <% end %>
         </div>

         <!-- Quick Controls -->
         <div class="flex items-center gap-2">
           <!-- Record Button -->
           <%= if can_record_audio?(@permissions) do %>
             <button
               phx-click={@is_recording && "stop_recording" || "start_recording"}
               phx-target={@myself}
               class={[
                 "w-8 h-8 rounded-full flex items-center justify-center transition-all duration-200",
                 @is_recording && "bg-red-500 hover:bg-red-600 animate-pulse" || "bg-white/10 hover:bg-red-500/20 text-white/60 hover:text-red-400"
               ]}
               title={@is_recording && "Stop recording" || "Start recording"}
             >
               <%= if @is_recording do %>
                 <div class="w-3 h-3 bg-white rounded-sm"></div>
               <% else %>
                 <div class="w-3 h-3 bg-current rounded-full"></div>
               <% end %>
             </button>
           <% end %>

           <!-- Mute Button -->
           <button
             phx-click="toggle_mute"
             phx-target={@myself}
             disabled={not can_edit_audio?(@permissions)}
             class={[
               "w-8 h-8 rounded-lg flex items-center justify-center transition-colors",
               @track.muted && "bg-red-500/20 text-red-400" || "bg-white/10 hover:bg-white/20 text-white/60 hover:text-white",
               not can_edit_audio?(@permissions) && "opacity-50 cursor-not-allowed"
             ]}
             title={@track.muted && "Unmute track" || "Mute track"}
           >
             <%= if @track.muted do %>
               <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                 <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z" />
                 <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2" />
               </svg>
             <% else %>
               <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                 <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.536 8.464a5 5 0 010 7.072m2.828-9.9a9 9 0 010 12.728M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z" />
               </svg>
             <% end %>
           </button>

           <!-- Solo Button -->
           <button
             phx-click="toggle_solo"
             phx-target={@myself}
             disabled={not can_edit_audio?(@permissions)}
             class={[
               "w-8 h-8 rounded-lg flex items-center justify-center transition-colors text-xs font-bold",
               @track.solo && "bg-yellow-500/20 text-yellow-400" || "bg-white/10 hover:bg-white/20 text-white/60 hover:text-white",
               not can_edit_audio?(@permissions) && "opacity-50 cursor-not-allowed"
             ]}
             title={@track.solo && "Unsolo track" || "Solo track"}
           >
             S
           </button>

           <!-- Expand Button -->
           <button
             phx-click="toggle_expanded"
             phx-target={@myself}
             class="w-8 h-8 rounded-lg flex items-center justify-center bg-white/10 hover:bg-white/20 text-white/60 hover:text-white transition-colors"
             title={@expanded && "Collapse track" || "Expand track"}
           >
             <svg class={[
               "h-4 w-4 transition-transform",
               @expanded && "rotate-180"
             ]} fill="none" stroke="currentColor" viewBox="0 0 24 24">
               <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
             </svg>
           </button>
         </div>
       </div>

       <!-- Expanded Controls -->
       <%= if @expanded do %>
         <div class="px-4 pb-4 space-y-4 border-t border-white/10 pt-4">
           <!-- Volume and Pan Controls -->
           <div class="grid grid-cols-2 gap-4">
             <!-- Volume -->
             <div>
               <div class="flex justify-between items-center mb-2">
                 <label class="text-sm font-medium text-white">Volume</label>
                 <span class="text-sm text-white/70"><%= round((@track.volume || 0.8) * 100) %>%</span>
               </div>
               <input
                 type="range"
                 min="0"
                 max="100"
                 value={round((@track.volume || 0.8) * 100)}
                 phx-change="update_volume"
                 phx-target={@myself}
                 disabled={not can_edit_audio?(@permissions)}
                 class="w-full h-2 bg-white/20 rounded-lg appearance-none cursor-pointer slider"
               />
             </div>

             <!-- Pan -->
             <div>
               <div class="flex justify-between items-center mb-2">
                 <label class="text-sm font-medium text-white">Pan</label>
                 <span class="text-sm text-white/70">
                   <%= cond do %>
                     <% (@track.pan || 0) > 0.1 -> %>R<%= round((@track.pan || 0) * 100) %>
                     <% (@track.pan || 0) < -0.1 -> %>L<%= round(abs(@track.pan || 0) * 100) %>
                     <% true -> %>Center
                   <% end %>
                 </span>
               </div>
               <input
                 type="range"
                 min="-100"
                 max="100"
                 value={round((@track.pan || 0) * 100)}
                 phx-change="update_pan"
                 phx-target={@myself}
                 disabled={not can_edit_audio?(@permissions)}
                 class="w-full h-2 bg-white/20 rounded-lg appearance-none cursor-pointer slider"
               />
             </div>
           </div>

           <!-- Effects and Actions -->
           <div class="flex items-center justify-between">
             <div class="flex items-center gap-2">
               <button
                 phx-click="toggle_effects"
                 phx-target={@myself}
                 class={[
                   "px-3 py-1.5 rounded-lg text-sm font-medium transition-colors",
                   @show_effects && "bg-purple-500/20 text-purple-300" || "bg-white/10 text-white/70 hover:text-white hover:bg-white/20"
                 ]}
               >
                 Effects
               </button>

               <%= if @show_effects do %>
                 <div class="text-white/60 text-sm">
                   <%= length(@track.effects || []) %> active
                 </div>
               <% end %>
             </div>

             <%= if can_edit_audio?(@permissions) do %>
               <button
                 phx-click="delete_track"
                 phx-target={@myself}
                 data-confirm="Are you sure you want to delete this track?"
                 class="px-3 py-1.5 rounded-lg text-sm font-medium bg-red-500/20 text-red-300 hover:bg-red-500/30 hover:text-red-200 transition-colors"
               >
                 Delete Track
               </button>
             <% end %>
           </div>
         </div>
       <% end %>

       <!-- Waveform Area -->
       <div class="relative bg-black/10 border-t border-white/10">
         <%= if length(@track.clips || []) > 0 do %>
           <!-- Waveform Container -->
           <div
             class="relative h-24 overflow-hidden"
             phx-hook="WaveformCanvas"
             data-track-id={@track.id}
             data-zoom-level={@zoom_level}
             id={"waveform-#{@track.id}"}
           >
             <!-- Audio Clips -->
             <%= for clip <- @track.clips || [] do %>
               <div
                 class={[
                   "absolute top-2 bottom-2 rounded-lg border transition-all duration-200 cursor-pointer",
                   @selected_clip == clip.id && "border-white/60 bg-white/10" || "border-white/20 bg-white/5 hover:bg-white/10"
                 ]}
                 style={"left: #{calculate_clip_position(clip, @zoom_level)}px; width: #{calculate_clip_width(clip, @zoom_level)}px; background-color: #{@track_color}20;"}
                 phx-click="select_clip"
                 phx-value-clip_id={clip.id}
                 phx-target={@myself}
               >
                 <!-- Clip Content -->
                 <div class="h-full flex items-center justify-between p-2">
                   <div class="text-white text-xs font-medium truncate flex-1">
                     <%= clip.name || "Audio Clip" %>
                   </div>

                   <%= if @selected_clip == clip.id and can_edit_audio?(@permissions) do %>
                     <button
                       phx-click="delete_clip"
                       phx-value-clip_id={clip.id}
                       phx-target={@myself}
                       class="w-4 h-4 rounded-full bg-red-500/30 hover:bg-red-500/50 text-red-300 hover:text-red-200 flex items-center justify-center ml-1"
                       title="Delete clip"
                     >
                       <svg class="h-2.5 w-2.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                         <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                       </svg>
                     </button>
                   <% end %>
                 </div>

                 <!-- Waveform Visualization (Canvas will be injected here by JS hook) -->
                 <canvas
                   class="absolute inset-0 pointer-events-none opacity-70"
                   data-clip-id={clip.id}
                   data-waveform-data={Jason.encode!(get_clip_waveform(@waveform_data, clip.id))}
                 ></canvas>
               </div>
             <% end %>

             <!-- Recording Indicator -->
             <%= if @is_recording do %>
               <div class="absolute inset-0 bg-red-500/10 border-2 border-red-500/30 rounded-lg animate-pulse">
                 <div class="absolute inset-0 flex items-center justify-center">
                   <div class="bg-red-500/90 text-white px-3 py-1 rounded-full text-sm font-medium flex items-center gap-2">
                     <div class="w-2 h-2 bg-white rounded-full animate-pulse"></div>
                     Recording...
                   </div>
                 </div>
               </div>
             <% end %>

             <!-- Time Markers -->
             <div class="absolute top-0 left-0 right-0 h-4 border-b border-white/10 bg-black/20">
               <%= for time <- generate_time_markers(get_track_duration(@track), @zoom_level) do %>
                 <div
                   class="absolute top-0 bottom-0 w-px bg-white/20"
                   style={"left: #{time.position}px;"}
                 >
                   <span class="absolute -top-4 left-1 text-xs text-white/60">
                     <%= format_time(time.seconds) %>
                   </span>
                 </div>
               <% end %>
             </div>
           </div>
         <% else %>
           <!-- Empty Track -->
           <div class="h-24 flex items-center justify-center text-white/40 border-t border-white/10">
             <div class="text-center">
               <svg class="h-8 w-8 mx-auto mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                 <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z" />
               </svg>
               <p class="text-sm">No audio clips</p>
               <%= if can_record_audio?(@permissions) do %>
                 <button
                   phx-click="start_recording"
                   phx-target={@myself}
                   class="mt-2 text-xs text-purple-400 hover:text-purple-300"
                 >
                   Click to record
                 </button>
               <% end %>
             </div>
           </div>
         <% end %>
       </div>

     <% else %>
       <!-- Mobile Layout -->
       <div class="p-3">
         <!-- Mobile Track Header -->
         <div class="flex items-center gap-3 mb-3">
           <!-- Track Color & Number -->
           <div
             class="w-10 h-10 rounded-xl flex items-center justify-center text-white font-bold shadow-lg"
             style={"background: #{@track_color};"}
           >
             <%= @track.number %>
           </div>

           <!-- Track Info -->
           <div class="flex-1 min-w-0">
             <h3 class="text-white font-semibold text-lg truncate"><%= @track.name %></h3>
             <div class="flex items-center gap-3 text-white/60 text-sm">
               <span><%= length(@track.clips || []) %> clips</span>
               <span><%= format_time(get_track_duration(@track)) %></span>
               <%= if @output_level > 0 do %>
                 <span class="text-green-400"><%= format_db_level(@output_level) %></span>
               <% end %>
             </div>
           </div>

           <!-- Mobile View Switcher -->
           <div class="flex bg-white/10 rounded-lg p-1">
             <button
               phx-click="mobile_switch_view"
               phx-value-mode="simple"
               phx-target={@myself}
               class={[
                 "px-2 py-1 rounded text-xs font-medium transition-colors",
                 @mobile_view_mode == "simple" && "bg-white/20 text-white" || "text-white/60"
               ]}
             >
               Simple
             </button>
             <button
               phx-click="mobile_switch_view"
               phx-value-mode="detailed"
               phx-target={@myself}
               class={[
                 "px-2 py-1 rounded text-xs font-medium transition-colors",
                 @mobile_view_mode == "detailed" && "bg-white/20 text-white" || "text-white/60"
               ]}
             >
               Controls
             </button>
             <button
               phx-click="mobile_switch_view"
               phx-value-mode="waveform"
               phx-target={@myself}
               class={[
                 "px-2 py-1 rounded text-xs font-medium transition-colors",
                 @mobile_view_mode == "waveform" && "bg-white/20 text-white" || "text-white/60"
               ]}
             >
               Wave
             </button>
           </div>
         </div>

         <!-- Mobile Level Meter -->
         <%= if @output_level > 0 or @input_level > 0 do %>
           <div class="mb-3">
             <div class="h-3 bg-black/30 rounded-full overflow-hidden relative">
               <!-- Output Level -->
               <div
                 class={[
                   "h-full transition-all duration-75 rounded-full",
                   @output_level > 0.8 && "bg-red-500" || @output_level > 0.6 && "bg-yellow-500" || "bg-green-500"
                 ]}
                 style={"width: #{@output_level * 100}%;"}
               ></div>

               <!-- Input Level Overlay -->
               <%= if @input_level > 0 do %>
                 <div
                   class="absolute top-0 h-1 bg-blue-400 rounded-full"
                   style={"width: #{@input_level * 100}%;"}
                 ></div>
               <% end %>

               <!-- Peak Warning -->
               <%= if @peak_level > 0.95 do %>
                 <div class="absolute right-1 top-0 bottom-0 w-1 bg-red-500 animate-pulse rounded-full"></div>
               <% end %>
             </div>
           </div>
         <% end %>

         <!-- Mobile Content Based on View Mode -->
         <%= case @mobile_view_mode do %>
           <% "simple" -> %>
             <!-- Simple Mobile Controls -->
             <div class="grid grid-cols-2 gap-3">
               <!-- Record/Stop -->
               <%= if can_record_audio?(@permissions) do %>
                 <button
                   phx-click="mobile_track_action"
                   phx-value-action={@is_recording && "stop" || "record"}
                   phx-target={@myself}
                   class={[
                     "flex items-center justify-center gap-2 py-3 rounded-xl font-medium transition-all duration-200",
                     @is_recording && "bg-red-500 hover:bg-red-600 text-white" || "bg-white/10 hover:bg-red-500/20 text-white/80 hover:text-red-300"
                   ]}
                 >
                   <%= if @is_recording do %>
                     <div class="w-4 h-4 bg-white rounded-sm"></div>
                     <span>Stop</span>
                   <% else %>
                     <div class="w-4 h-4 bg-current rounded-full"></div>
                     <span>Record</span>
                   <% end %>
                 </button>
               <% end %>

               <!-- Mute -->
               <button
                 phx-click="mobile_track_action"
                 phx-value-action="mute"
                 phx-target={@myself}
                 disabled={not can_edit_audio?(@permissions)}
                 class={[
                   "flex items-center justify-center gap-2 py-3 rounded-xl font-medium transition-colors",
                   @track.muted && "bg-red-500/20 text-red-300" || "bg-white/10 text-white/80 hover:bg-white/20",
                   not can_edit_audio?(@permissions) && "opacity-50"
                 ]}
               >
                 <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                   <%= if @track.muted do %>
                     <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z" />
                     <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2" />
                   <% else %>
                     <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.536 8.464a5 5 0 010 7.072m2.828-9.9a9 9 0 010 12.728M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z" />
                   <% end %>
                 </svg>
                 <span><%= @track.muted && "Unmute" || "Mute" %></span>
               </button>

               <!-- Solo -->
               <button
                 phx-click="mobile_track_action"
                 phx-value-action="solo"
                 phx-target={@myself}
                 disabled={not can_edit_audio?(@permissions)}
                 class={[
                   "flex items-center justify-center gap-2 py-3 rounded-xl font-medium transition-colors",
                   @track.solo && "bg-yellow-500/20 text-yellow-300" || "bg-white/10 text-white/80 hover:bg-white/20",
                   not can_edit_audio?(@permissions) && "opacity-50"
                 ]}
               >
                 <span class="font-bold">S</span>
                 <span><%= @track.solo && "Unsolo" || "Solo" %></span>
               </button>

               <!-- Volume Control -->
               <div class="bg-white/10 rounded-xl p-3">
                 <div class="text-center text-white/80 text-sm font-medium mb-2">
                   Volume: <%= round((@track.volume || 0.8) * 100) %>%
                 </div>
                 <input
                   type="range"
                   min="0"
                   max="100"
                   value={round((@track.volume || 0.8) * 100)}
                   phx-change="update_volume"
                   phx-target={@myself}
                   disabled={not can_edit_audio?(@permissions)}
                   class="w-full h-2 bg-white/20 rounded-lg appearance-none cursor-pointer slider"
                 />
               </div>
             </div>

           <% "detailed" -> %>
             <!-- Detailed Mobile Controls -->
             <div class="space-y-4">
               <!-- Volume and Pan -->
               <div class="grid grid-cols-2 gap-4">
                 <div class="bg-white/10 rounded-xl p-3">
                   <div class="text-center text-white/80 text-sm font-medium mb-2">
                     Volume: <%= round((@track.volume || 0.8) * 100) %>%
                   </div>
                   <input
                     type="range"
                     min="0"
                     max="100"
                     value={round((@track.volume || 0.8) * 100)}
                     phx-change="update_volume"
                     phx-target={@myself}
                     disabled={not can_edit_audio?(@permissions)}
                     class="w-full h-3 bg-white/20 rounded-lg appearance-none cursor-pointer slider"
                   />
                 </div>

                 <div class="bg-white/10 rounded-xl p-3">
                   <div class="text-center text-white/80 text-sm font-medium mb-2">
                     Pan: <%= cond do %>
                       <% (@track.pan || 0) > 0.1 -> %>R<%= round((@track.pan || 0) * 100) %>
                       <% (@track.pan || 0) < -0.1 -> %>L<%= round(abs(@track.pan || 0) * 100) %>
                       <% true -> %>Center
                     <% end %>
                   </div>
                   <input
                     type="range"
                     min="-100"
                     max="100"
                     value={round((@track.pan || 0) * 100)}
                     phx-change="update_pan"
                     phx-target={@myself}
                     disabled={not can_edit_audio?(@permissions)}
                     class="w-full h-3 bg-white/20 rounded-lg appearance-none cursor-pointer slider"
                   />
                 </div>
               </div>

               <!-- Effects -->
               <div class="bg-white/10 rounded-xl p-3">
                 <div class="flex items-center justify-between mb-3">
                   <span class="text-white font-medium">Effects</span>
                   <span class="text-white/60 text-sm"><%= length(@track.effects || []) %> active</span>
                 </div>

                 <%= if length(@track.effects || []) > 0 do %>
                   <div class="space-y-2">
                     <%= for effect <- @track.effects || [] do %>
                       <div class="flex items-center justify-between py-2 px-3 bg-white/5 rounded-lg">
                         <span class="text-white/80 text-sm"><%= String.capitalize(effect.type) %></span>
                         <button class="text-red-400 hover:text-red-300 text-xs">Remove</button>
                       </div>
                     <% end %>
                   </div>
                 <% else %>
                   <p class="text-white/60 text-sm text-center py-2">No effects applied</p>
                 <% end %>
               </div>

               <!-- Actions -->
               <%= if can_edit_audio?(@permissions) do %>
                 <div class="grid grid-cols-2 gap-3">
                   <button class="py-3 px-4 bg-blue-500/20 text-blue-300 rounded-xl font-medium">
                     Add Effect
                   </button>
                   <button
                     phx-click="delete_track"
                     phx-target={@myself}
                     data-confirm="Delete this track?"
                     class="py-3 px-4 bg-red-500/20 text-red-300 rounded-xl font-medium"
                   >
                     Delete Track
                   </button>
                 </div>
               <% end %>
             </div>

           <% "waveform" -> %>
             <!-- Mobile Waveform View -->
             <div class="bg-black/20 rounded-xl overflow-hidden">
               <%= if length(@track.clips || []) > 0 do %>
                 <div
                   class="relative h-32"
                   phx-hook="MobileWaveform"
                   data-track-id={@track.id}
                   id={"mobile-waveform-#{@track.id}"}
                   phx-click="waveform_touch_start"
                   phx-target={@myself}
                 >
                   <!-- Mobile Audio Clips -->
                   <%= for clip <- @track.clips || [] do %>
                     <div
                       class={[
                         "absolute top-2 bottom-2 rounded-lg border-2 transition-all duration-200",
                         @selected_clip == clip.id && "border-white/80 bg-white/20" || "border-white/30 bg-white/10"
                       ]}
                       style={"left: #{calculate_clip_position(clip, 1.0)}%; width: #{calculate_clip_width(clip, 1.0)}%; background-color: #{@track_color}40;"}
                       phx-click="select_clip"
                       phx-value-clip_id={clip.id}
                       phx-target={@myself}
                     >
                       <div class="h-full flex items-center justify-center">
                         <span class="text-white text-xs font-medium truncate px-2">
                           <%= clip.name || "Clip" %>
                         </span>
                       </div>

                       <!-- Mobile Waveform Canvas -->
                       <canvas
                         class="absolute inset-0 pointer-events-none opacity-80"
                         data-clip-id={clip.id}
                         data-mobile="true"
                       ></canvas>
                     </div>
                   <% end %>

                   <!-- Mobile Recording Indicator -->
                   <%= if @is_recording do %>
                     <div class="absolute inset-0 bg-red-500/20 border-2 border-red-500/50 rounded-lg">
                       <div class="absolute inset-0 flex items-center justify-center">
                         <div class="bg-red-500 text-white px-4 py-2 rounded-full text-sm font-medium flex items-center gap-2">
                           <div class="w-2 h-2 bg-white rounded-full animate-pulse"></div>
                           Recording...
                         </div>
                       </div>
                     </div>
                   <% end %>
                 </div>
               <% else %>
                 <!-- Empty Mobile Waveform -->
                 <div class="h-32 flex items-center justify-center">
                   <div class="text-center text-white/60">
                     <svg class="h-10 w-10 mx-auto mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                       <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3" />
                     </svg>
                     <p class="text-sm">No audio clips</p>
                     <%= if can_record_audio?(@permissions) do %>
                       <button
                         phx-click="start_recording"
                         phx-target={@myself}
                         class="mt-2 text-xs text-purple-400 hover:text-purple-300"
                       >
                         Tap to record
                       </button>
                     <% end %>
                   </div>
                 </div>
               <% end %>
             </div>
         <% end %>
       </div>
     <% end %>
   </div>
   """
 end

 # Helper functions for waveform positioning and rendering
 defp calculate_clip_position(clip, zoom_level) do
   start_time = clip.start_time || 0
   pixels_per_second = 50 * zoom_level  # Base pixels per second
   start_time * pixels_per_second
 end

 defp calculate_clip_width(clip, zoom_level) do
   duration = clip.duration || 1.0
   pixels_per_second = 50 * zoom_level
   max(duration * pixels_per_second, 20)  # Minimum 20px width
 end

 defp get_clip_waveform(waveform_data, clip_id) do
   case Enum.find(waveform_data, &(&1.clip_id == clip_id)) do
     nil -> []
     waveform -> waveform.data || []
   end
 end

 defp generate_time_markers(duration, zoom_level) do
   interval = case zoom_level do
     z when z < 0.5 -> 30  # 30 seconds
     z when z < 1.0 -> 15  # 15 seconds
     z when z < 2.0 -> 10  # 10 seconds
     z when z < 5.0 -> 5   # 5 seconds
     _ -> 1                # 1 second
   end

   0..trunc(duration)
   |> Enum.take_every(interval)
   |> Enum.map(fn seconds ->
     %{
       seconds: seconds,
       position: seconds * 50 * zoom_level  # pixels per second
     }
   end)
 end
end
