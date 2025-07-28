# lib/frestyl_web/live/portfolio_live/renderers/section_renderer_factory.ex

defmodule FrestylWeb.PortfolioLive.Renderers.SectionRendererFactory do
  @moduledoc """
  Factory for creating appropriate section renderers based on section type and professional context
  """

  alias FrestylWeb.PortfolioLive.Renderers.{
    CodeShowcaseRenderer,
    ExperienceRenderer,
    SkillsRenderer,
    ProjectsRenderer,
    DefaultRenderer
  }

  def get_renderer(section_type, professional_type \\ :professional) do
    case {section_type, professional_type} do
      {:code_showcase, _} -> CodeShowcaseRenderer
      {:experience, :developer} -> ExperienceRenderer.DeveloperStyle
      {:experience, :creative} -> ExperienceRenderer.CreativeStyle
      {:skills, :developer} -> SkillsRenderer.TechStackStyle
      {:skills, :creative} -> SkillsRenderer.CreativeToolsStyle
      {:projects, :developer} -> ProjectsRenderer.RepositoryStyle
      {:projects, :creative} -> ProjectsRenderer.FilmographyStyle
      _ -> DefaultRenderer
    end
  end

  def render_section(section, professional_type, layout_style \\ "standard") do
    renderer = get_renderer(section.section_type, professional_type)
    renderer.render(section, layout_style)
  end
end
