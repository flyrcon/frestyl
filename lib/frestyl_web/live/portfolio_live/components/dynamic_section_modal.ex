# lib/frestyl_web/live/portfolio_live/components/dynamic_section_modal.ex
# COMPREHENSIVE MODAL FIXES - Addressing all identified issues

defmodule FrestylWeb.PortfolioLive.Components.DynamicSectionModal do
  @moduledoc """
  Fixed hybrid section modal with proper field support, media handling, and mobile optimization.
  Addresses: missing fields, media upload errors, humanization, and section-specific requirements.
  """

  use FrestylWeb, :live_component
  alias Frestyl.Portfolios.EnhancedSectionSystem

  @impl true
  def update(assigns, socket) do
    # Initialize form data from editing section or defaults
    form_data = case assigns[:editing_section] do
      %{content: content, title: title, section_type: section_type} when is_map(content) ->
        # Properly extract content for editing
        extract_content_for_editing(content, title, section_type)
      %{title: title, section_type: section_type} ->
        %{"title" => title, "section_type" => to_string(section_type)}
      _ ->
        get_default_form_data(assigns.section_type)
        |> Map.put("section_type", assigns.section_type)
    end

    # Initialize progressive disclosure state with form data preservation
    socket = socket
    |> assign(assigns)
    |> assign(:form_data, form_data)
    |> assign(:validation_errors, %{})
    |> assign(:save_status, nil)
    |> assign(:show_enhanced_fields, false)
    |> assign(:show_advanced_options, false)
    |> assign(:show_media_section, false)
    |> assign(:form_changeset, build_form_changeset(form_data, assigns.section_type))

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4"
         phx-window-keydown="close_modal_on_escape"
         phx-key="Escape">

      <div class="bg-white rounded-xl shadow-2xl max-w-5xl w-full max-h-[95vh] overflow-hidden"
           phx-click={JS.exec("event.stopPropagation()")}>

        <!-- Modal Header -->
        <%= render_modal_header(assigns) %>

        <!-- Modal Content with Progressive Disclosure -->
        <div class="flex-1 overflow-y-auto max-h-[75vh]">
          <form id="section-form" phx-submit="save_section" phx-target={@myself} class="space-y-6 p-6">

            <!-- Hidden Fields -->
            <input type="hidden" name="section_type" value={@section_type} />
            <%= if @editing_section do %>
              <input type="hidden" name="section_id" value={@editing_section.id} />
              <input type="hidden" name="action" value="update" />
            <% else %>
              <input type="hidden" name="action" value="create" />
            <% end %>

            <!-- Essential Fields (Always Visible) -->
            <%= render_essential_fields(assigns) %>

            <!-- Enhanced Fields (Collapsible) -->
            <%= render_enhanced_fields_section(assigns) %>

            <!-- Advanced Options (Collapsible) -->
            <%= render_advanced_options_section(assigns) %>

            <!-- Media Management (Collapsible) -->
            <%= render_media_section(assigns) %>

            <!-- Validation Errors -->
            <%= render_validation_errors(assigns) %>
          </form>
        </div>

        <!-- Modal Footer -->
        <%= render_modal_footer(assigns) %>
      </div>
    </div>
    """
  end

  # ============================================================================
  # MODAL HEADER
  # ============================================================================

  defp render_modal_header(assigns) do
    ~H"""
    <div class="flex items-center justify-between p-6 border-b border-gray-200 bg-gradient-to-r from-blue-50 to-indigo-50">
      <div class="flex items-center">
        <div class="w-12 h-12 rounded-xl flex items-center justify-center mr-4 shadow-lg"
             style={"background: linear-gradient(135deg, #{get_section_color(@section_type)} 0%, #{darken_color(get_section_color(@section_type))} 100%)"}>
          <span class="text-white text-xl"><%= get_section_icon(@section_type) %></span>
        </div>
        <div>
          <h3 class="text-xl font-bold text-gray-900">
            <%= if @editing_section, do: "Edit", else: "Create" %> <%= get_section_name(@section_type) %>
          </h3>
          <p class="text-gray-600 text-sm"><%= get_section_description(@section_type) %></p>
        </div>
      </div>
      <button phx-click="close_section_modal" phx-target={@myself}
              class="text-gray-400 hover:text-gray-600 p-2 hover:bg-gray-100 rounded-full transition-colors">
        <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
        </svg>
      </button>
    </div>
    """
  end

  defp extract_content_for_editing(content, title, section_type) do
    base_data = %{
      "title" => title,
      "section_type" => to_string(section_type)
    }

    case section_type do
      :hero ->
        Map.merge(base_data, %{
          "headline" => Map.get(content, "headline", ""),
          "tagline" => Map.get(content, "tagline", ""),
          "description" => Map.get(content, "description", ""),
          "cta_text" => Map.get(content, "cta_text", ""),
          "cta_link" => Map.get(content, "cta_link", "")
        })

      :contact ->
        social_links = Map.get(content, "social_links", %{})

        # Flatten social links for form display
        flattened_social = Enum.reduce(social_links, %{}, fn {platform, url}, acc ->
          Map.put(acc, "social_links[#{platform}]", url)
        end)

        Map.merge(base_data, Map.merge(%{
          "email" => Map.get(content, "email", ""),
          "phone" => Map.get(content, "phone", ""),
          "location" => Map.get(content, "location", ""),
          "website" => Map.get(content, "website", ""),
          "availability" => Map.get(content, "availability", ""),
          "timezone" => Map.get(content, "timezone", ""),
          "preferred_contact" => Map.get(content, "preferred_contact", "Email")
        }, flattened_social))

      section_type when section_type in [:skills, :experience, :education, :projects, :testimonials, :certifications, :services, :published_articles, :achievements, :collaborations, :pricing, :code_showcase] ->
        items = Map.get(content, "items", [])

        # Convert items list to indexed map for form editing
        items_map = items
        |> Enum.with_index()
        |> Enum.reduce(%{}, fn {item, index}, acc ->
          Map.put(acc, to_string(index), item)
        end)

        Map.merge(base_data, %{
          "items" => items_map
        })

      _ ->
        # Simple content sections
        content_fields = Map.delete(content, "title")
        Map.merge(base_data, content_fields)
    end
  end

  # ============================================================================
  # ESSENTIAL FIELDS (Always Visible) - FIXED FIELD DEFINITIONS
  # ============================================================================

  defp render_essential_fields(assigns) do
    essential_fields = get_essential_fields(assigns.section_type)

    assigns = assign(assigns, :essential_fields, essential_fields)

    ~H"""
    <div class="bg-white rounded-lg border border-gray-200 p-6">
      <div class="flex items-center mb-4">
        <svg class="w-5 h-5 text-blue-600 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 0a9 9 0 1118 0 9 9 0 01-18 0z"/>
        </svg>
        <h4 class="text-lg font-semibold text-gray-900">Essential Information</h4>
        <span class="ml-2 text-xs bg-blue-100 text-blue-700 px-2 py-1 rounded-full">Required</span>
      </div>

      <!-- Section Title Field (Always First) -->
      <%= render_section_title_field(assigns) %>

      <!-- Essential Fields Grid -->
      <%= if length(@essential_fields) > 0 do %>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">
          <%= for {field_name, field_config} <- @essential_fields do %>
            <%= render_field(field_name, field_config, assigns, "essential") %>
          <% end %>
        </div>
      <% end %>

      <!-- Essential Items Section -->
      <%= if has_essential_items?(@section_type) do %>
        <%= render_essential_items_section(assigns) %>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # FIXED FIELD DEFINITIONS PER SECTION TYPE
  # ============================================================================

  defp get_essential_fields(section_type) do
    case section_type do
      "hero" ->
        [
          {:headline, %{type: :string, required: true, placeholder: "Your Name or Professional Brand"}},
          {:tagline, %{type: :string, required: true, placeholder: "Professional Title or Key Message"}}
        ]

      "contact" ->
        [
          {:email, %{type: :string, required: true, placeholder: "your@email.com"}},
          {:phone, %{type: :string, placeholder: "+1 (555) 123-4567"}},
          {:location, %{type: :string, placeholder: "City, State/Country"}},
          {:social_links, %{type: :social_links}}
        ]

      "intro" ->
        [
          {:summary, %{type: :text, required: true, placeholder: "Brief professional overview in 2-3 sentences..."}}
        ]

      "about" ->
        [
          {:story, %{type: :text, required: true, placeholder: "Tell your professional story in 2-3 paragraphs..."}}
        ]

      "pricing" ->
        [
          {:currency, %{type: :select, options: ["USD", "EUR", "GBP", "CAD", "AUD"], default: "USD"}},
          {:billing_model, %{type: :select, options: ["one_time", "monthly", "annually", "hourly", "project"], default: "project"}}
        ]

      "gallery" ->
        [
          {:display_style, %{type: :select, options: ["grid", "masonry", "carousel", "lightbox"], default: "grid"}},
          {:items_per_row, %{type: :select, options: ["2", "3", "4", "5"], default: "3"}}
        ]

      "blog" ->
        [
          {:blog_url, %{type: :string, placeholder: "https://yourblog.com or RSS feed URL"}},
          {:auto_sync, %{type: :boolean, default: false}}
        ]

      "timeline" ->
        [
          {:timeline_type, %{type: :select, options: ["chronological", "reverse_chronological", "milestone"], default: "reverse_chronological"}}
        ]

      "code_showcase" ->
        [
          {:showcase_type, %{type: :select, options: ["snippets", "projects", "repositories"], default: "snippets"}},
          {:primary_language, %{type: :string, placeholder: "e.g., JavaScript, Python, etc."}}
        ]

      # Sections with items as essential content - NO FIELDS HERE, just items
      section_type when section_type in ["experience", "education", "skills", "projects", "testimonials", "certifications", "services", "published_articles", "achievements", "collaborations"] ->
        []

      "custom" ->
        [
          {:custom_title, %{type: :string, required: true, placeholder: "What would you like to call this section?"}},
          {:layout_style, %{type: :select, options: ["list", "grid", "timeline", "cards"], default: "list"}}
        ]

      _ ->
        []
    end
  end

  # ============================================================================
  # ENHANCED ITEM SCHEMAS - FIXED FOR EACH SECTION TYPE
  # ============================================================================

  defp get_essential_item_schema(section_type) do
    case section_type do
      "experience" ->
        %{
          title: %{type: :string, required: true, placeholder: "Job Title"},
          company: %{type: :string, required: true, placeholder: "Company Name"},
          start_date: %{type: :date, required: true, placeholder: "MM/YYYY"},
          end_date: %{type: :date, placeholder: "MM/YYYY"},
          is_current: %{type: :boolean, default: false},
          employment_type: %{type: :select, options: ["Full-time", "Part-time", "Contract", "Freelance", "Internship"], default: "Full-time"},
          location: %{type: :string, placeholder: "City, State or Remote"},
          description: %{type: :text, placeholder: "Key responsibilities and achievements..."}
        }

      "education" ->
        %{
          degree: %{type: :string, required: true, placeholder: "Degree/Certification Name"},
          institution: %{type: :string, required: true, placeholder: "School/Institution"},
          field_of_study: %{type: :string, placeholder: "Major/Field of Study"},
          start_date: %{type: :date, placeholder: "MM/YYYY"},
          graduation_date: %{type: :date, placeholder: "MM/YYYY"},
          gpa: %{type: :string, placeholder: "3.8/4.0 (optional)"},
          description: %{type: :text, placeholder: "Relevant coursework, achievements, honors..."}
        }

      "skills" ->
        %{
          skill_name: %{type: :string, required: true, placeholder: "Skill Name"},
          proficiency: %{type: :select, options: ["Beginner", "Intermediate", "Advanced", "Expert"], default: "Intermediate"},
          category: %{type: :select, options: ["Technical", "Programming Languages", "Frameworks", "Tools", "Soft Skills", "Languages", "Design", "Marketing", "Other"], default: "Technical"},
          years_experience: %{type: :integer, placeholder: "Years of experience"}
        }

      "projects" ->
        %{
          title: %{type: :string, required: true, placeholder: "Project Name"},
          description: %{type: :text, required: true, placeholder: "What does this project do and what was your role?"},
          status: %{type: :select, options: ["Completed", "In Progress", "On Hold", "Prototype"], default: "Completed"},
          start_date: %{type: :date, placeholder: "MM/YYYY"},
          end_date: %{type: :date, placeholder: "MM/YYYY"},
          technologies: %{type: :array, placeholder: "Languages, frameworks, tools used"},
          project_url: %{type: :string, placeholder: "https://project-demo.com"},
          github_url: %{type: :string, placeholder: "https://github.com/username/repo"}
        }

      "testimonials" ->
        %{
          client_name: %{type: :string, required: true, placeholder: "Client/Colleague Name"},
          client_title: %{type: :string, placeholder: "Their job title"},
          client_company: %{type: :string, placeholder: "Their company"},
          feedback: %{type: :text, required: true, placeholder: "Their testimonial about your work..."},
          project: %{type: :string, placeholder: "Project or context"},
          date: %{type: :date, placeholder: "MM/YYYY"},
          rating: %{type: :select, options: ["5", "4", "3", "2", "1"], default: "5"}
        }

      "services" ->
        %{
          name: %{type: :string, required: true, placeholder: "Service Name"},
          description: %{type: :text, required: true, placeholder: "What's included in this service?"},
          price: %{type: :string, placeholder: "$X,XXX or 'Contact for pricing'"},
          duration: %{type: :string, placeholder: "Project timeline or hourly rate"},
          features: %{type: :array, placeholder: "Key features included (comma-separated)"}
        }

      "published_articles" ->
        %{
          title: %{type: :string, required: true, placeholder: "Article Title"},
          publication: %{type: :string, placeholder: "Medium, Dev.to, Company Blog, etc."},
          url: %{type: :string, placeholder: "Link to the article"},
          publish_date: %{type: :date, placeholder: "MM/YYYY"},
          excerpt: %{type: :text, placeholder: "Brief summary of the article..."},
          tags: %{type: :array, placeholder: "Topics, technologies covered"}
        }

      "certifications" ->
        %{
          name: %{type: :string, required: true, placeholder: "Certification Name"},
          issuer: %{type: :string, required: true, placeholder: "Issuing Organization"},
          issue_date: %{type: :date, placeholder: "MM/YYYY"},
          expiration_date: %{type: :date, placeholder: "MM/YYYY (if applicable)"},
          credential_id: %{type: :string, placeholder: "Certificate ID (optional)"},
          credential_url: %{type: :string, placeholder: "Verification URL"}
        }

      "achievements" ->
        %{
          title: %{type: :string, required: true, placeholder: "Achievement Title"},
          description: %{type: :text, required: true, placeholder: "What was accomplished?"},
          date: %{type: :date, placeholder: "MM/YYYY"},
          organization: %{type: :string, placeholder: "Awarding organization"},
          category: %{type: :select, options: ["Award", "Recognition", "Competition", "Publication", "Speaking", "Other"], default: "Award"}
        }

      "collaborations" ->
        %{
          project_name: %{type: :string, required: true, placeholder: "Collaboration/Project Name"},
          collaborators: %{type: :array, required: true, placeholder: "Names of people you worked with"},
          description: %{type: :text, required: true, placeholder: "What was accomplished together?"},
          your_role: %{type: :string, placeholder: "Your specific role"},
          date: %{type: :date, placeholder: "MM/YYYY"},
          outcome: %{type: :text, placeholder: "Results or impact of the collaboration"}
        }

      "pricing" ->
        %{
          package_name: %{type: :string, required: true, placeholder: "Package/Service Name"},
          price: %{type: :string, required: true, placeholder: "$XXX"},
          billing_period: %{type: :select, options: ["one-time", "hourly", "monthly", "annually"], default: "one-time"},
          description: %{type: :text, required: true, placeholder: "What's included in this package?"},
          features: %{type: :array, placeholder: "Key features (comma-separated)"},
          is_featured: %{type: :boolean, default: false}
        }

      "code_showcase" ->
        %{
          title: %{type: :string, required: true, placeholder: "Code Sample Title"},
          language: %{type: :string, required: true, placeholder: "Programming Language"},
          description: %{type: :text, placeholder: "What does this code do?"},
          code_snippet: %{type: :text, required: true, placeholder: "Paste your code here (will be safely displayed)"},
          repository_url: %{type: :string, placeholder: "GitHub repository link"},
          live_demo_url: %{type: :string, placeholder: "Live demo URL"}
        }

      "custom" ->
        %{
          title: %{type: :string, required: true, placeholder: "Item Title"},
          content: %{type: :text, placeholder: "Item content..."},
          link: %{type: :string, placeholder: "Related URL (optional)"},
          date: %{type: :date, placeholder: "MM/YYYY (optional)"}
        }

      _ ->
        %{
          title: %{type: :string, required: true, placeholder: "Item Title"},
          description: %{type: :text, placeholder: "Description..."}
        }
    end
  end

  # ============================================================================
  # ENHANCED FIELDS (Collapsible) - FIXED
  # ============================================================================

  defp get_enhanced_fields(section_type) do
    case section_type do
      "hero" ->
        [
          {:description, %{type: :text, placeholder: "Brief introduction or elevator pitch..."}},
          {:cta_text, %{type: :string, placeholder: "Call-to-action button text (e.g., 'Get In Touch')"}},
          {:cta_link, %{type: :string, placeholder: "Where the CTA button should link to"}}
        ]

      "contact" ->
        [
          {:website, %{type: :string, placeholder: "https://yourwebsite.com"}},
          {:availability, %{type: :text, placeholder: "Available for new projects, consulting, etc."}},
          {:timezone, %{type: :string, placeholder: "EST, PST, GMT+1, etc."}},
          {:preferred_contact, %{type: :select, options: ["Email", "Phone", "Website Form", "Social Media"], default: "Email"}}
        ]

      "intro" ->
        [
          {:specialties, %{type: :array, placeholder: "Key areas of expertise"}},
          {:years_experience, %{type: :integer, placeholder: "Years of professional experience"}},
          {:current_focus, %{type: :string, placeholder: "What you're currently focused on"}}
        ]

      "about" ->
        [
          {:interests, %{type: :array, placeholder: "Hobbies, interests, passions"}},
          {:values, %{type: :array, placeholder: "Professional values that guide your work"}},
          {:fun_facts, %{type: :array, placeholder: "Interesting facts about you"}}
        ]

      "pricing" ->
        [
          {:description, %{type: :text, placeholder: "Overview of your pricing structure"}},
          {:payment_methods, %{type: :array, placeholder: "Accepted payment methods"}},
          {:terms, %{type: :text, placeholder: "Payment terms and conditions"}}
        ]

      "gallery" ->
        [
          {:show_captions, %{type: :boolean, default: true}},
          {:enable_lightbox, %{type: :boolean, default: true}},
          {:auto_play, %{type: :boolean, default: false}}
        ]

      "blog" ->
        [
          {:description, %{type: :text, placeholder: "Brief description of your blog content"}},
          {:featured_tags, %{type: :array, placeholder: "Main topics you write about"}},
          {:max_posts, %{type: :integer, default: 6}}
        ]

      "timeline" ->
        [
          {:description, %{type: :text, placeholder: "Context for this timeline"}},
          {:show_dates, %{type: :boolean, default: true}},
          {:compact_view, %{type: :boolean, default: false}}
        ]

      "code_showcase" ->
        [
          {:github_username, %{type: :string, placeholder: "Your GitHub username"}},
          {:show_github_stats, %{type: :boolean, default: true}},
          {:featured_languages, %{type: :array, placeholder: "Languages to highlight"}}
        ]

      _ ->
        []
    end
  end

  # ============================================================================
  # MEDIA SECTION - FIXED MEDIA SUPPORT CHECK
  # ============================================================================

  defp supports_media?(section_type) do
    # Based on portfolio_section.ex, these sections support media through portfolio_media association
    section_type in [
      "hero", "gallery", "projects", "featured_project", "case_study",
      "media_showcase", "code_showcase", "services", "published_articles",
      "blog", "testimonials", "achievements", "collaborations"
    ]
  end

  defp render_media_section(assigns) do
    if supports_media?(assigns.section_type) do
      ~H"""
      <div class="bg-orange-50 rounded-lg border border-orange-200 overflow-hidden">
        <button type="button"
                phx-click="toggle_media_section" phx-target={@myself}
                class="w-full flex items-center justify-between p-4 text-left hover:bg-orange-100 transition-colors">
          <div class="flex items-center">
            <svg class="w-5 h-5 text-orange-600 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 002 2z"/>
            </svg>
            <h4 class="text-lg font-semibold text-orange-800">Media & Files</h4>
            <span class="ml-2 text-xs bg-orange-200 text-orange-700 px-2 py-1 rounded-full">
              <%= get_supported_media_types(@section_type) |> length() %> types
            </span>
          </div>
          <svg class={"w-5 h-5 text-orange-600 transition-transform #{if @show_media_section, do: "rotate-180", else: ""}"}
               fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>
          </svg>
        </button>

        <%= if @show_media_section do %>
          <div class="p-6 border-t border-orange-200 bg-white">
            <%= render_media_upload_section(assigns) %>
          </div>
        <% end %>
      </div>
      """
    else
      ~H""
    end
  end

  defp build_form_changeset(form_data, section_type) do
    # Create a simple struct for form binding
    types = get_form_field_types(section_type)

    {%{}, types}
    |> Ecto.Changeset.cast(form_data, Map.keys(types))
  end

  defp render_media_upload_section(assigns) do
    media_types = get_supported_media_types(assigns.section_type)
    assigns = assign(assigns, :media_types, media_types)

    ~H"""
    <div class="space-y-6">
      <div class="flex items-center justify-between">
        <h5 class="font-medium text-gray-900">Add Media Files</h5>
        <div class="text-xs text-gray-500">
          Supported: <%= Enum.join(@media_types, ", ") |> String.upcase() %>
        </div>
      </div>

      <!-- File Upload Zone -->
      <div class="border-2 border-dashed border-gray-300 rounded-lg p-8 text-center hover:border-gray-400 transition-colors">
        <input type="file"
               name="media_files[]"
               multiple
               accept={get_file_accept_string(@media_types)}
               class="hidden"
               id="media-upload-#{@section_type}" />

        <label for="media-upload-#{@section_type}" class="cursor-pointer">
          <svg class="w-12 h-12 text-gray-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/>
          </svg>
          <p class="text-lg font-medium text-gray-700 mb-2">Drop files here or click to upload</p>
          <p class="text-sm text-gray-500">
            Support for images, videos, audio, documents, and more
          </p>
        </label>
      </div>

      <!-- URL Input for External Media -->
      <div class="space-y-3">
        <h6 class="text-sm font-medium text-gray-700">Or add external links:</h6>

        <%= if "video" in @media_types do %>
          <div>
            <label class="text-xs text-gray-600">Video URL (YouTube, Vimeo, etc.)</label>
            <input type="url"
                   name="video_url"
                   placeholder="https://youtube.com/watch?v=..."
                   class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-orange-500 text-sm" />
          </div>
        <% end %>

        <%= if "image" in @media_types do %>
          <div>
            <label class="text-xs text-gray-600">Image URL</label>
            <input type="url"
                   name="image_url"
                   placeholder="https://example.com/image.jpg"
                   class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-orange-500 text-sm" />
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # ============================================================================
  # SOCIAL LINKS FIELD RENDERING - FIXED
  # ============================================================================

  defp render_social_links_field(field_name, field_config, current_value, assigns) do
    social_links = case current_value do
      map when is_map(map) -> map
      _ -> Map.get(field_config, :default, %{})
    end

    platforms = ["linkedin", "github", "twitter", "instagram", "website", "youtube", "facebook", "behance", "dribbble", "medium"]

    assigns = Map.merge(assigns, %{
      field_name: field_name,
      social_links: social_links,
      platforms: platforms
    })

    ~H"""
    <div class="md:col-span-2">
      <label class="block text-sm font-medium text-gray-700 mb-3">
        Social Links & Online Presence
      </label>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
        <%= for platform <- @platforms do %>
          <div>
            <label class="text-xs text-gray-600 capitalize flex items-center">
              <%= render_social_icon(platform) %>
              <span class="ml-1"><%= platform %></span>
            </label>
            <input type="url"
                   name={"#{@field_name}[#{platform}]"}
                   value={Map.get(@social_links, platform, "")}
                   placeholder={get_platform_placeholder(platform)}
                   class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 text-sm" />
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # ============================================================================
  # ITEM SORTING FUNCTIONALITY - NEW
  # ============================================================================

  defp render_item_card(item, index, item_schema, assigns) do
    item_title = get_item_display_title(item, assigns.section_type)
    item_visible = Map.get(item, "visible", true)
    total_items = length(get_current_items(assigns))

    assigns = Map.merge(assigns, %{
      item: item,
      index: index,
      item_schema: item_schema,
      item_title: item_title,
      item_visible: item_visible,
      total_items: total_items
    })

    ~H"""
    <div class={"border rounded-lg p-5 transition-all #{if @item_visible, do: "border-gray-200 bg-white shadow-sm hover:shadow-md", else: "border-gray-100 bg-gray-50 opacity-75"}"}>
      <!-- Item Header with Controls -->
      <div class="flex items-center justify-between mb-4">
        <div class="flex items-center">
          <%= if not @item_visible do %>
            <svg class="w-4 h-4 text-gray-400 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.878 9.878L12 12m-2.122-2.122L7.76 7.76M12 12l2.121 2.121M12 12V9m-3 6h6m3 3l-3-3m-3 3l3-3"/>
            </svg>
          <% end %>
          <h5 class={"text-base font-semibold #{if @item_visible, do: "text-gray-900", else: "text-gray-500"}"}>
            <%= @item_title || "#{get_item_name(@section_type)} #{@index + 1}" %>
          </h5>
        </div>

        <!-- Item Controls -->
        <div class="flex items-center space-x-2">
          <!-- Move Up Button -->
          <%= if @index > 0 do %>
            <button type="button"
                    phx-click="move_item_up"
                    phx-value-index={@index}
                    phx-target={@myself}
                    class="p-1.5 text-blue-600 hover:bg-blue-50 rounded transition-colors"
                    title="Move up">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7"/>
              </svg>
            </button>
          <% end %>

          <!-- Move Down Button -->
          <%= if @index < @total_items - 1 do %>
            <button type="button"
                    phx-click="move_item_down"
                    phx-value-index={@index}
                    phx-target={@myself}
                    class="p-1.5 text-blue-600 hover:bg-blue-50 rounded transition-colors"
                    title="Move down">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>
              </svg>
            </button>
          <% end %>

          <!-- Visibility Toggle -->
          <button type="button"
                  phx-click="toggle_item_visibility"
                  phx-value-index={@index}
                  phx-target={@myself}
                  class={"p-1.5 rounded transition-colors #{if @item_visible, do: "text-green-600 hover:bg-green-50", else: "text-gray-400 hover:bg-gray-100"}"}
                  title={if @item_visible, do: "Hide this item", else: "Show this item"}>
            <%= if @item_visible do %>
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
              </svg>
            <% else %>
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.878 9.878L12 12m-2.122-2.122L7.76 7.76M12 12l2.121 2.121M12 12V9"/>
              </svg>
            <% end %>
          </button>

          <!-- Duplicate Item -->
          <button type="button"
                  phx-click="duplicate_item"
                  phx-value-index={@index}
                  phx-target={@myself}
                  class="p-1.5 text-blue-600 hover:bg-blue-50 rounded transition-colors"
                  title="Duplicate this item">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/>
            </svg>
          </button>

          <!-- Delete Item -->
          <button type="button"
                  phx-click="remove_item"
                  phx-value-index={@index}
                  phx-target={@myself}
                  class="p-1.5 text-red-600 hover:bg-red-50 rounded transition-colors"
                  title="Delete this item">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
            </svg>
          </button>
        </div>
      </div>

      <!-- Item Fields -->
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <!-- Hidden field for item visibility -->
        <input type="hidden" name={"items[#{@index}][visible]"} value={to_string(@item_visible)} />

        <%= for {field_name, field_config} <- @item_schema do %>
          <%= render_item_field(@item, @index, field_name, field_config) %>
        <% end %>
      </div>
    </div>
    """
  end

  # ============================================================================
  # SORTING EVENT HANDLERS - NEW
  # ============================================================================

  @impl true
  def handle_event("move_item_up", %{"index" => index_str}, socket) do
    {index, _} = Integer.parse(index_str)
    current_items = get_current_items(socket.assigns)

    if index > 0 do
      updated_items = swap_items(current_items, index, index - 1)
      updated_form_data = Map.put(socket.assigns.form_data, "items", updated_items)
      {:noreply, assign(socket, :form_data, updated_form_data)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("move_item_down", %{"index" => index_str}, socket) do
    {index, _} = Integer.parse(index_str)
    current_items = get_current_items(socket.assigns)

    if index < length(current_items) - 1 do
      updated_items = swap_items(current_items, index, index + 1)
      updated_form_data = Map.put(socket.assigns.form_data, "items", updated_items)
      {:noreply, assign(socket, :form_data, updated_form_data)}
    else
      {:noreply, socket}
    end
  end

  defp swap_items(items, index_a, index_b) do
    item_a = Enum.at(items, index_a)
    item_b = Enum.at(items, index_b)

    items
    |> List.replace_at(index_a, item_b)
    |> List.replace_at(index_b, item_a)
  end

  # ============================================================================
  # CURRENT DATE HANDLING - FIXED FOR EXPERIENCE
  # ============================================================================

  defp render_item_field(item, index, field_name, field_config) do
    field_type = Map.get(field_config, :type, :string)
    current_value = Map.get(item, to_string(field_name), "")
    required = Map.get(field_config, :required, false)
    placeholder = Map.get(field_config, :placeholder, "")

    input_name = "items[#{index}][#{field_name}]"

    case field_type do
      :text ->
        render_item_textarea(input_name, current_value, field_name, required, placeholder)
      :select ->
        options = Map.get(field_config, :options, [])
        render_item_select(input_name, current_value, field_name, options, required)
      :array ->
        display_value = case current_value do
          list when is_list(list) -> Enum.join(list, ", ")
          str when is_binary(str) -> str
          _ -> ""
        end
        render_item_input(input_name, display_value, field_name, required, placeholder)
      :boolean ->
        render_item_boolean(input_name, current_value, field_name)
      :date ->
        render_item_date_with_current(item, index, field_name, field_config)
      :integer ->
        render_item_input(input_name, current_value, field_name, required, placeholder, "number")
      :file ->
        render_item_file(input_name, field_name, field_config)
      _ ->
        render_item_input(input_name, current_value, field_name, required, placeholder)
    end
  end

  defp render_item_date_with_current(item, index, field_name, field_config) do
    current_value = Map.get(item, to_string(field_name), "")
    required = Map.get(field_config, :required, false)
    placeholder = Map.get(field_config, :placeholder, "")
    input_name = "items[#{index}][#{field_name}]"

    # Special handling for end_date in experience sections
    is_end_date = field_name == :end_date
    is_current = Map.get(item, "is_current", false)

    assigns = %{
      input_name: input_name,
      current_value: current_value,
      field_name: field_name,
      required: required,
      placeholder: placeholder,
      is_end_date: is_end_date,
      is_current: is_current,
      index: index
    }

    ~H"""
    <%= if @is_end_date do %>
      <div>
        <div class="flex items-center justify-between mb-2">
          <label class="block text-sm font-medium text-gray-700">
            End Date
          </label>
          <label class="flex items-center text-sm">
            <input type="checkbox"
                   name={"items[#{@index}][is_current]"}
                   value="true"
                   checked={@is_current}
                   class="mr-2 rounded"
                   phx-click="toggle_current_position"
                   phx-value-index={@index} />
            <span class="text-gray-600">Current Position</span>
          </label>
        </div>
        <input type="text"
               name={@input_name}
               value={if @is_current, do: "Present", else: @current_value}
               placeholder={@placeholder}
               disabled={@is_current}
               class={"w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-green-500 text-sm #{if @is_current, do: "bg-gray-100 text-gray-500", else: ""}"} />
      </div>
    <% else %>
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">
          <%= humanize_field_name(@field_name) %>
          <%= if @required do %><span class="text-red-500">*</span><% end %>
        </label>
        <input type="text"
               name={@input_name}
               value={@current_value}
               placeholder={@placeholder}
               required={@required}
               class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-green-500 text-sm" />
        <p class="text-xs text-gray-500 mt-1">Format: MM/YYYY</p>
      </div>
    <% end %>
    """
  end

  @impl true
  def handle_event("toggle_current_position", %{"index" => index_str}, socket) do
    {index, _} = Integer.parse(index_str)
    current_items = get_current_items(socket.assigns)

    updated_items = List.update_at(current_items, index, fn item ->
      current_is_current = Map.get(item, "is_current", false)
      updated_item = Map.put(item, "is_current", !current_is_current)

      # Clear end_date if setting to current
      if !current_is_current do
        Map.put(updated_item, "end_date", "Present")
      else
        Map.put(updated_item, "end_date", "")
      end
    end)

    updated_form_data = Map.put(socket.assigns.form_data, "items", updated_items)
    {:noreply, assign(socket, :form_data, updated_form_data)}
  end

  @impl true
  def handle_event("form_change", params, socket) do
    # Update form data while preserving dropdown states
    current_form_data = socket.assigns.form_data
    updated_form_data = Map.merge(current_form_data, params)

    # Rebuild changeset
    updated_changeset = build_form_changeset(updated_form_data, socket.assigns.section_type)

    {:noreply, socket
    |> assign(:form_data, updated_form_data)
    |> assign(:form_changeset, updated_changeset)}
  end

  # ============================================================================
  # FIELD RENDERING HELPERS - FIXED WITH HUMANIZATION
  # ============================================================================

  defp render_field(field_name, field_config, assigns, field_level \\ "essential") do
    field_type = Map.get(field_config, :type, :string)
    current_value = Map.get(assigns.form_data, to_string(field_name), "")
    required = Map.get(field_config, :required, false)
    placeholder = Map.get(field_config, :placeholder, "")

    case field_type do
      :social_links ->
        render_social_links_field(field_name, field_config, current_value, assigns)
      :text ->
        render_text_field(field_name, field_config, current_value, required, placeholder, field_level)
      :select ->
        render_select_field(field_name, field_config, current_value, required, field_level)
      :array ->
        render_array_field(field_name, field_config, current_value, placeholder, field_level)
      :boolean ->
        render_boolean_field(field_name, field_config, current_value, field_level)
      :integer ->
        render_integer_field(field_name, field_config, current_value, required, placeholder, field_level)
      :date ->
        render_date_field(field_name, field_config, current_value, required, placeholder, field_level)
      :file ->
        render_file_field(field_name, field_config, assigns, field_level)
      _ ->
        render_string_field(field_name, field_config, current_value, required, placeholder, field_level)
    end
  end

  # String Field
  defp render_string_field(field_name, _field_config, current_value, required, placeholder, field_level) do
    color_class = get_field_color_class(field_level)

    assigns = %{
      field_name: field_name,
      current_value: current_value,
      placeholder: placeholder,
      required: required,
      color_class: color_class
    }

    ~H"""
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-2">
        <%= humanize_field_name(@field_name) %>
        <%= if @required do %><span class="text-red-500">*</span><% end %>
      </label>
      <input type="text"
             name={to_string(@field_name)}
             value={@current_value}
             placeholder={@placeholder}
             required={@required}
             class={"w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 #{@color_class} focus:border-blue-500"} />
    </div>
    """
  end

  # Text Area Field
  defp render_text_field(field_name, _field_config, current_value, required, placeholder, field_level) do
    color_class = get_field_color_class(field_level)

    assigns = %{
      field_name: field_name,
      current_value: current_value,
      placeholder: placeholder,
      required: required,
      color_class: color_class
    }

    ~H"""
    <div class="md:col-span-2">
      <label class="block text-sm font-medium text-gray-700 mb-2">
        <%= humanize_field_name(@field_name) %>
        <%= if @required do %><span class="text-red-500">*</span><% end %>
      </label>
      <textarea name={to_string(@field_name)}
                placeholder={@placeholder}
                required={@required}
                rows="4"
                class={"w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 #{@color_class} focus:border-blue-500"}><%= @current_value %></textarea>
    </div>
    """
  end

  # ============================================================================
  # HELPER FUNCTIONS - UPDATED
  # ============================================================================

  defp humanize_field_name(field_name) do
    field_name
    |> to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
    |> case do
      "Cta Text" -> "Call-to-Action Text"
      "Cta Link" -> "Call-to-Action Link"
      "Github Username" -> "GitHub Username"
      "Github Url" -> "GitHub URL"
      "Github Stats" -> "GitHub Stats"
      text -> text
    end
  end

  defp get_section_color(section_type) do
    case section_type do
      "hero" -> "#3B82F6"
      "contact" -> "#10B981"
      "intro" -> "#06B6D4"
      "about" -> "#84CC16"
      "experience" -> "#059669"
      "education" -> "#7C3AED"
      "skills" -> "#DC2626"
      "projects" -> "#EA580C"
      "pricing" -> "#FDE047"
      "gallery" -> "#F472B6"
      "blog" -> "#93C5FD"
      "timeline" -> "#A78BFA"
      "code_showcase" -> "#34D399"
      "custom" -> "#6B7280"
      _ -> "#6B7280"
    end
  end

  defp darken_color(hex_color) do
    case hex_color do
      "#3B82F6" -> "#1D4ED8"
      "#10B981" -> "#059669"
      "#06B6D4" -> "#0891B2"
      "#84CC16" -> "#65A30D"
      "#059669" -> "#047857"
      "#7C3AED" -> "#5B21B6"
      "#DC2626" -> "#B91C1C"
      "#EA580C" -> "#C2410C"
      "#FDE047" -> "#EAB308"
      "#F472B6" -> "#EC4899"
      "#93C5FD" -> "#60A5FA"
      "#A78BFA" -> "#8B5CF6"
      "#34D399" -> "#10B981"
      _ -> "#374151"
    end
  end

  defp get_section_icon(section_type) do
    case section_type do
      "hero" -> "🏠"
      "contact" -> "📞"
      "intro" -> "👋"
      "about" -> "👤"
      "experience" -> "💼"
      "education" -> "🎓"
      "skills" -> "🛠️"
      "projects" -> "🚀"
      "pricing" -> "💰"
      "gallery" -> "🖼️"
      "blog" -> "📝"
      "timeline" -> "📅"
      "code_showcase" -> "💻"
      "custom" -> "⚙️"
      _ -> "📄"
    end
  end

  defp get_section_name(section_type) do
    case section_type do
      "hero" -> "Hero Section"
      "contact" -> "Contact Information"
      "intro" -> "Introduction"
      "about" -> "About Me"
      "experience" -> "Work Experience"
      "education" -> "Education"
      "skills" -> "Skills & Expertise"
      "projects" -> "Projects"
      "pricing" -> "Pricing & Services"
      "gallery" -> "Gallery"
      "blog" -> "Blog"
      "timeline" -> "Timeline"
      "code_showcase" -> "Code Showcase"
      "custom" -> "Custom Section"
      _ -> String.capitalize(to_string(section_type))
    end
  end

  defp get_section_description(section_type) do
    case section_type do
      "hero" -> "Main introduction and call-to-action for your portfolio"
      "contact" -> "Contact information and social media links"
      "intro" -> "Brief professional introduction and overview"
      "about" -> "Detailed personal and professional story"
      "experience" -> "Professional work history and achievements"
      "education" -> "Academic background and qualifications"
      "skills" -> "Technical and soft skills with proficiency levels"
      "projects" -> "Portfolio projects and case studies"
      "pricing" -> "Service pricing and package information"
      "gallery" -> "Image and media showcase"
      "blog" -> "Blog integration and recent posts"
      "timeline" -> "Chronological view of important events"
      "code_showcase" -> "Code samples and technical demonstrations"
      "custom" -> "Create your own custom section with flexible content"
      _ -> "Configure this section to match your needs"
    end
  end

  defp get_form_field_types(section_type) do
    base_types = %{
      title: :string,
      section_type: :string,
      visible: :boolean
    }

    section_specific_types = case section_type do
      "hero" ->
        %{
          headline: :string,
          tagline: :string,
          description: :string,
          cta_text: :string,
          cta_link: :string
        }
      "contact" ->
        %{
          email: :string,
          phone: :string,
          location: :string,
          website: :string,
          availability: :string,
          timezone: :string,
          preferred_contact: :string
        }
      "intro" ->
        %{
          summary: :string,
          specialties: :string,
          years_experience: :integer,
          current_focus: :string
        }
      "about" ->
        %{
          story: :string,
          interests: :string,
          values: :string,
          fun_facts: :string
        }
      _ ->
        %{}
    end

    Map.merge(base_types, section_specific_types)
  end

  # ============================================================================
  # REMAINING HELPER FUNCTIONS
  # ============================================================================

  defp get_current_items(assigns) do
    case Map.get(assigns.form_data, "items") do
      items when is_list(items) -> items
      _ -> []
    end
  end

  defp create_empty_item(section_type) do
    item_schema = get_essential_item_schema(section_type)

    Enum.reduce(item_schema, %{}, fn {field_name, field_config}, acc ->
      default_value = get_field_default(field_config)
      Map.put(acc, to_string(field_name), default_value)
    end)
  end

  defp get_field_default(field_config) do
    case field_config do
      %{default: default} -> default
      %{type: :string} -> ""
      %{type: :text} -> ""
      %{type: :array} -> []
      %{type: :integer} -> nil
      %{type: :boolean} -> false
      _ -> ""
    end
  end

  defp get_item_display_title(item, section_type) do
    case section_type do
      "skills" ->
        skill_name = Map.get(item, "skill_name", "")
        category = Map.get(item, "category", "")
        if skill_name != "" do
          "#{skill_name}" <> if(category != "", do: " (#{category})", else: "")
        else
          nil
        end
      "experience" ->
        title = Map.get(item, "title", "")
        company = Map.get(item, "company", "")
        if title != "" and company != "" do
          "#{title} at #{company}"
        else
          nil
        end
      "education" ->
        degree = Map.get(item, "degree", "")
        institution = Map.get(item, "institution", "")
        if degree != "" and institution != "" do
          "#{degree} from #{institution}"
        else
          nil
        end
      "projects" ->
        Map.get(item, "title", nil)
      "services" ->
        Map.get(item, "name", nil)
      "published_articles" ->
        Map.get(item, "title", nil)
      "testimonials" ->
        client = Map.get(item, "client_name", "")
        company = Map.get(item, "client_company", "")
        if client != "" do
          "#{client}" <> if(company != "", do: " - #{company}", else: "")
        else
          nil
        end
      "certifications" ->
        name = Map.get(item, "name", "")
        issuer = Map.get(item, "issuer", "")
        if name != "" and issuer != "" do
          "#{name} (#{issuer})"
        else
          nil
        end
      "achievements" ->
        Map.get(item, "title", nil)
      "collaborations" ->
        Map.get(item, "project_name", nil)
      "pricing" ->
        Map.get(item, "package_name", nil)
      "code_showcase" ->
        title = Map.get(item, "title", "")
        language = Map.get(item, "language", "")
        if title != "" and language != "" do
          "#{title} (#{language})"
        else
          nil
        end
      _ ->
        Map.get(item, "title") || Map.get(item, "name", nil)
    end
  end

  defp get_items_label(section_type) do
    case section_type do
      "skills" -> "Skills"
      "experience" -> "Work Experience"
      "education" -> "Education"
      "projects" -> "Projects"
      "certifications" -> "Certifications"
      "testimonials" -> "Testimonials"
      "services" -> "Services"
      "published_articles" -> "Articles"
      "collaborations" -> "Collaborations"
      "achievements" -> "Achievements"
      "pricing" -> "Pricing Packages"
      "code_showcase" -> "Code Samples"
      _ -> "Items"
    end
  end

  defp get_item_name(section_type) do
    case section_type do
      "skills" -> "Skill"
      "experience" -> "Position"
      "education" -> "Education"
      "projects" -> "Project"
      "certifications" -> "Certification"
      "testimonials" -> "Testimonial"
      "services" -> "Service"
      "published_articles" -> "Article"
      "collaborations" -> "Collaboration"
      "achievements" -> "Achievement"
      "pricing" -> "Package"
      "code_showcase" -> "Code Sample"
      _ -> "Item"
    end
  end

  defp has_essential_items?(section_type) do
    section_type in [
      "experience", "education", "skills", "projects", "testimonials",
      "certifications", "services", "published_articles", "achievements",
      "collaborations", "pricing", "code_showcase"
    ]
  end

  defp has_enhanced_items?(section_type) do
    section_type in [
      "experience", "education", "projects", "services", "collaborations",
      "achievements", "pricing", "code_showcase"
    ]
  end

  defp get_supported_media_types(section_type) do
    case section_type do
      "media_showcase" -> ["image", "video", "audio", "document"]
      "gallery" -> ["image", "video"]
      "projects" -> ["image", "video", "document"]
      "hero" -> ["image", "video"]
      "featured_project" -> ["image", "video", "document"]
      "case_study" -> ["image", "video", "document"]
      "services" -> ["image", "video"]
      "published_articles" -> ["image", "document"]
      "blog" -> ["image"]
      "code_showcase" -> ["image", "video"]
      "testimonials" -> ["image"]
      "achievements" -> ["image", "document"]
      "collaborations" -> ["image", "video", "document"]
      _ -> ["image"]
    end
  end

  defp get_file_accept_string(media_types) do
    accept_map = %{
      "image" => "image/*",
      "video" => "video/*",
      "audio" => "audio/*",
      "document" => ".pdf,.doc,.docx,.txt,.md,.ppt,.pptx,.xls,.xlsx"
    }

    media_types
    |> Enum.map(&Map.get(accept_map, &1, "*/*"))
    |> Enum.join(",")
  end

  defp get_field_color_class(field_level) do
    case field_level do
      "essential" -> "focus:ring-blue-500"
      "enhanced" -> "focus:ring-green-500"
      "advanced" -> "focus:ring-purple-500"
      _ -> "focus:ring-blue-500"
    end
  end

  defp render_social_icon(platform) do
    case platform do
      "linkedin" -> "💼"
      "github" -> "💻"
      "twitter" -> "🐦"
      "instagram" -> "📷"
      "youtube" -> "📺"
      "facebook" -> "📘"
      "behance" -> "🎨"
      "dribbble" -> "🏀"
      "medium" -> "📝"
      _ -> "🔗"
    end
  end

  defp get_platform_placeholder(platform) do
    case platform do
      "linkedin" -> "https://linkedin.com/in/yourusername"
      "github" -> "https://github.com/yourusername"
      "twitter" -> "https://twitter.com/yourusername"
      "instagram" -> "https://instagram.com/yourusername"
      "youtube" -> "https://youtube.com/@yourchannel"
      "facebook" -> "https://facebook.com/yourpage"
      "behance" -> "https://behance.net/yourusername"
      "dribbble" -> "https://dribbble.com/yourusername"
      "medium" -> "https://medium.com/@yourusername"
      "website" -> "https://yourwebsite.com"
      _ -> "https://#{platform}.com/yourusername"
    end
  end

  defp get_default_form_data(section_type) do
    EnhancedSectionSystem.get_default_content(section_type)
  end

  # ============================================================================
  # REMAINING FIELD RENDERING FUNCTIONS
  # ============================================================================

  defp render_select_field(field_name, field_config, current_value, required, field_level) do
    options = Map.get(field_config, :options, [])
    default = Map.get(field_config, :default, "")
    color_class = get_field_color_class(field_level)

    assigns = %{
      field_name: field_name,
      current_value: current_value,
      options: options,
      required: required,
      default: default,
      color_class: color_class
    }

    ~H"""
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-2">
        <%= humanize_field_name(@field_name) %>
        <%= if @required do %><span class="text-red-500">*</span><% end %>
      </label>
      <select name={to_string(@field_name)}
              required={@required}
              class={"w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 #{@color_class} focus:border-blue-500"}>
        <%= if not @required do %>
          <option value="">Select an option</option>
        <% end %>
        <%= for option <- @options do %>
          <option value={option} selected={@current_value == option or (@current_value == "" and option == @default)}>
            <%= String.capitalize(to_string(option)) %>
          </option>
        <% end %>
      </select>
    </div>
    """
  end

  defp render_array_field(field_name, _field_config, current_value, placeholder, field_level) do
    display_value = case current_value do
      list when is_list(list) -> Enum.join(list, ", ")
      str when is_binary(str) -> str
      _ -> ""
    end

    color_class = get_field_color_class(field_level)

    assigns = %{
      field_name: field_name,
      display_value: display_value,
      placeholder: placeholder,
      color_class: color_class
    }

    ~H"""
    <div class="md:col-span-2">
      <label class="block text-sm font-medium text-gray-700 mb-2">
        <%= humanize_field_name(@field_name) %>
      </label>
      <input type="text"
             name={to_string(@field_name)}
             value={@display_value}
             placeholder={@placeholder}
             class={"w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 #{@color_class} focus:border-blue-500"} />
      <p class="text-xs text-gray-500 mt-1">Separate multiple items with commas</p>
    </div>
    """
  end

  defp render_boolean_field(field_name, _field_config, current_value, field_level) do
    checked = case current_value do
      true -> true
      "true" -> true
      _ -> false
    end

    assigns = %{
      field_name: field_name,
      checked: checked
    }

    ~H"""
    <div class="flex items-center justify-between">
      <label class="text-sm font-medium text-gray-700">
        <%= humanize_field_name(@field_name) %>
      </label>
      <label class="relative inline-flex items-center cursor-pointer">
        <input type="checkbox"
               name={to_string(@field_name)}
               value="true"
               checked={@checked}
               class="sr-only peer" />
        <div class="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-blue-300 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600"></div>
      </label>
    </div>
    """
  end

  defp render_integer_field(field_name, _field_config, current_value, required, placeholder, field_level) do
    color_class = get_field_color_class(field_level)

    assigns = %{
      field_name: field_name,
      current_value: current_value,
      placeholder: placeholder,
      required: required,
      color_class: color_class
    }

    ~H"""
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-2">
        <%= humanize_field_name(@field_name) %>
        <%= if @required do %><span class="text-red-500">*</span><% end %>
      </label>
      <input type="number"
             name={to_string(@field_name)}
             value={@current_value}
             placeholder={@placeholder}
             required={@required}
             class={"w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 #{@color_class} focus:border-blue-500"} />
    </div>
    """
  end

  defp render_date_field(field_name, _field_config, current_value, required, placeholder, field_level) do
    color_class = get_field_color_class(field_level)

    assigns = %{
      field_name: field_name,
      current_value: current_value,
      placeholder: placeholder,
      required: required,
      color_class: color_class
    }

    ~H"""
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-2">
        <%= humanize_field_name(@field_name) %>
        <%= if @required do %><span class="text-red-500">*</span><% end %>
      </label>
      <input type="text"
             name={to_string(@field_name)}
             value={@current_value}
             placeholder={@placeholder}
             required={@required}
             class={"w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 #{@color_class} focus:border-blue-500"} />
      <p class="text-xs text-gray-500 mt-1">Format: MM/YYYY or MM/DD/YYYY</p>
    </div>
    """
  end

  defp render_file_field(field_name, field_config, assigns, field_level) do
    accepts = Map.get(field_config, :accepts, "*/*")

    assigns = Map.merge(assigns, %{
      field_name: field_name,
      accepts: accepts
    })

    ~H"""
    <div class="md:col-span-2">
      <label class="block text-sm font-medium text-gray-700 mb-2">
        <%= humanize_field_name(@field_name) %>
      </label>
      <div class="border-2 border-dashed border-gray-300 rounded-lg p-4 text-center hover:border-gray-400 transition-colors">
        <input type="file"
               name={to_string(@field_name)}
               accept={@accepts}
               class="hidden"
               id={"file-#{@field_name}"} />

        <label for={"file-#{@field_name}"} class="cursor-pointer">
          <svg class="w-8 h-8 text-gray-400 mx-auto mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/>
          </svg>
          <p class="text-sm font-medium text-gray-700">Click to upload or drag and drop</p>
          <p class="text-xs text-gray-500">Supports: <%= String.replace(@accepts, "*/*", "all file types") %></p>
        </label>
      </div>
    </div>
    """
  end

  # ============================================================================
  # ITEM FIELD RENDERING HELPERS
  # ============================================================================

  defp render_item_input(name, value, field_name, required, placeholder, input_type \\ "text") do
    assigns = %{
      name: name,
      value: value,
      field_name: field_name,
      required: required,
      placeholder: placeholder,
      input_type: input_type
    }

    ~H"""
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-1">
        <%= humanize_field_name(@field_name) %>
        <%= if @required do %><span class="text-red-500">*</span><% end %>
      </label>
      <input type={@input_type}
             name={@name}
             value={@value}
             placeholder={@placeholder}
             required={@required}
             class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-green-500 text-sm" />
    </div>
    """
  end

  defp render_item_textarea(name, value, field_name, required, placeholder) do
    assigns = %{
      name: name,
      value: value,
      field_name: field_name,
      required: required,
      placeholder: placeholder
    }

    ~H"""
    <div class="md:col-span-2">
      <label class="block text-sm font-medium text-gray-700 mb-1">
        <%= humanize_field_name(@field_name) %>
        <%= if @required do %><span class="text-red-500">*</span><% end %>
      </label>
      <textarea name={@name}
                placeholder={@placeholder}
                required={@required}
                rows="3"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-green-500 text-sm"><%= @value %></textarea>
    </div>
    """
  end

  defp render_item_select(name, value, field_name, options, required) do
    assigns = %{
      name: name,
      value: value,
      field_name: field_name,
      options: options,
      required: required
    }

    ~H"""
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-1">
        <%= humanize_field_name(@field_name) %>
        <%= if @required do %><span class="text-red-500">*</span><% end %>
      </label>
      <select name={@name}
              required={@required}
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-green-500 text-sm">
        <%= if not @required do %>
          <option value="">Select...</option>
        <% end %>
        <%= for option <- @options do %>
          <option value={option} selected={@value == option}>
            <%= String.capitalize(to_string(option)) %>
          </option>
        <% end %>
      </select>
    </div>
    """
  end

  defp render_item_boolean(name, value, field_name) do
    checked = case value do
      true -> true
      "true" -> true
      _ -> false
    end

    assigns = %{
      name: name,
      checked: checked,
      field_name: field_name
    }

    ~H"""
    <div class="flex items-center justify-between">
      <label class="text-sm font-medium text-gray-700">
        <%= humanize_field_name(@field_name) %>
      </label>
      <input type="checkbox"
             name={@name}
             value="true"
             checked={@checked}
             class="w-4 h-4 text-green-600 bg-gray-100 border-gray-300 rounded focus:ring-green-500" />
    </div>
    """
  end

  defp render_item_file(name, field_name, field_config) do
    accepts = Map.get(field_config, :accepts, "*/*")

    assigns = %{
      name: name,
      field_name: field_name,
      accepts: accepts
    }

    ~H"""
    <div class="md:col-span-2">
      <label class="block text-sm font-medium text-gray-700 mb-1">
        <%= humanize_field_name(@field_name) %>
      </label>
      <input type="file"
             name={@name}
             accept={@accepts}
             class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-green-500 text-sm" />
    </div>
    """
  end

  # ============================================================================
  # SECTION TITLE AND REMAINING CORE FUNCTIONS
  # ============================================================================

  defp render_section_title_field(assigns) do
    current_title = case assigns.editing_section do
      %{title: title} when is_binary(title) -> title
      _ -> Map.get(assigns.form_data, "title", get_default_section_title(assigns.section_type))
    end

    assigns = assign(assigns, :current_title, current_title)

    ~H"""
    <div class="mb-6">
      <label class="block text-sm font-medium text-gray-700 mb-2">
        Section Title <span class="text-red-500">*</span>
      </label>
      <input type="text"
             name="title"
             value={@current_title}
             placeholder={"Enter custom title for your #{get_section_name(@section_type)} section"}
             required
             maxlength="100"
             class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 text-lg font-medium" />
      <p class="text-xs text-gray-500 mt-1">
        This title will appear as the section heading in your portfolio.
        Default: "<%= get_default_section_title(@section_type) %>"
      </p>
    </div>
    """
  end

  defp get_default_section_title(section_type) do
    case section_type do
      "hero" -> "Welcome"
      "contact" -> "Contact Information"
      "intro" -> "About Me"
      "about" -> "About"
      "experience" -> "Work Experience"
      "education" -> "Education"
      "skills" -> "Skills & Expertise"
      "projects" -> "Projects"
      "pricing" -> "Pricing"
      "gallery" -> "Gallery"
      "blog" -> "Blog"
      "timeline" -> "Timeline"
      "code_showcase" -> "Code Showcase"
      "custom" -> "Custom Section"
      _ -> String.capitalize(to_string(section_type))
    end
  end

  # ============================================================================
  # PROGRESSIVE DISCLOSURE AND REMAINING EVENT HANDLERS
  # ============================================================================

  defp render_enhanced_fields_section(assigns) do
    enhanced_fields = get_enhanced_fields(assigns.section_type)

    if length(enhanced_fields) > 0 do
      assigns = assign(assigns, :enhanced_fields, enhanced_fields)

      ~H"""
      <div class="bg-green-50 rounded-lg border border-green-200 overflow-hidden">
        <button type="button"
                phx-click="toggle_enhanced_fields" phx-target={@myself}
                class="w-full flex items-center justify-between p-4 text-left hover:bg-green-100 transition-colors">
          <div class="flex items-center">
            <svg class="w-5 h-5 text-green-600 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 100 4m0-4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 100 4m0-4v2m0-6V4"/>
            </svg>
            <h4 class="text-lg font-semibold text-green-800">Enhanced Details</h4>
            <span class="ml-2 text-xs bg-green-200 text-green-700 px-2 py-1 rounded-full">Optional</span>
          </div>
          <svg class={"w-5 h-5 text-green-600 transition-transform #{if @show_enhanced_fields, do: "rotate-180", else: ""}"}
               fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>
          </svg>
        </button>

        <%= if @show_enhanced_fields do %>
          <div class="p-6 border-t border-green-200 bg-white">
            <p class="text-sm text-gray-600 mb-4">Add more details to make your portfolio stand out.</p>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <%= for {field_name, field_config} <- @enhanced_fields do %>
                <%= render_field(field_name, field_config, assigns, "enhanced") %>
              <% end %>
            </div>

            <%= if has_enhanced_items?(@section_type) do %>
              <%= render_enhanced_items_section(assigns) %>
            <% end %>
          </div>
        <% end %>
      </div>
      """
    else
      ~H""
    end
  end

  defp render_enhanced_form_field(field_name, field_config, assigns, field_level) do
    field_type = Map.get(field_config, :type, :string)
    current_value = Map.get(assigns.form_data, to_string(field_name), "")
    required = Map.get(field_config, :required, false)
    placeholder = Map.get(field_config, :placeholder, "")

    case field_type do
      :social_links ->
        render_social_links_field_with_binding(field_name, field_config, assigns)
      :text ->
        render_text_field_with_binding(field_name, current_value, required, placeholder, field_level)
      :select ->
        render_select_field_with_binding(field_name, field_config, current_value, required, field_level)
      :array ->
        render_array_field_with_binding(field_name, current_value, placeholder, field_level)
      :boolean ->
        render_boolean_field_with_binding(field_name, current_value, field_level)
      :integer ->
        render_integer_field_with_binding(field_name, current_value, required, placeholder, field_level)
      _ ->
        render_string_field_with_binding(field_name, current_value, required, placeholder, field_level)
    end
  end

defp render_string_field_with_binding(field_name, current_value, required, placeholder, field_level) do
  color_class = get_field_color_class(field_level)
  field_name_str = to_string(field_name)

  assigns = %{
    field_name: field_name,
    field_name_str: field_name_str,
    current_value: current_value,
    placeholder: placeholder,
    required: required,
    color_class: color_class
  }

  ~H"""
  <div>
    <label class="block text-sm font-medium text-gray-700 mb-2">
      <%= humanize_field_name(@field_name) %>
      <%= if @required do %><span class="text-red-500">*</span><% end %>
    </label>
    <input type="text"
           name={@field_name_str}
           value={@current_value}
           placeholder={@placeholder}
           required={@required}
           phx-change="form_change"
           phx-target={@myself}
           class={"w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 #{@color_class} focus:border-blue-500"} />
  </div>
  """
end

defp render_select_field_with_binding(field_name, field_config, current_value, required, field_level) do
  options = Map.get(field_config, :options, [])
  default = Map.get(field_config, :default, "")
  color_class = get_field_color_class(field_level)
  field_name_str = to_string(field_name)

  assigns = %{
    field_name: field_name,
    field_name_str: field_name_str,
    current_value: current_value,
    options: options,
    required: required,
    default: default,
    color_class: color_class
  }

  ~H"""
  <div>
    <label class="block text-sm font-medium text-gray-700 mb-2">
      <%= humanize_field_name(@field_name) %>
      <%= if @required do %><span class="text-red-500">*</span><% end %>
    </label>
    <select name={@field_name_str}
            required={@required}
            phx-change="form_change"
            phx-target={@myself}
            class={"w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 #{@color_class} focus:border-blue-500"}>
      <%= if not @required do %>
        <option value="">Select an option</option>
      <% end %>
      <%= for option <- @options do %>
        <option value={option} selected={@current_value == option or (@current_value == "" and option == @default)}>
          <%= String.capitalize(to_string(option)) %>
        </option>
      <% end %>
    </select>
  </div>
  """
end

defp render_social_links_field_with_binding(field_name, field_config, assigns) do
  platforms = ["linkedin", "github", "twitter", "instagram", "website", "youtube", "facebook", "behance", "dribbble", "medium"]

  assigns = Map.merge(assigns, %{
    field_name: field_name,
    platforms: platforms
  })

  ~H"""
  <div class="md:col-span-2">
    <label class="block text-sm font-medium text-gray-700 mb-3">
      Social Links & Online Presence
    </label>
    <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
      <%= for platform <- @platforms do %>
        <div>
          <label class="text-xs text-gray-600 capitalize flex items-center">
            <%= render_social_icon(platform) %>
            <span class="ml-1"><%= platform %></span>
          </label>
          <input type="url"
                 name={"social_links[#{platform}]"}
                 value={Map.get(@form_data, "social_links[#{platform}]", "")}
                 placeholder={get_platform_placeholder(platform)}
                 phx-change="form_change"
                 phx-target={@myself}
                 class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 text-sm" />
        </div>
      <% end %>
    </div>
  </div>
  """
end

defp render_text_field_with_binding(field_name, current_value, required, placeholder, field_level) do
  color_class = get_field_color_class(field_level)
  field_name_str = to_string(field_name)

  assigns = %{
    field_name: field_name,
    field_name_str: field_name_str,
    current_value: current_value,
    placeholder: placeholder,
    required: required,
    color_class: color_class
  }

  ~H"""
  <div class="md:col-span-2">
    <label class="block text-sm font-medium text-gray-700 mb-2">
      <%= humanize_field_name(@field_name) %>
      <%= if @required do %><span class="text-red-500">*</span><% end %>
    </label>
    <textarea name={@field_name_str}
              placeholder={@placeholder}
              required={@required}
              phx-change="form_change"
              phx-target={@myself}
              rows="4"
              class={"w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 #{@color_class} focus:border-blue-500"}><%= @current_value %></textarea>
  </div>
  """
end

defp render_array_field_with_binding(field_name, current_value, placeholder, field_level) do
  display_value = case current_value do
    list when is_list(list) -> Enum.join(list, ", ")
    str when is_binary(str) -> str
    _ -> ""
  end

  color_class = get_field_color_class(field_level)
  field_name_str = to_string(field_name)

  assigns = %{
    field_name: field_name,
    field_name_str: field_name_str,
    display_value: display_value,
    placeholder: placeholder,
    color_class: color_class
  }

  ~H"""
  <div class="md:col-span-2">
    <label class="block text-sm font-medium text-gray-700 mb-2">
      <%= humanize_field_name(@field_name) %>
    </label>
    <input type="text"
           name={@field_name_str}
           value={@display_value}
           placeholder={@placeholder}
           phx-change="form_change"
           phx-target={@myself}
           class={"w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 #{@color_class} focus:border-blue-500"} />
    <p class="text-xs text-gray-500 mt-1">Separate multiple items with commas</p>
  </div>
  """
end

defp render_boolean_field_with_binding(field_name, current_value, field_level) do
  checked = case current_value do
    true -> true
    "true" -> true
    _ -> false
  end

  field_name_str = to_string(field_name)

  assigns = %{
    field_name: field_name,
    field_name_str: field_name_str,
    checked: checked
  }

  ~H"""
  <div class="flex items-center justify-between">
    <label class="text-sm font-medium text-gray-700">
      <%= humanize_field_name(@field_name) %>
    </label>
    <label class="relative inline-flex items-center cursor-pointer">
      <input type="checkbox"
             name={@field_name_str}
             value="true"
             checked={@checked}
             phx-change="form_change"
             phx-target={@myself}
             class="sr-only peer" />
      <div class="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-blue-300 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600"></div>
    </label>
  </div>
  """
end

defp render_integer_field_with_binding(field_name, current_value, required, placeholder, field_level) do
  color_class = get_field_color_class(field_level)
  field_name_str = to_string(field_name)

  assigns = %{
    field_name: field_name,
    field_name_str: field_name_str,
    current_value: current_value,
    placeholder: placeholder,
    required: required,
    color_class: color_class
  }

  ~H"""
  <div>
    <label class="block text-sm font-medium text-gray-700 mb-2">
      <%= humanize_field_name(@field_name) %>
      <%= if @required do %><span class="text-red-500">*</span><% end %>
    </label>
    <input type="number"
           name={@field_name_str}
           value={@current_value}
           placeholder={@placeholder}
           required={@required}
           phx-change="form_change"
           phx-target={@myself}
           class={"w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 #{@color_class} focus:border-blue-500"} />
  </div>
  """
end

defp render_item_textarea_with_binding(name, value, field_name, required, placeholder, myself) do
  assigns = %{
    name: name,
    value: value,
    field_name: field_name,
    required: required,
    placeholder: placeholder,
    myself: myself
  }

  ~H"""
  <div class="md:col-span-2">
    <label class="block text-sm font-medium text-gray-700 mb-1">
      <%= humanize_field_name(@field_name) %>
      <%= if @required do %><span class="text-red-500">*</span><% end %>
    </label>
    <textarea name={@name}
              placeholder={@placeholder}
              required={@required}
              phx-change="form_change"
              phx-target={@myself}
              rows="3"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-green-500 text-sm"><%= @value %></textarea>
  </div>
  """
end

defp render_item_date_with_binding(item, index, field_name, field_config, myself) do
  current_value = Map.get(item, to_string(field_name), "")
  required = Map.get(field_config, :required, false)
  placeholder = Map.get(field_config, :placeholder, "")
  input_name = "items[#{index}][#{field_name}]"

  # Special handling for end_date in experience sections
  is_end_date = field_name == :end_date
  is_current = Map.get(item, "is_current", false)

  assigns = %{
    input_name: input_name,
    current_value: current_value,
    field_name: field_name,
    required: required,
    placeholder: placeholder,
    is_end_date: is_end_date,
    is_current: is_current,
    index: index,
    myself: myself
  }

  ~H"""
  <%= if @is_end_date do %>
    <div>
      <div class="flex items-center justify-between mb-2">
        <label class="block text-sm font-medium text-gray-700">
          End Date
        </label>
        <label class="flex items-center text-sm">
          <input type="checkbox"
                 name={"items[#{@index}][is_current]"}
                 value="true"
                 checked={@is_current}
                 phx-change="form_change"
                 phx-target={@myself}
                 class="mr-2 rounded" />
          <span class="text-gray-600">Current Position</span>
        </label>
      </div>
      <input type="text"
             name={@input_name}
             value={if @is_current, do: "Present", else: @current_value}
             placeholder={@placeholder}
             disabled={@is_current}
             phx-change="form_change"
             phx-target={@myself}
             class={"w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-green-500 text-sm #{if @is_current, do: "bg-gray-100 text-gray-500", else: ""}"} />
    </div>
  <% else %>
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-1">
        <%= humanize_field_name(@field_name) %>
        <%= if @required do %><span class="text-red-500">*</span><% end %>
      </label>
      <input type="text"
             name={@input_name}
             value={@current_value}
             placeholder={@placeholder}
             required={@required}
             phx-change="form_change"
             phx-target={@myself}
             class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-green-500 text-sm" />
      <p class="text-xs text-gray-500 mt-1">Format: MM/YYYY</p>
    </div>
  <% end %>
  """
end

defp process_section_content_fixed(params, section_type, base_data) do
  case section_type do
    "hero" ->
      content = %{
        "headline" => Map.get(params, "headline", ""),
        "tagline" => Map.get(params, "tagline", ""),
        "description" => Map.get(params, "description", ""),
        "cta_text" => Map.get(params, "cta_text", ""),
        "cta_link" => Map.get(params, "cta_link", "")
      }
      |> reject_empty_values()

      final_data = Map.put(base_data, "content", content)
      errors = validate_hero_content(content)
      {final_data, errors}

    "contact" ->
      # Fix: Create proper social_links map structure
      social_links = extract_social_links_map(params)

      content = %{
        "email" => Map.get(params, "email", ""),
        "phone" => Map.get(params, "phone", ""),
        "location" => Map.get(params, "location", ""),
        "website" => Map.get(params, "website", ""),
        "social_links" => social_links,
        "availability" => Map.get(params, "availability", ""),
        "timezone" => Map.get(params, "timezone", ""),
        "preferred_contact" => Map.get(params, "preferred_contact", "Email")
      }
      |> reject_empty_values()

      final_data = Map.put(base_data, "content", content)
      errors = validate_contact_content(content)
      {final_data, errors}

    "skills" ->
      # Fix: Extract skills items in the correct format
      skills_items = extract_skills_items(params)

      content = %{
        "items" => skills_items
      }

      final_data = Map.put(base_data, "content", content)
      errors = validate_skills_content(content)
      {final_data, errors}

    section_type when section_type in ["experience", "education", "projects", "testimonials", "certifications", "services", "published_articles", "achievements", "collaborations", "pricing", "code_showcase"] ->
      # Fix: Extract items in correct format for these section types
      items = extract_items_in_correct_format(params, section_type)

      content = %{
        "items" => items
      }

      final_data = Map.put(base_data, "content", content)
      errors = validate_items_content(content, section_type)
      {final_data, errors}

    _ ->
      # Simple content sections
      content = extract_simple_section_content(params, section_type)
      final_data = Map.put(base_data, "content", content)
      errors = %{}
      {final_data, errors}
  end
end



  defp render_advanced_options_section(assigns) do
    advanced_fields = get_advanced_fields(assigns.section_type)

    if length(advanced_fields) > 0 do
      assigns = assign(assigns, :advanced_fields, advanced_fields)

      ~H"""
      <div class="bg-purple-50 rounded-lg border border-purple-200 overflow-hidden">
        <button type="button"
                phx-click="toggle_advanced_options" phx-target={@myself}
                class="w-full flex items-center justify-between p-4 text-left hover:bg-purple-100 transition-colors">
          <div class="flex items-center">
            <svg class="w-5 h-5 text-purple-600 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"/>
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
            </svg>
            <h4 class="text-lg font-semibold text-purple-800">Advanced Options</h4>
            <span class="ml-2 text-xs bg-purple-200 text-purple-700 px-2 py-1 rounded-full">Expert</span>
          </div>
          <svg class={"w-5 h-5 text-purple-600 transition-transform #{if @show_advanced_options, do: "rotate-180", else: ""}"}
               fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>
          </svg>
        </button>

        <%= if @show_advanced_options do %>
          <div class="p-6 border-t border-purple-200 bg-white">
            <p class="text-sm text-gray-600 mb-4">Fine-tune your section with advanced customization options.</p>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <%= for {field_name, field_config} <- @advanced_fields do %>
                <%= render_field(field_name, field_config, assigns, "advanced") %>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
      """
    else
      ~H""
    end
  end

  defp get_advanced_fields(section_type) do
    case section_type do
      "hero" ->
        [
          {:background_image, %{type: :file, accepts: "image/*"}},
          {:text_alignment, %{type: :select, options: ["left", "center", "right"], default: "center"}},
          {:overlay_opacity, %{type: :select, options: ["0", "25", "50", "75"], default: "50"}}
        ]

      "contact" ->
        [
          {:show_map, %{type: :boolean, default: false}},
          {:contact_form_endpoint, %{type: :string, placeholder: "Custom form handler URL"}},
          {:auto_response, %{type: :text, placeholder: "Auto-response message for inquiries"}}
        ]

      "gallery" ->
        [
          {:lazy_loading, %{type: :boolean, default: true}},
          {:thumbnail_size, %{type: :select, options: ["small", "medium", "large"], default: "medium"}},
          {:transition_effect, %{type: :select, options: ["fade", "slide", "zoom"], default: "fade"}}
        ]

      _ ->
        []
    end
  end

  defp render_enhanced_items_section(assigns) do
    if has_enhanced_items?(assigns.section_type) do
      ~H"""
      <div class="mt-6 pt-6 border-t border-green-200">
        <h6 class="text-sm font-medium text-green-800 mb-4">Enhanced Item Details</h6>
        <p class="text-xs text-gray-600 mb-4">
          Add more detailed information to make your items stand out.
        </p>
      </div>
      """
    else
      ~H""
    end
  end

  defp render_essential_items_section(assigns) do
    items = get_current_items(assigns)
    item_schema = get_essential_item_schema(assigns.section_type)

    assigns = Map.merge(assigns, %{
      items: items,
      item_schema: item_schema,
      item_level: "essential"
    })

    ~H"""
    <div class="mt-6 pt-6 border-t border-gray-200">
      <div class="flex items-center justify-between mb-4">
        <h5 class="text-lg font-semibold text-gray-900 flex items-center">
          <svg class="w-5 h-5 mr-2 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/>
          </svg>
          <%= get_items_label(@section_type) %>
        </h5>
        <button type="button"
                phx-click="add_item" phx-target={@myself}
                class="inline-flex items-center px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors font-medium text-sm">
          <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
          </svg>
          Add <%= get_item_name(@section_type) %>
        </button>
      </div>

      <%= if length(@items) > 0 do %>
        <div class="space-y-4">
          <%= for {item, index} <- Enum.with_index(@items) do %>
            <%= render_item_card(item, index, @item_schema, assigns) %>
          <% end %>
        </div>
      <% else %>
        <%= render_empty_items_state(assigns) %>
      <% end %>
    </div>
    """
  end

  defp render_empty_items_state(assigns) do
    ~H"""
    <div class="text-center py-12 bg-gray-50 rounded-lg border-2 border-dashed border-gray-300">
      <svg class="w-12 h-12 text-gray-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/>
      </svg>
      <h5 class="text-lg font-medium text-gray-900 mb-2">No <%= get_items_label(@section_type) %> Added</h5>
      <p class="text-gray-600 mb-6">Start building your <%= String.downcase(get_items_label(@section_type)) %> section by adding your first <%= String.downcase(get_item_name(@section_type)) %>.</p>
      <button type="button"
              phx-click="add_item" phx-target={@myself}
              class="inline-flex items-center px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors font-semibold">
        <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
        </svg>
        Add Your First <%= get_item_name(@section_type) %>
      </button>
    </div>
    """
  end

  # ============================================================================
  # EVENT HANDLERS
  # ============================================================================

  @impl true
  def handle_event("toggle_enhanced_fields", _params, socket) do
    {:noreply, assign(socket, :show_enhanced_fields, !socket.assigns.show_enhanced_fields)}
  end

  @impl true
  def handle_event("toggle_advanced_options", _params, socket) do
    {:noreply, assign(socket, :show_advanced_options, !socket.assigns.show_advanced_options)}
  end

  @impl true
  def handle_event("toggle_media_section", _params, socket) do
    {:noreply, assign(socket, :show_media_section, !socket.assigns.show_media_section)}
  end

  @impl true
  def handle_event("add_item", _params, socket) do
    current_items = get_current_items(socket.assigns)
    new_item = create_empty_item(socket.assigns.section_type)
    # Add new item at the TOP of the list instead of bottom
    updated_items = [new_item | current_items]

    updated_form_data = Map.put(socket.assigns.form_data, "items", updated_items)

    {:noreply, assign(socket, :form_data, updated_form_data)}
  end

  @impl true
  def handle_event("remove_item", %{"index" => index_str}, socket) do
    {index, _} = Integer.parse(index_str)
    current_items = get_current_items(socket.assigns)
    updated_items = List.delete_at(current_items, index)

    updated_form_data = Map.put(socket.assigns.form_data, "items", updated_items)

    {:noreply, assign(socket, :form_data, updated_form_data)}
  end

  @impl true
  def handle_event("toggle_item_visibility", %{"index" => index_str}, socket) do
    {index, _} = Integer.parse(index_str)
    current_items = get_current_items(socket.assigns)

    updated_items = List.update_at(current_items, index, fn item ->
      current_visibility = Map.get(item, "visible", true)
      Map.put(item, "visible", !current_visibility)
    end)

    updated_form_data = Map.put(socket.assigns.form_data, "items", updated_items)

    {:noreply, assign(socket, :form_data, updated_form_data)}
  end

  @impl true
  def handle_event("duplicate_item", %{"index" => index_str}, socket) do
    {index, _} = Integer.parse(index_str)
    current_items = get_current_items(socket.assigns)

    case Enum.at(current_items, index) do
      nil -> {:noreply, socket}
      item ->
        # Create a copy of the item with modified title to indicate it's a duplicate
        duplicated_item = case Map.get(item, "title") do
          nil -> item
          title -> Map.put(item, "title", title <> " (Copy)")
        end

        updated_items = List.insert_at(current_items, index + 1, duplicated_item)
        updated_form_data = Map.put(socket.assigns.form_data, "items", updated_items)

        {:noreply, assign(socket, :form_data, updated_form_data)}
    end
  end

  # ============================================================================
  # FORM PROCESSING AND SAVE HANDLER
  # ============================================================================

  @impl true
  def handle_event("save_section", params, socket) do
    IO.puts("🔧 SAVE_SECTION EVENT RECEIVED")
    IO.puts("🔧 Params: #{inspect(params, pretty: true)}")

    socket = assign(socket, :save_status, :saving)

    {form_data, validation_errors} = process_form_params(params, socket.assigns.section_type)

    # Clean {:safe, content} tuples before validation/saving
    cleaned_form_data = clean_content_for_database(form_data)

    IO.puts("🔧 Cleaned Form Data: #{inspect(cleaned_form_data, pretty: true)}")
    IO.puts("🔧 Validation Errors: #{inspect(validation_errors, pretty: true)}")

    if validation_errors == %{} do
      IO.puts("🔧 NO VALIDATION ERRORS - Sending to parent")
      send(self(), {:save_section, cleaned_form_data, socket.assigns.editing_section})
      {:noreply, assign(socket, :save_status, :saved)}
    else
      IO.puts("🔧 VALIDATION ERRORS FOUND - Staying in modal")
      socket = socket
      |> assign(:form_data, cleaned_form_data)
      |> assign(:validation_errors, validation_errors)
      |> assign(:save_status, :error)

      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("close_section_modal", _params, socket) do
    send(self(), :close_section_modal)
    {:noreply, socket}
  end

  # ============================================================================
  # FORM PROCESSING HELPERS
  # ============================================================================

  defp process_form_params(params, section_type) do
    IO.puts("🔧 PROCESSING FORM PARAMS")
    IO.puts("🔧 Section type: #{section_type}")
    IO.puts("🔧 Raw params: #{inspect(params, pretty: true)}")

    # Clean params first to extract {:safe, content} tuples
    cleaned_params = clean_content_for_database(params)

    # Ensure section_type is always present
    section_type = cleaned_params["section_type"] || section_type

    # Extract basic fields
    form_data = %{
      "title" => Map.get(cleaned_params, "title", ""),
      "visible" => Map.get(cleaned_params, "visible") != "false", # Default to true
      "section_type" => section_type
    }

    # Process section-specific fields using corrected logic
    {processed_data, validation_errors} = process_section_content(cleaned_params, section_type, form_data)

    IO.puts("🔧 Final processed data: #{inspect(processed_data, pretty: true)}")
    IO.puts("🔧 Validation errors: #{inspect(validation_errors, pretty: true)}")

    {processed_data, validation_errors}
  end

  defp process_section_content(params, section_type, base_data) do
    case section_type do
      "hero" ->
        content = %{
          "headline" => Map.get(params, "headline", ""),
          "tagline" => Map.get(params, "tagline", ""),
          "description" => Map.get(params, "description", ""),
          "cta_text" => Map.get(params, "cta_text", ""),
          "cta_link" => Map.get(params, "cta_link", "")
        }
        |> reject_empty_values()

        final_data = Map.put(base_data, "content", content)
        errors = validate_hero_content(content)
        {final_data, errors}

      "contact" ->
        # Fix: Create proper social_links map structure
        social_links = extract_social_links_map(params)

        content = %{
          "email" => Map.get(params, "email", ""),
          "phone" => Map.get(params, "phone", ""),
          "location" => Map.get(params, "location", ""),
          "website" => Map.get(params, "website", ""),
          "social_links" => social_links,
          "availability" => Map.get(params, "availability", ""),
          "timezone" => Map.get(params, "timezone", ""),
          "preferred_contact" => Map.get(params, "preferred_contact", "Email")
        }
        |> reject_empty_values()

        final_data = Map.put(base_data, "content", content)
        errors = validate_contact_content(content)
        {final_data, errors}

      "skills" ->
        # Fix: Extract skills items in the correct format
        skills_items = extract_skills_items(params)

        content = %{
          "items" => skills_items,
          "display_style" => Map.get(params, "display_style", "categorized")
        }

        final_data = Map.put(base_data, "content", content)
        errors = validate_skills_content(content)
        {final_data, errors}

      section_type when section_type in ["experience", "education", "projects", "testimonials", "certifications", "services", "published_articles", "achievements", "collaborations", "pricing", "code_showcase"] ->
        # Fix: Extract items in correct format for these section types
        items = extract_items_in_correct_format(params, section_type)

        content = %{
          "items" => items
        }

        final_data = Map.put(base_data, "content", content)
        errors = validate_items_content(content, section_type)
        {final_data, errors}

      _ ->
        # Simple content sections
        content = extract_simple_section_content(params, section_type)
        final_data = Map.put(base_data, "content", content)
        errors = %{}
        {final_data, errors}
    end
  end

  defp extract_items_in_correct_format(params, section_type) do
    # Get the correct item schema for this section type
    item_schema = get_item_schema_for_section(section_type)

    case Map.get(params, "items") do
      items_map when is_map(items_map) ->
        items_map
        |> Enum.sort_by(fn {index_str, _item} ->
          case Integer.parse(index_str) do
            {int, _} -> int
            :error -> 999
          end
        end)
        |> Enum.map(fn {_index, item_data} ->
          # Process each field according to its schema
          Enum.reduce(item_schema, %{}, fn {field_name, field_config}, acc ->
            field_name_str = to_string(field_name)
            raw_value = Map.get(item_data, field_name_str, "")
            processed_value = process_item_field_value(raw_value, field_config)

            # Only include non-empty values
            if processed_value != "" and processed_value != nil and processed_value != [] do
              Map.put(acc, field_name_str, processed_value)
            else
              acc
            end
          end)
          |> Map.put("visible", Map.get(item_data, "visible", "true") == "true")
        end)
        |> Enum.reject(fn item -> map_size(Map.delete(item, "visible")) == 0 end) # Remove empty items

      _ ->
        []
    end
  end

  defp process_item_field_value(value, field_config) do
    field_type = Map.get(field_config, :type, :string)

    case field_type do
      :array when is_binary(value) ->
        value
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
      :integer ->
        parse_integer(value)
      :boolean ->
        value == "true"
      _ ->
        if is_binary(value), do: String.trim(value), else: value
    end
  end

  defp get_item_schema_for_section(section_type) do
    case section_type do
      "experience" ->
        %{
          title: %{type: :string, required: true},
          company: %{type: :string, required: true},
          start_date: %{type: :string, required: true},
          end_date: %{type: :string},
          is_current: %{type: :boolean, default: false},
          employment_type: %{type: :string, default: "Full-time"},
          location: %{type: :string},
          description: %{type: :text}
        }
      "education" ->
        %{
          degree: %{type: :string, required: true},
          institution: %{type: :string, required: true},
          field_of_study: %{type: :string},
          start_date: %{type: :string},
          graduation_date: %{type: :string},
          gpa: %{type: :string},
          description: %{type: :text}
        }
      "projects" ->
        %{
          title: %{type: :string, required: true},
          description: %{type: :text, required: true},
          status: %{type: :string, default: "Completed"},
          start_date: %{type: :string},
          end_date: %{type: :string},
          technologies: %{type: :array},
          project_url: %{type: :string},
          github_url: %{type: :string}
        }
      "testimonials" ->
        %{
          client_name: %{type: :string, required: true},
          client_title: %{type: :string},
          client_company: %{type: :string},
          feedback: %{type: :text, required: true},
          project: %{type: :string},
          date: %{type: :string},
          rating: %{type: :string, default: "5"}
        }
      "services" ->
        %{
          name: %{type: :string, required: true},
          description: %{type: :text, required: true},
          price: %{type: :string},
          duration: %{type: :string},
          features: %{type: :array}
        }
      "published_articles" ->
        %{
          title: %{type: :string, required: true},
          publication: %{type: :string},
          url: %{type: :string},
          publish_date: %{type: :string},
          excerpt: %{type: :text},
          tags: %{type: :array}
        }
      "certifications" ->
        %{
          name: %{type: :string, required: true},
          issuer: %{type: :string, required: true},
          issue_date: %{type: :string},
          expiration_date: %{type: :string},
          credential_id: %{type: :string},
          credential_url: %{type: :string}
        }
      "achievements" ->
        %{
          title: %{type: :string, required: true},
          description: %{type: :text, required: true},
          date: %{type: :string},
          organization: %{type: :string},
          category: %{type: :string, default: "Award"}
        }
      "collaborations" ->
        %{
          project_name: %{type: :string, required: true},
          collaborators: %{type: :array, required: true},
          description: %{type: :text, required: true},
          your_role: %{type: :string},
          date: %{type: :string},
          outcome: %{type: :text}
        }
      "pricing" ->
        %{
          package_name: %{type: :string, required: true},
          price: %{type: :string, required: true},
          billing_period: %{type: :string, default: "one-time"},
          description: %{type: :text, required: true},
          features: %{type: :array},
          is_featured: %{type: :boolean, default: false}
        }
      "code_showcase" ->
        %{
          title: %{type: :string, required: true},
          language: %{type: :string, required: true},
          description: %{type: :text},
          code_snippet: %{type: :text, required: true},
          repository_url: %{type: :string},
          live_demo_url: %{type: :string}
        }
      _ ->
        %{
          title: %{type: :string, required: true},
          description: %{type: :text}
        }
    end
  end

  defp extract_skills_items(params) do
    # The form sends items as: "items" => %{"0" => %{...}, "1" => %{...}}
    case Map.get(params, "items") do
      items_map when is_map(items_map) ->
        items_map
        |> Enum.sort_by(fn {index_str, _item} ->
          case Integer.parse(index_str) do
            {int, _} -> int
            :error -> 999
          end
        end)
        |> Enum.map(fn {_index, item_data} ->
          %{
            "skill_name" => Map.get(item_data, "skill_name", ""),
            "proficiency" => Map.get(item_data, "proficiency", "Intermediate"),
            "category" => Map.get(item_data, "category", "Technical"),
            "years_experience" => parse_integer(Map.get(item_data, "years_experience", "0")),
            "visible" => Map.get(item_data, "visible", "true") == "true"
          }
        end)
        |> Enum.reject(fn item -> item["skill_name"] == "" end)

      _ ->
        []
    end
  end

  defp process_section_fields(params, fields, form_data) do
    Enum.reduce(fields, {form_data, %{}}, fn {field_name, field_config}, {data_acc, errors_acc} ->
      field_name_str = to_string(field_name)
      field_type = Map.get(field_config, :type, :string)

      case field_type do
        :items ->
          items = extract_items_from_params(params, field_config)
          {Map.put(data_acc, "items", items), errors_acc}
        :array ->
          value = Map.get(params, field_name_str, "")
          array_value = if value != "", do: String.split(value, ",") |> Enum.map(&String.trim/1), else: []
          {Map.put(data_acc, field_name_str, array_value), errors_acc}
        :social_links ->
          social_data = extract_social_links_from_params(params, field_name_str, field_config)
          {Map.put(data_acc, field_name_str, social_data), errors_acc}
        :integer ->
          value = Map.get(params, field_name_str, "")
          integer_value = case Integer.parse(value) do
            {int, _} -> int
            :error -> nil
          end
          {Map.put(data_acc, field_name_str, integer_value), errors_acc}
        :boolean ->
          value = Map.get(params, field_name_str) == "true"
          {Map.put(data_acc, field_name_str, value), errors_acc}
        _ ->
          value = Map.get(params, field_name_str, "")
          {Map.put(data_acc, field_name_str, value), errors_acc}
      end
    end)
  end

  defp extract_social_links_from_params(params, field_name, field_config) do
    platforms = ["linkedin", "github", "twitter", "instagram", "website", "youtube", "facebook", "behance", "dribbble", "medium"]

    # Extract social links from params like "social_links[linkedin]" => "https://..."
    Enum.reduce(platforms, %{}, fn platform, acc ->
      param_key = "#{field_name}[#{platform}]"
      url = Map.get(params, param_key, "")

      # Only include non-empty URLs
      if url != "" and String.trim(url) != "" do
        Map.put(acc, platform, String.trim(url))
      else
        acc
      end
    end)
  end

  defp extract_social_links_map(params) do
    platforms = ["linkedin", "github", "twitter", "instagram", "website", "youtube", "facebook", "behance", "dribbble", "medium"]

    # Extract from nested form structure like "social_links[linkedin]"
    social_links = Enum.reduce(platforms, %{}, fn platform, acc ->
      param_key = "social_links[#{platform}]"
      url = Map.get(params, param_key, "")

      # Only include non-empty URLs
      if url != "" and String.trim(url) != "" do
        Map.put(acc, platform, String.trim(url))
      else
        acc
      end
    end)

    # Also check for direct platform keys (fallback)
    if map_size(social_links) == 0 do
      Enum.reduce(platforms, %{}, fn platform, acc ->
        url = Map.get(params, platform, "")
        if url != "" and String.trim(url) != "" do
          Map.put(acc, platform, String.trim(url))
        else
          acc
        end
      end)
    else
      social_links
    end
  end

  defp extract_items_from_params(params, field_config) do
    item_schema = get_essential_item_schema(params["section_type"] || "custom")

    # The form sends items as: "items" => %{"0" => %{...}, "1" => %{...}}
    case Map.get(params, "items") do
      items_map when is_map(items_map) ->
        # Convert the numbered map to a list of items
        items_map
        |> Enum.sort_by(fn {index_str, _item} -> String.to_integer(index_str) end)
        |> Enum.map(fn {_index, item_data} ->
          # Process each field in the item according to its schema
          Enum.reduce(item_schema, %{}, fn {item_field_name, item_field_config}, acc ->
            field_name_str = to_string(item_field_name)
            raw_value = Map.get(item_data, field_name_str, "")
            processed_value = process_item_field_value(raw_value, field_config)
            Map.put(acc, field_name_str, processed_value)
          end)
        end)

      _ ->
        []
    end
  end

  defp process_item_field_value(value, field_config) do
    field_type = Map.get(field_config, :type, :string)

    case field_type do
      :array when is_binary(value) ->
        value
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
      :integer ->
        parse_integer(value)
      :boolean ->
        value == "true"
      _ ->
        if is_binary(value), do: String.trim(value), else: value
    end
  end

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> 0
    end
  end
  defp parse_integer(value) when is_integer(value), do: value
  defp parse_integer(_), do: 0


  defp validate_form_data(data, section_type) do
    case EnhancedSectionSystem.validate_section_content(section_type, data) do
      %{valid: true} -> %{}
      %{valid: false, errors: errors} -> Map.new(errors)
    end
  end

  # Extract content from {:safe, content} tuples safely
  defp extract_safe_content({:safe, content}) when is_binary(content), do: String.trim(content)
  defp extract_safe_content({:safe, content}) when is_list(content) do
    content
    |> List.flatten()
    |> Enum.reduce("", fn item, acc -> acc <> to_string(item) end)
    |> String.trim()
  end
  defp extract_safe_content(value) when is_binary(value), do: String.trim(value)
  defp extract_safe_content(value) when is_nil(value), do: ""
  defp extract_safe_content(value), do: to_string(value)

  # Clean entire content maps for database storage
  defp clean_content_for_database(content) when is_map(content) do
    content
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      cleaned_value = case value do
        items when is_list(items) ->
          Enum.map(items, &clean_item_for_database/1)
        map when is_map(map) ->
          clean_content_for_database(map)
        other ->
          extract_safe_content(other)
      end
      Map.put(acc, key, cleaned_value)
    end)
  end

  defp clean_item_for_database(item) when is_map(item) do
    item
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      cleaned_value = extract_safe_content(value)
      Map.put(acc, key, cleaned_value)
    end)
  end
  defp clean_item_for_database(item), do: extract_safe_content(item)

  # ============================================================================
  # VALIDATION ERRORS AND MODAL FOOTER
  # ============================================================================

  defp render_validation_errors(assigns) do
    if map_size(assigns.validation_errors) > 0 do
      ~H"""
      <div class="bg-red-50 border border-red-200 rounded-lg p-4">
        <div class="flex">
          <svg class="w-5 h-5 text-red-400 mr-3 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
          </svg>
          <div class="flex-1">
            <h4 class="text-red-800 font-semibold">Please fix the following errors:</h4>
            <ul class="text-red-700 text-sm mt-2 space-y-1">
              <%= for {field, message} <- @validation_errors do %>
                <li>• <%= humanize_field_name(field) %>: <%= message %></li>
              <% end %>
            </ul>
          </div>
        </div>
      </div>
      """
    else
      ~H""
    end
  end

  defp render_modal_footer(assigns) do
    ~H"""
    <div class="border-t border-gray-200 px-6 py-4 bg-gray-50">
      <div class="flex items-center justify-between">
        <div class="flex items-center space-x-4 text-sm text-gray-600">
          <%= if supports_multiple_items?(@section_type) do %>
            <div class="flex items-center">
              <svg class="w-4 h-4 mr-2 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
              </svg>
              <span>Multiple items supported</span>
            </div>
          <% end %>
          <%= if supports_media?(@section_type) do %>
            <div class="flex items-center">
              <svg class="w-4 h-4 mr-2 text-orange-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 002 2z"/>
              </svg>
              <span>Media uploads supported</span>
            </div>
          <% end %>
          <div class="flex items-center">
            <svg class="w-4 h-4 mr-2 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4"/>
            </svg>
            <span>Auto-validation enabled</span>
          </div>
        </div>

        <div class="flex items-center space-x-3">
          <button type="button"
                  phx-click="close_section_modal" phx-target={@myself}
                  class="px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50 transition-colors font-medium">
            Cancel
          </button>
          <button type="submit"
                  form="section-form"
                  class="px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors font-semibold shadow-sm">
            <%= if @editing_section, do: "Update Section", else: "Create Section" %>
          </button>
        </div>
      </div>
    </div>
    """
  end

  defp supports_multiple_items?(section_type) do
    EnhancedSectionSystem.supports_multiple?(section_type)
  end

  defp validate_hero_content(content) do
    errors = %{}

    errors = if content["headline"] == "" do
      Map.put(errors, "headline", "Headline is required")
    else
      errors
    end

    errors = if content["tagline"] == "" do
      Map.put(errors, "tagline", "Tagline is required")
    else
      errors
    end

    errors
  end

  defp validate_contact_content(content) do
    errors = %{}

    errors = if content["email"] == "" do
      Map.put(errors, "email", "Email is required")
    else
      errors
    end

    # Validate social_links is a proper map
    errors = case content["social_links"] do
      map when is_map(map) -> errors
      _ -> Map.put(errors, "social_links", "must be a map")
    end

    errors
  end

  defp validate_skills_content(content) do
    errors = %{}

    case content["items"] do
      items when is_list(items) and length(items) > 0 -> errors
      _ -> Map.put(errors, "items", "At least one skill is required")
    end
  end

  defp validate_items_content(content, _section_type) do
    errors = %{}

    case content["items"] do
      items when is_list(items) and length(items) > 0 -> errors
      _ -> Map.put(errors, "items", "At least one item is required")
    end
  end

  defp extract_simple_section_content(params, section_type) do
    case section_type do
      "intro" ->
        %{
          "summary" => Map.get(params, "summary", ""),
          "specialties" => parse_array_field(Map.get(params, "specialties", "")),
          "years_experience" => parse_integer(Map.get(params, "years_experience", "0")),
          "current_focus" => Map.get(params, "current_focus", "")
        }
      "about" ->
        %{
          "story" => Map.get(params, "story", ""),
          "interests" => parse_array_field(Map.get(params, "interests", "")),
          "values" => parse_array_field(Map.get(params, "values", "")),
          "fun_facts" => parse_array_field(Map.get(params, "fun_facts", ""))
        }
      "pricing" ->
        %{
          "currency" => Map.get(params, "currency", "USD"),
          "billing_model" => Map.get(params, "billing_model", "project"),
          "description" => Map.get(params, "description", ""),
          "payment_methods" => parse_array_field(Map.get(params, "payment_methods", "")),
          "terms" => Map.get(params, "terms", "")
        }
      "gallery" ->
        %{
          "display_style" => Map.get(params, "display_style", "grid"),
          "items_per_row" => Map.get(params, "items_per_row", "3"),
          "show_captions" => Map.get(params, "show_captions") == "true",
          "enable_lightbox" => Map.get(params, "enable_lightbox") == "true",
          "auto_play" => Map.get(params, "auto_play") == "true"
        }
      "custom" ->
        %{
          "custom_title" => Map.get(params, "custom_title", ""),
          "layout_style" => Map.get(params, "layout_style", "list")
        }
      _ ->
        %{"content" => Map.get(params, "content", "")}
    end
    |> reject_empty_values()
  end

  defp parse_array_field(value) when is_binary(value) do
    value
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end
  defp parse_array_field(value) when is_list(value), do: value
  defp parse_array_field(_), do: []

  defp reject_empty_values(map) when is_map(map) do
    map
    |> Enum.reject(fn {_key, value} ->
      case value do
        "" -> true
        [] -> true
        nil -> true
        %{} -> true
        _ -> false
      end
    end)
    |> Enum.into(%{})
  end

end
