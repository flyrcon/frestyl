# Replace your portfolio_section.ex schema definition with this:

defmodule Frestyl.Portfolios.PortfolioSection do
  use Ecto.Schema
  import Ecto.Changeset

  schema "portfolio_sections" do
    field :title, :string
    field :section_type, Ecto.Enum, values: [
      :intro,
      :experience,
      :education,
      :skills,
      :projects,
      :featured_project,
      :case_study,
      :achievements,
      :testimonial,
      :media_showcase,
      :code_showcase,
      :contact,
      :custom
    ]
    field :content, :map
    field :position, :integer
    field :visible, :boolean, default: true

    belongs_to :portfolio, Frestyl.Portfolios.Portfolio
    has_many :portfolio_media, Frestyl.Portfolios.PortfolioMedia, foreign_key: :section_id

    timestamps()
  end

  def changeset(section, attrs) do
    section
    |> cast(attrs, [:title, :section_type, :content, :position, :visible, :portfolio_id])
    |> validate_required([:title, :section_type, :portfolio_id])
    |> validate_length(:title, max: 100)
    |> foreign_key_constraint(:portfolio_id)
  end

  @doc """
  Returns the default content structure for each section type
  """
  def default_content_for_type(:intro) do
    %{
      "headline" => "Hello, I'm [Your Name]",
      "summary" => "A brief introduction about yourself and your professional journey.",
      "location" => "",
      "website" => "",
      "social_links" => %{
        "linkedin" => "",
        "github" => "",
        "twitter" => "",
        "portfolio" => ""
      },
      "availability" => "",
      "call_to_action" => ""
    }
  end

  def default_content_for_type(:experience) do
    %{
      "jobs" => []
    }
  end

  def default_content_for_type(:education) do
    %{
      "education" => []
    }
  end

  def default_content_for_type(:skills) do
    %{
      "skills" => []
    }
  end

  def default_content_for_type(:projects) do
    %{
      "projects" => []
    }
  end

  def default_content_for_type(:featured_project) do
    %{
      "title" => "",
      "description" => "",
      "challenge" => "",
      "solution" => "",
      "technologies" => [],
      "role" => "",
      "timeline" => "",
      "impact" => "",
      "key_insights" => [],
      "demo_url" => "",
      "github_url" => ""
    }
  end

  def default_content_for_type(:case_study) do
    %{
      "client" => "",
      "project_title" => "",
      "overview" => "",
      "problem_statement" => "",
      "approach" => "",
      "process" => [],
      "results" => "",
      "metrics" => [],
      "learnings" => "",
      "next_steps" => ""
    }
  end

  def default_content_for_type(:achievements) do
    %{
      "achievements" => []
    }
  end

  def default_content_for_type(:testimonial) do
    %{
      "testimonials" => []
    }
  end

  def default_content_for_type(:media_showcase) do
    %{
      "title" => "",
      "description" => "",
      "context" => "",
      "what_to_notice" => "",
      "techniques_used" => []
    }
  end

  def default_content_for_type(:code_showcase) do
    %{
      "title" => "",
      "description" => "",
      "language" => "",
      "key_features" => [],
      "explanation" => "",
      "line_highlights" => [],
      "repository_url" => ""
    }
  end

  def default_content_for_type(:contact) do
    %{
      "email" => "",
      "phone" => "",
      "location" => "",
      "availability" => "",
      "preferred_contact" => "email",
      "timezone" => "",
      "response_time" => "",
      "social_links" => %{}
    }
  end

  def default_content_for_type(:custom) do
    %{
      "title" => "",
      "content" => "",
      "layout" => "default",
      "custom_fields" => %{}
    }
  end

  def default_content_for_type(_), do: %{}
end
