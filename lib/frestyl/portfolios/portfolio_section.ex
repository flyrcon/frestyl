# lib/frestyl/portfolios/portfolio_section.ex
defmodule Frestyl.Portfolios.PortfolioSection do
  use Ecto.Schema
  import Ecto.Changeset

  schema "portfolio_sections" do
    field :title, :string
    field :section_type, Ecto.Enum, values: [:experience, :education, :skills, :projects,
                                           :achievements, :custom, :contact, :intro]
    field :content, :map
    field :position, :integer
    field :visible, :boolean, default: true

    belongs_to :portfolio, Frestyl.Portfolios.Portfolio
    has_many :portfolio_media, Frestyl.Portfolios.PortfolioMedia, foreign_key: :section_id

    timestamps()
  end

  def changeset(section, attrs) do
    section
    |> cast(attrs, [:title, :section_type, :content, :position, :visible, :portfolio_id])
    |> validate_required([:title, :section_type, :portfolio_id])
    |> validate_length(:title, max: 100)
    |> foreign_key_constraint(:portfolio_id)
  end
end
