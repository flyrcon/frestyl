# lib/frestyl/collaboration/operational_transform.ex
defmodule Frestyl.Collaboration.OperationalTransform do
  @moduledoc """
  Operational Transform (OT) implementation for collaborative editing.

  This module handles real-time collaborative editing by transforming operations
  to maintain consistency when multiple users edit simultaneously.

  Based on the ShareJS operational transform algorithm adapted for Elixir.
  """

  alias __MODULE__.{Operation, TextOp, AudioOp, VisualOp}

  @doc """
  Transforms two operations against each other.

  Given operations A and B that were created concurrently against the same state,
  transform A against B to get A' such that applying B then A' has the same effect
  as applying A then B.
  """
  def transform(op_a, op_b, priority \\ :left) do
    case {op_a.type, op_b.type} do
      {:text, :text} -> TextOp.transform(op_a, op_b, priority)
      {:audio, :audio} -> AudioOp.transform(op_a, op_b, priority)
      {:visual, :visual} -> VisualOp.transform(op_a, op_b, priority)
      # Different types don't conflict
      _ -> {op_a, op_b}
    end
  end

  @doc """
  Composes two operations into a single operation.
  """
  def compose(op_a, op_b) when op_a.type == op_b.type do
    case op_a.type do
      :text -> TextOp.compose(op_a, op_b)
      :audio -> AudioOp.compose(op_a, op_b)
      :visual -> VisualOp.compose(op_a, op_b)
    end
  end

  def compose(op_a, _op_b), do: op_a  # Can't compose different types

  @doc """
  Applies an operation to a workspace state.
  """
  def apply_operation(workspace_state, operation) do
    case operation.type do
      :text -> TextOp.apply(workspace_state, operation)
      :audio -> AudioOp.apply(workspace_state, operation)
      :visual -> VisualOp.apply(workspace_state, operation)
      :midi -> apply_midi_operation(workspace_state, operation)
    end
  end

  # MIDI operations (simpler, no complex OT needed)
  defp apply_midi_operation(workspace_state, %{action: :add_note, note: note}) do
    midi_state = workspace_state.midi
    new_notes = midi_state.notes ++ [note]
    new_midi_state = Map.put(midi_state, :notes, new_notes)
    Map.put(workspace_state, :midi, new_midi_state)
  end

  defp apply_midi_operation(workspace_state, %{action: :delete_note, note_id: note_id}) do
    midi_state = workspace_state.midi
    new_notes = Enum.reject(midi_state.notes, &(&1.id == note_id))
    new_midi_state = Map.put(midi_state, :notes, new_notes)
    Map.put(workspace_state, :midi, new_midi_state)
  end

  defp apply_midi_operation(workspace_state, _), do: workspace_state
end

