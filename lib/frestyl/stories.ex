# lib/frestyl/stories.ex
defmodule Frestyl.Stories do
  import Ecto.Query
  alias Frestyl.{Repo, Stories, Accounts}
  alias Frestyl.Stories.Collaboration

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
