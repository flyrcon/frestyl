# lib/frestyl/portfolios/enhanced_section_system.ex

defmodule Frestyl.Portfolios.EnhancedSectionSystem do
  @moduledoc """
  Enhanced section system with categorized sections for resume export
  and improved field definitions with proper multi-item support.
  """

  # Complete section type definitions with categories
  @section_types %{
    # ESSENTIAL SECTIONS (Resume Export Priority)
    "hero" => %{
      name: "Hero Section",
      description: "Main introduction with contact info and professional title",
      icon: "🏠",
      category: "essential",
      supports_video: true,
      supports_media: [:video, :image],
      supports_multiple: false,
      is_hero: true,
      fields: %{
        headline: %{type: :string, required: true, placeholder: "Your Name"},
        tagline: %{type: :string, required: true, placeholder: "Professional Title"},
        description: %{type: :text, placeholder: "Brief introduction about yourself"},
        cta_text: %{type: :string, placeholder: "Get In Touch"},
        cta_link: %{type: :string, placeholder: "mailto:you@example.com"},
        video_url: %{type: :string, placeholder: "Video introduction URL"},
        video_type: %{type: :select, options: ["none", "upload", "youtube", "vimeo"], default: "none"},
        background_image: %{type: :file, accepts: "image/*"},
        social_links: %{type: :map, default: %{"linkedin" => "", "github" => "", "twitter" => "", "website" => ""}},
        contact_info: %{type: :map, default: %{"email" => "", "phone" => "", "location" => ""}}
      }
    },

    "contact" => %{
      name: "Contact Information",
      description: "Essential contact details and social links",
      icon: "📞",
      category: "essential",
      supports_multiple: false,
      fields: %{
        email: %{type: :string, required: true, placeholder: "your@email.com"},
        phone: %{type: :string, placeholder: "+1 (555) 123-4567"},
        location: %{type: :string, placeholder: "City, State"},
        availability: %{type: :text, placeholder: "Available for new projects"},
        timezone: %{type: :string, placeholder: "EST, PST, etc."},
        preferred_contact: %{type: :select, options: ["Email", "Phone", "LinkedIn"], default: "Email"},
        social_links: %{
          type: :map,
          default: %{
            "linkedin" => "",
            "github" => "",
            "twitter" => "",
            "website" => "",
            "behance" => "",
            "dribbble" => ""
          }
        }
      }
    },

    "experience" => %{
      name: "Work Experience",
      description: "Professional work history with detailed accomplishments",
      icon: "💼",
      category: "essential",
      supports_multiple: true,
      fields: %{
        items: %{
          type: :items,
          required: true,
          item_schema: %{
            title: %{type: :string, required: true, placeholder: "Job Title"},
            company: %{type: :string, required: true, placeholder: "Company Name"},
            start_date: %{type: :date, required: true, placeholder: "MM/YYYY"},
            end_date: %{type: :date, placeholder: "MM/YYYY or 'Present'"},
            location: %{type: :string, placeholder: "City, State"},
            description: %{type: :text, placeholder: "Role description and key achievements"},
            technologies: %{type: :array, placeholder: "Technologies, tools, frameworks used"},
            achievements: %{type: :array, placeholder: "Specific accomplishments and results"},
            employment_type: %{type: :select, options: ["Full-time", "Part-time", "Contract", "Freelance", "Internship"], default: "Full-time"}
          }
        }
      }
    },

    "education" => %{
      name: "Education",
      description: "Academic background and qualifications",
      icon: "🎓",
      category: "essential",
      supports_multiple: true,
      fields: %{
        items: %{
          type: :items,
          required: true,
          item_schema: %{
            degree: %{type: :string, required: true, placeholder: "Degree Title"},
            institution: %{type: :string, required: true, placeholder: "School/University Name"},
            field_of_study: %{type: :string, placeholder: "Major/Field of Study"},
            graduation_date: %{type: :date, placeholder: "MM/YYYY"},
            gpa: %{type: :string, placeholder: "3.8/4.0 (optional)"},
            honors: %{type: :array, placeholder: "Dean's List, Magna Cum Laude, etc."},
            relevant_coursework: %{type: :array, placeholder: "Key courses relevant to your career"},
            activities: %{type: :array, placeholder: "Clubs, societies, leadership roles"}
          }
        }
      }
    },

    "skills" => %{
      name: "Skills & Expertise",
      description: "Technical and professional skills with proficiency levels",
      icon: "⚡",
      category: "essential",
      supports_multiple: true,
      fields: %{
        items: %{
          type: :items,
          required: true,
          item_schema: %{
            skill_name: %{type: :string, required: true, placeholder: "Skill name"},
            proficiency: %{type: :select, required: true, options: ["Beginner", "Intermediate", "Advanced", "Expert"], default: "Intermediate"},
            category: %{type: :select, options: ["Technical", "Soft Skills", "Tools", "Languages", "Frameworks"], default: "Technical"},
            years_experience: %{type: :integer, placeholder: "Years using this skill"},
            last_used: %{type: :date, placeholder: "MM/YYYY"},
            certification: %{type: :string, placeholder: "Related certification (optional)"}
          }
        }
      }
    },

    # PROFESSIONAL SECTIONS
    "projects" => %{
      name: "Portfolio Projects",
      description: "Showcase of work and projects with code examples",
      icon: "🚀",
      category: "professional",
      supports_multiple: true,
      supports_media: [:image, :video],
      fields: %{
        items: %{
          type: :items,
          required: true,
          item_schema: %{
            title: %{type: :string, required: true, placeholder: "Project Name"},
            description: %{type: :text, required: true, placeholder: "Detailed project description"},
            technologies: %{type: :array, placeholder: "Tech stack: React, Node.js, PostgreSQL"},
            project_url: %{type: :string, placeholder: "https://live-demo.com"},
            github_url: %{type: :string, placeholder: "https://github.com/user/repo"},
            image: %{type: :file, accepts: "image/*"},
            start_date: %{type: :date, placeholder: "MM/YYYY"},
            end_date: %{type: :date, placeholder: "MM/YYYY"},
            status: %{type: :select, options: ["Completed", "In Progress", "Planned", "Archived"], default: "Completed"},
            client: %{type: :string, placeholder: "Client name (if applicable)"},
            role: %{type: :string, placeholder: "Your role in the project"},
            methodology: %{type: :select, options: ["Agile", "Scrum", "Kanban", "Waterfall", "Lean", "Custom"], placeholder: "Project methodology"},
            code_excerpt: %{type: :text, placeholder: "Key code snippet or algorithm (optional)"},
            code_language: %{type: :string, placeholder: "JavaScript, Python, etc."},
            project_type: %{type: :select, options: ["Web App", "Mobile App", "API", "Library", "Tool", "Website", "Desktop App", "Game", "Other"], placeholder: "Project type"}
          }
        }
      }
    },

    "certifications" => %{
      name: "Certifications & Awards",
      description: "Professional certifications, awards, and recognition",
      icon: "🏆",
      category: "professional",
      supports_multiple: true,
      fields: %{
        items: %{
          type: :items,
          required: true,
          item_schema: %{
            title: %{type: :string, required: true, placeholder: "Certification/Award Title"},
            issuing_organization: %{type: :string, required: true, placeholder: "Issuing Organization"},
            issue_date: %{type: :date, placeholder: "MM/YYYY"},
            expiry_date: %{type: :date, placeholder: "MM/YYYY (if applicable)"},
            credential_id: %{type: :string, placeholder: "Certificate ID/Number"},
            credential_url: %{type: :string, placeholder: "Verification URL"},
            badge_image: %{type: :file, accepts: "image/*"},
            description: %{type: :text, placeholder: "Additional details about the certification"},
            skills_covered: %{type: :array, placeholder: "Skills/topics covered"}
          }
        }
      }
    },

    "services" => %{
      name: "Services Offered",
      description: "Professional services you provide to clients",
      icon: "🛠️",
      category: "professional",
      supports_multiple: true,
      fields: %{
        items: %{
          type: :items,
          required: true,
          item_schema: %{
            title: %{type: :string, required: true, placeholder: "Service Name"},
            description: %{type: :text, required: true, placeholder: "Detailed service description"},
            pricing: %{type: :string, placeholder: "Starting at $X or 'Contact for quote'"},
            duration: %{type: :string, placeholder: "Timeline estimate"},
            features: %{type: :array, placeholder: "What's included in this service"},
            icon: %{type: :string, placeholder: "Icon class or emoji"},
            category: %{type: :string, placeholder: "Service category"},
            delivery_method: %{type: :select, options: ["Remote", "On-site", "Hybrid"], default: "Remote"}
          }
        }
      }
    },

    # PERSONAL SECTIONS
    "intro" => %{
      name: "About/Introduction",
      description: "Personal story, background, and professional narrative",
      icon: "👋",
      category: "personal",
      supports_multiple: false,
      supports_media: [:image],
      fields: %{
        story: %{type: :text, required: true, placeholder: "Tell your professional story..."},
        highlights: %{type: :array, placeholder: "Key career highlights and achievements"},
        years_experience: %{type: :integer, placeholder: "Total years of experience"},
        specialties: %{type: :array, placeholder: "Areas of expertise and focus"},
        personal_photo: %{type: :file, accepts: "image/*"},
        mission_statement: %{type: :text, placeholder: "Your professional mission or vision"},
        fun_facts: %{type: :array, placeholder: "Interesting personal facts"}
      }
    },

    "testimonials" => %{
      name: "Client Testimonials",
      description: "Reviews and recommendations from clients and colleagues",
      icon: "💬",
      category: "personal",
      supports_multiple: true,
      fields: %{
        items: %{
          type: :items,
          required: true,
          item_schema: %{
            content: %{type: :text, required: true, placeholder: "Testimonial content"},
            author_name: %{type: :string, required: true, placeholder: "Client/Colleague Name"},
            author_title: %{type: :string, placeholder: "Their job title"},
            author_company: %{type: :string, placeholder: "Their company"},
            author_photo: %{type: :file, accepts: "image/*"},
            project_name: %{type: :string, placeholder: "Related project (optional)"},
            rating: %{type: :integer, placeholder: "1-5 star rating (optional)"},
            date: %{type: :date, placeholder: "MM/YYYY"},
            relationship: %{type: :select, options: ["Client", "Colleague", "Manager", "Direct Report", "Vendor"], default: "Client"}
          }
        }
      }
    },

    "volunteer" => %{
      name: "Volunteer Experience",
      description: "Community involvement and volunteer work",
      icon: "🤝",
      category: "personal",
      supports_multiple: true,
      fields: %{
        items: %{
          type: :items,
          required: true,
          item_schema: %{
            organization: %{type: :string, required: true, placeholder: "Organization Name"},
            role: %{type: :string, required: true, placeholder: "Volunteer Role/Position"},
            start_date: %{type: :date, placeholder: "MM/YYYY"},
            end_date: %{type: :date, placeholder: "MM/YYYY or 'Present'"},
            description: %{type: :text, placeholder: "What you did and how you contributed"},
            cause: %{type: :string, placeholder: "Cause area (e.g., Education, Environment)"},
            impact: %{type: :text, placeholder: "Impact you made or results achieved"},
            hours: %{type: :string, placeholder: "Time commitment (e.g., '10 hours/month')"},
            skills_used: %{type: :array, placeholder: "Skills you applied in this role"}
          }
        }
      }
    },

    "writing" => %{
      name: "Blog Posts & Articles",
      description: "Published writing and thought leadership content",
      icon: "✍️",
      category: "personal",
      supports_multiple: true,
      fields: %{
        items: %{
          type: :items,
          required: true,
          item_schema: %{
            title: %{type: :string, required: true, placeholder: "Article Title"},
            url: %{type: :string, required: true, placeholder: "Article URL"},
            publication: %{type: :string, placeholder: "Publication/Platform name"},
            publish_date: %{type: :date, placeholder: "MM/YYYY"},
            excerpt: %{type: :text, placeholder: "Brief summary or excerpt"},
            tags: %{type: :array, placeholder: "Topics, technologies, themes"},
            featured_image: %{type: :file, accepts: "image/*"},
            read_time: %{type: :string, placeholder: "5 min read"},
            views: %{type: :integer, placeholder: "View count (optional)"}
          }
        }
      }
    },

    # FLEXIBLE SECTIONS
    "custom" => %{
      name: "Custom Section",
      description: "User-defined section with flexible content structure",
      icon: "🔧",
      category: "flexible",
      supports_multiple: true,
      fields: %{
        section_title: %{type: :string, required: true, placeholder: "Custom Section Name"},
        items: %{
          type: :items,
          required: true,
          item_schema: %{
            title: %{type: :string, required: true, placeholder: "Item Title"},
            content: %{type: :text, placeholder: "Item content or description"},
            link: %{type: :string, placeholder: "Related URL (optional)"},
            date: %{type: :date, placeholder: "MM/YYYY (optional)"},
            tags: %{type: :array, placeholder: "Tags or categories"},
            image: %{type: :file, accepts: "image/*"},
            additional_info: %{type: :text, placeholder: "Any additional information"}
          }
        }
      }
    }
  }

  # Public API Functions
  def get_section_config(section_type) when is_binary(section_type) do
    Map.get(@section_types, section_type, %{})
  end
  def get_section_config(section_type) when is_atom(section_type) do
    get_section_config(Atom.to_string(section_type))
  end

  def get_section_fields(section_type) do
    case get_section_config(section_type) do
      %{fields: fields} -> fields
      _ -> %{}
    end
  end

  def get_all_section_types do
    Map.keys(@section_types)
  end

  def supports_multiple?(section_type) do
    case get_section_config(section_type) do
      %{supports_multiple: true} -> true
      _ -> false
    end
  end

  def supports_media?(section_type) do
    case get_section_config(section_type) do
      %{supports_media: media_types} when is_list(media_types) -> true
      _ -> false
    end
  end

  def is_hero_section?(section_type) do
    case get_section_config(section_type) do
      %{is_hero: true} -> true
      _ -> false
    end
  end

  def get_sections_by_category(category \\ nil) do
    if category do
      @section_types
      |> Enum.filter(fn {_key, config} -> Map.get(config, :category) == category end)
      |> Enum.into(%{})
    else
      @section_types
      |> Enum.group_by(fn {_key, config} -> Map.get(config, :category, "other") end)
    end
  end

  def get_essential_sections do
    get_sections_by_category("essential")
  end

  def get_resume_export_sections do
    # Return sections in resume priority order
    essential_sections = get_essential_sections()

    # Specific order for resume export
    resume_order = ["hero", "contact", "experience", "education", "skills"]

    resume_order
    |> Enum.map(fn section_type -> {section_type, Map.get(essential_sections, section_type)} end)
    |> Enum.reject(fn {_type, config} -> is_nil(config) end)
    |> Enum.into(%{})
  end

  def validate_section_content(section_type, content) do
    fields = get_section_fields(section_type)
    validate_fields(content, fields)
  end

  defp validate_fields(content, fields) do
    Enum.reduce(fields, %{valid: true, errors: []}, fn {field_name, field_config}, acc ->
      field_value = Map.get(content, Atom.to_string(field_name))

      case validate_field(field_value, field_config, field_name) do
        :ok -> acc
        {:error, message} ->
          %{acc | valid: false, errors: [{field_name, message} | acc.errors]}
      end
    end)
  end

  defp validate_field(nil, %{required: true}, _field_name), do: {:error, "is required"}
  defp validate_field("", %{required: true}, _field_name), do: {:error, "is required"}
  defp validate_field([], %{required: true}, _field_name), do: {:error, "is required"}
  defp validate_field(%{"items" => []}, %{required: true}, _field_name), do: {:error, "must have at least one item"}

  # Type validations
  defp validate_field(value, %{type: :string}, _field_name) when not is_binary(value), do: {:error, "must be text"}
  defp validate_field(value, %{type: :integer}, _field_name) when not is_integer(value) and not is_nil(value), do: {:error, "must be a number"}
  defp validate_field(value, %{type: :boolean}, _field_name) when not is_boolean(value), do: {:error, "must be true or false"}
  defp validate_field(value, %{type: :array}, _field_name) when not is_list(value), do: {:error, "must be a list"}
  defp validate_field(value, %{type: :map}, _field_name) when not is_map(value), do: {:error, "must be a map"}

  # Items validation
  defp validate_field(%{"items" => items}, %{type: :items, item_schema: item_schema}, field_name) when is_list(items) do
    validate_items(items, item_schema, field_name)
  end
  defp validate_field(items, %{type: :items, item_schema: item_schema}, field_name) when is_list(items) do
    validate_items(items, item_schema, field_name)
  end
  defp validate_field(_value, %{type: :items}, _field_name), do: {:error, "must be a list of items"}

  # Default case - field is valid
  defp validate_field(_value, _config, _field_name), do: :ok

  defp validate_items(items, item_schema, _field_name) do
    validation_results = Enum.with_index(items)
    |> Enum.map(fn {item, index} ->
      validate_item(item, item_schema, index)
    end)

    errors = validation_results
    |> Enum.flat_map(fn
      {:error, errors} -> errors
      :ok -> []
    end)

    if errors == [] do
      :ok
    else
      {:error, "items validation failed: #{Enum.join(errors, ", ")}"}
    end
  end

  defp validate_item(item, item_schema, index) when is_map(item) do
    item_errors = Enum.reduce(item_schema, [], fn {item_field_name, item_field_config}, acc ->
      item_field_value = Map.get(item, Atom.to_string(item_field_name))

      case validate_field(item_field_value, item_field_config, item_field_name) do
        :ok -> acc
        {:error, message} -> ["item #{index} #{item_field_name}: #{message}" | acc]
      end
    end)

    if item_errors == [] do
      :ok
    else
      {:error, item_errors}
    end
  end
  defp validate_item(_item, _item_schema, index), do: {:error, ["item #{index}: must be a map"]}

  def get_default_content(section_type) do
    fields = get_section_fields(section_type)

    Enum.reduce(fields, %{}, fn {field_name, field_config}, acc ->
      default_value = get_field_default_value(field_config)
      Map.put(acc, Atom.to_string(field_name), default_value)
    end)
  end

  defp get_field_default_value(field_config) do
    case field_config do
      %{default: default} -> default
      %{type: :string} -> ""
      %{type: :text} -> ""
      %{type: :array} -> []
      %{type: :map} -> %{}
      %{type: :boolean} -> false
      %{type: :integer} -> nil
      %{type: :items} -> %{"items" => []}
      %{type: :file} -> ""
      %{type: :date} -> ""
      %{type: :select, options: [first_option | _]} -> first_option
      %{type: :select} -> ""
      _ -> nil
    end
  end

  def get_section_categories do
    @section_types
    |> Enum.map(fn {_key, config} -> Map.get(config, :category, "other") end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  def get_category_display_name(category) do
    case category do
      "essential" -> "Essential"
      "professional" -> "Professional"
      "personal" -> "Personal"
      "flexible" -> "Custom"
      _ -> String.capitalize(category)
    end
  end

  def get_category_description(category) do
    case category do
      "essential" -> "Core sections for resumes and professional profiles"
      "professional" -> "Work-related sections showcasing expertise and achievements"
      "personal" -> "Personal branding and community involvement sections"
      "flexible" -> "Customizable sections for unique content"
      _ -> "Additional portfolio sections"
    end
  end

  def get_category_icon(category) do
    case category do
      "essential" -> "⭐"
      "professional" -> "💼"
      "personal" -> "👤"
      "flexible" -> "🔧"
      _ -> "📄"
    end
  end

  # Helper function to determine if a section should be shown in resume export
  def is_resume_section?(section_type) do
    case get_section_config(section_type) do
      %{category: "essential"} -> true
      _ -> false
    end
  end

  # Helper function to get sections in display order
  def get_sections_in_display_order do
    # Define preferred display order by category and within category
    section_order = [
      # Essential sections first (resume order)
      "hero", "contact", "intro", "experience", "education", "skills",
      # Professional sections
      "projects", "certifications", "services",
      # Personal sections
      "testimonials", "volunteer", "writing",
      # Flexible sections
      "custom"
    ]

    section_order
    |> Enum.map(fn section_type ->
      {section_type, Map.get(@section_types, section_type)}
    end)
    |> Enum.reject(fn {_type, config} -> is_nil(config) end)
    |> Enum.into(%{})
  end

  # Function to get field requirements for frontend validation
  def get_field_requirements(section_type) do
    fields = get_section_fields(section_type)

    Enum.reduce(fields, %{}, fn {field_name, field_config}, acc ->
      requirements = %{
        type: Map.get(field_config, :type, :string),
        required: Map.get(field_config, :required, false),
        placeholder: Map.get(field_config, :placeholder, ""),
        options: Map.get(field_config, :options, [])
      }

      # Add item schema for items fields
      requirements = if Map.get(field_config, :type) == :items do
        Map.put(requirements, :item_schema, Map.get(field_config, :item_schema, %{}))
      else
        requirements
      end

      Map.put(acc, field_name, requirements)
    end)
  end

  # Function to check if a section type exists
  def section_exists?(section_type) do
    Map.has_key?(@section_types, to_string(section_type))
  end

  # Function to get section display priority (lower number = higher priority)
  def get_section_priority(section_type) do
    case section_type do
      "hero" -> 1
      "contact" -> 2
      "intro" -> 3
      "experience" -> 4
      "education" -> 5
      "skills" -> 6
      "projects" -> 7
      "certifications" -> 8
      "services" -> 9
      "testimonials" -> 10
      "volunteer" -> 11
      "writing" -> 12
      "custom" -> 13
      _ -> 99
    end
  end
end
