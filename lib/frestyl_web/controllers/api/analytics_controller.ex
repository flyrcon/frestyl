defmodule FrestylWeb.API.AnalyticsController do
  use FrestylWeb, :controller
  alias Frestyl.Analytics

  # API key authentication (you'll need to implement this)
  plug :authenticate_api_request

  # 2FA verification for API requests
  def verify_2fa(conn, %{"totp_code" => totp_code}) do
    user = conn.assigns.current_user

    if user && user.totp_enabled do
      if Accounts.verify_totp(user.totp_secret, totp_code) do
        # Mark session as 2FA verified
        conn
        |> put_session(:totp_verified, true)
        |> json(%{success: true, message: "Two-factor authentication verified"})
      else
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "invalid_code", message: "Invalid verification code"})
      end
    else
      conn
      |> put_status(:bad_request)
      |> json(%{error: "2fa_not_enabled", message: "Two-factor authentication not enabled for this user"})
    end
  end

  def verify_backup_code(conn, %{"backup_code" => backup_code}) do
    user = conn.assigns.current_user

    if user && user.totp_enabled do
      case Accounts.verify_backup_code(user, backup_code) do
        {:ok, _updated_user} ->
          # Mark session as 2FA verified
          conn
          |> put_session(:totp_verified, true)
          |> json(%{success: true, message: "Backup code accepted"})

        {:error, _reason} ->
          conn
          |> put_status(:unauthorized)
          |> json(%{error: "invalid_code", message: "Invalid backup code"})
      end
    else
      conn
      |> put_status(:bad_request)
      |> json(%{error: "2fa_not_enabled", message: "Two-factor authentication not enabled for this user"})
    end
  end

  def status(conn, _params) do
    user = conn.assigns.current_user

    if user do
      totp_verified = get_session(conn, :totp_verified) || false

      conn
      |> json(%{
        authenticated: true,
        totp_enabled: user.totp_enabled || false,
        totp_verified: totp_verified
      })
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{authenticated: false})
    end
  end

  @doc """
  Returns metrics based on query parameters.
  """
  def index(conn, params) do
    # Extract query parameters
    channel_id = params["channel_id"]
    session_id = params["session_id"]
    event_id = params["event_id"]
    start_date = parse_date(params["start_date"])
    end_date = parse_date(params["end_date"]) || Date.utc_today()
    metric_type = params["metric_type"]

    # Get metrics based on parameters
    metrics =
      cond do
        channel_id && metric_type == "revenue" ->
          Analytics.get_revenue_metrics(channel_id, start_date, end_date)
        channel_id ->
          Analytics.list_channel_metrics(channel_id, start_date, end_date)
        session_id ->
          Analytics.get_session_metrics(session_id)
        event_id ->
          Analytics.get_audience_insights(event_id)
        true ->
          []
      end

    render(conn, :index, metrics: metrics)
  end

  @doc """
  Creates a new metric entry.
  """
  def create(conn, %{"metric" => metric_params}) do
    # Determine the type of metric and call the appropriate function
    result =
      cond do
        Map.has_key?(metric_params, "channel_id") && Map.has_key?(metric_params, "total_amount") ->
          Analytics.record_revenue(metric_params)
        Map.has_key?(metric_params, "channel_id") && Map.has_key?(metric_params, "session_id") &&
        Map.has_key?(metric_params, "buffer_count") ->
          Analytics.track_session_metric(metric_params)
        Map.has_key?(metric_params, "event_id") && Map.has_key?(metric_params, "demographic_group") ->
          Analytics.track_audience_insight(metric_params)
        Map.has_key?(metric_params, "channel_id") ->
          Analytics.track_channel_metric(metric_params)
        true ->
          {:error, "Invalid metric parameters"}
      end

    case result do
      {:ok, metric} ->
        conn
        |> put_status(:created)
        |> render(:show, metric: metric)
      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:error, changeset: changeset)
      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:error, error: reason)
    end
  end

  @doc """
  Returns metrics for a specific channel.
  """
  def channel_metrics(conn, %{"channel_id" => channel_id} = params) do
    start_date = parse_date(params["start_date"])
    end_date = parse_date(params["end_date"]) || Date.utc_today()
    interval = params["interval"] || "day"

    metrics = Analytics.aggregate_channel_metrics(channel_id, start_date, end_date, interval)

    render(conn, :channel_metrics, metrics: metrics)
  end

  @doc """
  Returns metrics for a specific session.
  """
  def session_metrics(conn, %{"session_id" => session_id}) do
    metrics = Analytics.get_session_metrics(session_id)

    render(conn, :session_metrics, metrics: metrics)
  end

  @doc """
  Returns audience insights for a specific event.
  """
  def audience_insights(conn, %{"event_id" => event_id}) do
    insights = Analytics.get_audience_insights(event_id)
    demographics = Analytics.get_audience_demographics(event_id)
    geography = Analytics.get_audience_geography(event_id)

    render(conn, :audience_insights,
      insights: insights,
      demographics: demographics,
      geography: geography
    )
  end

  @doc """
  Returns revenue metrics for a specific channel.
  """
  def revenue_metrics(conn, %{"channel_id" => channel_id} = params) do
    start_date = parse_date(params["start_date"])
    end_date = parse_date(params["end_date"]) || Date.utc_today()
    interval = params["interval"] || "day"

    metrics = Analytics.aggregate_revenue_metrics(channel_id, start_date, end_date, interval)

    render(conn, :revenue_metrics, metrics: metrics)
  end

  # Helper functions

  def get_analytics_api_key(_user), do: "demo-api-key"


  defp parse_date(nil), do: nil
  defp parse_date(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp authenticate_api_request(conn, _opts) do
    # This is a placeholder - implement your API authentication logic here
    # For example, check for an API key in headers
    api_key = get_req_header(conn, "x-api-key") |> List.first()

    if api_key && valid_api_key?(api_key) do
      conn
    else
      conn
      |> put_status(:unauthorized)
      |> put_view(FrestylWeb.ErrorView)
      |> render("401.json", message: "Unauthorized")
      |> halt()
    end
  end

  defp valid_api_key?(api_key) do
    # This is a placeholder - implement your API key validation logic here
    # For development, you might return true to bypass authentication
    true
  end
end
