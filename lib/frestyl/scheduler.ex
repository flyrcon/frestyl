# lib/frestyl/scheduler.ex
defmodule Frestyl.Scheduler do
  use GenServer
  alias Frestyl.Analytics

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{})
  end

  @impl true
  def init(state) do
    # Schedule daily report generation
    schedule_daily_report()
    {:ok, state}
  end

  @impl true
  def handle_info(:generate_daily_report, state) do
    # Generate yesterday's report
    yesterday = Date.add(Date.utc_today(), -1)
    Analytics.generate_daily_report(yesterday)

    # Reschedule for tomorrow
    schedule_daily_report()
    {:noreply, state}
  end

  defp schedule_daily_report do
    # Schedule to run at 1 AM UTC
    now = DateTime.utc_now()
    target = %{DateTime.utc_now() | hour: 1, minute: 0, second: 0}
    target = if DateTime.compare(now, target) == :gt do
      DateTime.add(target, 86400, :second) # Add one day
    else
      target
    end

    diff = DateTime.diff(target, now, :millisecond)
    Process.send_after(self(), :generate_daily_report, diff)
  end
end
