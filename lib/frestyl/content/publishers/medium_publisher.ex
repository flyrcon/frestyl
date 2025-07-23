# lib/frestyl/content/publishers/medium_publisher.ex
defmodule Frestyl.Content.Publishers.MediumPublisher do
  @moduledoc """
  Medium.com API integration for content syndication
  """

  alias Frestyl.Content.{Document, Syndication}
  alias Frestyl.HTTP.MediumClient

  def publish(document, account) do
    with {:ok, credentials} <- get_medium_credentials(account),
         {:ok, formatted_content} <- format_for_medium(document),
         {:ok, response} <- MediumClient.create_post(credentials, formatted_content) do

      # Create syndication record
      syndication_attrs = %{
        document_id: document.id,
        account_id: account.id,
        platform: "medium",
        external_id: response["id"],
        external_url: response["url"],
        syndication_status: "published",
        syndicated_at: DateTime.utc_now(),
        platform_metrics: %{
          "initial_claps" => 0,
          "initial_responses" => 0
        }
      }

      case Syndication.changeset(%Syndication{}, syndication_attrs) |> Frestyl.Repo.insert() do
        {:ok, syndication} ->
          schedule_metrics_update(syndication)
          {:ok, syndication}
        error -> error
      end
    end
  end

  defp get_medium_credentials(account) do
    # Retrieve encrypted Medium API credentials
    {:ok, %{token: "medium_token"}}
  end

  defp format_for_medium(document) do
    # Convert Frestyl document format to Medium API format
    formatted = %{
      title: document.title,
      contentFormat: "html",
      content: render_document_html(document),
      tags: extract_tags(document),
      publishStatus: "public"
    }
    {:ok, formatted}
  end

  defp render_document_html(document) do
    # Convert document blocks to HTML
    document.blocks
    |> Enum.map(&render_block_to_html/1)
    |> Enum.join("\n")
  end

  defp render_block_to_html(%{block_type: :text, content_data: %{"text" => text}}) do
    "<p>#{text}</p>"
  end

  defp render_block_to_html(%{block_type: :image, content_data: %{"src" => src, "alt" => alt}}) do
    "<img src=\"#{src}\" alt=\"#{alt}\" />"
  end

  # Add more block type renderers...

  defp extract_tags(document) do
    # Extract tags from document metadata
    get_in(document.metadata, ["seo", "tags"]) || []
  end

  defp schedule_metrics_update(syndication) do
    # Schedule background job to fetch metrics from Medium
    # This would integrate with your job queue system
    :ok
  end
end

# Similar publishers for LinkedIn, Hashnode, etc.
