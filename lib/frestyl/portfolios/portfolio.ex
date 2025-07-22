# lib/frestyl/portfolios/portfolio.ex - Enhanced with Four-Tier Privacy System

defmodule Frestyl.Portfolios.Portfolio do
  use Ecto.Schema
  import Ecto.Changeset

  schema "portfolios" do
    field :title, :string
    field :slug, :string
    field :description, :string

    # 🔥 ENHANCED: Four-tier privacy system
    field :visibility, Ecto.Enum, values: [
      :public,        # Discoverable and accessible to everyone
      :link_only,     # Accessible via direct URL only
      :request_only,  # Requires approval to view
      :private        # Owner and invited collaborators only
    ], default: :link_only

    # 🔥 NEW: Privacy controls
    field :privacy_settings, :map, default: %{
      "allow_search_engines" => false,
      "show_in_discovery" => false,
      "require_login_to_view" => false,
      "watermark_images" => false,
      "disable_right_click" => false,
      "track_visitor_analytics" => true,
      "allow_social_sharing" => true,
      "show_contact_info" => true,
      "allow_downloads" => false
    }

    # 🔥 NEW: Social integration settings
    field :social_integration, :map, default: %{
      "enabled_platforms" => [],
      "auto_sync" => false,
      "last_sync_at" => nil,
      "sync_frequency" => "daily", # daily, weekly, manual
      "show_follower_counts" => true,
      "show_recent_posts" => true,
      "max_posts_per_platform" => 3
    }

    # 🔥 NEW: Contact information with privacy controls
    field :contact_info, :map, default: %{
      "email" => nil,
      "phone" => nil,
      "website" => nil,
      "location" => nil,
      "linkedin" => nil,
      "twitter" => nil,
      "instagram" => nil,
      "github" => nil,
      "show_email" => false,
      "show_phone" => false,
      "show_location" => false
    }

    # 🔥 NEW: Request access settings
    field :access_request_settings, :map, default: %{
      "enabled" => true,
      "require_message" => true,
      "auto_approve_connections" => false,
      "notification_email" => nil,
      "custom_message" => "Please provide a brief introduction and reason for accessing this portfolio."
    }

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

    field :audio_settings, :map, default: %{
      "background_music_enabled" => false,
      "background_music_url" => nil,
      "voice_intro_enabled" => false,
      "voice_intro_url" => nil,
      "auto_play_policy" => "hover"
    }

    field :monetization_settings, :map, default: %{
      "enabled" => false,
      "services" => [],
      "pricing_tiers" => [],
      "booking_enabled" => false
    }

    field :brand_enforcement, :map, default: %{
      "enforce_brand" => false,
      "locked_elements" => [],
      "custom_brand_config" => %{}
    }

    # Story-specific fields
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
    field :service_booking_enabled, :boolean, default: false

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
    has_many :access_requests, Frestyl.Portfolios.AccessRequest
    has_many :social_integrations, Frestyl.Portfolios.SocialIntegration
    has_many :sharing_analytics, Frestyl.Portfolios.SharingAnalytic
    has_many :story_chapters, Frestyl.Stories.Chapter
    has_many :services, Frestyl.Services.Service

    timestamps()
  end

  def changeset(portfolio, attrs) do
    portfolio
    |> cast(attrs, [
      :title, :slug, :account_type, :sharing_permissions, :cross_account_sharing,
      :description, :visibility, :privacy_settings, :social_integration,
      :contact_info, :access_request_settings, :expires_at,
      :approval_required, :require_approval, :theme, :custom_css,
      :user_id, :allow_resume_export, :resume_template, :resume_config,
      :customization, :story_type, :estimated_read_time, :monetization_settings,
      :audio_settings
    ])
    |> validate_required([:title, :slug])
    |> validate_length(:title, min: 3, max: 100)
    |> validate_length(:description, max: 500)
    |> validate_length(:slug, min: 3, max: 50)
    |> validate_format(:slug, ~r/^[a-z0-9-]+$/, message: "can only contain lowercase letters, numbers, and hyphens")
    |> validate_inclusion(:visibility, [:public, :link_only, :request_only, :private])
    |> unique_constraint(:slug)
    |> validate_slug_not_reserved()
    |> validate_privacy_settings()
    |> validate_social_integration()
    |> validate_contact_info()
  end

  def customization_changeset(portfolio, attrs) do
    portfolio
    |> cast(attrs, [:customization])
    |> validate_required([])
  end

  defp validate_privacy_settings(changeset) do
    case get_change(changeset, :privacy_settings) do
      nil -> changeset
      settings when is_map(settings) ->
        required_keys = [
          "allow_search_engines", "show_in_discovery", "require_login_to_view",
          "watermark_images", "disable_right_click", "track_visitor_analytics",
          "allow_social_sharing", "show_contact_info", "allow_downloads"
        ]

        if Enum.all?(required_keys, &Map.has_key?(settings, &1)) do
          changeset
        else
          add_error(changeset, :privacy_settings, "missing required privacy settings")
        end
      _ ->
        add_error(changeset, :privacy_settings, "must be a valid map")
    end
  end

  # 🔥 NEW: Social integration validation
  defp validate_social_integration(changeset) do
    case get_change(changeset, :social_integration) do
      nil -> changeset
      settings when is_map(settings) ->
        platforms = Map.get(settings, "enabled_platforms", [])
        valid_platforms = ["linkedin", "twitter", "instagram", "github", "tiktok"]

        if Enum.all?(platforms, &(&1 in valid_platforms)) do
          changeset
        else
          add_error(changeset, :social_integration, "contains invalid social platforms")
        end
      _ ->
        add_error(changeset, :social_integration, "must be a valid map")
    end
  end

  # 🔥 NEW: Contact info validation
  defp validate_contact_info(changeset) do
    case get_change(changeset, :contact_info) do
      nil -> changeset
      contact when is_map(contact) ->
        changeset
        |> validate_email_format(contact)
        |> validate_social_urls(contact)
      _ ->
        add_error(changeset, :contact_info, "must be a valid map")
    end
  end

  defp validate_email_format(changeset, contact) do
    case Map.get(contact, "email") do
      nil -> changeset
      "" -> changeset
      email when is_binary(email) ->
        if String.match?(email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/) do
          changeset
        else
          add_error(changeset, :contact_info, "email format is invalid")
        end
      _ ->
        add_error(changeset, :contact_info, "email must be a string")
    end
  end

  defp validate_social_urls(changeset, contact) do
    social_fields = ["linkedin", "twitter", "instagram", "github", "website"]

    Enum.reduce(social_fields, changeset, fn field, acc ->
      case Map.get(contact, field) do
        nil -> acc
        "" -> acc
        url when is_binary(url) ->
          if String.match?(url, ~r/^https?:\/\/.+/) do
            acc
          else
            add_error(acc, :contact_info, "#{field} must be a valid URL")
          end
        _ ->
          add_error(acc, :contact_info, "#{field} must be a string")
      end
    end)
  end

  # Existing validation helpers
  defp validate_slug_not_reserved(changeset) do
    case get_change(changeset, :slug) do
      nil -> changeset
      slug ->
        if slug in reserved_slugs() do
          add_error(changeset, :slug, "is reserved and cannot be used")
        else
          changeset
        end
    end
  end

  # Reserved slugs that cannot be used by users
  defp reserved_slugs do
    [
      # System routes
      "dashboard", "channels", "chat", "media", "events", "analytics",
      "invite", "collaborations", "profile", "settings", "search",
      "subscriptions", "broadcasts", "sessions", "users", "portfolios",
      "login", "logout", "register", "api", "uploads", "p", "admin",

      # Social platforms to avoid confusion
      "linkedin", "twitter", "instagram", "github", "tiktok", "facebook",

      # Common portfolio paths
      "about", "contact", "resume", "cv", "portfolio", "work", "projects"
    ]
  end
end
