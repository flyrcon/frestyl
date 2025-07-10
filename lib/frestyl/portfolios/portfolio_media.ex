# lib/frestyl/portfolios/portfolio_media.ex
defmodule Frestyl.Portfolios.PortfolioMedia do
  use Ecto.Schema
  import Ecto.Changeset

  schema "portfolio_media" do
    field :filename, :string
    field :original_filename, :string
    field :file_type, :string
    field :file_size, :integer
    field :file_path, :string
    field :alt_text, :string
    field :caption, :string
    field :sort_order, :integer, default: 0

    # NEW: Video-specific fields
    field :video_thumbnail_url, :string
    field :video_duration, :integer  # in seconds
    field :video_format, :string     # mp4, webm, etc.
    field :is_external_video, :boolean, default: false
    field :external_video_platform, :string  # youtube, vimeo
    field :external_video_id, :string
    field :video_metadata, :map, default: %{}

    belongs_to :portfolio, Frestyl.Portfolios.Portfolio
    belongs_to :section, Frestyl.Portfolios.PortfolioSection, foreign_key: :section_id

    timestamps()
  end

  def changeset(media, attrs) do
    media
    |> cast(attrs, [
      :filename, :original_filename, :file_type, :file_size, :file_path,
      :alt_text, :caption, :sort_order, :portfolio_id, :section_id,
      :video_thumbnail_url, :video_duration, :video_format,
      :is_external_video, :external_video_platform, :external_video_id,
      :video_metadata
    ])
    |> validate_required([:filename, :file_type, :portfolio_id])
    |> validate_video_fields()
    |> foreign_key_constraint(:portfolio_id)
    |> foreign_key_constraint(:section_id)
  end

    # Changeset for external video creation
  def external_video_changeset(media, attrs) do
    media
    |> cast(attrs, [
      :external_video_platform, :external_video_id, :video_thumbnail_url,
      :video_duration, :video_metadata, :alt_text, :caption,
      :portfolio_id, :section_id
    ])
    |> put_change(:is_external_video, true)
    |> put_change(:file_type, "video/external")
    |> generate_external_video_filename()
    |> validate_required([:external_video_platform, :external_video_id, :portfolio_id])
    |> validate_inclusion(:external_video_platform, ["youtube", "vimeo"])
    |> foreign_key_constraint(:portfolio_id)
    |> foreign_key_constraint(:section_id)
  end

  defp validate_video_fields(changeset) do
    is_external = get_field(changeset, :is_external_video)
    file_type = get_field(changeset, :file_type) || ""

    cond do
      is_external ->
        validate_external_video_fields(changeset)
      String.starts_with?(file_type, "video/") ->
        validate_uploaded_video_fields(changeset)
      true ->
        changeset
    end
  end

  defp validate_external_video_fields(changeset) do
    changeset
    |> validate_required([:external_video_platform, :external_video_id])
    |> validate_inclusion(:external_video_platform, ["youtube", "vimeo"])
  end

  defp validate_uploaded_video_fields(changeset) do
    changeset
    |> validate_required([:file_path])
    |> validate_inclusion(:video_format, ["mp4", "webm", "ogg", "mov"])
  end

  defp generate_external_video_filename(changeset) do
    platform = get_field(changeset, :external_video_platform)
    video_id = get_field(changeset, :external_video_id)

    if platform && video_id do
      filename = "external_#{platform}_#{video_id}"
      put_change(changeset, :filename, filename)
    else
      changeset
    end
  end

  # Helper functions for video handling
  def is_video?(%__MODULE__{file_type: file_type}) when is_binary(file_type) do
    String.starts_with?(file_type, "video/") or file_type == "video/external"
  end
  def is_video?(_), do: false

  def is_external_video?(%__MODULE__{is_external_video: true}), do: true
  def is_external_video?(_), do: false

  def get_video_url(%__MODULE__{is_external_video: true, external_video_platform: platform, external_video_id: video_id}) do
    case platform do
      "youtube" -> "https://www.youtube.com/watch?v=#{video_id}"
      "vimeo" -> "https://vimeo.com/#{video_id}"
      _ -> nil
    end
  end
  def get_video_url(%__MODULE__{file_path: file_path}) when is_binary(file_path) do
    "/uploads/#{file_path}"
  end
  def get_video_url(_), do: nil

  def get_embed_url(%__MODULE__{is_external_video: true, external_video_platform: platform, external_video_id: video_id}) do
    case platform do
      "youtube" -> "https://www.youtube.com/embed/#{video_id}"
      "vimeo" -> "https://player.vimeo.com/video/#{video_id}"
      _ -> nil
    end
  end
  def get_embed_url(_), do: nil

  def get_thumbnail_url(%__MODULE__{video_thumbnail_url: url}) when is_binary(url) and url != "" do
    url
  end
  def get_thumbnail_url(%__MODULE__{is_external_video: true, external_video_platform: platform, external_video_id: video_id}) do
    case platform do
      "youtube" -> "https://img.youtube.com/vi/#{video_id}/maxresdefault.jpg"
      "vimeo" -> nil  # Vimeo thumbnails require API call
      _ -> nil
    end
  end
  def get_thumbnail_url(_), do: nil
end
