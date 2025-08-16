# lib/frestyl/podcasts/show.ex
defmodule Frestyl.Podcasts.Show do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "podcast_guests" do
    field :name, :string
    field :email, :string
    field :bio, :string
    field :title, :string
    field :company, :string
    field :website_url, :string
    field :avatar_url, :string
    field :social_links, :map, default: %{} # {twitter, linkedin, etc}
    field :status, :string, default: "invited" # invited, confirmed, declined, attended, no_show
    field :role, :string, default: "guest" # guest, co_host, expert
    field :invitation_sent_at, :utc_datetime
    field :confirmed_at, :utc_datetime
    field :joined_at, :utc_datetime
    field :notes, :string
    field :technical_setup, :map, default: %{} # audio quality, equipment, etc

    belongs_to :episode, Frestyl.Podcasts.Episode
    belongs_to :invited_by, Frestyl.Accounts.User
    belongs_to :user, Frestyl.Accounts.User # if guest has an account

    timestamps()
  end

  def changeset(guest, attrs) do
    guest
    |> cast(attrs, [:name, :email, :bio, :title, :company, :website_url, :avatar_url,
                    :social_links, :status, :role, :invitation_sent_at, :confirmed_at,
                    :joined_at, :notes, :technical_setup, :episode_id, :invited_by, :user_id])
    |> validate_required([:name, :email, :episode_id, :invited_by])
    |> validate_email(:email)
    |> validate_length(:name, min: 1, max: 255)
    |> validate_length(:bio, max: 2000)
    |> validate_inclusion(:status, ~w(invited confirmed declined attended no_show))
    |> validate_inclusion(:role, ~w(guest co_host expert))
    |> validate_url(:website_url)
    |> validate_url(:avatar_url)
    |> unique_constraint([:episode_id, :email])
  end

  defp validate_email(changeset, field) do
    validate_format(changeset, field, ~r/^[^\s]+@[^\s]+$/, message: "must be a valid email")
  end

  defp validate_url(changeset, field) do
    validate_change(changeset, field, fn _, url ->
      case URI.parse(url) do
        %URI{scheme: scheme} when scheme in ~w(http https) -> []
        _ -> [{field, "must be a valid URL"}]
      end
    end)
  end
end
