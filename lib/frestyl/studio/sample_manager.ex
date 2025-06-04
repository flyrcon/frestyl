# lib/frestyl/studio/sample_manager.ex
defmodule Frestyl.Studio.SampleManager do
  @moduledoc """
  Manages audio samples for the beat machine and other studio tools.
  Creates and maintains the sample library with built-in drum kits.
  """

  require Logger

  # Default sample configuration
  @sample_config %{
    "classic_808" => %{
      "kick" => %{
        name: "808 Kick",
        file: "808_kick.wav",
        category: "drums",
        tags: ["kick", "808", "bass"]
      },
      "snare" => %{
        name: "808 Snare",
        file: "808_snare.wav",
        category: "drums",
        tags: ["snare", "808"]
      },
      "hihat" => %{
        name: "808 Hi-Hat",
        file: "808_hihat.wav",
        category: "drums",
        tags: ["hihat", "808", "closed"]
      },
      "openhat" => %{
        name: "808 Open Hat",
        file: "808_openhat.wav",
        category: "drums",
        tags: ["hihat", "808", "open"]
      },
      "clap" => %{
        name: "808 Clap",
        file: "808_clap.wav",
        category: "drums",
        tags: ["clap", "808"]
      },
      "crash" => %{
        name: "808 Crash",
        file: "808_crash.wav",
        category: "drums",
        tags: ["crash", "808", "cymbal"]
      },
      "perc1" => %{
        name: "808 Perc 1",
        file: "808_perc1.wav",
        category: "drums",
        tags: ["percussion", "808"]
      },
      "perc2" => %{
        name: "808 Perc 2",
        file: "808_perc2.wav",
        category: "drums",
        tags: ["percussion", "808"]
      }
    },
    "acoustic" => %{
      "kick" => %{
        name: "Acoustic Kick",
        file: "acoustic_kick.wav",
        category: "drums",
        tags: ["kick", "acoustic", "natural"]
      },
      "snare" => %{
        name: "Acoustic Snare",
        file: "acoustic_snare.wav",
        category: "drums",
        tags: ["snare", "acoustic", "natural"]
      },
      "hihat" => %{
        name: "Acoustic Hi-Hat",
        file: "acoustic_hihat.wav",
        category: "drums",
        tags: ["hihat", "acoustic", "closed"]
      },
      "openhat" => %{
        name: "Acoustic Open Hat",
        file: "acoustic_openhat.wav",
        category: "drums",
        tags: ["hihat", "acoustic", "open"]
      },
      "ride" => %{
        name: "Acoustic Ride",
        file: "acoustic_ride.wav",
        category: "drums",
        tags: ["ride", "acoustic", "cymbal"]
      },
      "crash" => %{
        name: "Acoustic Crash",
        file: "acoustic_crash.wav",
        category: "drums",
        tags: ["crash", "acoustic", "cymbal"]
      },
      "tom1" => %{
        name: "High Tom",
        file: "acoustic_tom1.wav",
        category: "drums",
        tags: ["tom", "acoustic", "high"]
      },
      "tom2" => %{
        name: "Low Tom",
        file: "acoustic_tom2.wav",
        category: "drums",
        tags: ["tom", "acoustic", "low"]
      }
    },
    "trap" => %{
      "kick" => %{
        name: "Trap Kick",
        file: "trap_kick.wav",
        category: "drums",
        tags: ["kick", "trap", "hip-hop"]
      },
      "snare" => %{
        name: "Trap Snare",
        file: "trap_snare.wav",
        category: "drums",
        tags: ["snare", "trap", "hip-hop"]
      },
      "hihat" => %{
        name: "Trap Hi-Hat",
        file: "trap_hihat.wav",
        category: "drums",
        tags: ["hihat", "trap", "closed"]
      },
      "openhat" => %{
        name: "Trap Open Hat",
        file: "trap_openhat.wav",
        category: "drums",
        tags: ["hihat", "trap", "open"]
      },
      "clap" => %{
        name: "Trap Clap",
        file: "trap_clap.wav",
        category: "drums",
        tags: ["clap", "trap"]
      },
      "shaker" => %{
        name: "Trap Shaker",
        file: "trap_shaker.wav",
        category: "drums",
        tags: ["shaker", "trap", "percussion"]
      },
      "perc1" => %{
        name: "Trap Perc 1",
        file: "trap_perc1.wav",
        category: "drums",
        tags: ["percussion", "trap"]
      },
      "perc2" => %{
        name: "Trap Perc 2",
        file: "trap_perc2.wav",
        category: "drums",
        tags: ["percussion", "trap"]
      }
    }
  }

  @doc """
  Initializes the sample library by creating directories and placeholder files.
  """
  def initialize_sample_library do
    Logger.info("Initializing beat machine sample library...")

    base_path = get_samples_base_path()
    File.mkdir_p!(base_path)

    # Create kit directories and sample files
    Enum.each(@sample_config, fn {kit_name, instruments} ->
      kit_path = Path.join(base_path, kit_name)
      File.mkdir_p!(kit_path)

      Enum.each(instruments, fn {instrument, config} ->
        sample_path = Path.join(kit_path, config.file)
        create_sample_file_if_missing(sample_path, config)
      end)

      Logger.info("Created sample kit: #{kit_name}")
    end)

    # Create sample manifest
    create_sample_manifest()

    Logger.info("Sample library initialization complete")
    :ok
  end

  @doc """
  Gets the configuration for all available kits.
  """
  def get_kits_config do
    @sample_config
  end

  @doc """
  Gets the configuration for a specific kit.
  """
  def get_kit_config(kit_name) do
    Map.get(@sample_config, kit_name)
  end

  @doc """
  Gets the full path for a sample file.
  """
  def get_sample_path(kit_name, instrument) do
    case get_in(@sample_config, [kit_name, instrument]) do
      nil -> nil
      config ->
        base_path = get_samples_base_path()
        Path.join([base_path, kit_name, config.file])
    end
  end

  @doc """
  Gets the web URL for a sample file.
  """
  def get_sample_url(kit_name, instrument) do
    case get_in(@sample_config, [kit_name, instrument]) do
      nil -> nil
      config -> "/audio/samples/#{kit_name}/#{config.file}"
    end
  end

  @doc """
  Lists all available kits.
  """
  def list_kits do
    Map.keys(@sample_config)
  end

  @doc """
  Lists instruments for a kit.
  """
  def list_kit_instruments(kit_name) do
    case Map.get(@sample_config, kit_name) do
      nil -> []
      instruments -> Map.keys(instruments)
    end
  end

  @doc """
  Searches samples by tags.
  """
  def search_samples(tags) when is_list(tags) do
    Enum.reduce(@sample_config, [], fn {kit_name, instruments}, acc ->
      kit_matches = Enum.reduce(instruments, [], fn {instrument, config}, kit_acc ->
        if Enum.any?(tags, &(&1 in config.tags)) do
          sample_info = %{
            kit: kit_name,
            instrument: instrument,
            name: config.name,
            url: get_sample_url(kit_name, instrument),
            tags: config.tags,
            category: config.category
          }
          [sample_info | kit_acc]
        else
          kit_acc
        end
      end)
      kit_matches ++ acc
    end)
  end

  @doc """
  Gets sample metadata for the frontend.
  """
  def get_sample_metadata(kit_name, instrument) do
    case get_in(@sample_config, [kit_name, instrument]) do
      nil -> nil
      config ->
        %{
          name: config.name,
          url: get_sample_url(kit_name, instrument),
          category: config.category,
          tags: config.tags,
          kit: kit_name,
          instrument: instrument
        }
    end
  end

  @doc """
  Gets all sample metadata for a kit.
  """
  def get_kit_metadata(kit_name) do
    case Map.get(@sample_config, kit_name) do
      nil -> %{}
      instruments ->
        Enum.reduce(instruments, %{}, fn {instrument, _config}, acc ->
          metadata = get_sample_metadata(kit_name, instrument)
          Map.put(acc, instrument, metadata)
        end)
    end
  end

  @doc """
  Validates that a sample file exists.
  """
  def sample_exists?(kit_name, instrument) do
    case get_sample_path(kit_name, instrument) do
      nil -> false
      path -> File.exists?(path)
    end
  end

  @doc """
  Gets statistics about the sample library.
  """
  def get_library_stats do
    total_kits = length(Map.keys(@sample_config))

    total_samples = Enum.reduce(@sample_config, 0, fn {_kit, instruments}, acc ->
      acc + length(Map.keys(instruments))
    end)

    existing_samples = Enum.reduce(@sample_config, 0, fn {kit_name, instruments}, acc ->
      existing_count = Enum.count(instruments, fn {instrument, _config} ->
        sample_exists?(kit_name, instrument)
      end)
      acc + existing_count
    end)

    %{
      total_kits: total_kits,
      total_samples: total_samples,
      existing_samples: existing_samples,
      missing_samples: total_samples - existing_samples
    }
  end

  # Private helper functions

  defp get_samples_base_path do
    Path.join([:code.priv_dir(:frestyl), "static", "audio", "samples"])
  end

  defp create_sample_file_if_missing(sample_path, config) do
    unless File.exists?(sample_path) do
      # Create a placeholder audio file (silence)
      # In production, you would use actual sample files
      create_placeholder_audio_file(sample_path, config)
    end
  end

  defp create_placeholder_audio_file(path, config) do
    # Create a very basic WAV file header for a 1-second silent sample
    # This is just a placeholder - replace with actual samples
    wav_header = create_wav_header(44100, 1.0) # 44.1kHz, 1 second
    silent_data = List.duplicate(0, 44100 * 2) # 1 second of silence (16-bit stereo)

    wav_data = wav_header <> :binary.list_to_bin(silent_data)

    File.write!(path, wav_data)
    Logger.debug("Created placeholder sample: #{path} (#{config.name})")
  end

  defp create_wav_header(sample_rate, duration) do
    # Very basic WAV header for placeholder files
    num_samples = trunc(sample_rate * duration)
    data_size = num_samples * 2 * 2  # 16-bit stereo
    file_size = data_size + 36

    # WAV file header (simplified)
    <<"RIFF", file_size::little-size(32), "WAVE",
      "fmt ", 16::little-size(32), 1::little-size(16), 2::little-size(16),
      sample_rate::little-size(32), sample_rate * 4::little-size(32), 4::little-size(16), 16::little-size(16),
      "data", data_size::little-size(32)>>
  end

  defp create_sample_manifest do
    manifest_path = Path.join(get_samples_base_path(), "manifest.json")

    manifest_data = %{
      version: "1.0.0",
      created_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      kits: @sample_config,
      stats: get_library_stats()
    }

    json_data = Jason.encode!(manifest_data, pretty: true)
    File.write!(manifest_path, json_data)
  end
end
