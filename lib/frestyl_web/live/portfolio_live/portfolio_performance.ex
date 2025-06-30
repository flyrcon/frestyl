# lib/frestyl_web/live/portfolio_live/portfolio_performance.ex
defmodule FrestylWeb.PortfolioLive.PortfolioPerformance do
  @moduledoc """
  Performance tracking and telemetry for portfolio-related operations.
  """

  def track_portfolio_editor_load(portfolio_id, load_time_ms) do
    :telemetry.execute(
      [:frestyl, :portfolio_editor, :load],
      %{duration: load_time_ms},
      %{portfolio_id: portfolio_id}
    )
  end

  def track_integration_usage(integration_type, portfolio_id) do
    :telemetry.execute(
      [:frestyl, :integration, :used],
      %{count: 1},
      %{type: integration_type, portfolio_id: portfolio_id}
    )
  end

  def track_content_block_creation(block_type, section_id, creation_time_ms) do
    :telemetry.execute(
      [:frestyl, :content_block, :created],
      %{duration: creation_time_ms, count: 1},
      %{block_type: block_type, section_id: section_id}
    )
  end
end
