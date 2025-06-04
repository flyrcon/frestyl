# lib/frestyl/collaboration/operational_transform/beat_op.ex
defmodule Frestyl.Collaboration.OperationalTransform.BeatOp do
  @moduledoc """
  Operational Transform operations for the Beat Machine.
  Handles real-time collaborative beat programming.
  """

  defstruct [
    :id,
    :type,
    :action,
    :data,
    :user_id,
    :timestamp,
    :pattern_id,
    :version
  ]

  @type t :: %__MODULE__{
    id: String.t(),
    type: :beat_machine,
    action: atom(),
    data: map(),
    user_id: String.t(),
    timestamp: integer(),
    pattern_id: String.t() | nil,
    version: integer()
  }

  @doc """
  Creates a new beat machine operation.
  """
  def new(action, data, user_id, opts \\ []) do
    %__MODULE__{
      id: generate_operation_id(),
      type: :beat_machine,
      action: action,
      data: data,
      user_id: user_id,
      timestamp: System.monotonic_time(:millisecond),
      pattern_id: opts[:pattern_id],
      version: opts[:version] || 0
    }
  end

  @doc """
  Transforms two beat operations for operational transform.
  """
  def transform(op1, op2, priority \\ :left) do
    case {op1.action, op2.action} do
      # Same step update on same pattern
      {:update_step, :update_step} when op1.pattern_id == op2.pattern_id ->
        transform_step_updates(op1, op2, priority)

      # Pattern operations
      {:create_pattern, :create_pattern} ->
        transform_pattern_creations(op1, op2, priority)

      {:delete_pattern, :update_step} ->
        transform_delete_vs_step_update(op1, op2, priority)

      {:update_step, :delete_pattern} ->
        {op2_transformed, op1_transformed} = transform_delete_vs_step_update(op2, op1, flip_priority(priority))
        {op1_transformed, op2_transformed}

      # Kit changes
      {:change_kit, :change_kit} ->
        transform_kit_changes(op1, op2, priority)

      # BPM changes
      {:set_bpm, :set_bpm} ->
        transform_bpm_changes(op1, op2, priority)

      # Non-conflicting operations
      _ ->
        {op1, op2}
    end
  end

  @doc """
  Applies a beat operation to workspace state.
  """
  def apply_to_state(workspace_state, operation) do
    beat_state = Map.get(workspace_state, :beat_machine, %{
      current_kit: "classic_808",
      patterns: %{},
      active_pattern: nil,
      playing: false,
      bpm: 120,
      swing: 0,
      master_volume: 0.8,
      pattern_counter: 0
    })

    updated_beat_state = case operation.action do
      :create_pattern ->
        pattern = operation.data
        patterns = Map.put(beat_state.patterns || %{}, pattern.id, pattern)
        Map.put(beat_state, :patterns, patterns)

      :update_step ->
        update_pattern_step(beat_state, operation.data)

      :delete_pattern ->
        patterns = Map.delete(beat_state.patterns || %{}, operation.data.pattern_id)
        beat_state
        |> Map.put(:patterns, patterns)
        |> maybe_clear_active_pattern(operation.data.pattern_id)

      :change_kit ->
        Map.put(beat_state, :current_kit, operation.data.kit_name)

      :set_bpm ->
        Map.put(beat_state, :bpm, operation.data.bpm)

      :set_swing ->
        Map.put(beat_state, :swing, operation.data.swing)

      :set_master_volume ->
        Map.put(beat_state, :master_volume, operation.data.volume)

      :duplicate_pattern ->
        pattern = operation.data.new_pattern
        patterns = Map.put(beat_state.patterns || %{}, pattern.id, pattern)
        Map.put(beat_state, :patterns, patterns)

      :randomize_pattern ->
        randomize_pattern_sequences(beat_state, operation.data)

      :clear_pattern ->
        clear_pattern_sequences(beat_state, operation.data.pattern_id)

      _ ->
        beat_state
    end

    # Update version
    updated_beat_state = Map.put(updated_beat_state, :version, (beat_state[:version] || 0) + 1)

    Map.put(workspace_state, :beat_machine, updated_beat_state)
  end

  @doc """
  Validates a beat operation.
  """
  def valid?(operation) do
    case operation.action do
      :create_pattern ->
        has_required_keys?(operation.data, [:id, :name, :steps, :sequences])

      :update_step ->
        has_required_keys?(operation.data, [:pattern_id, :instrument, :step, :velocity]) and
        is_integer(operation.data.velocity) and
        operation.data.velocity >= 0 and operation.data.velocity <= 127

      :delete_pattern ->
        has_required_keys?(operation.data, [:pattern_id])

      :change_kit ->
        has_required_keys?(operation.data, [:kit_name]) and
        is_binary(operation.data.kit_name)

      :set_bpm ->
        has_required_keys?(operation.data, [:bpm]) and
        is_integer(operation.data.bpm) and
        operation.data.bpm >= 60 and operation.data.bpm <= 200

      :set_swing ->
        has_required_keys?(operation.data, [:swing]) and
        is_number(operation.data.swing) and
        operation.data.swing >= 0 and operation.data.swing <= 100

      :set_master_volume ->
        has_required_keys?(operation.data, [:volume]) and
        is_number(operation.data.volume) and
        operation.data.volume >= 0 and operation.data.volume <= 1

      _ ->
        false
    end
  end

  @doc """
  Gets the operation priority for conflict resolution.
  """
  def priority(operation) do
    case operation.action do
      :create_pattern -> 3
      :delete_pattern -> 4
      :update_step -> 2
      :change_kit -> 3
      :set_bpm -> 1
      :set_swing -> 1
      :set_master_volume -> 1
      _ -> 2
    end
  end

  # Private helper functions

  defp generate_operation_id do
    "beat_op_" <> (:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower))
  end

  defp transform_step_updates(op1, op2, priority) do
    data1 = op1.data
    data2 = op2.data

    cond do
      # Same step, same instrument - use priority
      data1.pattern_id == data2.pattern_id and
      data1.instrument == data2.instrument and
      data1.step == data2.step ->
        if priority == :left do
          {op1, make_noop(op2)}
        else
          {make_noop(op1), op2}
        end

      # Different steps or instruments - no conflict
      true ->
        {op1, op2}
    end
  end

  defp transform_pattern_creations(op1, op2, priority) do
    # If both users create patterns simultaneously, both succeed
    # but we ensure unique IDs based on priority
    if op1.data.id == op2.data.id do
      if priority == :left do
        updated_op2_data = %{op2.data | id: op2.data.id <> "_" <> op2.user_id}
        updated_op2 = %{op2 | data: updated_op2_data}
        {op1, updated_op2}
      else
        updated_op1_data = %{op1.data | id: op1.data.id <> "_" <> op1.user_id}
        updated_op1 = %{op1 | data: updated_op1_data}
        {updated_op1, op2}
      end
    else
      {op1, op2}
    end
  end

  defp transform_delete_vs_step_update(delete_op, update_op, priority) do
    if delete_op.data.pattern_id == update_op.data.pattern_id do
      # Pattern is being deleted, step update becomes no-op
      {delete_op, make_noop(update_op)}
    else
      {delete_op, update_op}
    end
  end

  defp transform_kit_changes(op1, op2, priority) do
    # Last kit change wins based on priority
    if priority == :left do
      {op1, make_noop(op2)}
    else
      {make_noop(op1), op2}
    end
  end

  defp transform_bpm_changes(op1, op2, priority) do
    # Last BPM change wins based on priority
    if priority == :left do
      {op1, make_noop(op2)}
    else
      {make_noop(op1), op2}
    end
  end

  defp make_noop(operation) do
    %{operation | action: :noop, data: %{}}
  end

  defp flip_priority(:left), do: :right
  defp flip_priority(:right), do: :left

  defp update_pattern_step(beat_state, data) do
    patterns = beat_state.patterns || %{}

    case Map.get(patterns, data.pattern_id) do
      nil ->
        beat_state

      pattern ->
        updated_sequences = put_in(pattern.sequences, [data.instrument, data.step], data.velocity)
        updated_pattern = %{pattern | sequences: updated_sequences}
        updated_patterns = Map.put(patterns, data.pattern_id, updated_pattern)
        Map.put(beat_state, :patterns, updated_patterns)
    end
  end

  defp maybe_clear_active_pattern(beat_state, deleted_pattern_id) do
    if beat_state.active_pattern == deleted_pattern_id do
      beat_state
      |> Map.put(:active_pattern, nil)
      |> Map.put(:playing, false)
    else
      beat_state
    end
  end

  defp randomize_pattern_sequences(beat_state, data) do
    patterns = beat_state.patterns || %{}

    case Map.get(patterns, data.pattern_id) do
      nil ->
        beat_state

      pattern ->
        updated_pattern = %{pattern | sequences: data.sequences}
        updated_patterns = Map.put(patterns, data.pattern_id, updated_pattern)
        Map.put(beat_state, :patterns, updated_patterns)
    end
  end

  defp clear_pattern_sequences(beat_state, pattern_id) do
    patterns = beat_state.patterns || %{}

    case Map.get(patterns, pattern_id) do
      nil ->
        beat_state

      pattern ->
        # Clear all sequences to zeros
        cleared_sequences = Enum.reduce(pattern.sequences, %{}, fn {instrument, sequence}, acc ->
          Map.put(acc, instrument, List.duplicate(0, length(sequence)))
        end)

        updated_pattern = %{pattern | sequences: cleared_sequences}
        updated_patterns = Map.put(patterns, pattern_id, updated_pattern)
        Map.put(beat_state, :patterns, updated_patterns)
    end
  end

  defp has_required_keys?(data, keys) when is_map(data) do
    Enum.all?(keys, &Map.has_key?(data, &1))
  end
  defp has_required_keys?(_, _), do: false
end
