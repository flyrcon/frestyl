defmodule FrestylWeb.Studio.BeatMachineComponent do
 use FrestylWeb, :live_component

 @impl true
 def mount(socket) do
   {:ok, assign(socket,
     # UI State
     expanded: false,
     active_pattern: nil,
     selected_instrument: "kick",
     show_pattern_menu: false,
     show_kit_menu: false,
     # Beat Machine State
     current_kit: "classic_808",
     patterns: %{},
     playing: false,
     current_step: 0,
     bpm: 120,
     swing: 0,
     master_volume: 0.8,
     # Pattern Editor
     editing_pattern: nil,
     steps_per_pattern: 16,
     current_page: 0, # For mobile pagination
     # Mobile specific
     mobile_mode: "patterns", # patterns, sequencer, settings
     touch_editing: false,
     selected_steps: [],
     # Available instruments for current kit
     instruments: get_default_instruments(),
     # Pattern clipboard for copy/paste
     clipboard_pattern: nil
   )}
 end

 @impl true
 def update(assigns, socket) do
   # Update beat machine state from parent
   beat_state = assigns.beat_machine_state || %{}

   socket = socket
     |> assign(assigns)
     |> assign_beat_state(beat_state)
     |> maybe_load_patterns(beat_state)

   {:ok, socket}
 end

 @impl true
 def handle_event("toggle_expanded", _, socket) do
   {:noreply, assign(socket, expanded: !socket.assigns.expanded)}
 end

 @impl true
 def handle_event("create_pattern", %{"name" => name}, socket) when name != "" do
   if can_edit_audio?(socket.assigns.permissions) do
     steps = socket.assigns.steps_per_pattern
     session_id = socket.assigns.session.id

     send(self(), {:beat_create_pattern, session_id, name, steps})
     {:noreply, assign(socket, show_pattern_menu: false)}
   else
     {:noreply, socket}
   end
 end

 @impl true
 def handle_event("select_pattern", %{"pattern_id" => pattern_id}, socket) do
   pattern = Map.get(socket.assigns.patterns, pattern_id)

   if pattern do
     {:noreply, assign(socket,
       active_pattern: pattern_id,
       editing_pattern: pattern,
       selected_instrument: get_first_instrument(socket.assigns.instruments)
     )}
   else
     {:noreply, socket}
   end
 end

 @impl true
 def handle_event("play_pattern", %{"pattern_id" => pattern_id}, socket) do
   if can_edit_audio?(socket.assigns.permissions) do
     session_id = socket.assigns.session.id
     send(self(), {:beat_play_pattern, session_id, pattern_id})
     {:noreply, assign(socket, playing: true, active_pattern: pattern_id)}
   else
     {:noreply, socket}
   end
 end

 @impl true
 def handle_event("stop_pattern", _, socket) do
   if can_edit_audio?(socket.assigns.permissions) do
     session_id = socket.assigns.session.id
     send(self(), {:beat_stop_pattern, session_id})
     {:noreply, assign(socket, playing: false, current_step: 0)}
   else
     {:noreply, socket}
   end
 end

 @impl true
 def handle_event("toggle_step", %{"instrument" => instrument, "step" => step}, socket) do
   if can_edit_audio?(socket.assigns.permissions) and socket.assigns.editing_pattern do
     step_num = String.to_integer(step)
     pattern_id = socket.assigns.editing_pattern.id
     session_id = socket.assigns.session.id

     # Get current velocity or toggle between 0 and 127
     current_velocity = get_step_velocity(socket.assigns.editing_pattern, instrument, step_num)
     new_velocity = if current_velocity > 0, do: 0, else: 127

     send(self(), {:beat_update_step, session_id, pattern_id, instrument, step_num, new_velocity})
     {:noreply, socket}
   else
     {:noreply, socket}
   end
 end

 @impl true
 def handle_event("update_step_velocity", %{"instrument" => instrument, "step" => step, "velocity" => velocity}, socket) do
   if can_edit_audio?(socket.assigns.permissions) and socket.assigns.editing_pattern do
     step_num = String.to_integer(step)
     velocity_num = String.to_integer(velocity)
     pattern_id = socket.assigns.editing_pattern.id
     session_id = socket.assigns.session.id

     send(self(), {:beat_update_step, session_id, pattern_id, instrument, step_num, velocity_num})
     {:noreply, socket}
   else
     {:noreply, socket}
   end
 end

 @impl true
 def handle_event("clear_pattern", %{"pattern_id" => pattern_id}, socket) do
   if can_edit_audio?(socket.assigns.permissions) do
     session_id = socket.assigns.session.id
     send(self(), {:beat_clear_pattern, session_id, pattern_id})
     {:noreply, socket}
   else
     {:noreply, socket}
   end
 end

 @impl true
 def handle_event("duplicate_pattern", %{"pattern_id" => pattern_id, "new_name" => new_name}, socket) do
   if can_edit_audio?(socket.assigns.permissions) and new_name != "" do
     session_id = socket.assigns.session.id
     send(self(), {:beat_duplicate_pattern, session_id, pattern_id, new_name})
     {:noreply, socket}
   else
     {:noreply, socket}
   end
 end

 @impl true
 def handle_event("delete_pattern", %{"pattern_id" => pattern_id}, socket) do
   if can_edit_audio?(socket.assigns.permissions) do
     session_id = socket.assigns.session.id
     send(self(), {:beat_delete_pattern, session_id, pattern_id})

     # Clear editing if this was the active pattern
     new_socket = if socket.assigns.active_pattern == pattern_id do
       assign(socket, active_pattern: nil, editing_pattern: nil)
     else
       socket
     end

     {:noreply, new_socket}
   else
     {:noreply, socket}
   end
 end

 @impl true
 def handle_event("change_kit", %{"kit_name" => kit_name}, socket) do
   if can_edit_audio?(socket.assigns.permissions) do
     session_id = socket.assigns.session.id
     send(self(), {:beat_change_kit, session_id, kit_name})

     # Update instruments for new kit
     new_instruments = get_kit_instruments(kit_name)

     {:noreply, assign(socket,
       current_kit: kit_name,
       instruments: new_instruments,
       selected_instrument: get_first_instrument(new_instruments),
       show_kit_menu: false
     )}
   else
     {:noreply, socket}
   end
 end

 @impl true
 def handle_event("update_bpm", %{"bpm" => bpm}, socket) do
   if can_edit_audio?(socket.assigns.permissions) do
     bpm_num = String.to_integer(bpm)
     session_id = socket.assigns.session.id
     send(self(), {:beat_set_bpm, session_id, bpm_num})
     {:noreply, assign(socket, bpm: bpm_num)}
   else
     {:noreply, socket}
   end
 end

 @impl true
 def handle_event("update_swing", %{"swing" => swing}, socket) do
   if can_edit_audio?(socket.assigns.permissions) do
     swing_num = String.to_integer(swing)
     session_id = socket.assigns.session.id
     send(self(), {:beat_set_swing, session_id, swing_num})
     {:noreply, assign(socket, swing: swing_num)}
   else
     {:noreply, socket}
   end
 end

 @impl true
 def handle_event("update_master_volume", %{"volume" => volume}, socket) do
   if can_edit_audio?(socket.assigns.permissions) do
     volume_float = String.to_float(volume) / 100.0
     session_id = socket.assigns.session.id
     send(self(), {:beat_set_master_volume, session_id, volume_float})
     {:noreply, assign(socket, master_volume: volume_float)}
   else
     {:noreply, socket}
   end
 end

 @impl true
 def handle_event("select_instrument", %{"instrument" => instrument}, socket) do
   {:noreply, assign(socket, selected_instrument: instrument)}
 end

 @impl true
 def handle_event("toggle_pattern_menu", _, socket) do
   {:noreply, assign(socket, show_pattern_menu: !socket.assigns.show_pattern_menu)}
 end

 @impl true
 def handle_event("toggle_kit_menu", _, socket) do
   {:noreply, assign(socket, show_kit_menu: !socket.assigns.show_kit_menu)}
 end

 # Mobile-specific events
 @impl true
 def handle_event("mobile_switch_mode", %{"mode" => mode}, socket) do
   {:noreply, assign(socket, mobile_mode: mode)}
 end

 @impl true
 def handle_event("mobile_page_change", %{"direction" => direction}, socket) do
   current_page = socket.assigns.current_page
   max_pages = div(socket.assigns.steps_per_pattern - 1, 8) # 8 steps per mobile page

   new_page = case direction do
     "next" -> min(current_page + 1, max_pages)
     "prev" -> max(current_page - 1, 0)
     _ -> current_page
   end

   {:noreply, assign(socket, current_page: new_page)}
 end

 @impl true
 def handle_event("mobile_multi_select_start", _, socket) do
   {:noreply, assign(socket, touch_editing: true, selected_steps: [])}
 end

 @impl true
 def handle_event("mobile_multi_select_end", _, socket) do
   # Apply action to all selected steps
   if socket.assigns.touch_editing and length(socket.assigns.selected_steps) > 0 do
     # Toggle all selected steps
     instrument = socket.assigns.selected_instrument
     pattern_id = socket.assigns.editing_pattern.id
     session_id = socket.assigns.session.id

     Enum.each(socket.assigns.selected_steps, fn step ->
       send(self(), {:beat_update_step, session_id, pattern_id, instrument, step, 127})
     end)
   end

   {:noreply, assign(socket, touch_editing: false, selected_steps: [])}
 end

 @impl true
 def handle_event("mobile_select_step", %{"step" => step}, socket) do
   if socket.assigns.touch_editing do
     step_num = String.to_integer(step)
     selected_steps = socket.assigns.selected_steps

     new_selected = if step_num in selected_steps do
       List.delete(selected_steps, step_num)
     else
       [step_num | selected_steps]
     end

     {:noreply, assign(socket, selected_steps: new_selected)}
   else
     # Normal step toggle
     handle_event("toggle_step", %{"instrument" => socket.assigns.selected_instrument, "step" => step}, socket)
   end
 end

 # Handle beat machine updates from audio engine
 @impl true
 def handle_info({:beat_pattern_created, pattern}, socket) do
   patterns = Map.put(socket.assigns.patterns, pattern.id, pattern)
   {:noreply, assign(socket, patterns: patterns)}
 end

 @impl true
 def handle_info({:beat_step_updated, pattern_id, instrument, step, velocity}, socket) do
   if socket.assigns.editing_pattern && socket.assigns.editing_pattern.id == pattern_id do
     updated_pattern = update_pattern_step(socket.assigns.editing_pattern, instrument, step, velocity)
     patterns = Map.put(socket.assigns.patterns, pattern_id, updated_pattern)

     {:noreply, assign(socket, editing_pattern: updated_pattern, patterns: patterns)}
   else
     {:noreply, socket}
   end
 end

 @impl true
 def handle_info({:beat_pattern_started, pattern_id}, socket) do
   {:noreply, assign(socket, playing: true, active_pattern: pattern_id, current_step: 0)}
 end

 @impl true
 def handle_info({:beat_pattern_stopped}, socket) do
   {:noreply, assign(socket, playing: false, current_step: 0)}
 end

 @impl true
 def handle_info({:beat_step_triggered, step, _instruments}, socket) do
   {:noreply, assign(socket, current_step: step)}
 end

 defp assign_beat_state(socket, beat_state) do
   assign(socket,
     current_kit: Map.get(beat_state, :current_kit, socket.assigns.current_kit),
     playing: Map.get(beat_state, :playing, socket.assigns.playing),
     current_step: Map.get(beat_state, :current_step, socket.assigns.current_step),
     bpm: Map.get(beat_state, :bpm, socket.assigns.bpm),
     swing: Map.get(beat_state, :swing, socket.assigns.swing),
     master_volume: Map.get(beat_state, :master_volume, socket.assigns.master_volume)
   )
 end

 defp maybe_load_patterns(socket, beat_state) do
   patterns = Map.get(beat_state, :patterns, %{})
   active_pattern = Map.get(beat_state, :active_pattern)

   editing_pattern = if active_pattern && Map.has_key?(patterns, active_pattern) do
     Map.get(patterns, active_pattern)
   else
     socket.assigns.editing_pattern
   end

   assign(socket,
     patterns: patterns,
     active_pattern: active_pattern,
     editing_pattern: editing_pattern
   )
 end

 defp can_edit_audio?(permissions), do: :edit_audio in permissions

 defp get_default_instruments do
   [
     %{id: "kick", name: "Kick", color: "#EF4444"},
     %{id: "snare", name: "Snare", color: "#F59E0B"},
     %{id: "hihat", name: "Hi-Hat", color: "#10B981"},
     %{id: "openhat", name: "Open Hat", color: "#06B6D4"},
     %{id: "crash", name: "Crash", color: "#8B5CF6"},
     %{id: "ride", name: "Ride", color: "#EC4899"},
     %{id: "clap", name: "Clap", color: "#84CC16"},
     %{id: "perc", name: "Perc", color: "#F97316"}
   ]
 end

 defp get_kit_instruments(kit_name) do
   case kit_name do
     "classic_808" -> get_default_instruments()
     "trap" -> [
       %{id: "kick", name: "808 Kick", color: "#EF4444"},
       %{id: "snare", name: "Trap Snare", color: "#F59E0B"},
       %{id: "hihat", name: "Trap Hat", color: "#10B981"},
       %{id: "openhat", name: "Open Hat", color: "#06B6D4"},
       %{id: "rim", name: "Rim Shot", color: "#8B5CF6"},
       %{id: "clap", name: "Hand Clap", color: "#EC4899"},
       %{id: "shaker", name: "Shaker", color: "#84CC16"},
       %{id: "vocal", name: "Vocal Chop", color: "#F97316"}
     ]
     "techno" -> [
       %{id: "kick", name: "Techno Kick", color: "#EF4444"},
       %{id: "snare", name: "Techno Snare", color: "#F59E0B"},
       %{id: "hihat", name: "Techno Hat", color: "#10B981"},
       %{id: "openhat", name: "Open Hat", color: "#06B6D4"},
       %{id: "cymbal", name: "Cymbal", color: "#8B5CF6"},
       %{id: "tom", name: "Tom", color: "#EC4899"},
       %{id: "noise", name: "Noise", color: "#84CC16"},
       %{id: "bass", name: "Bass Hit", color: "#F97316"}
     ]
     _ -> get_default_instruments()
   end
 end

 defp get_first_instrument(instruments) do
   case instruments do
     [first | _] -> first.id
     [] -> "kick"
   end
 end

 defp get_step_velocity(pattern, instrument, step) do
   sequences = pattern.sequences || %{}
   instrument_sequence = Map.get(sequences, instrument, [])
   Enum.at(instrument_sequence, step, 0)
 end

 defp update_pattern_step(pattern, instrument, step, velocity) do
   sequences = pattern.sequences || %{}
   instrument_sequence = Map.get(sequences, instrument, List.duplicate(0, 16))

   # Ensure sequence is long enough
   padded_sequence = instrument_sequence ++ List.duplicate(0, max(0, step + 1 - length(instrument_sequence)))
   updated_sequence = List.replace_at(padded_sequence, step, velocity)

   updated_sequences = Map.put(sequences, instrument, updated_sequence)
   Map.put(pattern, :sequences, updated_sequences)
 end

 defp get_available_kits do
   [
     %{id: "classic_808", name: "Classic 808", description: "Traditional 808 drum sounds"},
     %{id: "trap", name: "Trap Kit", description: "Modern trap and hip-hop sounds"},
     %{id: "techno", name: "Techno Kit", description: "Electronic dance music sounds"},
     %{id: "acoustic", name: "Acoustic Kit", description: "Natural drum kit sounds"},
     %{id: "vintage", name: "Vintage Kit", description: "Classic vintage drum machines"}
   ]
 end

 @impl true
 def render(assigns) do
   ~H"""
   <div class={[
     "bg-black/20 backdrop-blur-sm border border-white/10 rounded-xl transition-all duration-300",
     @expanded && "bg-black/40"
   ]}>
     <!-- Beat Machine Header -->
     <div class="flex items-center justify-between p-4 border-b border-white/10">
       <div class="flex items-center gap-3">
         <div class="p-2 bg-gradient-to-r from-orange-500 to-red-600 rounded-xl">
           <svg class="h-5 w-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
             <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3" />
           </svg>
         </div>
         <div>
           <h3 class="text-white font-bold text-lg">Beat Machine</h3>
           <p class="text-white/60 text-sm">
             <%= @current_kit |> String.replace("_", " ") |> String.split(" ") |> Enum.map(&String.capitalize/1) |> Enum.join(" ") %> •
             <%= @bpm %> BPM
             <%= if @playing do %>
               • <span class="text-green-400">Playing</span>
             <% end %>
           </p>
         </div>
       </div>

       <div class="flex items-center gap-3">
         <!-- Global Transport Controls -->
         <div class="flex items-center gap-2">
           <%= if @playing do %>
             <button
               phx-click="stop_pattern"
               phx-target={@myself}
               disabled={not can_edit_audio?(@permissions)}
               class="w-10 h-10 rounded-xl bg-red-500 hover:bg-red-600 disabled:bg-red-500/50 disabled:cursor-not-allowed flex items-center justify-center text-white transition-colors"
               title="Stop"
             >
               <div class="w-4 h-4 bg-white rounded-sm"></div>
             </button>
           <% else %>
             <button
               phx-click="play_pattern"
               phx-value-pattern_id={@active_pattern}
               phx-target={@myself}
               disabled={is_nil(@active_pattern) or not can_edit_audio?(@permissions)}
               class="w-10 h-10 rounded-xl bg-green-500 hover:bg-green-600 disabled:bg-green-500/50 disabled:cursor-not-allowed flex items-center justify-center text-white transition-colors"
               title="Play"
             >
               <svg class="h-5 w-5 ml-0.5" fill="currentColor" viewBox="0 0 24 24">
                 <path d="M8 5v14l11-7z"/>
               </svg>
             </button>
           <% end %>

           <!-- BPM Display -->
           <div class="bg-white/10 rounded-lg px-3 py-2 text-white text-sm font-mono">
             <%= @bpm %>
           </div>
         </div>

         <!-- Expand Button -->
         <button
           phx-click="toggle_expanded"
           phx-target={@myself}
           class="w-8 h-8 rounded-lg flex items-center justify-center bg-white/10 hover:bg-white/20 text-white/60 hover:text-white transition-colors"
           title={@expanded && "Collapse" || "Expand"}
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

     <!-- Expanded Content -->
     <%= if @expanded do %>
       <!-- Desktop Layout -->
       <%= if not @is_mobile do %>
         <div class="p-4 space-y-4">
           <!-- Top Controls -->
           <div class="flex items-center justify-between">
             <!-- Pattern Management -->
             <div class="flex items-center gap-3">
               <!-- Pattern Selector -->
               <div class="relative">
                 <button
                   phx-click="toggle_pattern_menu"
                   phx-target={@myself}
                   class="flex items-center gap-2 px-4 py-2 bg-white/10 hover:bg-white/20 rounded-lg text-white transition-colors"
                 >
                   <span><%= if @editing_pattern, do: @editing_pattern.name, else: "Select Pattern" %></span>
                   <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                     <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                   </svg>
                 </button>

                 <%= if @show_pattern_menu do %>
                   <div class="absolute top-full left-0 mt-1 bg-black/95 backdrop-blur-xl border border-white/20 rounded-lg shadow-xl min-w-64 z-10 max-h-64 overflow-y-auto">
                     <!-- Create New Pattern -->
                     <div class="p-3 border-b border-white/10">
                       <form phx-submit="create_pattern" phx-target={@myself}>
                         <input
                           type="text"
                           name="name"
                           placeholder="New pattern name..."
                           class="w-full bg-white/10 border border-white/20 rounded px-3 py-2 text-white text-sm placeholder-white/50 focus:outline-none focus:ring-2 focus:ring-orange-500"
                           required
                         />
                       </form>
                     </div>

                     <!-- Pattern List -->
                     <%= for {pattern_id, pattern} <- @patterns do %>
                       <div class="flex items-center justify-between p-2 hover:bg-white/10 transition-colors">
                         <button
                           phx-click="select_pattern"
                           phx-value-pattern_id={pattern_id}
                           phx-target={@myself}
                           class="flex-1 text-left text-white/80 hover:text-white text-sm"
                         >
                           <%= pattern.name %>
                         </button>

                         <div class="flex items-center gap-1">
                           <button
                             phx-click="play_pattern"
                             phx-value-pattern_id={pattern_id}
                             phx-target={@myself}
                             class="w-6 h-6 rounded bg-green-500/20 hover:bg-green-500/30 text-green-400 flex items-center justify-center"
                             title="Play"
                           >
                             <svg class="h-3 w-3" fill="currentColor" viewBox="0 0 24 24">
                               <path d="M8 5v14l11-7z"/>
                             </svg>
                           </button>

                           <%= if can_edit_audio?(@permissions) do %>
                             <button
                               phx-click="delete_pattern"
                               phx-value-pattern_id={pattern_id}
                               phx-target={@myself}
                               data-confirm="Delete this pattern?"
                               class="w-6 h-6 rounded bg-red-500/20 hover:bg-red-500/30 text-red-400 flex items-center justify-center"
                               title="Delete"
                             >
                               <svg class="h-3 w-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                 <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                               </svg>
                             </button>
                           <% end %>
                         </div>
                       </div>
                     <% end %>
                   </div>
                 <% end %>
               </div>

               <!-- Kit Selector -->
               <div class="relative">
                 <button
                   phx-click="toggle_kit_menu"
                   phx-target={@myself}
                   class="flex items-center gap-2 px-4 py-2 bg-white/10 hover:bg-white/20 rounded-lg text-white transition-colors"
                 >
                   <span><%= @current_kit |> String.replace("_", " ") |> String.split(" ") |> Enum.map(&String.capitalize/1) |> Enum.join(" ") %></span>
                   <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                     <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                   </svg>
                 </button>

                 <%= if @show_kit_menu do %>
                   <div class="absolute top-full left-0 mt-1 bg-black/95 backdrop-blur-xl border border-white/20 rounded-lg shadow-xl min-w-64 z-10">
                     <%= for kit <- get_available_kits() do %>
                       <button
                         phx-click="change_kit"
                         phx-value-kit_name={kit.id}
                         phx-target={@myself}
                         class={[
                           "w-full text-left p-3 hover:bg-white/10 transition-colors",
                           @current_kit == kit.id && "bg-orange-500/20 text-orange-300" || "text-white/80 hover:text-white"
                         ]}
                       >
                         <div class="font-medium"><%= kit.name %></div>
                         <div class="text-xs text-white/60"><%= kit.description %></div>
                       </button>
                     <% end %>
                   </div>
                 <% end %>
               </div>
             </div>

             <!-- Settings -->
             <div class="flex items-center gap-3">
               <!-- BPM Control -->
               <div class="flex items-center gap-2">
                 <label class="text-white/70 text-sm font-medium">BPM:</label>
                 <input
                   type="number"
                   min="60"
                   max="200"
                   value={@bpm}
                   phx-change="update_bpm"
                   phx-target={@myself}
                   disabled={not can_edit_audio?(@permissions)}
                   class="w-16 bg-white/10 border border-white/20 rounded px-2 py-1 text-white text-sm text-center focus:outline-none focus:ring-2 focus:ring-orange-500"
                 />
               </div>

               <!-- Swing Control -->
               <div class="flex items-center gap-2">
                 <label class="text-white/70 text-sm font-medium">Swing:</label>
                 <input
                   type="range"
                   min="0"
                   max="100"
                   value={@swing}
                   phx-change="update_swing"
                   phx-target={@myself}
                   disabled={not can_edit_audio?(@permissions)}
                   class="w-20 h-2 bg-white/20 rounded-lg appearance-none cursor-pointer slider"
                 />
                 <span class="text-white/70 text-xs w-8"><%= @swing %>%</span>
               </div>

               <!-- Master Volume -->
               <div class="flex items-center gap-2">
                 <label class="text-white/70 text-sm font-medium">Vol:</label>
                 <input
                   type="range"
                   min="0"
                   max="100"
                   value={round(@master_volume * 100)}
                   phx-change="update_master_volume"
                   phx-target={@myself}
                   disabled={not can_edit_audio?(@permissions)}
                   class="w-20 h-2 bg-white/20 rounded-lg appearance-none cursor-pointer slider"
                 />
                 <span class="text-white/70 text-xs w-8"><%= round(@master_volume * 100) %>%</span>
               </div>
             </div>
           </div>

           <!-- Step Sequencer -->
           <%= if @editing_pattern do %>
             <div class="bg-black/20 rounded-xl p-4 border border-white/10">
               <!-- Step Numbers Header -->
               <div class="grid grid-cols-17 gap-1 mb-3">
                 <div class="text-white/70 text-xs font-medium text-right pr-2">Instrument</div>
                 <%= for step <- 0..15 do %>
                   <div class={[
                     "text-center text-xs font-medium py-1 rounded transition-colors",
                     @current_step == step && @playing && "bg-orange-500 text-white" || "text-white/60",
                     rem(step, 4) == 0 && "text-white/90"
                   ]}>
                     <%= step + 1 %>
                   </div>
                 <% end %>
               </div>

               <!-- Instrument Rows -->
               <%= for instrument <- @instruments do %>
                 <div class="grid grid-cols-17 gap-1 mb-2 group">
                   <!-- Instrument Label -->
                   <button
                     phx-click="select_instrument"
                     phx-value-instrument={instrument.id}
                     phx-target={@myself}
                     class={[
                       "text-right pr-2 py-2 rounded-lg text-sm font-medium transition-colors",
                       @selected_instrument == instrument.id && "bg-white/20 text-white" || "text-white/70 hover:text-white hover:bg-white/10"
                     ]}
                     style={@selected_instrument == instrument.id && "border-left: 3px solid #{instrument.color};" || ""}
                   >
                     <%= instrument.name %>
                   </button>

                   <!-- Step Buttons -->
                   <%= for step <- 0..15 do %>
                     <% velocity = get_step_velocity(@editing_pattern, instrument.id, step)
                     pattern_id = @editing_pattern.id
                     step_index = step
                   %>
                     <button
                      id={"beat_step_#{pattern_id}_#{instrument}_#{step_index}"}
                      phx-hook="BeatMachineStep"
                      data-pattern-id={pattern_id}
                      data-instrument={instrument}
                      data-step={step_index}
                      data-velocity={velocity}
                      class={[
                        "beat-step w-8 h-8 m-1 rounded border-2 transition-all duration-100",
                        velocity > 0 && "step-active bg-indigo-600 border-indigo-400" || "step-off bg-gray-700 border-gray-600"
                      ]}
                      tabindex="0"
                     >
                       <!-- Velocity indicator -->
                       <%= if velocity > 0 do %>
                         <div
                           class="absolute inset-1 rounded bg-white/30"
                           style={"opacity: #{velocity / 127};"}
                         ></div>
                       <% end %>

                       <!-- Step accent indicator -->
                       <%= if rem(step, 4) == 0 do %>
                         <div class="absolute top-0 left-0 w-1 h-1 bg-white/60 rounded-full"></div>
                       <% end %>

                       <!-- Velocity editor on hover -->
                       <%= if velocity > 0 and can_edit_audio?(@permissions) do %>
                         <div class="absolute -top-8 left-1/2 transform -translate-x-1/2 hidden group-hover/step:block bg-black/90 text-white text-xs px-2 py-1 rounded whitespace-nowrap z-10">
                           <input
                             type="range"
                             min="1"
                             max="127"
                             value={velocity}
                             phx-change="update_step_velocity"
                             phx-value-instrument={instrument.id}
                             phx-value-step={step}
                             phx-target={@myself}
                             class="w-16 h-1 bg-white/20 rounded-lg appearance-none cursor-pointer"
                             onclick="event.stopPropagation()"
                           />
                           <div class="text-center mt-1"><%= velocity %></div>
                         </div>
                       <% end %>
                     </button>
                   <% end %>
                 </div>
               <% end %>

               <!-- Pattern Actions -->
               <%= if can_edit_audio?(@permissions) do %>
                 <div class="flex items-center justify-between mt-4 pt-4 border-t border-white/10">
                   <div class="flex items-center gap-2">
                     <button
                       phx-click="clear_pattern"
                       phx-value-pattern_id={@editing_pattern.id}
                       phx-target={@myself}
                       data-confirm="Clear all steps in this pattern?"
                       class="px-3 py-1.5 bg-red-500/20 text-red-300 hover:bg-red-500/30 rounded-lg text-sm font-medium transition-colors"
                     >
                       Clear Pattern
                     </button>

                     <form phx-submit="duplicate_pattern" phx-target={@myself} class="flex items-center gap-2">
                       <input type="hidden" name="pattern_id" value={@editing_pattern.id} />
                       <input
                         type="text"
                         name="new_name"
                         placeholder="Copy name..."
                         class="bg-white/10 border border-white/20 rounded px-2 py-1 text-white text-sm placeholder-white/50 focus:outline-none focus:ring-2 focus:ring-orange-500"
                         required
                       />
                       <button
                         type="submit"
                         class="px-3 py-1.5 bg-blue-500/20 text-blue-300 hover:bg-blue-500/30 rounded-lg text-sm font-medium transition-colors"
                       >
                         Duplicate
                       </button>
                     </form>
                   </div>

                   <div class="text-white/60 text-sm">
                     Pattern: <%= @editing_pattern.name %> • <%= @steps_per_pattern %> steps
                   </div>
                 </div>
               <% end %>
             </div>
           <% else %>
             <!-- No Pattern Selected -->
             <div class="bg-black/20 rounded-xl p-8 border border-white/10 text-center">
               <svg class="h-16 w-16 mx-auto mb-4 text-white/30" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                 <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3" />
               </svg>
               <h4 class="text-white text-lg font-medium mb-2">No Pattern Selected</h4>
               <p class="text-white/60 mb-4">Create or select a pattern to start making beats</p>

               <%= if can_edit_audio?(@permissions) do %>
                 <form phx-submit="create_pattern" phx-target={@myself} class="flex items-center justify-center gap-2">
                   <input
                     type="text"
                     name="name"
                     placeholder="Enter pattern name..."
                     class="bg-white/10 border border-white/20 rounded-lg px-4 py-2 text-white placeholder-white/50 focus:outline-none focus:ring-2 focus:ring-orange-500"
                     required
                   />
                   <button
                     type="submit"
                     class="px-4 py-2 bg-gradient-to-r from-orange-500 to-red-600 hover:from-orange-600 hover:to-red-700 text-white rounded-lg font-medium transition-all duration-200"
                   >
                     Create Pattern
                   </button>
                 </form>
               <% end %>
             </div>
           <% end %>
         </div>

       <% else %>
         <!-- Mobile Layout -->
         <div class="p-3">
           <!-- Mobile Mode Switcher -->
           <div class="flex bg-white/10 rounded-lg p-1 mb-4">
             <button
               phx-click="mobile_switch_mode"
               phx-value-mode="patterns"
               phx-target={@myself}
               class={[
                 "flex-1 py-2 px-3 rounded text-sm font-medium transition-colors",
                 @mobile_mode == "patterns" && "bg-white/20 text-white" || "text-white/60"
               ]}
             >
               Patterns
             </button>
             <button
               phx-click="mobile_switch_mode"
               phx-value-mode="sequencer"
               phx-target={@myself}
               class={[
                 "flex-1 py-2 px-3 rounded text-sm font-medium transition-colors",
                 @mobile_mode == "sequencer" && "bg-white/20 text-white" || "text-white/60"
               ]}
             >
               Sequencer
             </button>
             <button
               phx-click="mobile_switch_mode"
               phx-value-mode="settings"
               phx-target={@myself}
               class={[
                 "flex-1 py-2 px-3 rounded text-sm font-medium transition-colors",
                 @mobile_mode == "settings" && "bg-white/20 text-white" || "text-white/60"
               ]}
             >
               Settings
             </button>
           </div>

           <!-- Mobile Content -->
           <%= case @mobile_mode do %>
             <% "patterns" -> %>
               <!-- Mobile Pattern Management -->
               <div class="space-y-3">
                 <!-- Create New Pattern -->
                 <%= if can_edit_audio?(@permissions) do %>
                   <form phx-submit="create_pattern" phx-target={@myself} class="flex gap-2">
                     <input
                       type="text"
                       name="name"
                       placeholder="New pattern name..."
                       class="flex-1 bg-white/10 border border-white/20 rounded-lg px-3 py-3 text-white placeholder-white/50 focus:outline-none focus:ring-2 focus:ring-orange-500"
                       required
                     />
                     <button
                       type="submit"
                       class="px-4 py-3 bg-gradient-to-r from-orange-500 to-red-600 text-white rounded-lg font-medium"
                     >
                       Create
                     </button>
                   </form>
                 <% end %>

                 <!-- Pattern List -->
                 <div class="space-y-2">
                   <%= for {pattern_id, pattern} <- @patterns do %>
                     <div class={[
                       "bg-white/10 rounded-xl p-4 border transition-colors",
                       @active_pattern == pattern_id && "border-orange-500/50 bg-orange-500/10" || "border-white/20"
                     ]}>
                       <div class="flex items-center justify-between mb-3">
                         <h4 class="text-white font-medium"><%= pattern.name %></h4>
                         <div class="flex items-center gap-2">
                           <button
                             phx-click="play_pattern"
                             phx-value-pattern_id={pattern_id}
                             phx-target={@myself}
                             class="w-8 h-8 rounded-lg bg-green-500 hover:bg-green-600 text-white flex items-center justify-center"
                           >
                             <svg class="h-4 w-4" fill="currentColor" viewBox="0 0 24 24">
                               <path d="M8 5v14l11-7z"/>
                             </svg>
                           </button>

                           <button
                             phx-click="select_pattern"
                             phx-value-pattern_id={pattern_id}
                             phx-target={@myself}
                             class="px-3 py-1.5 bg-blue-500/20 text-blue-300 rounded-lg text-sm font-medium"
                           >
                             Edit
                           </button>
                         </div>
                       </div>

                       <!-- Pattern Preview -->
                       <div class="grid grid-cols-8 gap-1">
                         <%= for step <- 0..7 do %>
                           <% has_hits = Enum.any?(@instruments, fn inst -> get_step_velocity(pattern, inst.id, step) > 0 end) %>
                           <div class={[
                             "h-6 rounded border transition-colors",
                             has_hits && "bg-orange-500/40 border-orange-500/60" || "bg-white/10 border-white/20",
                             @current_step == step && @playing && @active_pattern == pattern_id && "ring-2 ring-orange-400"
                           ]}>
                           </div>
                         <% end %>
                       </div>

                       <%= if can_edit_audio?(@permissions) do %>
                         <div class="flex items-center justify-between mt-3 pt-3 border-t border-white/10">
                           <button
                             phx-click="clear_pattern"
                             phx-value-pattern_id={pattern_id}
                             phx-target={@myself}
                             data-confirm="Clear this pattern?"
                             class="text-red-400 hover:text-red-300 text-sm"
                           >
                             Clear
                           </button>

                           <button
                             phx-click="delete_pattern"
                             phx-value-pattern_id={pattern_id}
                             phx-target={@myself}
                             data-confirm="Delete this pattern?"
                             class="text-red-400 hover:text-red-300 text-sm"
                           >
                             Delete
                           </button>
                         </div>
                       <% end %>
                     </div>
                   <% end %>

                   <%= if map_size(@patterns) == 0 do %>
                     <div class="text-center py-8 text-white/60">
                       <svg class="h-12 w-12 mx-auto mb-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                         <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3" />
                       </svg>
                       <p>No patterns created yet</p>
                     </div>
                   <% end %>
                 </div>
               </div>

             <% "sequencer" -> %>
               <!-- Mobile Sequencer -->
               <%= if @editing_pattern do %>
                 <div class="space-y-4">
                   <!-- Instrument Selector -->
                   <div class="grid grid-cols-2 gap-2">
                     <%= for instrument <- @instruments do %>
                       <button
                         phx-click="select_instrument"
                         phx-value-instrument={instrument.id}
                         phx-target={@myself}
                         class={[
                           "py-3 px-4 rounded-xl font-medium transition-all duration-200 text-sm",
                           @selected_instrument == instrument.id && "text-white shadow-lg" || "bg-white/10 text-white/70 hover:bg-white/20"
                         ]}
                         style={@selected_instrument == instrument.id && "background-color: #{instrument.color};" || ""}
                       >
                         <%= instrument.name %>
                       </button>
                     <% end %>
                   </div>

                   <!-- Step Grid (8 steps per page on mobile) -->
                   <div class="bg-white/10 rounded-xl p-4">
                     <!-- Page Navigation -->
                     <div class="flex items-center justify-between mb-4">
                       <button
                         phx-click="mobile_page_change"
                         phx-value-direction="prev"
                         phx-target={@myself}
                         disabled={@current_page == 0}
                         class="w-8 h-8 rounded-lg bg-white/10 hover:bg-white/20 disabled:opacity-50 disabled:cursor-not-allowed text-white flex items-center justify-center"
                       >
                         <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                           <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
                         </svg>
                       </button>

                       <div class="text-white text-sm font-medium">
                         Steps <%= @current_page * 8 + 1 %>-<%= min((@current_page + 1) * 8, @steps_per_pattern) %>
                       </div>

                       <button
                         phx-click="mobile_page_change"
                         phx-value-direction="next"
                         phx-target={@myself}
                         disabled={(@current_page + 1) * 8 >= @steps_per_pattern}
                         class="w-8 h-8 rounded-lg bg-white/10 hover:bg-white/20 disabled:opacity-50 disabled:cursor-not-allowed text-white flex items-center justify-center"
                       >
                         <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                           <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
                         </svg>
                       </button>
                     </div>

                     <!-- Mobile Step Grid -->
                     <div class="grid grid-cols-4 gap-2">
                       <%= for step <- (@current_page * 8)..min((@current_page + 1) * 8 - 1, @steps_per_pattern - 1) do %>
                         <% velocity = get_step_velocity(@editing_pattern, @selected_instrument, step) %>
                         <div class="text-center">
                           <div class="text-white/60 text-xs mb-1"><%= step + 1 %></div>
                           <button
                             phx-click={@touch_editing && "mobile_select_step" || "toggle_step"}
                             phx-value-step={step}
                             phx-value-instrument={@selected_instrument}
                             phx-target={@myself}
                             disabled={not can_edit_audio?(@permissions)}
                             class={[
                               "w-full h-12 rounded-xl border-2 transition-all duration-200 relative",
                               velocity > 0 && "border-white/40 shadow-lg" || "border-white/20",
                               @current_step == step && @playing && "ring-2 ring-orange-400",
                               @touch_editing && step in @selected_steps && "ring-2 ring-blue-400",
                               not can_edit_audio?(@permissions) && "opacity-50"
                             ]}
                             style={velocity > 0 && "background-color: #{get_instrument_color(@instruments, @selected_instrument)}#{Integer.to_string(div(velocity * 255, 127), 16) |> String.pad_leading(2, "0")};" || ""}
                           >
                             <%= if velocity > 0 do %>
                               <div class="text-white text-xs font-bold"><%= velocity %></div>
                             <% end %>
                           </button>
                         </div>
                       <% end %>
                     </div>

                     <!-- Mobile Multi-Select Controls -->
                     <%= if can_edit_audio?(@permissions) do %>
                       <div class="flex items-center justify-between mt-4 pt-4 border-t border-white/10">
                         <%= if @touch_editing do %>
                           <button
                             phx-click="mobile_multi_select_end"
                             phx-target={@myself}
                             class="px-4 py-2 bg-green-500 text-white rounded-lg font-medium"
                           >
                             Apply (<%= length(@selected_steps) %>)
                           </button>
                         <% else %>
                           <button
                             phx-click="mobile_multi_select_start"
                             phx-target={@myself}
                             class="px-4 py-2 bg-blue-500/20 text-blue-300 rounded-lg font-medium"
                           >
                             Multi-Select
                           </button>
                         <% end %>

                         <div class="text-white/60 text-sm">
                           <%= @selected_instrument |> String.capitalize() %>
                         </div>
                       </div>
                     <% end %>
                   </div>
                 </div>
               <% else %>
                 <div class="text-center py-8 text-white/60">
                   <p>Select a pattern to edit</p>
                 </div>
               <% end %>

             <% "settings" -> %>
               <!-- Mobile Settings -->
               <div class="space-y-4">
                 <!-- Kit Selection -->
                 <div class="bg-white/10 rounded-xl p-4">
                   <h4 class="text-white font-medium mb-3">Drum Kit</h4>
                   <div class="space-y-2">
                     <%= for kit <- get_available_kits() do %>
                       <button
                         phx-click="change_kit"
                         phx-value-kit_name={kit.id}
                         phx-target={@myself}
                         disabled={not can_edit_audio?(@permissions)}
                         class={[
                           "w-full text-left p-3 rounded-lg transition-colors",
                           @current_kit == kit.id && "bg-orange-500/20 text-orange-300 border border-orange-500/30" || "bg-white/5 text-white/80 hover:bg-white/10",
                           not can_edit_audio?(@permissions) && "opacity-50"
                         ]}
                       >
                         <div class="font-medium"><%= kit.name %></div>
                         <div class="text-xs text-white/60"><%= kit.description %></div>
                       </button>
                     <% end %>
                   </div>
                 </div>

                 <!-- Tempo & Timing -->
                 <div class="bg-white/10 rounded-xl p-4">
                   <h4 class="text-white font-medium mb-3">Tempo & Timing</h4>

                   <!-- BPM -->
                   <div class="mb-4">
                     <div class="flex justify-between items-center mb-2">
                       <label class="text-white/80 text-sm">BPM</label>
                       <span class="text-white font-mono"><%= @bpm %></span>
                     </div>
                     <input
                       type="range"
                       min="60"
                       max="200"
                       value={@bpm}
                       phx-change="update_bpm"
                       phx-target={@myself}
                       disabled={not can_edit_audio?(@permissions)}
                       class="w-full h-3 bg-white/20 rounded-lg appearance-none cursor-pointer slider"
                     />
                   </div>

                   <!-- Swing -->
                   <div class="mb-4">
                     <div class="flex justify-between items-center mb-2">
                       <label class="text-white/80 text-sm">Swing</label>
                       <span class="text-white font-mono"><%= @swing %>%</span>
                     </div>
                     <input
                       type="range"
                       min="0"
                       max="100"
                       value={@swing}
                       phx-change="update_swing"
                       phx-target={@myself}
                       disabled={not can_edit_audio?(@permissions)}
                       class="w-full h-3 bg-white/20 rounded-lg appearance-none cursor-pointer slider"
                     />
                   </div>

                   <!-- Master Volume -->
                   <div>
                     <div class="flex justify-between items-center mb-2">
                       <label class="text-white/80 text-sm">Master Volume</label>
                       <span class="text-white font-mono"><%= round(@master_volume * 100) %>%</span>
                     </div>
                     <input
                       type="range"
                       min="0"
                       max="100"
                       value={round(@master_volume * 100)}
                       phx-change="update_master_volume"
                       phx-target={@myself}
                       disabled={not can_edit_audio?(@permissions)}
                       class="w-full h-3 bg-white/20 rounded-lg appearance-none cursor-pointer slider"
                     />
                   </div>
                 </div>
               </div>
           <% end %>
         </div>
       <% end %>
     <% end %>
   </div>
   """
 end

 defp get_instrument_color(instruments, instrument_id) do
   case Enum.find(instruments, &(&1.id == instrument_id)) do
     %{color: color} -> color
     _ -> "#8B5CF6"
   end
 end
end
