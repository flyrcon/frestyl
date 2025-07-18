defmodule Frestyl.Calendar.Integration do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "calendar_integrations" do
    field :provider, :string
    field :provider_account_id, :string
    field :calendar_id, :string
    field :calendar_name, :string
    field :access_token, :string
    field :refresh_token, :string
    field :token_expires_at, :utc_datetime
    field :is_primary, :boolean, default: false
    field :sync_enabled, :boolean, default: true
    field :sync_direction, :string, default: "bidirectional"
    field :last_synced_at, :utc_datetime
    field :sync_errors, {:array, :string}, default: []
    field :settings, :map, default: %{}

    field :user_id, :integer
    field :account_id, :integer

    # Manual associations
    belongs_to :user, Frestyl.Accounts.User, foreign_key: :user_id, references: :id, define_field: false
    belongs_to :account, Frestyl.Accounts.Account, foreign_key: :account_id, references: :id, define_field: false

    timestamps()
  end

  def changeset(integration, attrs) do
    integration
    |> cast(attrs, [
      :provider, :provider_account_id, :calendar_id, :calendar_name,
      :access_token, :refresh_token, :token_expires_at, :is_primary,
      :sync_enabled, :sync_direction, :settings, :user_id, :account_id
    ])
    |> validate_required([:provider, :provider_account_id, :calendar_id])
    |> validate_inclusion(:provider, ["google", "outlook", "apple", "caldav"])
    |> validate_inclusion(:sync_direction, ["import_only", "export_only", "bidirectional"])
    |> unique_constraint([:user_id, :provider, :calendar_id])
  end
end
