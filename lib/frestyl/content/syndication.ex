# lib/frestyl/content/syndication.ex
defmodule Frestyl.Content.Syndication do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "content_syndications" do
    field :platform, :string
    field :external_url, :string
    field :external_id, :string
    field :syndication_status, :string, default: "pending"
    field :platform_metrics, :map, default: %{}
    field :revenue_attribution, :decimal
    field :collaboration_revenue_splits, :map, default: %{}
    field :syndicated_at, :utc_datetime
    field :last_metrics_update, :utc_datetime
    field :syndication_config, :map, default: %{}

    belongs_to :document, Frestyl.Content.Document, type: :binary_id  # documents uses UUID
    belongs_to :account, Frestyl.Accounts.Account, type: :id  # accounts uses bigint

    timestamps()
  end

  def changeset(syndication, attrs) do
    syndication
    |> cast(attrs, [
      :platform, :external_url, :external_id, :syndication_status,
      :platform_metrics, :revenue_attribution, :collaboration_revenue_splits,
      :syndicated_at, :last_metrics_update, :syndication_config,
      :document_id, :account_id
    ])
    |> validate_required([:platform, :document_id, :account_id])
    |> validate_inclusion(:syndication_status, ["pending", "published", "failed", "updated"])
    |> validate_inclusion(:platform, ["medium", "linkedin", "hashnode", "dev_to", "ghost", "wordpress", "custom"])
    |> unique_constraint([:document_id, :platform])
  end
end
