# lib/frestyl/studio/recording_engine_registry.ex
defmodule Frestyl.Studio.RecordingEngineRegistry do
  @moduledoc """
  Registry for RecordingEngine processes.
  """

  def start_link(_opts) do
    Registry.start_link(keys: :unique, name: __MODULE__)
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor
    }
  end
end
