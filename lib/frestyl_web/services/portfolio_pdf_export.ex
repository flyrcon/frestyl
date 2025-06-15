# lib/frestyl_web/services/portfolio_pdf_export.ex - CLEAN VERSION
defmodule FrestylWeb.Services.PortfolioPdfExport do
  @moduledoc """
  Handles ATS-optimized PDF export of portfolios using ChromicPDF
  Returns PDF binary for browser download dialog
  """

  require Logger
  alias Frestyl.Portfolios

  @doc """
  Exports a portfolio to PDF with browser download dialog
  """
  def export_portfolio(portfolio_id, user_id, opts \\ []) do
    try do
      portfolio = Portfolios.get_portfolio!(portfolio_id)
      unless portfolio.user_id == user_id do
        {:error, "Unauthorized"}
      else
        portfolio_url = build_ats_portfolio_url(portfolio.slug, opts)
        Logger.info("PDF Export URL: #{portfolio_url}")

        case test_url_accessibility(portfolio_url) do
          :ok ->
            pdf_options = build_ats_pdf_options(opts)

            case ChromicPDF.print_to_pdf({:url, portfolio_url}, pdf_options) do
              {:ok, pdf_binary} ->
                suggested_filename = generate_download_filename(portfolio)

                Logger.info("ATS PDF generated successfully, size: #{byte_size(pdf_binary)} bytes")
                {:ok, %{
                  pdf_binary: pdf_binary,
                  filename: suggested_filename,
                  size: byte_size(pdf_binary),
                  content_type: "application/pdf"
                }}

              {:error, reason} ->
                Logger.error("ChromicPDF failed: #{inspect(reason)}")
                {:error, "Failed to generate PDF: #{inspect(reason)}"}
            end

          {:error, reason} ->
            Logger.error("URL not accessible: #{reason}")
            {:error, "Portfolio URL not accessible: #{reason}"}
        end
      end
    rescue
      error ->
        Logger.error("PDF export error: #{Exception.message(error)}")
        {:error, "PDF export failed: #{Exception.message(error)}"}
    end
  end

  # Build ATS-optimized URL with special parameters
  defp build_ats_portfolio_url(portfolio_slug, opts) do
    base_url = get_base_url()

    # ATS-specific parameters for optimal parsing
    ats_params = [
      "format=ats",           # Trigger ATS-optimized layout
      "print=true",           # Enable print styles
      "optimize=resume",      # Resume optimization mode
      "structure=semantic",   # Use semantic HTML structure
      "fonts=system",         # Use system fonts for ATS compatibility
      "images=alt_text"       # Prioritize alt text over images
    ]

    # Add custom options
    params = case opts[:template] do
      "resume" -> ["template=resume" | ats_params]
      _ -> ats_params
    end

    query_string = Enum.join(params, "&")
    "#{base_url}/p/#{portfolio_slug}?#{query_string}"
  end

  # ATS-optimized PDF settings
  defp build_ats_pdf_options(opts) do
    # ATS scanners work best with these settings
    base_options = [
      # Standard letter size (8.5" x 11") - ATS standard
      format: :letter,

      # Generous margins for ATS parsing
      margin_top: 0.75,
      margin_bottom: 0.75,
      margin_left: 0.75,
      margin_right: 0.75,

      # Essential for ATS text extraction
      print_background: false,  # ATS systems ignore backgrounds
      landscape: false,         # Portrait orientation only

      # Font and text optimization
      prefer_css_page_size: false,
      display_header_footer: false,

      # Increased timeout for complex portfolios
      wait_until: :networkidle0,
      timeout: 60_000,          # Increased to 60 seconds

      # ATS-friendly scaling
      scale: 1.0,

      # Generate tagged PDF for accessibility/ATS
      tagged: true,

      # Additional Chrome options for stability
      no_sandbox: true,
      disable_gpu: true,
      disable_dev_shm_usage: true
    ]

    # Merge with any custom options
    Keyword.merge(base_options, opts[:pdf_options] || [])
  end

  # Generate user-friendly filename for download
  defp generate_download_filename(portfolio) do
    # Create a clean filename from portfolio title and slug
    base_name = case portfolio.title do
      title when is_binary(title) and title != "" ->
        title
        |> String.replace(~r/[^\w\s-]/, "")
        |> String.replace(~r/\s+/, "_")
        |> String.slice(0, 50)
      _ ->
        portfolio.slug || "portfolio"
    end

    # Add timestamp for uniqueness
    timestamp = DateTime.utc_now() |> DateTime.to_date() |> Date.to_string()

    "#{base_name}_#{timestamp}.pdf"
  end

  # Test if the portfolio URL is accessible before attempting PDF generation
  defp test_url_accessibility(url) do
    try do
      # Use Finch (which should be available in Phoenix apps) to test URL
      case Finch.build(:get, url) |> Finch.request(Frestyl.Finch, receive_timeout: 10_000) do
        {:ok, %{status: status}} when status in 200..299 ->
          :ok
        {:ok, %{status: status}} ->
          {:error, "HTTP #{status}"}
        {:error, reason} ->
          {:error, "Connection failed: #{inspect(reason)}"}
      end
    rescue
      error ->
        # If Finch is not available or fails, skip the test and proceed
        Logger.warning("URL accessibility test failed: #{Exception.message(error)}")
        :ok
    end
  end

  # Get base URL for the application
  defp get_base_url do
    endpoint_config = Application.get_env(:frestyl, FrestylWeb.Endpoint)
    url_config = endpoint_config[:url] || []

    host = url_config[:host] || "localhost"
    port = endpoint_config[:http][:port] || 4000
    scheme = if url_config[:scheme] == "https", do: "https", else: "http"

    case {Mix.env(), port} do
      {:prod, _} -> "#{scheme}://#{host}"
      {_, 80} when scheme == "http" -> "#{scheme}://#{host}"
      {_, 443} when scheme == "https" -> "#{scheme}://#{host}"
      _ -> "#{scheme}://#{host}:#{port}"
    end
  end

  @doc """
  Clean up old PDF exports (older than 30 days)
  Note: This is kept for backward compatibility but not used in new browser-download flow
  """
  def cleanup_old_exports(user_id \\ nil) do
    Logger.info("Cleanup function called but not needed for browser downloads")
    :ok
  end

  @doc """
  Get user's export history
  Note: This is kept for backward compatibility but not used in new browser-download flow
  """
  def list_user_exports(user_id) do
    Logger.info("List exports function called but not needed for browser downloads")
    []
  end
end
