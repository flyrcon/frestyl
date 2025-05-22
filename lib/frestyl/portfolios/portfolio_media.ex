# lib/frestyl/portfolios/portfolio_media.ex
defmodule Frestyl.Portfolios.PortfolioMedia do
  use Ecto.Schema
  import Ecto.Changeset

  schema "portfolio_media" do
    field :title, :string
    field :description, :string
    field :media_type, Ecto.Enum, values: [:image, :video, :audio, :document]
    field :file_path, :string
    field :file_size, :integer
    field :mime_type, :string
    field :visible, :boolean, default: true
    field :position, :integer

    belongs_to :portfolio, Frestyl.Portfolios.Portfolio
    belongs_to :section, Frestyl.Portfolios.PortfolioSection, foreign_key: :section_id

    # This allows us to link existing media files
    belongs_to :media_file, Frestyl.Media.MediaFile, foreign_key: :media_file_id

    timestamps()
  end

  def changeset(media, attrs) do
    media
    |> cast(attrs, [:title, :description, :media_type, :file_path, :file_size,
                    :mime_type, :visible, :position, :portfolio_id, :section_id, :media_file_id])
    |> validate_required([:title, :media_type, :file_path, :portfolio_id])
    |> validate_length(:title, max: 100)
    |> validate_length(:description, max: 1000)
    |> foreign_key_constraint(:portfolio_id)
    |> foreign_key_constraint(:section_id)
    |> foreign_key_constraint(:media_file_id)
  end
end
