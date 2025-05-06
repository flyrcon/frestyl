defmodule FrestylWeb.EmailHelpers do
  @moduledoc """
  Helper functions for building email content.
  """

  @doc """
  Generates a confirmation URL for the given token.
  """
  def confirmation_url(token) do
    base_url = FrestylWeb.Endpoint.url()
    "#{base_url}/users/confirm/#{token}"
  end

  @doc """
  Generates a password reset URL for the given token.
  """
  def password_reset_url(token) do
    base_url = FrestylWeb.Endpoint.url()
    "#{base_url}/users/reset_password/#{token}"
  end

  defp url(path) do
    endpoint = Application.get_env(:frestyl, FrestylWeb.Endpoint)
    host = endpoint[:url][:host] || "localhost"
    scheme = if Mix.env() == :prod, do: "https", else: "http"

    "#{scheme}://#{host}#{path}"
  end
end
