# lib/frestyl/portfolios/social_integration.ex
defmodule Frestyl.Portfolios.SocialIntegration do
  use Ecto.Schema
  import Ecto.Changeset

  schema "social_integrations" do
    field :platform, Ecto.Enum, values: [:linkedin, :twitter, :instagram, :github, :tiktok]
    field :platform_user_id, :string
    field :username, :string
    field :display_name, :string
    field :profile_url, :string
    field :avatar_url, :string
    field :follower_count, :integer
    field :bio, :string
    field :verified, :boolean, default: false

    # OAuth tokens (encrypted)
    field :access_token, :string, redact: true
    field :refresh_token, :string, redact: true
    field :token_expires_at, :utc_datetime

    # Sync settings
    field :auto_sync_enabled, :boolean, default: true
    field :last_sync_at, :utc_datetime
    field :sync_frequency, Ecto.Enum, values: [:hourly, :daily, :weekly, :manual], default: :daily
    field :sync_status, Ecto.Enum, values: [:active, :error, :disabled], default: :active
    field :last_error, :string

    # Content settings
    field :show_recent_posts, :boolean, default: true
    field :max_posts, :integer, default: 3
    field :show_follower_count, :boolean, default: true
    field :show_bio, :boolean, default: true

    # Privacy settings
    field :public_visibility, :boolean, default: true

    belongs_to :portfolio, Frestyl.Portfolios.Portfolio
    belongs_to :user, Frestyl.Accounts.User
    has_many :social_posts, Frestyl.Portfolios.SocialPost, on_delete: :delete_all

    timestamps()
  end

  def changeset(social_integration, attrs) do
    social_integration
    |> cast(attrs, [
      :platform, :platform_user_id, :username, :display_name, :profile_url,
      :avatar_url, :follower_count, :bio, :verified, :access_token, :refresh_token,
      :token_expires_at, :auto_sync_enabled, :last_sync_at, :sync_frequency,
      :sync_status, :last_error, :show_recent_posts, :max_posts, :show_follower_count,
      :show_bio, :public_visibility, :portfolio_id, :user_id
    ])
    |> validate_required([:platform, :username, :profile_url, :portfolio_id, :user_id])
    |> validate_length(:username, min: 1, max: 50)
    |> validate_length(:display_name, max: 100)
    |> validate_format(:profile_url, ~r/^https?:\/\/.+/, message: "must be a valid URL")
    |> validate_number(:follower_count, greater_than_or_equal_to: 0)
    |> validate_number(:max_posts, greater_than: 0, less_than_or_equal_to: 10)
    |> unique_constraint([:portfolio_id, :platform])
    |> foreign_key_constraint(:portfolio_id)
    |> foreign_key_constraint(:user_id)
  end

  def sync_changeset(social_integration, attrs) do
    social_integration
    |> cast(attrs, [
      :platform_user_id, :display_name, :avatar_url, :follower_count,
      :bio, :verified, :last_sync_at, :sync_status, :last_error
    ])
    |> validate_number(:follower_count, greater_than_or_equal_to: 0)
  end
end
