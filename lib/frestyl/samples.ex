# lib/mix/tasks/frestyl.samples.ex

defmodule Mix.Tasks.Frestyl.Samples do
  @moduledoc """
  Manages the beat machine sample library.

  ## Examples

      # Initialize the sample library
      mix frestyl.samples init

      # Check sample library status
      mix frestyl.samples status

      # Reset the sample library
      mix frestyl.samples reset
  """

  use Mix.Task
  alias Frestyl.Studio.SampleManager

  @shortdoc "Manages the beat machine sample library"

  def run(["init"]) do
    Mix.shell().info("Initializing beat machine sample library...")

    case SampleManager.initialize_sample_library() do
      :ok ->
        Mix.shell().info("✅ Sample library initialized successfully!")
        print_library_stats()
      {:error, reason} ->
        Mix.shell().error("❌ Failed to initialize sample library: #{reason}")
    end
  end

  def run(["status"]) do
    Mix.shell().info("Beat Machine Sample Library Status")
    Mix.shell().info("=====================================")
    print_library_stats()
  end

  def run(["reset"]) do
    Mix.shell().info("Resetting beat machine sample library...")

    # Remove existing sample directory
    samples_path = Path.join([:code.priv_dir(:frestyl), "static", "audio", "samples"])
    if File.exists?(samples_path) do
      File.rm_rf!(samples_path)
      Mix.shell().info("🗑️  Removed existing sample library")
    end

    # Reinitialize
    case SampleManager.initialize_sample_library() do
      :ok ->
        Mix.shell().info("✅ Sample library reset successfully!")
        print_library_stats()
      {:error, reason} ->
        Mix.shell().error("❌ Failed to reset sample library: #{reason}")
    end
  end

  def run([]) do
    Mix.shell().info(@moduledoc)
  end

  def run(_) do
    Mix.shell().error("Unknown command. Run 'mix frestyl.samples' for help.")
  end

  defp print_library_stats do
    stats = SampleManager.get_library_stats()

    Mix.shell().info("")
    Mix.shell().info("📊 Library Statistics:")
    Mix.shell().info("  - Total Kits: #{stats.total_kits}")
    Mix.shell().info("  - Total Samples: #{stats.total_samples}")
    Mix.shell().info("  - Existing Files: #{stats.existing_samples}")
    Mix.shell().info("  - Missing Files: #{stats.missing_samples}")

    if stats.missing_samples > 0 do
      Mix.shell().info("")
      Mix.shell().info("⚠️  Some sample files are missing (using placeholders)")
      Mix.shell().info("   You can replace them with actual audio files in:")
      Mix.shell().info("   priv/static/audio/samples/")
    else
      Mix.shell().info("✅ All sample files are present")
    end

    Mix.shell().info("")
    Mix.shell().info("🎛️  Available Kits:")
    for kit <- SampleManager.list_kits() do
      instruments = SampleManager.list_kit_instruments(kit)
      Mix.shell().info("  - #{kit}: #{length(instruments)} instruments")
    end
  end
end
