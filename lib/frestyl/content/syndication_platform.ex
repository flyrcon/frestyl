# lib/frestyl/content/syndication_platform.ex
defmodule Frestyl.Content.SyndicationPlatform do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "syndication_platforms" do
    field :api_credentials, :map, default: %{}
    field :platform_config, :map, default: %{}
    field :is_active, :boolean, default: true
    field :last_sync, :utc_datetime
    field :sync_status, :string, default: "ready"

    belongs_to :account, Frestyl.Accounts.Account, type: :id  # accounts uses bigint

    timestamps()
  end

  def changeset(platform, attrs) do
    platform
    |> cast(attrs, [
      :platform_name, :api_credentials, :platform_config,
      :is_active, :last_sync, :sync_status, :account_id
    ])
    |> validate_required([:platform_name, :account_id])
    |> validate_inclusion(:platform_name, ["medium", "linkedin", "hashnode", "dev_to", "ghost", "wordpress", "custom"])
    |> validate_inclusion(:sync_status, ["ready", "syncing", "error"])
    |> unique_constraint([:account_id, :platform_name])
  end
end
