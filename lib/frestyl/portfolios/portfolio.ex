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
    field :allow_resume_export, :boolean, default: false
    field :resume_template, :string, default: "ats_friendly"
    field :resume_config, :map, default: %{}
    field :require_approval, :boolean, default: false
    field :account_type, Ecto.Enum, values: [:personal, :professional, :enterprise]
    field :sharing_permissions, :map
    field :cross_account_sharing, :boolean, default: false

    field :customization, :map, default: %{
      "color_scheme" => "purple-pink",
      "layout_style" => "single_page",
      "section_spacing" => "normal",
      "font_style" => "inter",
      "fixed_navigation" => true,
      "dark_mode_support" => false
    }
    # NEW: Story-specific fields
    field :story_type, Ecto.Enum, values: [
      :personal_narrative, :professional_showcase, :brand_story,
      :case_study, :creative_portfolio, :educational_content
    ]
    field :narrative_structure, Ecto.Enum, values: [
      :chronological, :hero_journey, :case_study, :before_after, :problem_solution
    ], default: :chronological
    field :target_audience, :string
    field :story_tags, {:array, :string}
    field :estimated_read_time, :integer, default: 0
    field :collaboration_settings, :map, default: %{}

    many_to_many :shared_with_accounts, Frestyl.Accounts.UserAccount,
      join_through: "portfolio_account_shares"

    # Relations
    belongs_to :user, Frestyl.Accounts.User
    belongs_to :account, Frestyl.Accounts.UserAccount
    has_many :portfolio_sections, Frestyl.Portfolios.PortfolioSection
    has_many :sections, Frestyl.Portfolios.PortfolioSection
    has_many :portfolio_media, Frestyl.Portfolios.PortfolioMedia
    has_many :portfolio_visits, Frestyl.Portfolios.PortfolioVisit
    has_many :portfolio_shares, Frestyl.Portfolios.PortfolioShare
    has_many :story_chapters, Frestyl.Stories.Chapter

    timestamps()
  end

  def story_changeset(portfolio, attrs) do
    portfolio
    |> cast(attrs, [
      :title, :description, :story_type, :narrative_structure,
      :target_audience, :story_tags, :collaboration_settings
    ])
    |> validate_required([:title, :account_id])
    |> validate_length(:title, min: 1, max: 255)
    |> calculate_estimated_read_time()
  end

  defp calculate_estimated_read_time(changeset) do
    # Simple estimation: 200 words per minute
    description = get_change(changeset, :description) || ""
    word_count = String.split(description) |> length()
    read_time = div(word_count, 200) |> max(1)

    put_change(changeset, :estimated_read_time, read_time)
  end

  def changeset(portfolio, attrs) do
    portfolio
    |> cast(attrs, [:title, :slug, :account_type, :sharing_permissions, :cross_account_sharing,
                    :description, :visibility, :expires_at,
                    :approval_required, :require_approval, :theme, :custom_css,
                    :user_id, :allow_resume_export, :resume_template, :resume_config,
                    :customization])
    |> validate_required([:title, :slug])
    |> validate_length(:title, min: 3, max: 100)
    |> validate_length(:description, max: 500)
    |> validate_length(:slug, min: 5, max: 50)
    |> validate_slug()
    |> validate_format(:slug, ~r/^[a-z0-9-]+$/, message: "must contain only lowercase letters, numbers, and hyphens")
    |> validate_inclusion(:account_type, [:personal, :professional, :enterprise])
    |> validate_inclusion(:visibility, [:public, :private, :link_only])
    |> validate_inclusion(:theme, [
      "default", "creative", "corporate", "minimalist",
      "executive", "developer", "designer", "consultant", "academic",
      "artist", "entrepreneur", "freelancer", "photographer", "writer",
      "marketing", "healthcare"
    ])
    |> validate_inclusion(:resume_template, ["ats_friendly", "modern", "creative"])
    |> validate_customization()
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

  defp validate_customization(changeset) do
    validate_change(changeset, :customization, fn :customization, customization ->
      case customization do
        %{} = custom when is_map(custom) ->
          # Validate that customization is a map with expected keys
          valid_color_schemes = ["purple-pink", "blue-cyan", "green-teal", "orange-red", "gray-slate"]
          valid_layout_styles = ["single_page", "multi_page"]
          valid_section_spacing = ["compact", "normal", "spacious"]
          valid_font_styles = ["inter", "merriweather", "roboto", "playfair"]

          errors = []

          # Validate color_scheme
          color_scheme = Map.get(custom, "color_scheme", "purple-pink")
          errors = if color_scheme in valid_color_schemes do
            errors
          else
            [{:customization, "invalid color scheme"} | errors]
          end

          # Validate layout_style
          layout_style = Map.get(custom, "layout_style", "single_page")
          errors = if layout_style in valid_layout_styles do
            errors
          else
            [{:customization, "invalid layout style"} | errors]
          end

          # Validate section_spacing
          section_spacing = Map.get(custom, "section_spacing", "normal")
          errors = if section_spacing in valid_section_spacing do
            errors
          else
            [{:customization, "invalid section spacing"} | errors]
          end

          # Validate font_style
          font_style = Map.get(custom, "font_style", "inter")
          errors = if font_style in valid_font_styles do
            errors
          else
            [{:customization, "invalid font style"} | errors]
          end

          errors
        _ ->
          [{:customization, "must be a map"}]
      end
    end)
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
