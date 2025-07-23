# lib/frestyl/content/collaboration_tracker.ex
defmodule Frestyl.Content.CollaborationTracker do
  @moduledoc """
  Real-time collaboration tracking with contribution metrics
  """

  import Ecto.Query, warn: false  # ADD THIS LINE
  alias Frestyl.Repo  # ADD THIS LINE
  alias Frestyl.Content.{Document, CampaignContributor, ContributionSession, CollaborationCampaign, Syndication}
  alias Phoenix.PubSub

  @doc """
  Track writing contribution in real-time
  """
  def track_writing_contribution(document_id, user_id, content_changes) do
    with {:ok, session} <- get_or_create_session(document_id, user_id),
         {:ok, metrics} <- calculate_contribution_metrics(content_changes, session) do

      # Update session metrics
      updated_session = update_session_metrics(session, metrics)

      # Update document-level contribution tracking
      update_document_contribution_tracking(document_id, user_id, metrics)

      # Broadcast real-time updates
      PubSub.broadcast(
        Frestyl.PubSub,
        "content_collaboration:#{document_id}",
        {:contribution_updated, user_id, metrics}
      )

      # Update revenue splits if needed
      maybe_recalculate_revenue_splits(document_id)

      {:ok, updated_session}
    end
  end

  @doc """
  Get contribution summary for a document
  """
  def get_contribution_summary(document_id) do
    # Fix the query syntax
    sessions = from(s in ContributionSession,
      where: s.document_id == ^document_id and not is_nil(s.session_end),
      preload: [:user]
    ) |> Frestyl.Repo.all()

    total_words = Enum.sum(Enum.map(sessions, & &1.words_contributed))
    total_edits = Enum.sum(Enum.map(sessions, & &1.edits_count))

    contributors = Enum.map(sessions, fn session ->
      %{
        user: session.user,
        words_contributed: session.words_contributed,
        edits_count: session.edits_count,
        contribution_percentage: if(total_words > 0, do: session.words_contributed / total_words * 100, else: 0),
        sections_edited: session.sections_edited,
        time_spent: calculate_time_spent(session)
      }
    end)
    |> Enum.group_by(& &1.user.id)
    |> Enum.map(fn {_user_id, user_sessions} ->
      consolidate_user_contributions(user_sessions)
    end)

    %{
      total_words: total_words,
      total_edits: total_edits,
      contributors: contributors,
      collaboration_score: calculate_collaboration_score(contributors)
    }
  end

  defp get_or_create_session(document_id, user_id) do
    case Frestyl.Repo.get_by(ContributionSession,
           document_id: document_id,
           user_id: user_id,
           session_end: nil) do
      nil ->
        %ContributionSession{
          document_id: document_id,
          user_id: user_id,
          session_start: DateTime.utc_now()
        }
        |> Frestyl.Repo.insert()

      session -> {:ok, session}
    end
  end

  defp calculate_contribution_metrics(content_changes, session) do
    words_added = count_words_added(content_changes)
    sections_modified = extract_sections_modified(content_changes)

    metrics = %{
      words_contributed: words_added,
      edits_count: 1,
      sections_edited: sections_modified,
      timestamp: DateTime.utc_now()
    }

    {:ok, metrics}
  end

  defp update_session_metrics(session, metrics) do
    updated_attrs = %{
      words_contributed: session.words_contributed + metrics.words_contributed,
      edits_count: session.edits_count + metrics.edits_count,
      sections_edited: Enum.uniq(session.sections_edited ++ metrics.sections_edited)
    }

    ContributionSession.changeset(session, updated_attrs)
    |> Frestyl.Repo.update!()
  end

  defp update_document_contribution_tracking(document_id, user_id, metrics) do
    document = Frestyl.Repo.get!(Document, document_id)

    current_tracking = document.contribution_tracking || %{}
    user_contributions = Map.get(current_tracking, to_string(user_id), %{
      "total_words" => 0,
      "total_edits" => 0,
      "sections" => []
    })

    updated_tracking = Map.put(current_tracking, to_string(user_id), %{
      "total_words" => user_contributions["total_words"] + metrics.words_contributed,
      "total_edits" => user_contributions["total_edits"] + metrics.edits_count,
      "sections" => Enum.uniq(user_contributions["sections"] ++ metrics.sections_edited),
      "last_contribution" => DateTime.utc_now()
    })

    Document.changeset(document, %{contribution_tracking: updated_tracking})
    |> Frestyl.Repo.update!()
  end

  defp maybe_recalculate_revenue_splits(document_id) do
    # If document is part of a campaign with dynamic revenue splits,
    # recalculate based on current contributions
    case get_campaign_for_document(document_id) do
      nil -> :ok
      campaign ->
        if campaign.revenue_split_config["type"] == "dynamic" do
          recalculate_dynamic_splits(document_id, campaign)
        end
    end
  end

  defp count_words_added(%{"operations" => operations}) do
    operations
    |> Enum.filter(fn op -> op["type"] == "insert" end)
    |> Enum.map(fn op -> String.split(op["text"] || "", ~r/\s+/) |> length() end)
    |> Enum.sum()
  end

  defp extract_sections_modified(%{"operations" => operations}) do
    operations
    |> Enum.map(fn op -> op["section_id"] end)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp calculate_time_spent(session) do
    case {session.session_start, session.session_end} do
      {start, finish} when not is_nil(start) and not is_nil(finish) ->
        DateTime.diff(finish, start, :minute)
      _ -> 0
    end
  end

  defp consolidate_user_contributions(user_sessions) do
    first_session = List.first(user_sessions)

    %{
      user: first_session.user,
      words_contributed: Enum.sum(Enum.map(user_sessions, & &1.words_contributed)),
      edits_count: Enum.sum(Enum.map(user_sessions, & &1.edits_count)),
      contribution_percentage: Enum.sum(Enum.map(user_sessions, & &1.contribution_percentage)),
      sections_edited: user_sessions |> Enum.flat_map(& &1.sections_edited) |> Enum.uniq(),
      time_spent: Enum.sum(Enum.map(user_sessions, & &1.time_spent))
    }
  end

  defp calculate_collaboration_score(contributors) do
    case length(contributors) do
      0 -> 0
      count ->
        # Simple scoring: base score + engagement bonus
        base_score = min(count * 20, 80)
        engagement_bonus = contributors
        |> Enum.map(& &1.edits_count)
        |> Enum.sum()
        |> min(20)

        base_score + engagement_bonus
    end
  end

  defp get_campaign_for_document(document_id) do
    from(d in Document,
      where: d.id == ^document_id,
      preload: [:collaboration_campaign]
    )
    |> Repo.one()
    |> case do
      %{collaboration_campaign: campaign} when not is_nil(campaign) -> campaign
      _ -> nil
    end
  end

  defp recalculate_dynamic_splits(document_id, campaign) do
    # Get contribution summary
    summary = get_contribution_summary(document_id)

    # Calculate new splits based on contribution percentages
    new_splits = summary.contributors
    |> Enum.map(fn contributor ->
      {to_string(contributor.user.id), %{
        "percentage" => contributor.contribution_percentage,
        "words_contributed" => contributor.words_contributed,
        "last_updated" => DateTime.utc_now()
      }}
    end)
    |> Map.new()

    # Update campaign with new revenue splits
    updated_config = Map.put(campaign.revenue_split_config, "current_splits", new_splits)

    from(c in CollaborationCampaign,
      where: c.id == ^campaign.id
    )
    |> Repo.update_all(set: [revenue_split_config: updated_config])

    # Update all syndications for this document
    from(s in Syndication,
      where: s.document_id == ^document_id
    )
    |> Repo.update_all(set: [collaboration_revenue_splits: new_splits])

    :ok
  end

end
