# lib/frestyl/streaming/streaming_session.ex
defmodule Frestyl.Streaming.StreamingSession do
  use Ecto.Schema
  import Ecto.Changeset

  schema "streaming_sessions" do
    field :session_key, :string
    field :status, :string, default: "inactive"
    field :rtmp_url, :string
    field :stream_title, :string
    field :viewer_count, :integer, default: 0
    field :started_at, :utc_datetime
    field :ended_at, :utc_datetime

    belongs_to :portfolio, Frestyl.Portfolios.Portfolio
    belongs_to :user, Frestyl.Accounts.User

    timestamps()
  end

  def changeset(streaming_session, attrs) do
    streaming_session
    |> cast(attrs, [:session_key, :status, :rtmp_url, :stream_title, :viewer_count, :started_at, :ended_at, :portfolio_id, :user_id])
    |> validate_required([:session_key, :portfolio_id, :user_id])
    |> validate_inclusion(:status, ["inactive", "starting", "live", "ending", "ended"])
  end
end
