# lib/frestyl/storage/temp_file_store.ex
defmodule Frestyl.Storage.TempFileStore do
  @moduledoc """
  Database-backed temporary file storage for metadata and tracking.
  Works in conjunction with TempFileManager for complete file lifecycle management.
  """

  import Ecto.Query
  alias Frestyl.Repo
  alias Frestyl.Storage.TempFile

  @doc """
  Create a new temporary file record
  """
  def create_temp_file(attrs) do
    %TempFile{}
    |> TempFile.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Get temporary file by filename
  """
  def get_temp_file(filename) do
    from(tf in TempFile,
      where: tf.filename == ^filename and tf.expires_at > ^DateTime.utc_now()
    )
    |> Repo.one()
  end

  @doc """
  Get all temporary files for a user
  """
  def list_user_temp_files(user_id) do
    from(tf in TempFile,
      where: tf.user_id == ^user_id and tf.expires_at > ^DateTime.utc_now(),
      order_by: [desc: tf.created_at]
    )
    |> Repo.all()
  end

  @doc """
  Delete expired temporary file records
  """
  def cleanup_expired_records do
    now = DateTime.utc_now()

    {count, _} =
      from(tf in TempFile,
        where: tf.expires_at <= ^now
      )
      |> Repo.delete_all()

    count
  end

  @doc """
  Update file download count
  """
  def increment_download_count(filename) do
    from(tf in TempFile,
      where: tf.filename == ^filename
    )
    |> Repo.update_all(inc: [download_count: 1])
  end

  @doc """
  Get file statistics
  """
  def get_file_stats do
    query = from(tf in TempFile,
      select: %{
        total_files: count(tf.id),
        total_size: sum(tf.file_size),
        total_downloads: sum(tf.download_count)
      }
    )

    Repo.one(query) || %{total_files: 0, total_size: 0, total_downloads: 0}
  end
end

# lib/frestyl/storage/temp_file.ex
defmodule Frestyl.Storage.TempFile do
  @moduledoc """
  Schema for temporary file metadata storage
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "temp_files" do
    field :filename, :string
    field :original_name, :string
    field :file_path, :string
    field :content_type, :string
    field :file_size, :integer
    field :download_count, :integer, default: 0
    field :expires_at, :utc_datetime
    field :export_format, :string
    field :export_options, :map

    belongs_to :user, Frestyl.Accounts.User
    belongs_to :portfolio, Frestyl.Portfolios.Portfolio

    timestamps()
  end

  def changeset(temp_file, attrs) do
    temp_file
    |> cast(attrs, [
      :filename, :original_name, :file_path, :content_type,
      :file_size, :expires_at, :export_format, :export_options,
      :user_id, :portfolio_id
    ])
    |> validate_required([:filename, :file_path, :content_type, :expires_at])
    |> validate_length(:filename, max: 255)
    |> validate_number(:file_size, greater_than: 0)
    |> unique_constraint(:filename)
  end
end
