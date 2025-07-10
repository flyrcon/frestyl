# lib/frestyl/portfolios/portfolio_section.ex - ENHANCED SCHEMA
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
      :custom,
      :story,
      :timeline,
      :narrative,
      :journey,
      :video_hero  # NEW: Video-specific hero block
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
    |> validate_content_structure()
    |> foreign_key_constraint(:portfolio_id)
  end

  @doc """
  Returns the default content structure for each section type with enhanced support for multiple entries
  """
  def default_content_for_type(:video_hero) do
    %{
      "headline" => "Welcome to My Portfolio",
      "subtitle" => "Discover my work through video",
      "video_url" => "",
      "video_type" => "upload", # "upload", "youtube", "vimeo"
      "poster_image" => "",
      "autoplay" => false,
      "show_controls" => true,
      "call_to_action" => %{
        "text" => "Learn More",
        "url" => "#about",
        "style" => "primary"
      },
      "overlay_text" => true,
      "video_settings" => %{
        "muted" => true,
        "loop" => false,
        "playsinline" => true
      }
    }
  end

  # Keep existing default_content_for_type functions...
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
      "availability" => "Available for new opportunities",
      "call_to_action" => "Let's connect and discuss opportunities"
    }
  end

  def default_content_for_type(:experience) do
    %{
      "jobs" => [
        %{
          "title" => "Your Current Position",
          "company" => "Company Name",
          "location" => "City, State/Country",
          "employment_type" => "Full-time",
          "start_date" => "Month Year",
          "end_date" => "",
          "current" => true,
          "description" => "Brief description of your role and key responsibilities.",
          "achievements" => [],
          "skills_used" => []
        }
      ]
    }
  end

  def default_content_for_type(:education) do
    %{
      "education" => [
        %{
          "degree" => "Bachelor of Science",
          "field" => "Your Field of Study",
          "institution" => "University Name",
          "location" => "City, State/Country",
          "start_date" => "Year",
          "end_date" => "Year",
          "status" => "Completed",
          "gpa" => "",
          "description" => "Relevant details about your educational experience.",
          "relevant_coursework" => [
            "Data Structures and Algorithms",
            "Database Systems",
            "Software Engineering"
          ],
          "activities" => [
            "Computer Science Club Member",
            "Dean's List (3 semesters)",
            "Undergraduate Research Assistant"
          ],
          "institution_logo" => "",
          "institution_url" => "",
          "thesis_title" => "",
          "advisor" => ""
        }
      ],
      "certifications" => [
        %{
          "name" => "Certification Name",
          "issuer" => "Issuing Organization",
          "date_earned" => "Month Year",
          "expiry_date" => "",
          "credential_id" => "",
          "verification_url" => ""
        }
      ]
    }
  end

  def default_content_for_type(:skills) do
    %{
      "skills" => [
        "JavaScript", "Python", "React", "Node.js", "SQL",
        "Git", "Docker", "AWS", "Problem Solving", "Team Leadership"
      ],
      "skill_categories" => %{
        "Programming Languages" => [
          %{"name" => "JavaScript", "proficiency" => "Expert", "years" => 5},
          %{"name" => "Python", "proficiency" => "Advanced", "years" => 4},
          %{"name" => "SQL", "proficiency" => "Advanced", "years" => 3}
        ],
        "Frameworks & Libraries" => [
          %{"name" => "React", "proficiency" => "Expert", "years" => 4},
          %{"name" => "Node.js", "proficiency" => "Advanced", "years" => 3},
          %{"name" => "Django", "proficiency" => "Intermediate", "years" => 2}
        ],
        "Tools & Platforms" => [
          %{"name" => "Git", "proficiency" => "Expert", "years" => 5},
          %{"name" => "Docker", "proficiency" => "Advanced", "years" => 2},
          %{"name" => "AWS", "proficiency" => "Intermediate", "years" => 2}
        ],
        "Soft Skills" => [
          %{"name" => "Team Leadership", "proficiency" => "Advanced", "years" => 3},
          %{"name" => "Problem Solving", "proficiency" => "Expert", "years" => 5},
          %{"name" => "Communication", "proficiency" => "Advanced", "years" => 4}
        ]
      },
      "skill_display_mode" => "categorized", # "flat" or "categorized"
      "show_proficiency" => true,
      "show_years" => true
    }
  end

  def default_content_for_type(:projects) do
    %{
      "projects" => [
        %{
          "title" => "Project Name",
          "description" => "Brief description of the project and its purpose.",
          "technologies" => ["React", "Node.js", "PostgreSQL"],
          "role" => "Full-Stack Developer",
          "start_date" => "Month Year",
          "end_date" => "Month Year",
          "status" => "Completed",
          "demo_url" => "",
          "github_url" => "",
          "featured_image" => "",
          "screenshots" => [],
          "team_size" => 1,
          "my_contribution" => "Led development and architecture decisions"
        }
      ]
    }
  end

  def default_content_for_type(:featured_project) do
    %{
      "title" => "Featured Project Name",
      "subtitle" => "Innovative solution for complex problem",
      "description" => "Comprehensive description of your most impressive project.",
      "challenge" => "The main challenge or problem this project addressed.",
      "solution" => "Your innovative approach to solving the challenge.",
      "technologies" => ["React", "Node.js", "PostgreSQL", "Docker", "AWS"],
      "role" => "Lead Full-Stack Developer",
      "timeline" => "6 months",
      "team_size" => 4,
      "impact" => "Delivered 40% performance improvement and enhanced user experience.",
      "key_insights" => [
        "Learned advanced optimization techniques",
        "Gained experience with microservices architecture",
        "Improved skills in agile project management"
      ],
      "demo_url" => "",
      "github_url" => "",
      "case_study_url" => "",
      "featured_image" => "",
      "gallery_images" => [],
      "metrics" => [
        %{"label" => "Performance Improvement", "value" => "40%"},
        %{"label" => "User Engagement", "value" => "+60%"},
        %{"label" => "Code Coverage", "value" => "95%"}
      ]
    }
  end

  def default_content_for_type(:case_study) do
    %{
      "client" => "Client/Company Name",
      "project_title" => "Project Title",
      "project_type" => "Web Application Development",
      "duration" => "3 months",
      "team_size" => 3,
      "my_role" => "Lead Developer",
      "overview" => "Executive summary of the project and its objectives.",
      "problem_statement" => "Clear definition of the business problem to be solved.",
      "target_audience" => "Description of the target users or stakeholders.",
      "constraints" => ["Budget: $50k", "Timeline: 3 months", "Legacy system integration"],
      "approach" => "Detailed methodology and approach to solving the problem.",
      "process" => [
        "Discovery and Requirements Gathering",
        "Design and Architecture Planning",
        "Development and Implementation",
        "Testing and Quality Assurance",
        "Deployment and Launch",
        "Post-launch Monitoring and Optimization"
      ],
      "technologies_used" => ["React", "Node.js", "PostgreSQL", "Docker", "AWS"],
      "challenges_faced" => [
        "Integration with legacy systems",
        "Performance optimization for large datasets",
        "Cross-browser compatibility issues"
      ],
      "solutions_implemented" => [
        "Developed custom API middleware for legacy integration",
        "Implemented data pagination and caching strategies",
        "Created comprehensive browser testing suite"
      ],
      "results" => "Measurable outcomes and business impact achieved.",
      "metrics" => [
        %{"label" => "Page Load Time", "value" => "2.3s", "improvement" => "-60%"},
        %{"label" => "User Satisfaction", "value" => "4.8/5", "improvement" => "+25%"},
        %{"label" => "Conversion Rate", "value" => "12%", "improvement" => "+35%"}
      ],
      "learnings" => "Key insights and lessons learned from the project.",
      "next_steps" => "Future recommendations and planned enhancements.",
      "testimonial" => %{
        "quote" => "Outstanding work and exceeded our expectations.",
        "author" => "Client Name",
        "title" => "Project Manager"
      }
    }
  end

  def default_content_for_type(:achievements) do
    %{
      "achievements" => [
        %{
          "title" => "Achievement Title",
          "description" => "Description of the achievement and its significance.",
          "date" => "Month Year",
          "organization" => "Awarding Organization",
          "category" => "Professional", # Professional, Academic, Personal, Award
          "verification_url" => "",
          "certificate_image" => ""
        }
      ],
      "categories" => ["Professional", "Academic", "Personal", "Awards", "Certifications"]
    }
  end

  def default_content_for_type(:testimonial) do
    %{
      "testimonials" => [
        %{
          "quote" => "This professional consistently delivers high-quality work and demonstrates exceptional problem-solving skills.",
          "name" => "Client Name",
          "title" => "Senior Manager",
          "company" => "Company Name",
          "relationship" => "Direct Supervisor", # Client, Colleague, Direct Supervisor, etc.
          "project" => "Project Name",
          "date" => "Month Year",
          "rating" => 5,
          "avatar_image" => "",
          "company_logo" => "",
          "verification_url" => ""
        }
      ],
      "display_settings" => %{
        "show_ratings" => true,
        "show_avatars" => true,
        "show_company_logos" => true,
        "layout" => "grid" # grid, carousel, list
      }
    }
  end

  def default_content_for_type(:media_showcase) do
    %{
      "title" => "Media Gallery",
      "description" => "A curated collection of visual work and project demonstrations.",
      "context" => "Context about when and why this media was created.",
      "what_to_notice" => "Key elements and details viewers should pay attention to.",
      "techniques_used" => ["Photography", "Video Editing", "Graphic Design"],
      "media_categories" => %{
        "Screenshots" => [],
        "Demonstrations" => [],
        "Process Documentation" => [],
        "Final Results" => []
      },
      "layout_settings" => %{
        "gallery_type" => "masonry", # grid, masonry, carousel
        "items_per_row" => 3,
        "show_captions" => true,
        "enable_lightbox" => true
      }
    }
  end

  def default_content_for_type(:code_showcase) do
    %{
      "title" => "Code Example",
      "description" => "Demonstration of coding skills and problem-solving approach.",
      "language" => "JavaScript",
      "code_snippet" => "",
      "key_features" => [
        "Clean, readable code structure",
        "Efficient algorithm implementation",
        "Comprehensive error handling"
      ],
      "explanation" => "Detailed explanation of the code logic and design decisions.",
      "line_highlights" => [
        %{"line" => 5, "note" => "Key algorithm implementation"},
        %{"line" => 12, "note" => "Error handling logic"}
      ],
      "repository_url" => "",
      "live_demo_url" => "",
      "complexity_analysis" => %{
        "time_complexity" => "O(n)",
        "space_complexity" => "O(1)"
      },
      "test_cases" => [
        %{"input" => "example input", "output" => "expected output", "description" => "Basic test case"}
      ]
    }
  end

  def default_content_for_type(:contact) do
    %{
      "primary_email" => "",
      "secondary_email" => "",
      "phone" => "",
      "location" => %{
        "city" => "",
        "state" => "",
        "country" => "",
        "timezone" => ""
      },
      "availability" => %{
        "status" => "Available for new opportunities",
        "preferred_contact_method" => "email",
        "response_time" => "Within 24 hours",
        "working_hours" => "9 AM - 6 PM EST",
        "open_to" => ["Full-time", "Contract", "Consulting"]
      },
      "social_links" => %{
        "linkedin" => "",
        "github" => "",
        "twitter" => "",
        "portfolio" => "",
        "blog" => "",
        "dribbble" => "",
        "behance" => ""
      },
      "professional_profiles" => %{
        "stackoverflow" => "",
        "codepen" => "",
        "medium" => "",
        "dev_to" => ""
      },
      "contact_form_enabled" => false,
      "calendly_url" => "",
      "resume_download_enabled" => true
    }
  end

  def default_content_for_type(:custom) do
    %{
      "title" => "Custom Section",
      "content" => "Add your custom content here using rich text formatting.",
      "layout" => "default",
      "custom_fields" => %{},
      "styling" => %{
        "background_color" => "",
        "text_color" => "",
        "custom_css" => ""
      }
    }
  end

  def default_content_for_type(_), do: %{}

  # Validation for content structure based on section type
  defp validate_content_structure(changeset) do
    case get_change(changeset, :section_type) do
      nil -> changeset
      section_type -> validate_content_for_type(changeset, section_type)
    end
  end

  defp validate_content_for_type(changeset, :experience) do
    validate_change(changeset, :content, fn :content, content ->
      case content do
        %{"jobs" => jobs} when is_list(jobs) ->
          validate_jobs_structure(jobs)
        _ ->
          [{:content, "must contain a 'jobs' list for experience sections"}]
      end
    end)
  end

  defp validate_content_for_type(changeset, :education) do
    validate_change(changeset, :content, fn :content, content ->
      case content do
        %{"education" => education} when is_list(education) ->
          validate_education_structure(education)
        _ ->
          [{:content, "must contain an 'education' list for education sections"}]
      end
    end)
  end

  defp validate_content_for_type(changeset, :skills) do
    validate_change(changeset, :content, fn :content, content ->
      case content do
        %{"skills" => skills} when is_list(skills) ->
          []
        _ ->
          [{:content, "must contain a 'skills' list for skills sections"}]
      end
    end)
  end

  defp validate_content_for_type(changeset, _), do: changeset

  defp validate_jobs_structure(jobs) do
    Enum.with_index(jobs)
    |> Enum.flat_map(fn {job, index} ->
      case job do
        %{"title" => title, "company" => company} when is_binary(title) and is_binary(company) ->
          []
        _ ->
          [{:content, "job at index #{index} must have title and company fields"}]
      end
    end)
  end

  defp validate_education_structure(education) do
    Enum.with_index(education)
    |> Enum.flat_map(fn {edu, index} ->
      case edu do
        %{"degree" => degree, "institution" => institution} when is_binary(degree) and is_binary(institution) ->
          []
        _ ->
          [{:content, "education at index #{index} must have degree and institution fields"}]
      end
    end)
  end

    defp validate_content_structure(changeset) do
    case get_field(changeset, :section_type) do
      :video_hero ->
        validate_video_hero_content(changeset)
      _ ->
        changeset
    end
  end

  defp validate_video_hero_content(changeset) do
    content = get_field(changeset, :content) || %{}

    cond do
      is_external_video?(content) ->
        validate_external_video_content(changeset, content)
      is_upload_video?(content) ->
        validate_upload_video_content(changeset, content)
      true ->
        add_error(changeset, :content, "Video hero must have valid video source")
    end
  end

  defp is_external_video?(content) do
    video_type = Map.get(content, "video_type", "")
    video_type in ["youtube", "vimeo"] and Map.has_key?(content, "video_url")
  end

  defp is_upload_video?(content) do
    video_type = Map.get(content, "video_type", "")
    video_type == "upload"
  end

  defp validate_external_video_content(changeset, content) do
    video_url = Map.get(content, "video_url", "")

    cond do
      String.contains?(video_url, "youtube.com") or String.contains?(video_url, "youtu.be") ->
        changeset
      String.contains?(video_url, "vimeo.com") ->
        changeset
      video_url == "" ->
        changeset  # Allow empty for drafts
      true ->
        add_error(changeset, :content, "Invalid external video URL")
    end
  end

  defp validate_upload_video_content(changeset, _content) do
    # Upload validation will be handled in the media upload process
    changeset
  end

end
