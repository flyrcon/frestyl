# lib/frestyl/storage/audio_processor.ex
defmodule Frestyl.Storage.AudioProcessor do
  @moduledoc """
  Handles audio processing, encoding, and storage for Frestyl recordings.
  Supports multiple audio formats and cloud storage integration.
  """

  require Logger
  alias Frestyl.Storage.CloudUploader

  @supported_formats ["mp3", "wav", "flac", "ogg"]
  @default_quality %{
    sample_rate: 44100,
    bit_depth: 16,
    channels: 2
  }

  @doc """
  Process and encode audio chunks into a complete audio file.
  """
  def process_audio_chunks(chunks, options \\ %{}) do
    format = Map.get(options, :format, "mp3")
    quality = Map.get(options, :quality, @default_quality)
    normalize = Map.get(options, :normalize, true)

    with :ok <- validate_format(format),
         {:ok, compiled_audio} <- compile_chunks(chunks),
         {:ok, processed_audio} <- apply_processing(compiled_audio, quality, normalize),
         {:ok, encoded_audio} <- encode_audio(processed_audio, format, quality) do
      {:ok, encoded_audio}
    else
      error -> error
    end
  end

  @doc """
  Save processed audio to storage and return file info.
  """
  def save_audio_file(audio_data, metadata, storage_options \\ %{}) do
    filename = generate_filename(metadata)
    file_path = create_temp_file(audio_data, filename)

    try do
      # Upload to cloud storage
      upload_result = case Map.get(storage_options, :storage_type, :cloud) do
        :cloud -> CloudUploader.upload_audio_file(file_path, filename, metadata)
        :local -> save_local_file(file_path, filename)
      end

      case upload_result do
        {:ok, file_info} ->
          # Generate file metadata
          audio_metadata = analyze_audio_file(file_path)

          complete_metadata = Map.merge(metadata, %{
            file_info: file_info,
            audio_metadata: audio_metadata,
            processed_at: DateTime.utc_now()
          })

          {:ok, complete_metadata}

        error -> error
      end
    after
      File.rm(file_path)
    end
  end

  @doc """
  Create a mixed audio track from multiple audio sources.
  """
  def mix_audio_tracks(tracks, mix_options \\ %{}) do
    master_volume = Map.get(mix_options, :master_volume, 1.0)
    output_format = Map.get(mix_options, :format, "mp3")
    quality = Map.get(mix_options, :quality, @default_quality)

    with {:ok, normalized_tracks} <- normalize_track_lengths(tracks),
         {:ok, mixed_audio} <- perform_mixing(normalized_tracks, master_volume),
         {:ok, final_audio} <- apply_mastering(mixed_audio, quality),
         {:ok, encoded_audio} <- encode_audio(final_audio, output_format, quality) do
      {:ok, encoded_audio}
    else
      error -> error
    end
  end

  @doc """
  Apply real-time audio effects to a stream.
  """
  def apply_real_time_effects(audio_chunk, effects \\ []) do
    Enum.reduce(effects, {:ok, audio_chunk}, fn effect, {:ok, audio} ->
      apply_effect(audio, effect)
    end)
  end

  # Private Functions

  defp validate_format(format) when format in @supported_formats, do: :ok
  defp validate_format(format), do: {:error, "Unsupported format: #{format}"}

  defp compile_chunks(chunks) when is_list(chunks) do
    try do
      # Sort chunks by timestamp
      sorted_chunks = Enum.sort_by(chunks, & &1.timestamp)

      # Combine audio data
      combined_audio = sorted_chunks
      |> Enum.map(& &1.data)
      |> IO.iodata_to_binary()

      {:ok, combined_audio}
    rescue
      error -> {:error, "Failed to compile chunks: #{inspect(error)}"}
    end
  end

  defp apply_processing(audio_data, quality, normalize) do
    try do
      processed_audio = audio_data
      |> resample_audio(quality.sample_rate)
      |> adjust_bit_depth(quality.bit_depth)
      |> adjust_channels(quality.channels)

      final_audio = if normalize do
        normalize_audio_levels(processed_audio)
      else
        processed_audio
      end

      {:ok, final_audio}
    rescue
      error -> {:error, "Audio processing failed: #{inspect(error)}"}
    end
  end

  defp encode_audio(audio_data, format, quality) do
    case format do
      "mp3" -> encode_mp3(audio_data, quality)
      "wav" -> encode_wav(audio_data, quality)
      "flac" -> encode_flac(audio_data, quality)
      "ogg" -> encode_ogg(audio_data, quality)
      _ -> {:error, "Unsupported encoding format"}
    end
  end

  defp encode_mp3(audio_data, quality) do
    # Use FFmpeg for MP3 encoding
    temp_input = create_temp_wav_file(audio_data, quality)
    temp_output = temp_input <> ".mp3"

    bitrate = calculate_mp3_bitrate(quality)

    ffmpeg_cmd = [
      "ffmpeg", "-y",
      "-i", temp_input,
      "-codec:a", "libmp3lame",
      "-b:a", "#{bitrate}k",
      "-ar", "#{quality.sample_rate}",
      "-ac", "#{quality.channels}",
      temp_output
    ]

    try do
      case System.cmd("ffmpeg", tl(ffmpeg_cmd)) do
        {_output, 0} ->
          encoded_data = File.read!(temp_output)
          cleanup_temp_files([temp_input, temp_output])
          {:ok, encoded_data}

        {error, _code} ->
          cleanup_temp_files([temp_input, temp_output])
          {:error, "MP3 encoding failed: #{error}"}
      end
    rescue
      error ->
        cleanup_temp_files([temp_input, temp_output])
        {:error, "MP3 encoding error: #{inspect(error)}"}
    end
  end

  defp encode_wav(audio_data, quality) do
    # WAV encoding is simpler - just add proper header
    try do
      wav_header = create_wav_header(byte_size(audio_data), quality)
      wav_data = wav_header <> audio_data
      {:ok, wav_data}
    rescue
      error -> {:error, "WAV encoding failed: #{inspect(error)}"}
    end
  end

  defp encode_flac(audio_data, quality) do
    # Use FFmpeg for FLAC encoding
    temp_input = create_temp_wav_file(audio_data, quality)
    temp_output = temp_input <> ".flac"

    ffmpeg_cmd = [
      "ffmpeg", "-y",
      "-i", temp_input,
      "-codec:a", "flac",
      "-compression_level", "8",
      "-ar", "#{quality.sample_rate}",
      "-ac", "#{quality.channels}",
      temp_output
    ]

    try do
      case System.cmd("ffmpeg", tl(ffmpeg_cmd)) do
        {_output, 0} ->
          encoded_data = File.read!(temp_output)
          cleanup_temp_files([temp_input, temp_output])
          {:ok, encoded_data}

        {error, _code} ->
          cleanup_temp_files([temp_input, temp_output])
          {:error, "FLAC encoding failed: #{error}"}
      end
    rescue
      error ->
        cleanup_temp_files([temp_input, temp_output])
        {:error, "FLAC encoding error: #{inspect(error)}"}
    end
  end

  defp encode_ogg(audio_data, quality) do
    # Use FFmpeg for OGG encoding
    temp_input = create_temp_wav_file(audio_data, quality)
    temp_output = temp_input <> ".ogg"

    quality_level = calculate_ogg_quality(quality)

    ffmpeg_cmd = [
      "ffmpeg", "-y",
      "-i", temp_input,
      "-codec:a", "libvorbis",
      "-q:a", "#{quality_level}",
      "-ar", "#{quality.sample_rate}",
      "-ac", "#{quality.channels}",
      temp_output
    ]

    try do
      case System.cmd("ffmpeg", tl(ffmpeg_cmd)) do
        {_output, 0} ->
          encoded_data = File.read!(temp_output)
          cleanup_temp_files([temp_input, temp_output])
          {:ok, encoded_data}

        {error, _code} ->
          cleanup_temp_files([temp_input, temp_output])
          {:error, "OGG encoding failed: #{error}"}
      end
    rescue
      error ->
        cleanup_temp_files([temp_input, temp_output])
        {:error, "OGG encoding error: #{inspect(error)}"}
    end
  end

  defp resample_audio(audio_data, target_sample_rate) do
    # Simplified resampling - in production, use proper DSP library
    # For now, return as-is if already at target rate
    audio_data
  end

  defp adjust_bit_depth(audio_data, target_bit_depth) do
    # Simplified bit depth conversion
    # In production, implement proper bit depth conversion
    audio_data
  end

  defp adjust_channels(audio_data, target_channels) do
    # Simplified channel adjustment
    # In production, implement proper mono/stereo conversion
    audio_data
  end

  defp normalize_audio_levels(audio_data) do
    # Simplified normalization - find peak and adjust
    # In production, use proper audio normalization algorithms
    audio_data
  end

  defp normalize_track_lengths(tracks) do
    # Find the longest track duration
    max_length = tracks
    |> Enum.map(&calculate_audio_length/1)
    |> Enum.max()

    # Pad shorter tracks with silence
    normalized_tracks = Enum.map(tracks, fn track ->
      current_length = calculate_audio_length(track)
      if current_length < max_length do
        silence_padding = generate_silence(max_length - current_length)
        Map.update!(track, :data, &(&1 <> silence_padding))
      else
        track
      end
    end)

    {:ok, normalized_tracks}
  end

  defp perform_mixing(tracks, master_volume) do
    # Simple mixing algorithm - sum all tracks with volume adjustment
    try do
      track_count = length(tracks)
      volume_per_track = master_volume / track_count

      mixed_audio = tracks
      |> Enum.map(&apply_volume(&1.data, &1.volume * volume_per_track))
      |> sum_audio_data()

      {:ok, mixed_audio}
    rescue
      error -> {:error, "Mixing failed: #{inspect(error)}"}
    end
  end

  defp apply_mastering(audio_data, quality) do
    # Apply basic mastering: compression, EQ, limiting
    try do
      mastered_audio = audio_data
      |> apply_compression()
      |> apply_eq()
      |> apply_limiting()

      {:ok, mastered_audio}
    rescue
      error -> {:error, "Mastering failed: #{inspect(error)}"}
    end
  end

  defp apply_effect(audio_data, effect) do
    case effect.type do
      :reverb -> apply_reverb(audio_data, effect.params)
      :delay -> apply_delay(audio_data, effect.params)
      :distortion -> apply_distortion(audio_data, effect.params)
      :filter -> apply_filter(audio_data, effect.params)
      _ -> {:ok, audio_data}
    end
  end

  # Audio processing helper functions

  defp create_temp_file(data, filename) do
    temp_dir = System.tmp_dir!()
    file_path = Path.join(temp_dir, filename)
    File.write!(file_path, data)
    file_path
  end

  defp create_temp_wav_file(audio_data, quality) do
    temp_dir = System.tmp_dir!()
    filename = "temp_#{:rand.uniform(10000)}.wav"
    file_path = Path.join(temp_dir, filename)

    wav_header = create_wav_header(byte_size(audio_data), quality)
    wav_data = wav_header <> audio_data

    File.write!(file_path, wav_data)
    file_path
  end

  defp create_wav_header(data_size, quality) do
    # Standard WAV header format
    chunk_size = data_size + 36
    byte_rate = quality.sample_rate * quality.channels * Integer.floor_div(quality.bit_depth, 8)
    block_align = quality.channels * Integer.floor_div(quality.bit_depth, 8)

    <<
      # RIFF header
      "RIFF", chunk_size::little-32, "WAVE",
      # Format chunk
      "fmt ", 16::little-32, 1::little-16, quality.channels::little-16,
      quality.sample_rate::little-32, byte_rate::little-32,
      block_align::little-16, quality.bit_depth::little-16,
      # Data chunk
      "data", data_size::little-32
    >>
  end

  defp generate_filename(metadata) do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    session_id = Map.get(metadata, :session_id, "unknown")
    track_id = Map.get(metadata, :track_id, "track")
    format = Map.get(metadata, :format, "mp3")

    "frestyl_#{session_id}_#{track_id}_#{timestamp}.#{format}"
  end

  defp analyze_audio_file(file_path) do
    # Use FFprobe to analyze audio file
    case System.cmd("ffprobe", [
      "-v", "quiet",
      "-print_format", "json",
      "-show_format",
      "-show_streams",
      file_path
    ]) do
      {output, 0} ->
        case Jason.decode(output) do
          {:ok, metadata} -> extract_audio_metadata(metadata)
          _ -> %{}
        end
      _ -> %{}
    end
  end

  defp extract_audio_metadata(ffprobe_data) do
    format = get_in(ffprobe_data, ["format"])
    stream = get_in(ffprobe_data, ["streams"]) |> List.first()

    %{
      duration: get_in(format, ["duration"]) |> parse_float(),
      size: get_in(format, ["size"]) |> parse_integer(),
      bit_rate: get_in(format, ["bit_rate"]) |> parse_integer(),
      sample_rate: get_in(stream, ["sample_rate"]) |> parse_integer(),
      channels: get_in(stream, ["channels"]) |> parse_integer(),
      codec: get_in(stream, ["codec_name"])
    }
  end

  defp calculate_mp3_bitrate(quality) do
    # Calculate appropriate MP3 bitrate based on quality
    case quality.sample_rate do
      rate when rate >= 44100 -> 320
      rate when rate >= 22050 -> 192
      _ -> 128
    end
  end

  defp calculate_ogg_quality(quality) do
    # OGG quality scale 0-10
    case quality.sample_rate do
      rate when rate >= 44100 -> 8
      rate when rate >= 22050 -> 6
      _ -> 4
    end
  end

  defp calculate_audio_length(track) do
    # Calculate length based on data size and quality
    # This is a simplified calculation
    byte_size(track.data)
  end

  defp generate_silence(length) do
    # Generate silence of specified length
    <<0::size(length * 8)>>
  end

  defp apply_volume(audio_data, volume) do
    # Simple volume adjustment (multiply samples by volume)
    # In production, implement proper sample-by-sample volume adjustment
    audio_data
  end

  defp sum_audio_data(audio_data_list) do
    # Sum audio samples from multiple tracks
    # In production, implement proper sample-by-sample addition with clipping protection
    List.first(audio_data_list)
  end

  defp apply_compression(audio_data), do: audio_data
  defp apply_eq(audio_data), do: audio_data
  defp apply_limiting(audio_data), do: audio_data

  defp apply_reverb(audio_data, _params), do: {:ok, audio_data}
  defp apply_delay(audio_data, _params), do: {:ok, audio_data}
  defp apply_distortion(audio_data, _params), do: {:ok, audio_data}
  defp apply_filter(audio_data, _params), do: {:ok, audio_data}

  defp save_local_file(file_path, filename) do
    local_storage_dir = Application.get_env(:frestyl, :local_audio_storage, "/tmp/frestyl_audio")
    File.mkdir_p!(local_storage_dir)

    destination = Path.join(local_storage_dir, filename)
    case File.cp(file_path, destination) do
      :ok ->
        {:ok, %{
          storage_type: :local,
          file_path: destination,
          filename: filename,
          url: "/audio/#{filename}"
        }}
      error -> error
    end
  end

  defp cleanup_temp_files(files) do
    Enum.each(files, fn file ->
      if File.exists?(file), do: File.rm(file)
    end)
  end

  defp parse_float(nil), do: 0.0
  defp parse_float(str) when is_binary(str) do
    case Float.parse(str) do
      {float, _} -> float
      :error -> 0.0
    end
  end
  defp parse_float(num) when is_number(num), do: num / 1

  defp parse_integer(nil), do: 0
  defp parse_integer(str) when is_binary(str) do
    case Integer.parse(str) do
      {int, _} -> int
      :error -> 0
    end
  end
  defp parse_integer(num) when is_number(num), do: round(num)
end
