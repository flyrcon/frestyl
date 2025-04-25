# lib/frestyl/accounts/user.ex
defmodule Frestyl.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  # Keep existing fields and changesets from phx.gen.auth...

  schema "users" do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :confirmed_at, :naive_datetime
    field :status, :string, default: "offline"

    # New fields
    field :role, :string, default: "user"
    field :subscription_tier, :string, default: "free"
    field :full_name, :string
    field :bio, :string
    field :avatar_url, :string
    field :website, :string
    field :social_links, :map, default: %{}
    field :last_active_at, :utc_datetime

    timestamps()
  end

  # Add these new changesets in addition to existing ones

  def role_changeset(user, attrs) do
    user
    |> cast(attrs, [:role])
    |> validate_inclusion(:role, ["user", "creator", "host", "channel_owner", "admin"])
  end

  def subscription_changeset(user, attrs) do
    user
    |> cast(attrs, [:subscription_tier])
    |> validate_inclusion(:subscription_tier, ["free", "basic", "premium", "pro"])
  end

  def profile_changeset(user, attrs) do
    user
    |> cast(attrs, [:full_name, :bio, :avatar_url, :website, :social_links])
    |> validate_length(:full_name, max: 255)
    |> validate_length(:bio, max: 2000)
    |> validate_length(:avatar_url, max: 1000)
    |> validate_length(:website, max: 255)
    |> validate_website_format(:website)
  end

  def activity_changeset(user, attrs) do
    user
    |> cast(attrs, [:last_active_at])
  end

  def status_changeset(user, attrs) do
    user
    |> cast(attrs, [:status])
    |> validate_inclusion(:status, ["online", "away", "busy", "offline"])
  end

  defp validate_website_format(changeset, field) do
    validate_change(changeset, field, fn _, website ->
      if is_nil(website) do
        []
      else
        uri = URI.parse(website)
        if uri.scheme in ["http", "https"] && uri.host && String.contains?(uri.host, ".") do
          []
        else
          [{field, "must be a valid URL with http/https protocol"}]
        end
      end
    end)
  end
end
