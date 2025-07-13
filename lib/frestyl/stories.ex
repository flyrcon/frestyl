# lib/frestyl/stories.ex
defmodule Frestyl.Stories do
  import Ecto.Query, warn: false
  alias Frestyl.{Repo, Accounts}
  alias Frestyl.Stories.{Chapter, Collaboration, ContentBlock, Story, StoryLabUsage}
  alias Frestyl.Features.TierManager

  def invite_collaborator(story, inviting_user, invitee_email, role, permissions \\ %{}) do
    host_account = get_story_account(story)

    # Check if inviting user has permission to invite
    cond do
      not can_invite_collaborators?(inviting_user, story) ->
        {:error, :unauthorized}

      not Frestyl.Features.FeatureGate.can_access_feature?(host_account, {:collaborator_invite, 1}) ->
        {:error, :collaborator_limit_reached}

      true ->
        # Find invitee user if they exist
        invitee_user = Accounts.get_user_by_email(invitee_email)
        invitee_account = if invitee_user, do: Accounts.get_user_primary_account(invitee_user)

        # Determine collaboration permissions based on tiers
        collaboration_permissions = determine_collaboration_permissions(
          host_account,
          invitee_account,
          role,
          permissions
        )

        collaboration_attrs = %{
          story_id: story.id,
          collaborator_user_id: invitee_user && invitee_user.id,
          collaborator_account_id: invitee_account && invitee_account.id,
          invited_by_user_id: inviting_user.id,
          invitation_email: invitee_email,
          role: role,
          permissions: collaboration_permissions.permissions,
          access_level: collaboration_permissions.access_level,
          billing_context: collaboration_permissions.billing_context
        }

        case create_collaboration_invitation(collaboration_attrs) do
          {:ok, collaboration} ->
            # Send invitation email
            send_collaboration_invitation_email(collaboration, story, inviting_user)

            # Track usage
            Frestyl.Billing.UsageTracker.track_collaboration_invitation(host_account, collaboration)

            {:ok, collaboration}

          error ->
            error
        end
    end
  end

  def accept_collaboration_invitation(token) do
    case get_valid_invitation(token) do
      nil ->
        {:error, :invalid_or_expired_invitation}

      collaboration ->
        changeset = Ecto.Changeset.change(collaboration, %{
          status: :accepted,
          accepted_at: DateTime.utc_now(),
          last_active_at: DateTime.utc_now()
        })

        case Repo.update(changeset) do
          {:ok, updated_collaboration} ->
            # Grant access to the story
            grant_story_access(updated_collaboration)

            {:ok, updated_collaboration}

          error ->
            error
        end
    end
  end

    def list_user_stories(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, -1)

    query = from s in Story,
      where: s.created_by_id == ^user_id,
      order_by: [desc: s.updated_at]

    query = if limit > 0, do: limit(query, ^limit), else: query

    Repo.all(query)
  end

  @doc """
  Creates a story from a template with tier checking
  """
    def create_story_from_template(user, account, template_id, attrs \\ %{}) do
      with {:ok, _} <- check_story_limits(user, account),
          {:ok, template} <- get_template(template_id),
          {:ok, _} <- check_template_access(account, template) do

        story_attrs = Map.merge(attrs, %{
          created_by_id: user.id,
          account_id: account.id,
          story_type: template.story_type,
          narrative_structure: template.narrative_structure
        })

        create_story_with_template(story_attrs, template)
      end
    end

  defp check_story_limits(user, account) do
    current_count = count_user_stories(user.id)
    limits = TierManager.get_tier_limits(account.subscription_tier)
    max_stories = Map.get(limits, :max_stories, 0)

    if max_stories == -1 or current_count < max_stories do
      {:ok, :within_limits}
    else
      {:error, :story_limit_exceeded}
    end
  end

  defp check_template_access(account, template) do
    if template.requires_tier do
      if TierManager.has_tier_access?(account.subscription_tier, template.requires_tier) do
        {:ok, :access_granted}
      else
        {:error, :insufficient_tier}
      end
    else
      {:ok, :access_granted}
    end
  end

  def count_user_stories(user_id) do
    from(s in Story, where: s.created_by_id == ^user_id)
    |> Repo.aggregate(:count)
  end

  @doc """
  Gets or creates story lab usage tracking
  """
  def get_story_lab_usage(user_id) do
    case Repo.get_by(Frestyl.Stories.StoryLabUsage, user_id: user_id) do
      nil ->
        %Frestyl.Stories.StoryLabUsage{
          user_id: user_id,
          stories_created: count_user_stories(user_id),
          chapters_created: count_user_chapters(user_id),
          recording_minutes_used: get_recording_minutes_used(user_id)
        }
      usage -> usage
    end
  end

  defp count_user_chapters(user_id) do
    from(c in Chapter,
      join: s in Story, on: c.story_id == s.id,
      where: s.created_by_id == ^user_id)
    |> Repo.aggregate(:count)
  end

  defp get_recording_minutes_used(user_id) do
    # This would calculate total recording time from audio files
    # associated with user's stories
    0  # Placeholder
  end

  @doc """
  Updates story lab usage when user creates content
  """
  def track_story_lab_usage(user_id, action, data \\ %{}) do
    usage = get_story_lab_usage(user_id)

    updated_usage = case action do
      :story_created ->
        %{usage |
          stories_created: usage.stories_created + 1,
          last_story_created_at: DateTime.utc_now()
        }
      :chapter_created ->
        %{usage | chapters_created: usage.chapters_created + 1}
      :recording_added ->
        minutes = Map.get(data, :minutes, 0)
        %{usage | recording_minutes_used: usage.recording_minutes_used + minutes}
    end

    Repo.insert_or_update(Frestyl.Stories.StoryLabUsage.changeset(updated_usage, %{}))
  end

  # Template management
  defp get_template("personal_journey") do
    {:ok, %{
      id: "personal_journey",
      name: "Personal Journey",
      story_type: :personal_narrative,
      narrative_structure: "chronological",
      requires_tier: nil,
      chapters: [
        %{title: "The Beginning", type: :intro, narrative_purpose: :hook},
        %{title: "The Journey", type: :content, narrative_purpose: :journey},
        %{title: "Where I Am Now", type: :conclusion, narrative_purpose: :resolution}
      ]
    }}
  end

  defp get_template("simple_portfolio") do
    {:ok, %{
      id: "simple_portfolio",
      name: "Story Portfolio",
      story_type: :professional_showcase,
      narrative_structure: "skills_first",
      requires_tier: nil,
      chapters: [
        %{title: "About Me", type: :intro, narrative_purpose: :context},
        %{title: "My Work", type: :content, narrative_purpose: :journey},
        %{title: "Let's Connect", type: :call_to_action, narrative_purpose: :call_to_action}
      ]
    }}
  end

  defp get_template("basic_lyrics") do
    {:ok, %{
      id: "basic_lyrics",
      name: "Lyrics & Audio",
      story_type: :creative_portfolio,
      narrative_structure: "artistic",
      requires_tier: nil,
      chapters: [
        %{title: "Verse 1", type: :content, narrative_purpose: :hook},
        %{title: "Chorus", type: :content, narrative_purpose: :journey},
        %{title: "Verse 2", type: :content, narrative_purpose: :journey}
      ]
    }}
  end

  defp get_template("hero_journey") do
    {:ok, %{
      id: "hero_journey",
      name: "Hero's Journey",
      story_type: :personal_narrative,
      narrative_structure: "hero_journey",
      requires_tier: "creator",
      chapters: [
        %{title: "The Call", type: :intro, narrative_purpose: :hook},
        %{title: "The Challenge", type: :content, narrative_purpose: :conflict},
        %{title: "The Journey", type: :content, narrative_purpose: :journey},
        %{title: "The Transformation", type: :conclusion, narrative_purpose: :resolution}
      ]
    }}
  end

  defp get_template(_), do: {:error, :template_not_found}

  defp create_story_with_template(story_attrs, template) do
    Repo.transaction(fn ->
      # Create the story
      story = %Story{}
      |> Story.changeset(story_attrs)
      |> Repo.insert!()

      # Create chapters from template
      template.chapters
      |> Enum.with_index()
      |> Enum.each(fn {chapter_template, index} ->
        %Chapter{}
        |> Chapter.changeset(%{
          story_id: story.id,
          title: chapter_template.title,
          chapter_type: chapter_template.type,
          narrative_purpose: chapter_template.narrative_purpose,
          position: index
        })
        |> Repo.insert!()
      end)

      story
    end)
  end

  def list_story_collaborators(story_id) do
    from(c in Collaboration,
      where: c.story_id == ^story_id and c.status == :accepted,
      preload: [:collaborator_user, :collaborator_account, :invited_by_user]
    )
    |> Repo.all()
  end

  def get_user_collaboration_for_story(user_id, story_id) do
    from(c in Collaboration,
      where: c.story_id == ^story_id and c.collaborator_user_id == ^user_id and c.status == :accepted
    )
    |> Repo.one()
  end

  defp determine_collaboration_permissions(host_account, guest_account, role, requested_permissions) do
    host_tier = host_account.subscription_tier
    guest_tier = guest_account && guest_account.subscription_tier || :personal

    base_permissions = get_base_permissions_for_role(role)

    # Adjust permissions based on subscription compatibility
    adjusted_permissions = case {host_tier, guest_tier} do
      {:enterprise, _} ->
        # Enterprise hosts can collaborate with anyone at full capacity
        base_permissions

      {:professional, guest_tier} when guest_tier in [:professional, :enterprise] ->
        # Professional-to-professional gets full features
        base_permissions

      {:professional, guest_tier} when guest_tier in [:personal, :creator] ->
        # Professional hosting lower-tier guests: some limitations
        limit_guest_features(base_permissions)

      {:creator, :creator} ->
        # Creator-to-creator: standard collaboration
        base_permissions

      {:creator, :personal} ->
        # Creator hosting personal: basic collaboration only
        basic_collaboration_only(base_permissions)

      {:personal, _} ->
        # Personal accounts can only do view-only sharing
        view_only_permissions()
    end

    # Determine billing and access level
    {billing_context, access_level} = determine_billing_and_access(host_tier, guest_tier)

    %{
      permissions: Map.merge(adjusted_permissions, requested_permissions),
      access_level: access_level,
      billing_context: billing_context
    }
  end

  defp get_base_permissions_for_role(:viewer) do
    %{
      can_view: true,
      can_comment: false,
      can_edit: false,
      can_invite_others: false,
      can_export: false,
      can_see_analytics: false
    }
  end

  defp get_base_permissions_for_role(:commenter) do
    %{
      can_view: true,
      can_comment: true,
      can_edit: false,
      can_invite_others: false,
      can_export: false,
      can_see_analytics: false
    }
  end

  defp get_base_permissions_for_role(:editor) do
    %{
      can_view: true,
      can_comment: true,
      can_edit: true,
      can_invite_others: false,
      can_export: true,
      can_see_analytics: false
    }
  end

  defp get_base_permissions_for_role(:co_author) do
    %{
      can_view: true,
      can_comment: true,
      can_edit: true,
      can_invite_others: true,
      can_export: true,
      can_see_analytics: true
    }
  end

  defp limit_guest_features(permissions) do
    permissions
    |> Map.put(:can_invite_others, false)
    |> Map.put(:can_see_analytics, false)
  end

  defp basic_collaboration_only(permissions) do
    permissions
    |> Map.put(:can_edit, false)
    |> Map.put(:can_invite_others, false)
    |> Map.put(:can_export, false)
    |> Map.put(:can_see_analytics, false)
  end

  defp view_only_permissions do
    %{
      can_view: true,
      can_comment: false,
      can_edit: false,
      can_invite_others: false,
      can_export: false,
      can_see_analytics: false
    }
  end

  defp determine_billing_and_access(host_tier, guest_tier) do
    case {host_tier, guest_tier} do
      {:enterprise, _} -> {:host_pays, :cross_account}
      {:professional, _} -> {:host_pays, :cross_account}
      {:creator, guest_tier} when guest_tier in [:creator, :professional, :enterprise] ->
        {:shared, :cross_account}
      {:creator, :personal} -> {:host_pays, :guest}
      {:personal, _} -> {:host_pays, :guest}
    end
  end

  defp can_invite_collaborators?(user, story) do
    # Check if user owns the story or has co-author permissions
    story.user_id == user.id ||
    (get_user_collaboration_for_story(user.id, story.id) |>
     case do
       %{permissions: %{"can_invite_others" => true}} -> true
       _ -> false
     end)
  end

  defp get_story_account(story) do
    Repo.preload(story, :account).account
  end

  defp create_collaboration_invitation(attrs) do
    %Collaboration{}
    |> Collaboration.invitation_changeset(attrs)
    |> Repo.insert()
  end

  defp get_valid_invitation(token) do
    now = DateTime.utc_now()

    from(c in Collaboration,
      where: c.invitation_token == ^token
        and c.status == :pending
        and c.expires_at > ^now
    )
    |> Repo.one()
  end

  defp send_collaboration_invitation_email(collaboration, story, inviting_user) do
    # This would integrate with your email system
    # For now, just log it
    IO.puts("Sending collaboration invitation for story '#{story.title}' to #{collaboration.invitation_email}")
  end

  defp grant_story_access(collaboration) do
    # This would update any necessary access controls
    # For now, the collaboration record itself grants access
    :ok
  end
end
