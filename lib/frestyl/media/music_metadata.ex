# lib/frestyl/media/music_metadata.ex
defmodule Frestyl.Media.MusicMetadata do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias Frestyl.Accounts.User
  alias Frestyl.Media.MediaFile

  schema "music_metadata" do
    field :bpm, :float
    field :key_signature, :string # C, Dm, F#, etc.
    field :time_signature, :string # 4/4, 3/4, 7/8, etc.
    field :genre, :string
    field :mood, :string
    field :energy_level, :float # 0.0 to 1.0
    field :instrument_tags, {:array, :string}, default: []
    field :stems, {:array, :map}, default: [] # Array of stem file references
    field :collaborators, {:array, :integer}, default: [] # User IDs
    field :lyrics, :string
    field :chord_progression, :string
    field :production_notes, :string
    field :version_number, :string
    field :is_loop, :boolean, default: false
    field :loop_bars, :integer
    field :metadata, :map, default: %{}

    belongs_to :media_file, MediaFile, foreign_key: :media_file_id
    belongs_to :creation_session, MediaFile, foreign_key: :creation_session_id # Link to session file
    belongs_to :parent_track, MediaFile, foreign_key: :parent_track_id # For remixes/versions

    timestamps()
  end

  @required_fields [:media_file_id]
  @optional_fields [:bpm, :key_signature, :time_signature, :genre, :mood, :energy_level,
                   :instrument_tags, :stems, :collaborators, :creation_session_id, :lyrics,
                   :chord_progression, :production_notes, :version_number, :parent_track_id,
                   :is_loop, :loop_bars, :metadata]

  def changeset(music_metadata, attrs) do
    music_metadata
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_number(:bpm, greater_than: 0.0, less_than: 300.0)
    |> validate_number(:energy_level, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_number(:loop_bars, greater_than: 0)
    |> validate_key_signature()
    |> validate_time_signature()
    |> validate_genre()
    |> validate_mood()
    |> validate_instrument_tags()
    |> validate_stems()
    |> validate_collaborators()
    |> validate_metadata()
    |> unique_constraint(:media_file_id)
    |> foreign_key_constraint(:media_file_id)
    |> foreign_key_constraint(:creation_session_id)
    |> foreign_key_constraint(:parent_track_id)
  end

  # Query helpers
  def for_media_file(query \\ __MODULE__, media_file_id) do
    from(mm in query, where: mm.media_file_id == ^media_file_id)
  end

  def by_bpm_range(query \\ __MODULE__, min_bpm, max_bpm) do
    from(mm in query, where: mm.bpm >= ^min_bpm and mm.bpm <= ^max_bpm)
  end

  def by_key(query \\ __MODULE__, key_signature) do
    from(mm in query, where: mm.key_signature == ^key_signature)
  end

  def by_genre(query \\ __MODULE__, genre) do
    from(mm in query, where: mm.genre == ^genre)
  end

  def by_mood(query \\ __MODULE__, mood) do
    from(mm in query, where: mm.mood == ^mood)
  end

  def by_energy_level(query \\ __MODULE__, min_energy, max_energy \\ 1.0) do
    from(mm in query, where: mm.energy_level >= ^min_energy and mm.energy_level <= ^max_energy)
  end

  def with_collaborator(query \\ __MODULE__, user_id) do
    from(mm in query, where: ^user_id in mm.collaborators)
  end

  def with_instrument(query \\ __MODULE__, instrument) do
    from(mm in query, where: ^instrument in mm.instrument_tags)
  end

  def loops_only(query \\ __MODULE__) do
    from(mm in query, where: mm.is_loop == true)
  end

  def tracks_only(query \\ __MODULE__) do
    from(mm in query, where: mm.is_loop == false)
  end

  def with_stems(query \\ __MODULE__) do
    from(mm in query, where: fragment("array_length(?, 1) > 0", mm.stems))
  end

  def recent(query \\ __MODULE__, days \\ 30) do
    cutoff = DateTime.utc_now() |> DateTime.add(-days * 24 * 60 * 60, :second)
    from(mm in query, where: mm.inserted_at >= ^cutoff)
  end

  def with_media_file(query \\ __MODULE__) do
    from(mm in query,
      join: mf in assoc(mm, :media_file),
      preload: [media_file: mf]
    )
  end

  def with_parent_track(query \\ __MODULE__) do
    from(mm in query,
      left_join: pt in assoc(mm, :parent_track),
      preload: [parent_track: pt]
    )
  end

  # Discovery interface specific queries
  def compatible_tracks(reference_metadata, opts \\ []) do
    tolerance = Keyword.get(opts, :bpm_tolerance, 5.0)
    energy_tolerance = Keyword.get(opts, :energy_tolerance, 0.2)
    limit = Keyword.get(opts, :limit, 20)

    query = from(mm in __MODULE__)

    # BPM compatibility
    query = if reference_metadata.bpm do
      min_bpm = reference_metadata.bpm - tolerance
      max_bpm = reference_metadata.bpm + tolerance
      from(mm in query, where: mm.bpm >= ^min_bpm and mm.bpm <= ^max_bpm)
    else
      query
    end

    # Key compatibility (musical theory based)
    query = if reference_metadata.key_signature do
      compatible_keys = get_compatible_keys(reference_metadata.key_signature)
      from(mm in query, where: mm.key_signature in ^compatible_keys)
    else
      query
    end

    # Energy level compatibility
    query = if reference_metadata.energy_level do
      min_energy = max(0.0, reference_metadata.energy_level - energy_tolerance)
      max_energy = min(1.0, reference_metadata.energy_level + energy_tolerance)
      from(mm in query, where: mm.energy_level >= ^min_energy and mm.energy_level <= ^max_energy)
    else
      query
    end

    # Genre compatibility
    query = if reference_metadata.genre do
      compatible_genres = get_compatible_genres(reference_metadata.genre)
      from(mm in query, where: mm.genre in ^compatible_genres)
    else
      query
    end

    from(mm in query,
      limit: ^limit,
      order_by: [desc: mm.inserted_at]
    )
  end

  def trending_by_genre(opts \\ []) do
    days = Keyword.get(opts, :days, 30)
    cutoff = DateTime.utc_now() |> DateTime.add(-days * 24 * 60 * 60, :second)

    from(mm in __MODULE__,
      join: mf in assoc(mm, :media_file),
      where: mm.inserted_at >= ^cutoff and not is_nil(mm.genre),
      group_by: mm.genre,
      order_by: [desc: count(mm.id)],
      select: {mm.genre, count(mm.id)}
    )
  end

  def bpm_distribution do
    from(mm in __MODULE__,
      where: not is_nil(mm.bpm),
      group_by: fragment("floor(? / 10) * 10", mm.bpm),
      order_by: [asc: fragment("floor(? / 10) * 10", mm.bpm)],
      select: {fragment("floor(? / 10) * 10", mm.bpm), count(mm.id)}
    )
  end

  def popular_keys(opts \\ []) do
    limit = Keyword.get(opts, :limit, 12)

    from(mm in __MODULE__,
      where: not is_nil(mm.key_signature),
      group_by: mm.key_signature,
      order_by: [desc: count(mm.id)],
      limit: ^limit,
      select: {mm.key_signature, count(mm.id)}
    )
  end

  # Collaboration helpers
  def for_collaborator_projects(user_id) do
    from(mm in __MODULE__,
      where: ^user_id in mm.collaborators,
      preload: [:media_file, :creation_session]
    )
  end

  def collaboration_stats(user_id) do
    from(mm in __MODULE__,
      where: ^user_id in mm.collaborators,
      group_by: fragment("array_length(?, 1)", mm.collaborators),
      select: {fragment("array_length(?, 1)", mm.collaborators), count(mm.id)}
    )
  end

  # Stem management
  def tracks_with_stems do
    from(mm in __MODULE__,
      where: fragment("array_length(?, 1) > 0", mm.stems),
      preload: [:media_file]
    )
  end

  def stem_types_distribution do
    from(mm in __MODULE__,
      where: fragment("array_length(?, 1) > 0", mm.stems),
      select: mm.stems
    )
  end

  # Helper functions
  def get_stem_count(music_metadata) do
    length(music_metadata.stems || [])
  end

  def get_collaborator_count(music_metadata) do
    length(music_metadata.collaborators || [])
  end

  def has_stems?(music_metadata) do
    get_stem_count(music_metadata) > 0
  end

  def is_collaboration?(music_metadata) do
    get_collaborator_count(music_metadata) > 1
  end

  def calculate_completion_score(music_metadata) do
    # Calculate how "complete" the metadata is (0.0 to 1.0)
    fields_to_check = [
      :bpm, :key_signature, :time_signature, :genre, :mood, :energy_level
    ]

    filled_fields = Enum.count(fields_to_check, fn field ->
      value = Map.get(music_metadata, field)
      value != nil and value != ""
    end)

    base_score = filled_fields / length(fields_to_check)

    # Bonus for additional metadata
    bonus = 0.0
    bonus = bonus + if length(music_metadata.instrument_tags || []) > 0, do: 0.1, else: 0.0
    bonus = bonus + if music_metadata.lyrics && music_metadata.lyrics != "", do: 0.1, else: 0.0
    bonus = bonus + if music_metadata.chord_progression && music_metadata.chord_progression != "", do: 0.1, else: 0.0
    bonus = bonus + if length(music_metadata.stems || []) > 0, do: 0.2, else: 0.0

    min(1.0, base_score + bonus)
  end

  # Music theory helpers
  defp get_compatible_keys(key) do
    # Simplified musical compatibility - in reality this would be more complex
    key_circles = %{
      "C" => ["C", "G", "F", "Am", "Em", "Dm"],
      "G" => ["G", "D", "C", "Em", "Bm", "Am"],
      "D" => ["D", "A", "G", "Bm", "F#m", "Em"],
      "A" => ["A", "E", "D", "F#m", "C#m", "Bm"],
      "E" => ["E", "B", "A", "C#m", "G#m", "F#m"],
      "B" => ["B", "F#", "E", "G#m", "D#m", "C#m"],
      "F#" => ["F#", "C#", "B", "D#m", "A#m", "G#m"],
      "F" => ["F", "C", "Bb", "Dm", "Am", "Gm"],
      "Bb" => ["Bb", "F", "Eb", "Gm", "Dm", "Cm"],
      "Eb" => ["Eb", "Bb", "Ab", "Cm", "Gm", "Fm"],
      "Ab" => ["Ab", "Eb", "Db", "Fm", "Cm", "Bbm"],
      "Db" => ["Db", "Ab", "Gb", "Bbm", "Fm", "Ebm"],
      "Gb" => ["Gb", "Db", "Cb", "Ebm", "Bbm", "Abm"]
    }

    key_circles[key] || [key]
  end

  defp get_compatible_genres(genre) do
    # Genre compatibility mapping
    genre_families = %{
      "electronic" => ["electronic", "techno", "house", "ambient", "synth"],
      "rock" => ["rock", "alternative", "indie", "grunge", "metal"],
      "hip-hop" => ["hip-hop", "rap", "trap", "lo-fi", "boom-bap"],
      "jazz" => ["jazz", "fusion", "bebop", "smooth-jazz", "blues"],
      "classical" => ["classical", "orchestral", "chamber", "baroque", "romantic"],
      "folk" => ["folk", "acoustic", "country", "americana", "bluegrass"],
      "pop" => ["pop", "dance", "synthpop", "indie-pop", "electropop"]
    }

    # Find the family this genre belongs to
    family = Enum.find_value(genre_families, fn {family_key, genres} ->
      if genre in genres, do: genres, else: nil
    end)

    family || [genre]
  end

  # Private validation helpers
  defp validate_key_signature(changeset) do
    case get_field(changeset, :key_signature) do
      nil -> changeset
      key when key in [
        # Major keys
        "C", "C#", "Db", "D", "D#", "Eb", "E", "F", "F#", "Gb", "G", "G#", "Ab", "A", "A#", "Bb", "B",
        # Minor keys
        "Cm", "C#m", "Dm", "D#m", "Em", "Fm", "F#m", "Gm", "G#m", "Am", "A#m", "Bm"
      ] -> changeset
      _ -> add_error(changeset, :key_signature, "must be a valid musical key")
    end
  end

  defp validate_time_signature(changeset) do
    case get_field(changeset, :time_signature) do
      nil -> changeset
      sig when sig in ["4/4", "3/4", "2/4", "6/8", "9/8", "12/8", "5/4", "7/8", "2/2"] -> changeset
      _ -> add_error(changeset, :time_signature, "must be a valid time signature")
    end
  end

  defp validate_genre(changeset) do
    # Allow free-form genres but validate length
    case get_field(changeset, :genre) do
      nil -> changeset
      genre when is_binary(genre) and byte_size(genre) <= 50 -> changeset
      _ -> add_error(changeset, :genre, "must be a string with maximum 50 characters")
    end
  end

  defp validate_mood(changeset) do
    case get_field(changeset, :mood) do
      nil -> changeset
      mood when mood in [
        "energetic", "calm", "aggressive", "melancholic", "uplifting", "dark", "bright",
        "mysterious", "romantic", "epic", "playful", "serious", "nostalgic", "futuristic"
      ] -> changeset
      _ -> add_error(changeset, :mood, "must be a valid mood")
    end
  end

  defp validate_instrument_tags(changeset) do
    case get_field(changeset, :instrument_tags) do
      nil -> changeset
      [] -> changeset
      tags when is_list(tags) ->
        if Enum.all?(tags, &(is_binary(&1) and byte_size(&1) <= 30)) do
          changeset
        else
          add_error(changeset, :instrument_tags, "all instrument tags must be strings with maximum 30 characters")
        end
      _ -> add_error(changeset, :instrument_tags, "must be a list of strings")
    end
  end

  defp validate_stems(changeset) do
    case get_field(changeset, :stems) do
      nil -> changeset
      [] -> changeset
      stems when is_list(stems) ->
        if Enum.all?(stems, &is_map/1) do
          changeset
        else
          add_error(changeset, :stems, "all stems must be maps")
        end
      _ -> add_error(changeset, :stems, "must be a list of maps")
    end
  end

  defp validate_collaborators(changeset) do
    case get_field(changeset, :collaborators) do
      nil -> changeset
      [] -> changeset
      collaborators when is_list(collaborators) ->
        if Enum.all?(collaborators, &is_integer/1) do
          changeset
        else
          add_error(changeset, :collaborators, "all collaborators must be user IDs (integers)")
        end
      _ -> add_error(changeset, :collaborators, "must be a list of integers")
    end
  end

  defp validate_metadata(changeset) do
    case get_field(changeset, :metadata) do
      nil -> changeset
      metadata when is_map(metadata) -> changeset
      _ -> add_error(changeset, :metadata, "must be a valid map")
    end
  end
end
