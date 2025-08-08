# lib/frestyl/narrative_beats/session.ex
defmodule Frestyl.NarrativeBeats.Session do
  @moduledoc """
  Schema for Narrative Beats sessions - musical composition driven by story structure.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Frestyl.Accounts.User
  alias Frestyl.Studio.Session, as: StudioSession

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "narrative_beats_sessions" do
    field :title, :string
    field :description, :string
    field :story_structure, :map, default: %{}
    field :musical_structure, :map, default: %{}
    field :collaboration_settings, :map, default: %{}
    field :session_state, :string, default: "development"
    field :bpm, :integer, default: 120
    field :key_signature, :string, default: "C"
    field :time_signature, :string, default: "4/4"
    field :total_duration, :float, default: 0.0
    field :completion_percentage, :float, default: 0.0
    field :export_settings, :map, default: %{}

    belongs_to :session, StudioSession, foreign_key: :session_id
    belongs_to :created_by, User, foreign_key: :created_by_id, type: :id

    has_many :story_music_mappings, Frestyl.NarrativeBeats.StoryMusicMapping
    has_many :character_instruments, Frestyl.NarrativeBeats.CharacterInstrument
    has_many :emotional_progressions, Frestyl.NarrativeBeats.EmotionalProgression
    has_many :musical_sections, Frestyl.NarrativeBeats.MusicalSection
    has_many :collaboration_tracks, Frestyl.NarrativeBeats.CollaborationTrack
    has_many :ai_music_suggestions, Frestyl.NarrativeBeats.AIMusicSuggestion
    has_many :narrative_beat_patterns, Frestyl.NarrativeBeats.NarrativeBeatPattern

    timestamps()
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [
      :title, :description, :story_structure, :musical_structure,
      :collaboration_settings, :session_state, :bpm, :key_signature,
      :time_signature, :total_duration, :completion_percentage,
      :export_settings, :session_id, :created_by_id
    ])
    |> validate_required([:title, :session_id, :created_by_id])
    |> validate_length(:title, min: 1, max: 200)
    |> validate_inclusion(:session_state, ["development", "composition", "arrangement", "mixing", "complete"])
    |> validate_number(:bpm, greater_than: 60, less_than: 200)
    |> validate_number(:completion_percentage, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> foreign_key_constraint(:session_id)
    |> foreign_key_constraint(:created_by_id)
  end

  # Query functions
  def for_session(query \\ __MODULE__, session_id) do
    from nb in query, where: nb.session_id == ^session_id
  end

  def for_user(query \\ __MODULE__, user_id) do
    from nb in query, where: nb.created_by_id == ^user_id
  end

  def by_state(query \\ __MODULE__, state) do
    from nb in query, where: nb.session_state == ^state
  end
end

# lib/frestyl/narrative_beats/story_music_mapping.ex
defmodule Frestyl.NarrativeBeats.StoryMusicMapping do
  @moduledoc """
  Maps narrative elements to musical elements in Narrative Beats.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "story_music_mappings" do
    field :story_element, :string
    field :story_element_id, :string
    field :musical_element, :string
    field :mapping_data, :map, default: %{}
    field :intensity_scale, :float, default: 0.5
    field :duration_bars, :integer, default: 4
    field :position_in_timeline, :float

    belongs_to :narrative_beats_session, Frestyl.NarrativeBeats.Session

    timestamps()
  end

  def changeset(mapping, attrs) do
    mapping
    |> cast(attrs, [
      :story_element, :story_element_id, :musical_element,
      :mapping_data, :intensity_scale, :duration_bars,
      :position_in_timeline, :narrative_beats_session_id
    ])
    |> validate_required([:story_element, :musical_element, :narrative_beats_session_id])
    |> validate_inclusion(:story_element, ["character", "emotion", "plot_point", "setting", "theme"])
    |> validate_inclusion(:musical_element, ["instrument", "chord_progression", "tempo", "dynamics", "melody"])
    |> validate_number(:intensity_scale, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_number(:duration_bars, greater_than: 0)
    |> foreign_key_constraint(:narrative_beats_session_id)
  end
end

# lib/frestyl/narrative_beats/character_instrument.ex
defmodule Frestyl.NarrativeBeats.CharacterInstrument do
  @moduledoc """
  Assigns instruments to story characters in Narrative Beats.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "character_instruments" do
    field :character_name, :string
    field :instrument_type, :string
    field :instrument_config, :map, default: %{}
    field :track_number, :integer
    field :character_data, :map, default: %{}
    field :emotional_range, :map, default: %{}
    field :is_active, :boolean, default: true

    belongs_to :narrative_beats_session, Frestyl.NarrativeBeats.Session

    timestamps()
  end

  def changeset(character_instrument, attrs) do
    character_instrument
    |> cast(attrs, [
      :character_name, :instrument_type, :instrument_config,
      :track_number, :character_data, :emotional_range,
      :is_active, :narrative_beats_session_id
    ])
    |> validate_required([:character_name, :instrument_type, :narrative_beats_session_id])
    |> validate_length(:character_name, min: 1, max: 100)
    |> validate_inclusion(:instrument_type, [
      "piano", "guitar", "violin", "cello", "flute", "trumpet", "drums",
      "synthesizer", "voice", "bass", "saxophone", "clarinet", "harp"
    ])
    |> validate_number(:track_number, greater_than: 0, less_than: 33) # Max 32 tracks
    |> foreign_key_constraint(:narrative_beats_session_id)
    |> unique_constraint([:narrative_beats_session_id, :character_name])
    |> unique_constraint([:narrative_beats_session_id, :track_number])
  end
end

# lib/frestyl/narrative_beats/emotional_progression.ex
defmodule Frestyl.NarrativeBeats.EmotionalProgression do
  @moduledoc """
  Maps story emotions to harmonic progressions in Narrative Beats.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "emotional_progressions" do
    field :emotion_name, :string
    field :chord_progression, {:array, :string}, default: []
    field :progression_type, :string
    field :tension_level, :float, default: 0.5
    field :resolution_chords, {:array, :string}, default: []
    field :timing_pattern, :map, default: %{}
    field :dynamics, :string, default: "mf"

    belongs_to :narrative_beats_session, Frestyl.NarrativeBeats.Session

    timestamps()
  end

  def changeset(progression, attrs) do
    progression
    |> cast(attrs, [
      :emotion_name, :chord_progression, :progression_type,
      :tension_level, :resolution_chords, :timing_pattern,
      :dynamics, :narrative_beats_session_id
    ])
    |> validate_required([:emotion_name, :narrative_beats_session_id])
    |> validate_length(:emotion_name, min: 1, max: 50)
    |> validate_inclusion(:progression_type, ["major", "minor", "diminished", "augmented", "modal", "chromatic"])
    |> validate_number(:tension_level, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_inclusion(:dynamics, ["pp", "p", "mp", "mf", "f", "ff", "fff"])
    |> foreign_key_constraint(:narrative_beats_session_id)
  end
end

# lib/frestyl/narrative_beats/musical_section.ex
defmodule Frestyl.NarrativeBeats.MusicalSection do
  @moduledoc """
  Musical sections that correspond to plot points in Narrative Beats.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "musical_sections" do
    field :section_name, :string
    field :section_type, :string
    field :plot_point, :string
    field :start_time, :float, default: 0.0
    field :duration, :float, default: 16.0
    field :musical_content, :map, default: %{}
    field :arrangement, :map, default: %{}
    field :order_index, :integer

    belongs_to :narrative_beats_session, Frestyl.NarrativeBeats.Session

    timestamps()
  end

  def changeset(section, attrs) do
    section
    |> cast(attrs, [
      :section_name, :section_type, :plot_point, :start_time,
      :duration, :musical_content, :arrangement, :order_index,
      :narrative_beats_session_id
    ])
    |> validate_required([:section_name, :section_type, :narrative_beats_session_id])
    |> validate_length(:section_name, min: 1, max: 100)
    |> validate_inclusion(:section_type, ["intro", "verse", "chorus", "bridge", "outro", "interlude", "climax"])
    |> validate_number(:start_time, greater_than_or_equal_to: 0.0)
    |> validate_number(:duration, greater_than: 0.0)
    |> validate_number(:order_index, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:narrative_beats_session_id)
    |> unique_constraint([:narrative_beats_session_id, :order_index])
  end
end

# lib/frestyl/narrative_beats/collaboration_track.ex
defmodule Frestyl.NarrativeBeats.CollaborationTrack do
  @moduledoc """
  Tracks collaboration roles and permissions in Narrative Beats.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "collaboration_tracks" do
    field :role, :string
    field :assigned_elements, {:array, :string}, default: []
    field :permissions, :map, default: %{}
    field :contribution_data, :map, default: %{}
    field :last_activity_at, :utc_datetime

    belongs_to :narrative_beats_session, Frestyl.NarrativeBeats.Session
    belongs_to :user, User, foreign_key: :user_id, type: :id

    timestamps()
  end

  def changeset(track, attrs) do
    track
    |> cast(attrs, [
      :role, :assigned_elements, :permissions, :contribution_data,
      :last_activity_at, :narrative_beats_session_id, :user_id
    ])
    |> validate_required([:role, :narrative_beats_session_id, :user_id])
    |> validate_inclusion(:role, ["writer", "composer", "producer", "musician", "arranger"])
    |> foreign_key_constraint(:narrative_beats_session_id)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:narrative_beats_session_id, :user_id])
  end
end
