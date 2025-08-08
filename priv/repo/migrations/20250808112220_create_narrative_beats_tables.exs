# priv/repo/migrations/20250808120001_create_narrative_beats_tables.exs
defmodule Frestyl.Repo.Migrations.CreateNarrativeBeatesTables do
  use Ecto.Migration

  def change do
    # Main Narrative Beats Sessions
    create table(:narrative_beats_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :description, :text
      add :story_structure, :map, default: %{}
      add :musical_structure, :map, default: %{}
      add :collaboration_settings, :map, default: %{}
      add :session_state, :string, default: "development"
      add :bpm, :integer, default: 120
      add :key_signature, :string, default: "C"
      add :time_signature, :string, default: "4/4"
      add :total_duration, :float, default: 0.0
      add :completion_percentage, :float, default: 0.0
      add :export_settings, :map, default: %{}

      add :session_id, references(:sessions), null: false
      add :created_by_id, references(:users, type: :id), null: false

      timestamps()
    end

    # Story-to-Music Mappings
    create table(:story_music_mappings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :narrative_beats_session_id, references(:narrative_beats_sessions, type: :binary_id), null: false
      add :story_element, :string, null: false # "character", "emotion", "plot_point", "setting"
      add :story_element_id, :string # Reference to specific element
      add :musical_element, :string, null: false # "instrument", "chord_progression", "tempo", "dynamics"
      add :mapping_data, :map, default: %{}
      add :intensity_scale, :float, default: 0.5 # 0.0 to 1.0
      add :duration_bars, :integer, default: 4
      add :position_in_timeline, :float # Position in beats/measures

      timestamps()
    end

    # Character Instrument Assignments
    create table(:character_instruments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :narrative_beats_session_id, references(:narrative_beats_sessions, type: :binary_id), null: false
      add :character_name, :string, null: false
      add :instrument_type, :string, null: false
      add :instrument_config, :map, default: %{}
      add :track_number, :integer
      add :character_data, :map, default: %{}
      add :emotional_range, :map, default: %{}
      add :is_active, :boolean, default: true

      timestamps()
    end

    # Emotional Progressions (maps story emotions to harmonic progressions)
    create table(:emotional_progressions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :narrative_beats_session_id, references(:narrative_beats_sessions, type: :binary_id), null: false
      add :emotion_name, :string, null: false
      add :chord_progression, {:array, :string}, default: []
      add :progression_type, :string # "major", "minor", "diminished", "augmented", "modal"
      add :tension_level, :float, default: 0.5 # 0.0 (calm) to 1.0 (intense)
      add :resolution_chords, {:array, :string}, default: []
      add :timing_pattern, :map, default: %{}
      add :dynamics, :string, default: "mf" # Musical dynamics notation

      timestamps()
    end

    # Musical Sections (verse, chorus, bridge mapping to plot points)
    create table(:musical_sections, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :narrative_beats_session_id, references(:narrative_beats_sessions, type: :binary_id), null: false
      add :section_name, :string, null: false
      add :section_type, :string, null: false # "intro", "verse", "chorus", "bridge", "outro"
      add :plot_point, :string # Story element this represents
      add :start_time, :float, default: 0.0
      add :duration, :float, default: 16.0 # Duration in bars
      add :musical_content, :map, default: %{}
      add :arrangement, :map, default: %{}
      add :order_index, :integer

      timestamps()
    end

    # Collaboration Tracks (who's working on what)
    create table(:collaboration_tracks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :narrative_beats_session_id, references(:narrative_beats_sessions, type: :binary_id), null: false
      add :user_id, references(:users, type: :id), null: false
      add :role, :string, null: false # "writer", "composer", "producer", "musician"
      add :assigned_elements, {:array, :string}, default: []
      add :permissions, :map, default: %{}
      add :contribution_data, :map, default: %{}
      add :last_activity_at, :utc_datetime

      timestamps()
    end

    # AI Music Suggestions
    create table(:ai_music_suggestions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :narrative_beats_session_id, references(:narrative_beats_sessions, type: :binary_id), null: false
      add :suggestion_type, :string, null: false # "chord_progression", "melody", "rhythm", "arrangement"
      add :context, :map, default: %{}
      add :suggestion_data, :map, default: %{}
      add :confidence_score, :float, default: 0.5
      add :status, :string, default: "pending" # "pending", "accepted", "rejected", "modified"
      add :feedback, :text

      timestamps()
    end

    # Beat Machine Patterns for Narrative Beats
    create table(:narrative_beat_patterns, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :narrative_beats_session_id, references(:narrative_beats_sessions, type: :binary_id), null: false
      add :pattern_name, :string, null: false
      add :story_context, :string # What story element this pattern represents
      add :pattern_data, :map, default: %{}
      add :steps, :integer, default: 16
      add :tracks, :map, default: %{}
      add :is_active, :boolean, default: false

      timestamps()
    end

    # Indexes for performance
    create index(:narrative_beats_sessions, [:session_id])
    create index(:narrative_beats_sessions, [:created_by_id])
    create index(:story_music_mappings, [:narrative_beats_session_id])
    create index(:character_instruments, [:narrative_beats_session_id])
    create index(:emotional_progressions, [:narrative_beats_session_id])
    create index(:musical_sections, [:narrative_beats_session_id, :order_index])
    create index(:collaboration_tracks, [:narrative_beats_session_id, :user_id])
    create index(:ai_music_suggestions, [:narrative_beats_session_id, :status])
    create index(:narrative_beat_patterns, [:narrative_beats_session_id])
  end
end
