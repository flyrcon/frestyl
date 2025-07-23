# lib/frestyl_web/controllers/api/content_controller.ex
defmodule FrestylWeb.API.ContentController do
  use FrestylWeb, :controller

  alias Frestyl.Content
  alias Frestyl.Content.Publishers
  alias Frestyl.Features.FeatureGate

  action_fallback FrestylWeb.API.FallbackController

  def index(conn, params) do
    account = get_current_account(conn)

    with :ok <- check_api_access(account) do
      filters = build_content_filters(params)
      content = Content.list_published_content(account, filters)

      render(conn, "index.json", %{content: content})
    end
  end

  def show(conn, %{"id" => id}) do
    account = get_current_account(conn)

    with {:ok, content} <- Content.get_published_content(id, account) do
      render(conn, "show.json", %{content: content})
    end
  end

  def publish_to_platforms(conn, %{"id" => id, "platforms" => platforms}) do
    account = get_current_account(conn)

    with {:ok, validated_platforms} <- Publishers.can_syndicate_to_platforms?(account, platforms),
         {:ok, results} <- Publishers.publish_to_platforms(id, validated_platforms, account) do

      render(conn, "syndication_results.json", %{results: results})
    else
      {:error, :platform_limit_exceeded, limits} ->
        conn
        |> put_status(:forbidden)
        |> json(%{
          error: "Platform limit exceeded",
          limits: limits,
          upgrade_suggestion: get_upgrade_suggestion(account, :syndication_limits)
        })

      {:error, :monthly_limit_exceeded, limits} ->
        conn
        |> put_status(:forbidden)
        |> json(%{
          error: "Monthly publish limit exceeded",
          limits: limits,
          upgrade_suggestion: get_upgrade_suggestion(account, :monthly_publishes)
        })
    end
  end

  def collaboration_data(conn, %{"id" => id}) do
    account = get_current_account(conn)

    with {:ok, document} <- Content.get_document_for_collaboration(id, account),
         summary <- Content.CollaborationTracker.get_contribution_summary(id) do

      render(conn, "collaboration.json", %{
        document: document,
        contribution_summary: summary
      })
    end
  end

  defp check_api_access(account) do
    if FeatureGate.can_access_feature?(account, :content_api) do
      :ok
    else
      {:error, :api_access_denied}
    end
  end

  defp get_upgrade_suggestion(account, feature) do
    FeatureGate.get_upgrade_suggestion(account, feature)
  end

  defp get_current_account(conn) do
    # Option 1: If you have current_user in conn.assigns
    case conn.assigns[:current_user] do
      %{account: account} when not is_nil(account) -> account
      %{accounts: [account | _]} -> account
      user when not is_nil(user) ->
        # Fetch user's primary account
        Frestyl.Accounts.get_primary_account_for_user(user.id)
      _ -> nil
    end
  end

  defp build_content_filters(params) do
    %{}
    |> maybe_add_filter(:status, params["status"])
    |> maybe_add_filter(:platform, params["platform"])
    |> maybe_add_filter(:date_range, params["date_range"])
    |> maybe_add_filter(:collaboration_campaign_id, params["campaign_id"])
  end

  defp maybe_add_filter(filters, _key, nil), do: filters
  defp maybe_add_filter(filters, _key, ""), do: filters
  defp maybe_add_filter(filters, key, value), do: Map.put(filters, key, value)

  defp check_api_access(account) when is_nil(account), do: {:error, :unauthorized}
  defp check_api_access(account) do
    if Frestyl.Features.FeatureGate.can_access_feature?(account, :content_api) do
      :ok
    else
      {:error, :api_access_denied}
    end
  end

  defp get_upgrade_suggestion(account, feature) do
    Frestyl.Features.FeatureGate.get_upgrade_suggestion(account, feature)
  end
end
