# lib/frestyl/portfolios/portfolio_media.ex
defmodule Frestyl.Portfolios.PortfolioMedia do
  use Ecto.Schema
  import Ecto.Changeset

  schema "portfolio_media" do
    field :title, :string
    field :description, :string
    field :media_type, :string
    field :file_path, :string
    field :file_size, :integer
    field :mime_type, :string
    field :visible, :boolean, default: true
    field :position, :integer, default: 0

    belongs_to :portfolio, Frestyl.Portfolios.Portfolio
    belongs_to :section, Frestyl.Portfolios.PortfolioSection
    belongs_to :media_file, Frestyl.Media.MediaFile

    timestamps()
  end

  def changeset(media, attrs) do
    media
    |> cast(attrs, [:title, :description, :media_type, :file_path, :file_size,
                    :mime_type, :visible, :position, :portfolio_id, :section_id, :media_file_id])
    |> validate_required([:media_type])
    |> validate_inclusion(:media_type, ["image", "video", "audio", "document"])
    |> foreign_key_constraint(:portfolio_id)
    |> foreign_key_constraint(:section_id)
  end
end
