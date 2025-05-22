# lib/frestyl/portfolios/portfolio.ex
defmodule Frestyl.Portfolios.Portfolio do
  use Ecto.Schema
  import Ecto.Changeset

  schema "portfolios" do
    field :title, :string
    field :slug, :string
    field :description, :string
    field :visibility, Ecto.Enum, values: [:public, :private, :link_only], default: :link_only
    field :expires_at, :utc_datetime
    field :approval_required, :boolean, default: false
    field :theme, :string, default: "default"
    field :custom_css, :string

    # Relations
    belongs_to :user, Frestyl.Accounts.User
    has_many :portfolio_sections, Frestyl.Portfolios.PortfolioSection
    has_many :portfolio_media, Frestyl.Portfolios.PortfolioMedia
    has_many :portfolio_visits, Frestyl.Portfolios.PortfolioVisit
    has_many :portfolio_shares, Frestyl.Portfolios.PortfolioShare

    timestamps()
  end

  def changeset(portfolio, attrs) do
    portfolio
    |> cast(attrs, [:title, :slug, :description, :visibility, :expires_at,
                    :approval_required, :theme, :custom_css, :user_id])
    |> validate_required([:title, :user_id])
    |> validate_length(:title, min: 3, max: 100)
    |> validate_length(:description, max: 2000)
    |> validate_slug()
    |> unique_constraint([:slug, :user_id], message: "This URL is already taken for your account")
    |> unique_constraint(:slug, message: "This URL is already taken")
  end

  def get_portfolio_by_slug(slug) do
    case Repo.get_by(Portfolio, slug: slug) do
      nil -> {:error, :not_found}
      portfolio -> {:ok, portfolio}
    end
  end

  defp validate_slug(changeset) do
    case get_change(changeset, :slug) do
      nil ->
        # If no slug provided, generate one from title
        case get_change(changeset, :title) do
          nil -> changeset
          title -> put_change(changeset, :slug, generate_slug_from_title(title))
        end

      slug ->
        changeset
        |> validate_slug_format(slug)
        |> put_change(:slug, normalize_slug(slug))
    end
  end

  defp validate_slug_format(changeset, slug) do
    changeset
    |> validate_length(:slug, min: 3, max: 50, message: "URL must be between 3 and 50 characters")
    |> validate_format(:slug, ~r/^[a-z0-9-]+$/, message: "URL can only contain lowercase letters, numbers, and hyphens")
    |> validate_format(:slug, ~r/^[a-z0-9]/, message: "URL must start with a letter or number")
    |> validate_format(:slug, ~r/[a-z0-9]$/, message: "URL must end with a letter or number")
    |> validate_format(:slug, ~r/^(?!.*--)/, message: "URL cannot contain consecutive hyphens")
    |> validate_exclusion(:slug, reserved_slugs(), message: "This URL is reserved and cannot be used")
  end

  defp normalize_slug(slug) do
    slug
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9-]/, "")
    |> String.replace(~r/-+/, "-")
    |> String.trim("-")
  end

  defp generate_slug_from_title(title) do
    base_slug = title
                |> String.downcase()
                |> String.replace(~r/[^a-z0-9\s-]/, "")
                |> String.replace(~r/\s+/, "-")
                |> String.replace(~r/-+/, "-")
                |> String.trim("-")
                |> (fn s ->
                  if String.length(s) > 50 do
                    String.slice(s, 0, 50) |> String.trim("-")
                  else
                    s
                  end
                end).()

    # Add random suffix to ensure uniqueness (keeping your existing pattern)
    "#{base_slug}-#{:rand.uniform(1000)}"
  end

  # Reserved slugs that cannot be used by users
  defp reserved_slugs do
    [
    # Existing system routes from your router
    "dashboard", "channels", "chat", "media", "events", "analytics",
    "invite", "collaborations", "profile", "settings", "search",
    "subscriptions", "broadcasts", "sessions", "users", "portfolios",
    "login", "logout", "register", "api", "uploads", "p",

    # Auth routes
    "login", "logout", "register", "signup", "signin", "auth", "oauth",

    # System routes
    "admin", "api", "www", "app", "account", "help", "support", "about",
    "contact", "privacy", "terms", "blog", "news", "home", "index",
    "billing", "tickets", "my-tickets",

    # File/asset routes
    "static", "assets", "images", "css", "js", "uploads", "files",
    "download", "downloads", "share", "public", "private", "dev", "test",
    "staging", "production", "demo", "example", "sample", "template"
    ]
  end
end
