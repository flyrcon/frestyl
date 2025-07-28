# lib/frestyl_web/live/portfolio_live/display/layout_detector.ex
defmodule FrestylWeb.PortfolioLive.Display.LayoutDetector do
  @moduledoc """
  Detects the appropriate professional type and layout for portfolios
  """

  @doc """
  Determines the professional category based on portfolio sections and customization
  """
  def determine_professional_type(portfolio) do
    explicit_type = get_explicit_type(portfolio)

    case explicit_type do
      nil -> infer_from_sections(portfolio)
      type -> type
    end
  end

  @doc """
  Gets the appropriate layout component module for a professional type
  """
  def get_layout_component(professional_type, layout_style \\ "default") do
    case {professional_type, layout_style} do
      {:developer, "github"} -> FrestylWeb.PortfolioLive.Layouts.DeveloperGithubLayoutComponent
      {:developer, _} -> FrestylWeb.PortfolioLive.Layouts.DeveloperLayoutComponent
      {:creative, "imdb"} -> FrestylWeb.PortfolioLive.Layouts.CreativeImdbLayoutComponent
      {:creative, _} -> FrestylWeb.PortfolioLive.Layouts.CreativeLayoutComponent
      {:service_provider, _} -> FrestylWeb.PortfolioLive.Layouts.ServiceProviderLayoutComponent
      {:musician, "playlist"} -> FrestylWeb.PortfolioLive.Layouts.MusicianPlaylistLayoutComponent
      {:musician, _} -> FrestylWeb.PortfolioLive.Layouts.MusicianLayoutComponent
      _ -> FrestylWeb.PortfolioLive.Layouts.ProfessionalLayoutComponent
    end
  end

  @doc """
  Detects appropriate section layout based on content and professional type
  """
  def determine_section_layout(section, professional_type) do
    section_type = normalize_section_type(section.section_type)
    content = section.content || %{}

    case {section_type, professional_type} do
      {:code_showcase, :developer} -> "terminal_style"
      {:media_showcase, :creative} -> "gallery_grid"
      {:media_showcase, :musician} -> "playlist_style"
      {:experience, :creative} -> "filmography_style"
      {:experience, :developer} -> "commit_timeline"
      {:projects, :creative} -> "portfolio_showcase"
      {:projects, :developer} -> "repository_grid"
      {:skills, :developer} -> "tech_stack"
      {:skills, :creative} -> "creative_tools"
      {:skills, :service_provider} -> "service_matrix"
      _ -> "standard"
    end
  end

  @doc """
  Suggests optimal section arrangement for professional type
  """
  def suggest_section_order(sections, professional_type) do
    case professional_type do
      :developer ->
        order_sections(sections, [:hero, :code_showcase, :projects, :experience, :skills, :contact])
      :creative ->
        order_sections(sections, [:hero, :media_showcase, :projects, :experience, :skills, :testimonials, :contact])
      :musician ->
        order_sections(sections, [:hero, :media_showcase, :discography, :performances, :testimonials, :contact])
      :service_provider ->
        order_sections(sections, [:hero, :services, :experience, :testimonials, :skills, :contact])
      _ ->
        order_sections(sections, [:hero, :about, :experience, :skills, :projects, :contact])
    end
  end

  # Private functions

  defp get_explicit_type(portfolio) do
    customization = portfolio.customization || %{}

    # Check for explicit user selection FIRST - this takes priority
    case Map.get(customization, "professional_type") do
      type when is_binary(type) and type != "" ->
        explicit_type = String.to_atom(type)
        IO.puts("🎯 Using EXPLICIT professional type: #{explicit_type}")
        explicit_type
      type when is_atom(type) ->
        IO.puts("🎯 Using EXPLICIT professional type: #{type}")
        type
      _ ->
        IO.puts("🔍 No explicit type found, will infer from content")
        nil
    end
  end

  defp infer_from_sections(portfolio) do
    sections = get_portfolio_sections(portfolio)
    section_types = Enum.map(sections, &normalize_section_type(&1.section_type))

    cond do
      has_developer_indicators?(sections, section_types) -> :developer
      has_creative_indicators?(sections, section_types) -> :creative
      has_musician_indicators?(sections, section_types) -> :musician
      has_service_provider_indicators?(sections, section_types) -> :service_provider
      true -> :professional
    end
  end

  defp has_developer_indicators?(sections, section_types) do
    # Check for code-specific sections
    code_sections = [:code_showcase, :projects] -- ([:code_showcase, :projects] -- section_types)

    cond do
      :code_showcase in section_types -> true
      length(code_sections) >= 1 && has_tech_keywords?(sections) -> true
      has_github_links?(sections) -> true
      true -> false
    end
  end

  defp has_creative_indicators?(sections, section_types) do
    creative_sections = [:media_showcase, :gallery, :portfolio] -- ([:media_showcase, :gallery, :portfolio] -- section_types)

    cond do
      :media_showcase in section_types && has_visual_media?(sections) -> true
      length(creative_sections) >= 2 -> true
      has_creative_keywords?(sections) -> true
      true -> false
    end
  end

  defp has_musician_indicators?(sections, section_types) do
    music_sections = [:media_showcase, :discography, :performances] -- ([:media_showcase, :discography, :performances] -- section_types)

    cond do
      has_audio_media?(sections) -> true
      has_music_keywords?(sections) -> true
      length(music_sections) >= 1 && has_music_content?(sections) -> true
      true -> false
    end
  end

  defp has_service_provider_indicators?(sections, section_types) do
    service_sections = [:services, :testimonials, :pricing] -- ([:services, :testimonials, :pricing] -- section_types)

    cond do
      :services in section_types -> true
      length(service_sections) >= 2 -> true
      has_service_keywords?(sections) -> true
      true -> false
    end
  end

  defp has_tech_keywords?(sections) do
    keywords = ["javascript", "python", "react", "node", "api", "database", "framework", "algorithm", "code", "programming", "software", "development"]
    content_text = get_all_content_text(sections)

    Enum.any?(keywords, fn keyword ->
      String.contains?(String.downcase(content_text), keyword)
    end)
  end

  defp has_creative_keywords?(sections) do
    keywords = ["design", "photography", "video", "art", "creative", "visual", "portfolio", "gallery", "film", "animation", "graphics"]
    content_text = get_all_content_text(sections)

    Enum.any?(keywords, fn keyword ->
      String.contains?(String.downcase(content_text), keyword)
    end)
  end

  defp has_music_keywords?(sections) do
    keywords = ["music", "musician", "song", "album", "band", "concert", "performance", "audio", "recording", "studio", "track", "remix"]
    content_text = get_all_content_text(sections)

    Enum.any?(keywords, fn keyword ->
      String.contains?(String.downcase(content_text), keyword)
    end)
  end

  defp has_service_keywords?(sections) do
    keywords = ["consulting", "service", "client", "business", "strategy", "solution", "professional", "expertise", "consulting"]
    content_text = get_all_content_text(sections)

    Enum.any?(keywords, fn keyword ->
      String.contains?(String.downcase(content_text), keyword)
    end)
  end

  defp has_visual_media?(sections) do
    Enum.any?(sections, fn section ->
      content = section.content || %{}
      has_images = Map.get(content, "images", []) != []
      has_gallery = Map.get(content, "gallery", []) != []
      has_media = Map.get(content, "media", []) != []

      has_images || has_gallery || has_media
    end)
  end

  defp has_audio_media?(sections) do
    Enum.any?(sections, fn section ->
      content = section.content || %{}
      has_audio_url = Map.get(content, "audio_url", "") != ""
      has_tracks = Map.get(content, "tracks", []) != []
      has_spotify = String.contains?(get_section_text(section), "spotify")

      has_audio_url || has_tracks || has_spotify
    end)
  end

  defp has_music_content?(sections) do
    Enum.any?(sections, fn section ->
      content = section.content || %{}
      section_text = get_section_text(section)

      has_discography = Map.has_key?(content, "discography")
      has_performances = Map.has_key?(content, "performances")
      mentions_music = String.contains?(String.downcase(section_text), "music")

      has_discography || has_performances || mentions_music
    end)
  end

  defp has_github_links?(sections) do
    content_text = get_all_content_text(sections)
    String.contains?(String.downcase(content_text), "github.com")
  end

  defp get_all_content_text(sections) do
    sections
    |> Enum.map(&get_section_text/1)
    |> Enum.join(" ")
  end

  defp get_section_text(section) do
    content = section.content || %{}

    [
      section.title || "",
      Map.get(content, "description", ""),
      Map.get(content, "content", ""),
      Map.get(content, "summary", ""),
      extract_nested_text(content)
    ]
    |> Enum.join(" ")
  end

  defp extract_nested_text(content) when is_map(content) do
    content
    |> Map.values()
    |> Enum.map(fn
      value when is_binary(value) -> value
      value when is_list(value) -> extract_list_text(value)
      value when is_map(value) -> extract_nested_text(value)
      _ -> ""
    end)
    |> Enum.join(" ")
  end
  defp extract_nested_text(_), do: ""

  defp extract_list_text(list) when is_list(list) do
    list
    |> Enum.map(fn
      item when is_binary(item) -> item
      item when is_map(item) -> extract_nested_text(item)
      _ -> ""
    end)
    |> Enum.join(" ")
  end

  defp get_portfolio_sections(portfolio) do
    case Map.get(portfolio, :sections) do
      sections when is_list(sections) -> sections
      %Ecto.Association.NotLoaded{} -> []
      _ -> []
    end
  end

  defp normalize_section_type(section_type) when is_atom(section_type), do: section_type
  defp normalize_section_type(section_type) when is_binary(section_type) do
    case section_type do
      "code_showcase" -> :code_showcase
      "media_showcase" -> :media_showcase
      "experience" -> :experience
      "projects" -> :projects
      "skills" -> :skills
      "services" -> :services
      "testimonials" -> :testimonials
      "hero" -> :hero
      "about" -> :about
      "contact" -> :contact
      "gallery" -> :gallery
      "portfolio" -> :portfolio
      "discography" -> :discography
      "performances" -> :performances
      "pricing" -> :pricing
      _ -> :custom
    end
  end
  defp normalize_section_type(_), do: :custom

  defp order_sections(sections, preferred_order) do
    # Create a map of section types to their preferred positions
    order_map = preferred_order
    |> Enum.with_index()
    |> Map.new(fn {type, index} -> {type, index} end)

    sections
    |> Enum.sort_by(fn section ->
      section_type = normalize_section_type(section.section_type)
      Map.get(order_map, section_type, 999)
    end)
  end
end
