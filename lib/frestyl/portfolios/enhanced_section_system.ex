# lib/frestyl/portfolios/enhanced_section_system.ex

defmodule Frestyl.Portfolios.EnhancedSectionSystem do
  @moduledoc """
  Consolidated section system with 17 core section types.
  Provides configuration, validation, and default content for portfolio sections.
  """


  # ============================================================================
  # CONSOLIDATED SECTION TYPES - 17 Core Types
  # ============================================================================

  @section_types %{
    # ESSENTIAL SECTIONS
    "hero" => %{
      name: "Hero Section",
      description: "Main landing page section with video support, CTAs, and social links",
      icon: "🏠",
      category: "essential",
      is_hero: true,
      supports_multiple: false,
      supports_media: ["image", "video"],
      fields: %{
        headline: %{type: :string, required: true, placeholder: "Welcome to My Portfolio"},
        tagline: %{type: :string, required: true, placeholder: "Your professional tagline"},
        description: %{type: :text, placeholder: "Brief description of what you do"},
        cta_text: %{type: :string, placeholder: "Get Started"},
        cta_link: %{type: :string, placeholder: "#contact"},
        video_url: %{type: :string, placeholder: "YouTube/Vimeo URL or upload"},
        video_type: %{type: :select, options: ["none", "youtube", "vimeo", "upload"], default: "none"},
        background_image: %{type: :file, accepts: "image/*"},
        social_links: %{
          type: :map,
          fields: %{
            linkedin: %{type: :string, placeholder: "LinkedIn URL"},
            github: %{type: :string, placeholder: "GitHub URL"},
            twitter: %{type: :string, placeholder: "Twitter URL"},
            website: %{type: :string, placeholder: "Personal website"}
          }
        },
        contact_info: %{
          type: :map,
          fields: %{
            email: %{type: :string, placeholder: "your@email.com"},
            phone: %{type: :string, placeholder: "+1 (555) 123-4567"},
            location: %{type: :string, placeholder: "City, State"}
          }
        }
      }
    },

    "intro" => %{
      name: "Introduction",
      description: "Personal and professional story, background, and key highlights",
      icon: "👋",
      category: "essential",
      supports_multiple: false,
      supports_media: ["image"],
      fields: %{
        story: %{type: :text, required: true, placeholder: "Tell your professional story..."},
        highlights: %{type: :array, placeholder: "Key achievements, separated by commas"},
        personality_traits: %{type: :array, placeholder: "Creative, analytical, collaborative"},
        fun_facts: %{type: :array, placeholder: "Interesting facts about you"},
        specialties: %{type: :array, placeholder: "Areas of expertise"},
        years_experience: %{type: :integer, placeholder: "Years of experience"},
        current_focus: %{type: :string, placeholder: "What you're working on now"}
      }
    },

    "contact" => %{
      name: "Contact Information",
      description: "Contact details, social media, and communication preferences",
      icon: "📞",
      category: "essential",
      supports_multiple: false,
      supports_media: [],
      fields: %{
        email: %{type: :string, required: true, placeholder: "your@email.com"},
        phone: %{type: :string, placeholder: "+1 (555) 123-4567"},
        location: %{type: :string, placeholder: "City, State, Country"},
        availability: %{type: :string, placeholder: "Available for new projects"},
        social_links: %{
          type: :map,
          fields: %{
            linkedin: %{type: :string, placeholder: "LinkedIn profile"},
            github: %{type: :string, placeholder: "GitHub profile"},
            twitter: %{type: :string, placeholder: "Twitter handle"},
            website: %{type: :string, placeholder: "Personal website"},
            behance: %{type: :string, placeholder: "Behance portfolio"},
            dribbble: %{type: :string, placeholder: "Dribbble profile"}
          }
        },
        preferred_contact: %{type: :select, options: ["email", "phone", "linkedin"], default: "email"}
      }
    },

    # PROFESSIONAL SECTIONS
    "experience" => %{
      name: "Work Experience",
      description: "Professional work history, roles, and achievements",
      icon: "💼",
      category: "professional",
      supports_multiple: true,
      supports_media: ["image"],
      fields: %{
        items: %{
          type: :items,
          required: true,
          item_schema: %{
            title: %{type: :string, required: true, placeholder: "Job Title"},
            company: %{type: :string, required: true, placeholder: "Company Name"},
            location: %{type: :string, placeholder: "City, State"},
            start_date: %{type: :date, required: true, placeholder: "MM/YYYY"},
            end_date: %{type: :date, placeholder: "MM/YYYY or 'Present'"},
            description: %{type: :text, required: true, placeholder: "What you accomplished in this role"},
            technologies: %{type: :array, placeholder: "Technologies used"},
            achievements: %{type: :array, placeholder: "Key achievements"},
            company_url: %{type: :string, placeholder: "Company website"}
          }
        }
      }
    },

    "education" => %{
      name: "Education",
      description: "Academic background, degrees, and relevant coursework",
      icon: "🎓",
      category: "professional",
      supports_multiple: true,
      supports_media: ["image"],
      fields: %{
        items: %{
          type: :items,
          required: true,
          item_schema: %{
            degree: %{type: :string, required: true, placeholder: "Bachelor of Science"},
            field: %{type: :string, required: true, placeholder: "Computer Science"},
            institution: %{type: :string, required: true, placeholder: "University Name"},
            location: %{type: :string, placeholder: "City, State"},
            graduation_date: %{type: :date, placeholder: "MM/YYYY"},
            gpa: %{type: :string, placeholder: "3.8/4.0"},
            honors: %{type: :array, placeholder: "Magna Cum Laude, Dean's List"},
            relevant_coursework: %{type: :array, placeholder: "Advanced algorithms, machine learning"}
          }
        }
      }
    },

    "skills" => %{
      name: "Skills & Expertise",
      description: "Technical and soft skills with proficiency levels",
      icon: "🛠️",
      category: "professional",
      supports_multiple: false,
      supports_media: [],
      fields: %{
        items: %{
          type: :items,
          required: true,
          item_schema: %{
            name: %{type: :string, required: true, placeholder: "JavaScript"},
            category: %{type: :select, options: ["frontend", "backend", "database", "devops", "design", "soft_skills", "tools", "other"], required: true},
            proficiency: %{type: :select, options: ["beginner", "intermediate", "advanced", "expert"], default: "intermediate"},
            years_experience: %{type: :integer, placeholder: "Years using this skill"},
            description: %{type: :string, placeholder: "Brief description or context"}
          }
        }
      }
    },

    "projects" => %{
      name: "Projects",
      description: "Portfolio projects, case studies, and notable work",
      icon: "🚀",
      category: "professional",
      supports_multiple: true,
      supports_media: ["image", "video"],
      fields: %{
        items: %{
          type: :items,
          required: true,
          item_schema: %{
            title: %{type: :string, required: true, placeholder: "Project Name"},
            description: %{type: :text, required: true, placeholder: "What this project does and why it matters"},
            technologies: %{type: :array, placeholder: "React, Node.js, PostgreSQL"},
            project_url: %{type: :string, placeholder: "Live demo URL"},
            github_url: %{type: :string, placeholder: "GitHub repository"},
            start_date: %{type: :date, placeholder: "MM/YYYY"},
            end_date: %{type: :date, placeholder: "MM/YYYY"},
            status: %{type: :select, options: ["completed", "in_progress", "planned"], default: "completed"},
            role: %{type: :string, placeholder: "Your role in the project"},
            team_size: %{type: :integer, placeholder: "Number of team members"},
            featured_image: %{type: :file, accepts: "image/*"}
          }
        }
      }
    },

    "certifications" => %{
      name: "Certifications",
      description: "Professional certifications, licenses, and credentials",
      icon: "🏆",
      category: "professional",
      supports_multiple: true,
      supports_media: ["image"],
      fields: %{
        items: %{
          type: :items,
          required: true,
          item_schema: %{
            name: %{type: :string, required: true, placeholder: "AWS Certified Solutions Architect"},
            issuer: %{type: :string, required: true, placeholder: "Amazon Web Services"},
            issue_date: %{type: :date, placeholder: "MM/YYYY"},
            expiration_date: %{type: :date, placeholder: "MM/YYYY"},
            credential_id: %{type: :string, placeholder: "Credential ID"},
            verification_url: %{type: :string, placeholder: "Verification URL"},
            description: %{type: :text, placeholder: "What this certification demonstrates"}
          }
        }
      }
    },

    "services" => %{
      name: "Services",
      description: "Services offered, pricing, and packages",
      icon: "⚡",
      category: "professional",
      supports_multiple: true,
      supports_media: ["image"],
      fields: %{
        items: %{
          type: :items,
          required: true,
          item_schema: %{
            name: %{type: :string, required: true, placeholder: "Web Development"},
            description: %{type: :text, required: true, placeholder: "What this service includes"},
            price: %{type: :string, placeholder: "$5,000 - $15,000"},
            duration: %{type: :string, placeholder: "2-4 weeks"},
            deliverables: %{type: :array, placeholder: "Responsive website, admin panel, documentation"},
            technologies: %{type: :array, placeholder: "Technologies used"},
            package_type: %{type: :select, options: ["basic", "standard", "premium"], default: "standard"}
          }
        }
      }
    },

    # CONTENT SECTIONS
    "achievements" => %{
      name: "Achievements & Awards",
      description: "Recognition, awards, and notable accomplishments",
      icon: "🏅",
      category: "content",
      supports_multiple: true,
      supports_media: ["image"],
      fields: %{
        items: %{
          type: :items,
          required: true,
          item_schema: %{
            title: %{type: :string, required: true, placeholder: "Best Developer Award"},
            issuer: %{type: :string, required: true, placeholder: "Tech Conference 2024"},
            date: %{type: :date, placeholder: "MM/YYYY"},
            description: %{type: :text, placeholder: "What you achieved and why it matters"},
            category: %{type: :select, options: ["award", "recognition", "competition", "publication", "speaking"], default: "award"},
            url: %{type: :string, placeholder: "Link to announcement or details"}
          }
        }
      }
    },

    "testimonials" => %{
      name: "Testimonials",
      description: "Client testimonials, recommendations, and feedback",
      icon: "💬",
      category: "content",
      supports_multiple: true,
      supports_media: ["image"],
      fields: %{
        items: %{
          type: :items,
          required: true,
          item_schema: %{
            quote: %{type: :text, required: true, placeholder: "What the client said about working with you"},
            author: %{type: :string, required: true, placeholder: "Client Name"},
            title: %{type: :string, placeholder: "Client's Job Title"},
            company: %{type: :string, placeholder: "Client's Company"},
            project: %{type: :string, placeholder: "Project you worked on together"},
            rating: %{type: :select, options: ["5", "4", "3", "2", "1"], default: "5"},
            date: %{type: :date, placeholder: "MM/YYYY"},
            avatar: %{type: :file, accepts: "image/*"}
          }
        }
      }
    },

    "published_articles" => %{
      name: "Publications & Writing",
      description: "Published articles, blog posts, and written content",
      icon: "📝",
      category: "content",
      supports_multiple: true,
      supports_media: ["image"],
      fields: %{
        items: %{
          type: :items,
          required: true,
          item_schema: %{
            title: %{type: :string, required: true, placeholder: "Article Title"},
            publication: %{type: :string, required: true, placeholder: "Publication/Platform name"},
            publish_date: %{type: :date, placeholder: "MM/YYYY"},
            url: %{type: :string, placeholder: "Article URL"},
            excerpt: %{type: :text, placeholder: "Brief summary or excerpt"},
            tags: %{type: :array, placeholder: "Topics, technologies, themes"},
            featured_image: %{type: :file, accepts: "image/*"},
            read_time: %{type: :string, placeholder: "5 min read"}
          }
        }
      }
    },

    "collaborations" => %{
      name: "Collaborations",
      description: "Partnerships, collaborations, and joint projects",
      icon: "🤝",
      category: "content",
      supports_multiple: true,
      supports_media: ["image"],
      fields: %{
        items: %{
          type: :items,
          required: true,
          item_schema: %{
            title: %{type: :string, required: true, placeholder: "Collaboration Name"},
            partner: %{type: :string, required: true, placeholder: "Partner/Organization"},
            description: %{type: :text, required: true, placeholder: "What you accomplished together"},
            start_date: %{type: :date, placeholder: "MM/YYYY"},
            end_date: %{type: :date, placeholder: "MM/YYYY"},
            role: %{type: :string, placeholder: "Your role in the collaboration"},
            outcomes: %{type: :array, placeholder: "Key results and outcomes"},
            url: %{type: :string, placeholder: "Project or partner URL"}
          }
        }
      }
    },

    "timeline" => %{
      name: "Timeline",
      description: "Chronological journey, milestones, and career progression",
      icon: "📅",
      category: "content",
      supports_multiple: false,
      supports_media: ["image"],
      fields: %{
        items: %{
          type: :items,
          required: true,
          item_schema: %{
            date: %{type: :date, required: true, placeholder: "MM/YYYY"},
            title: %{type: :string, required: true, placeholder: "Milestone Title"},
            description: %{type: :text, required: true, placeholder: "What happened and why it matters"},
            category: %{type: :select, options: ["career", "education", "personal", "achievement"], default: "career"},
            location: %{type: :string, placeholder: "City, State"},
            tags: %{type: :array, placeholder: "Relevant tags or themes"}
          }
        }
      }
    },

    # MEDIA SECTIONS
    "gallery" => %{
      name: "Gallery",
      description: "Visual portfolio, image galleries, and media showcase",
      icon: "🖼️",
      category: "media",
      supports_multiple: true,
      supports_media: ["image", "video"],
      fields: %{
        items: %{
          type: :items,
          required: true,
          item_schema: %{
            title: %{type: :string, required: true, placeholder: "Image/Video Title"},
            description: %{type: :text, placeholder: "Description of the media"},
            media_file: %{type: :file, accepts: "image/*,video/*", required: true},
            category: %{type: :string, placeholder: "Category or tag"},
            date: %{type: :date, placeholder: "MM/YYYY"},
            tags: %{type: :array, placeholder: "Relevant tags"}
          }
        }
      }
    },

    "blog" => %{
      name: "Blog",
      description: "Blog integration and recent posts",
      icon: "📄",
      category: "media",
      supports_multiple: true,
      supports_media: ["image"],
      fields: %{
        blog_url: %{type: :string, placeholder: "Your blog URL"},
        rss_feed: %{type: :string, placeholder: "RSS feed URL"},
        items: %{
          type: :items,
          item_schema: %{
            title: %{type: :string, required: true, placeholder: "Blog Post Title"},
            excerpt: %{type: :text, placeholder: "Post excerpt"},
            url: %{type: :string, required: true, placeholder: "Post URL"},
            publish_date: %{type: :date, placeholder: "MM/YYYY"},
            tags: %{type: :array, placeholder: "Post tags"},
            featured_image: %{type: :file, accepts: "image/*"}
          }
        }
      }
    },

    # FLEXIBLE
    "custom" => %{
      name: "Custom Section",
      description: "User-defined section with flexible content structure",
      icon: "⚙️",
      category: "flexible",
      supports_multiple: true,
      supports_media: ["image", "video"],
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

  # ============================================================================
  # PUBLIC API FUNCTIONS
  # ============================================================================

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
      %{supports_media: media_types} when is_list(media_types) and length(media_types) > 0 -> true
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

  def get_default_content(section_type) do
    case section_type do
      "hero" -> %{
        "headline" => "Welcome to My Portfolio",
        "tagline" => "Your Professional Tagline Here",
        "description" => "Brief description of what you do and what makes you unique.",
        "cta_text" => "Get Started",
        "cta_link" => "#contact",
        "video_type" => "none",
        "social_links" => %{},
        "contact_info" => %{}
      }
      "intro" -> %{
        "story" => "Tell your professional story here...",
        "highlights" => [],
        "personality_traits" => [],
        "fun_facts" => [],
        "specialties" => [],
        "years_experience" => 0,
        "current_focus" => ""
      }
      "contact" -> %{
        "email" => "",
        "phone" => "",
        "location" => "",
        "availability" => "Available for new projects",
        "social_links" => %{},
        "preferred_contact" => "email"
      }
      _ -> %{
        "items" => []
      }
    end
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

  defp validate_field(value, %{required: true}, field_name) when value in [nil, ""] do
    {:error, "#{field_name} is required"}
  end
  defp validate_field(_value, _config, _field_name), do: :ok

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
      "achievements" -> 10
      "testimonials" -> 11
      "published_articles" -> 12
      "collaborations" -> 13
      "timeline" -> 14
      "gallery" -> 15
      "blog" -> 16
      "custom" -> 17
      _ -> 99
    end
  end
end
