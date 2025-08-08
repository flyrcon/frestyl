# lib/frestyl/voice_sketch.ex
defmodule Frestyl.VoiceSketch do
  @moduledoc """
  The VoiceSketch context.
  """

  import Ecto.Query, warn: false
  alias Frestyl.Repo
  alias Frestyl.VoiceSketch.{Session, Stroke}

  # Session Management

  def list_sessions do
    Repo.all(Session)
  end

  def list_user_sessions(user_id) do
    Session
    |> where([s], s.user_id == ^user_id)
    |> order_by([s], desc: s.updated_at)
    |> Repo.all()
  end

  def get_session!(id) do
    # Fixed: Use proper preload with ordered strokes
    stroke_query = from(st in Stroke, order_by: st.stroke_order)

    Session
    |> preload(strokes: ^stroke_query)
    |> Repo.get!(id)
  end

  def get_session(id) do
    # Fixed: Use proper preload with ordered strokes
    stroke_query = from(st in Stroke, order_by: st.stroke_order)

    Session
    |> preload(strokes: ^stroke_query)
    |> Repo.get(id)
  end

  def create_session(attrs \\ %{}) do
    %Session{}
    |> Session.changeset(attrs)
    |> Repo.insert()
  end

  def update_session(%Session{} = session, attrs) do
    session
    |> Session.changeset(attrs)
    |> Repo.update()
  end

  def delete_session(%Session{} = session) do
    Repo.delete(session)
  end

  def change_session(%Session{} = session, attrs \\ %{}) do
    Session.changeset(session, attrs)
  end

  # Stroke Management

  def list_session_strokes(session_id) do
    Stroke
    |> where([st], st.session_id == ^session_id)
    |> order_by([st], asc: st.stroke_order)
    |> Repo.all()
  end

  def get_stroke!(id) do
    Repo.get!(Stroke, id)
  end

  def create_stroke(attrs \\ %{}) do
    %Stroke{}
    |> Stroke.changeset(attrs)
    |> Repo.insert()
  end

  def update_stroke(%Stroke{} = stroke, attrs) do
    stroke
    |> Stroke.changeset(attrs)
    |> Repo.update()
  end

  def delete_stroke(%Stroke{} = stroke) do
    Repo.delete(stroke)
  end

  def change_stroke(%Stroke{} = stroke, attrs \\ %{}) do
    Stroke.changeset(stroke, attrs)
  end

  # Batch stroke operations
  def add_strokes_to_session(session_id, strokes_data) do
    strokes = Enum.map(strokes_data, fn stroke_data ->
      %{
        session_id: session_id,
        stroke_data: stroke_data.stroke_data,
        stroke_order: stroke_data.stroke_order,
        timestamp: stroke_data.timestamp || DateTime.utc_now(),
        inserted_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }
    end)

    Repo.insert_all(Stroke, strokes)
  end

  def clear_session_strokes(session_id) do
    Stroke
    |> where([st], st.session_id == ^session_id)
    |> Repo.delete_all()
  end

  # Session status management
  def start_recording(session_id) do
    session = get_session!(session_id)
    update_session(session, %{
      status: "recording",
      started_at: DateTime.utc_now()
    })
  end

  def pause_recording(session_id) do
    session = get_session!(session_id)
    update_session(session, %{status: "paused"})
  end

  def stop_recording(session_id) do
    session = get_session!(session_id)
    duration = calculate_session_duration(session)

    update_session(session, %{
      status: "completed",
      completed_at: DateTime.utc_now(),
      duration: duration
    })
  end

  # Audio synchronization
  def sync_audio_with_strokes(session_id, audio_duration) do
    strokes = list_session_strokes(session_id)

    # Calculate timing ratios and update stroke timestamps
    Enum.each(strokes, fn stroke ->
      # Implement audio synchronization logic here
      # This would update stroke timestamps to match audio timeline
    end)
  end

  # Export functionality
  def export_session_data(session_id, format \\ :json) do
    session = get_session!(session_id)
    strokes = list_session_strokes(session_id)

    export_data = %{
      session: session,
      strokes: strokes,
      metadata: %{
        exported_at: DateTime.utc_now(),
        format: format,
        version: "1.0"
      }
    }

    case format do
      :json -> Jason.encode(export_data)
      :svg -> convert_to_svg(export_data)
      :video -> generate_video_export(export_data)
      _ -> {:error, "Unsupported format"}
    end
  end

  # Analytics and statistics
  def get_session_stats(session_id) do
    session = get_session!(session_id)
    strokes = list_session_strokes(session_id)

    %{
      total_strokes: length(strokes),
      duration: session.duration || 0,
      status: session.status,
      complexity_score: calculate_complexity_score(strokes),
      avg_stroke_duration: calculate_avg_stroke_duration(strokes),
      canvas_coverage: calculate_canvas_coverage(strokes)
    }
  end

  def get_user_stats(user_id) do
    sessions = list_user_sessions(user_id)

    total_sessions = length(sessions)
    completed_sessions = Enum.count(sessions, &(&1.status == "completed"))
    total_duration = Enum.reduce(sessions, 0, &((&1.duration || 0) + &2))

    %{
      total_sessions: total_sessions,
      completed_sessions: completed_sessions,
      completion_rate: if(total_sessions > 0, do: completed_sessions / total_sessions * 100, else: 0),
      total_duration: total_duration,
      avg_session_duration: if(total_sessions > 0, do: total_duration / total_sessions, else: 0)
    }
  end

  # Private helper functions
  defp calculate_session_duration(%Session{inserted_at: nil}), do: 0
  defp calculate_session_duration(%Session{inserted_at: inserted_at}) do
    DateTime.diff(DateTime.utc_now(), inserted_at, :second)
  end

  defp calculate_complexity_score(strokes) do
    # Simple complexity calculation based on number of strokes and data points
    total_points = Enum.reduce(strokes, 0, fn stroke, acc ->
      points = length(stroke.stroke_data["points"] || [])
      acc + points
    end)

    cond do
      total_points > 10000 -> "complex"
      total_points > 5000 -> "detailed"
      total_points > 1000 -> "moderate"
      total_points > 0 -> "simple"
      true -> "none"
    end
  end

  defp calculate_avg_stroke_duration(strokes) do
    if length(strokes) == 0 do
      0
    else
      total_duration = Enum.reduce(strokes, 0, fn stroke, acc ->
        duration = stroke.stroke_data["duration"] || 0
        acc + duration
      end)

      total_duration / length(strokes)
    end
  end

  defp calculate_canvas_coverage(strokes) do
    # Calculate what percentage of the canvas has been used
    # This is a simplified version - would need actual canvas dimensions
    if length(strokes) == 0 do
      0
    else
      # Simplified calculation - would need proper bounds calculation
      min(length(strokes) * 5, 100)  # Each stroke covers ~5% of canvas, max 100%
    end
  end

  defp convert_to_svg(export_data) do
    # Convert stroke data to SVG format
    # This would implement actual SVG generation
    {:ok, "<svg><!-- SVG content would go here --></svg>"}
  end

  defp generate_video_export(export_data) do
    # Generate video from stroke data and audio
    # This would implement actual video generation
    {:ok, "video_export_path.mp4"}
  end
