defmodule Frestyl.SEO.AccountSettings do
  def configure_seo_settings(account, portfolio) do
    case account.account_type do
      :personal ->
        %{
          indexable: true,
          meta_description: generate_basic_meta(portfolio),
          robots: "index, follow",
          schema_markup: generate_basic_schema(portfolio)
        }

      :professional ->
        %{
          indexable: true,
          custom_meta_tags: true,
          advanced_schema_markup: true,
          sitemap_inclusion: true,
          social_media_optimization: true,
          google_analytics: true
        }

      :enterprise ->
        %{
          white_label_seo: true,
          custom_robots_txt: true,
          advanced_analytics: true,
          custom_tracking_pixels: true,
          multi_domain_seo: true,
          enterprise_schema: true
        }
    end
  end

  defp generate_basic_meta(portfolio) do
    description = portfolio.description ||
                 "Professional portfolio showcasing #{portfolio.title}'s work and experience"

    String.slice(description, 0, 160)
  end

  defp generate_basic_schema(portfolio) do
    %{
      "@context" => "https://schema.org",
      "@type" => "Person",
      "name" => portfolio.title,
      "description" => generate_basic_meta(portfolio),
      "url" => "#{FrestylWeb.Endpoint.url()}/p/#{portfolio.slug}",
      "sameAs" => extract_social_links(portfolio)
    }
  end

  defp extract_social_links(portfolio) do
    # Extract social media links from portfolio content
    contact_section = get_contact_section(portfolio)

    [
      Map.get(contact_section, "linkedin"),
      Map.get(contact_section, "github"),
      Map.get(contact_section, "website")
    ]
    |> Enum.filter(&(&1 && String.length(&1) > 0))
  end

  defp get_contact_section(portfolio) do
    # Helper to extract contact information from portfolio sections
    case Enum.find(portfolio.sections || [], &(&1.section_type == :contact)) do
      nil -> %{}
      section -> section.content || %{}
    end
  end
end
