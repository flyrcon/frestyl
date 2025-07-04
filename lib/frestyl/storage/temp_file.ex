# lib/frestyl/storage/temp_file.ex
defmodule Frestyl.Storage.TempFile do
  @moduledoc """
  Schema for temporary file metadata storage
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :bigserial  # Changed to match your existing schema

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

    belongs_to :user, Frestyl.Accounts.User, type: :integer  # Explicit type
    belongs_to :portfolio, Frestyl.Portfolios.Portfolio, type: :integer  # Explicit type

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
