# lib/frestyl/content/collaboration_campaign.ex
defmodule Frestyl.Content.CollaborationCampaign do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "collaboration_campaigns" do
    field :title, :string
    field :description, :string
    field :campaign_type, :string, default: "content_writing"
    field :status, :string, default: "open"
    field :max_contributors, :integer, default: 5
    field :contribution_rules, :map, default: %{}
    field :revenue_split_config, :map, default: %{}
    field :target_platforms, {:array, :string}, default: []
    field :deadline, :utc_datetime
    field :campaign_metadata, :map, default: %{}

    belongs_to :account, Frestyl.Accounts.Account, type: :binary_id
    has_many :contributors, Frestyl.Content.CampaignContributor, foreign_key: :campaign_id
    has_many :documents, Frestyl.Content.Document, foreign_key: :collaboration_campaign_id

    timestamps()
  end

  def changeset(campaign, attrs) do
    campaign
    |> cast(attrs, [
      :title, :description, :campaign_type, :status, :max_contributors,
      :contribution_rules, :revenue_split_config, :target_platforms,
      :deadline, :campaign_metadata, :account_id
    ])
    |> validate_required([:title, :account_id])
    |> validate_inclusion(:status, ["open", "active", "completed", "cancelled"])
    |> validate_inclusion(:campaign_type, ["content_writing", "research", "editing", "mixed"])
    |> validate_number(:max_contributors, greater_than: 0, less_than_or_equal_to: 50)
    |> validate_revenue_split_config()
    |> validate_target_platforms()
  end

  defp validate_revenue_split_config(changeset) do
    case get_field(changeset, :revenue_split_config) do
      %{"splits" => splits} when is_list(splits) ->
        total = Enum.sum(Enum.map(splits, fn %{"percentage" => p} -> p end))
        if total == 100.0 do
          changeset
        else
          add_error(changeset, :revenue_split_config, "Revenue splits must total 100%")
        end
      _ -> changeset
    end
  end

  defp validate_target_platforms(changeset) do
    valid_platforms = ["medium", "linkedin", "hashnode", "dev_to", "ghost", "wordpress", "custom"]

    case get_field(changeset, :target_platforms) do
      platforms when is_list(platforms) ->
        invalid_platforms = platforms -- valid_platforms
        if Enum.empty?(invalid_platforms) do
          changeset
        else
          add_error(changeset, :target_platforms, "Invalid platforms: #{Enum.join(invalid_platforms, ", ")}")
        end
      _ -> changeset
    end
  end
end
