# lib/frestyl/config.ex
defmodule Frestyl.Config do
  def upload_path do
    Application.get_env(:frestyl, :upload_path, "priv/static/uploads")
  end

  def storage_type do
    Application.get_env(:frestyl, :storage_type, "local")
    |> to_string()
  end

  def thumbnail_sizes do
    Application.get_env(:frestyl, :thumbnail_sizes, [
      small: [width: 150, height: 150],
      medium: [width: 300, height: 300],
      large: [width: 600, height: 600]
    ])
  end

  def aws_bucket do
    Application.get_env(:frestyl, :aws_bucket)
  end

  def aws_region do
    Application.get_env(:frestyl, :aws_region, "us-west-2")
  end

  def aws_url_base do
    "https://#{aws_bucket()}.s3.#{aws_region()}.amazonaws.com"
  end

  def max_upload_size do
    Application.get_env(:frestyl, :max_upload_size, 100_000_000) # 100MB default
  end

  def accepted_file_types do
    Application.get_env(:frestyl, :accepted_file_types, :any)
  end
end
