# lib/frestyl/portfolios/enhanced_section_system.ex

defmodule Frestyl.Portfolios.EnhancedSectionSystem do
  @moduledoc """
  Enhanced section system with unified section types that work for any profession.
  Mobile-first, block-based design with smart content adaptation.
  """

  # Consolidated and organized section types
  @section_types %{
    # Hero/Intro Sections
    "hero" => %{
      name: "Hero Section",
      description: "Main introduction with video, headline, and call-to-action",
      icon: "🏠",
      category: "introduction",
      supports_video: true,
      supports_media: [:video, :image],
      is_hero: true,
      fields: %{
        headline: %{type: :string, required: true, placeholder: "Your Name"},
        tagline: %{type: :string, required: true, placeholder: "Professional Title"},
        description: %{type: :text, placeholder: "Brief introduction about yourself"},
        cta_text: %{type: :string, placeholder: "Get In Touch"},
        cta_link: %{type: :string, placeholder: "mailto:you@example.com"},
        video_url: %{type: :string, placeholder: "Video introduction URL"},
        video_type: %{type: :select, options: ["upload", "youtube", "vimeo", "none"], default: "none"},
        background_image: %{type: :file, accepts: "image/*"},
        social_links: %{type: :map, default: %{}},
        contact_info: %{type: :map, default: %{}}
      },
      display_modes: ["video_prominent", "image_hero", "text_focused", "split_content"]
    },

    "intro" => %{
      name: "About/Introduction",
      description: "Personal story, background, and professional narrative",
      icon: "👋",
      category: "introduction",
      fields: %{
        title: %{type: :string, default: "About Me"},
        story: %{type: :text, required: true, placeholder: "Tell your story..."},
        highlights: %{type: :array, placeholder: "Key highlights about you"},
        personality_traits: %{type: :array, placeholder: "Creative, Analytical, Leader"},
        fun_facts: %{type: :array, placeholder: "Interesting facts about you"},
        profile_image: %{type: :file, accepts: "image/*"},
        background_story: %{type: :text, placeholder: "Your journey so far..."}
      },
      display_modes: ["narrative", "highlight_cards", "timeline", "split_image"]
    },

    # Experience & Work
    "experience" => %{
      name: "Professional Experience",
      description: "Work history, roles, and professional achievements",
      icon: "💼",
      category: "professional",
      supports_multiple: true,
      fields: %{
        items: %{
          type: :array,
          item_fields: %{
            title: %{type: :string, required: true, placeholder: "Job Title"},
            company: %{type: :string, required: true, placeholder: "Company Name"},
            location: %{type: :string, placeholder: "City, Country"},
            employment_type: %{type: :select, options: ["Full-time", "Part-time", "Contract", "Freelance", "Internship"]},
            start_date: %{type: :string, required: true, placeholder: "MM/YYYY"},
            end_date: %{type: :string, placeholder: "MM/YYYY or 'Present'"},
            is_current: %{type: :boolean, default: false},
            description: %{type: :text, placeholder: "Key responsibilities and achievements"},
            achievements: %{type: :array, placeholder: "Specific accomplishments"},
            skills_used: %{type: :array, placeholder: "Technologies/skills used"},
            projects: %{type: :array, placeholder: "Notable projects"},
            company_logo: %{type: :file, accepts: "image/*"},
            media: %{type: :array, accepts: ["image/*", "video/*", ".pdf"]}
          }
        }
      },
      display_modes: ["timeline", "cards", "compact_list", "detailed_stories"]
    },

    # Education & Learning
    "education" => %{
      name: "Education & Learning",
      description: "Academic background, degrees, and continuous learning",
      icon: "🎓",
      category: "education",
      supports_multiple: true,
      fields: %{
        items: %{
          type: :array,
          item_fields: %{
            degree: %{type: :string, required: true, placeholder: "Degree/Certification"},
            field: %{type: :string, placeholder: "Field of Study"},
            institution: %{type: :string, required: true, placeholder: "Institution Name"},
            location: %{type: :string, placeholder: "City, Country"},
            start_date: %{type: :string, placeholder: "YYYY"},
            end_date: %{type: :string, placeholder: "YYYY or 'Present'"},
            status: %{type: :select, options: ["Completed", "In Progress", "Paused"]},
            gpa: %{type: :string, placeholder: "GPA (optional)"},
            description: %{type: :text, placeholder: "Key coursework, achievements"},
            relevant_coursework: %{type: :array, placeholder: "Important courses"},
            activities: %{type: :array, placeholder: "Clubs, organizations, activities"},
            honors: %{type: :array, placeholder: "Dean's List, Scholarships, etc."},
            thesis_title: %{type: :string, placeholder: "Thesis/Capstone title"},
            institution_logo: %{type: :file, accepts: "image/*"},
            transcript: %{type: :file, accepts: ".pdf"},
            certificates: %{type: :array, accepts: [".pdf", "image/*"]}
          }
        }
      },
      display_modes: ["timeline", "cards", "academic_grid", "certification_showcase"]
    },

    # Skills & Expertise
    "skills" => %{
      name: "Skills & Expertise",
      description: "Technical skills, soft skills, and proficiency levels",
      icon: "⚡",
      category: "skills",
      fields: %{
        display_style: %{type: :select, options: ["categorized", "flat_list", "proficiency_bars", "skill_cloud"], default: "categorized"},
        categories: %{
          type: :map,
          default: %{
            "Technical Skills" => [],
            "Soft Skills" => [],
            "Tools & Platforms" => [],
            "Languages" => []
          }
        },
        skills: %{
          type: :array,
          item_fields: %{
            name: %{type: :string, required: true, placeholder: "Skill name"},
            category: %{type: :string, placeholder: "Category"},
            proficiency: %{type: :select, options: ["Beginner", "Intermediate", "Advanced", "Expert"], default: "Intermediate"},
            years_experience: %{type: :integer, placeholder: "Years"},
            endorsed_by: %{type: :array, placeholder: "People who endorsed this skill"},
            certifications: %{type: :array, placeholder: "Related certifications"},
            projects_used: %{type: :array, placeholder: "Projects where you used this"}
          }
        },
        show_proficiency: %{type: :boolean, default: true},
        show_endorsements: %{type: :boolean, default: false}
      },
      display_modes: ["category_cards", "proficiency_bars", "interactive_cloud", "minimal_tags"]
    },

    # Projects & Portfolio Work
    "projects" => %{
      name: "Projects & Portfolio",
      description: "Showcase of work, personal projects, and case studies",
      icon: "🚀",
      category: "work",
      supports_multiple: true,
      supports_media: [:image, :video, :document, :link],
      fields: %{
        items: %{
          type: :array,
          item_fields: %{
            title: %{type: :string, required: true, placeholder: "Project Title"},
            subtitle: %{type: :string, placeholder: "Brief tagline"},
            description: %{type: :text, required: true, placeholder: "Project description"},
            role: %{type: :string, placeholder: "Your role in the project"},
            client: %{type: :string, placeholder: "Client/Company name"},
            duration: %{type: :string, placeholder: "Project duration"},
            status: %{type: :select, options: ["Completed", "In Progress", "Concept", "On Hold"], default: "Completed"},
            category: %{type: :string, placeholder: "Project category/type"},
            technologies: %{type: :array, placeholder: "Technologies used"},
            skills_demonstrated: %{type: :array, placeholder: "Skills demonstrated"},
            challenges: %{type: :text, placeholder: "Challenges faced and how you solved them"},
            outcomes: %{type: :text, placeholder: "Results and impact"},
            lessons_learned: %{type: :text, placeholder: "What you learned"},
            gallery: %{type: :array, accepts: ["image/*", "video/*"]},
            live_url: %{type: :string, placeholder: "Live project URL"},
            github_url: %{type: :string, placeholder: "GitHub repository"},
            documentation: %{type: :array, accepts: [".pdf", ".doc", ".docx"]},
            featured: %{type: :boolean, default: false},
            collaboration_details: %{type: :text, placeholder: "Team members and collaboration"}
          }
        }
      },
      display_modes: ["gallery_grid", "case_study_cards", "featured_showcase", "timeline_projects"]
    },

    "featured_project" => %{
      name: "Featured Project",
      description: "Highlight your most important project in detail",
      icon: "⭐",
      category: "work",
      fields: %{
        title: %{type: :string, required: true, placeholder: "Featured Project Title"},
        headline: %{type: :string, placeholder: "Compelling headline"},
        overview: %{type: :text, required: true, placeholder: "Project overview"},
        problem: %{type: :text, placeholder: "Problem you solved"},
        solution: %{type: :text, placeholder: "Your solution approach"},
        process: %{type: :text, placeholder: "Your design/development process"},
        results: %{type: :text, placeholder: "Measurable outcomes"},
        role: %{type: :string, placeholder: "Your specific role"},
        team: %{type: :array, placeholder: "Team members"},
        duration: %{type: :string, placeholder: "Project timeline"},
        technologies: %{type: :array, placeholder: "Tech stack used"},
        hero_image: %{type: :file, accepts: "image/*"},
        gallery: %{type: :array, accepts: ["image/*", "video/*"]},
        live_url: %{type: :string, placeholder: "Live project URL"},
        case_study_url: %{type: :string, placeholder: "Detailed case study URL"},
        testimonial: %{type: :text, placeholder: "Client/colleague testimonial"},
        metrics: %{type: :map, default: %{"Users" => "", "Performance" => "", "Impact" => ""}}
      },
      display_modes: ["hero_showcase", "case_study_layout", "visual_story", "metrics_focused"]
    },

    # Media & Creative Work
    "gallery" => %{
      name: "Media Gallery",
      description: "Visual portfolio - images, videos, artwork, photography",
      icon: "🖼️",
      category: "creative",
      supports_media: [:image, :video],
      fields: %{
        layout_style: %{type: :select, options: ["masonry", "grid", "carousel", "lightbox"], default: "masonry"},
        items: %{
          type: :array,
          item_fields: %{
            title: %{type: :string, placeholder: "Image/Video title"},
            description: %{type: :text, placeholder: "Description or story"},
            media_file: %{type: :file, accepts: ["image/*", "video/*"], required: true},
            category: %{type: :string, placeholder: "Category/tag"},
            date_created: %{type: :string, placeholder: "When was this created"},
            location: %{type: :string, placeholder: "Where was this taken/made"},
            technical_details: %{type: :text, placeholder: "Camera settings, tools used, etc."},
            client: %{type: :string, placeholder: "Client name (if applicable)"},
            featured: %{type: :boolean, default: false}
          }
        },
        show_captions: %{type: :boolean, default: true},
        show_metadata: %{type: :boolean, default: false}
      },
      display_modes: ["masonry_grid", "full_screen_carousel", "thumbnail_gallery", "story_layout"]
    },

    "media_showcase" => %{
      name: "Media Showcase",
      description: "Curated media presentations with storytelling",
      icon: "🎬",
      category: "creative",
      supports_media: [:image, :video, :audio],
      fields: %{
        showcase_type: %{type: :select, options: ["video_reel", "photo_story", "audio_collection", "mixed_media"], default: "mixed_media"},
        items: %{
          type: :array,
          item_fields: %{
            title: %{type: :string, required: true, placeholder: "Media title"},
            description: %{type: :text, placeholder: "Story behind this piece"},
            media_file: %{type: :file, accepts: ["image/*", "video/*", "audio/*"], required: true},
            thumbnail: %{type: :file, accepts: "image/*"},
            duration: %{type: :string, placeholder: "Duration (for video/audio)"},
            genre: %{type: :string, placeholder: "Genre/style"},
            collaboration: %{type: :text, placeholder: "Collaborators"},
            awards: %{type: :array, placeholder: "Awards or recognition"},
            technical_specs: %{type: :text, placeholder: "Technical information"},
            external_link: %{type: :string, placeholder: "Link to full version"}
          }
        }
      },
      display_modes: ["video_playlist", "audio_player", "interactive_gallery", "presentation_mode"]
    },

    # Professional Services
    "services" => %{
      name: "Services & Offerings",
      description: "What you offer - services, consulting, products",
      icon: "🛠️",
      category: "business",
      supports_multiple: true,
      fields: %{
        items: %{
          type: :array,
          item_fields: %{
            name: %{type: :string, required: true, placeholder: "Service name"},
            description: %{type: :text, required: true, placeholder: "Service description"},
            deliverables: %{type: :array, placeholder: "What you deliver"},
            process: %{type: :text, placeholder: "Your process/approach"},
            duration: %{type: :string, placeholder: "Typical timeline"},
            price_range: %{type: :string, placeholder: "Price range (optional)"},
            includes: %{type: :array, placeholder: "What's included"},
            excludes: %{type: :array, placeholder: "What's not included"},
            requirements: %{type: :array, placeholder: "What you need from client"},
            portfolio_examples: %{type: :array, placeholder: "Example projects"},
            testimonials: %{type: :array, placeholder: "Client testimonials"},
            booking_link: %{type: :string, placeholder: "Booking/contact link"},
            featured: %{type: :boolean, default: false}
          }
        }
      },
      display_modes: ["service_cards", "pricing_table", "detailed_breakdown", "consultation_focused"]
    },

    "pricing" => %{
      name: "Pricing & Packages",
      description: "Clear pricing structure for your services",
      icon: "💰",
      category: "business",
      fields: %{
        pricing_model: %{type: :select, options: ["packages", "hourly", "project_based", "retainer"], default: "packages"},
        packages: %{
          type: :array,
          item_fields: %{
            name: %{type: :string, required: true, placeholder: "Package name"},
            price: %{type: :string, required: true, placeholder: "$X,XXX"},
            billing_period: %{type: :select, options: ["one-time", "monthly", "quarterly", "annually"], default: "one-time"},
            description: %{type: :text, placeholder: "Package description"},
            features: %{type: :array, placeholder: "What's included"},
            deliverables: %{type: :array, placeholder: "Deliverables"},
            timeline: %{type: :string, placeholder: "Delivery timeline"},
            popular: %{type: :boolean, default: false},
            booking_link: %{type: :string, placeholder: "Purchase/booking link"}
          }
        },
        hourly_rate: %{type: :string, placeholder: "$XXX/hour"},
        minimum_project: %{type: :string, placeholder: "Minimum project size"},
        payment_terms: %{type: :text, placeholder: "Payment terms and conditions"},
        add_ons: %{type: :array, placeholder: "Additional services available"}
      },
      display_modes: ["package_cards", "pricing_table", "calculator", "comparison_chart"]
    },

    # Achievements & Recognition
    "achievements" => %{
      name: "Achievements & Awards",
      description: "Recognition, awards, and notable accomplishments",
      icon: "🏆",
      category: "recognition",
      supports_multiple: true,
      fields: %{
        items: %{
          type: :array,
          item_fields: %{
            title: %{type: :string, required: true, placeholder: "Achievement title"},
            description: %{type: :text, placeholder: "Achievement description"},
            date: %{type: :string, placeholder: "Date received"},
            issuer: %{type: :string, placeholder: "Who gave this award"},
            category: %{type: :string, placeholder: "Type of achievement"},
            significance: %{type: :text, placeholder: "Why this matters"},
            media: %{type: :file, accepts: ["image/*", ".pdf"]},
            link: %{type: :string, placeholder: "Link to announcement/details"},
            featured: %{type: :boolean, default: false}
          }
        }
      },
      display_modes: ["trophy_case", "timeline", "category_groups", "featured_highlights"]
    },

    "certifications" => %{
      name: "Certifications & Credentials",
      description: "Professional certifications and credentials",
      icon: "📜",
      category: "credentials",
      supports_multiple: true,
      fields: %{
        items: %{
          type: :array,
          item_fields: %{
            name: %{type: :string, required: true, placeholder: "Certification name"},
            issuer: %{type: :string, required: true, placeholder: "Issuing organization"},
            date_earned: %{type: :string, placeholder: "Date earned"},
            expiry_date: %{type: :string, placeholder: "Expiry date (if applicable)"},
            credential_id: %{type: :string, placeholder: "Credential ID"},
            verification_url: %{type: :string, placeholder: "Verification link"},
            description: %{type: :text, placeholder: "What this certification covers"},
            skills_demonstrated: %{type: :array, placeholder: "Skills this proves"},
            certificate_file: %{type: :file, accepts: [".pdf", "image/*"]},
            continuing_education: %{type: :boolean, default: false}
          }
        }
      },
      display_modes: ["badge_grid", "detailed_list", "verification_focused", "skill_mapping"]
    },

    # Social Proof & Testimonials
    "testimonials" => %{
      name: "Testimonials & Reviews",
      description: "Client feedback, recommendations, and social proof",
      icon: "💬",
      category: "social_proof",
      supports_multiple: true,
      fields: %{
        items: %{
          type: :array,
          item_fields: %{
            quote: %{type: :text, required: true, placeholder: "Testimonial quote"},
            author: %{type: :string, required: true, placeholder: "Person's name"},
            title: %{type: :string, placeholder: "Their job title"},
            company: %{type: :string, placeholder: "Their company"},
            relationship: %{type: :string, placeholder: "How you worked together"},
            project: %{type: :string, placeholder: "Project they're referring to"},
            rating: %{type: :select, options: ["1", "2", "3", "4", "5"], placeholder: "Star rating"},
            date: %{type: :string, placeholder: "When they gave this feedback"},
            photo: %{type: :file, accepts: "image/*"},
            linkedin_url: %{type: :string, placeholder: "Their LinkedIn profile"},
            featured: %{type: :boolean, default: false},
            permission_granted: %{type: :boolean, default: false}
          }
        }
      },
      display_modes: ["carousel", "grid_layout", "featured_quotes", "video_testimonials"]
    },

    # Content & Publications
    "published_articles" => %{
      name: "Publications & Articles",
      description: "Written work, blog posts, and thought leadership",
      icon: "📝",
      category: "content",
      supports_multiple: true,
      fields: %{
        items: %{
          type: :array,
          item_fields: %{
            title: %{type: :string, required: true, placeholder: "Article title"},
            publication: %{type: :string, placeholder: "Where it was published"},
            date: %{type: :string, placeholder: "Publication date"},
            url: %{type: :string, placeholder: "Link to article"},
            abstract: %{type: :text, placeholder: "Brief summary"},
            topics: %{type: :array, placeholder: "Topics covered"},
            audience: %{type: :string, placeholder: "Target audience"},
            impact: %{type: :text, placeholder: "Reception/impact"},
            co_authors: %{type: :array, placeholder: "Co-authors"},
            featured_image: %{type: :file, accepts: "image/*"},
            pdf_copy: %{type: :file, accepts: ".pdf"}
          }
        }
      },
      display_modes: ["article_cards", "publication_list", "topic_clusters", "impact_focused"]
    },

    "blog" => %{
      name: "Blog & Thoughts",
      description: "Personal blog posts and thought leadership content",
      icon: "✍️",
      category: "content",
      supports_multiple: true,
      fields: %{
        items: %{
          type: :array,
          item_fields: %{
            title: %{type: :string, required: true, placeholder: "Blog post title"},
            excerpt: %{type: :text, placeholder: "Brief excerpt"},
            content: %{type: :text, placeholder: "Full blog post content"},
            date: %{type: :string, placeholder: "Publication date"},
            tags: %{type: :array, placeholder: "Tags/categories"},
            reading_time: %{type: :string, placeholder: "Estimated reading time"},
            featured_image: %{type: :file, accepts: "image/*"},
            external_url: %{type: :string, placeholder: "If published elsewhere"},
            engagement_stats: %{type: :map, default: %{"views" => "", "shares" => "", "comments" => ""}},
            featured: %{type: :boolean, default: false}
          }
        }
      },
      display_modes: ["blog_cards", "magazine_layout", "minimal_list", "featured_posts"]
    },

    # Professional Network
    "collaborations" => %{
      name: "Collaborations & Partnerships",
      description: "Team projects, partnerships, and collaborative work",
      icon: "🤝",
      category: "network",
      supports_multiple: true,
      fields: %{
        items: %{
          type: :array,
          item_fields: %{
            project_name: %{type: :string, required: true, placeholder: "Collaboration title"},
            collaborators: %{type: :array, required: true, placeholder: "Team members"},
            my_role: %{type: :string, placeholder: "Your specific role"},
            description: %{type: :text, placeholder: "What you worked on together"},
            outcome: %{type: :text, placeholder: "Results achieved"},
            duration: %{type: :string, placeholder: "How long you collaborated"},
            skills_contributed: %{type: :array, placeholder: "Skills you brought"},
            skills_gained: %{type: :array, placeholder: "Skills you learned"},
            testimonial: %{type: :text, placeholder: "What collaborators said"},
            project_url: %{type: :string, placeholder: "Link to project"},
            media: %{type: :array, accepts: ["image/*", "video/*"]},
            ongoing: %{type: :boolean, default: false}
          }
        }
      },
      display_modes: ["network_map", "project_stories", "testimonial_focused", "skills_exchange"]
    },

    # Contact & Availability
    "contact" => %{
      name: "Contact & Connect",
      description: "How people can reach you and connect",
      icon: "📞",
      category: "contact",
      fields: %{
        headline: %{type: :string, placeholder: "Let's work together!"},
        description: %{type: :text, placeholder: "Brief message about getting in touch"},
        email: %{type: :string, placeholder: "your@email.com"},
        phone: %{type: :string, placeholder: "+1 (555) 123-4567"},
        location: %{type: :string, placeholder: "City, Country"},
        timezone: %{type: :string, placeholder: "Your timezone"},
        availability: %{type: :text, placeholder: "When you're available"},
        preferred_contact: %{type: :select, options: ["Email", "Phone", "LinkedIn", "Calendly"], default: "Email"},
        response_time: %{type: :string, placeholder: "Typical response time"},
        social_links: %{
          type: :map,
          default: %{
            "linkedin" => "",
            "twitter" => "",
            "github" => "",
            "instagram" => "",
            "behance" => "",
            "dribbble" => ""
          }
        },
        booking_link: %{type: :string, placeholder: "Calendly or booking link"},
        contact_form: %{type: :boolean, default: true},
        languages: %{type: :array, placeholder: "Languages you speak"}
      },
      display_modes: ["contact_card", "social_focused", "booking_prominent", "minimal_info"]
    },

    # Flexible Content
    "custom" => %{
      name: "Custom Section",
      description: "Create your own section with custom content",
      icon: "⚙️",
      category: "flexible",
      fields: %{
        title: %{type: :string, required: true, placeholder: "Section title"},
        content_type: %{type: :select, options: ["text", "media", "mixed", "embedded"], default: "mixed"},
        content: %{type: :text, placeholder: "Your custom content"},
        media: %{type: :array, accepts: ["image/*", "video/*", "audio/*", ".pdf"]},
        embed_code: %{type: :text, placeholder: "Embed code (YouTube, etc.)"},
        links: %{type: :array, placeholder: "Related links"},
        call_to_action: %{type: :string, placeholder: "Action button text"},
        cta_link: %{type: :string, placeholder: "Action button link"}
      },
      display_modes: ["rich_content", "media_heavy", "text_focused", "interactive"]
    },

    # Storytelling Sections
    "story" => %{
      name: "Story Section",
      description: "Tell a specific story or narrative",
      icon: "📖",
      category: "narrative",
      fields: %{
        title: %{type: :string, required: true, placeholder: "Story title"},
        theme: %{type: :string, placeholder: "Story theme/message"},
        setting: %{type: :text, placeholder: "When and where this happened"},
        challenge: %{type: :text, placeholder: "The challenge or conflict"},
        journey: %{type: :text, placeholder: "What happened/your journey"},
        resolution: %{type: :text, placeholder: "How it ended/was resolved"},
        lesson: %{type: :text, placeholder: "What you learned"},
        impact: %{type: :text, placeholder: "How this changed you"},
        media: %{type: :array, accepts: ["image/*", "video/*"]},
        mood: %{type: :select, options: ["inspiring", "challenging", "triumphant", "reflective", "humorous"], default: "inspiring"}
      },
      display_modes: ["narrative_flow", "chapter_style", "visual_story", "timeline_story"]
    },

    "timeline" => %{
      name: "Life Timeline",
      description: "Chronological journey of key moments",
      icon: "📅",
      category: "narrative",
      fields: %{
        events: %{
          type: :array,
          item_fields: %{
            date: %{type: :string, required: true, placeholder: "Date or period"},
            title: %{type: :string, required: true, placeholder: "Event title"},
            description: %{type: :text, placeholder: "What happened"},
            significance: %{type: :text, placeholder: "Why this was important"},
            location: %{type: :string, placeholder: "Where this happened"},
            media: %{type: :file, accepts: ["image/*", "video/*"]},
            category: %{type: :string, placeholder: "Life area (career, personal, etc.)"},
            mood: %{type: :select, options: ["milestone", "challenge", "growth", "celebration"], default: "milestone"}
          }
        }
      },
      display_modes: ["vertical_timeline", "horizontal_scroll", "decade_view", "category_filtered"]
    },

    "journey" => %{
      name: "Professional Journey",
      description: "Your career evolution and growth story",
      icon: "🛤️",
      category: "narrative",
      fields: %{
        phases: %{
          type: :array,
          item_fields: %{
            phase_name: %{type: :string, required: true, placeholder: "Phase of your journey"},
            timeframe: %{type: :string, placeholder: "Time period"},
            focus: %{type: :string, placeholder: "What you focused on"},
            challenges: %{type: :text, placeholder: "Challenges you faced"},
            growth: %{type: :text, placeholder: "How you grew"},
            achievements: %{type: :array, placeholder: "Key achievements"},
            skills_developed: %{type: :array, placeholder: "Skills you developed"},
            key_relationships: %{type: :array, placeholder: "Important connections made"},
            media: %{type: :array, accepts: ["image/*", "video/*"]},
            reflection: %{type: :text, placeholder: "Looking back, what did this phase teach you?"}
          }
        }
      },
      display_modes: ["journey_map", "phase_cards", "evolution_timeline", "growth_story"]
    }
  }

  @layout_styles %{
    "mobile_single" => %{
      name: "Single Column",
      description: "Mobile-first single column layout",
      grid_columns: 1,
      block_height: "fixed",
      spacing: "comfortable",
      responsive: true
    },
    "grid_uniform" => %{
      name: "Grid Layout",
      description: "Uniform grid blocks",
      grid_columns: 2,
      block_height: "fixed",
      spacing: "tight",
      responsive: true
    },
    "dashboard" => %{
      name: "Dashboard",
      description: "Variable-sized blocks like a dashboard",
      grid_columns: "variable",
      block_height: "variable",
      spacing: "dynamic",
      responsive: true
    },
    "creative_modern" => %{
      name: "Creative Modern",
      description: "Asymmetric, dynamic layout",
      grid_columns: "asymmetric",
      block_height: "content_driven",
      spacing: "artistic",
      responsive: true
    }
  }

  def get_section_types, do: @section_types
  def get_layout_styles, do: @layout_styles

  def get_section_config(section_type) when is_atom(section_type) do
    get_section_config(Atom.to_string(section_type))
  end

  def get_section_config(section_type) when is_binary(section_type) do
    Map.get(@section_types, section_type)
  end

  def get_section_fields(section_type) do
    case get_section_config(section_type) do
      %{fields: fields} -> fields
      _ -> %{}
    end
  end

  def get_display_modes(section_type) do
    case get_section_config(section_type) do
      %{display_modes: modes} -> modes
      _ -> ["default"]
    end
  end

  def supports_multiple_items?(section_type) do
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

  def validate_section_content(section_type, content) do
    fields = get_section_fields(section_type)
    validate_fields(content, fields)
  end

  defp validate_fields(content, fields) do
    Enum.reduce(fields, %{valid: true, errors: []}, fn {field_name, field_config}, acc ->
      field_value = Map.get(content, Atom.to_string(field_name))

      case validate_field(field_value, field_config) do
        :ok -> acc
        {:error, message} ->
          %{acc | valid: false, errors: [{"#{field_name}: #{message}"} | acc.errors]}
      end
    end)
  end

  defp validate_field(nil, %{required: true}), do: {:error, "is required"}
  defp validate_field("", %{required: true}), do: {:error, "is required"}
  defp validate_field(value, %{type: :string}) when not is_binary(value), do: {:error, "must be text"}
  defp validate_field(value, %{type: :integer}) when not is_integer(value), do: {:error, "must be a number"}
  defp validate_field(value, %{type: :boolean}) when not is_boolean(value), do: {:error, "must be true or false"}
  defp validate_field(value, %{type: :array}) when not is_list(value), do: {:error, "must be a list"}
  defp validate_field(_value, _config), do: :ok

  def get_default_content(section_type) do
    fields = get_section_fields(section_type)

    Enum.reduce(fields, %{}, fn {field_name, field_config}, acc ->
      default_value = case field_config do
        %{default: default} -> default
        %{type: :string} -> ""
        %{type: :text} -> ""
        %{type: :array} -> []
        %{type: :map} -> %{}
        %{type: :boolean} -> false
        %{type: :integer} -> 0
        _ -> nil
      end

      Map.put(acc, Atom.to_string(field_name), default_value)
    end)
  end

  def get_section_categories do
    @section_types
    |> Enum.map(fn {_key, config} -> Map.get(config, :category, "other") end)
    |> Enum.uniq()
    |> Enum.sort()
  end
end
