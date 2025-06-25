defmodule Frestyl.Portfolios.EmbedCode do
  def generate_embed_code(portfolio, options \\ %{}) do
    token = generate_secure_token()
    settings = %{
      width: options[:width] || "100%",
      height: options[:height] || "600px",
      theme: options[:theme] || "light",
      show_header: options[:show_header] || true,
      allow_fullscreen: options[:allow_fullscreen] || false
    }

    """
    <iframe
      src="#{FrestylWeb.Endpoint.url()}/embed/#{portfolio.slug}?token=#{token}"
      width="#{settings.width}"
      height="#{settings.height}"
      frameborder="0"
      allowfullscreen="#{settings.allow_fullscreen}">
    </iframe>
    """
  end

  def generate_embed_token(portfolio, permission_level \\ :view, expires_in_hours \\ 24) do
    token = generate_secure_token()
    expires_at = DateTime.add(DateTime.utc_now(), expires_in_hours, :hour)

    # Store token with portfolio association for validation
    embed_permission = %{
      portfolio_id: portfolio.id,
      access_token: token,
      permission_level: permission_level,
      expires_at: expires_at,
      embed_settings: %{
        "created_at" => DateTime.utc_now(),
        "embed_type" => "iframe"
      }
    }

    case Frestyl.Portfolios.create_sharing_permission(embed_permission) do
      {:ok, _permission} -> {:ok, token}
      {:error, changeset} -> {:error, changeset}
    end
  end

  def validate_embed_token(token) do
    case Frestyl.Portfolios.get_sharing_permission_by_token(token) do
      nil -> {:error, :invalid_token}
      permission ->
        if DateTime.compare(permission.expires_at, DateTime.utc_now()) == :gt do
          {:ok, permission}
        else
          {:error, :expired_token}
        end
    end
  end

  defp generate_secure_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end
end
