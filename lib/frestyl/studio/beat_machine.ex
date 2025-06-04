# lib/frestyl/studio/beat_machine.ex
defmodule Frestyl.Studio.BeatMachine do
  @moduledoc """
  Beat machine engine that integrates with the audio engine for
  drum patterns, loops, and rhythm generation.
  """

  use GenServer
  require Logger
  alias Frestyl.Studio.AudioEngine
  alias Phoenix.PubSub

  defstruct [
    :session_id,
    :patterns,
    :active_pattern,
    :kit,
    :bpm,
    :swing,
    :steps_per_pattern,
    :playing,
    :current_step,
    :pattern_bank,
    :sample_library,
    :effects,
    :output_track_id
  ]

  # Sample kits available
  @default_kits %{
    "classic_808" => %{
      kick: "/samples/808/kick.wav",
      snare: "/samples/808/snare.wav",
      hihat: "/samples/808/hihat.wav",
      openhat: "/samples/808/openhat.wav",
      crash: "/samples/808/crash.wav",
      clap: "/samples/808/clap.wav"
    },
    "acoustic" => %{
      kick: "/samples/acoustic/kick.wav",
      snare: "/samples/acoustic/snare.wav",
      hihat: "/samples/acoustic/hihat.wav",
      tom_high: "/samples/acoustic/tom_high.wav",
      tom_low: "/samples/acoustic/tom_low.wav",
      crash: "/samples/acoustic/crash.wav"
    },
    "electronic" => %{
      kick: "/samples/electronic/kick.wav",
      snare: "/samples/electronic/snare.wav",
      hihat: "/samples/electronic/hihat.wav",
      perc: "/samples/electronic/perc.wav",
      fx: "/samples/electronic/fx.wav",
      bass: "/samples/electronic/bass.wav"
    }
  }

  # Public API

  def start_link(session_id) do
    GenServer.start_link(__MODULE__, session_id, name: via_tuple(session_id))
  end

  def create_pattern(session_id, pattern_name, steps \\ 16) do
    GenServer.call(via_tuple(session_id), {:create_pattern, pattern_name, steps})
  end

  def update_pattern_step(session_id, pattern_id, instrument, step, velocity) do
    GenServer.call(via_tuple(session_id), {:update_pattern_step, pattern_id, instrument, step, velocity})
  end

  def play_pattern(session_id, pattern_id) do
    GenServer.call(via_tuple(session_id), {:play_pattern, pattern_id})
  end

  def stop_pattern(session_id) do
    GenServer.call(via_tuple(session_id), :stop_pattern)
  end

  def change_kit(session_id, kit_name) do
    GenServer.call(via_tuple(session_id), {:change_kit, kit_name})
  end

  def set_bpm(session_id, bpm) do
    GenServer.call(via_tuple(session_id), {:set_bpm, bpm})
  end

  def set_swing(session_id, swing_amount) do
    GenServer.call(via_tuple(session_id), {:set_swing, swing_amount})
  end

  def get_beat_machine_state(session_id) do
    GenServer.call(via_tuple(session_id), :get_state)
  end

  def record_to_audio_track(session_id, track_id) do
    GenServer.call(via_tuple(session_id), {:record_to_audio_track, track_id})
  end

  # GenServer Callbacks

  @impl true
  def init(session_id) do
    state = %__MODULE__{
      session_id: session_id,
      patterns: %{},
      active_pattern: nil,
      kit: @default_kits["classic_808"],
      bpm: 120,
      swing: 0,
      steps_per_pattern: 16,
      playing: false,
      current_step: 0,
      pattern_bank: [],
      sample_library: load_sample_library(),
      effects: [],
      output_track_id: nil
    }

    # Create default pattern
    default_pattern = create_default_pattern()
    state = %{state |
      patterns: %{"default" => default_pattern},
      active_pattern: "default"
    }

    # Subscribe to audio engine events
    PubSub.subscribe(Frestyl.PubSub, "audio_engine:#{session_id}")

    {:ok, state}
  end

  @impl true
  def handle_call({:create_pattern, pattern_name, steps}, _from, state) do
    pattern = %{
      id: generate_pattern_id(),
      name: pattern_name,
      steps: steps,
      tracks: initialize_pattern_tracks(steps),
      created_at: DateTime.utc_now(),
      bpm: state.bpm,
      swing: state.swing
    }

    new_patterns = Map.put(state.patterns, pattern.id, pattern)
    new_state = %{state | patterns: new_patterns}

    # Broadcast pattern created
    broadcast_beat_event(state.session_id, {:pattern_created, pattern})

    {:reply, {:ok, pattern}, new_state}
  end

  @impl true
  def handle_call({:update_pattern_step, pattern_id, instrument, step, velocity}, _from, state) do
    case Map.get(state.patterns, pattern_id) do
      nil -> {:reply, {:error, :pattern_not_found}, state}
      pattern ->
        # Update the step in the pattern
        instrument_track = Map.get(pattern.tracks, instrument, [])
        updated_track = List.replace_at(instrument_track, step - 1, velocity)
        updated_tracks = Map.put(pattern.tracks, instrument, updated_track)
        updated_pattern = %{pattern | tracks: updated_tracks}

        new_patterns = Map.put(state.patterns, pattern_id, updated_pattern)
        new_state = %{state | patterns: new_patterns}

        # Broadcast step updated
        broadcast_beat_event(state.session_id, {:step_updated, pattern_id, instrument, step, velocity})

        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:play_pattern, pattern_id}, _from, state) do
    case Map.get(state.patterns, pattern_id) do
      nil -> {:reply, {:error, :pattern_not_found}, state}
      pattern ->
        new_state = %{state |
          playing: true,
          active_pattern: pattern_id,
          current_step: 0
        }

        # Start the sequencer timer
        schedule_next_step(new_state)

        # Broadcast pattern started
        broadcast_beat_event(state.session_id, {:pattern_started, pattern_id})

        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call(:stop_pattern, _from, state) do
    new_state = %{state | playing: false, current_step: 0}

    # Broadcast pattern stopped
    broadcast_beat_event(state.session_id, {:pattern_stopped})

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:change_kit, kit_name}, _from, state) do
    case Map.get(@default_kits, kit_name) do
      nil -> {:reply, {:error, :kit_not_found}, state}
      kit ->
        new_state = %{state | kit: kit}

        # Broadcast kit changed
        broadcast_beat_event(state.session_id, {:kit_changed, kit_name, kit})

        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:set_bpm, bpm}, _from, state) do
    new_state = %{state | bpm: bpm}

    # Update active pattern BPM
    if state.active_pattern do
      pattern = state.patterns[state.active_pattern]
      updated_pattern = %{pattern | bpm: bpm}
      new_patterns = Map.put(state.patterns, state.active_pattern, updated_pattern)
      new_state = %{new_state | patterns: new_patterns}
    end

    # Broadcast BPM changed
    broadcast_beat_event(state.session_id, {:bpm_changed, bpm})

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:set_swing, swing_amount}, _from, state) do
    new_state = %{state | swing: swing_amount}

    # Broadcast swing changed
    broadcast_beat_event(state.session_id, {:swing_changed, swing_amount})

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:record_to_audio_track, track_id}, _from, state) do
    new_state = %{state | output_track_id: track_id}

    # Broadcast recording setup
    broadcast_beat_event(state.session_id, {:recording_to_track, track_id})

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    public_state = %{
      session_id: state.session_id,
      patterns: state.patterns,
      active_pattern: state.active_pattern,
      kit: state.kit,
      bpm: state.bpm,
      swing: state.swing,
      playing: state.playing,
      current_step: state.current_step,
      available_kits: Map.keys(@default_kits),
      output_track_id: state.output_track_id
    }

    {:reply, public_state, state}
  end

  @impl true
  def handle_info(:step_trigger, state) do
    if state.playing and state.active_pattern do
      pattern = state.patterns[state.active_pattern]

      # Calculate current step (with swing)
      current_step = rem(state.current_step, state.steps_per_pattern)

      # Trigger instruments for this step
      triggered_instruments = get_triggered_instruments(pattern, current_step)

      # Play samples for triggered instruments
      Enum.each(triggered_instruments, fn {instrument, velocity} ->
        play_sample(state, instrument, velocity)
      end)

      # Record to audio track if set up
      if state.output_track_id and length(triggered_instruments) > 0 do
        record_step_to_track(state, triggered_instruments)
      end

      # Broadcast step triggered
      broadcast_beat_event(state.session_id, {:step_triggered, current_step, triggered_instruments})

      # Update state and schedule next step
      new_state = %{state | current_step: state.current_step + 1}

      if new_state.playing do
        schedule_next_step(new_state)
      end

      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # Private Functions

  defp via_tuple(session_id) do
    {:via, Registry, {Frestyl.Studio.BeatMachineRegistry, session_id}}
  end

  defp generate_pattern_id do
    "pattern_" <> (:crypto.strong_rand_bytes(6) |> Base.encode16(case: :lower))
  end

  defp create_default_pattern do
    %{
      id: "default",
      name: "Basic Beat",
      steps: 16,
      tracks: %{
        kick: [127, 0, 0, 0, 127, 0, 0, 0, 127, 0, 0, 0, 127, 0, 0, 0],
        snare: [0, 0, 127, 0, 0, 0, 127, 0, 0, 0, 127, 0, 0, 0, 127, 0],
        hihat: [64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64]
      },
      created_at: DateTime.utc_now(),
      bpm: 120,
      swing: 0
    }
  end

  defp initialize_pattern_tracks(steps) do
    instruments = ["kick", "snare", "hihat", "openhat", "crash", "clap"]

    instruments
    |> Enum.map(fn instrument ->
      {instrument, List.duplicate(0, steps)}
    end)
    |> Map.new()
  end

  defp schedule_next_step(state) do
    # Calculate step duration in milliseconds
    step_duration = calculate_step_duration(state.bpm, state.swing, state.current_step)
    Process.send_after(self(), :step_trigger, step_duration)
  end

  defp calculate_step_duration(bpm, swing, current_step) do
    # Base duration for 16th notes
    base_duration = 60_000 / (bpm * 4)

    # Apply swing to odd steps (shuffle feel)
    if swing > 0 and rem(current_step, 2) == 1 do
      base_duration + (base_duration * swing * 0.1)
    else
      base_duration
    end
    |> round()
  end

  defp get_triggered_instruments(pattern, step) do
    pattern.tracks
    |> Enum.filter(fn {_instrument, steps} ->
      velocity = Enum.at(steps, step, 0)
      velocity > 0
    end)
    |> Enum.map(fn {instrument, steps} ->
      velocity = Enum.at(steps, step, 0)
      {instrument, velocity}
    end)
  end

  defp play_sample(state, instrument, velocity) do
    case Map.get(state.kit, String.to_atom(instrument)) do
      nil -> :ok
      sample_path ->
        # This would integrate with your WebRTC audio streaming
        # For now, we'll broadcast the sample trigger
        broadcast_beat_event(state.session_id, {:sample_triggered, instrument, sample_path, velocity})
    end
  end

  defp record_step_to_track(state, triggered_instruments) do
    # Generate audio data for the triggered instruments
    # This is a simplified version - in production you'd mix the samples
    audio_data = generate_mixed_audio(triggered_instruments, state.kit)

    # Send to audio engine for recording
    if state.output_track_id do
      AudioEngine.record_to_track(
        state.session_id,
        state.output_track_id,
        :beat_machine,
        audio_data
      )
    end
  end

  defp generate_mixed_audio(triggered_instruments, kit) do
    # This is a placeholder - would actually mix samples
    # For now, return a simple audio buffer
    <<0::size(1024*8)>>
  end

  defp load_sample_library do
    # Load available samples for the beat machine
    %{
      "user_samples" => [],
      "factory_samples" => @default_kits,
      "imported_samples" => []
    }
  end

  defp broadcast_beat_event(session_id, event) do
    PubSub.broadcast(Frestyl.PubSub, "session:#{session_id}", {:beat_machine, event})
    PubSub.broadcast(Frestyl.PubSub, "beat_machine:#{session_id}", event)
  end
end
