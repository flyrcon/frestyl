# File: lib/frestyl/integrations/external_tools.ex

defmodule Frestyl.Integrations.ExternalTools do
  @moduledoc """
  Integration examples for external content creation tools to connect
  with the Frestyl content campaigns system via API.
  """

  # ============================================================================
  # NOTION INTEGRATION EXAMPLE
  # ============================================================================

  @doc """
  Notion database integration for content planning and tracking.
  """
  def sync_notion_content_database(campaign_id, notion_database_id) do
    # Example integration with Notion API
    notion_pages = fetch_notion_pages(notion_database_id)

    Enum.each(notion_pages, fn page ->
      if should_sync_page?(page) do
        contribution_data = extract_contribution_from_notion_page(page)

        # Send to Frestyl API
        sync_contribution_to_frestyl(campaign_id, contribution_data)
      end
    end)
  end

  defp fetch_notion_pages(database_id) do
    # Mock Notion API call
    [
      %{
        "id" => "page_1",
        "properties" => %{
          "Title" => %{"title" => [%{"text" => %{"content" => "Chapter 1: Introduction"}}]},
          "Word Count" => %{"number" => 1500},
          "Status" => %{"select" => %{"name" => "Complete"}},
          "Author" => %{"people" => [%{"name" => "John Doe"}]}
        },
        "last_edited_time" => "2024-01-15T10:00:00.000Z"
      }
    ]
  end

  defp should_sync_page?(page) do
    # Only sync completed pages that haven't been synced recently
    status = get_in(page, ["properties", "Status", "select", "name"])
    last_edited = page["last_edited_time"]

    status == "Complete" and recently_edited?(last_edited)
  end

  defp recently_edited?(last_edited_time) do
    {:ok, datetime, _} = DateTime.from_iso8601(last_edited_time)
    DateTime.diff(DateTime.utc_now(), datetime, :hour) < 24
  end

  defp extract_contribution_from_notion_page(page) do
    title = get_in(page, ["properties", "Title", "title", Access.at(0), "text", "content"])
    word_count = get_in(page, ["properties", "Word Count", "number"])

    %{
      "type" => "content",
      "data" => %{
        "title" => title,
        "word_count" => word_count,
        "content" => "Content extracted from Notion page",
        "source" => "notion",
        "page_id" => page["id"]
      }
    }
  end

  defp sync_contribution_to_frestyl(campaign_id, contribution_data) do
    # HTTP request to Frestyl API
    api_url = "https://frestyl.com/api/campaigns/#{campaign_id}/contributions"
    headers = [{"Authorization", "Bearer #{get_api_token()}"}, {"Content-Type", "application/json"}]
    body = Jason.encode!(%{"contribution" => contribution_data})

    case HTTPoison.post(api_url, body, headers) do
      {:ok, %{status_code: 201}} ->
        IO.puts("✅ Synced contribution to Frestyl")
      {:error, reason} ->
        IO.puts("❌ Failed to sync: #{inspect(reason)}")
    end
  end

  # ============================================================================
  # GOOGLE DOCS INTEGRATION EXAMPLE
  # ============================================================================

  @doc """
  Google Docs integration for real-time collaborative writing.
  """
  def setup_google_docs_webhook(campaign_id, document_id) do
    # Setup webhook to receive Google Docs changes
    webhook_url = "https://frestyl.com/api/webhooks/campaign_update"

    google_docs_webhook_config = %{
      "document_id" => document_id,
      "webhook_url" => webhook_url,
      "events" => ["document.edit", "document.comment"],
      "campaign_id" => campaign_id
    }

    # Register webhook with Google Docs API
    register_google_docs_webhook(google_docs_webhook_config)
  end

  def process_google_docs_webhook(webhook_data) do
    campaign_id = webhook_data["campaign_id"]
    document_changes = webhook_data["changes"]

    contribution_data = %{
      "type" => "content",
      "data" => %{
        "content_changes" => document_changes,
        "word_count_delta" => calculate_word_count_delta(document_changes),
        "source" => "google_docs",
        "document_id" => webhook_data["document_id"]
      }
    }

    # Send to Frestyl webhook endpoint
    sync_contribution_to_frestyl(campaign_id, contribution_data)
  end

  defp register_google_docs_webhook(config) do
    # Mock Google Docs API webhook registration
    IO.puts("📝 Registered Google Docs webhook for document #{config["document_id"]}")
    {:ok, "webhook_registered"}
  end

  defp calculate_word_count_delta(changes) do
    # Calculate word count change from document edits
    added_text = changes["added_text"] || ""
    removed_text = changes["removed_text"] || ""

    added_words = String.split(added_text, ~r/\s+/, trim: true) |> length()
    removed_words = String.split(removed_text, ~r/\s+/, trim: true) |> length()

    added_words - removed_words
  end

  # ============================================================================
  # FIGMA INTEGRATION EXAMPLE
  # ============================================================================

  @doc """
  Figma integration for design collaboration tracking.
  """
  def sync_figma_design_contributions(campaign_id, figma_file_id) do
    # Fetch Figma file version history
    figma_versions = fetch_figma_versions(figma_file_id)

    Enum.each(figma_versions, fn version ->
      if version_has_significant_changes?(version) do
        contribution_data = extract_design_contribution(version)
        sync_contribution_to_frestyl(campaign_id, contribution_data)
      end
    end)
  end

  defp fetch_figma_versions(file_id) do
    # Mock Figma API call
    [
      %{
        "id" => "version_1",
        "created_at" => "2024-01-15T14:30:00.000Z",
        "user" => %{"name" => "Jane Designer"},
        "changes" => %{
          "components_added" => 3,
          "frames_modified" => 5,
          "changes_description" => "Added new component library and updated color scheme"
        }
      }
    ]
  end

  defp version_has_significant_changes?(version) do
    changes = version["changes"]

    (changes["components_added"] || 0) > 0 or
    (changes["frames_modified"] || 0) > 2
  end

  defp extract_design_contribution(version) do
    %{
      "type" => "design",
      "data" => %{
        "design_changes" => version["changes"],
        "contribution_score" => calculate_design_contribution_score(version["changes"]),
        "source" => "figma",
        "version_id" => version["id"]
      }
    }
  end

  defp calculate_design_contribution_score(changes) do
    # Score based on design contribution complexity
    base_score = 10
    component_bonus = (changes["components_added"] || 0) * 5
    frame_bonus = (changes["frames_modified"] || 0) * 2

    base_score + component_bonus + frame_bonus
  end

  # ============================================================================
  # DISCORD BOT INTEGRATION EXAMPLE
  # ============================================================================

  @doc """
  Discord bot integration for community collaboration.
  """
  def setup_discord_campaign_bot(campaign_id, discord_guild_id) do
    # Setup Discord bot commands for campaign interaction
    bot_commands = [
      %{
        "name" => "campaign_status",
        "description" => "Get current campaign status and your contribution metrics"
      },
      %{
        "name" => "submit_contribution",
        "description" => "Submit a new contribution to the campaign"
      },
      %{
        "name" => "review_request",
        "description" => "Request peer review for your contribution"
      }
    ]

    register_discord_bot_commands(discord_guild_id, bot_commands, campaign_id)
  end

  def handle_discord_command("campaign_status", user_id, campaign_id) do
    # Fetch user's campaign metrics from Frestyl API
    api_url = "https://frestyl.com/api/campaigns/#{campaign_id}/metrics"
    headers = [{"Authorization", "Bearer #{get_api_token()}"}]

    case HTTPoison.get(api_url, headers) do
      {:ok, %{status_code: 200, body: body}} ->
        metrics = Jason.decode!(body)
        format_discord_status_response(metrics)

      {:error, _} ->
        "❌ Unable to fetch campaign status. Please try again later."
    end
  end

  def handle_discord_command("submit_contribution", user_id, campaign_id, contribution_text) do
    contribution_data = %{
      "type" => "content",
      "data" => %{
        "content" => contribution_text,
        "word_count" => String.split(contribution_text, ~r/\s+/, trim: true) |> length(),
        "source" => "discord",
        "user_id" => user_id
      }
    }

    case sync_contribution_to_frestyl(campaign_id, contribution_data) do
      :ok ->
        "✅ Contribution submitted successfully! Your metrics have been updated."

      :error ->
        "❌ Failed to submit contribution. Please check your input and try again."
    end
  end

  defp register_discord_bot_commands(guild_id, commands, campaign_id) do
    # Mock Discord bot registration
    IO.puts("🤖 Registered Discord bot commands for guild #{guild_id}, campaign #{campaign_id}")
    {:ok, "commands_registered"}
  end

  defp format_discord_status_response(metrics) do
    user_metrics = metrics["metrics"]["user_metrics"]

    """
    📊 **Campaign Status**

    🎯 Your Revenue Share: **#{user_metrics["revenue_percentage"]}%**
    ⭐ Quality Gates Passed: **#{user_metrics["quality_gates_passed"]}**
    📈 Contribution Score: **#{user_metrics["contribution_score"]}**

    💡 *Keep contributing to increase your revenue share!*
    """
  end

  # ============================================================================
  # ZAPIER INTEGRATION EXAMPLE
  # ============================================================================

  @doc """
  Zapier webhook integration for connecting various tools.
  """
  def setup_zapier_integration(campaign_id, zapier_webhook_url) do
    # Configure Zapier webhook to receive Frestyl campaign events
    integration_config = %{
      "campaign_id" => campaign_id,
      "webhook_url" => zapier_webhook_url,
      "events" => [
        "contribution_added",
        "quality_gate_passed",
        "quality_gate_failed",
        "revenue_updated",
        "payment_processed"
      ]
    }

    register_zapier_webhook(integration_config)
  end

  def send_zapier_event(event_type, campaign_id, event_data) do
    case get_zapier_webhook_url(campaign_id) do
      {:ok, webhook_url} ->
        payload = %{
          "event" => event_type,
          "campaign_id" => campaign_id,
          "timestamp" => DateTime.utc_now(),
          "data" => event_data
        }

        send_webhook(webhook_url, payload)

      {:error, :not_configured} ->
        # No Zapier integration configured for this campaign
        :ok
    end
  end

  defp register_zapier_webhook(config) do
    # Store webhook configuration
    :ets.insert(:zapier_webhooks, {config["campaign_id"], config["webhook_url"]})
    IO.puts("⚡ Registered Zapier webhook for campaign #{config["campaign_id"]}")
  end

  defp get_zapier_webhook_url(campaign_id) do
    case :ets.lookup(:zapier_webhooks, campaign_id) do
      [{^campaign_id, webhook_url}] -> {:ok, webhook_url}
      [] -> {:error, :not_configured}
    end
  end

  defp send_webhook(url, payload) do
    headers = [{"Content-Type", "application/json"}]
    body = Jason.encode!(payload)

    HTTPoison.post(url, body, headers)
  end

  # ============================================================================
  # UTILITY FUNCTIONS
  # ============================================================================

  defp get_api_token do
    # Get API token from environment or configuration
    System.get_env("FRESTYL_API_TOKEN") || "demo_token_123"
  end
end
