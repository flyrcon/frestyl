# lib/frestyl/storage/s3.ex
defmodule Frestyl.Storage.S3 do
  alias ExAws.S3

  @doc """
  Uploads a file to S3 bucket
  """
  def upload_file(source_path, key, opts \\ []) do
    bucket = get_bucket()
    content_type = opts[:content_type] || MIME.from_path(source_path)

    source_path
    |> File.read!()
    |> S3.put_object(bucket, key, [
      {:content_type, content_type},
      {:acl, opts[:acl] || "public-read"}
    ])
    |> ExAws.request()
    |> case do
      {:ok, _} -> {:ok, get_url(key)}
      error -> error
    end
  end

  @doc """
  Deletes a file from S3 bucket
  """
  def delete_file(key) do
    bucket = get_bucket()

    S3.delete_object(bucket, key)
    |> ExAws.request()
  end

  @doc """
  Gets the URL for a file in S3
  """
  def get_url(key) do
    bucket = get_bucket()
    region = get_region()

    "https://#{bucket}.s3.#{region}.amazonaws.com/#{key}"
  end

  defp get_bucket, do: Application.get_env(:frestyl, :aws_bucket)
  defp get_region, do: Application.get_env(:frestyl, :aws_region, "us-west-2")
end