# Text Operations
defmodule Frestyl.Collaboration.OperationalTransform.TextOp do
  @moduledoc """
  Text-specific operational transforms.
  Handles insert, delete, and retain operations on text.
  """

  defstruct [:type, :ops, :version, :user_id, :timestamp]

  def new(ops, user_id, version \\ 0) do
    %__MODULE__{
      type: :text,
      ops: normalize_ops(ops),
      version: version,
      user_id: user_id,
      timestamp: DateTime.utc_now()
    }
  end

  @doc """
  Transform text operation A against operation B.
  """
  def transform(%__MODULE__{ops: ops_a} = op_a, %__MODULE__{ops: ops_b}, priority) do
    {new_ops_a, new_ops_b} = transform_ops(ops_a, ops_b, priority)

    {%{op_a | ops: new_ops_a}, %{op_a | ops: new_ops_b}}
  end

  def compose(%__MODULE__{ops: ops_a} = op_a, %__MODULE__{ops: ops_b}) do
    %{op_a | ops: compose_ops(ops_a, ops_b)}
  end

  def apply(workspace_state, %__MODULE__{ops: ops}) do
    text_state = workspace_state.text
    new_content = apply_ops_to_string(text_state.content, ops)
    new_version = text_state.version + 1

    new_text_state = %{text_state | content: new_content, version: new_version}
    Map.put(workspace_state, :text, new_text_state)
  end

  # Transform two operation lists
  defp transform_ops(ops_a, ops_b, priority, offset_a \\ 0, offset_b \\ 0, result_a \\ [], result_b \\ [])

  defp transform_ops([], ops_b, _priority, _offset_a, offset_b, result_a, result_b) do
    # A is exhausted, add remaining B ops with offset
    remaining_b = Enum.map(ops_b, fn
      {:retain, n} -> {:retain, n}
      {:insert, text} -> {:insert, text}
      {:delete, n} -> {:delete, n}
    end)
    {Enum.reverse(result_a), Enum.reverse(result_b) ++ remaining_b}
  end

  defp transform_ops(ops_a, [], _priority, offset_a, _offset_b, result_a, result_b) do
    # B is exhausted, add remaining A ops
    remaining_a = Enum.map(ops_a, fn
      {:retain, n} -> {:retain, n}
      {:insert, text} -> {:insert, text}
      {:delete, n} -> {:delete, n}
    end)
    {Enum.reverse(result_a) ++ remaining_a, Enum.reverse(result_b)}
  end

  defp transform_ops([op_a | rest_a] = ops_a, [op_b | rest_b] = ops_b, priority, offset_a, offset_b, result_a, result_b) do
    case {op_a, op_b} do
      # Both retain
      {{:retain, n_a}, {:retain, n_b}} when n_a == n_b ->
        transform_ops(rest_a, rest_b, priority, offset_a + n_a, offset_b + n_b,
                     [{:retain, n_a} | result_a], [{:retain, n_b} | result_b])

      {{:retain, n_a}, {:retain, n_b}} when n_a < n_b ->
        transform_ops(rest_a, [{:retain, n_b - n_a} | rest_b], priority, offset_a + n_a, offset_b + n_a,
                     [{:retain, n_a} | result_a], [{:retain, n_a} | result_b])

      {{:retain, n_a}, {:retain, n_b}} when n_a > n_b ->
        transform_ops([{:retain, n_a - n_b} | rest_a], rest_b, priority, offset_a + n_b, offset_b + n_b,
                     [{:retain, n_b} | result_a], [{:retain, n_b} | result_b])

      # Insert vs Insert
      {{:insert, text_a}, {:insert, text_b}} ->
        case priority do
          :left ->
            # A goes first
            len_a = String.length(text_a)
            transform_ops(rest_a, ops_b, priority, offset_a, offset_b,
                         [{:insert, text_a} | result_a], [{:retain, len_a} | result_b])
          :right ->
            # B goes first
            len_b = String.length(text_b)
            transform_ops(ops_a, rest_b, priority, offset_a, offset_b,
                         [{:retain, len_b} | result_a], [{:insert, text_b} | result_b])
        end

      # Insert vs Retain
      {{:insert, text_a}, {:retain, n_b}} ->
        len_a = String.length(text_a)
        transform_ops(rest_a, [{:retain, n_b} | rest_b], priority, offset_a, offset_b,
                     [{:insert, text_a} | result_a], [{:retain, len_a} | result_b])

      {{:retain, n_a}, {:insert, text_b}} ->
        len_b = String.length(text_b)
        transform_ops([{:retain, n_a} | rest_a], rest_b, priority, offset_a, offset_b,
                     [{:retain, len_b} | result_a], [{:insert, text_b} | result_b])

      # Delete vs Delete
      {{:delete, n_a}, {:delete, n_b}} when n_a == n_b ->
        # Both delete same range - no-op
        transform_ops(rest_a, rest_b, priority, offset_a, offset_b, result_a, result_b)

      {{:delete, n_a}, {:delete, n_b}} when n_a < n_b ->
        transform_ops(rest_a, [{:delete, n_b - n_a} | rest_b], priority, offset_a, offset_b, result_a, result_b)

      {{:delete, n_a}, {:delete, n_b}} when n_a > n_b ->
        transform_ops([{:delete, n_a - n_b} | rest_a], rest_b, priority, offset_a, offset_b, result_a, result_b)

      # Delete vs Retain
      {{:delete, n_a}, {:retain, n_b}} when n_a <= n_b ->
        transform_ops(rest_a, [{:retain, n_b - n_a} | rest_b], priority, offset_a, offset_b,
                     [{:delete, n_a} | result_a], result_b)

      {{:retain, n_a}, {:delete, n_b}} when n_b <= n_a ->
        transform_ops([{:retain, n_a - n_b} | rest_a], rest_b, priority, offset_a, offset_b,
                     result_a, [{:delete, n_b} | result_b])

      # Insert vs Delete
      {{:insert, text_a}, {:delete, n_b}} ->
        len_a = String.length(text_a)
        transform_ops(rest_a, [{:delete, n_b} | rest_b], priority, offset_a, offset_b,
                     [{:insert, text_a} | result_a], [{:retain, len_a} | result_b])

      {{:delete, n_a}, {:insert, text_b}} ->
        len_b = String.length(text_b)
        transform_ops([{:delete, n_a} | rest_a], rest_b, priority, offset_a, offset_b,
                     [{:retain, len_b} | result_a], [{:insert, text_b} | result_b])

      _ ->
        # Fallback - shouldn't happen with well-formed ops
        transform_ops(rest_a, rest_b, priority, offset_a, offset_b, result_a, result_b)
    end
  end

  # Compose operation lists
  defp compose_ops(ops_a, ops_b) do
    # Implementation of operation composition
    # This is complex - for now, return ops_b (later operation wins)
    ops_b
  end

  # Apply operations to string
  defp apply_ops_to_string(text, ops) do
    {result, _pos} = Enum.reduce(ops, {text, 0}, fn op, {acc_text, pos} ->
      case op do
        {:retain, n} ->
          {acc_text, pos + n}

        {:insert, new_text} ->
          {String.slice(acc_text, 0, pos) <> new_text <> String.slice(acc_text, pos..-1), pos + String.length(new_text)}

        {:delete, n} ->
          {String.slice(acc_text, 0, pos) <> String.slice(acc_text, (pos + n)..-1), pos}
      end
    end)

    result
  end

  # Normalize operations (merge consecutive operations of same type)
  defp normalize_ops(ops) do
    ops
    |> Enum.reduce([], fn op, acc ->
      case {op, List.first(acc)} do
        {{:retain, n1}, {:retain, n2}} ->
          [{:retain, n1 + n2} | Enum.drop(acc, 1)]
        {{:delete, n1}, {:delete, n2}} ->
          [{:delete, n1 + n2} | Enum.drop(acc, 1)]
        {{:insert, text1}, {:insert, text2}} ->
          [{:insert, text2 <> text1} | Enum.drop(acc, 1)]
        _ ->
          [op | acc]
      end
    end)
    |> Enum.reverse()
  end