end

# Also fix the Session schema if it has similar issues
# lib/frestyl/voice_sketch/session.ex
defmodule Frestyl.VoiceSketch.Session do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "voice_sketch_sessions" do
    field :title, :string
    field :description, :string
    field :status, :string, default: "draft"
    field :duration, :integer, default: 0
    field :audio_url, :string
    field :canvas_data, :map, default: %{}
    field :settings, :map, default: %{}
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime

    belongs_to :user, Frestyl.Accounts.User, type: :id
    has_many :strokes, Frestyl.VoiceSketch.Stroke, foreign_key: :session_id

    timestamps()
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [
      :title, :description, :status, :duration, :audio_url,
      :canvas_data, :settings, :started_at, :completed_at, :user_id
    ])
    |> validate_required([:title, :user_id])
    |> validate_length(:title, min: 1, max: 200)
    |> validate_inclusion(:status, ["draft", "recording", "paused", "completed", "exported"])
    |> validate_number(:duration, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:user_id)
  end
end

# lib/frestyl/voice_sketch/stroke.ex
defmodule Frestyl.VoiceSketch.Stroke do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "voice_sketch_strokes" do
    field :stroke_data, :map
    field :stroke_order, :integer
    field :timestamp, :utc_datetime

    belongs_to :session, Frestyl.VoiceSketch.Session

    timestamps()
  end

  def changeset(stroke, attrs) do
    stroke
    |> cast(attrs, [:stroke_data, :stroke_order, :timestamp, :session_id])
    |> validate_required([:stroke_data, :stroke_order, :session_id])
    |> validate_number(:stroke_order, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:session_id)
  end
end
