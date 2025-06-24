defmodule Frestyl.Stories.Collaboration do
  use Ecto.Schema           # Provides schema/2 macro
  import Ecto.Changeset
  alias Frestyl.Accounts.Account

  schema "story_collaborations" do
    belongs_to :story, Frestyl.Portfolios.Portfolio, foreign_key: :story_id
    belongs_to :collaborator_user, Frestyl.Accounts.User
    belongs_to :collaborator_account, Frestyl.Accounts.Account
    belongs_to :invited_by, Frestyl.Accounts.User

    field :role, Ecto.Enum, values: [:viewer, :commenter, :editor, :co_author]
    field :permissions, :map, default: %{}
    field :access_level, Ecto.Enum, values: [:guest, :account_member, :cross_account]
    field :billing_context, Ecto.Enum, values: [:host_pays, :guest_pays, :shared]

    field :invitation_token, :string
    field :invitation_email, :string
     field :status, Ecto.Enum, values: [:pending, :accepted, :declined, :revoked], default: :pending
    field :expires_at, :utc_datetime
    field :accepted_at, :utc_datetime
    field :last_active_at, :utc_datetime

    timestamps()
  end

  def collaboration_permissions(host_tier, guest_tier, role) do
    base_permissions = base_permissions_for_role(role)

    # Adjust based on subscription compatibility
    case {host_tier, guest_tier} do
      {:enterprise, _} ->
        # Enterprise hosts can collaborate with anyone at full capacity
        base_permissions

      {:professional, guest_tier} when guest_tier in [:professional, :enterprise] ->
        # Professional-to-professional collaboration gets full features
        base_permissions

      {:professional, guest_tier} when guest_tier in [:personal, :creator] ->
        # Professional hosting lower-tier guests: limited features
        limit_guest_features(base_permissions)

      {:creator, :creator} ->
        # Creator-to-creator: standard collaboration
        base_permissions

      {:creator, guest_tier} when guest_tier in [:personal] ->
        # Creator hosting personal: very limited
        basic_collaboration_only(base_permissions)

      {:personal, _} ->
        # Personal accounts can only do basic sharing
        view_only_permissions()
    end
  end

   # ============================================================================
  # Permission Helper Functions
  # ============================================================================

  def base_permissions_for_role(role) do
    case role do
      :viewer ->
        %{
          can_view: true,
          can_comment: false,
          can_edit: false,
          can_delete: false,
          can_invite: false,
          can_manage_permissions: false,
          can_export: false,
          can_view_analytics: false,
          can_edit_metadata: false,
          can_create_chapters: false
        }

      :commenter ->
        %{
          can_view: true,
          can_comment: true,
          can_edit: false,
          can_delete: false,
          can_invite: false,
          can_manage_permissions: false,
          can_export: false,
          can_view_analytics: false,
          can_edit_metadata: false,
          can_create_chapters: false
        }

      :editor ->
        %{
          can_view: true,
          can_comment: true,
          can_edit: true,
          can_delete: false,
          can_invite: false,
          can_manage_permissions: false,
          can_export: true,
          can_view_analytics: false,
          can_edit_metadata: false,
          can_create_chapters: true
        }

      :co_author ->
        %{
          can_view: true,
          can_comment: true,
          can_edit: true,
          can_delete: true,
          can_invite: true,
          can_manage_permissions: false,
          can_export: true,
          can_view_analytics: true,
          can_edit_metadata: true,
          can_create_chapters: true
        }

      _ ->
        view_only_permissions()
    end
  end

  def limit_guest_features(base_permissions) do
    # Limit features for guests from lower-tier accounts
    base_permissions
    |> Map.put(:can_export, false)
    |> Map.put(:can_view_analytics, false)
    |> Map.put(:can_invite, false)
    |> Map.put(:can_delete, false)
    |> Map.put(:can_edit_metadata, false)
  end

  def basic_collaboration_only(base_permissions) do
    # Very basic collaboration - mostly view and comment
    base_permissions
    |> Map.put(:can_edit, false)
    |> Map.put(:can_delete, false)
    |> Map.put(:can_invite, false)
    |> Map.put(:can_export, false)
    |> Map.put(:can_view_analytics, false)
    |> Map.put(:can_edit_metadata, false)
    |> Map.put(:can_create_chapters, false)
  end

  def view_only_permissions do
    %{
      can_view: true,
      can_comment: false,
      can_edit: false,
      can_delete: false,
      can_invite: false,
      can_manage_permissions: false,
      can_export: false,
      can_view_analytics: false,
      can_edit_metadata: false,
      can_create_chapters: false
    }
  end

  # ============================================================================
  # Changeset Functions
  # ============================================================================

  def changeset(collaboration, attrs) do
    collaboration
    |> cast(attrs, [
      :story_id, :collaborator_user_id, :collaborator_account_id, :invited_by_id,
      :role, :permissions, :access_level, :billing_context,
      :invitation_token, :expires_at, :accepted_at, :last_active_at
    ])
    |> validate_required([:story_id, :collaborator_user_id, :role])
    |> validate_inclusion(:role, [:viewer, :commenter, :editor, :co_author])
    |> validate_inclusion(:access_level, [:guest, :account_member, :cross_account])
    |> validate_inclusion(:billing_context, [:host_pays, :guest_pays, :shared])
    |> unique_constraint([:story_id, :collaborator_user_id])
    |> foreign_key_constraint(:story_id)
    |> foreign_key_constraint(:collaborator_user_id)
    |> foreign_key_constraint(:collaborator_account_id)
    |> foreign_key_constraint(:invited_by_id)
  end

  def invitation_changeset(collaboration, attrs) do
    collaboration
    |> cast(attrs, [
      :story_id, :collaborator_user_id, :collaborator_account_id, :invited_by_user_id,
      :role, :permissions, :access_level, :billing_context,
      :invitation_token, :invitation_email, :expires_at
    ])
    |> validate_required([:story_id, :invited_by_user_id, :role])
    |> validate_inclusion(:role, [:viewer, :commenter, :editor, :co_author])
    |> unique_constraint([:story_id, :collaborator_user_id],
                        name: :idx_story_collaborations_unique)
    |> put_token()
    |> put_expiry()
  end

  def accept_invitation_changeset(collaboration, attrs \\ %{}) do
    collaboration
    |> changeset(attrs)
    |> put_change(:accepted_at, DateTime.utc_now())
    |> put_change(:last_active_at, DateTime.utc_now())
    |> put_change(:invitation_token, nil)
  end

  defp put_token(changeset) do
    case changeset do
      %Ecto.Changeset{valid?: true} ->
        put_change(changeset, :invitation_token, generate_token())
      _ ->
        changeset
    end
  end

  defp put_expiry(changeset) do
    case changeset do
      %Ecto.Changeset{valid?: true} ->
        expires_at = DateTime.utc_now() |> DateTime.add(7, :day)
        put_change(changeset, :expires_at, expires_at)
      _ ->
        changeset
    end
  end

  defp generate_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64() |> binary_part(0, 32)
  end

  # ============================================================================
  # Utility Functions
  # ============================================================================

  def generate_invitation_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end

  def expired?(collaboration) do
    case collaboration.expires_at do
      nil -> false
      expires_at -> DateTime.compare(DateTime.utc_now(), expires_at) == :gt
    end
  end

  def accepted?(collaboration) do
    not is_nil(collaboration.accepted_at)
  end

  def can_perform_action?(collaboration, action) do
    permissions = collaboration.permissions || %{}
    Map.get(permissions, action, false)
  end

  def update_last_active(collaboration) do
    collaboration
    |> changeset(%{last_active_at: DateTime.utc_now()})
  end

  # ============================================================================
  # Permission Checking Functions
  # ============================================================================

  def has_permission?(collaboration, permission_key) do
    permissions = collaboration.permissions || %{}
    Map.get(permissions, permission_key, false)
  end

  def can_edit_story?(collaboration) do
    has_permission?(collaboration, :can_edit)
  end

  def can_delete_content?(collaboration) do
    has_permission?(collaboration, :can_delete)
  end

  def can_invite_others?(collaboration) do
    has_permission?(collaboration, :can_invite)
  end

  def can_export_story?(collaboration) do
    has_permission?(collaboration, :can_export)
  end

  def can_view_analytics?(collaboration) do
    has_permission?(collaboration, :can_view_analytics)
  end
end
