defmodule Frestyl.Teams.PortfolioManager do
  alias Frestyl.{Portfolios, Teams, Repo}
  import Ecto.Query

  def create_team_portfolio(team, members, portfolio_template) do
    with {:ok, portfolio} <- create_base_portfolio(portfolio_template),
         {:ok, _} <- assign_team_members(portfolio, members),
         {:ok, _} <- setup_collaboration_permissions(portfolio, team) do
      {:ok, portfolio}
    end
  end

  def get_team_analytics(team, date_range) do
    portfolios = get_team_portfolios(team)

    %{
      total_views: calculate_total_views(portfolios, date_range),
      engagement_metrics: calculate_engagement(portfolios, date_range),
      top_performing_portfolios: get_top_performers(portfolios, date_range),
      member_performance: calculate_member_metrics(portfolios, date_range)
    }
  end

  # Private helper functions

  defp create_base_portfolio(portfolio_template) do
    portfolio_attrs = %{
      title: portfolio_template.title || "Team Portfolio",
      slug: generate_unique_slug(portfolio_template.title),
      account_type: :professional,
      cross_account_sharing: true,
      sharing_permissions: %{
        "team_collaboration" => true,
        "public_view" => false
      }
    }

    case Portfolios.create_portfolio(portfolio_attrs) do
      {:ok, portfolio} -> {:ok, portfolio}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp assign_team_members(portfolio, members) do
    team_assignments = Enum.map(members, fn member ->
      %{
        portfolio_id: portfolio.id,
        user_id: member.user_id,
        collaboration_level: member.role || "member",
        inserted_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }
    end)

    case Repo.insert_all("team_portfolios", team_assignments) do
      {count, _} when count > 0 -> {:ok, :assigned}
      _ -> {:error, "Failed to assign team members"}
    end
  end

  defp setup_collaboration_permissions(portfolio, team) do
    permissions = %{
      team_id: team.id,
      edit_permissions: ["admin", "editor"],
      view_permissions: ["admin", "editor", "member"],
      comment_permissions: ["admin", "editor", "member"]
    }

    case Portfolios.update_portfolio(portfolio, %{sharing_permissions: permissions}) do
      {:ok, updated_portfolio} -> {:ok, updated_portfolio}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp get_team_portfolios(team) do
    from(p in Portfolios.Portfolio,
      join: tp in "team_portfolios", on: tp.portfolio_id == p.id,
      where: tp.team_id == ^team.id,
      preload: [:sections, :user]
    )
    |> Repo.all()
  end

  defp calculate_total_views(portfolios, date_range) do
    portfolio_ids = Enum.map(portfolios, & &1.id)

    from(pa in "portfolio_analytics",
      where: pa.portfolio_id in ^portfolio_ids,
      where: pa.date >= ^date_range.start_date and pa.date <= ^date_range.end_date,
      select: sum(pa.views)
    )
    |> Repo.one() || 0
  end

  defp calculate_engagement(portfolios, date_range) do
    portfolio_ids = Enum.map(portfolios, & &1.id)

    analytics = from(pa in "portfolio_analytics",
      where: pa.portfolio_id in ^portfolio_ids,
      where: pa.date >= ^date_range.start_date and pa.date <= ^date_range.end_date,
      select: %{
        total_views: sum(pa.views),
        total_engagement_time: sum(pa.engagement_time),
        avg_bounce_rate: avg(pa.bounce_rate)
      }
    )
    |> Repo.one()

    %{
      total_sessions: analytics.total_views || 0,
      avg_engagement_time: safe_divide(analytics.total_engagement_time, analytics.total_views),
      bounce_rate: analytics.avg_bounce_rate || 0.0
    }
  end

  defp get_top_performers(portfolios, date_range) do
    portfolio_ids = Enum.map(portfolios, & &1.id)

    from(pa in "portfolio_analytics",
      where: pa.portfolio_id in ^portfolio_ids,
      where: pa.date >= ^date_range.start_date and pa.date <= ^date_range.end_date,
      group_by: pa.portfolio_id,
      select: %{
        portfolio_id: pa.portfolio_id,
        total_views: sum(pa.views),
        unique_visitors: sum(pa.unique_visitors)
      },
      order_by: [desc: sum(pa.views)],
      limit: 5
    )
    |> Repo.all()
    |> Enum.map(fn analytics ->
      portfolio = Enum.find(portfolios, &(&1.id == analytics.portfolio_id))
      Map.put(analytics, :portfolio, portfolio)
    end)
  end

  defp calculate_member_metrics(portfolios, date_range) do
    # Group portfolios by user/member
    portfolios_by_user = Enum.group_by(portfolios, & &1.user_id)

    Enum.map(portfolios_by_user, fn {user_id, user_portfolios} ->
      portfolio_ids = Enum.map(user_portfolios, & &1.id)

      user_analytics = from(pa in "portfolio_analytics",
        where: pa.portfolio_id in ^portfolio_ids,
        where: pa.date >= ^date_range.start_date and pa.date <= ^date_range.end_date,
        select: %{
          total_views: sum(pa.views),
          total_portfolios: count(fragment("DISTINCT ?", pa.portfolio_id))
        }
      )
      |> Repo.one()

      %{
        user_id: user_id,
        portfolio_count: length(user_portfolios),
        total_views: user_analytics.total_views || 0,
        avg_views_per_portfolio: safe_divide(user_analytics.total_views, length(user_portfolios))
      }
    end)
  end

  defp generate_unique_slug(title) do
    base_slug = title
                |> String.downcase()
                |> String.replace(~r/[^a-z0-9\s-]/, "")
                |> String.replace(~r/\s+/, "-")
                |> String.trim_trailing("-")

    # Add timestamp to ensure uniqueness
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    "#{base_slug}-#{timestamp}"
  end

  defp safe_divide(numerator, denominator) when denominator == 0 or denominator == nil, do: 0
  defp safe_divide(numerator, denominator), do: numerator / denominator
end