end

# Audio Operations
defmodule Frestyl.Collaboration.OperationalTransform.AudioOp do
  @moduledoc """
  Audio-specific operational transforms.
  Handles track operations, clip operations, and audio state changes.
  """

  defstruct [:type, :action, :data, :track_id, :clip_id, :user_id, :timestamp, :track_counter]

  def new(action, data, user_id, opts \\ []) do
    %__MODULE__{
      type: :audio,
      action: action,
      data: data,
      track_id: opts[:track_id],
      clip_id: opts[:clip_id],
      user_id: user_id,
      timestamp: DateTime.utc_now(),
      track_counter: opts[:track_counter]
    }
  end

  def transform(op_a, op_b, priority) do
    case {op_a.action, op_b.action} do
      {:add_track, :add_track} ->
        transform_add_track_vs_add_track(op_a, op_b, priority)

      {:add_clip, :add_track} ->
        # Adding clip is not affected by adding track
        {op_a, op_b}

      {:add_track, :add_clip} ->
        # Adding track is not affected by adding clip
        {op_a, op_b}

      {:delete_track, :add_clip} ->
        transform_delete_track_vs_add_clip(op_a, op_b)

      {:add_clip, :delete_track} ->
        {op_b_prime, op_a_prime} = transform_delete_track_vs_add_clip(op_b, op_a)
        {op_a_prime, op_b_prime}

      # NEW: Handle track deletion conflicts
      {:delete_track, :delete_track} ->
        transform_delete_track_vs_delete_track(op_a, op_b)

      {:delete_track, :update_track_property} ->
        transform_delete_track_vs_update_property(op_a, op_b)

      {:update_track_property, :delete_track} ->
        {op_b_prime, op_a_prime} = transform_delete_track_vs_update_property(op_b, op_a)
        {op_a_prime, op_b_prime}

      # Property updates don't conflict with each other (last write wins)
      {:update_track_property, :update_track_property} ->
        if op_a.track_id == op_b.track_id do
          # Same track - apply both updates (merge properties)
          case priority do
            :left -> {op_a, op_b}  # A's properties take precedence
            :right -> {op_a, op_b} # B's properties take precedence
          end
        else
          # Different tracks - no conflict
          {op_a, op_b}
        end

      _ ->
        # Most audio operations don't conflict
        {op_a, op_b}
    end
  end

  def compose(op_a, op_b) do
    # For audio operations, later operation typically wins
    op_b
  end

  def apply(workspace_state, operation) do
    audio_state = workspace_state.audio

    new_audio_state = case operation.action do
      :add_track ->
        add_track_to_state(audio_state, operation)

      :delete_track ->
        delete_track_from_state(audio_state, operation)

      :add_clip ->
        add_clip_to_state(audio_state, operation)

      :delete_clip ->
        delete_clip_from_state(audio_state, operation)

      :update_track_property ->
        update_track_property_in_state(audio_state, operation)

      :noop ->
        # No-op operations (result of conflict resolution)
        audio_state

      _ ->
        audio_state
    end

    Map.put(workspace_state, :audio, new_audio_state)
  end

  # Transform two concurrent track additions
  defp transform_add_track_vs_add_track(op_a, op_b, priority) do
    # Both operations are adding tracks
    counter_a = op_a.track_counter || 0
    counter_b = op_b.track_counter || 0

    if counter_a == counter_b do
      # Same counter - need to resolve conflict
      case priority do
        :left ->
          # A wins, B gets incremented
          new_track_b = Map.put(op_b.data, :number, counter_b + 1)
          new_track_b = Map.put(new_track_b, :name, "Track #{counter_b + 1}")

          op_b_prime = %{op_b |
            data: new_track_b,
            track_counter: counter_b + 1
          }

          {op_a, op_b_prime}

        :right ->
          # B wins, A gets incremented
          new_track_a = Map.put(op_a.data, :number, counter_a + 1)
          new_track_a = Map.put(new_track_a, :name, "Track #{counter_a + 1}")

          op_a_prime = %{op_a |
            data: new_track_a,
            track_counter: counter_a + 1
          }

          {op_a_prime, op_b}
      end
    else
      # Different counters - no conflict
      {op_a, op_b}
    end
  end

  # Transform delete track vs add clip
  defp transform_delete_track_vs_add_clip(delete_op, add_clip_op) do
    if delete_op.track_id == add_clip_op.track_id do
      # Trying to add clip to deleted track - make add_clip a no-op
      noop_op = %{add_clip_op | action: :noop}
      {delete_op, noop_op}
    else
      # Different tracks - no conflict
      {delete_op, add_clip_op}
    end
  end

  # NEW: Transform delete track vs delete track
  defp transform_delete_track_vs_delete_track(op_a, op_b) do
    if op_a.track_id == op_b.track_id do
      # Both trying to delete same track - first one wins, second becomes no-op
      noop_op = %{op_b | action: :noop}
      {op_a, noop_op}
    else
      # Different tracks - no conflict
      {op_a, op_b}
    end
  end

  # NEW: Transform delete track vs update track property
  defp transform_delete_track_vs_update_property(delete_op, update_op) do
    if delete_op.track_id == update_op.track_id do
      # Trying to update deleted track - make update a no-op
      noop_op = %{update_op | action: :noop}
      {delete_op, noop_op}
    else
      # Different tracks - no conflict
      {delete_op, update_op}
    end
  end

  # Apply operations to audio state
  defp add_track_to_state(audio_state, operation) do
    new_track = operation.data
    new_tracks = audio_state.tracks ++ [new_track]
    new_counter = max(audio_state.track_counter || 0, operation.track_counter || 0)

    %{audio_state |
      tracks: new_tracks,
      track_counter: new_counter
    }
  end

  defp delete_track_from_state(audio_state, operation) do
    track_id = operation.track_id
    new_tracks = Enum.reject(audio_state.tracks, &(&1.id == track_id))

    %{audio_state | tracks: new_tracks}
  end

  defp add_clip_to_state(audio_state, operation) do
    track_id = operation.track_id
    new_clip = operation.data

    new_tracks = Enum.map(audio_state.tracks, fn track ->
      if track.id == track_id do
        %{track | clips: track.clips ++ [new_clip]}
      else
        track
      end
    end)

    %{audio_state | tracks: new_tracks}
  end

  defp delete_clip_from_state(audio_state, operation) do
    track_id = operation.track_id
    clip_id = operation.clip_id

    new_tracks = Enum.map(audio_state.tracks, fn track ->
      if track.id == track_id do
        new_clips = Enum.reject(track.clips, &(&1.id == clip_id))
        %{track | clips: new_clips}
      else
        track
      end
    end)

    %{audio_state | tracks: new_tracks}
  end

  defp update_track_property_in_state(audio_state, operation) do
    track_id = operation.track_id
    property_updates = operation.data

    new_tracks = Enum.map(audio_state.tracks, fn track ->
      if track.id == track_id do
        Enum.reduce(property_updates, track, fn {key, value}, acc_track ->
          Map.put(acc_track, key, value)
        end)
      else
        track
      end
    end)

    %{audio_state | tracks: new_tracks}
  end
