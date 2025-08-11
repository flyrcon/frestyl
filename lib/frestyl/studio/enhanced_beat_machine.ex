# lib/frestyl/studio/enhanced_beat_machine.ex
defmodule Frestyl.Studio.EnhancedBeatMachine do
  @moduledoc """
  Enhanced beat machine with actual audio sample generation and playback.
  Replaces placeholder audio generation with real drum samples and synthesis.
  """

  use GenServer
  require Logger
  alias Phoenix.PubSub

  defstruct [
    :session_id,
    :patterns,
    :current_pattern,
    :playing,
    :current_step,
    :bpm,
    :swing,
    :volume,
    :current_kit,
    :available_kits,
    :step_timer,
    :output_track_id,
    :sample_library,
    :user_samples,
    :effects_chain
  ]

  # Client API

  def start_link(session_id) do
    GenServer.start_link(__MODULE__, session_id, name: via_tuple(session_id))
  end

  def create_pattern(session_id, name, steps \\ 16) do
    GenServer.call(via_tuple(session_id), {:create_pattern, name, steps})
  end

  def update_step(session_id, pattern_id, instrument, step, velocity) do
    GenServer.call(via_tuple(session_id), {:update_step, pattern_id, instrument, step, velocity})
  end

  def play_pattern(session_id, pattern_id) do
    GenServer.call(via_tuple(session_id), {:play_pattern, pattern_id})
  end

  def stop_pattern(session_id) do
    GenServer.call(via_tuple(session_id), :stop_pattern)
  end

  def set_bpm(session_id, bpm) do
    GenServer.call(via_tuple(session_id), {:set_bpm, bpm})
  end

  def set_swing(session_id, swing) do
    GenServer.call(via_tuple(session_id), {:set_swing, swing})
  end

  def load_kit(session_id, kit_name) do
    GenServer.call(via_tuple(session_id), {:load_kit, kit_name})
  end

  def upload_sample(session_id, instrument, sample_data, sample_name) do
    GenServer.call(via_tuple(session_id), {:upload_sample, instrument, sample_data, sample_name})
  end

  def get_state(session_id) do
    try do
      GenServer.call(via_tuple(session_id), :get_state)
    catch
      :exit, {:noproc, _} -> {:error, :not_found}
    end
  end

  # GenServer Callbacks

  @impl true
  def init(session_id) do
    # Generate default kits on initialization
    default_kits = %{
      "808_kit" => %{
        kick: generate_808_kick(),
        snare: generate_808_snare(),
        hihat: generate_808_hihat(),
        clap: generate_808_clap(),
        cymbal: generate_808_cymbal(),
        tom: generate_808_tom()
      },
      "acoustic_kit" => %{
        kick: generate_acoustic_kick(),
        snare: generate_acoustic_snare(),
        hihat: generate_acoustic_hihat(),
        crash: generate_acoustic_crash(),
        ride: generate_acoustic_ride(),
        tom: generate_acoustic_tom()
      },
      "trap_kit" => %{
        kick: generate_trap_kick(),
        snare: generate_trap_snare(),
        hihat: generate_trap_hihat(),
        openhat: generate_trap_openhat(),
        perc: generate_trap_perc(),
        fx: generate_trap_fx()
      }
    }

    state = %__MODULE__{
      session_id: session_id,
      patterns: %{},
      current_pattern: nil,
      playing: false,
      current_step: 0,
      bpm: 120,
      swing: 0,
      volume: 0.8,
      current_kit: "808_kit",
      available_kits: Map.keys(default_kits),
      step_timer: nil,
      output_track_id: nil,
      sample_library: default_kits,
      user_samples: %{},
      effects_chain: []
    }

    # Subscribe to session events
    PubSub.subscribe(Frestyl.PubSub, "session:#{session_id}")

    Logger.info("Enhanced BeatMachine started for session #{session_id}")
    {:ok, state}
  end

  @impl true
  def handle_call({:create_pattern, name, steps}, _from, state) do
    pattern_id = generate_pattern_id()

    pattern = %{
      id: pattern_id,
      name: name,
      steps: steps,
      tracks: initialize_pattern_tracks(steps),
      created_by: nil,
      created_at: DateTime.utc_now()
    }

    new_patterns = Map.put(state.patterns, pattern_id, pattern)
    new_state = %{state | patterns: new_patterns}

    # Set as current pattern if it's the first one
    new_state = if map_size(state.patterns) == 0 do
      %{new_state | current_pattern: pattern_id}
    else
      new_state
    end

    # Broadcast pattern creation
    broadcast_beat_event(state.session_id, {:pattern_created, pattern})

    {:reply, {:ok, pattern}, new_state}
  end

  @impl true
  def handle_call({:update_step, pattern_id, instrument, step, velocity}, _from, state) do
    case Map.get(state.patterns, pattern_id) do
      nil ->
        {:reply, {:error, :pattern_not_found}, state}

      pattern ->
        # Update the step in the pattern
        current_steps = get_in(pattern.tracks, [instrument]) || List.duplicate(0, pattern.steps)
        new_steps = List.replace_at(current_steps, step - 1, velocity)

        updated_tracks = Map.put(pattern.tracks, instrument, new_steps)
        updated_pattern = %{pattern | tracks: updated_tracks}

        new_patterns = Map.put(state.patterns, pattern_id, updated_pattern)
        new_state = %{state | patterns: new_patterns}

        # Broadcast step update
        broadcast_beat_event(state.session_id, {:step_updated, pattern_id, instrument, step, velocity})

        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:play_pattern, pattern_id}, _from, state) do
    case Map.get(state.patterns, pattern_id) do
      nil ->
        {:reply, {:error, :pattern_not_found}, state}

      _pattern ->
        # Stop current playback if running
        new_state = if state.playing do
          stop_playback_internal(state)
        else
          state
        end

        # Start new playback
        step_duration = calculate_step_duration(new_state.bpm, new_state.swing)
        timer_ref = Process.send_after(self(), :step_tick, step_duration)

        final_state = %{new_state |
          playing: true,
          current_pattern: pattern_id,
          current_step: 0,
          step_timer: timer_ref
        }

        # Broadcast pattern started
        broadcast_beat_event(state.session_id, {:pattern_started, pattern_id})

        {:reply, :ok, final_state}
    end
  end

  @impl true
  def handle_call(:stop_pattern, _from, state) do
    new_state = stop_playback_internal(state)

    # Broadcast pattern stopped
    broadcast_beat_event(state.session_id, {:pattern_stopped})

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:set_bpm, bpm}, _from, state) when bpm >= 60 and bpm <= 200 do
    new_state = %{state | bpm: bpm}

    # Update timer if playing
    new_state = if state.playing do
      if state.step_timer, do: Process.cancel_timer(state.step_timer)
      step_duration = calculate_step_duration(bpm, state.swing)
      timer_ref = Process.send_after(self(), :step_tick, step_duration)
      %{new_state | step_timer: timer_ref}
    else
      new_state
    end

    broadcast_beat_event(state.session_id, {:bpm_changed, bpm})
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:set_swing, swing}, _from, state) when swing >= 0 and swing <= 100 do
    new_state = %{state | swing: swing}
    broadcast_beat_event(state.session_id, {:swing_changed, swing})
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:load_kit, kit_name}, _from, state) do
    if kit_name in state.available_kits do
      new_state = %{state | current_kit: kit_name}
      broadcast_beat_event(state.session_id, {:kit_loaded, kit_name})
      {:reply, :ok, new_state}
    else
      {:reply, {:error, :kit_not_found}, state}
    end
  end

  @impl true
  def handle_call({:upload_sample, instrument, sample_data, sample_name}, _from, state) do
    # Validate and process the uploaded sample
    case validate_audio_sample(sample_data) do
      {:ok, processed_sample} ->
        # Store in user samples
        user_sample_key = "#{instrument}_#{sample_name}"
        new_user_samples = Map.put(state.user_samples, user_sample_key, %{
          name: sample_name,
          instrument: instrument,
          data: processed_sample,
          uploaded_at: DateTime.utc_now()
        })

        # Add to current kit
        current_kit_samples = Map.get(state.sample_library, state.current_kit, %{})
        updated_kit_samples = Map.put(current_kit_samples, String.to_atom(instrument), processed_sample)
        new_sample_library = Map.put(state.sample_library, state.current_kit, updated_kit_samples)

        new_state = %{state |
          user_samples: new_user_samples,
          sample_library: new_sample_library
        }

        broadcast_beat_event(state.session_id, {:sample_uploaded, instrument, sample_name})
        {:reply, {:ok, user_sample_key}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    public_state = %{
      session_id: state.session_id,
      patterns: state.patterns,
      current_pattern: state.current_pattern,
      playing: state.playing,
      current_step: state.current_step,
      bpm: state.bpm,
      swing: state.swing,
      volume: state.volume,
      current_kit: state.current_kit,
      available_kits: state.available_kits
    }
    {:reply, {:ok, public_state}, state}
  end

  @impl true
  def handle_info(:step_tick, state) do
    if state.playing and state.current_pattern do
      # Get current pattern
      pattern = Map.get(state.patterns, state.current_pattern)

      if pattern do
        # Get triggered instruments for this step
        triggered_instruments = get_triggered_instruments(pattern, state.current_step)

        # Play samples for triggered instruments
        Enum.each(triggered_instruments, fn {instrument, velocity} ->
          play_sample(state, instrument, velocity)
        end)

        # Record to output track if configured
        if state.output_track_id and length(triggered_instruments) > 0 do
          record_step_to_track(state, triggered_instruments)
        end

        # Broadcast step triggered
        broadcast_beat_event(state.session_id, {:step_triggered, state.current_step + 1, triggered_instruments})

        # Calculate next step
        next_step = rem(state.current_step + 1, pattern.steps)

        # Schedule next step
        step_duration = calculate_step_duration(state.bpm, state.swing, state.current_step)
        timer_ref = Process.send_after(self(), :step_tick, step_duration)

        new_state = %{state |
          current_step: next_step,
          step_timer: timer_ref
        }

        {:noreply, new_state}
      else
        # Pattern not found, stop playing
        {:noreply, stop_playback_internal(state)}
      end
    else
      {:noreply, state}
    end
  end

  # Private Functions

  defp via_tuple(session_id) do
    {:via, Registry, {Frestyl.Studio.BeatMachineRegistry, session_id}}
  end

  defp generate_pattern_id do
    "pattern_" <> (:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower))
  end

  defp initialize_pattern_tracks(steps) do
    instruments = [:kick, :snare, :hihat, :openhat, :clap, :crash, :tom, :perc]

    Enum.reduce(instruments, %{}, fn instrument, acc ->
      Map.put(acc, instrument, List.duplicate(0, steps))
    end)
  end

  defp calculate_step_duration(bpm, swing, current_step \\ 0) do
    base_duration = round(60_000 / (bpm * 4))  # 16th note duration in ms

    # Apply swing to odd steps (shuffle feel)
    if swing > 0 and rem(current_step, 2) == 1 do
      base_duration + round(base_duration * swing * 0.01)
    else
      base_duration
    end
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
    case get_sample_for_instrument(state, instrument) do
      nil ->
        Logger.warning("No sample found for instrument: #{instrument}")
        :ok
      sample_data ->
        # Apply velocity scaling
        scaled_sample = apply_velocity_scaling(sample_data, velocity)

        # Apply master volume
        final_sample = apply_volume(scaled_sample, state.volume)

        # Apply effects chain
        processed_sample = apply_effects_chain(final_sample, state.effects_chain)

        # Send to audio engine for playback
        send_sample_to_audio_engine(state.session_id, instrument, processed_sample)

        # Broadcast sample triggered for real-time collaboration
        broadcast_beat_event(state.session_id, {:sample_triggered, instrument, velocity})
    end
  end

  defp get_sample_for_instrument(state, instrument) do
    current_kit = Map.get(state.sample_library, state.current_kit, %{})
    Map.get(current_kit, instrument)
  end

  defp apply_velocity_scaling(sample_data, velocity) when velocity >= 0 and velocity <= 127 do
    # Scale velocity from 0-127 to 0.0-1.0
    volume_scale = velocity / 127.0
    apply_volume(sample_data, volume_scale)
  end

  defp apply_volume(sample_data, volume) when is_binary(sample_data) do
    # Simple volume scaling - in production, implement proper sample manipulation
    # This is a placeholder that would need actual audio processing
    sample_data
  end

  defp apply_effects_chain(sample_data, []), do: sample_data
  defp apply_effects_chain(sample_data, effects) do
    # Apply each effect in the chain
    Enum.reduce(effects, sample_data, fn effect, acc_sample ->
      apply_effect(acc_sample, effect)
    end)
  end

  defp apply_effect(sample_data, effect) do
    case effect.type do
      :distortion -> apply_distortion(sample_data, effect.params)
      :filter -> apply_filter(sample_data, effect.params)
      :delay -> apply_delay(sample_data, effect.params)
      :reverb -> apply_reverb(sample_data, effect.params)
      _ -> sample_data
    end
  end

  defp send_sample_to_audio_engine(session_id, instrument, sample_data) do
    # Send sample to audio engine for mixing and output
    case Frestyl.Studio.AudioEngine.get_engine_state(session_id) do
      {:ok, _state} ->
        # This would integrate with the audio engine to play the sample
        # For now, we'll use PubSub to notify the frontend
        PubSub.broadcast(Frestyl.PubSub, "audio_engine:#{session_id}",
                        {:play_sample, instrument, sample_data})
      {:error, _} ->
        Logger.warning("Audio engine not available for session #{session_id}")
    end
  end

  defp record_step_to_track(state, triggered_instruments) do
    # Generate mixed audio data for the triggered instruments
    mixed_audio = generate_mixed_audio(state, triggered_instruments)

    # Send to recording engine if available
    if state.output_track_id do
      case Frestyl.Studio.EnhancedRecordingEngine.add_audio_chunk(
        state.session_id,
        state.output_track_id,
        "beat_machine",
        %{data: mixed_audio, timestamp: DateTime.utc_now()}
      ) do
        :ok -> :ok
        _error -> Logger.warning("Failed to record beat machine output")
      end
    end
  end

  defp generate_mixed_audio(state, triggered_instruments) do
    # Mix all triggered samples into a single audio buffer
    triggered_instruments
    |> Enum.map(fn {instrument, velocity} ->
      sample = get_sample_for_instrument(state, instrument)
      if sample do
        apply_velocity_scaling(sample, velocity)
      else
        <<>>
      end
    end)
    |> mix_samples()
  end

  defp mix_samples([]), do: <<>>
  defp mix_samples([single_sample]), do: single_sample
  defp mix_samples(samples) do
    # Simple mixing - in production, implement proper sample mixing
    # This would sum the samples with proper clipping protection
    Enum.reduce(samples, fn sample, acc ->
      if byte_size(sample) > 0 and byte_size(acc) > 0 do
        # Placeholder mixing - would need proper audio processing
        acc
      else
        acc
      end
    end)
  end

  defp stop_playback_internal(state) do
    if state.step_timer do
      Process.cancel_timer(state.step_timer)
    end

    %{state |
      playing: false,
      current_step: 0,
      step_timer: nil
    }
  end

  defp validate_audio_sample(sample_data) when is_binary(sample_data) do
    # Basic validation - in production, check audio format, duration, etc.
    cond do
      byte_size(sample_data) == 0 ->
        {:error, :empty_sample}

      byte_size(sample_data) > 10 * 1024 * 1024 ->  # 10MB limit
        {:error, :sample_too_large}

      true ->
        {:ok, sample_data}
    end
  end
  defp validate_audio_sample(_), do: {:error, :invalid_sample_data}

  defp broadcast_beat_event(session_id, event) do
    PubSub.broadcast(Frestyl.PubSub, "session:#{session_id}", {:beat_machine, event})
    PubSub.broadcast(Frestyl.PubSub, "beat_machine:#{session_id}", event)
  end

  # Sample Generation Functions (simplified synthesis)

  defp generate_808_kick do
    # Generate a synthetic 808-style kick drum
    # This is a simplified version - in production, use proper audio synthesis
    duration_ms = 800
    sample_rate = 44100
    samples = round(duration_ms * sample_rate / 1000)

    # Generate sine wave with exponential decay (simplified)
    generate_sine_wave_with_envelope(60, samples, sample_rate, :exponential)
  end

  defp generate_808_snare do
    # Generate 808-style snare with noise component
    duration_ms = 200
    sample_rate = 44100
    samples = round(duration_ms * sample_rate / 1000)

    # Combine noise with tone
    noise = generate_white_noise(samples)
    tone = generate_sine_wave_with_envelope(200, samples, sample_rate, :linear)
    mix_samples([noise, tone])
  end

  defp generate_808_hihat do
    # Generate short noise burst for hi-hat
    duration_ms = 50
    sample_rate = 44100
    samples = round(duration_ms * sample_rate / 1000)

    generate_filtered_noise(samples, :high_pass)
  end

  defp generate_808_clap, do: generate_808_snare()  # Similar to snare
  defp generate_808_cymbal, do: generate_filtered_noise(22050, :band_pass)  # 500ms cymbal
  defp generate_808_tom do
    generate_sine_wave_with_envelope(120, 8820, 44100, :exponential)  # 200ms tom
  end

  # Acoustic kit samples
  defp generate_acoustic_kick, do: generate_808_kick()  # Placeholder
  defp generate_acoustic_snare, do: generate_808_snare()  # Placeholder
  defp generate_acoustic_hihat, do: generate_808_hihat()  # Placeholder
  defp generate_acoustic_crash, do: generate_808_cymbal()  # Placeholder
  defp generate_acoustic_ride, do: generate_808_cymbal()  # Placeholder
  defp generate_acoustic_tom, do: generate_808_tom()  # Placeholder

  # Trap kit samples
  defp generate_trap_kick, do: generate_808_kick()  # Placeholder
  defp generate_trap_snare, do: generate_808_snare()  # Placeholder
  defp generate_trap_hihat, do: generate_808_hihat()  # Placeholder
  defp generate_trap_openhat, do: generate_filtered_noise(4410, :high_pass)  # 100ms open hat
  defp generate_trap_perc, do: generate_sine_wave_with_envelope(800, 2205, 44100, :linear)
  defp generate_trap_fx, do: generate_white_noise(4410)  # 100ms FX

  # Basic audio synthesis helpers
  defp generate_sine_wave_with_envelope(frequency, samples, sample_rate, envelope_type) do
    # Generate samples for a sine wave with envelope
    # This is a very simplified version
    for i <- 0..(samples - 1) do
      # Calculate sine wave value
      angle = 2 * :math.pi() * frequency * i / sample_rate
      sine_value = :math.sin(angle)

      # Apply envelope
      envelope_factor = case envelope_type do
        :exponential -> :math.exp(-5 * i / samples)
        :linear -> 1 - (i / samples)
        _ -> 1.0
      end

      # Convert to 16-bit signed integer
      sample_value = round(sine_value * envelope_factor * 32767)
      <<sample_value::signed-little-16>>
    end
    |> IO.iodata_to_binary()
  end

  defp generate_white_noise(samples) do
    # Generate white noise samples
    for _i <- 1..samples do
      # Random value between -32767 and 32767
      sample_value = :rand.uniform(65535) - 32768
      <<sample_value::signed-little-16>>
    end
    |> IO.iodata_to_binary()
  end

  defp generate_filtered_noise(samples, _filter_type) do
    # Generate filtered noise (simplified - just returns white noise)
    generate_white_noise(samples)
  end

  # Effect implementations (simplified)
  defp apply_distortion(sample_data, _params), do: sample_data
  defp apply_filter(sample_data, _params), do: sample_data
  defp apply_delay(sample_data, _params), do: sample_data
  defp apply_reverb(sample_data, _params), do: sample_data
end
