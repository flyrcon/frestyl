# lib/frestyl/portfolios/sharing_analytic.ex
defmodule Frestyl.Portfolios.SharingAnalytic do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sharing_analytics" do
    field :event_type, Ecto.Enum, values: [
      :portfolio_shared, :portfolio_viewed, :social_share_clicked,
      :contact_info_viewed, :section_viewed, :media_viewed,
      :resume_downloaded, :contact_form_submitted
    ]
    field :platform, :string # "linkedin", "twitter", "email", "direct_link", etc.
    field :referrer_url, :string
    field :user_agent, :string
    field :ip_address, :string
    field :country, :string
    field :city, :string
    field :device_type, :string # "desktop", "mobile", "tablet"
    field :browser, :string

    # Event-specific data
    field :section_id, :integer
    field :media_id, :integer
    field :click_position, :map # {x: 100, y: 200}
    field :time_on_page, :integer # seconds
    field :scroll_depth, :float # percentage

    # Session tracking
    field :session_id, :string
    field :visitor_id, :string # anonymous visitor tracking

    # Lead generation
    field :is_potential_lead, :boolean, default: false
    field :lead_score, :integer, default: 0
    field :conversion_action, :string

    belongs_to :portfolio, Frestyl.Portfolios.Portfolio
    belongs_to :user, Frestyl.Accounts.User

    timestamps()
  end

  def changeset(sharing_analytic, attrs) do
    sharing_analytic
    |> cast(attrs, [
      :event_type, :platform, :referrer_url, :user_agent, :ip_address,
      :country, :city, :device_type, :browser, :section_id, :media_id,
      :click_position, :time_on_page, :scroll_depth, :session_id, :visitor_id,
      :is_potential_lead, :lead_score, :conversion_action, :portfolio_id, :user_id
    ])
    |> validate_required([:event_type, :portfolio_id])
    |> validate_number(:time_on_page, greater_than_or_equal_to: 0)
    |> validate_number(:scroll_depth, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:lead_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> foreign_key_constraint(:portfolio_id)
  end
end