end

# Visual Operations
defmodule Frestyl.Collaboration.OperationalTransform.VisualOp do
  @moduledoc """
  Visual-specific operational transforms.
  Handles drawing operations, element creation/deletion/modification.
  """

  defstruct [:type, :action, :data, :element_id, :user_id, :timestamp]

  def new(action, data, user_id, opts \\ []) do
    %__MODULE__{
      type: :visual,
      action: action,
      data: data,
      element_id: opts[:element_id],
      user_id: user_id,
      timestamp: DateTime.utc_now()
    }
  end

  def transform(op_a, op_b, _priority) do
    case {op_a.action, op_b.action} do
      {:add_element, :add_element} ->
        # Both adding elements - no conflict (they get different IDs)
        {op_a, op_b}

      {:delete_element, :update_element} ->
        if op_a.element_id == op_b.element_id do
          # Updating deleted element - make update a no-op
          noop_op = %{op_b | action: :noop}
          {op_a, noop_op}
        else
          {op_a, op_b}
        end

      {:update_element, :delete_element} ->
        if op_a.element_id == op_b.element_id do
          # Deleting updated element - delete wins
          noop_op = %{op_a | action: :noop}
          {noop_op, op_b}
        else
          {op_a, op_b}
        end

      _ ->
        {op_a, op_b}
    end
  end

  def compose(op_a, op_b) do
    op_b  # Later operation wins
  end

  def apply(workspace_state, operation) do
    visual_state = workspace_state.visual

    new_visual_state = case operation.action do
      :add_element ->
        new_element = operation.data
        %{visual_state | elements: visual_state.elements ++ [new_element]}

      :delete_element ->
        element_id = operation.element_id
        new_elements = Enum.reject(visual_state.elements, &(&1.id == element_id))
        %{visual_state | elements: new_elements}

      :update_element ->
        element_id = operation.element_id
        updates = operation.data

        new_elements = Enum.map(visual_state.elements, fn element ->
          if element.id == element_id do
            Enum.reduce(updates, element, fn {key, value}, acc ->
              Map.put(acc, key, value)
            end)
          else
            element
          end
        end)

        %{visual_state | elements: new_elements}

      :noop ->
        visual_state

      _ ->
        visual_state
    end

    Map.put(workspace_state, :visual, new_visual_state)
  end
end

# Operation wrapper
defmodule Frestyl.Collaboration.OperationalTransform.Operation do
  @moduledoc """
  Generic operation wrapper for all operation types.
  """

  defstruct [:id, :type, :user_id, :session_id, :timestamp, :operation]

  def new(type, operation, user_id, session_id) do
    %__MODULE__{
      id: Ecto.UUID.generate(),
      type: type,
      user_id: user_id,
      session_id: session_id,
      timestamp: DateTime.utc_now(),
      operation: operation
    }
  end
end
