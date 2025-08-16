# lib/frestyl_web/controllers/api/podcast_controller.ex
defmodule FrestylWeb.Api.PodcastController do
  use FrestylWeb, :controller

  alias Frestyl.Podcasts

  def analytics(conn, %{"show_id" => show_id} = params) do
    timeframe = Map.get(params, "timeframe", "month") |> String.to_atom()
    analytics = Podcasts.get_show_analytics(show_id, timeframe)

    json(conn, %{status: "success", data: analytics})
  end

  def episode_analytics(conn, %{"episode_id" => episode_id}) do
    analytics = Podcasts.get_episode_analytics(episode_id)

    json(conn, %{status: "success", data: analytics})
  end

  def track_event(conn, %{"episode_id" => episode_id, "event" => event_data}) do
    # Track podcast listening events for analytics
    case Podcasts.Analytics.track_event(episode_id, event_data) do
      {:ok, _} ->
        json(conn, %{status: "success"})
      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{status: "error", error: to_string(reason)})
    end
  end

  def rss_feed(conn, %{"show_id" => show_id}) do
    case Podcasts.get_rss_feed(show_id) do
      {:ok, rss_content} ->
        conn
        |> put_resp_content_type("application/rss+xml")
        |> text(rss_content)
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{status: "error", error: "RSS feed not found"})
    end
  end

  def rss_feed_by_slug(conn, %{"show_slug" => slug}) do
    case Podcasts.get_show_by_slug(slug) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{status: "error", error: "Podcast not found"})
      show ->
        rss_feed(conn, %{"show_id" => show.id})
    end
  end
end
