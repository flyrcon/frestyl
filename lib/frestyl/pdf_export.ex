# lib/frestyl/pdf_export.ex - NEW MODULE for PDF generation

defmodule Frestyl.PdfExport do
  @moduledoc """
  Handles PDF export of portfolios using ChromicPDF
  """

  require Logger

  @doc """
  Exports a portfolio to PDF
  """
  def export_portfolio(portfolio_slug, opts \\ []) do
    try do
      # Get the portfolio URL
      portfolio_url = build_portfolio_url(portfolio_slug, opts)

      # Generate PDF
      pdf_options = build_pdf_options(opts)

      Logger.info("Generating PDF for portfolio: #{portfolio_slug}")

      case ChromicPDF.print_to_pdf({:url, portfolio_url}, pdf_options) do
        {:ok, pdf_binary} ->
          filename = generate_filename(portfolio_slug)
          save_path = build_save_path(filename)

          case File.write(save_path, pdf_binary) do
            :ok ->
              Logger.info("PDF exported successfully: #{save_path}")
              {:ok, %{
                filename: filename,
                path: save_path,
                url: "/uploads/exports/#{filename}",
                size: byte_size(pdf_binary)
              }}

            {:error, reason} ->
              Logger.error("Failed to save PDF: #{inspect(reason)}")
              {:error, "Failed to save PDF file"}
          end

        {:error, reason} ->
          Logger.error("ChromicPDF failed: #{inspect(reason)}")
          {:error, "Failed to generate PDF"}
      end

    rescue
      error ->
        Logger.error("PDF export error: #{Exception.message(error)}")
        {:error, "PDF export failed: #{Exception.message(error)}"}
    end
  end

  @doc """
  Exports portfolio with custom template for PDF
  """
  def export_portfolio_with_template(portfolio_slug, template \\ :resume) do
    case template do
      :resume -> export_as_resume(portfolio_slug)
      :presentation -> export_as_presentation(portfolio_slug)
      :portfolio -> export_portfolio(portfolio_slug, format: :portfolio)
      _ -> export_portfolio(portfolio_slug)
    end
  end

  # Private functions

  defp build_portfolio_url(portfolio_slug, opts) do
    base_url = Application.get_env(:frestyl, FrestylWeb.Endpoint)[:url][:host] || "localhost"
    port = Application.get_env(:frestyl, FrestylWeb.Endpoint)[:http][:port] || 4000
    scheme = if Mix.env() == :prod, do: "https", else: "http"

    url = "#{scheme}://#{base_url}"
    url = if Mix.env() != :prod, do: "#{url}:#{port}", else: url

    # Add PDF-specific parameters
    params = [
      "pdf=true",
      "print_mode=true"
    ]

    # Add any custom options
    if opts[:hide_navigation], do: params = ["hide_nav=true" | params]
    if opts[:theme], do: params = ["theme=#{opts[:theme]}" | params]

    query_string = if length(params) > 0, do: "?" <> Enum.join(params, "&"), else: ""

    "#{url}/p/#{portfolio_slug}#{query_string}"
  end

  defp build_pdf_options(opts) do
    default_options = [
      format: :a4,
      margin_top: 1.0,
      margin_bottom: 1.0,
      margin_left: 1.0,
      margin_right: 1.0,
      print_background: true,
      landscape: false,
      wait_until: :networkidle0,
      timeout: 30_000
    ]

    # Merge with user options
    Keyword.merge(default_options, opts[:pdf_options] || [])
  end

  defp generate_filename(portfolio_slug) do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    "portfolio_#{portfolio_slug}_#{timestamp}.pdf"
  end

  defp build_save_path(filename) do
    export_dir = Path.join([
      Application.app_dir(:frestyl, "priv"),
      "static",
      "uploads",
      "exports"
    ])

    # Ensure directory exists
    File.mkdir_p!(export_dir)

    Path.join(export_dir, filename)
  end

  defp export_as_resume(portfolio_slug) do
    resume_options = [
      pdf_options: [
        format: :a4,
        margin_top: 0.5,
        margin_bottom: 0.5,
        margin_left: 0.5,
        margin_right: 0.5,
        print_background: false,
        landscape: false
      ],
      hide_navigation: true,
      theme: "resume"
    ]

    export_portfolio(portfolio_slug, resume_options)
  end

  defp export_as_presentation(portfolio_slug) do
    presentation_options = [
      pdf_options: [
        format: :a4,
        margin_top: 0.2,
        margin_bottom: 0.2,
        margin_left: 0.2,
        margin_right: 0.2,
        print_background: true,
        landscape: true
      ],
      theme: "presentation"
    ]

    export_portfolio(portfolio_slug, presentation_options)
  end

  @doc """
  Cleans up old export files (older than 7 days)
  """
  def cleanup_old_exports do
    export_dir = Path.join([
      Application.app_dir(:frestyl, "priv"),
      "static",
      "uploads",
      "exports"
    ])

    if File.exists?(export_dir) do
      cutoff_time = DateTime.utc_now() |> DateTime.add(-7 * 24 * 60 * 60, :second)

      File.ls!(export_dir)
      |> Enum.each(fn filename ->
        file_path = Path.join(export_dir, filename)

        case File.stat(file_path) do
          {:ok, %{mtime: mtime}} ->
            file_datetime = NaiveDateTime.from_erl!(mtime) |> DateTime.from_naive!("Etc/UTC")

            if DateTime.compare(file_datetime, cutoff_time) == :lt do
              File.rm(file_path)
              Logger.info("Cleaned up old export: #{filename}")
            end

          {:error, _} -> :ok
        end
      end)
    end
  end

  @doc """
  Gets the size of all export files
  """
  def get_exports_disk_usage do
    export_dir = Path.join([
      Application.app_dir(:frestyl, "priv"),
      "static",
      "uploads",
      "exports"
    ])

    if File.exists?(export_dir) do
      File.ls!(export_dir)
      |> Enum.reduce(0, fn filename, acc ->
        file_path = Path.join(export_dir, filename)
        case File.stat(file_path) do
          {:ok, %{size: size}} -> acc + size
          {:error, _} -> acc
        end
      end)
    else
      0
    end
  end
end
