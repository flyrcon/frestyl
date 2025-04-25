# lib/frestyl_web/plugs/rate_limiter.ex
defmodule FrestylWeb.Plugs.RateLimiter do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, opts) do
    limit = opts[:limit] || 10
    period = opts[:period] || 60_000 # 1 minute in milliseconds

    # Use IP address or user ID as key
    key = case conn.assigns[:current_user] do
      nil -> conn.remote_ip |> :inet.ntoa() |> to_string()
      user -> "user:#{user.id}"
    end

    case check_rate(key, limit, period) do
      :ok ->
        conn
      :rate_limited ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(429, Jason.encode!(%{error: "Rate limit exceeded. Please try again later."}))
        |> halt()
    end
  end

  # Implementation would use Redis or ETS to track request rates
  defp check_rate(key, limit, period) do
    # This is a placeholder - you'd implement this with Redis or ETS
    :ok
  end
end
