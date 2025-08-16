# lib/frestyl/podcasts/analytics.ex
defmodule Frestyl.Podcasts.Analytics do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias Frestyl.Repo

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "podcast_analytics" do
    field :event_type, :string # download, play, completion, share, etc
    field :platform, :string # spotify, apple, web, etc
    field :country, :string
    field :device_type, :string # mobile, desktop, tablet
    field :user_agent, :string
    field :duration_listened, :integer # seconds
    field :completion_rate, :float # 0.0 to 1.0
    field :timestamp, :utc_datetime
    field :metadata, :map, default: %{}

    belongs_to :show, Frestyl.Podcasts.Show
    belongs_to :episode, Frestyl.Podcasts.Episode
    belongs_to :user, Frestyl.Accounts.User # if authenticated

    timestamps()
  end

  def changeset(analytics, attrs) do
    analytics
    |> cast(attrs, [:event_type, :platform, :country, :device_type, :user_agent,
                    :duration_listened, :completion_rate, :timestamp, :metadata,
                    :show_id, :episode_id, :user_id])
    |> validate_required([:event_type, :timestamp])
    |> validate_inclusion(:event_type, ~w(download play pause resume completion share subscribe))
    |> validate_number(:completion_rate, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_number(:duration_listened, greater_than_or_equal_to: 0)
  end

  # Analytics aggregation functions

  def initialize_show_tracking(show_id) do
    # Create initial analytics tracking for show
    %__MODULE__{}
    |> changeset(%{
      event_type: "show_created",
      show_id: show_id,
      timestamp: DateTime.utc_now(),
      metadata: %{tracking_initialized: true}
    })
    |> Repo.insert()
  end

  def track_episode_published(episode_id) do
    %__MODULE__{}
    |> changeset(%{
      event_type: "episode_published",
      episode_id: episode_id,
      timestamp: DateTime.utc_now()
    })
    |> Repo.insert()
  end

  def track_guest_invited(guest_id) do
    # This would be tracked via episode association
    # Implementation depends on how you want to structure guest analytics
    :ok
  end

  def get_show_analytics(show_id, timeframe) do
    {start_date, end_date} = get_timeframe_dates(timeframe)

    base_query = from a in __MODULE__,
      where: a.show_id == ^show_id and
             a.timestamp >= ^start_date and
             a.timestamp <= ^end_date

    %{
      total_downloads: get_total_downloads(base_query),
      total_plays: get_total_plays(base_query),
      unique_listeners: get_unique_listeners(base_query),
      average_completion_rate: get_average_completion_rate(base_query),
      top_episodes: get_top_episodes(show_id, timeframe),
      geographic_breakdown: get_geographic_breakdown(base_query),
      platform_breakdown: get_platform_breakdown(base_query),
      listening_trends: get_listening_trends(base_query, timeframe),
      growth_metrics: get_growth_metrics(show_id, timeframe)
    }
  end

  def get_episode_analytics(episode_id) do
    base_query = from a in __MODULE__, where: a.episode_id == ^episode_id

    %{
      total_downloads: get_total_downloads(base_query),
      total_plays: get_total_plays(base_query),
      unique_listeners: get_unique_listeners(base_query),
      average_completion_rate: get_average_completion_rate(base_query),
      listening_pattern: get_listening_pattern(episode_id),
      drop_off_points: get_drop_off_points(episode_id),
      geographic_breakdown: get_geographic_breakdown(base_query),
      platform_breakdown: get_platform_breakdown(base_query),
      engagement_score: calculate_engagement_score(base_query)
    }
  end

  defp get_timeframe_dates(:week) do
    end_date = DateTime.utc_now()
    start_date = DateTime.add(end_date, -7, :day)
    {start_date, end_date}
  end

  defp get_timeframe_dates(:month) do
    end_date = DateTime.utc_now()
    start_date = DateTime.add(end_date, -30, :day)
    {start_date, end_date}
  end

  defp get_timeframe_dates(:year) do
    end_date = DateTime.utc_now()
    start_date = DateTime.add(end_date, -365, :day)
    {start_date, end_date}
  end

  defp get_total_downloads(base_query) do
    from(a in base_query, where: a.event_type == "download", select: count(a.id))
    |> Repo.one() || 0
  end

  defp get_total_plays(base_query) do
    from(a in base_query, where: a.event_type == "play", select: count(a.id))
    |> Repo.one() || 0
  end

  defp get_unique_listeners(base_query) do
    from(a in base_query,
         where: a.event_type in ["play", "download"],
         select: count(a.user_id, :distinct))
    |> Repo.one() || 0
  end

  defp get_average_completion_rate(base_query) do
    from(a in base_query,
         where: a.event_type == "completion" and not is_nil(a.completion_rate),
         select: avg(a.completion_rate))
    |> Repo.one() || 0.0
  end

  defp get_top_episodes(show_id, timeframe) do
    {start_date, end_date} = get_timeframe_dates(timeframe)

    from(a in __MODULE__,
         join: e in Frestyl.Podcasts.Episode, on: a.episode_id == e.id,
         where: a.show_id == ^show_id and
                a.timestamp >= ^start_date and
                a.timestamp <= ^end_date and
                a.event_type in ["play", "download"],
         group_by: [a.episode_id, e.title],
         select: %{episode_id: a.episode_id, title: e.title, total_listens: count(a.id)},
         order_by: [desc: count(a.id)],
         limit: 10)
    |> Repo.all()
  end

  defp get_geographic_breakdown(base_query) do
    from(a in base_query,
         where: not is_nil(a.country),
         group_by: a.country,
         select: %{country: a.country, listens: count(a.id)},
         order_by: [desc: count(a.id)],
         limit: 20)
    |> Repo.all()
  end

  defp get_platform_breakdown(base_query) do
    from(a in base_query,
         where: not is_nil(a.platform),
         group_by: a.platform,
         select: %{platform: a.platform, listens: count(a.id)},
         order_by: [desc: count(a.id)])
    |> Repo.all()
  end

  defp get_listening_trends(base_query, timeframe) do
    # Group by time period based on timeframe
    interval = case timeframe do
      :week -> "day"
      :month -> "day"
      :year -> "month"
    end

    from(a in base_query,
         where: a.event_type in ["play", "download"],
         group_by: fragment("date_trunc(?, ?)", ^interval, a.timestamp),
         select: %{
           period: fragment("date_trunc(?, ?)", ^interval, a.timestamp),
           listens: count(a.id)
         },
         order_by: fragment("date_trunc(?, ?)", ^interval, a.timestamp))
    |> Repo.all()
  end

  defp get_growth_metrics(show_id, timeframe) do
    # Calculate growth compared to previous period
    current_stats = get_show_analytics(show_id, timeframe)

    # Get previous period stats for comparison
    {prev_start, prev_end} = get_previous_timeframe_dates(timeframe)

    prev_query = from a in __MODULE__,
      where: a.show_id == ^show_id and
             a.timestamp >= ^prev_start and
             a.timestamp <= ^prev_end

    prev_downloads = get_total_downloads(prev_query)
    prev_plays = get_total_plays(prev_query)

    %{
      downloads_growth: calculate_growth_rate(current_stats.total_downloads, prev_downloads),
      plays_growth: calculate_growth_rate(current_stats.total_plays, prev_plays),
      listener_growth: calculate_growth_rate(current_stats.unique_listeners, get_unique_listeners(prev_query))
    }
  end

  defp get_previous_timeframe_dates(:week) do
    end_date = DateTime.add(DateTime.utc_now(), -7, :day)
    start_date = DateTime.add(end_date, -7, :day)
    {start_date, end_date}
  end

  defp get_previous_timeframe_dates(:month) do
    end_date = DateTime.add(DateTime.utc_now(), -30, :day)
    start_date = DateTime.add(end_date, -30, :day)
    {start_date, end_date}
  end

  defp get_previous_timeframe_dates(:year) do
    end_date = DateTime.add(DateTime.utc_now(), -365, :day)
    start_date = DateTime.add(end_date, -365, :day)
    {start_date, end_date}
  end

  defp calculate_growth_rate(current, previous) when previous == 0, do: if current > 0, do: 100.0, else: 0.0
  defp calculate_growth_rate(current, previous) do
    ((current - previous) / previous * 100.0) |> Float.round(2)
  end

  defp get_listening_pattern(episode_id) do
    # Analyze when people start/stop listening within the episode
    from(a in __MODULE__,
         where: a.episode_id == ^episode_id and a.event_type in ["play", "pause", "resume"],
         order_by: a.timestamp,
         select: %{event: a.event_type, timestamp: a.timestamp, metadata: a.metadata})
    |> Repo.all()
  end

  defp get_drop_off_points(episode_id) do
    # Analyze where people typically stop listening
    from(a in __MODULE__,
         where: a.episode_id == ^episode_id and
                a.event_type == "pause" and
                not is_nil(a.duration_listened),
         group_by: fragment("floor(? / 60)", a.duration_listened), # Group by minute
         select: %{
           minute: fragment("floor(? / 60)", a.duration_listened),
           drop_offs: count(a.id)
         },
         order_by: fragment("floor(? / 60)", a.duration_listened))
    |> Repo.all()
  end

  defp calculate_engagement_score(base_query) do
    # Calculate engagement score based on completion rate, shares, etc
    completion_rate = get_average_completion_rate(base_query)

    shares = from(a in base_query, where: a.event_type == "share", select: count(a.id))
             |> Repo.one() || 0

    total_listens = get_total_plays(base_query)

    share_rate = if total_listens > 0, do: shares / total_listens, else: 0.0

    # Weighted engagement score
    (completion_rate * 0.7 + share_rate * 0.3) * 100
    |> Float.round(2)
  end
end
