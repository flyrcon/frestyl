defmodule FrestylWeb.Studio.RecordingWorkspaceComponent do
 use FrestylWeb, :live_component

 @impl true
 def mount(socket) do
   {:ok, assign(socket,
     # Recording state
     recording_state: :idle, # :idle, :preparing, :recording, :paused, :stopped
     recording_track: nil,
     recording_start_time: nil,
     recording_duration: 0,
     countdown: 0,
     # Audio monitoring
     input_level: 0,
     peak_level: 0,
     clip_detected: false,
     # Recording settings
     auto_punch: false,
     punch_in_time: 0,
     punch_out_time: 0,
     metronome_enabled: true,
     count_in_beats: 4,
     # Session management
     take_number: 1,
     recorded_takes: [],
     active_take: nil,
     # Mobile specific
     mobile_recording_mode: "simple", # simple, advanced, monitoring
     recording_quality: "high", # high, medium, low
     background_recording: false,
     # UI state
     show_metronome_settings: false,
     show_take_manager: false,
     show_recording_settings: false,
     # Real-time visualization
     waveform_buffer: [],
     recording_peaks: [],
     # Error handling
     error_message: nil,
     recording_permission: :unknown # :granted, :denied, :unknown
   )}
 end

 @impl true
 def update(assigns, socket) do
   socket = socket
     |> assign(assigns)
     |> maybe_initialize_recording_session()
     |> update_recording_state(assigns)

   {:ok, socket}
 end

 @impl true
 def handle_event("start_recording", %{"track_id" => track_id}, socket) do
   if can_record_audio?(socket.assigns.permissions) do
     if socket.assigns.countdown > 0 do
       # Start countdown
       {:noreply, start_countdown(socket, track_id)}
     else
       # Start immediately
       {:noreply, begin_recording(socket, track_id)}
     end
   else
     {:noreply, assign(socket, error_message: "You don't have permission to record")}
   end
 end

 @impl true
 def handle_event("stop_recording", _, socket) do
   case socket.assigns.recording_state do
     :recording ->
       {:noreply, stop_recording(socket)}
     :preparing ->
       {:noreply, cancel_recording(socket)}
     _ ->
       {:noreply, socket}
   end
 end

 @impl true
 def handle_event("pause_recording", _, socket) do
   if socket.assigns.recording_state == :recording do
     send(self(), {:pause_recording, socket.assigns.recording_track})
     {:noreply, assign(socket, recording_state: :paused)}
   else
     {:noreply, socket}
   end
 end

 @impl true
 def handle_event("resume_recording", _, socket) do
   if socket.assigns.recording_state == :paused do
     send(self(), {:resume_recording, socket.assigns.recording_track})
     {:noreply, assign(socket, recording_state: :recording)}
   else
     {:noreply, socket}
   end
 end

 @impl true
 def handle_event("select_track", %{"track_id" => track_id}, socket) do
   {:noreply, assign(socket, recording_track: track_id)}
 end

 @impl true
 def handle_event("create_new_track", _, socket) do
   if can_edit_audio?(socket.assigns.permissions) do
     session_id = socket.assigns.session.id
     user_id = socket.assigns.current_user.id
     track_name = "Recording #{socket.assigns.take_number}"

     send(self(), {:create_recording_track, session_id, user_id, track_name})
     {:noreply, socket}
   else
     {:noreply, socket}
   end
 end

 @impl true
 def handle_event("toggle_metronome", _, socket) do
   new_state = !socket.assigns.metronome_enabled
   send(self(), {:toggle_metronome, new_state})
   {:noreply, assign(socket, metronome_enabled: new_state)}
 end

 @impl true
 def handle_event("update_count_in", %{"count" => count}, socket) do
   count_beats = String.to_integer(count)
   {:noreply, assign(socket, count_in_beats: count_beats, countdown: count_beats)}
 end

 @impl true
 def handle_event("toggle_auto_punch", _, socket) do
   {:noreply, assign(socket, auto_punch: !socket.assigns.auto_punch)}
 end

 @impl true
 def handle_event("set_punch_time", %{"type" => type, "time" => time}, socket) do
   time_float = String.to_float(time)

   case type do
     "in" -> {:noreply, assign(socket, punch_in_time: time_float)}
     "out" -> {:noreply, assign(socket, punch_out_time: time_float)}
     _ -> {:noreply, socket}
   end
 end

 @impl true
 def handle_event("select_take", %{"take_id" => take_id}, socket) do
   take = Enum.find(socket.assigns.recorded_takes, &(&1.id == take_id))
   {:noreply, assign(socket, active_take: take)}
 end

 @impl true
 def handle_event("delete_take", %{"take_id" => take_id}, socket) do
   if can_edit_audio?(socket.assigns.permissions) do
     send(self(), {:delete_recording_take, take_id})

     takes = Enum.reject(socket.assigns.recorded_takes, &(&1.id == take_id))
     active_take = if socket.assigns.active_take && socket.assigns.active_take.id == take_id do
       nil
     else
       socket.assigns.active_take
     end

     {:noreply, assign(socket, recorded_takes: takes, active_take: active_take)}
   else
     {:noreply, socket}
   end
 end

 @impl true
 def handle_event("comp_take", %{"take_id" => take_id}, socket) do
   if can_edit_audio?(socket.assigns.permissions) do
     send(self(), {:comp_recording_take, take_id, socket.assigns.recording_track})
     {:noreply, socket}
   else
     {:noreply, socket}
   end
 end

 # Mobile-specific events
 @impl true
 def handle_event("mobile_switch_mode", %{"mode" => mode}, socket) do
   {:noreply, assign(socket, mobile_recording_mode: mode)}
 end

 @impl true
 def handle_event("mobile_quick_record", _, socket) do
   if socket.assigns.recording_track do
     handle_event("start_recording", %{"track_id" => socket.assigns.recording_track}, socket)
   else
     # Auto-create track and start recording
     handle_event("create_new_track", %{}, socket)
   end
 end

 @impl true
 def handle_event("update_recording_quality", %{"quality" => quality}, socket) do
   send(self(), {:update_recording_quality, quality})
   {:noreply, assign(socket, recording_quality: quality)}
 end

 @impl true
 def handle_event("toggle_background_recording", _, socket) do
   new_state = !socket.assigns.background_recording
   send(self(), {:toggle_background_recording, new_state})
   {:noreply, assign(socket, background_recording: new_state)}
 end

 @impl true
 def handle_event("request_audio_permission", _, socket) do
   {:noreply, push_event(socket, "request_audio_permission", %{})}
 end

 @impl true
 def handle_event("audio_permission_result", %{"granted" => granted}, socket) do
   permission = if granted, do: :granted, else: :denied
   error_msg = if not granted, do: "Microphone access denied. Please enable in browser settings.", else: nil

   {:noreply, assign(socket, recording_permission: permission, error_message: error_msg)}
 end

 # Toggle UI panels
 @impl true
 def handle_event("toggle_metronome_settings", _, socket) do
   {:noreply, assign(socket, show_metronome_settings: !socket.assigns.show_metronome_settings)}
 end

 @impl true
 def handle_event("toggle_take_manager", _, socket) do
   {:noreply, assign(socket, show_take_manager: !socket.assigns.show_take_manager)}
 end

 @impl true
 def handle_event("toggle_recording_settings", _, socket) do
   {:noreply, assign(socket, show_recording_settings: !socket.assigns.show_recording_settings)}
 end

 # Handle real-time updates from audio engine
 @impl true
 def handle_info({:recording_started, track_id, take_id}, socket) do
   {:noreply, assign(socket,
     recording_state: :recording,
     recording_track: track_id,
     recording_start_time: DateTime.utc_now(),
     take_number: socket.assigns.take_number + 1,
     error_message: nil
   )}
 end

 @impl true
 def handle_info({:recording_stopped, take_data}, socket) do
   new_takes = [take_data | socket.assigns.recorded_takes]

   {:noreply, assign(socket,
     recording_state: :stopped,
     recorded_takes: new_takes,
     active_take: take_data,
     recording_track: nil,
     recording_start_time: nil,
     recording_duration: 0
   )}
 end

 @impl true
 def handle_info({:recording_error, error}, socket) do
   {:noreply, assign(socket,
     recording_state: :idle,
     error_message: error,
     recording_track: nil
   )}
 end

 @impl true
 def handle_info({:audio_levels, input_level, peak_level}, socket) do
   clip_detected = peak_level > 0.95

   # Update waveform buffer for real-time visualization
   new_buffer = [input_level | socket.assigns.waveform_buffer] |> Enum.take(200)

   {:noreply, assign(socket,
     input_level: input_level,
     peak_level: peak_level,
     clip_detected: clip_detected,
     waveform_buffer: new_buffer
   )}
 end

 @impl true
 def handle_info({:recording_duration_update, duration}, socket) do
   {:noreply, assign(socket, recording_duration: duration)}
 end

 @impl true
 def handle_info({:countdown_tick, count}, socket) do
   if count > 0 do
     # Continue countdown
     Process.send_after(self(), {:countdown_tick, count - 1}, 1000)
     {:noreply, assign(socket, countdown: count)}
   else
     # Start actual recording
     {:noreply, begin_recording(socket, socket.assigns.recording_track)}
   end
 end

 @impl true
 def handle_info({:new_recording_track, track}, socket) do
   # Auto-select the newly created track
   {:noreply, assign(socket, recording_track: track.id)}
 end

 defp maybe_initialize_recording_session(socket) do
   if socket.assigns.recording_permission == :unknown do
     push_event(socket, "check_audio_permission", %{})
   else
     socket
   end
 end

 defp update_recording_state(socket, assigns) do
   # Update from workspace state
   workspace_state = assigns.workspace_state

   if workspace_state && workspace_state.audio do
     audio_state = workspace_state.audio

     assign(socket,
       recording_state: if(audio_state.recording, do: :recording, else: socket.assigns.recording_state)
     )
   else
     socket
   end
 end

 defp start_countdown(socket, track_id) do
   count = socket.assigns.count_in_beats

   if count > 0 do
     # Enable metronome for countdown
     send(self(), {:start_countdown_metronome})
     Process.send_after(self(), {:countdown_tick, count}, 1000)

     assign(socket,
       recording_state: :preparing,
       recording_track: track_id,
       countdown: count
     )
   else
     begin_recording(socket, track_id)
   end
 end

 defp begin_recording(socket, track_id) do
   session_id = socket.assigns.session.id
   user_id = socket.assigns.current_user.id

   recording_options = %{
     auto_punch: socket.assigns.auto_punch,
     punch_in: socket.assigns.punch_in_time,
     punch_out: socket.assigns.punch_out_time,
     quality: socket.assigns.recording_quality,
     metronome: socket.assigns.metronome_enabled
   }

   send(self(), {:start_recording, session_id, track_id, user_id, recording_options})

   assign(socket,
     recording_state: :recording,
     recording_track: track_id,
     recording_start_time: DateTime.utc_now(),
     countdown: 0,
     error_message: nil
   )
 end

 defp stop_recording(socket) do
   session_id = socket.assigns.session.id
   track_id = socket.assigns.recording_track

   send(self(), {:stop_recording, session_id, track_id})

   assign(socket, recording_state: :stopped)
 end

 defp cancel_recording(socket) do
   send(self(), {:cancel_recording})

   assign(socket,
     recording_state: :idle,
     recording_track: nil,
     countdown: 0
   )
 end

 defp can_record_audio?(permissions), do: :record_audio in permissions
 defp can_edit_audio?(permissions), do: :edit_audio in permissions

 defp format_duration(seconds) when is_number(seconds) do
   minutes = div(trunc(seconds), 60)
   seconds = rem(trunc(seconds), 60)
   "#{String.pad_leading(Integer.to_string(minutes), 2, "0")}:#{String.pad_leading(Integer.to_string(seconds), 2, "0")}"
 end
 defp format_duration(_), do: "00:00"

 defp get_recording_time(socket) do
   case socket.assigns.recording_start_time do
     nil -> 0
     start_time -> DateTime.diff(DateTime.utc_now(), start_time, :second)
   end
 end

 defp get_available_tracks(workspace_state) do
   workspace_state.audio.tracks || []
 end

 defp get_level_color(level) when is_number(level) do
   cond do
     level > 0.9 -> "bg-red-500"
     level > 0.7 -> "bg-yellow-500"
     level > 0.3 -> "bg-green-500"
     true -> "bg-green-400"
   end
 end
 defp get_level_color(_), do: "bg-gray-500"

 @impl true
 def render(assigns) do
   ~H"""
   <div class="h-full bg-black/30 backdrop-blur-sm">
     <!-- Recording Header -->
     <div class="flex items-center justify-between p-4 border-b border-white/10 bg-black/40">
       <div class="flex items-center gap-3">
         <div class={[
           "p-3 rounded-xl transition-all duration-200",
           @recording_state == :recording && "bg-red-500 animate-pulse" || "bg-gradient-to-r from-red-500 to-pink-600"
         ]}>
           <svg class="h-6 w-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
             <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z" />
           </svg>
         </div>

         <div>
           <h2 class="text-white text-xl font-bold">Recording Studio</h2>
           <p class="text-white/70 text-sm">
             <%= case @recording_state do %>
               <% :recording -> %>
                 <span class="text-red-400">● Recording</span> •
                 Track <%= @recording_track || "?" %> •
                 <%= format_duration(get_recording_time(assigns)) %>
               <% :preparing -> %>
                 <span class="text-yellow-400">● Preparing</span> •
                 Count-in: <%= @countdown %>
               <% :paused -> %>
                 <span class="text-yellow-400">⏸ Paused</span> •
                 <%= format_duration(@recording_duration) %>
               <% :stopped -> %>
                 <span class="text-green-400">● Stopped</span> •
                 Take <%= @take_number - 1 %> completed
               <% _ -> %>
                 Ready to record • Take <%= @take_number %>
             <% end %>
           </p>
         </div>
       </div>

       <div class="flex items-center gap-3">
         <!-- Permission Status -->
         <%= case @recording_permission do %>
           <% :granted -> %>
             <div class="flex items-center gap-2 text-green-400 text-sm">
               <div class="w-2 h-2 bg-green-400 rounded-full"></div>
               <span>Mic Ready</span>
             </div>
           <% :denied -> %>
             <button
               phx-click="request_audio_permission"
               phx-target={@myself}
               class="flex items-center gap-2 text-red-400 hover:text-red-300 text-sm"
             >
               <div class="w-2 h-2 bg-red-400 rounded-full"></div>
               <span>Enable Mic</span>
             </button>
           <% _ -> %>
             <div class="flex items-center gap-2 text-yellow-400 text-sm">
               <div class="w-2 h-2 bg-yellow-400 rounded-full animate-pulse"></div>
               <span>Checking...</span>
             </div>
         <% end %>

         <!-- Quality Indicator -->
         <div class="text-white/60 text-sm">
           Quality: <%= String.capitalize(@recording_quality) %>
         </div>
       </div>
     </div>

     <!-- Error Display -->
     <%= if @error_message do %>
       <div class="bg-red-900/30 border border-red-500/30 p-4 m-4 rounded-lg">
         <div class="flex items-center gap-3">
           <svg class="h-5 w-5 text-red-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
             <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
           </svg>
           <span class="text-red-200"><%= @error_message %></span>
         </div>
       </div>
     <% end %>

     <!-- Countdown Display -->
     <%= if @recording_state == :preparing and @countdown > 0 do %>
       <div class="fixed inset-0 bg-black/80 backdrop-blur-sm flex items-center justify-center z-50">
         <div class="text-center">
           <div class="text-8xl font-bold text-white mb-4 animate-pulse">
             <%= @countdown %>
           </div>
           <p class="text-white/80 text-xl">Get ready to record...</p>
           <button
             phx-click="stop_recording"
             phx-target={@myself}
             class="mt-6 px-6 py-3 bg-red-500 hover:bg-red-600 text-white rounded-lg font-medium"
           >
             Cancel
           </button>
         </div>
       </div>
     <% end %>

     <!-- Main Content -->
     <div class="flex-1 overflow-hidden">
       <%= if not @is_mobile do %>
         <!-- Desktop Recording Interface -->
         <div class="h-full grid grid-cols-3 gap-4 p-4">
           <!-- Left: Track Selection & Controls -->
           <div class="space-y-4">
             <!-- Track Selection -->
             <div class="bg-black/20 rounded-xl p-4 border border-white/10">
               <h3 class="text-white font-medium mb-3 flex items-center gap-2">
                 <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                   <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3" />
                 </svg>
                 Record to Track
               </h3>

               <div class="space-y-2">
                 <%= for track <- get_available_tracks(@workspace_state) do %>
                   <button
                     phx-click="select_track"
                     phx-value-track_id={track.id}
                     phx-target={@myself}
                     class={[
                       "w-full text-left p-3 rounded-lg transition-colors",
                       @recording_track == track.id && "bg-red-500/20 border border-red-500/30 text-red-300" || "bg-white/10 hover:bg-white/20 text-white/80"
                     ]}
                   >
                     <div class="font-medium">Track <%= track.number %>: <%= track.name %></div>
                     <div class="text-xs text-white/60">
                       <%= length(track.clips || []) %> clips •
                       <%= if track.muted, do: "Muted", else: "Active" %>
                     </div>
                   </button>
                 <% end %>

                 <%= if can_edit_audio?(@permissions) do %>
                   <button
                     phx-click="create_new_track"
                     phx-target={@myself}
                     class="w-full p-3 border-2 border-dashed border-white/30 hover:border-white/50 rounded-lg text-white/60 hover:text-white transition-colors"
                   >
                     <div class="flex items-center justify-center gap-2">
                       <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                         <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
                       </svg>
                       Create New Track
                     </div>
                   </button>
                 <% end %>
               </div>
             </div>

             <!-- Recording Controls -->
             <div class="bg-black/20 rounded-xl p-4 border border-white/10">
               <h3 class="text-white font-medium mb-3">Recording Controls</h3>

               <div class="space-y-3">
                 <!-- Main Record Button -->
                 <div class="text-center">
                   <%= case @recording_state do %>
                     <% state when state in [:idle, :stopped] -> %>
                       <button
                         phx-click="start_recording"
                         phx-value-track_id={@recording_track}
                         phx-target={@myself}
                         disabled={is_nil(@recording_track) or @recording_permission != :granted or not can_record_audio?(@permissions)}
                         class="w-20 h-20 rounded-full bg-red-500 hover:bg-red-600 disabled:bg-red-500/50 disabled:cursor-not-allowed flex items-center justify-center text-white shadow-lg transition-all duration-200 hover:scale-105"
                       >
                         <div class="w-6 h-6 bg-white rounded-full"></div>
                       </button>
                     <% :recording -> %>
                       <div class="flex gap-3 justify-center">
                         <button
                           phx-click="pause_recording"
                           phx-target={@myself}
                           class="w-16 h-16 rounded-full bg-yellow-500 hover:bg-yellow-600 flex items-center justify-center text-white shadow-lg transition-all duration-200"
                         >
                           <div class="flex gap-1">
                             <div class="w-2 h-6 bg-white rounded-sm"></div>
                             <div class="w-2 h-6 bg-white rounded-sm"></div>
                           </div>
                         </button>
                         <button
                           phx-click="stop_recording"
                           phx-target={@myself}
                           class="w-16 h-16 rounded-full bg-red-600 hover:bg-red-700 flex items-center justify-center text-white shadow-lg transition-all duration-200"
                         >
                           <div class="w-6 h-6 bg-white rounded-sm"></div>
                         </button>
                       </div>
                     <% :paused -> %>
                       <div class="flex gap-3 justify-center">
                         <button
                           phx-click="resume_recording"
                           phx-target={@myself}
                           class="w-16 h-16 rounded-full bg-green-500 hover:bg-green-600 flex items-center justify-center text-white shadow-lg transition-all duration-200"
                         >
                           <svg class="h-6 w-6 ml-1" fill="currentColor" viewBox="0 0 24 24">
                             <path d="M8 5v14l11-7z"/>
                           </svg>
                         </button>
                         <button
                           phx-click="stop_recording"
                           phx-target={@myself}
                           class="w-16 h-16 rounded-full bg-red-600 hover:bg-red-700 flex items-center justify-center text-white shadow-lg transition-all duration-200"
                         >
                           <div class="w-6 h-6 bg-white rounded-sm"></div>
                         </button>
                       </div>
                     <% :preparing -> %>
                       <button
                         phx-click="stop_recording"
                         phx-target={@myself}
                         class="w-20 h-20 rounded-full bg-yellow-500 hover:bg-yellow-600 flex items-center justify-center text-white shadow-lg transition-all duration-200 animate-pulse"
                       >
                         <span class="text-sm font-bold">Cancel</span>
                       </button>
                   <% end %>
                 </div>

                 <!-- Metronome Toggle -->
                 <div class="flex items-center justify-between">
                   <span class="text-white/80 text-sm">Metronome</span>
                   <button
                     phx-click="toggle_metronome"
                     phx-target={@myself}
                     class={[
                       "relative inline-flex h-6 w-11 items-center rounded-full transition-colors",
                       @metronome_enabled && "bg-blue-500" || "bg-white/20"
                     ]}
                   >
                     <span class={[
                       "inline-block h-4 w-4 transform rounded-full bg-white transition-transform",
                       @metronome_enabled && "translate-x-6" || "translate-x-1"
                     ]}></span>
                   </button>
                 </div>

                 <!-- Count-in Setting -->
                 <div class="flex items-center justify-between">
                   <span class="text-white/80 text-sm">Count-in Beats</span>
                   <select
                     phx-change="update_count_in"
                     phx-target={@myself}
                     class="bg-white/10 border border-white/20 rounded px-2 py-1 text-white text-sm"
                   >
                     <%= for count <- [0, 1, 2, 4, 8] do %>
                       <option value={count} selected={@count_in_beats == count}>
                         <%= if count == 0, do: "None", else: count %>
                       </option>
                     <% end %>
                   </select>
                 </div>

                 <!-- Auto Punch -->
                 <div class="space-y-2">
                   <div class="flex items-center justify-between">
                     <span class="text-white/80 text-sm">Auto Punch</span>
                     <button
                       phx-click="toggle_auto_punch"
                       phx-target={@myself}
                       class={[
                         "relative inline-flex h-6 w-11 items-center rounded-full transition-colors",
                         @auto_punch && "bg-purple-500" || "bg-white/20"
                       ]}
                     >
                       <span class={[
                         "inline-block h-4 w-4 transform rounded-full bg-white transition-transform",
                         @auto_punch && "translate-x-6" || "translate-x-1"
                       ]}></span>
                     </button>
                   </div>

                   <%= if @auto_punch do %>
                     <div class="grid grid-cols-2 gap-2">
                       <div>
                         <label class="text-white/60 text-xs">Punch In</label>
                         <input
                           type="number"
                           step="0.1"
                           value={@punch_in_time}
                           phx-change="set_punch_time"
                           phx-value-type="in"
                           phx-target={@myself}
                           class="w-full bg-white/10 border border-white/20 rounded px-2 py-1 text-white text-sm"
                         />
                       </div>
                       <div>
                         <label class="text-white/60 text-xs">Punch Out</label>
                         <input
                           type="number"
                           step="0.1"
                           value={@punch_out_time}
                           phx-change="set_punch_time"
                           phx-value-type="out"
                           phx-target={@myself}
                           class="w-full bg-white/10 border border-white/20 rounded px-2 py-1 text-white text-sm"
                         />
                       </div>
                     </div>
                   <% end %>
                 </div>
               </div>
             </div>
           </div>

           <!-- Center: Level Monitoring & Waveform -->
           <div class="space-y-4">
             <!-- Input Level Meter -->
             <div class="bg-black/20 rounded-xl p-4 border border-white/10">
               <h3 class="text-white font-medium mb-3 flex items-center gap-2">
                 <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                   <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.536 8.464a5 5 0 010 7.072m2.828-9.9a9 9 0 010 12.728M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z" />
                 </svg>
                 Input Level
                 <%= if @clip_detected do %>
                   <span class="text-red-400 text-xs animate-pulse">CLIP!</span>
                 <% end %>
               </h3>

               <!-- Vertical Level Meter -->
               <div class="flex items-end justify-center h-48 gap-2">
                 <%= for db <- [0, -3, -6, -12, -18, -24, -30, -40, -50, -60] do %>
                   <% db_normalized = (60 + db) / 60 # Convert to 0-1 range %>
                   <div class="flex flex-col items-center">
                     <div class="w-6 bg-black/30 rounded-full relative h-40">
                       <div
                         class={[
                           "absolute bottom-0 w-full rounded-full transition-all duration-75",
                           get_level_color(@input_level)
                         ]}
                         style={"height: #{if @input_level > db_normalized, do: min(@input_level * 100, 100), else: 0}%;"}
                       ></div>

                       <!-- Peak hold indicator -->
                       <%= if @peak_level > db_normalized do %>
                         <div
                           class="absolute w-full h-1 bg-yellow-400"
                           style={"bottom: #{min(@peak_level * 100, 100)}%;"}
                         ></div>
                       <% end %>
                     </div>
                     <span class="text-white/60 text-xs mt-1"><%= db %></span>
                   </div>
                 <% end %>
               </div>

               <!-- Digital Level Display -->
               <div class="mt-3 text-center">
                 <div class="text-2xl font-mono text-white">
                   <%= if @input_level > 0 do %>
                     <%= Float.round(20 * :math.log10(@input_level), 1) %> dB
                   <% else %>
                     -∞ dB
                   <% end %>
                 </div>
                 <div class="text-white/60 text-sm">
                   Peak: <%= if @peak_level > 0 do %>
                     <%= Float.round(20 * :math.log10(@peak_level), 1) %> dB
                   <% else %>
                     -∞ dB
                   <% end %>
                 </div>
               </div>
             </div>

             <!-- Real-time Waveform -->
             <div class="bg-black/20 rounded-xl p-4 border border-white/10">
               <h3 class="text-white font-medium mb-3">Live Waveform</h3>

               <div class="h-32 bg-black/30 rounded-lg relative overflow-hidden" id="live-waveform">
                 <canvas
                   id="waveform-canvas"
                   phx-hook="LiveWaveform"
                   data-buffer={Jason.encode!(@waveform_buffer)}
                   class="absolute inset-0 w-full h-full"
                 ></canvas>

                 <%= if @recording_state == :recording do %>
                   <div class="absolute top-2 right-2 bg-red-500 text-white text-xs px-2 py-1 rounded-full animate-pulse">
                     REC
                   </div>
                 <% end %>
               </div>
             </div>
           </div>

           <!-- Right: Take Management -->
           <div class="space-y-4">
             <!-- Take Manager -->
             <div class="bg-black/20 rounded-xl p-4 border border-white/10">
               <h3 class="text-white font-medium mb-3 flex items-center justify-between">
                 <span class="flex items-center gap-2">
                   <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                     <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 712 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 712-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 712-2m0 0V5a2 2 0 712-2h6a2 2 0 712 2v2M7 7h10" />
                   </svg>
                   Recorded Takes
                 </span>
                 <span class="text-white/60 text-sm"><%= length(@recorded_takes) %> takes</span>
               </h3>

               <div class="space-y-2 max-h-64 overflow-y-auto">
                 <%= if length(@recorded_takes) == 0 do %>
                   <div class="text-center py-8 text-white/60">
                     <svg class="h-12 w-12 mx-auto mb-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                       <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z" />
                     </svg>
                     <p>No takes recorded yet</p>
                     <p class="text-sm text-white/40 mt-1">Start recording to see takes here</p>
                   </div>
                 <% else %>
                   <%= for take <- @recorded_takes do %>
                     <div class={[
                       "bg-white/10 rounded-lg p-3 transition-colors",
                       @active_take && @active_take.id == take.id && "bg-green-500/20 border border-green-500/30"
                     ]}>
                       <div class="flex items-center justify-between mb-2">
                         <div>
                           <h4 class="text-white font-medium text-sm">Take <%= take.number %></h4>
                           <p class="text-white/60 text-xs">
                             <%= format_duration(take.duration) %> •
                             <%= Calendar.strftime(take.recorded_at, "%H:%M:%S") %>
                           </p>
                         </div>

                         <div class="flex items-center gap-1">
                           <button
                             phx-click="select_take"
                             phx-value-take_id={take.id}
                             phx-target={@myself}
                             class="w-6 h-6 rounded bg-blue-500/20 hover:bg-blue-500/30 text-blue-400 flex items-center justify-center"
                             title="Select take"
                           >
                             <svg class="h-3 w-3" fill="currentColor" viewBox="0 0 24 24">
                               <path d="M8 5v14l11-7z"/>
                             </svg>
                           </button>

                           <%= if can_edit_audio?(@permissions) do %>
                             <button
                               phx-click="comp_take"
                               phx-value-take_id={take.id}
                               phx-target={@myself}
                               class="w-6 h-6 rounded bg-green-500/20 hover:bg-green-500/30 text-green-400 flex items-center justify-center"
                               title="Comp take"
                             >
                               <svg class="h-3 w-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                 <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                               </svg>
                             </button>

                             <button
                               id={"cursor-#{take.id}"}
                               phx-click="delete_take"
                               phx-value-take_id={take.id}
                               phx-target={@myself}
                               data-confirm="Delete this take?"
                               class="w-6 h-6 rounded bg-red-500/20 hover:bg-red-500/30 text-red-400 flex items-center justify-center"
                               title="Delete take"
                             >
                               <svg class="h-3 w-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                 <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                               </svg>
                             </button>
                           <% end %>
                         </div>
                       </div>

                       <!-- Take Waveform Preview -->
                       <div class="h-8 bg-black/30 rounded overflow-hidden">
                         <canvas
                           id={"waveform-#{take.id}"}
                           phx-hook="TakeWaveform"
                           data-take-id={take.id}
                           data-waveform={Jason.encode!(take.waveform_data || [])}
                           class="w-full h-full"
                         ></canvas>
                       </div>
                     </div>
                   <% end %>
                 <% end %>
               </div>
             </div>

             <!-- Recording Settings -->
             <div class="bg-black/20 rounded-xl p-4 border border-white/10">
               <h3 class="text-white font-medium mb-3">Recording Settings</h3>

               <div class="space-y-3">
                 <!-- Quality Setting -->
                 <div>
                   <label class="text-white/80 text-sm mb-2 block">Quality</label>
                   <select
                     phx-change="update_recording_quality"
                     phx-target={@myself}
                     class="w-full bg-white/10 border border-white/20 rounded px-3 py-2 text-white text-sm"
                   >
                     <option value="high" selected={@recording_quality == "high"}>High (48kHz/24bit)</option>
                     <option value="medium" selected={@recording_quality == "medium"}>Medium (44.1kHz/16bit)</option>
                     <option value="low" selected={@recording_quality == "low"}>Low (22kHz/16bit)</option>
                   </select>
                 </div>

                 <!-- Background Recording (Mobile) -->
                 <%= if @is_mobile do %>
                   <div class="flex items-center justify-between">
                     <span class="text-white/80 text-sm">Background Recording</span>
                     <button
                       phx-click="toggle_background_recording"
                       phx-target={@myself}
                       class={[
                         "relative inline-flex h-6 w-11 items-center rounded-full transition-colors",
                         @background_recording && "bg-blue-500" || "bg-white/20"
                       ]}
                     >
                       <span class={[
                         "inline-block h-4 w-4 transform rounded-full bg-white transition-transform",
                         @background_recording && "translate-x-6" || "translate-x-1"
                       ]}></span>
                     </button>
                   </div>
                 <% end %>
               </div>
             </div>
           </div>
         </div>

       <% else %>
         <!-- Mobile Recording Interface -->
         <div class="p-4 space-y-4">
           <!-- Mobile Mode Switcher -->
           <div class="flex bg-white/10 rounded-lg p-1">
             <button
               phx-click="mobile_switch_mode"
               phx-value-mode="simple"
               phx-target={@myself}
               class={[
                 "flex-1 py-2 px-3 rounded text-sm font-medium transition-colors",
                 @mobile_recording_mode == "simple" && "bg-white/20 text-white" || "text-white/60"
               ]}
             >
               Simple
             </button>
             <button
               phx-click="mobile_switch_mode"
               phx-value-mode="advanced"
               phx-target={@myself}
               class={[
                 "flex-1 py-2 px-3 rounded text-sm font-medium transition-colors",
                 @mobile_recording_mode == "advanced" && "bg-white/20 text-white" || "text-white/60"
               ]}
             >
               Advanced
             </button>
             <button
               phx-click="mobile_switch_mode"
               phx-value-mode="monitoring"
               phx-target={@myself}
               class={[
                 "flex-1 py-2 px-3 rounded text-sm font-medium transition-colors",
                 @mobile_recording_mode == "monitoring" && "bg-white/20 text-white" || "text-white/60"
               ]}
             >
               Monitor
             </button>
           </div>

           <!-- Mobile Content -->
           <%= case @mobile_recording_mode do %>
             <% "simple" -> %>
               <!-- Simple Mobile Recording -->
               <div class="space-y-4">
                 <!-- Quick Record Button -->
                 <div class="text-center">
                   <%= case @recording_state do %>
                     <% state when state in [:idle, :stopped] -> %>
                       <button
                         phx-click="mobile_quick_record"
                         phx-target={@myself}
                         disabled={@recording_permission != :granted or not can_record_audio?(@permissions)}
                         class="w-32 h-32 rounded-full bg-red-500 hover:bg-red-600 disabled:bg-red-500/50 disabled:cursor-not-allowed flex items-center justify-center text-white shadow-2xl transition-all duration-200 hover:scale-105"
                       >
                         <div class="w-8 h-8 bg-white rounded-full"></div>
                       </button>
                       <p class="text-white/70 text-sm mt-3">Tap to start recording</p>
                     <% :recording -> %>
                       <button
                         phx-click="stop_recording"
                         phx-target={@myself}
                         class="w-32 h-32 rounded-full bg-red-600 hover:bg-red-700 flex items-center justify-center text-white shadow-2xl transition-all duration-200 animate-pulse"
                       >
                         <div class="w-8 h-8 bg-white rounded-sm"></div>
                       </button>
                       <p class="text-red-300 text-sm mt-3 font-medium">
                         Recording: <%= format_duration(get_recording_time(assigns)) %>
                       </p>
                     <% :preparing -> %>
                       <div class="w-32 h-32 rounded-full bg-yellow-500 flex items-center justify-center text-white shadow-2xl animate-pulse mx-auto">
                         <span class="text-3xl font-bold"><%= @countdown %></span>
                       </div>
                       <p class="text-yellow-300 text-sm mt-3">Get ready...</p>
                   <% end %>
                 </div>

                 <!-- Mobile Level Meter -->
                 <div class="bg-black/20 rounded-xl p-4">
                   <div class="flex items-center justify-between mb-2">
                     <span class="text-white/80 text-sm">Input Level</span>
                     <%= if @clip_detected do %>
                       <span class="text-red-400 text-xs font-bold animate-pulse">CLIPPING!</span>
                     <% end %>
                   </div>

                   <div class="h-8 bg-black/30 rounded-full overflow-hidden relative">
                     <div
                       class={[
                         "h-full transition-all duration-75 rounded-full",
                         get_level_color(@input_level)
                       ]}
                       style={"width: #{@input_level * 100}%;"}
                     ></div>

                     <!-- Peak indicator -->
                     <%= if @peak_level > 0.95 do %>
                       <div class="absolute right-2 top-1 bottom-1 w-1 bg-red-500 animate-pulse rounded-full"></div>
                     <% end %>
                   </div>

                   <div class="text-center mt-2 text-white/70 text-sm font-mono">
                     <%= if @input_level > 0 do %>
                       <%= Float.round(20 * :math.log10(@input_level), 1) %> dB
                     <% else %>
                       -∞ dB
                     <% end %>
                   </div>
                 </div>

                 <!-- Track Selection -->
                 <%= if length(get_available_tracks(@workspace_state)) > 0 do %>
                   <div class="bg-black/20 rounded-xl p-4">
                     <h4 class="text-white font-medium mb-3">Record to Track</h4>
                     <div class="space-y-2">
                       <%= for track <- get_available_tracks(@workspace_state) do %>
                         <button
                           phx-click="select_track"
                           phx-value-track_id={track.id}
                           phx-target={@myself}
                           class={[
                             "w-full text-left p-3 rounded-lg transition-colors",
                             @recording_track == track.id && "bg-red-500/20 border border-red-500/30 text-red-300" || "bg-white/10 text-white/80"
                           ]}
                         >
                           <div class="font-medium">Track <%= track.number %>: <%= track.name %></div>
                           <div class="text-xs text-white/60">
                             <%= length(track.clips || []) %> clips
                           </div>
                         </button>
                       <% end %>
                     </div>
                   </div>
                 <% end %>
               </div>

             <% "advanced" -> %>
               <!-- Advanced Mobile Controls -->
               <div class="space-y-4">
                 <!-- Recording Controls -->
                 <div class="bg-black/20 rounded-xl p-4">
                   <h4 class="text-white font-medium mb-3">Recording Controls</h4>

                   <div class="grid grid-cols-2 gap-3">
                     <!-- Metronome -->
                     <div class="bg-white/10 rounded-lg p-3">
                       <div class="flex items-center justify-between mb-2">
                         <span class="text-white/80 text-sm">Metronome</span>
                         <button
                           phx-click="toggle_metronome"
                           phx-target={@myself}
                           class={[
                             "relative inline-flex h-5 w-9 items-center rounded-full transition-colors",
                             @metronome_enabled && "bg-blue-500" || "bg-white/20"
                           ]}
                         >
                           <span class={[
                             "inline-block h-3 w-3 transform rounded-full bg-white transition-transform",
                             @metronome_enabled && "translate-x-5" || "translate-x-1"
                           ]}></span>
                         </button>
                       </div>
                     </div>

                     <!-- Count-in -->
                     <div class="bg-white/10 rounded-lg p-3">
                       <div class="text-white/80 text-sm mb-2">Count-in</div>
                       <select
                         phx-change="update_count_in"
                         phx-target={@myself}
                         class="w-full bg-black/20 border border-white/20 rounded px-2 py-1 text-white text-sm"
                       >
                         <%= for count <- [0, 1, 2, 4] do %>
                           <option value={count} selected={@count_in_beats == count}>
                             <%= if count == 0, do: "None", else: "#{count} beats" %>
                           </option>
                         <% end %>
                       </select>
                     </div>
                   </div>

                   <!-- Quality Settings -->
                   <div class="mt-3">
                     <label class="text-white/80 text-sm mb-2 block">Recording Quality</label>
                     <select
                       phx-change="update_recording_quality"
                       phx-target={@myself}
                       class="w-full bg-white/10 border border-white/20 rounded px-3 py-2 text-white text-sm"
                     >
                       <option value="high" selected={@recording_quality == "high"}>High Quality</option>
                       <option value="medium" selected={@recording_quality == "medium"}>Medium Quality</option>
                       <option value="low" selected={@recording_quality == "low"}>Low Quality (Save Battery)</option>
                     </select>
                   </div>
                 </div>

                 <!-- Mobile Record Button -->
                 <div class="text-center">
                   <%= case @recording_state do %>
                     <% state when state in [:idle, :stopped] -> %>
                       <button
                         phx-click="start_recording"
                         phx-value-track_id={@recording_track}
                         phx-target={@myself}
                         disabled={is_nil(@recording_track) or @recording_permission != :granted or not can_record_audio?(@permissions)}
                         class="w-24 h-24 rounded-full bg-red-500 hover:bg-red-600 disabled:bg-red-500/50 disabled:cursor-not-allowed flex items-center justify-center text-white shadow-xl transition-all duration-200"
                       >
                         <div class="w-6 h-6 bg-white rounded-full"></div>
                       </button>
                     <% :recording -> %>
                       <div class="flex gap-4 justify-center">
                         <button
                           phx-click="pause_recording"
                           phx-target={@myself}
                           class="w-16 h-16 rounded-full bg-yellow-500 hover:bg-yellow-600 flex items-center justify-center text-white shadow-xl transition-all duration-200"
                         >
                           <div class="flex gap-1">
                             <div class="w-1.5 h-4 bg-white rounded-sm"></div>
                             <div class="w-1.5 h-4 bg-white rounded-sm"></div>
                           </div>
                         </button>
                         <button
                           phx-click="stop_recording"
                           phx-target={@myself}
                           class="w-16 h-16 rounded-full bg-red-600 hover:bg-red-700 flex items-center justify-center text-white shadow-xl transition-all duration-200"
                         >
                           <div class="w-4 h-4 bg-white rounded-sm"></div>
                         </button>
                       </div>
                     <% :paused -> %>
                       <div class="flex gap-4 justify-center">
                         <button
                           phx-click="resume_recording"
                           phx-target={@myself}
                           class="w-16 h-16 rounded-full bg-green-500 hover:bg-green-600 flex items-center justify-center text-white shadow-xl transition-all duration-200"
                         >
                           <svg class="h-5 w-5 ml-0.5" fill="currentColor" viewBox="0 0 24 24">
                             <path d="M8 5v14l11-7z"/>
                           </svg>
                         </button>
                         <button
                           phx-click="stop_recording"
                           phx-target={@myself}
                           class="w-16 h-16 rounded-full bg-red-600 hover:bg-red-700 flex items-center justify-center text-white shadow-xl transition-all duration-200"
                         >
                           <div class="w-4 h-4 bg-white rounded-sm"></div>
                         </button>
                       </div>
                   <% end %>
                 </div>

                 <!-- Takes List -->
                 <%= if length(@recorded_takes) > 0 do %>
                   <div class="bg-black/20 rounded-xl p-4">
                     <h4 class="text-white font-medium mb-3">Recent Takes</h4>
                     <div class="space-y-2">
                       <%= for take <- Enum.take(@recorded_takes, 3) do %>
                         <div class="bg-white/10 rounded-lg p-3 flex items-center justify-between">
                           <div>
                             <div class="text-white text-sm font-medium">Take <%= take.number %></div>
                             <div class="text-white/60 text-xs"><%= format_duration(take.duration) %></div>
                           </div>

                           <div class="flex gap-2">
                             <button
                               phx-click="select_take"
                               phx-value-take_id={take.id}
                               phx-target={@myself}
                               class="w-8 h-8 rounded bg-blue-500/20 text-blue-400 flex items-center justify-center"
                             >
                               <svg class="h-4 w-4" fill="currentColor" viewBox="0 0 24 24">
                                 <path d="M8 5v14l11-7z"/>
                               </svg>
                             </button>

                             <%= if can_edit_audio?(@permissions) do %>
                               <button
                                 phx-click="delete_take"
                                 phx-value-take_id={take.id}
                                 phx-target={@myself}
                                 data-confirm="Delete this take?"
                                 class="w-8 h-8 rounded bg-red-500/20 text-red-400 flex items-center justify-center"
                               >
                                 <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                   <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                                 </svg>
                               </button>
                             <% end %>
                           </div>
                         </div>
                       <% end %>
                     </div>
                   </div>
                 <% end %>
               </div>

             <% "monitoring" -> %>
               <!-- Mobile Monitoring -->
               <div class="space-y-4">
                 <!-- Large Level Meter -->
                 <div class="bg-black/20 rounded-xl p-6">
                   <h4 class="text-white font-medium mb-4 text-center">Input Monitor</h4>

                   <!-- Large Circular Level Meter -->
                   <div class="relative w-48 h-48 mx-auto">
                     <div class="absolute inset-0 rounded-full border-8 border-gray-800">
                       <div
                         class={[
                           "absolute inset-0 rounded-full border-8 transition-all duration-75",
                           get_level_color(@input_level),
                           "border-transparent"
                         ]}
                         style={"clip-path: conic-gradient(from 0deg, transparent 0%, transparent #{@input_level * 100}%, transparent #{@input_level * 100}%)"}
                       ></div>
                     </div>

                     <div class="absolute inset-0 flex items-center justify-center">
                       <div class="text-center">
                         <div class="text-2xl font-bold text-white font-mono">
                           <%= if @input_level > 0 do %>
                             <%= Float.round(20 * :math.log10(@input_level), 1) %>
                           <% else %>
                             -∞
                           <% end %>
                         </div>
                         <div class="text-sm text-white/60">dB</div>
                       </div>
                     </div>

                     <!-- Clip warning -->
                     <%= if @clip_detected do %>
                       <div class="absolute -top-4 left-1/2 transform -translate-x-1/2 bg-red-500 text-white text-xs px-3 py-1 rounded-full animate-pulse font-bold">
                         CLIP!
                       </div>
                     <% end %>
                   </div>

                   <!-- Peak Hold -->
                   <div class="text-center mt-4">
                     <div class="text-white/70 text-sm">
                       Peak: <%= if @peak_level > 0 do %>
                         <%= Float.round(20 * :math.log10(@peak_level), 1) %> dB
                       <% else %>
                         -∞ dB
                       <% end %>
                     </div>
                   </div>
                 </div>

                 <!-- Mobile Waveform -->
                 <div class="bg-black/20 rounded-xl p-4">
                   <h4 class="text-white font-medium mb-3">Live Waveform</h4>
                   <div class="h-20 bg-black/30 rounded-lg relative">
                     <canvas
                       id="mobile-waveform-canvas"
                       phx-hook="MobileLiveWaveform"
                       data-buffer={Jason.encode!(@waveform_buffer)}
                       class="absolute inset-0 w-full h-full"
                     ></canvas>

                     <%= if @recording_state == :recording do %>
                       <div class="absolute top-1 right-1 bg-red-500 text-white text-xs px-2 py-1 rounded-full animate-pulse">
                         REC
                       </div>
                     <% end %>
                   </div>
                 </div>

                 <!-- Mobile Quick Controls -->
                 <div class="grid grid-cols-2 gap-3">
                   <button
                     phx-click="toggle_metronome"
                     phx-target={@myself}
                     class={[
                       "py-3 px-4 rounded-xl font-medium transition-colors",
                       @metronome_enabled && "bg-blue-500/20 text-blue-300 border border-blue-500/30" || "bg-white/10 text-white/70"
                     ]}
                   >
                     <div class="flex items-center justify-center gap-2">
                       <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                         <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                       </svg>
                       <span class="text-sm">Metronome</span>
                     </div>
                   </button>

                   <div class="bg-white/10 rounded-xl p-3">
                     <div class="text-center">
                       <div class="text-white/80 text-sm mb-1">Quality</div>
                       <select
                         phx-change="update_recording_quality"
                         phx-target={@myself}
                         class="w-full bg-black/20 border border-white/20 rounded px-2 py-1 text-white text-xs"
                       >
                         <option value="high" selected={@recording_quality == "high"}>High</option>
                         <option value="medium" selected={@recording_quality == "medium"}>Medium</option>
                         <option value="low" selected={@recording_quality == "low"}>Low</option>
                       </select>
                     </div>
                   </div>
                 </div>
               </div>
           <% end %>
         </div>
       <% end %>
     </div>
   </div>
   """
 end
end
