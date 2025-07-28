# lib/frestyl_web/live/portfolio_live/portfolio_editor_unified.ex
defmodule FrestylWeb.PortfolioLive.PortfolioEditorUnified do
  @moduledoc """
  Unified Portfolio Editor - Clean, modern editing experience following portfolio_hub design patterns.
  Consolidates all editing functionality into one coherent LiveView with real-time preview.
  """

  use FrestylWeb, :live_view
  import Phoenix.HTML.Form

  alias Frestyl.Portfolios
  alias Frestyl.Portfolios.Portfolio
  alias Frestyl.Media
  alias Phoenix.PubSub
  alias FrestylWeb.PortfolioLive.EnhancedVideoIntroComponent
  alias FrestylWeb.PortfolioLive.Display.PortfolioDisplayCoordinator

  @section_types [
    "achievements",
    "case_study",
    "code_showcase",
    "collaborations",
    "contact",
    "custom",
    "education",
    "experience",
    "featured_project",
    "intro",
    "journey",
    "media_showcase",
    "narrative",
    "projects",
    "published_articles",
    "skills",
    "story",
    "testimonial",
    "timeline",
    "video_hero"
  ]

  @impl true
  def mount(%{"id" => portfolio_id}, session, socket) do
    IO.puts("🔥 MOUNT: Starting mount for portfolio #{portfolio_id}")

    if connected?(socket) do
      PubSub.subscribe(Frestyl.PubSub, "portfolio:#{portfolio_id}")
      PubSub.subscribe(Frestyl.PubSub, "portfolio_preview:#{portfolio_id}")
    end

    current_user = get_current_user_from_session(session)
    IO.puts("🔥 MOUNT: Current user loaded")

    case Portfolios.get_portfolio_with_sections(portfolio_id) do
      {:ok, portfolio} ->
        IO.puts("🔥 MOUNT: Portfolio loaded successfully")
        IO.puts("🔥 MOUNT: About to call assign_portfolio_data_safely")

        socket = socket
        |> assign(:current_user, current_user)
        |> assign_portfolio_data_safely(portfolio)

        IO.puts("🔥 MOUNT: assign_portfolio_data_safely completed")

        socket = socket |> assign_ui_state()
        IO.puts("🔥 MOUNT: assign_ui_state completed")

        socket = socket |> assign_editor_state()
        IO.puts("🔥 MOUNT: assign_editor_state completed")

        {:ok, socket}

      error ->
        IO.puts("❌ MOUNT: Error: #{inspect(error)}")
        {:ok, socket
        |> assign(:current_user, current_user)
        |> put_flash(:error, "Error loading portfolio")
        |> redirect(to: ~p"/portfolios")}
    end
  end

defp assign_portfolio_data_safely(socket, portfolio) do
  IO.puts("🔥 ASSIGN: Starting with portfolio keys: #{inspect(Map.keys(portfolio))}")

  sections = Map.get(portfolio, :sections, [])
  IO.puts("🔥 ASSIGN: Got #{length(sections)} sections")

  customization = Map.get(portfolio, :customization, %{})
  hero_section = find_hero_section(sections)

  socket
  |> assign(:portfolio, portfolio)
  |> assign(:sections, sections)
  |> assign(:customization, customization)
  |> assign(:hero_section, hero_section)
end

defp assign_portfolio_data(socket, portfolio) do
  # Get sections from the portfolio (your Portfolios function already added this)
  sections = Map.get(portfolio, :sections, [])
  customization = Map.get(portfolio, :customization, %{})
  hero_section = find_hero_section(sections)

  socket
  |> assign(:portfolio, portfolio)
  |> assign(:sections, sections)
  |> assign(:customization, customization)
  |> assign(:hero_section, hero_section)
end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, socket
    |> assign(:live_action, socket.assigns.live_action)
    |> apply_action(socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, _params) do
    socket
    |> assign(:page_title, "Edit Portfolio")
    |> assign(:editor_mode, :edit)
  end

  defp apply_action(socket, :preview, _params) do
    socket
    |> assign(:page_title, "Preview Portfolio")
    |> assign(:editor_mode, :preview)
  end

  @impl true
  def handle_params(%{"id" => portfolio_id} = params, uri, socket) do
    preview_mode = if String.contains?(uri, "/editor_preview"), do: :preview, else: :edit

    {:noreply, socket
    |> assign(:live_action, socket.assigns.live_action)
    |> assign(:preview_mode, preview_mode)
    |> maybe_setup_preview_iframe(params)}
  end

  defp maybe_setup_preview_iframe(socket, %{"id" => portfolio_id}) do
    if socket.assigns.preview_mode == :split do
      socket
      |> push_event("setup_preview_iframe", %{
        portfolio_id: portfolio_id,
        preview_url: "/portfolios/#{portfolio_id}/editor_preview"
      })
    else
      socket
    end
  end

  # Add this helper function:
  defp safe_get_sections(portfolio_id) do
    try do
      case Portfolios.list_portfolio_sections(portfolio_id) do
        sections when is_list(sections) -> sections
        _ -> []
      end
    rescue
      _error -> []
    end
  end


  # ============================================================================
  # CORE EVENT HANDLERS
  # ============================================================================

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  @impl true
  def handle_event("toggle_preview", _params, socket) do
    new_mode = if socket.assigns.preview_mode == :split, do: :editor, else: :split
    {:noreply, assign(socket, :preview_mode, new_mode)}
  end

  @impl true
  def handle_event("create_section", %{"section_type" => section_type}, socket) do
    IO.puts("🔥 CREATING SECTION TYPE: #{section_type}")

    # Convert string to atom for enum compatibility
    section_type_atom = case section_type do
      "hero" -> :intro  # Map "hero" to :intro since that's in the enum
      "about" -> :narrative
      "blog" -> :blog
      "testimonial" -> :testimonials  # Map singular to plural
      "achievement" -> :achievements  # Map singular to plural
      "collaboration" -> :collaborations  # Map singular to plural
      "certification" -> :certifications  # Map singular to plural
      "service" -> :services  # Map singular to plural
      other ->
        atom_type = String.to_atom(other)
        # Validate that the atom is in our allowed list
        allowed_types = [
          :intro, :experience, :education, :skills, :projects, :featured_project,
          :case_study, :achievements, :testimonial, :testimonials, :media_showcase,
          :code_showcase, :contact, :custom, :story, :timeline, :narrative,
          :journey, :video_hero, :collaborations, :published_articles,
          :certifications, :services, :blog, :gallery, :hero, :about, :pricing
        ]

        if atom_type in allowed_types do
          atom_type
        else
          IO.puts("⚠️ Unknown section type: #{other}, defaulting to :custom")
          :custom
        end
    end

    IO.puts("🔥 CONVERTED TO ATOM: #{section_type_atom}")

    # Rest of your create_section logic...
  end

  @impl true
  def handle_event("reorder_sections", %{"sections" => section_order}, socket) do
    try do
      # Convert string IDs to integers and validate
      section_ids = Enum.map(section_order, fn id_str ->
        case Integer.parse(id_str) do
          {id, ""} -> id
          _ -> raise "Invalid section ID: #{id_str}"
        end
      end)

      # Verify all sections exist
      existing_ids = Enum.map(socket.assigns.sections, & &1.id)
      missing_ids = section_ids -- existing_ids

      if length(missing_ids) > 0 do
        raise "Missing sections: #{inspect(missing_ids)}"
      end

      # Reorder sections and update positions in database
      case update_section_positions(section_ids, socket.assigns.portfolio.id) do
        {:ok, updated_sections} ->
          # Update both visible_sections and sections in portfolio
          updated_portfolio = socket.assigns.portfolio
                            |> Map.put(:sections, updated_sections)
                            |> Map.put(:visible_sections, updated_sections)

          broadcast_preview_update(socket.assigns.portfolio.id, updated_sections, socket.assigns.customization)

          # Force UI refresh
          {:noreply, socket
          |> assign(:portfolio, updated_portfolio)
          |> assign(:sections, updated_sections)
          |> push_event("sections_reordered", %{sections: updated_sections})
          |> put_flash(:info, "Section order updated successfully")}

        {:error, reason} ->
          {:noreply, socket
          |> put_flash(:error, "Failed to reorder sections: #{reason}")}
      end
    rescue
      error ->
        IO.inspect(error, label: "Section reorder error")
        {:noreply, socket
        |> put_flash(:error, "Failed to reorder sections. Please try again.")}
    end
  end

  @impl true
  def handle_event("edit_section", %{"section_id" => section_id}, socket) do
    case Enum.find(socket.assigns.sections, &(&1.id == String.to_integer(section_id))) do
      nil ->
        {:noreply, put_flash(socket, :error, "Section not found")}

      section ->
        {:noreply, socket
        |> assign(:editing_section, section)
        |> assign(:show_section_modal, true)}
    end
  end

  def handle_info({:close_section_modal}, socket) do
    {:noreply, assign(socket, show_section_modal: false, editing_section: nil)}
  end

  def handle_info({:save_section, params}, socket) do
    case save_section_with_params(socket.assigns.editing_section, params) do
      {:ok, updated_section} ->
        updated_sections = update_section_in_list(socket.assigns.sections, updated_section)

        {:noreply, socket
        |> assign(:sections, updated_sections)
        |> assign(:show_section_modal, false)
        |> assign(:editing_section, nil)
        |> put_flash(:info, "Section updated successfully")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update section")}
    end
  end

  defp save_section_with_params(section, params) do
    # Extract and structure the content based on section type
    structured_content = structure_content_by_section_type(section.section_type, params)

    attrs = %{
      title: params["title"],
      visible: params["visible"] == "true",
      content: structured_content
    }

    Frestyl.Portfolios.update_section(section, attrs)
  end

  defp get_default_content_for_section_type(section_type) do
    case section_type do
      "experience" -> %{
        "jobs" => [get_default_item_for_section_type(section_type)]
      }

      "education" -> %{
        "education" => [get_default_item_for_section_type(section_type)]
      }

      "skills" -> %{
        "skills" => []
      }

      "projects" -> %{
        "projects" => [get_default_item_for_section_type(section_type)]
      }

      "testimonials" -> %{
        "testimonials" => [get_default_item_for_section_type(section_type)]
      }

      "certifications" -> %{
        "certifications" => [get_default_item_for_section_type(section_type)]
      }

      "achievements" -> %{
        "achievements" => [get_default_item_for_section_type(section_type)]
      }

      "services" -> %{
        "services" => [get_default_item_for_section_type(section_type)]
      }

      "blog" -> %{
        "articles" => [get_default_item_for_section_type(section_type)]
      }

      "gallery" -> %{
        "images" => [get_default_item_for_section_type(section_type)]
      }

      _ -> %{
        "content" => Map.get(get_default_item_for_section_type(section_type), "description", "Add your content here...")
      }
    end
  end

  defp normalize_section_type(section_type) when is_atom(section_type), do: section_type
  defp normalize_section_type(section_type) when is_binary(section_type) do
    case section_type do
      "code_showcase" -> :code_showcase
      "media_showcase" -> :media_showcase
      "experience" -> :experience
      "skills" -> :skills
      "projects" -> :projects
      "testimonials" -> :testimonials
      "hero" -> :hero
      "about" -> :about
      "contact" -> :contact
      "published_articles" -> :published_articles
      "collaborations" -> :collaborations
      "certifications" -> :certifications
      "achievements" -> :achievements
      "services" -> :services
      "education" -> :education
      "custom" -> :custom
      _ -> String.to_atom(section_type)
    end
  end

  defp structure_content_by_section_type(section_type, params) do
    case normalize_section_type(section_type) do
      :code_showcase ->
        structure_code_showcase_content(params)
      :media_showcase ->
        structure_media_showcase_content(params)
      :experience ->
        structure_experience_content(params)
      :skills ->
        structure_skills_content(params)
      :projects ->
        structure_projects_content(params)
      :testimonials ->
        structure_testimonials_content(params)
      :hero ->
        structure_hero_content(params)
      :about ->
        structure_about_content(params)
      :contact ->
        structure_contact_content(params)
      :published_articles ->
        structure_published_articles_content(params)
      :collaborations ->
        structure_collaborations_content(params)
      :certifications ->
        structure_certifications_content(params)
      :achievements ->
        structure_achievements_content(params)
      :services ->
        structure_services_content(params)
      :education ->
        structure_education_content(params)
      :custom ->
        structure_custom_content(params)
      _ ->
        %{"description" => params["description"] || params["content"] || ""}
    end
  end

  # Content structuring functions
  defp structure_code_showcase_content(params) do
    %{
      "description" => params["description"],
      "tech_stack" => String.split(params["tech_stack"] || "", ",") |> Enum.map(&String.trim/1),
      "display_style" => params["display_style"],
      "difficulty_level" => params["difficulty_level"],
      "completion_time" => params["completion_time"],
      "code_examples" => extract_code_examples(params)
    }
  end

  defp structure_media_showcase_content(params) do
    %{
      "description" => params["description"],
      "gallery_type" => params["gallery_type"],
      "items_per_row" => String.to_integer(params["items_per_row"] || "3"),
      "show_captions" => params["show_captions"] == "true",
      "enable_lightbox" => params["enable_lightbox"] == "true",
      "show_metadata" => params["show_metadata"] == "true",
      "enable_filtering" => params["enable_filtering"] == "true",
      "media_categories" => extract_media_categories(params)
    }
  end

  defp structure_experience_content(params) do
    %{
      "description" => params["description"],
      "display_style" => params["display_style"],
      "show_duration" => params["show_duration"] == "true",
      "show_skills" => params["show_skills"] == "true",
      "items" => extract_experience_items(params)
    }
  end

  defp structure_skills_content(params) do
    %{
      "description" => params["description"],
      "display_mode" => params["display_mode"],
      "show_proficiency" => params["show_proficiency"] == "true",
      "show_years" => params["show_years"] == "true",
      "enable_filtering" => params["enable_filtering"] == "true",
      "skill_categories" => extract_skill_categories(params)
    }
  end

  defp structure_projects_content(params) do
    %{
      "description" => params["description"],
      "display_style" => params["display_style"],
      "show_technologies" => params["show_technologies"] == "true",
      "show_dates" => params["show_dates"] == "true",
      "enable_filtering" => params["enable_filtering"] == "true",
      "show_github_stats" => params["show_github_stats"] == "true",
      "items" => extract_project_items(params)
    }
  end

  defp structure_testimonials_content(params) do
    %{
      "description" => params["description"],
      "layout_style" => params["layout_style"],
      "items_per_row" => String.to_integer(params["items_per_row"] || "2"),
      "display_settings" => %{
        "show_ratings" => params["show_ratings"] == "true",
        "show_avatars" => params["show_avatars"] == "true",
        "show_company_logos" => params["show_company_logos"] == "true",
        "show_verification" => params["show_verification"] == "true"
      },
      "items" => extract_testimonial_items(params)
    }
  end

  defp structure_hero_content(params) do
    %{
      "headline" => params["headline"],
      "tagline" => params["tagline"],
      "description" => params["description"],
      "background_type" => params["background_type"],
      "background_url" => params["background_url"],
      "background_color" => params["background_color"],
      "text_color" => params["text_color"],
      "text_alignment" => params["text_alignment"],
      "profile_image" => params["profile_image"],
      "show_social_links" => params["show_social_links"] == "true",
      "show_profile_image" => params["show_profile_image"] == "true",
      "enable_parallax" => params["enable_parallax"] == "true",
      "fullscreen_hero" => params["fullscreen_hero"] == "true",
      "cta_buttons" => extract_cta_buttons(params),
      "social_links" => extract_social_links(params)
    }
  end

  defp structure_about_content(params) do
    hero_content = structure_hero_content(params)
    Map.merge(hero_content, %{
      "summary" => params["summary"],
      "highlights" => extract_highlights(params)
    })
  end

  defp structure_contact_content(params) do
    %{
      "description" => params["description"],
      "email" => params["email"],
      "phone" => params["phone"],
      "location" => params["location"],
      "timezone" => params["timezone"],
      "availability_status" => params["availability_status"],
      "response_time" => params["response_time"],
      "availability_note" => params["availability_note"],
      "show_contact_form" => params["show_contact_form"] == "true",
      "form_action" => params["form_action"],
      "success_message" => params["success_message"],
      "show_availability" => params["show_availability"] == "true",
      "show_response_time" => params["show_response_time"] == "true",
      "show_location" => params["show_location"] == "true",
      "contact_methods" => extract_contact_methods(params),
      "form_fields" => extract_form_field_requirements(params)
    }
  end

  defp structure_published_articles_content(params) do
    %{
      "headline" => params["headline"],
      "subtitle" => params["subtitle"],
      "description" => params["description"],
      "display_style" => params["display_style"],
      "show_metrics" => params["show_metrics"] == "true",
      "show_collaboration_details" => params["show_collaboration_details"] == "true",
      "max_articles" => parse_integer(params["max_articles"], 12),
      "sort_by" => params["sort_by"],
      "include_draft_metrics" => params["include_draft_metrics"] == "true",
      "platform_filter" => String.split(params["platform_filter"] || "", ",") |> Enum.map(&String.trim/1),
      "articles" => extract_published_articles(params)
    }
  end

  defp structure_collaborations_content(params) do
    %{
      "description" => params["description"],
      "display_style" => params["display_style"],
      "show_collaborator_info" => params["show_collaborator_info"] == "true",
      "show_project_details" => params["show_project_details"] == "true",
      "show_my_role" => params["show_my_role"] == "true",
      "enable_filtering" => params["enable_filtering"] == "true",
      "items" => extract_collaboration_items(params)
    }
  end

  defp structure_certifications_content(params) do
    %{
      "description" => params["description"],
      "display_style" => params["display_style"],
      "show_expiry_dates" => params["show_expiry_dates"] == "true",
      "show_verification" => params["show_verification"] == "true",
      "show_issuer_logos" => params["show_issuer_logos"] == "true",
      "group_by_issuer" => params["group_by_issuer"] == "true",
      "items" => extract_certification_items(params)
    }
  end

  defp structure_achievements_content(params) do
    %{
      "description" => params["description"],
      "display_style" => params["display_style"],
      "show_dates" => params["show_dates"] == "true",
      "show_metrics" => params["show_metrics"] == "true",
      "show_media" => params["show_media"] == "true",
      "group_by_category" => params["group_by_category"] == "true",
      "items" => extract_achievement_items(params)
    }
  end

  defp structure_services_content(params) do
    %{
      "description" => params["description"],
      "display_style" => params["display_style"],
      "show_pricing" => params["show_pricing"] == "true",
      "show_duration" => params["show_duration"] == "true",
      "enable_booking" => params["enable_booking"] == "true",
      "booking_url" => params["booking_url"],
      "currency" => params["currency"],
      "items" => extract_service_items(params)
    }
  end

  defp structure_education_content(params) do
    %{
      "description" => params["description"],
      "display_style" => params["display_style"],
      "show_gpa" => params["show_gpa"] == "true",
      "show_coursework" => params["show_coursework"] == "true",
      "show_activities" => params["show_activities"] == "true",
      "show_logos" => params["show_logos"] == "true",
      "group_by_type" => params["group_by_type"] == "true",
      "items" => extract_education_items(params)
    }
  end

  defp structure_custom_content(params) do
    %{
      "title" => params["title"] || "",
      "content" => params["content"] || "",
      "layout_type" => params["layout_type"] || "text",
      "custom_html" => params["custom_html"] || "",
      "custom_css" => params["custom_css"] || "",
      "embed_code" => params["embed_code"] || "",
      "background_color" => params["background_color"] || "#ffffff",
      "text_color" => params["text_color"] || "#000000",
      "padding" => params["padding"] || "normal",
      "show_border" => params["show_border"] == "true",
      "border_color" => params["border_color"] || "#e5e7eb",
      "alignment" => params["alignment"] || "left",
      "images" => extract_custom_images(params),
      "links" => extract_custom_links(params),
      "enable_markdown" => params["enable_markdown"] == "true",
      "full_width" => params["full_width"] == "true"
    }
  end

  defp parse_bullet_points(text) do
    text
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(fn line ->
      String.replace(line, ~r/^[•\-\*]\s*/, "")
    end)
  end

  defp parse_integer(value, default \\ 0) do
    case Integer.parse(value || "") do
      {int, _} -> int
      :error -> default
    end
  end

  defp update_section_in_list(sections, updated_section) do
    Enum.map(sections, fn section ->
      if section.id == updated_section.id do
        updated_section
      else
        section
      end
    end)
  end

  # Parameter extraction functions
  defp extract_code_examples(params) do
    case params["code_examples"] do
      nil -> []
      examples when is_map(examples) ->
        examples
        |> Enum.sort_by(fn {key, _value} -> String.to_integer(key) end)
        |> Enum.map(fn {_index, example} -> example end)
      _ -> []
    end
  end

  defp extract_media_categories(params) do
    case params["media_categories"] do
      nil -> %{}
      categories when is_map(categories) ->
        Enum.into(categories, %{}, fn {category_name, category_data} ->
          items = case category_data["items"] do
            nil -> []
            items when is_map(items) ->
              items
              |> Enum.sort_by(fn {key, _value} -> String.to_integer(key) end)
              |> Enum.map(fn {_index, item} -> item end)
            _ -> []
          end
          {category_name, items}
        end)
      _ -> %{}
    end
  end

  defp extract_experience_items(params) do
    case params["items"] do
      nil -> []
      items when is_map(items) ->
        items
        |> Enum.sort_by(fn {key, _value} -> String.to_integer(key) end)
        |> Enum.map(fn {_index, item} ->
          Map.merge(item, %{
            "skills_used" => String.split(item["skills_used"] || "", ",") |> Enum.map(&String.trim/1),
            "achievements" => parse_bullet_points(item["achievements"] || ""),
            "current" => item["current"] == "true"
          })
        end)
      _ -> []
    end
  end

  defp extract_skill_categories(params) do
    case params["skill_categories"] do
      nil -> []
      categories when is_map(categories) ->
        categories
        |> Enum.sort_by(fn {key, _value} -> String.to_integer(key) end)
        |> Enum.map(fn {_index, category} ->
          skills = case category["skills"] do
            nil -> []
            skills when is_map(skills) ->
              skills
              |> Enum.sort_by(fn {key, _value} -> String.to_integer(key) end)
              |> Enum.map(fn {_index, skill} -> skill end)
            _ -> []
          end
          Map.put(category, "skills", skills)
        end)
      _ -> []
    end
  end

  defp extract_project_items(params) do
    case params["items"] do
      nil -> []
      items when is_map(items) ->
        items
        |> Enum.sort_by(fn {key, _value} -> String.to_integer(key) end)
        |> Enum.map(fn {_index, item} ->
          Map.merge(item, %{
            "technologies" => String.split(item["technologies"] || "", ",") |> Enum.map(&String.trim/1),
            "key_features" => parse_bullet_points(item["key_features"] || ""),
            "featured" => item["featured"] == "true",
            "open_source" => item["open_source"] == "true",
            "has_case_study" => item["has_case_study"] == "true",
            "team_size" => parse_integer(item["team_size"])
          })
        end)
      _ -> []
    end
  end

  defp extract_testimonial_items(params) do
    case params["items"] do
      nil -> []
      items when is_map(items) ->
        items
        |> Enum.sort_by(fn {key, _value} -> String.to_integer(key) end)
        |> Enum.map(fn {_index, item} ->
          Map.merge(item, %{
            "rating" => parse_integer(item["rating"], 5),
            "featured" => item["featured"] == "true",
            "verified" => item["verified"] == "true",
            "show_company" => item["show_company"] == "true"
          })
        end)
      _ -> []
    end
  end

  defp extract_cta_buttons(params) do
    case params["cta_buttons"] do
      nil -> []
      buttons when is_map(buttons) ->
        buttons
        |> Enum.sort_by(fn {key, _value} -> String.to_integer(key) end)
        |> Enum.map(fn {_index, button} -> button end)
      _ -> []
    end
  end

  defp extract_social_links(params) do
    %{
      "linkedin" => params["social_linkedin"] || "",
      "twitter" => params["social_twitter"] || "",
      "github" => params["social_github"] || "",
      "instagram" => params["social_instagram"] || "",
      "website" => params["social_website"] || "",
      "email" => params["social_email"] || ""
    }
  end

  defp extract_highlights(params) do
    case params["highlights"] do
      nil -> []
      highlights when is_map(highlights) ->
        highlights
        |> Enum.sort_by(fn {key, _value} -> String.to_integer(key) end)
        |> Enum.map(fn {_index, highlight} -> highlight end)
      _ -> []
    end
  end

  defp extract_contact_methods(params) do
    case params["contact_methods"] do
      nil -> []
      methods when is_map(methods) ->
        methods
        |> Enum.sort_by(fn {key, _value} -> String.to_integer(key) end)
        |> Enum.map(fn {_index, method} ->
          Map.put(method, "preferred", method["preferred"] == "true")
        end)
      _ -> []
    end
  end

  defp extract_form_field_requirements(params) do
    %{
      "name" => params["require_name"] == "true",
      "email" => params["require_email"] == "true",
      "phone" => params["require_phone"] == "true",
      "company" => params["require_company"] == "true",
      "budget" => params["require_budget"] == "true"
    }
  end

  defp extract_published_articles(params) do
    case params["articles"] do
      nil -> []
      articles when is_map(articles) ->
        articles
        |> Enum.sort_by(fn {key, _value} -> String.to_integer(key) end)
        |> Enum.map(fn {_index, article} ->
          Map.merge(article, %{
            "co_authors" => String.split(article["co_authors"] || "", ",") |> Enum.map(&String.trim/1),
            "tags" => String.split(article["tags"] || "", ",") |> Enum.map(&String.trim/1),
            "featured" => article["featured"] == "true",
            "metrics" => %{
              "views" => parse_integer(article["views"]),
              "likes" => parse_integer(article["likes"]),
              "shares" => parse_integer(article["shares"]),
              "comments" => parse_integer(article["comments"])
            }
          })
        end)
      _ -> []
    end
  end

  defp extract_collaboration_items(params) do
    case params["items"] do
      nil -> []
      items when is_map(items) ->
        items
        |> Enum.sort_by(fn {key, _value} -> String.to_integer(key) end)
        |> Enum.map(fn {_index, item} ->
          Map.merge(item, %{
            "technologies" => String.split(item["technologies"] || "", ",") |> Enum.map(&String.trim/1),
            "collaborators" => extract_collaborators(item["collaborators"]),
            "featured" => item["featured"] == "true",
            "ongoing" => item["ongoing"] == "true"
          })
        end)
      _ -> []
    end
  end

  defp extract_certification_items(params) do
    case params["items"] do
      nil -> []
      items when is_map(items) ->
        items
        |> Enum.sort_by(fn {key, _value} -> String.to_integer(key) end)
        |> Enum.map(fn {_index, item} ->
          Map.merge(item, %{
            "skills" => String.split(item["skills"] || "", ",") |> Enum.map(&String.trim/1),
            "featured" => item["featured"] == "true",
            "expires" => item["expires"] == "true"
          })
        end)
      _ -> []
    end
  end

  defp extract_achievement_items(params) do
    case params["items"] do
      nil -> []
      items when is_map(items) ->
        items
        |> Enum.sort_by(fn {key, _value} -> String.to_integer(key) end)
        |> Enum.map(fn {_index, item} ->
          Map.merge(item, %{
            "tags" => String.split(item["tags"] || "", ",") |> Enum.map(&String.trim/1),
            "featured" => item["featured"] == "true",
            "metrics" => parse_achievement_metrics(item)
          })
        end)
      _ -> []
    end
  end

  defp extract_service_items(params) do
    case params["items"] do
      nil -> []
      items when is_map(items) ->
        items
        |> Enum.sort_by(fn {key, _value} -> String.to_integer(key) end)
        |> Enum.map(fn {_index, item} ->
          Map.merge(item, %{
            "features" => parse_bullet_points(item["features"] || ""),
            "deliverables" => parse_bullet_points(item["deliverables"] || ""),
            "price" => parse_float(item["price"]),
            "featured" => item["featured"] == "true",
            "available" => item["available"] == "true"
          })
        end)
      _ -> []
    end
  end

  defp extract_education_items(params) do
    case params["items"] do
      nil -> []
      items when is_map(items) ->
        items
        |> Enum.sort_by(fn {key, _value} -> String.to_integer(key) end)
        |> Enum.map(fn {_index, item} ->
          Map.merge(item, %{
            "relevant_coursework" => parse_bullet_points(item["relevant_coursework"] || ""),
            "activities" => parse_bullet_points(item["activities"] || ""),
            "honors" => parse_bullet_points(item["honors"] || ""),
            "gpa" => parse_float(item["gpa"]),
            "ongoing" => item["ongoing"] == "true"
          })
        end)
      _ -> []
    end
  end

  defp extract_custom_images(params) do
    case params["images"] do
      nil -> []
      images when is_map(images) ->
        images
        |> Enum.sort_by(fn {key, _value} -> String.to_integer(key) end)
        |> Enum.map(fn {_index, image} ->
          Map.merge(image, %{
            "width" => parse_integer(image["width"]),
            "height" => parse_integer(image["height"])
          })
        end)
      _ -> []
    end
  end

  defp extract_custom_links(params) do
    case params["links"] do
      nil -> []
      links when is_map(links) ->
        links
        |> Enum.sort_by(fn {key, _value} -> String.to_integer(key) end)
        |> Enum.map(fn {_index, link} ->
          Map.merge(link, %{
            "new_tab" => link["new_tab"] == "true"
          })
        end)
      _ -> []
    end
  end

  defp extract_collaborators(collaborators_param) do
    case collaborators_param do
      nil -> []
      collaborators when is_map(collaborators) ->
        collaborators
        |> Enum.sort_by(fn {key, _value} -> String.to_integer(key) end)
        |> Enum.map(fn {_index, collaborator} -> collaborator end)
      _ -> []
    end
  end

  defp parse_achievement_metrics(item) do
    %{
      "impact_number" => parse_integer(item["impact_number"]),
      "impact_unit" => item["impact_unit"] || "",
      "ranking" => item["ranking"] || "",
      "participants" => parse_integer(item["participants"])
    }
  end

  defp parse_float(value, default \\ 0.0) do
    case Float.parse(value || "") do
      {float, _} -> float
      :error -> default
    end
  end


  @impl true
  def handle_event("toggle_section_visibility", %{"section_id" => section_id}, socket) do
    case Enum.find(socket.assigns.sections, &(&1.id == String.to_integer(section_id))) do
      nil ->
        {:noreply, socket}

      section ->
        case Portfolios.update_portfolio_section(section, %{visible: !section.visible}) do
          {:ok, updated_section} ->
            sections = update_section_in_list(socket.assigns.sections, updated_section)
            broadcast_preview_update(socket.assigns.portfolio.id, sections, socket.assigns.customization)

            {:noreply, socket
            |> assign(:sections, sections)
            |> push_event("section_visibility_changed", %{
              section_id: updated_section.id,
              visible: updated_section.visible
            })}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to update section visibility")}
        end
    end
  end

  @impl true
  def handle_event("delete_section", %{"section_id" => section_id}, socket) do
    case Enum.find(socket.assigns.sections, &(&1.id == String.to_integer(section_id))) do
      nil ->
        {:noreply, socket}

      section ->
        case Portfolios.delete_portfolio_section(section) do
          {:ok, _} ->
            sections = Enum.reject(socket.assigns.sections, &(&1.id == section.id))

            # Update portfolio with ALL section fields for consistency
            updated_portfolio = socket.assigns.portfolio
                              |> Map.put(:sections, sections)
                              |> Map.put(:visible_sections, sections)
                              |> Map.put(:visible_non_hero_sections, Enum.reject(sections, &is_hero_section?/1))

            broadcast_preview_update(socket.assigns.portfolio.id, sections, socket.assigns.customization)

            {:noreply, socket
            |> assign(:portfolio, updated_portfolio)
            |> assign(:sections, sections)
            |> put_flash(:info, "Section deleted successfully")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to delete section")}
        end
    end
  end

  def handle_event("update_customization", params, socket) do
    portfolio = socket.assigns.portfolio
    current_customization = portfolio.customization || %{}

    # Merge new customization with existing
    updated_customization = Map.merge(current_customization, params)

    # FIX: Use proper update function that works with loaded portfolio
    case update_portfolio_safely(portfolio, %{customization: updated_customization}) do
      {:ok, updated_portfolio} ->
        broadcast_portfolio_update(updated_portfolio)

        {:noreply, socket
        |> assign(:portfolio, updated_portfolio)
        |> assign(:customization, updated_customization)}

      {:error, changeset} ->
        IO.inspect(changeset.errors, label: "Portfolio update errors")
        {:noreply, put_flash(socket, :error, "Failed to update design")}
    end
  end

  @impl true
  def handle_info({:debounced_customization_update, portfolio_id, customization_params}, socket) do
    case Portfolios.update_portfolio_customization_by_id(portfolio_id, customization_params) do
      {:ok, updated_portfolio} ->
        broadcast_preview_update(updated_portfolio.id, socket.assigns.sections, updated_portfolio.customization)

        {:noreply, socket
        |> assign(:portfolio, updated_portfolio)
        |> assign(:customization, updated_portfolio.customization)
        |> assign(:debounce_timer, nil)
        |> assign(:last_updated, DateTime.utc_now())}

      {:error, changeset} ->
        IO.inspect(changeset, label: "Customization Update Error")
        {:noreply, socket
        |> assign(:debounce_timer, nil)
        |> put_flash(:error, "Failed to save design changes")}
    end
  end

  @impl true
  def handle_event("upload_media", _params, socket) do
    # Handle media upload for sections
    {:noreply, socket}
  end

  defp update_section_positions(section_ids, portfolio_id) do
    Portfolios.update_section_positions(section_ids, portfolio_id)
  end

  @impl true
  def handle_event("toggle_create_dropdown", _params, socket) do
    current_state = Map.get(socket.assigns, :show_create_dropdown, false)
    IO.puts("🔥 TOGGLING DROPDOWN: #{current_state} -> #{!current_state}")

    {:noreply, assign(socket, :show_create_dropdown, !current_state)}
  end

  @impl true
  def handle_event("update_single_color", params, socket) do
    IO.puts("🎨 SINGLE COLOR UPDATE: #{inspect(params)}")

    field = params["field"]
    value = params["value"] || params[field]

    if field && value do
      customization_params = %{field => value}

      case Portfolios.update_portfolio_customization(socket.assigns.portfolio, customization_params) do
        {:ok, updated_portfolio} ->
          IO.puts("🎨 COLOR UPDATED - UPDATING SOCKET")

          updated_customization = updated_portfolio.customization
          broadcast_preview_update(updated_portfolio.id, socket.assigns.sections, updated_customization)

          {:noreply, socket
          |> assign(:portfolio, updated_portfolio)
          |> assign(:customization, updated_customization)
          |> assign(:last_updated, DateTime.utc_now())
          |> push_event("design_updated", %{customization: updated_customization})}

        {:error, changeset} ->
          IO.puts("❌ COLOR UPDATE ERROR: #{inspect(changeset.errors)}")
          {:noreply, socket |> put_flash(:error, "Failed to update color")}
      end
    else
      {:noreply, socket}
    end
  end

  # Add this helper function to debug state
  defp debug_socket_state(socket, action) do
    IO.puts("🔍 SOCKET STATE DEBUG - #{action}")
    IO.puts("🔍 Portfolio ID: #{socket.assigns.portfolio.id}")
    IO.puts("🔍 Customization in socket: #{inspect(socket.assigns.customization)}")
    IO.puts("🔍 Customization in portfolio: #{inspect(socket.assigns.portfolio.customization)}")
    socket
  end

  @impl true
  def handle_event("update_typography", params, socket) do
    IO.puts("🔥 TYPOGRAPHY UPDATE: #{inspect(params)}")

    field = params["field"]
    value = params["value"] || params[field]

    if field && value do
      customization_params = %{field => value}

      case Portfolios.update_portfolio_customization(socket.assigns.portfolio, customization_params) do
        {:ok, updated_portfolio} ->
          broadcast_preview_update(updated_portfolio.id, socket.assigns.sections, updated_portfolio.customization)

          {:noreply, socket
          |> assign(:portfolio, updated_portfolio)
          |> assign(:customization, updated_portfolio.customization)
          |> assign(:last_updated, DateTime.utc_now())}

        {:error, _} ->
          {:noreply, socket
          |> put_flash(:error, "Failed to update typography")}
      end
    else
      {:noreply, socket}
    end
  end

@impl true
def handle_event("update_hero_style", %{"style" => style}, socket) do
  customization_params = %{"hero_style" => style}

  case Portfolios.update_portfolio_customization_by_id(socket.assigns.portfolio.id, customization_params) do
    {:ok, updated_portfolio} ->
      broadcast_preview_update(updated_portfolio.id, socket.assigns.sections, updated_portfolio.customization)

      {:noreply, socket
      |> assign(:portfolio, updated_portfolio)
      |> assign(:customization, updated_portfolio.customization)
      |> put_flash(:info, "Hero style updated successfully")}

    {:error, _} ->
      {:noreply, socket
      |> put_flash(:error, "Failed to update hero style")}
  end
end

  @impl true
  def handle_event("update_hero_background", params, socket) do
    section_id = String.to_integer(params["section_id"])
    background_type = params["background_type"]

    case Enum.find(socket.assigns.sections, &(&1.id == section_id)) do
      nil ->
        {:noreply, put_flash(socket, :error, "Hero section not found")}

      section ->
        updated_content = Map.put(section.content || %{}, "background_type", background_type)

        case Portfolios.update_portfolio_section(section, %{content: updated_content}) do
          {:ok, updated_section} ->
            sections = update_section_in_list(socket.assigns.sections, updated_section)
            broadcast_preview_update(socket.assigns.portfolio.id, sections, socket.assigns.customization)

            {:noreply, socket
            |> assign(:sections, sections)
            |> assign(:hero_section, updated_section)
            |> put_flash(:info, "Hero background updated successfully")}

          {:error, _} ->
            {:noreply, socket
            |> put_flash(:error, "Failed to update hero background")}
        end
    end
  end

  @impl true
  def handle_event("toggle_hero_social", params, socket) do
    section_id = String.to_integer(params["section_id"])

    case Enum.find(socket.assigns.sections, &(&1.id == section_id)) do
      nil ->
        {:noreply, put_flash(socket, :error, "Hero section not found")}

      section ->
        current_value = get_in(section.content, ["show_social"]) == true
        updated_content = Map.put(section.content || %{}, "show_social", !current_value)

        case Portfolios.update_portfolio_section(section, %{content: updated_content}) do
          {:ok, updated_section} ->
            sections = update_section_in_list(socket.assigns.sections, updated_section)
            broadcast_preview_update(socket.assigns.portfolio.id, sections, socket.assigns.customization)

            {:noreply, socket
            |> assign(:sections, sections)
            |> assign(:hero_section, updated_section)
            |> put_flash(:info, "Social links setting updated")}

          {:error, _} ->
            {:noreply, socket
            |> put_flash(:error, "Failed to update social links setting")}
        end
    end
  end

  @impl true
  def handle_event("apply_color_preset", %{"preset" => preset_name}, socket) do
    IO.puts("🔥 APPLYING COLOR PRESET: #{preset_name}")

    case get_color_preset_by_name(preset_name) do
      nil ->
        {:noreply, put_flash(socket, :error, "Invalid color preset")}

      preset ->
        portfolio = socket.assigns.portfolio
        current_customization = portfolio.customization || %{}

        updated_customization = Map.merge(current_customization, %{
          "primary_color" => preset.primary,
          "secondary_color" => preset.secondary,
          "accent_color" => preset.accent
        })

        case update_portfolio_safely(portfolio, %{customization: updated_customization}) do
          {:ok, updated_portfolio} ->
            broadcast_portfolio_update(updated_portfolio)

            {:noreply, socket
            |> assign(:portfolio, updated_portfolio)
            |> assign(:customization, updated_customization)
            |> put_flash(:info, "Color preset applied successfully")}

          {:error, changeset} ->
            IO.inspect(changeset.errors, label: "Color preset update errors")
            {:noreply, put_flash(socket, :error, "Failed to apply color preset")}
        end
    end
  end


  defp update_portfolio_safely(portfolio, attrs) do
    try do
      # Method 1: Use the portfolio ID to get a fresh copy
      case Frestyl.Portfolios.get_portfolio(portfolio.id) do
        nil ->
          {:error, :not_found}
        fresh_portfolio ->
          Frestyl.Portfolios.update_portfolio(fresh_portfolio, attrs)
      end
    rescue
      error ->
        IO.inspect(error, label: "Portfolio update error")
        {:error, :update_failed}
    end
  end

  defp broadcast_portfolio_update(portfolio) do
    # Broadcast to preview LiveView
    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "portfolio_preview:#{portfolio.id}",
      {:portfolio_updated, portfolio}
    )

    # Also broadcast to any other portfolio views
    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "portfolio:#{portfolio.id}",
      {:portfolio_updated, portfolio}
    )
  end

  defp process_color_params(params) do
    params
    |> Map.put("primary_color", params["primary_color_hex"] || params["primary_color"])
    |> Map.put("secondary_color", params["secondary_color_hex"] || params["secondary_color"])
    |> Map.put("accent_color", params["accent_color_hex"] || params["accent_color"])
    |> Map.drop(["primary_color_hex", "secondary_color_hex", "accent_color_hex"])
  end

  @impl true
  def handle_event("update_hero_settings", params, socket) do
    hero_section = socket.assigns.hero_section

    case Portfolios.update_portfolio_section(hero_section, format_section_params(params)) do
      {:ok, updated_section} ->
        sections = update_section_in_list(socket.assigns.sections, updated_section)
        broadcast_preview_update(socket.assigns.portfolio.id, sections, socket.assigns.customization)

        {:noreply, socket
        |> assign(:sections, sections)
        |> assign(:hero_section, updated_section)
        |> put_flash(:info, "Hero settings updated successfully")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update hero settings")}
    end
  end

  @impl true
  def handle_event("update_portfolio_settings", params, socket) do
    # Extract only portfolio-specific fields
    portfolio_params = %{
      "title" => params["title"],
      "description" => params["description"],
      "slug" => params["slug"],
      "visibility" => String.to_atom(params["visibility"] || "private")
    }

    case Portfolios.update_portfolio(socket.assigns.portfolio, portfolio_params) do
      {:ok, updated_portfolio} ->
        {:noreply, socket
        |> assign(:portfolio, updated_portfolio)
        |> put_flash(:info, "Portfolio settings updated successfully")}

      {:error, changeset} ->
        IO.inspect(changeset.errors, label: "Portfolio update errors")
        {:noreply, socket
        |> put_flash(:error, "Failed to update portfolio settings")}
    end
  end

  @impl true
  def handle_event("update_seo_settings", params, socket) do
    seo_params = %{
      "meta_description" => params["meta_description"],
      "keywords" => params["keywords"]
    }

    case Portfolios.update_portfolio_seo_settings(socket.assigns.portfolio, seo_params) do
      {:ok, updated_portfolio} ->
        {:noreply, socket
        |> assign(:portfolio, updated_portfolio)
        |> put_flash(:info, "SEO settings updated successfully")}

      {:error, _} ->
        {:noreply, socket
        |> put_flash(:error, "Failed to update SEO settings")}
    end
  end

  @impl true
  def handle_event("export_portfolio", %{"format" => format}, socket) do
    case format do
      "pdf" ->
        # Handle PDF export
        {:noreply, put_flash(socket, :info, "PDF export will be available soon")}

      "json" ->
        # Handle JSON export
        {:noreply, put_flash(socket, :info, "JSON export will be available soon")}

      _ ->
        {:noreply, put_flash(socket, :error, "Invalid export format")}
    end
  end

  @impl true
  def handle_event("add_section_item", %{"section_id" => section_id}, socket) do
    case Enum.find(socket.assigns.sections, &(&1.id == String.to_integer(section_id))) do
      nil ->
        {:noreply, put_flash(socket, :error, "Section not found")}

      section ->
        content = section.content || %{}
        items = Map.get(content, "items", [])
        new_item = get_default_item_for_section_type(section.section_type)
        updated_content = Map.put(content, "items", items ++ [new_item])

        case Portfolios.update_portfolio_section(section, %{content: updated_content}) do
          {:ok, updated_section} ->
            sections = update_section_in_list(socket.assigns.sections, updated_section)
            broadcast_preview_update(socket.assigns.portfolio.id, sections, socket.assigns.customization)

            {:noreply, socket
            |> assign(:sections, sections)
            |> put_flash(:info, "Item added successfully")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to add item")}
        end
    end
  end

  @impl true
  def handle_event("remove_section_item", %{"section_id" => section_id, "item_index" => item_index}, socket) do
    case Enum.find(socket.assigns.sections, &(&1.id == String.to_integer(section_id))) do
      nil ->
        {:noreply, put_flash(socket, :error, "Section not found")}

      section ->
        content = section.content || %{}
        items = Map.get(content, "items", [])
        index = String.to_integer(item_index)
        updated_items = List.delete_at(items, index)
        updated_content = Map.put(content, "items", updated_items)

        case Portfolios.update_portfolio_section(section, %{content: updated_content}) do
          {:ok, updated_section} ->
            sections = update_section_in_list(socket.assigns.sections, updated_section)
            broadcast_preview_update(socket.assigns.portfolio.id, sections, socket.assigns.customization)

            {:noreply, socket
            |> assign(:sections, sections)
            |> put_flash(:info, "Item removed successfully")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to remove item")}
        end
    end
  end

  @impl true
  def handle_event("duplicate_section", %{"section_id" => section_id}, socket) do
    case Enum.find(socket.assigns.sections, &(&1.id == String.to_integer(section_id))) do
      nil ->
        {:noreply, put_flash(socket, :error, "Section not found")}

      section ->
        duplicate_params = %{
          section_type: section.section_type,
          title: "#{section.title} (Copy)",
          content: section.content,
          position: length(socket.assigns.sections),
          visible: section.visible
        }

        case Portfolios.create_portfolio_section(socket.assigns.portfolio.id, duplicate_params) do
          {:ok, new_section} ->
            sections = socket.assigns.sections ++ [new_section]
            broadcast_preview_update(socket.assigns.portfolio.id, sections, socket.assigns.customization)

            {:noreply, socket
            |> assign(:sections, sections)
            |> put_flash(:info, "Section duplicated successfully")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to duplicate section")}
        end
    end
  end

    @impl true
  def handle_event("auto_save", params, socket) do
    # Process auto-save data
    case extract_auto_save_data(params) do
      {:ok, save_data} ->
        # Save relevant data
        {:noreply, socket
        |> assign(:last_saved, DateTime.utc_now())
        |> push_event("auto_save_success", %{timestamp: DateTime.utc_now()})}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  defp extract_auto_save_data(params) do
    # Extract and validate auto-save data
    {:ok, params}
  end

  @impl true
  def handle_event("show_video_recorder", _params, socket) do
    {:noreply, assign(socket, :show_video_recorder, true)}
  end

  @impl true
  def handle_event("show_video_uploader", _params, socket) do
    # For now, show recorder (can be extended to show upload modal)
    {:noreply, assign(socket, :show_video_recorder, true)}
  end

  @impl true
  def handle_event("edit_video_intro", _params, socket) do
    {:noreply, assign(socket, :show_video_recorder, true)}
  end

  @impl true
  def handle_event("delete_video_intro", %{"section_id" => section_id}, socket) do
    case Enum.find(socket.assigns.sections, &(&1.id == String.to_integer(section_id))) do
      nil ->
        {:noreply, put_flash(socket, :error, "Video section not found")}

      section ->
        case Portfolios.delete_portfolio_section(section) do
          {:ok, _} ->
            sections = Enum.reject(socket.assigns.sections, &(&1.id == section.id))
            broadcast_preview_update(socket.assigns.portfolio.id, sections, socket.assigns.customization)

            {:noreply, socket
            |> assign(:sections, sections)
            |> put_flash(:info, "Video introduction deleted successfully")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to delete video introduction")}
        end
    end
  end

  @impl true
  def handle_event("show_resume_import", _params, socket) do
    {:noreply, assign(socket, :show_resume_import, true)}
  end

  @impl true
  def handle_event("close_resume_import", _params, socket) do
    {:noreply, assign(socket, :show_resume_import, false)}
  end

  @impl true
  def handle_event("validate_resume", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("upload_resume", _params, socket) do
    case uploaded_entries(socket, :resume) do
      {[entry], _} ->
        consume_uploaded_entry(socket, entry, fn %{path: path} ->
          # For now, just show success message
          # You can implement actual resume parsing later
          {:ok, :file_uploaded}
        end)

        {:noreply, socket
        |> assign(:show_resume_import, false)
        |> put_flash(:info, "Resume uploaded successfully! (Processing not yet implemented)")}

      _ ->
        {:noreply, socket
        |> put_flash(:error, "Please select a resume file")}
    end
  end

def update_portfolio_customization(%Portfolio{} = portfolio, customization_params) do
  IO.puts("🔥 UPDATING PORTFOLIO CUSTOMIZATION")
  IO.puts("🔥 Portfolio ID: #{portfolio.id}")
  IO.puts("🔥 Current: #{inspect(portfolio.customization)}")
  IO.puts("🔥 Params: #{inspect(customization_params)}")

  # Get current customization (with defaults)
  current_customization = portfolio.customization || %{
    "color_scheme" => "purple-pink",
    "layout_style" => "single_page",
    "section_spacing" => "normal",
    "font_style" => "inter",
    "fixed_navigation" => true,
    "dark_mode_support" => false
  }

  # Merge new parameters
  updated_customization = Map.merge(current_customization, customization_params)

  IO.puts("🔥 Merged: #{inspect(updated_customization)}")

  # Update using changeset
  result = portfolio
  |> Portfolio.changeset(%{customization: updated_customization})
  |> Repo.update()

  case result do
    {:ok, updated_portfolio} ->
      IO.puts("✅ CUSTOMIZATION UPDATED SUCCESSFULLY")
      {:ok, updated_portfolio}

    {:error, changeset} ->
      IO.puts("❌ CUSTOMIZATION UPDATE ERROR: #{inspect(changeset.errors)}")
      IO.puts("❌ CHANGESET DETAILS: #{inspect(changeset)}")
      {:error, changeset}
  end
end

  # ============================================================================
  # PUBSUB HANDLERS
  # ============================================================================

  @impl true
  def handle_info({:section_updated, section}, socket) do
    sections = update_section_in_list(socket.assigns.sections, section)
    {:noreply, assign(socket, :sections, sections)}
  end

  @impl true
  def handle_info({:preview_update, update_data}, socket) do
    # Handle preview updates from other sources
    {:noreply, socket
    |> assign(:sections, Map.get(update_data, :sections, socket.assigns.sections))
    |> assign(:customization, Map.get(update_data, :customization, socket.assigns.customization))}
  end

  @impl true
  def handle_info({:portfolio_updated, portfolio}, socket) do
    {:noreply, assign(socket, :portfolio, portfolio)}
  end

  # Handle messages from video component
  @impl true
  def handle_info(:close_video_recorder, socket) do
    {:noreply, assign(socket, :show_video_recorder, false)}
  end

  @impl true
  def handle_info({:video_intro_complete, video_data}, socket) do
    # Refresh sections to include the new video
    case Portfolios.get_portfolio_with_sections(socket.assigns.portfolio.id) do
      {:ok, updated_portfolio} ->
        {:noreply, socket
        |> assign(:sections, updated_portfolio.sections)
        |> assign(:show_video_recorder, false)
        |> put_flash(:info, "Video introduction added successfully!")}

      {:error, _} ->
        {:noreply, socket
        |> assign(:show_video_recorder, false)
        |> put_flash(:info, "Video saved! Refresh to see changes.")}
    end
  end

  @impl true
  def handle_info({:debounced_portfolio_update, params}, socket) do
    handle_event("update_portfolio_settings", params, socket)
  end

  @impl true
  def handle_info({:debounced_seo_update, params}, socket) do
    handle_event("update_seo_settings", params, socket)
  end

  @impl true
  def handle_info(msg, socket) do
    # Log unhandled messages for debugging
    IO.inspect(msg, label: "Unhandled handle_info message")
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_visibility", %{"visibility" => visibility}, socket) do
    portfolio_params = %{"visibility" => String.to_atom(visibility)}

    case Portfolios.update_portfolio(socket.assigns.portfolio, portfolio_params) do
      {:ok, updated_portfolio} ->
        {:noreply, socket
        |> assign(:portfolio, updated_portfolio)
        |> put_flash(:info, "Visibility updated successfully")}

      {:error, _} ->
        {:noreply, socket
        |> put_flash(:error, "Failed to update visibility")}
    end
  end

  @impl true
  def handle_event("toggle_social_sharing", _params, socket) do
    portfolio = socket.assigns.portfolio
    current_seo_settings = Map.get(portfolio, :seo_settings, %{})
    current_value = Map.get(current_seo_settings, "social_sharing_enabled", false)

    seo_params = %{
      "social_sharing_enabled" => !current_value
    }

    case Portfolios.update_portfolio_seo_settings(portfolio, seo_params) do
      {:ok, updated_portfolio} ->
        {:noreply, socket
        |> assign(:portfolio, updated_portfolio)
        |> put_flash(:info, "Social sharing setting updated")}

      {:error, _} ->
        {:noreply, socket
        |> put_flash(:error, "Failed to update social sharing setting")}
    end
  end

  @impl true
  def handle_event("toggle_analytics", _params, socket) do
    portfolio = socket.assigns.portfolio
    current_settings = Map.get(portfolio, :settings, %{})
    current_value = Map.get(current_settings, "analytics_enabled", false)

    settings_params = %{
      "analytics_enabled" => !current_value
    }

    case Portfolios.update_portfolio_settings(portfolio, settings_params) do
      {:ok, updated_portfolio} ->
        {:noreply, socket
        |> assign(:portfolio, updated_portfolio)
        |> put_flash(:info, "Analytics setting updated")}

      {:error, _} ->
        {:noreply, socket
        |> put_flash(:error, "Failed to update analytics setting")}
    end
  end

  @impl true
  def handle_event("update_custom_css", %{"custom_css" => custom_css}, socket) do
    customization_params = %{"custom_css" => custom_css}

    case Portfolios.update_portfolio_customization(socket.assigns.portfolio, customization_params) do
      {:ok, updated_portfolio} ->
        broadcast_preview_update(updated_portfolio.id, socket.assigns.sections, updated_portfolio.customization)

        {:noreply, socket
        |> assign(:portfolio, updated_portfolio)
        |> assign(:customization, updated_portfolio.customization)
        |> put_flash(:info, "Custom CSS updated")}

      {:error, _} ->
        {:noreply, socket
        |> put_flash(:error, "Failed to update custom CSS")}
    end
  end

  @impl true
  def handle_event("update_font_family", %{"font" => font}, socket) do
    IO.puts("🔥 APPLYING FONT CHANGE: #{font}")

    customization_params = %{
      "font_family" => font
    }

    case Portfolios.update_portfolio_customization_by_id(socket.assigns.portfolio.id, customization_params) do
      {:ok, updated_portfolio} ->
        broadcast_preview_update(updated_portfolio.id, socket.assigns.sections, updated_portfolio.customization)

        {:noreply, socket
        |> assign(:portfolio, updated_portfolio)
        |> assign(:customization, updated_portfolio.customization)
        |> put_flash(:info, "Font updated successfully")}

      {:error, _} ->
        {:noreply, socket
        |> put_flash(:error, "Failed to update font")}
    end
  end

  @impl true
  def handle_event("update_theme", %{"theme" => theme}, socket) do
    IO.puts("🔥 APPLYING THEME CHANGE: #{theme}")

    portfolio = socket.assigns.portfolio
    current_customization = portfolio.customization || %{}

    updated_customization = Map.merge(current_customization, %{
      "theme" => theme,
      "primary_color" => get_theme_primary_color(theme),
      "secondary_color" => get_theme_secondary_color(theme),
      "font_family" => get_theme_font_family(theme)
    })

    case update_portfolio_safely(portfolio, %{customization: updated_customization}) do
      {:ok, updated_portfolio} ->
        broadcast_portfolio_update(updated_portfolio)

        {:noreply, socket
        |> assign(:portfolio, updated_portfolio)
        |> assign(:customization, updated_customization)
        |> put_flash(:info, "Theme updated successfully")}

      {:error, changeset} ->
        IO.inspect(changeset.errors, label: "Theme update errors")
        {:noreply, put_flash(socket, :error, "Failed to update theme")}
    end
  end


  @impl true
  def handle_event("update_professional_type", %{"professional_type" => professional_type}, socket) do
    IO.puts("🔥 UPDATING PROFESSIONAL TYPE: #{professional_type}")

    # Update the portfolio with explicit professional type
    updated_customization = Map.put(socket.assigns.customization, "professional_type", professional_type)
    updated_portfolio = Map.put(socket.assigns.portfolio, :customization, updated_customization)

    # Force CSS and preview update with new type
    css = generate_dynamic_css(updated_portfolio)

    socket = socket
    |> assign(:portfolio, updated_portfolio)
    |> assign(:customization, updated_customization)
    |> push_event("design_updated", %{customization: updated_customization})
    |> push_event("inject_design_css", %{css: css})

    # Database update
    case Portfolios.update_portfolio_customization_by_id(socket.assigns.portfolio.id, %{"professional_type" => professional_type}) do
      {:ok, db_updated_portfolio} ->
        broadcast_preview_update(db_updated_portfolio.id, socket.assigns.sections, db_updated_portfolio.customization)
        {:noreply, socket |> assign(:portfolio, db_updated_portfolio)}

      {:error, error} ->
        IO.puts("❌ Failed to update professional type: #{inspect(error)}")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("update_portfolio_layout", %{"portfolio_layout" => layout}, socket) do
    IO.puts("🔥 UPDATING PORTFOLIO LAYOUT: #{layout}")

    customization_params = %{"portfolio_layout" => layout}

    case Portfolios.update_portfolio_customization_by_id(socket.assigns.portfolio.id, customization_params) do
      {:ok, updated_portfolio} ->
        IO.puts("✅ Database updated with layout: #{layout}")
        IO.puts("🔍 Updated customization: #{inspect(updated_portfolio.customization)}")

        broadcast_preview_update(updated_portfolio.id, socket.assigns.sections, updated_portfolio.customization)

        {:noreply, socket
        |> assign(:portfolio, updated_portfolio)
        |> assign(:customization, updated_portfolio.customization)
        |> put_flash(:info, "Layout updated successfully")}

      {:error, error} ->
        IO.puts("❌ Failed to update layout: #{inspect(error)}")
        {:noreply, socket
        |> put_flash(:error, "Failed to update layout")}
    end
  end

  defp get_theme_primary_color(theme) do
    case theme do
      "professional" -> "#1e40af"
      "creative" -> "#7c3aed"
      "developer" -> "#059669"
      "minimalist" -> "#374151"
      _ -> "#1e40af"
    end
  end

  defp get_theme_secondary_color(theme) do
    case theme do
      "professional" -> "#64748b"
      "creative" -> "#ec4899"
      "developer" -> "#10b981"
      "minimalist" -> "#6b7280"
      _ -> "#64748b"
    end
  end

  defp get_color_preset_by_name(preset_name) do
    presets = get_color_presets()
    Enum.find(presets, fn preset -> preset.name == preset_name end)
  end

  defp get_theme_font_family(theme) do
    case theme do
      "professional" -> "Inter, sans-serif"
      "creative" -> "Montserrat, sans-serif"
      "developer" -> "JetBrains Mono, monospace"
      "minimalist" -> "Helvetica, sans-serif"
      _ -> "Inter, sans-serif"
    end
  end

  # ADD broadcast function:
  defp broadcast_portfolio_preview_update(portfolio) do
    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "portfolio_preview:#{portfolio.id}",
      {:portfolio_updated, portfolio}
    )
  end

  @impl true
  def handle_event("view_section_details", %{"section_id" => section_id}, socket) do
    case Enum.find(socket.assigns.sections, &(&1.id == String.to_integer(section_id))) do
      nil ->
        {:noreply, put_flash(socket, :error, "Section not found")}

      section ->
        {:noreply, socket
        |> assign(:viewing_section, section)
        |> assign(:show_section_details_modal, true)}
    end
  end

  @impl true
  def handle_event("toggle_section_actions", %{"section_id" => section_id}, socket) do
    current_active = Map.get(socket.assigns, :active_section_id)
    current_show = Map.get(socket.assigns, :show_actions, false)

    if current_active == section_id && current_show do
      # Close if clicking the same section's dropdown
      {:noreply, socket
      |> assign(:show_actions, false)
      |> assign(:active_section_id, nil)}
    else
      # Open dropdown for this section (close others)
      {:noreply, socket
      |> assign(:show_actions, true)
      |> assign(:active_section_id, section_id)}
    end
  end

  @impl true
  def handle_event("close_section_actions", _params, socket) do
    {:noreply, socket
    |> assign(:show_actions, false)
    |> assign(:active_section_id, nil)}
  end

  # Add event handler for viewing section details in modal:
  @impl true
  def handle_event("view_section_details", %{"section_id" => section_id}, socket) do
    case Enum.find(socket.assigns.sections, &(&1.id == String.to_integer(section_id))) do
      nil ->
        {:noreply, put_flash(socket, :error, "Section not found")}

      section ->
        {:noreply, socket
        |> assign(:viewing_section, section)
        |> assign(:show_section_details_modal, true)}
    end
  end

  # Add event handler for closing section details modal:
  @impl true
  def handle_event("close_section_details_modal", _params, socket) do
    {:noreply, socket
    |> assign(:show_section_details_modal, false)
    |> assign(:viewing_section, nil)}
  end

  @impl true
  def handle_event("toggle_add_section_panel", _params, socket) do
    current_state = Map.get(socket.assigns, :show_add_section_panel, true)
    {:noreply, assign(socket, :show_add_section_panel, !current_state)}
  end

  @impl true
  def handle_event("close_modal_on_escape", %{"key" => "Escape"}, socket) do
    {:noreply, socket
    |> assign(:show_section_modal, false)
    |> assign(:editing_section, nil)
    |> assign(:show_video_recorder, false)
    |> assign(:show_resume_import, false)}
  end

  # Handle any key but only act on Escape
  @impl true
  def handle_event("close_modal_on_escape", _params, socket) do
    # Ignore non-Escape keys
    {:noreply, socket}
  end

  @impl true
  def handle_event("start_hero_video_recording", _params, socket) do
    {:noreply, socket
    |> assign(:show_hero_video_recorder, true)
    |> assign(:hero_video_mode, :recording)}
  end

  @impl true
  def handle_event("show_hero_video_uploader", _params, socket) do
    {:noreply, socket
    |> assign(:show_hero_video_uploader, true)}
  end

  @impl true
  def handle_event("remove_hero_video", _params, socket) do
    section = socket.assigns.editing_section
    content = section.content || %{}
    updated_content = content
    |> Map.delete("video_url")
    |> Map.delete("video_duration")
    |> Map.put("video_type", "none")

    case Portfolios.update_portfolio_section(section, %{content: updated_content}) do
      {:ok, updated_section} ->
        {:noreply, socket
        |> assign(:editing_section, updated_section)
        |> put_flash(:info, "Video removed successfully")}

      {:error, _} ->
        {:noreply, socket
        |> put_flash(:error, "Failed to remove video")}
    end
  end

  @impl true
def handle_event("update_professional_type", %{"professional_type" => type}, socket) do
  IO.puts("🔥 APPLYING PROFESSIONAL TYPE CHANGE: #{type}")

  portfolio = socket.assigns.portfolio
  current_customization = portfolio.customization || %{}

  updated_customization = Map.merge(current_customization, %{
    "professional_type" => type
  })

  case update_portfolio_safely(portfolio, %{customization: updated_customization}) do
    {:ok, updated_portfolio} ->
      broadcast_portfolio_update(updated_portfolio)

      {:noreply, socket
      |> assign(:portfolio, updated_portfolio)
      |> assign(:customization, updated_customization)
      |> put_flash(:info, "Professional type updated successfully")}

    {:error, changeset} ->
      IO.inspect(changeset.errors, label: "Professional type update errors")
      {:noreply, put_flash(socket, :error, "Failed to update professional type")}
  end
end

@impl true
def handle_event("update_portfolio_layout", %{"portfolio_layout" => layout}, socket) do
  IO.puts("🔥 APPLYING LAYOUT CHANGE: #{layout}")

  portfolio = socket.assigns.portfolio
  current_customization = portfolio.customization || %{}

  updated_customization = Map.merge(current_customization, %{
    "portfolio_layout" => layout
  })

  case update_portfolio_safely(portfolio, %{customization: updated_customization}) do
    {:ok, updated_portfolio} ->
      broadcast_portfolio_update(updated_portfolio)

      {:noreply, socket
      |> assign(:portfolio, updated_portfolio)
      |> assign(:customization, updated_customization)
      |> put_flash(:info, "Layout updated successfully")}

    {:error, changeset} ->
      IO.inspect(changeset.errors, label: "Layout update errors")
      {:noreply, put_flash(socket, :error, "Failed to update layout")}
  end
end



  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp assign_ui_state(socket) do
    socket
    |> assign(:active_tab, "sections")
    |> assign(:preview_mode, :split)
    |> assign(:show_section_modal, false)
    |> assign(:editing_section, nil)
    |> assign(:section_changeset, nil)
    |> assign(:show_create_dropdown, false)
    |> assign(:show_video_recorder, false)
    |> assign(:show_resume_import, false)
    |> assign(:pending_customization_update, false)
    |> assign(:debounce_timer, nil)
    |> assign(:last_updated, DateTime.utc_now())
    |> assign(:section_types, @section_types)
    |> assign(:show_add_section_panel, true)
    |> assign(:show_hero_video_recorder, false)  # NEW: Hero-specific video recorder
    |> assign(:show_hero_video_uploader, false)  # NEW: Hero-specific video uploader
    |> assign(:hero_video_mode, nil)  # NEW: Track video mode for hero
    |> allow_upload(:resume,
      accept: ~w(.pdf .doc .docx .txt),
      max_entries: 1,
      max_file_size: 5_000_000)
  end

  defp assign_editor_state(socket) do
    socket
    |> assign(:editor_mode, :edit)
    |> assign(:autosave_enabled, true)
    |> assign(:last_saved, DateTime.utc_now())
  end

  defp ensure_all_assigns(socket) do
    required_assigns = [
      :show_video_recorder,
      :pending_customization_update,
      :show_section_modal,
      :editing_section,
      :section_changeset,
      :show_create_dropdown,
      :current_user,
      :preview_mode,
      :autosave_enabled,
      :last_saved
    ]

    Enum.reduce(required_assigns, socket, fn assign_key, acc_socket ->
      if Map.has_key?(acc_socket.assigns, assign_key) do
        acc_socket
      else
        case assign_key do
          :show_video_recorder -> assign(acc_socket, :show_video_recorder, false)
          :pending_customization_update -> assign(acc_socket, :pending_customization_update, false)
          :show_section_modal -> assign(acc_socket, :show_section_modal, false)
          :editing_section -> assign(acc_socket, :editing_section, nil)
          :section_changeset -> assign(acc_socket, :section_changeset, nil)
          :show_create_dropdown -> assign(acc_socket, :show_create_dropdown, false)
          :current_user -> assign(acc_socket, :current_user, get_current_user_from_session(acc_socket))
          :preview_mode -> assign(acc_socket, :preview_mode, :split)
          :autosave_enabled -> assign(acc_socket, :autosave_enabled, true)
          :last_saved -> assign(acc_socket, :last_saved, DateTime.utc_now())
          _ -> acc_socket
        end
      end
    end)
  end

  defp is_hero_section?(section) do
    section_type = Map.get(section, :section_type) || Map.get(section, "section_type")
    section_type == :hero or section_type == "hero"
  end

  defp find_hero_section(sections) when is_list(sections) do
    Enum.find(sections, fn section ->
      section_type = Map.get(section, :section_type) || Map.get(section, "section_type")
      section_type == :hero or section_type == "hero"
    end)
  end
  defp find_hero_section(_), do: nil

  defp safe_get_sections(portfolio_id) do
    try do
      case Portfolios.list_portfolio_sections(portfolio_id) do
        sections when is_list(sections) -> sections
        _ -> []
      end
    rescue
      _error -> []
    end
  end

  defp get_current_user_from_session(session) do
    case session do
      %{"user_token" => user_token} when not is_nil(user_token) ->
        # Try to get user from token - adapt this to your auth system
        case Frestyl.Accounts.get_user_by_session_token(user_token) do
          %Frestyl.Accounts.User{} = user -> user
          _ -> create_fallback_user()
        end

      _ -> create_fallback_user()
    end
  rescue
    _ -> create_fallback_user()
  end

  defp create_fallback_user do
    %{
      id: -1,  # Use -1 to indicate this is a fallback user
      username: "User",
      name: "Anonymous User",
      email: "user@example.com",
      subscription_tier: "free",
      role: "user",
      verified: false,
      status: "active",
      preferences: %{},
      social_links: %{},
      avatar_url: nil,
      display_name: "User",
      full_name: nil,
      totp_enabled: false,
      backup_codes: [],
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
  end

  # Add these functions to portfolio_editor_unified.ex

  defp get_all_available_sections do
    [
      # Core sections (available to everyone)
      {"intro", "Hero/About", "Essential", "👋"},
      {"experience", "Experience", "Essential", "💼"},
      {"skills", "Skills", "Essential", "⚡"},
      {"projects", "Projects", "Essential", "🚀"},
      {"contact", "Contact", "Essential", "📧"},

      # Professional sections
      {"education", "Education", "Professional", "🎓"},
      {"achievements", "Achievements", "Professional", "🏆"},
      {"testimonials", "Testimonials", "Professional", "💬"},
      {"services", "Services", "Business", "🏢"},
      {"certifications", "Certifications", "Professional", "📜"},

      # Creative sections
      {"media_showcase", "Media Gallery", "Creative", "🎨"},
      {"collaborations", "Collaborations", "Creative", "🤝"},
      {"blog", "Blog/Articles", "Creative", "✍️"},

      # Technical sections
      {"code_showcase", "Code Showcase", "Technical", "💻"},

      # Flexible sections
      {"custom", "Custom Section", "Universal", "⚙️"}
    ]
  end

  defp get_sections_for_professional_type(professional_type) do
    all_sections = get_all_available_sections()

    case professional_type do
      "developer" ->
        suggested = ["intro", "code_showcase", "projects", "experience", "skills", "contact"]
        {filter_suggested(all_sections, suggested), all_sections}

      "creative" ->
        suggested = ["intro", "media_showcase", "projects", "collaborations", "experience", "testimonials", "contact"]
        {filter_suggested(all_sections, suggested), all_sections}

      "service_provider" ->
        suggested = ["intro", "services", "experience", "testimonials", "achievements", "contact"]
        {filter_suggested(all_sections, suggested), all_sections}

      "musician" ->
        suggested = ["intro", "media_showcase", "collaborations", "testimonials", "contact"]
        {filter_suggested(all_sections, suggested), all_sections}

      _ ->
        suggested = ["intro", "experience", "skills", "projects", "contact"]
        {filter_suggested(all_sections, suggested), all_sections}
    end
  end

  defp filter_suggested(all_sections, suggested_ids) do
    Enum.filter(all_sections, fn {id, _, _, _} -> id in suggested_ids end)
  end

  defp get_default_section_title(section_type) do
    case section_type do
      "hero" -> "Welcome"
      "about" -> "About Me"
      "experience" -> "Experience"
      "education" -> "Education"
      "skills" -> "Skills"
      "projects" -> "Projects"
      "testimonials" -> "Testimonials"
      "contact" -> "Contact"
      "certifications" -> "Certifications"
      "achievements" -> "Achievements"
      "services" -> "Services"
      "blog" -> "Blog"
      "gallery" -> "Gallery"
      "custom" -> "Custom Section"
      "narrative" -> "My Story"
      "published_articles" -> "Published Articles"
      _ -> String.capitalize(section_type)
    end
  end

  defp get_default_section_content(section_type) do
    case section_type do
      "experience" -> %{
        "jobs" => [get_default_item_for_section_type(section_type)]
      }

      "education" -> %{
        "education" => [get_default_item_for_section_type(section_type)]
      }

      "skills" -> %{
        "skills" => []
      }

      "projects" -> %{
        "projects" => [get_default_item_for_section_type(section_type)]
      }

      "testimonials" -> %{
        "testimonials" => [get_default_item_for_section_type(section_type)]
      }

      "certifications" -> %{
        "certifications" => [get_default_item_for_section_type(section_type)]
      }

      "achievements" -> %{
        "achievements" => [get_default_item_for_section_type(section_type)]
      }

      "services" -> %{
        "services" => [get_default_item_for_section_type(section_type)]
      }

      "blog" -> %{
        "articles" => [get_default_item_for_section_type(section_type)]
      }

      "gallery" -> %{
        "images" => [get_default_item_for_section_type(section_type)]
      }

      "hero" -> %{
        "headline" => "Welcome to My Portfolio",
        "summary" => "A brief introduction about yourself and your professional journey.",
        "location" => "",
        "website" => "",
        "social_links" => %{}
      }

      "intro" -> %{
        "headline" => "Welcome to My Portfolio",
        "summary" => "A brief introduction about yourself and your professional journey.",
        "location" => "",
        "website" => "",
        "social_links" => %{}
      }

      "about" -> %{
        "content" => "Tell your story here...",
        "highlights" => []
      }

      "narrative" -> %{
        "content" => "Tell your story here...",
        "highlights" => []
      }

      "contact" -> %{
        "email" => "",
        "phone" => "",
        "location" => "",
        "social_links" => %{},
        "contact_form_enabled" => true
      }

      _ -> %{
        "content" => "Add your content here..."
      }
    end
  end

  defp get_section_types do
    [
      {"intro", "Hero/About"},
      {"experience", "Experience"},
      {"skills", "Skills"},
      {"projects", "Projects"},
      {"education", "Education"},
      {"achievements", "Achievements"},
      {"testimonials", "Testimonials"},
      {"media_showcase", "Media Gallery"},
      {"code_showcase", "Code Showcase"},
      {"collaborations", "Collaborations"},
      {"services", "Services"},
      {"blog", "Blog/Articles"},
      {"contact", "Contact"},
      {"custom", "Custom Section"}
    ]
  end

  defp get_section_description(section_type) do
    case section_type do
      "hero" -> "Main banner with headline and call-to-action"
      "about" -> "Personal introduction and background"
      "experience" -> "Work history and career timeline"
      "education" -> "Academic background and qualifications"
      "skills" -> "Technical and professional abilities"
      "projects" -> "Portfolio projects and case studies"
      "testimonials" -> "Client reviews and recommendations"
      "contact" -> "Contact information and form"
      "certifications" -> "Professional certifications"
      "achievements" -> "Awards and accomplishments"
      "services" -> "Services offered with pricing"
      "blog" -> "Blog posts and articles"
      "gallery" -> "Image gallery showcase"
      "custom" -> "Flexible custom content section"
      "published_articles" -> "Showcase syndicated articles and collaborative content"
      _ -> "Additional portfolio content"
    end
  end

  defp get_section_modal_component(section_type) do
    IO.puts("🔍 Getting modal component for section type: #{inspect(section_type)}")

    component = case section_type do
      :experience -> FrestylWeb.PortfolioLive.Modals.ExperienceModalComponent
      :skills -> FrestylWeb.PortfolioLive.Modals.SkillsModalComponent
      :projects -> FrestylWeb.PortfolioLive.Modals.ProjectsModalComponent
      :code_showcase -> FrestylWeb.PortfolioLive.Modals.CodeShowcaseModalComponent
      :media_showcase -> FrestylWeb.PortfolioLive.Modals.MediaShowcaseModalComponent
      :testimonials -> FrestylWeb.PortfolioLive.Modals.TestimonialsModalComponent
      :achievements -> FrestylWeb.PortfolioLive.Modals.AchievementsModalComponent
      :collaborations -> FrestylWeb.PortfolioLive.Modals.CollaborationsModalComponent
      :contact -> FrestylWeb.PortfolioLive.Modals.ContactModalComponent
      :education -> FrestylWeb.PortfolioLive.Modals.EducationModalComponent
      :services -> FrestylWeb.PortfolioLive.Modals.ServicesModalComponent
      :blog -> FrestylWeb.PortfolioLive.Modals.BlogArticlesModalComponent
      :custom -> FrestylWeb.PortfolioLive.Modals.CustomModalComponent

      # Map additional section types
      :intro -> FrestylWeb.PortfolioLive.Modals.HeroAboutModalComponent
      :about -> FrestylWeb.PortfolioLive.Modals.HeroAboutModalComponent
      :hero -> FrestylWeb.PortfolioLive.Modals.HeroAboutModalComponent
      :narrative -> FrestylWeb.PortfolioLive.Modals.HeroAboutModalComponent
      :journey -> FrestylWeb.PortfolioLive.Modals.HeroAboutModalComponent

      # Fallback to base modal
      _ ->
        IO.puts("🔍 Using BaseSectionModalComponent as fallback for: #{inspect(section_type)}")
        FrestylWeb.PortfolioLive.Modals.BaseSectionModalComponent
    end

    IO.puts("🔍 Selected modal component: #{inspect(component)}")
    component
  end

  defp format_section_params(params) do
    content = build_section_content(params)

    %{
      title: params["title"] || "",
      content: content,
      visible: params["visible"] != "false"
    }
  end

  defp build_section_content(params) do
    params
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      if key not in ["title", "visible", "section_id", "_target"] do
        Map.put(acc, key, value)
      else
        acc
      end
    end)
  end

  defp extract_customization_params(params) do
    # Only extract valid customization fields
    valid_fields = [
      "primary_color", "secondary_color", "accent_color",
      "font_family", "font_size", "border_radius",
      "theme", "portfolio_layout", "professional_type",
      "custom_css", "enable_dark_mode", "enable_animations",
      "section_spacing"
    ]

    params
    |> Map.take(valid_fields)
    |> Enum.reject(fn {_key, value} -> value in [nil, ""] end)
    |> Map.new()
  end

  defp update_section_in_list(sections, updated_section) do
    Enum.map(sections, fn section ->
      if section.id == updated_section.id, do: updated_section, else: section
    end)
  end

  defp reorder_sections_by_ids(sections, section_order) do
    # Reorder sections based on provided order and update positions
    sections
    |> Enum.sort_by(fn section ->
      Enum.find_index(section_order, &(&1 == to_string(section.id))) || 999
    end)
    |> Enum.with_index()
    |> Enum.map(fn {section, index} ->
      Map.put(section, :position, index)
    end)
  end

  defp broadcast_preview_update(portfolio_id, sections, customization) do
    # Build portfolio structure for CSS generation
    portfolio = %{
      id: portfolio_id,
      customization: customization,
      theme: Map.get(customization, "theme", "professional")
    }

    # Generate the CSS
    css = generate_dynamic_css(portfolio)

    # Broadcast with immediate CSS injection
    Phoenix.PubSub.broadcast(Frestyl.PubSub, "portfolio_preview:#{portfolio_id}", {
      :preview_update,
      %{
        css: css,
        customization: customization,
        portfolio: portfolio,
        sections: sections,
        force_update: true  # Add this flag
      }
    })

    # Also send direct CSS injection event
    Phoenix.PubSub.broadcast(Frestyl.PubSub, "portfolio_preview:#{portfolio_id}", {
      :inject_css,
      %{css: css}
    })

    IO.puts("✅ PREVIEW UPDATE BROADCASTED - CSS: #{String.length(css)} chars")
    IO.puts("🎨 Layout: #{Map.get(customization, "portfolio_layout", "unknown")}")
    IO.puts("👔 Professional Type: #{Map.get(customization, "professional_type", "unknown")}")
  end

  defp time_ago(datetime) when is_struct(datetime, DateTime) do
    case DateTime.diff(DateTime.utc_now(), datetime, :second) do
      seconds when seconds < 60 -> "just now"
      seconds when seconds < 3600 -> "#{div(seconds, 60)}m ago"
      seconds when seconds < 86400 -> "#{div(seconds, 3600)}h ago"
      seconds -> "#{div(seconds, 86400)}d ago"
    end
  end
  defp time_ago(_), do: "unknown"

  defp generate_dynamic_css(portfolio) do
    customization = portfolio.customization || %{}

    primary_color = Map.get(customization, "primary_color", "#1e40af")
    secondary_color = Map.get(customization, "secondary_color", "#64748b")
    accent_color = Map.get(customization, "accent_color", "#f59e0b")
    font_family = Map.get(customization, "font_family", "Inter, sans-serif")
    font_size = Map.get(customization, "font_size", "medium")
    border_radius = Map.get(customization, "border_radius", "medium")
    theme = Map.get(customization, "theme", "professional")
    portfolio_layout = Map.get(customization, "portfolio_layout", "grid")
    professional_type = Map.get(customization, "professional_type", "general")

    # Convert values to CSS units
    font_size_px = case font_size do
      "small" -> "14px"
      "medium" -> "16px"
      "large" -> "18px"
      _ -> "16px"
    end

    border_radius_px = case border_radius do
      "none" -> "0px"
      "small" -> "4px"
      "medium" -> "8px"
      "large" -> "12px"
      "xl" -> "16px"
      _ -> "8px"
    end

    custom_css = Map.get(customization, "custom_css", "")

    """
    :root {
      --primary-color: #{primary_color};
      --secondary-color: #{secondary_color};
      --accent-color: #{accent_color};
      --font-family: #{font_family};
      --font-size: #{font_size_px};
      --border-radius: #{border_radius_px};
      --theme: #{theme};
      --portfolio-layout: #{portfolio_layout};
      --professional-type: #{professional_type};
    }

    /* ===== TARGET ACTUAL RENDERED ELEMENTS ===== */

    /* Portfolio Display Container */
    .portfolio-display,
    .portfolio-preview-container,
    .portfolio-container,
    .basic-portfolio-layout {
      font-family: var(--font-family) !important;
      font-size: var(--font-size) !important;
    }

    /* ===== LAYOUT-SPECIFIC TARGETING ===== */

    /* Grid Layout - FIXED SQUARE SECTIONS */
    [data-portfolio-layout="grid"] {
      background: #ffffff !important;
      padding: 1rem !important;
    }

    [data-portfolio-layout="grid"] .portfolio-sections,
    [data-portfolio-layout="grid"] > * {
      display: grid !important;
      grid-template-columns: repeat(auto-fit, minmax(320px, 1fr)) !important;
      grid-auto-rows: 320px !important; /* FIXED SQUARE HEIGHT */
      gap: 1.5rem !important;
    }

    [data-portfolio-layout="grid"] .portfolio-section {
      background: white !important;
      border-radius: 12px !important;
      padding: 1.5rem !important;
      box-shadow: 0 4px 12px rgba(0,0,0,0.1) !important;
      border: 1px solid #e5e7eb !important;
      width: 100% !important;
      height: 100% !important; /* Fill the fixed grid cell */
      overflow: hidden !important;
      display: flex !important;
      flex-direction: column !important;
    }

    [data-portfolio-layout="grid"] .portfolio-section .section-title {
      flex-shrink: 0 !important;
      margin-bottom: 1rem !important;
      font-weight: 600 !important;
      font-size: 1.1rem !important;
    }

    [data-portfolio-layout="grid"] .portfolio-section .section-content {
      flex: 1 !important;
      overflow-y: auto !important;
      padding-right: 8px !important;
      min-height: 0 !important; /* Important for flex scrolling */
    }

    [data-portfolio-layout="grid"] .portfolio-section:hover {
      transform: translateY(-2px) !important;
      box-shadow: 0 8px 24px rgba(0,0,0,0.15) !important;
    }

    /* Dashboard Layout - MAX HEIGHT, SCROLLABLE */
    [data-portfolio-layout="dashboard"] {
      background: linear-gradient(135deg, #f1f5f9 0%, #e2e8f0 100%) !important;
      padding: 1rem !important;
    }

    [data-portfolio-layout="dashboard"] .portfolio-sections,
    [data-portfolio-layout="dashboard"] > * {
      display: grid !important;
      grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)) !important;
      gap: 1rem !important;
      grid-auto-rows: auto !important; /* Auto height, controlled by max-height */
    }

    [data-portfolio-layout="dashboard"] .portfolio-section {
      background: white !important;
      border-radius: 8px !important;
      padding: 1rem !important;
      box-shadow: 0 2px 8px rgba(0,0,0,0.08) !important;
      border: 1px solid #d1d5db !important;
      max-height: 250px !important; /* MAX HEIGHT - NOT FIXED */
      overflow: hidden !important;
      display: flex !important;
      flex-direction: column !important;
    }

    [data-portfolio-layout="dashboard"] .portfolio-section .section-title {
      flex-shrink: 0 !important;
      margin-bottom: 0.75rem !important;
      font-weight: 600 !important;
      font-size: 1rem !important;
    }

    [data-portfolio-layout="dashboard"] .portfolio-section .section-content {
      flex: 1 !important;
      overflow-y: auto !important;
      padding-right: 6px !important;
      min-height: 0 !important;
    }

    /* Single Column - MAX HEIGHT, SCROLLABLE */
    [data-portfolio-layout="single_column"] {
      max-width: 800px !important;
      margin: 0 auto !important;
      background: #f8fafc !important;
      padding: 2rem !important;
      border-radius: 12px !important;
    }

    [data-portfolio-layout="single_column"] .portfolio-sections,
    [data-portfolio-layout="single_column"] > * {
      display: flex !important;
      flex-direction: column !important;
      gap: 2rem !important;
    }

    [data-portfolio-layout="single_column"] .portfolio-section {
      background: white !important;
      padding: 2rem !important;
      border-radius: 12px !important;
      box-shadow: 0 2px 8px rgba(0,0,0,0.1) !important;
      border-left: 4px solid var(--primary-color) !important;
      max-height: 400px !important; /* MAX HEIGHT - NOT FIXED */
      overflow: hidden !important;
      display: flex !important;
      flex-direction: column !important;
    }

    [data-portfolio-layout="single_column"] .portfolio-section .section-title {
      flex-shrink: 0 !important;
      margin-bottom: 1.5rem !important;
      font-weight: 600 !important;
      font-size: 1.25rem !important;
    }

    [data-portfolio-layout="single_column"] .portfolio-section .section-content {
      flex: 1 !important;
      overflow-y: auto !important;
      padding-right: 12px !important;
      min-height: 0 !important;
    }

    /* Creative Layout - MAX HEIGHT, SCROLLABLE */
    [data-portfolio-layout="creative"] {
      background: linear-gradient(135deg, #f8fafc 0%, #e2e8f0 100%) !important;
      padding: 1rem !important;
    }

    [data-portfolio-layout="creative"] .portfolio-sections,
    [data-portfolio-layout="creative"] > * {
      display: grid !important;
      grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)) !important;
      gap: 1.5rem !important;
      grid-auto-rows: auto !important; /* Auto height, controlled by max-height */
    }

    [data-portfolio-layout="creative"] .portfolio-section {
      background: linear-gradient(135deg, white 0%, #f8fafc 100%) !important;
      border-radius: 16px !important;
      padding: 1.5rem !important;
      box-shadow: 0 6px 20px rgba(0,0,0,0.1) !important;
      max-height: 350px !important; /* MAX HEIGHT - NOT FIXED */
      overflow: hidden !important;
      display: flex !important;
      flex-direction: column !important;
    }

    /* Hero section in creative gets special treatment */
    [data-portfolio-layout="creative"] .portfolio-section:first-child {
      grid-column: 1 / -1 !important;
      max-height: 250px !important;
    }

    [data-portfolio-layout="creative"] .portfolio-section .section-title {
      flex-shrink: 0 !important;
      margin-bottom: 1rem !important;
      font-weight: 600 !important;
      font-size: 1.1rem !important;
    }

    [data-portfolio-layout="creative"] .portfolio-section .section-content {
      flex: 1 !important;
      overflow-y: auto !important;
      padding-right: 10px !important;
      min-height: 0 !important;
    }

    [data-portfolio-layout="creative"] .portfolio-section:hover {
      transform: scale(1.01) !important;
      box-shadow: 0 12px 32px rgba(0,0,0,0.15) !important;
    }

    /* ===== SCROLLBAR STYLING FOR ALL LAYOUTS ===== */
    [data-portfolio-layout] .section-content::-webkit-scrollbar {
      width: 6px !important;
    }

    [data-portfolio-layout] .section-content::-webkit-scrollbar-track {
      background: #f8f9fa !important;
      border-radius: 3px !important;
    }

    [data-portfolio-layout] .section-content::-webkit-scrollbar-thumb {
      background: #d1d5db !important;
      border-radius: 3px !important;
    }

    [data-portfolio-layout] .section-content::-webkit-scrollbar-thumb:hover {
      background: #9ca3af !important;
    }

    /* ===== RESPONSIVE BEHAVIOR ===== */
    @media (max-width: 768px) {
      /* Grid stays square but smaller on mobile */
      [data-portfolio-layout="grid"] .portfolio-sections,
      [data-portfolio-layout="grid"] > * {
        grid-template-columns: 1fr !important;
        grid-auto-rows: 280px !important;
      }

      /* Other layouts stack single column on mobile */
      [data-portfolio-layout="dashboard"] .portfolio-sections,
      [data-portfolio-layout="creative"] .portfolio-sections {
        grid-template-columns: 1fr !important;
      }
    }

    /* ===== PROFESSIONAL TYPE STYLING ===== */

    .portfolio-display[data-professional-type="creative"] {
      --accent-color: #ec4899;
      background: linear-gradient(135deg, #fdf2f8 0%, #f3e8ff 100%);
    }

    .portfolio-display[data-professional-type="creative"] .portfolio-section {
      border-top: 3px solid var(--accent-color);
    }

    .portfolio-display[data-professional-type="technical"] {
      --accent-color: #10b981;
      background: #f0fdf4;
    }

    .portfolio-display[data-professional-type="technical"] .portfolio-section {
      border-left: 4px solid var(--accent-color);
      font-family: 'JetBrains Mono', 'Courier New', monospace;
    }

    .portfolio-display[data-professional-type="business"] {
      --accent-color: #3b82f6;
      background: #f8fafc;
    }

    .portfolio-display[data-professional-type="business"] .portfolio-section {
      box-shadow: 0 2px 8px rgba(59, 130, 246, 0.1);
      border: 1px solid rgba(59, 130, 246, 0.2);
    }

    /* ===== COLOR APPLICATIONS ===== */

    /* Primary color applications */
    .text-primary,
    .text-blue-600,
    h1, h2, h3, h4, h5, h6 {
      color: var(--primary-color) !important;
    }

    .bg-primary,
    .bg-blue-600,
    .btn-primary {
      background-color: var(--primary-color) !important;
    }

    .border-primary,
    .border-blue-500 {
      border-color: var(--primary-color) !important;
    }

    /* Apply to common elements */
    .section-title {
      color: var(--primary-color) !important;
    }

    .hero-section h1 {
      color: var(--primary-color) !important;
    }

    #{custom_css}
    """
  end

  defp get_color_suggestions do
    [
      %{name: "Ocean Blue", primary: "#1e40af", secondary: "#64748b", accent: "#3b82f6"},
      %{name: "Forest Green", primary: "#059669", secondary: "#6b7280", accent: "#10b981"},
      %{name: "Sunset Orange", primary: "#ea580c", secondary: "#6b7280", accent: "#f97316"},
      %{name: "Royal Purple", primary: "#7c3aed", secondary: "#6b7280", accent: "#8b5cf6"},
      %{name: "Rose Gold", primary: "#be185d", secondary: "#6b7280", accent: "#ec4899"},
      %{name: "Charcoal", primary: "#374151", secondary: "#6b7280", accent: "#6366f1"}
    ]
  end

  defp get_font_preview_style(font) do
    case font do
      "inter" -> "font-family: 'Inter', sans-serif;"
      "serif" -> "font-family: 'Times New Roman', serif;"
      "mono" -> "font-family: 'Monaco', monospace;"
      "system" -> "font-family: -apple-system, BlinkMacSystemFont, sans-serif;"
      _ -> ""
    end
  end

  defp extract_portfolio_settings_params(params) do
    %{
      title: params["title"],
      description: params["description"],
      slug: params["slug"],
      visibility: String.to_atom(params["visibility"] || "private")
    }
  end

  defp extract_seo_settings_params(params) do
    %{
      seo_settings: %{
        "meta_description" => params["meta_description"],
        "keywords" => params["keywords"],
        "social_sharing_enabled" => params["social_sharing_enabled"] == "true"
      }
    }
  end

  defp get_default_item_for_section_type(section_type) do
    case section_type do
      "experience" -> %{
        "title" => "",
        "company" => "",
        "duration" => "",
        "description" => "",
        "location" => ""
      }

      "skills" -> %{
        "name" => "",
        "skills" => []
      }

      "projects" -> %{
        "title" => "",
        "description" => "",
        "technologies" => "",
        "url" => "",
        "image_url" => ""
      }

      "testimonials" -> %{
        "name" => "",
        "title" => "",
        "company" => "",
        "content" => "",
        "avatar_url" => "",
        "rating" => 5
      }

      "education" -> %{
        "degree" => "",
        "institution" => "",
        "duration" => "",
        "description" => "",
        "gpa" => ""
      }

      "certifications" -> %{
        "name" => "",
        "issuer" => "",
        "date" => "",
        "expiry" => "",
        "credential_id" => "",
        "url" => ""
      }

      "achievements" -> %{
        "title" => "",
        "organization" => "",
        "date" => "",
        "description" => ""
      }

      "services" -> %{
        "title" => "",
        "description" => "",
        "price" => "",
        "price_type" => "hour",
        "features" => "",
        "booking_enabled" => false
      }

      "blog" -> %{
        "title" => "",
        "excerpt" => "",
        "category" => "",
        "published_date" => "",
        "read_time" => "",
        "author" => "",
        "url" => "",
        "featured_image" => ""
      }

      "gallery" -> %{
        "url" => "",
        "caption" => "",
        "alt_text" => ""
      }

      _ -> %{
        "title" => "",
        "description" => ""
      }
    end
  end

  defp get_default_section_content(section_type) do
    case section_type do
      "hero" -> %{
        "headline" => "",
        "tagline" => "",
        "description" => "",
        "cta_text" => "",
        "cta_link" => "",
        "background_type" => "gradient",
        "show_social" => false,
        "video_enabled" => false
      }
      "experience" -> %{
        "jobs" => [get_default_item_for_section_type(section_type)]
      }

      "education" -> %{
        "education" => [get_default_item_for_section_type(section_type)]
      }

      "skills" -> %{
        "skills" => []
      }

      "projects" -> %{
        "projects" => [get_default_item_for_section_type(section_type)]
      }

      "testimonials" -> %{
        "testimonials" => [get_default_item_for_section_type(section_type)]
      }

      "certifications" -> %{
        "certifications" => [get_default_item_for_section_type(section_type)]
      }

      "achievements" -> %{
        "achievements" => [get_default_item_for_section_type(section_type)]
      }

      "services" -> %{
        "services" => [get_default_item_for_section_type(section_type)]
      }

      "blog" -> %{
        "articles" => [get_default_item_for_section_type(section_type)]
      }

      "gallery" -> %{
        "images" => [get_default_item_for_section_type(section_type)]
      }

      "hero" -> %{
        "headline" => "Welcome to My Portfolio",
        "summary" => "A brief introduction about yourself and your professional journey.",
        "location" => "",
        "website" => "",
        "social_links" => %{}
      }

      "intro" -> %{
        "headline" => "Welcome to My Portfolio",
        "summary" => "A brief introduction about yourself and your professional journey.",
        "location" => "",
        "website" => "",
        "social_links" => %{}
      }
      "about" -> %{
        "content" => "",
        "highlights" => []
      }
      "narrative" -> %{
        "content" => "Tell your story here...",
        "highlights" => []
      }
      "contact" -> %{
        "email" => "",
        "phone" => "",
        "location" => "",
        "social_links" => %{},
        "contact_form_enabled" => true
      }
      "custom" -> %{
        "title" => "",
        "content" => "",
        "layout_type" => "text",
        "images" => [],
        "video_url" => "",
        "embed_code" => "",
        "custom_css" => "",
        "background_color" => "#ffffff",
        "text_color" => "#000000",
        "show_border" => false,
        "padding" => "normal"
      }

      _ -> %{
        "content" => "Add your content here..."
      }
    end
  end

  defp get_section_content_safe(section) do
    case section.content do
      content when is_binary(content) -> content
      content when is_map(content) -> Map.get(content, "content", "")
      _ -> ""
    end
  end

  defp find_video_intro_section(sections) when is_list(sections) do
    Enum.find(sections, fn section ->
      section.section_type == :media_showcase or
      (is_binary(section.section_type) and section.section_type == "media_showcase") or
      (section.section_type == "video" or section.section_type == :video) or
      (get_in(section.content, ["video_type"]) == "introduction")
    end)
  end
  defp find_video_intro_section(_), do: nil

  defp get_user_tier(user) when is_map(user) do
    Map.get(user, :subscription_tier, "free")
  end
  defp get_user_tier(_), do: "free"

  defp format_video_duration(duration_seconds) when is_integer(duration_seconds) do
    minutes = div(duration_seconds, 60)
    seconds = rem(duration_seconds, 60)
    "#{minutes}:#{String.pad_leading(to_string(seconds), 2, "0")}"
  end
  defp format_video_duration(_), do: "Unknown"

  defp format_position_name(position) do
    case position do
      "hero" -> "Hero Section"
      "about" -> "About Section"
      "sidebar" -> "Sidebar"
      "footer" -> "Footer"
      _ -> "Hero Section"
    end
  end

  defp assign_defaults(assigns) do
    defaults = %{
      show_video_recorder: false,
      current_user: %{subscription_tier: "free"},
      hero_section: nil
    }

    Enum.reduce(defaults, assigns, fn {key, default_value}, acc ->
      if Map.has_key?(acc, key) do
        acc
      else
        Map.put(acc, key, default_value)
      end
    end)
  end

  defp get_section_stats(section) do
    content = section.content || %{}

    case to_string(section.section_type) do
      "experience" ->
        items = Map.get(content, "items", [])
        current_jobs = Enum.count(items, &Map.get(&1, "current", false))
        if current_jobs > 0, do: ["#{current_jobs} current position#{if current_jobs == 1, do: "", else: "s"}"], else: []

      "skills" ->
        categories = Map.get(content, "categories", [])
        if length(categories) > 0 do
          top_category = categories |> Enum.max_by(&length(Map.get(&1, "skills", [])), fn -> %{} end)
          top_skills_count = Map.get(top_category, "skills", []) |> length()
          ["Top category: #{top_skills_count} skills"]
        else
          []
        end

      "projects" ->
        items = Map.get(content, "items", [])
        with_links = Enum.count(items, fn item ->
          Map.get(item, "demo_url", "") != "" || Map.get(item, "source_url", "") != ""
        end)
        if with_links > 0, do: ["#{with_links} with links"], else: []

      "testimonials" ->
        items = Map.get(content, "items", [])
        avg_rating = if length(items) > 0 do
          ratings = items |> Enum.map(&Map.get(&1, "rating", 5)) |> Enum.filter(&is_number/1)
          if length(ratings) > 0 do
            avg = Enum.sum(ratings) / length(ratings)
            ["Avg rating: #{Float.round(avg, 1)}/5"]
          else
            []
          end
        else
          []
        end
        avg_rating

      _ -> []
    end
  end

  defp get_professional_types do
    %{
      "general" => %{
        name: "General Professional",
        description: "Versatile professional layout suitable for most careers",
        icon: "👔"
      },
      "creative" => %{
        name: "Creative Professional",
        description: "Visual-focused layout for designers, artists, and creatives",
        icon: "🎨"
      },
      "developer" => %{  # Change from "technical" to "developer"
        name: "Developer/Technical",
        description: "Code and project-focused layout for developers and engineers",
        icon: "💻"
      },
      "service_provider" => %{  # Add this
        name: "Service Provider",
        description: "Business services, consulting, and client-focused layout",
        icon: "🏢"
      },
      "musician" => %{  # Add this
        name: "Musician/Artist",
        description: "Music and performance-focused portfolio layout",
        icon: "🎵"
      }
    }
  end

  defp get_available_themes do
    %{
      "professional" => %{
        name: "Professional",
        description: "Clean and business-focused",
        color_class: "bg-blue-500"
      },
      "creative" => %{
        name: "Creative",
        description: "Bold and artistic",
        color_class: "bg-purple-500"
      },
      "developer" => %{
        name: "Developer",
        description: "Technical and code-focused",
        color_class: "bg-green-500"
      },
      "minimalist" => %{
        name: "Minimalist",
        description: "Simple and elegant",
        color_class: "bg-gray-500"
      }
    }
  end

  defp get_portfolio_layouts do
    %{
      "single_column" => %{
        name: "Single Column",
        description: "Traditional single-column layout",
        icon: "<svg class='w-6 h-6 text-gray-600' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M4 6h16M4 10h16M4 14h16M4 18h16'/></svg>"
      },
      "dashboard" => %{
        name: "Dashboard",
        description: "Card-based layout with varying sizes",
        icon: "<svg class='w-6 h-6 text-gray-600' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M4 5a1 1 0 011-1h4a1 1 0 011 1v7a1 1 0 01-1 1H5a1 1 0 01-1-1V5zM14 5a1 1 0 011-1h4a1 1 0 011 1v2a1 1 0 01-1 1h-4a1 1 0 01-1-1V5zM14 12a1 1 0 011-1h4a1 1 0 011 1v7a1 1 0 01-1 1h-4a1 1 0 01-1-1v-7z'/></svg>"
      },
      "grid" => %{
        name: "Grid",
        description: "Uniform grid layout",
        icon: "<svg class='w-6 h-6 text-gray-600' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M4 5a1 1 0 011-1h4a1 1 0 011 1v4a1 1 0 01-1 1H5a1 1 0 01-1-1V5zM14 5a1 1 0 011-1h4a1 1 0 011 1v4a1 1 0 01-1 1h-4a1 1 0 01-1-1V5zM4 15a1 1 0 011-1h4a1 1 0 011 1v4a1 1 0 01-1 1H5a1 1 0 01-1-1v-4zM14 15a1 1 0 011-1h4a1 1 0 011 1v4a1 1 0 01-1 1h-4a1 1 0 01-1-1v-4z'/></svg>"
      },
      "creative" => %{
        name: "Creative",
        description: "Dynamic and artistic layout",
        icon: "<svg class='w-6 h-6 text-gray-600' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M7 21a4 4 0 01-4-4V5a2 2 0 012-2h4a2 2 0 012 2v12a4 4 0 01-4 4zM21 5a2 2 0 00-2-2h-4a2 2 0 00-2 2v12a4 4 0 004 4h4a2 2 0 002-2V5z'/></svg>"
      }
    }
  end

  defp get_color_presets do
    [
      %{name: "Ocean", primary: "#1e40af", secondary: "#64748b", accent: "#0ea5e9"},
      %{name: "Forest", primary: "#059669", secondary: "#6b7280", accent: "#10b981"},
      %{name: "Sunset", primary: "#ea580c", secondary: "#6b7280", accent: "#f97316"},
      %{name: "Purple", primary: "#7c3aed", secondary: "#6b7280", accent: "#8b5cf6"},
      %{name: "Rose", primary: "#be185d", secondary: "#6b7280", accent: "#ec4899"},
      %{name: "Slate", primary: "#374151", secondary: "#6b7280", accent: "#6366f1"}
    ]
  end

  # Helper functions to get current values:
  defp get_current_professional_type(customization) do
    Map.get(customization, "professional_type", "professional")
  end

  defp get_current_theme(customization) do
    Map.get(customization, "theme", "professional")
  end

  defp get_current_layout(customization) do
    Map.get(customization, "portfolio_layout", "single_column")
  end

  defp get_current_font(customization) do
    Map.get(customization, "font_family", "Inter, sans-serif")
  end

  defp get_current_font_size(customization) do
    Map.get(customization, "font_size", "medium")
  end

  def get_layout_component(professional_type, layout_style \\ "default") do
    component = case {professional_type, layout_style} do
      {:developer, "github"} -> FrestylWeb.PortfolioLive.Layouts.DeveloperGithubLayoutComponent
      {:developer, _} -> FrestylWeb.PortfolioLive.Layouts.DeveloperLayoutComponent
      {:creative, "imdb"} -> FrestylWeb.PortfolioLive.Layouts.CreativeImdbLayoutComponent
      {:creative, _} -> FrestylWeb.PortfolioLive.Layouts.CreativeLayoutComponent
      {:service_provider, _} -> FrestylWeb.PortfolioLive.Layouts.ServiceProviderLayoutComponent
      {:musician, "playlist"} -> FrestylWeb.PortfolioLive.Layouts.MusicianPlaylistLayoutComponent
      {:musician, _} -> FrestylWeb.PortfolioLive.Layouts.MusicianLayoutComponent
      _ -> FrestylWeb.PortfolioLive.Layouts.ProfessionalLayoutComponent
    end

    # Check if component exists, fallback to ProfessionalLayoutComponent
    if Code.ensure_loaded?(component) do
      component
    else
      IO.puts("⚠️ Layout component #{inspect(component)} not found, using ProfessionalLayoutComponent")
      FrestylWeb.PortfolioLive.Layouts.ProfessionalLayoutComponent
    end
  end

  # ============================================================================
  # RENDER FUNCTIONS
  # ============================================================================

  def render(assigns) do
    section_types = [
      "intro", "experience", "education", "skills", "projects",
      "testimonial", "contact", "custom", "achievements",
      "narrative", "journey", "timeline", "media_showcase"
    ]

    assigns = Map.merge(%{
      show_video_recorder: false,
      current_user: %{subscription_tier: "free"},
      hero_section: nil,
      show_section_modal: false,
      editing_section: nil,
      active_tab: "sections",
      preview_mode: :split,
      sections: [],
      customization: %{},
      portfolio: %{},
      section_types: @section_types  # FIXED: Add this
    }, assigns)

    ~H"""
    <div class="min-h-screen bg-gray-50">
      <.nav {assigns} />
      <!-- Use Map.get with fallback for preview_css -->
      <style id="preview-styles">
        <%= Phoenix.HTML.raw(Map.get(assigns, :preview_css, "/* No CSS */")) %>
      </style>
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <!-- Editor Header -->
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-gray-900">Portfolio Editor</h1>
          <p class="text-gray-600 mt-2">Customize your portfolio and preview changes in real-time</p>
        </div>

        <!-- Tab Navigation -->
        <div class="border-b border-gray-200 mb-8">
          <nav class="-mb-px flex space-x-8">
            <%= for {tab_id, tab_name} <- [{"sections", "Sections"}, {"design", "Design"}, {"settings", "Settings"}] do %>
              <button
                phx-click="switch_tab"
                phx-value-tab={tab_id}
                class={[
                  "py-4 px-1 border-b-2 font-medium text-sm transition-colors",
                  if(Map.get(assigns, :active_tab, "sections") == tab_id,
                    do: "border-gray-900 text-gray-900",
                    else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300")
                ]}>
                <%= tab_name %>
              </button>
            <% end %>
          </nav>
        </div>

        <!-- FIXED: Main content with proper grid layout -->
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
          <!-- Editor Panel -->
          <div class="space-y-6">
            <%= case Map.get(assigns, :active_tab, "sections") do %>
              <% "sections" -> %>
                <.render_sections_tab {assigns} />
              <% "design" -> %>
                <.render_design_tab {assigns} />
              <% "settings" -> %>
                <.render_settings_tab {assigns} />
              <% _ -> %>
                <.render_sections_tab {assigns} />
            <% end %>
          </div>

          <!-- Preview Panel -->
          <div class="lg:sticky lg:top-8 lg:h-screen">
            <div class="bg-white rounded-xl shadow-sm border overflow-hidden h-full">
              <div class="p-4 border-b border-gray-200 flex items-center justify-between">
                <h3 class="font-semibold text-gray-900">Live Preview</h3>
                <div class="flex items-center space-x-2">
                  <button
                    phx-click="toggle_preview"
                    class="text-sm text-gray-500 hover:text-gray-700">
                    <%= if Map.get(assigns, :preview_mode, :split) == :split, do: "Hide Preview", else: "Show Preview" %>
                  </button>
                  <a
                    href={"/portfolios/#{@portfolio.id}/preview"}
                    target="_blank"
                    class="text-sm text-blue-600 hover:text-blue-700">
                    Open in New Tab
                  </a>
                </div>
              </div>

              <%= if Map.get(assigns, :preview_mode, :split) == :split do %>
                <div class="h-full">
                  <iframe
                    id="portfolio-preview-frame"
                    src={"/portfolios/#{@portfolio.id}/preview"}
                    class="w-full h-full border-0"
                    phx-hook="PreviewFrame"
                    data-portfolio-id={@portfolio.id}>
                  </iframe>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>

      <!-- Section Edit Modal -->
      <%= if Map.get(assigns, :show_section_modal, false) do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div class="bg-white rounded-xl shadow-2xl max-w-4xl w-full max-h-[90vh] overflow-hidden">
            <div class="flex items-center justify-between p-6 border-b border-gray-200">
              <h3 class="text-lg font-bold text-gray-900">
                Edit <%= Map.get(assigns, :editing_section, %{}) |> Map.get(:title, "Section") %>
              </h3>
              <button
                phx-click="close_section_modal"
                class="text-gray-400 hover:text-gray-600">
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                </svg>
              </button>
            </div>

            <div class="p-6 overflow-y-auto max-h-[calc(90vh-140px)]">
              <%= if Map.get(assigns, :editing_section) do %>
                <form phx-submit="save_section" class="space-y-6">
                  <input type="hidden" name="section_id" value={assigns.editing_section.id} />

                  <!-- Section Title -->
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-2">Section Title</label>
                    <input
                      type="text"
                      name="title"
                      value={assigns.editing_section.title}
                      class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
                  </div>

                  <!-- Section Visibility -->
                  <div class="flex items-center">
                    <input
                      type="checkbox"
                      id="section_visible"
                      name="visible"
                      value="true"
                      checked={assigns.editing_section.visible}
                      class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded">
                    <label for="section_visible" class="ml-2 block text-sm text-gray-900">
                      Show this section on portfolio
                    </label>
                  </div>

                  <!-- Basic content field for now -->
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-2">Content</label>
                    <textarea
                      name="content"
                      rows="8"
                      class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                      placeholder="Add your content here..."><%= get_section_content_safe(assigns.editing_section) %></textarea>
                  </div>

                  <!-- Modal Actions -->
                  <div class="flex items-center justify-end space-x-3 pt-6 border-t border-gray-200">
                    <button
                      type="button"
                      phx-click="close_section_modal"
                      class="px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50 transition-colors">
                      Cancel
                    </button>
                    <button
                      type="submit"
                      class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors">
                      Save Section
                    </button>
                  </div>
                </form>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Video Intro Modal -->
      <%= if Map.get(assigns, :show_video_recorder, false) do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <.live_component
            module={EnhancedVideoIntroComponent}
            id={"video-intro-recorder-modal-#{@portfolio.id}"}
            portfolio={Map.get(assigns, :portfolio, %{})}
            current_user={Map.get(assigns, :current_user, %{})}
          />
        </div>
      <% end %>
    </div>
    """
  end

  defp nav(assigns) do
    ~H"""
    <nav class="bg-white border-b border-gray-200 sticky top-0 z-40">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex justify-between items-center h-16">
          <!-- Left side - navigation links (unchanged) -->
          <div class="flex items-center space-x-4">
            <.link navigate={~p"/hub"} class="inline-flex items-center text-gray-600 hover:text-gray-900 transition-colors group">
              <svg class="w-5 h-5 mr-2 group-hover:transform group-hover:-translate-x-1 transition-transform" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18"/>
              </svg>
              <span class="font-medium">My Portfolios</span>
            </.link>

            <div class="h-6 w-px bg-gray-300"></div>

            <.link navigate={~p"/"} class="text-xl font-bold text-gray-900">Frestyl</.link>

            <div class="hidden md:flex items-center space-x-2">
              <span class="text-gray-400">/</span>
              <span class="text-gray-700 font-medium"><%= Map.get(@portfolio, :title, "Portfolio") %></span>
            </div>
          </div>

          <!-- Right side - auto-save status and actions -->
          <div class="flex items-center space-x-4">
            <!-- Auto-save Status Indicator -->
            <div class="hidden sm:flex items-center space-x-2">
              <%= if Map.get(assigns, :debounce_timer) do %>
                <!-- Saving state -->
                <div class="flex items-center text-xs text-yellow-600">
                  <svg class="w-4 h-4 mr-1 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
                  </svg>
                  Saving...
                </div>
              <% else %>
                <!-- Saved state -->
                <div class="flex items-center text-xs text-green-600">
                  <svg class="w-4 h-4 mr-1" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
                  </svg>
                  Auto-saved <%= time_ago(Map.get(assigns, :last_updated, DateTime.utc_now())) %>
                </div>
              <% end %>
            </div>

            <!-- Preview Button -->
            <.link
              href={"/portfolios/#{Map.get(@portfolio, :id)}/preview"}
              target="_blank"
              class="inline-flex items-center px-3 py-2 border border-gray-300 rounded-lg text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 transition-colors">
              <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/>
              </svg>
              Preview
            </.link>

            <!-- User menu (unchanged) -->
            <%= if Map.get(assigns, :current_user) do %>
              <div class="flex items-center space-x-3">
                <span class="hidden md:block text-gray-700">
                  Hello, <%= Map.get(@current_user, :username, Map.get(@current_user, :name, "User")) %>
                </span>
                <.link navigate={~p"/logout"} class="text-red-600 hover:text-red-700 text-sm">Logout</.link>
              </div>
            <% else %>
              <.link navigate={~p"/login"} class="text-blue-600 hover:text-blue-700">Login</.link>
            <% end %>
          </div>
        </div>
      </div>
    </nav>
    """
  end

  def render_sections_tab(assigns) do
    sections = Map.get(assigns, :sections, [])
    assigns = assign(assigns, :sections, sections)

    # Find existing video intro section
    video_section = find_video_intro_section(Map.get(assigns, :sections, []))
    assigns = assign(assigns, :video_section, video_section)

    ~H"""
    <div class="space-y-6" id="sections-manager" phx-hook="DesignUpdater">

      <!-- Collapsible Add Section Container -->
      <div class="bg-white rounded-xl shadow-sm border">
        <!-- Collapsible Header -->
        <div class="p-4 border-b border-gray-100">
          <button
            phx-click="toggle_add_section_panel"
            class="w-full flex items-center justify-between text-left group">
            <div>
              <h3 class="text-lg font-bold text-gray-900 group-hover:text-gray-700 transition-colors">
                Portfolio Sections
              </h3>
              <p class="text-gray-600 mt-1">Add and manage sections to showcase your work</p>
            </div>

            <!-- Collapse/Expand Indicator -->
            <div class="flex items-center space-x-3">
              <!-- Section Count Badge -->
              <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-gray-100 text-gray-800">
                <%= length(@sections) %> section<%= if length(@sections) != 1, do: "s", else: "" %>
              </span>

              <!-- Chevron Icon -->
              <svg class={[
                "w-5 h-5 text-gray-400 transition-transform duration-200",
                if(Map.get(assigns, :show_add_section_panel, true), do: "rotate-180", else: "rotate-0")
              ]} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>
              </svg>
            </div>
          </button>
        </div>

        <!-- Collapsible Content -->
        <%= if Map.get(assigns, :show_add_section_panel, true) do %>
          <div class="p-6" id="add-section-panel">
            <!-- Action Buttons Row -->
            <div class="flex flex-wrap items-center gap-3 mb-6">
              <!-- Import Resume Button -->
              <button
                phx-click="show_resume_import"
                class="inline-flex items-center bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded-lg font-medium transition-colors">
                <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/>
                </svg>
                Import Resume
              </button>

              <!-- Add Section Dropdown -->
              <div class="relative">
                <button
                  phx-click="toggle_create_dropdown"
                  class="inline-flex items-center bg-gray-900 hover:bg-gray-800 text-white px-4 py-2 rounded-lg font-medium transition-colors">
                  <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
                  </svg>
                  Add Section
                  <svg class="w-4 h-4 ml-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>
                  </svg>
                </button>

                <%= if Map.get(assigns, :show_create_dropdown, false) do %>
                  <div class="absolute left-0 mt-2 w-80 bg-white rounded-xl shadow-xl border border-gray-200 py-4 z-50">
                    <div class="px-4 pb-3 border-b border-gray-100">
                      <h4 class="font-semibold text-gray-900">Choose Section Type</h4>
                      <p class="text-sm text-gray-600">Select the type of content you want to add</p>
                    </div>

                    <div class="py-2 max-h-80 overflow-y-auto">
                      <%= for section_type <- @section_types do %>
                        <button
                          phx-click="create_section"
                          phx-value-section_type={section_type}
                          class="w-full flex items-center space-x-3 px-4 py-3 hover:bg-gray-50 transition-colors text-left">
                          <div class="w-8 h-8 bg-gradient-to-br from-gray-100 to-gray-200 rounded-lg flex items-center justify-center">
                            <%= raw(get_section_icon(section_type)) %>
                          </div>
                          <div>
                            <div class="font-medium text-gray-900"><%= format_section_type(section_type) %></div>
                            <div class="text-sm text-gray-600"><%= get_section_description(section_type) %></div>
                          </div>
                        </button>
                      <% end %>
                    </div>
                  </div>
                <% end %>
              </div>

              <!-- Quick Add Common Sections -->
              <div class="flex items-center space-x-2">
                <span class="text-sm text-gray-500">Quick add:</span>
                <%= for {type, label} <- [{"hero", "Hero"}, {"about", "About"}, {"experience", "Experience"}, {"projects", "Projects"}] do %>
                  <button
                    phx-click="create_section"
                    phx-value-section_type={type}
                    class="inline-flex items-center px-3 py-1 text-sm bg-gray-100 hover:bg-gray-200 text-gray-700 rounded-md transition-colors">
                    <%= label %>
                  </button>
                <% end %>
              </div>
            </div>

            <!-- Video Introduction Management -->
            <div class="p-4 bg-gradient-to-r from-purple-50 to-blue-50 border border-purple-200 rounded-lg">
              <div class="flex items-center justify-between">
                <div class="flex items-center space-x-3">
                  <div class="w-10 h-10 bg-gradient-to-br from-purple-500 to-blue-600 rounded-lg flex items-center justify-center">
                    <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
                    </svg>
                  </div>
                  <div>
                    <h4 class="font-medium text-gray-900">Video Introduction</h4>
                    <%= if @video_section do %>
                      <p class="text-sm text-gray-600">
                        Duration: <%= format_video_duration(get_in(@video_section.content, ["duration"])) %> •
                        <%= case Map.get(assigns, :current_user, %{}) |> Map.get(:subscription_tier, "free") do %>
                          <% "free" -> %><span class="text-gray-500">1min max</span>
                          <% "pro" -> %><span class="text-blue-600">2min max</span>
                          <% "premium" -> %><span class="text-purple-600">3min max</span>
                          <% _ -> %><span class="text-gray-500">1min max</span>
                        <% end %>
                      </p>
                    <% else %>
                      <p class="text-sm text-gray-600">
                        Add a personal video to welcome visitors •
                        <%= case Map.get(assigns, :current_user, %{}) |> Map.get(:subscription_tier, "free") do %>
                          <% "free" -> %><span class="text-gray-500">1min max</span>
                          <% "pro" -> %><span class="text-blue-600">2min max</span>
                          <% "premium" -> %><span class="text-purple-600">3min max</span>
                          <% _ -> %><span class="text-gray-500">1min max</span>
                        <% end %>
                      </p>
                    <% end %>
                  </div>
                </div>

                <div class="flex items-center space-x-2">
                  <%= if @video_section do %>
                    <!-- Manage Existing Video -->
                    <button
                      phx-click="edit_video_intro"
                      class="bg-white hover:bg-gray-50 text-purple-700 px-3 py-2 rounded-lg text-sm font-medium border border-purple-200 transition-colors inline-flex items-center">
                      <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5"/>
                      </svg>
                      Update
                    </button>

                    <button
                      phx-click="delete_video_intro"
                      phx-value-section_id={@video_section.id}
                      phx-data-confirm="Are you sure you want to delete your video introduction?"
                      class="text-red-600 hover:text-red-700 p-2 rounded-lg hover:bg-red-50 transition-colors"
                      title="Delete video">
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
                      </svg>
                    </button>
                  <% else %>
                    <!-- Add New Video -->
                    <button
                      phx-click="show_video_recorder"
                      class="bg-purple-600 hover:bg-purple-700 text-white px-3 py-2 rounded-lg text-sm font-medium transition-colors inline-flex items-center">
                      <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
                      </svg>
                      Add Video
                    </button>
                  <% end %>
                </div>
              </div>

              <!-- Video Preview (if exists) -->
              <%= if @video_section && get_in(@video_section.content, ["video_url"]) do %>
                <div class="mt-3 flex justify-center">
                  <video class="w-32 h-20 object-cover rounded border" controls>
                    <source src={get_in(@video_section.content, ["video_url"])} type="video/webm">
                    <source src={get_in(@video_section.content, ["video_url"])} type="video/mp4">
                    Your browser does not support the video tag.
                  </video>
                </div>
              <% end %>
            </div>
          </div>
        <% else %>
          <!-- Collapsed State - Show Summary -->
          <div class="px-6 py-4 bg-gray-50 border-t border-gray-100">
            <div class="flex items-center justify-between text-sm text-gray-600">
              <div class="flex items-center space-x-4">
                <span>
                  <%= length(@sections) %> section<%= if length(@sections) != 1, do: "s", else: "" %> configured
                </span>
                <%= if @video_section do %>
                  <span class="inline-flex items-center px-2 py-1 bg-purple-100 text-purple-700 rounded-full text-xs">
                    <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14"/>
                    </svg>
                    Video intro added
                  </span>
                <% end %>
              </div>
              <button
                phx-click="toggle_add_section_panel"
                class="text-blue-600 hover:text-blue-700 font-medium">
                Expand to add sections
              </button>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Sections List -->
      <%= if length(Map.get(assigns, :sections, [])) > 0 do %>
        <div class="bg-white rounded-xl shadow-sm border p-6">
          <div class="flex items-center justify-between mb-4">
            <h4 class="font-medium text-gray-900">Section Order</h4>
            <div class="text-sm text-gray-500">Drag sections to reorder them</div>
          </div>

          <!-- Sortable Sections Container -->
          <div
            class="space-y-3"
            id="sections-sortable"
            phx-hook="SortableSections"
            data-portfolio-id={Map.get(assigns, :portfolio, %{}) |> Map.get(:id)}>
            <%= for section <- Enum.sort_by(Map.get(assigns, :sections, []), & &1.position) do %>
              <div
                class="section-sortable-item cursor-move"
                data-section-id={section.id}
                data-position={section.position}>
                <.render_section_card section={section} />
              </div>
            <% end %>
          </div>

          <!-- Sorting Instructions -->
          <div class="mt-4 p-4 bg-blue-50 rounded-lg">
            <div class="flex items-start space-x-3">
              <svg class="w-5 h-5 text-blue-600 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
              </svg>
              <div>
                <h5 class="text-sm font-medium text-blue-900">Section Ordering</h5>
                <p class="text-sm text-blue-700 mt-1">
                  The order of sections here determines how they appear on your portfolio.
                  Drag sections up or down to reorder them.
                </p>
              </div>
            </div>
          </div>
        </div>
      <% else %>
        <!-- Empty State -->
        <div class="bg-white rounded-xl shadow-sm border p-12 text-center">
          <div class="w-16 h-16 bg-gradient-to-br from-gray-100 to-gray-200 rounded-full flex items-center justify-center mx-auto mb-4">
            <svg class="w-8 h-8 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>
            </svg>
          </div>
          <h3 class="text-lg font-semibold text-gray-900 mb-2">No sections yet</h3>
          <p class="text-gray-600 mb-6 max-w-md mx-auto">Start building your portfolio by adding your first section. Choose from our templates or create a custom section.</p>
          <button
            phx-click="create_section"
            phx-value-section_type="hero"
            class="bg-gray-900 hover:bg-gray-800 text-white px-6 py-3 rounded-lg font-medium transition-all transform hover:scale-105">
            Create Hero Section
          </button>
        </div>
      <% end %>

      <!-- Modals remain the same as before -->
      <!-- Video Intro Modal -->
      <%= if Map.get(assigns, :show_video_recorder, false) do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <.live_component
            module={EnhancedVideoIntroComponent}
            id="video-intro-recorder"
            portfolio={Map.get(assigns, :portfolio, %{})}
            current_user={Map.get(assigns, :current_user, %{})}
          />
        </div>
      <% end %>

      <!-- Resume Import Modal -->
      <%= if Map.get(assigns, :show_resume_import, false) do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div class="bg-white rounded-xl shadow-2xl max-w-2xl w-full max-h-[90vh] overflow-hidden">
            <!-- Header -->
            <div class="flex items-center justify-between p-6 border-b border-gray-200">
              <h3 class="text-lg font-bold text-gray-900 flex items-center">
                <svg class="w-6 h-6 mr-3 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/>
                </svg>
                Import Resume
              </h3>
              <button phx-click="close_resume_import" class="text-gray-400 hover:text-gray-600">
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                </svg>
              </button>
            </div>

            <!-- Content -->
            <div class="p-6">
              <div class="text-center mb-6">
                <p class="text-gray-600 mb-4">
                  Upload your resume to automatically populate portfolio sections with your experience, education, and skills.
                </p>
                <div class="text-sm text-gray-500">
                  Supported formats: PDF, DOC, DOCX, TXT (max 5MB)
                </div>
              </div>

              <!-- Form -->
              <form phx-submit="upload_resume" phx-change="validate_resume" class="space-y-4">
                <div class="relative">
                  <!-- Hidden file input -->
                  <.live_file_input upload={@uploads.resume} class="absolute inset-0 w-full h-full opacity-0 cursor-pointer z-10" />

                  <!-- Visible dropzone -->
                  <div
                    class="border-2 border-dashed border-gray-300 rounded-lg p-8 text-center hover:border-green-400 transition-colors cursor-pointer bg-gray-50 hover:bg-green-50"
                    phx-drop-target={@uploads.resume.ref}>

                    <svg class="w-12 h-12 text-gray-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/>
                    </svg>

                    <p class="text-lg font-medium text-gray-900 mb-2">Drop your resume here</p>
                    <p class="text-gray-600">or click anywhere to browse</p>
                  </div>
                </div>

                <!-- Show selected files -->
                <%= for entry <- @uploads.resume.entries do %>
                  <div class="flex items-center justify-between p-3 bg-green-50 border border-green-200 rounded-lg">
                    <div class="flex items-center">
                      <svg class="w-8 h-8 text-green-600 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                      </svg>
                      <div>
                        <p class="font-medium text-gray-900"><%= entry.client_name %></p>
                        <p class="text-sm text-gray-600"><%= Float.round(entry.client_size / 1024 / 1024, 2) %> MB</p>
                      </div>
                    </div>
                    <button
                      type="button"
                      phx-click="cancel_upload"
                      phx-value-ref={entry.ref}
                      class="text-red-600 hover:text-red-800">
                      <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                      </svg>
                    </button>
                  </div>
                <% end %>

                <!-- Upload errors -->
                <%= for err <- upload_errors(@uploads.resume) do %>
                  <div class="p-3 bg-red-50 border border-red-200 rounded-lg">
                    <p class="text-sm text-red-800"><%= error_to_string(err) %></p>
                  </div>
                <% end %>

                <!-- Actions -->
                <div class="flex justify-end space-x-3 pt-4 border-t border-gray-200">
                  <button
                    type="button"
                    phx-click="close_resume_import"
                    class="px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50">
                    Cancel
                  </button>
                  <button
                    type="submit"
                    disabled={Enum.empty?(@uploads.resume.entries)}
                    class="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:bg-gray-300 disabled:cursor-not-allowed">
                    Import Resume
                  </button>
                </div>
              </form>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  def render_design_tab(assigns) do
    customization = Map.get(assigns, :customization, %{})
    hero_section = Map.get(assigns, :hero_section)

    ~H"""
    <div class="space-y-6" id="design-updater" phx-hook="DesignUpdater">

      <!-- Professional Type Selector -->
      <div class="bg-white rounded-xl shadow-sm border p-6">
        <h3 class="text-lg font-bold text-gray-900 mb-4">Professional Type</h3>
        <p class="text-gray-600 mb-4">Choose how your portfolio should be optimized</p>

        <!-- ✅ WRAP IN FORM -->
        <form phx-change="update_professional_type">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <%= for {type_id, type_info} <- get_professional_types() do %>
              <label class="relative">
                <input
                  type="radio"
                  name="professional_type"
                  value={type_id}
                  checked={get_current_professional_type(customization) == type_id}
                  class="sr-only peer">
                <div class="p-4 border-2 border-gray-200 rounded-lg cursor-pointer peer-checked:border-blue-500 peer-checked:bg-blue-50 hover:border-gray-300 transition-colors">
                  <div class="flex items-start space-x-3">
                    <div class="text-2xl"><%= type_info.icon %></div>
                    <div>
                      <h4 class="font-medium text-gray-900"><%= type_info.name %></h4>
                      <p class="text-sm text-gray-600"><%= type_info.description %></p>
                    </div>
                  </div>
                </div>
              </label>
            <% end %>
          </div>
        </form>
      </div>

      <!-- Layout Options -->
      <div class="bg-white rounded-xl shadow-sm border p-6">
        <h3 class="text-lg font-bold text-gray-900 mb-4">Layout Style</h3>
        <p class="text-gray-600 mb-4">Choose how sections are arranged</p>

        <!-- ✅ WRAP IN FORM -->
        <form phx-change="update_portfolio_layout">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <%= for {layout_id, layout_info} <- get_portfolio_layouts() do %>
              <label class="relative">
                <input
                  type="radio"
                  name="portfolio_layout"
                  value={layout_id}
                  checked={get_current_layout(customization) == layout_id}
                  class="sr-only peer">
                <div class="p-4 border-2 border-gray-200 rounded-lg cursor-pointer peer-checked:border-blue-500 peer-checked:bg-blue-50 hover:border-gray-300 transition-colors">
                  <div class="flex items-start space-x-3">
                    <div class="flex-shrink-0 w-12 h-12 bg-gray-100 rounded-lg flex items-center justify-center">
                      <%= raw(layout_info.icon) %>
                    </div>
                    <div class="flex-1">
                      <h4 class="font-medium text-gray-900"><%= layout_info.name %></h4>
                      <p class="text-sm text-gray-600 mt-1"><%= layout_info.description %></p>
                    </div>
                  </div>
                </div>
              </label>
            <% end %>
          </div>
        </form>
      </div>

      <!-- Color Customization -->
      <div class="bg-white rounded-xl shadow-sm border p-6">
        <h3 class="text-lg font-bold text-gray-900 mb-4">Colors</h3>
        <p class="text-gray-600 mb-4">Customize your portfolio's color scheme</p>

        <!-- ✅ WRAP IN FORM -->
        <form phx-change="update_customization">
          <div class="space-y-4">
            <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Primary Color</label>
                <div class="flex items-center space-x-3">
                  <input
                    type="color"
                    name="primary_color"
                    value={Map.get(customization, "primary_color", "#1e40af")}
                    class="w-12 h-12 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500" />
                  <input
                    type="text"
                    name="primary_color_hex"
                    value={Map.get(customization, "primary_color", "#1e40af")}
                    class="flex-1 px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 font-mono text-sm"
                    placeholder="#1e40af" />
                </div>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Secondary Color</label>
                <div class="flex items-center space-x-3">
                  <input
                    type="color"
                    name="secondary_color"
                    value={Map.get(customization, "secondary_color", "#64748b")}
                    class="w-12 h-12 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500" />
                  <input
                    type="text"
                    name="secondary_color_hex"
                    value={Map.get(customization, "secondary_color", "#64748b")}
                    class="flex-1 px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 font-mono text-sm"
                    placeholder="#64748b" />
                </div>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Accent Color</label>
                <div class="flex items-center space-x-3">
                  <input
                    type="color"
                    name="accent_color"
                    value={Map.get(customization, "accent_color", "#f59e0b")}
                    class="w-12 h-12 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500" />
                  <input
                    type="text"
                    name="accent_color_hex"
                    value={Map.get(customization, "accent_color", "#f59e0b")}
                    class="flex-1 px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 font-mono text-sm"
                    placeholder="#f59e0b" />
                </div>
              </div>
            </div>
          </div>
        </form>

        <!-- Color Presets - SEPARATE BUTTONS -->
        <div class="mt-6">
          <label class="block text-sm font-medium text-gray-700 mb-3">Color Presets</label>
          <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-3">
            <%= for preset <- get_color_presets() do %>
              <button
                type="button"
                phx-click="apply_color_preset"
                phx-value-preset={preset.name}
                class="flex flex-col items-center p-3 border border-gray-200 rounded-lg hover:border-gray-300 transition-colors group">
                <div class="flex space-x-1 mb-2">
                  <div class="w-4 h-4 rounded" style={"background-color: #{preset.primary}"}></div>
                  <div class="w-4 h-4 rounded" style={"background-color: #{preset.secondary}"}></div>
                  <div class="w-4 h-4 rounded" style={"background-color: #{preset.accent}"}></div>
                </div>
                <span class="text-xs text-gray-600 group-hover:text-gray-900"><%= preset.name %></span>
              </button>
            <% end %>
          </div>
        </div>
      </div>

      <!-- Typography -->
      <div class="bg-white rounded-xl shadow-sm border p-6">
        <h3 class="text-lg font-bold text-gray-900 mb-4">Typography</h3>
        <p class="text-gray-600 mb-4">Choose fonts and text styling</p>

        <!-- ✅ WRAP IN FORM -->
        <form phx-change="update_customization">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Font Family</label>
              <select
                name="font_family"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500">
                <option value="Inter, sans-serif" selected={get_current_font(customization) == "Inter, sans-serif"}>Inter (Modern Sans-serif)</option>
                <option value="Helvetica, sans-serif" selected={get_current_font(customization) == "Helvetica, sans-serif"}>Helvetica (Classic Sans-serif)</option>
                <option value="Georgia, serif" selected={get_current_font(customization) == "Georgia, serif"}>Georgia (Elegant Serif)</option>
                <option value="JetBrains Mono, monospace" selected={get_current_font(customization) == "JetBrains Mono, monospace"}>JetBrains Mono (Developer)</option>
                <option value="Playfair Display, serif" selected={get_current_font(customization) == "Playfair Display, serif"}>Playfair Display (Creative)</option>
                <option value="Montserrat, sans-serif" selected={get_current_font(customization) == "Montserrat, sans-serif"}>Montserrat (Bold Sans-serif)</option>
              </select>
              <div class="mt-2 p-3 border border-gray-200 rounded-lg">
                <p class="text-sm" style={"font-family: #{get_current_font(customization)}"}>
                  Preview: The quick brown fox jumps over the lazy dog
                </p>
              </div>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Base Font Size</label>
              <select
                name="font_size"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500">
                <option value="small" selected={get_current_font_size(customization) == "small"}>Small (14px base)</option>
                <option value="medium" selected={get_current_font_size(customization) == "medium"}>Medium (16px base)</option>
                <option value="large" selected={get_current_font_size(customization) == "large"}>Large (18px base)</option>
              </select>
            </div>
          </div>
        </form>
      </div>

      <!-- Advanced Options -->
      <div class="bg-white rounded-xl shadow-sm border p-6">
        <h3 class="text-lg font-bold text-gray-900 mb-4">Advanced Options</h3>

        <!-- ✅ WRAP IN FORM -->
        <form phx-change="update_customization">
          <div class="space-y-4">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div class="flex items-center justify-between">
                <div>
                  <label class="text-sm font-medium text-gray-900">Dark Mode Support</label>
                  <p class="text-xs text-gray-600">Enable automatic dark mode detection</p>
                </div>
                <input
                  type="checkbox"
                  name="enable_dark_mode"
                  value="true"
                  checked={Map.get(customization, "enable_dark_mode", false)}
                  class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded">
              </div>
              <div class="flex items-center justify-between">
                <div>
                  <label class="text-sm font-medium text-gray-900">Smooth Animations</label>
                  <p class="text-xs text-gray-600">Enable page transition animations</p>
                </div>
                <input
                  type="checkbox"
                  name="enable_animations"
                  value="true"
                  checked={Map.get(customization, "enable_animations", true)}
                  class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded">
              </div>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Border Radius</label>
                <select
                  name="border_radius"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500">
                  <option value="none" selected={Map.get(customization, "border_radius") == "none"}>None (Sharp corners)</option>
                  <option value="small" selected={Map.get(customization, "border_radius") == "small"}>Small (4px)</option>
                  <option value="medium" selected={Map.get(customization, "border_radius", "medium") == "medium"}>Medium (8px)</option>
                  <option value="large" selected={Map.get(customization, "border_radius") == "large"}>Large (12px)</option>
                  <option value="xl" selected={Map.get(customization, "border_radius") == "xl"}>Extra Large (16px)</option>
                </select>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Section Spacing</label>
                <select
                  name="section_spacing"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500">
                  <option value="tight" selected={Map.get(customization, "section_spacing") == "tight"}>Tight</option>
                  <option value="normal" selected={Map.get(customization, "section_spacing", "normal") == "normal"}>Normal</option>
                  <option value="relaxed" selected={Map.get(customization, "section_spacing") == "relaxed"}>Relaxed</option>
                  <option value="loose" selected={Map.get(customization, "section_spacing") == "loose"}>Loose</option>
                </select>
              </div>
            </div>
          </div>
        </form>
      </div>

      <!-- Custom CSS -->
      <div class="bg-white rounded-xl shadow-sm border p-6">
        <h3 class="text-lg font-bold text-gray-900 mb-4">Custom CSS</h3>
        <p class="text-gray-600 mb-4">Add custom styles (Advanced users only)</p>

        <!-- ✅ WRAP IN FORM -->
        <form phx-change="update_customization">
          <div>
            <textarea
              name="custom_css"
              rows="8"
              phx-debounce="1000"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 font-mono text-sm"
              placeholder="/* Add your custom CSS here */&#10;.portfolio-section {&#10;  /* Custom styles */&#10;}"><%= Map.get(customization, "custom_css", "") %></textarea>
            <p class="text-xs text-gray-500 mt-2">
              Use CSS custom properties: --primary-color, --secondary-color, --accent-color
            </p>
          </div>
        </form>
      </div>

    </div>
    """
  end

  def render_settings_tab(assigns) do
    # Safely extract portfolio data
    portfolio = Map.get(assigns, :portfolio, %{})

    # Helper function to safely get nested values from portfolio
    portfolio_title = if is_struct(portfolio), do: portfolio.title, else: Map.get(portfolio, :title, "")
    portfolio_slug = if is_struct(portfolio), do: portfolio.slug, else: Map.get(portfolio, :slug, "")
    portfolio_description = if is_struct(portfolio), do: portfolio.description, else: Map.get(portfolio, :description, "")
    portfolio_visibility = if is_struct(portfolio), do: portfolio.visibility, else: Map.get(portfolio, :visibility, :private)

    # Safe access to nested fields
    seo_settings = if is_struct(portfolio) do
      Map.get(portfolio, :seo_settings, %{})
    else
      Map.get(portfolio, :seo_settings, %{})
    end

    customization = if is_struct(portfolio) do
      Map.get(portfolio, :customization, %{})
    else
      Map.get(portfolio, :customization, %{})
    end

    settings = if is_struct(portfolio) do
      Map.get(portfolio, :settings, %{})
    else
      Map.get(portfolio, :settings, %{})
    end

    ~H"""
    <div class="space-y-6">

      <!-- Portfolio Settings -->
      <div class="bg-white rounded-xl shadow-sm border p-6">
        <h3 class="text-lg font-bold text-gray-900 mb-4">Portfolio Settings</h3>

        <div class="space-y-6">
          <!-- Basic Info -->
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Portfolio Title</label>
              <input
                type="text"
                name="title"
                value={portfolio_title}
                phx-change="update_portfolio_settings"
                phx-debounce="1000"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
            </div>

            <div class="min-w-0"> <!-- Add min-w-0 to prevent overflow -->
              <label class="block text-sm font-medium text-gray-700 mb-2">URL Slug</label>
              <div class="flex max-w-full">
                <span class="inline-flex items-center px-3 rounded-l-lg border border-r-0 border-gray-300 bg-gray-50 text-gray-500 text-sm whitespace-nowrap">
                  frestyl.com/p/
                </span>
                <input
                  type="text"
                  name="slug"
                  value={portfolio_slug}
                  phx-change="update_portfolio_settings"
                  phx-debounce="1000"
                  class="flex-1 min-w-0 px-3 py-2 border border-gray-300 rounded-r-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
              </div>
            </div>
          </div>

          <!-- Description -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Description</label>
            <textarea
              name="description"
              rows="3"
              phx-change="update_portfolio_settings"
              phx-debounce="1000"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              placeholder="Brief description of your portfolio..."><%= portfolio_description %></textarea>
          </div>

          <!-- Visibility -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-3">Visibility</label>
            <div class="space-y-3">
              <%= for {value, label, description} <- [
                {"public", "Public", "Anyone can find and view your portfolio"},
                {"link_only", "Link Only", "Only people with the link can view"},
                {"private", "Private", "Only you can view (perfect for drafts)"}
              ] do %>
                <label class="relative flex items-start cursor-pointer">
                  <input
                    type="radio"
                    name="visibility"
                    value={value}
                    checked={portfolio_visibility == String.to_atom(value)}
                    phx-click="update_visibility"
                    phx-value-visibility={value}
                    class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 mt-1">
                  <div class="ml-3">
                    <div class="text-sm font-medium text-gray-900"><%= label %></div>
                    <div class="text-sm text-gray-600"><%= description %></div>
                  </div>
                </label>
              <% end %>
            </div>
          </div>
        </div>
      </div>

      <!-- SEO Settings -->
      <div class="bg-white rounded-xl shadow-sm border p-6">
        <h3 class="text-lg font-bold text-gray-900 mb-4">SEO & Sharing</h3>

        <div class="space-y-4">
          <!-- Meta Description -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Meta Description</label>
            <textarea
              name="meta_description"
              rows="2"
              maxlength="160"
              phx-change="update_seo_settings"
              phx-debounce="1000"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              placeholder="Brief description for search engines..."><%= Map.get(seo_settings, "meta_description", "") %></textarea>
            <div class="text-xs text-gray-500 mt-1">
              <span id="meta-counter">0</span>/160 characters
            </div>
          </div>

          <!-- Keywords -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Keywords</label>
            <input
              type="text"
              name="keywords"
              value={Map.get(seo_settings, "keywords", "")}
              phx-change="update_seo_settings"
              phx-debounce="1000"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              placeholder="design, portfolio, creative, freelancer">
            <div class="text-xs text-gray-500 mt-1">Separate keywords with commas</div>
          </div>

          <!-- Social Sharing -->
          <div class="flex items-center">
            <input
              type="checkbox"
              id="social_sharing"
              name="social_sharing_enabled"
              value="true"
              checked={Map.get(seo_settings, "social_sharing_enabled", false) != false}
              phx-click="toggle_social_sharing"
              class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded">
            <label for="social_sharing" class="ml-2 block text-sm text-gray-900">
              Enable social media sharing buttons
            </label>
          </div>
        </div>
      </div>

      <!-- Advanced Settings -->
      <div class="bg-white rounded-xl shadow-sm border p-6">
        <h3 class="text-lg font-bold text-gray-900 mb-4">Advanced</h3>

        <div class="space-y-4">
          <!-- Custom CSS -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Custom CSS</label>
            <textarea
              name="custom_css"
              rows="4"
              phx-change="update_custom_css"
              phx-debounce="2000"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 font-mono text-sm"
              placeholder="/* Add your custom CSS here */"><%= Map.get(customization, "custom_css", "") %></textarea>
          </div>

          <!-- Analytics -->
          <div class="flex items-center">
            <input
              type="checkbox"
              id="analytics_enabled"
              name="analytics_enabled"
              value="true"
              checked={Map.get(settings, "analytics_enabled", false) != false}
              phx-click="toggle_analytics"
              class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded">
            <label for="analytics_enabled" class="ml-2 block text-sm text-gray-900">
              Enable portfolio analytics tracking
            </label>
          </div>

          <!-- Export Options -->
          <div class="pt-4 border-t border-gray-200">
            <h4 class="text-sm font-medium text-gray-900 mb-3">Export Options</h4>
            <div class="flex space-x-3">
              <button
                type="button"
                phx-click="export_portfolio"
                phx-value-format="pdf"
                class="bg-gray-100 hover:bg-gray-200 text-gray-700 px-3 py-2 rounded-lg text-sm font-medium transition-colors">
                Export as PDF
              </button>
              <button
                type="button"
                phx-click="export_portfolio"
                phx-value-format="json"
                class="bg-gray-100 hover:bg-gray-200 text-gray-700 px-3 py-2 rounded-lg text-sm font-medium transition-colors">
                Export Data
              </button>
            </div>
          </div>
        </div>
      </div>

    </div>
    """
  end

  def render_video_intro_section(assigns) do
    # Safely get values with defaults
    current_user = Map.get(assigns, :current_user, %{subscription_tier: "free"})
    show_video_recorder = Map.get(assigns, :show_video_recorder, false)
    sections = Map.get(assigns, :sections, [])
    portfolio = Map.get(assigns, :portfolio, %{})

    # Find existing video intro section
    video_section = find_video_intro_section(sections)

    assigns = assigns
    |> Map.put(:video_section, video_section)
    |> Map.put(:current_user, current_user)
    |> Map.put(:show_video_recorder, show_video_recorder)
    |> Map.put(:portfolio, portfolio)

    ~H"""
    <!-- Video Intro Management -->
    <div class="bg-white rounded-xl shadow-sm border p-6">
      <div class="flex items-center justify-between mb-4">
        <div>
          <h3 class="text-lg font-bold text-gray-900">Video Introduction</h3>
          <p class="text-gray-600 mt-1">Add a personal video to welcome visitors to your portfolio</p>
        </div>

        <!-- Account Tier Badge -->
        <div class="text-xs">
          <%= case Map.get(@current_user, :subscription_tier, "free") do %>
            <% "free" -> %>
              <span class="bg-gray-100 text-gray-700 px-2 py-1 rounded-full">Free: 30s max</span>
            <% "pro" -> %>
              <span class="bg-blue-100 text-blue-700 px-2 py-1 rounded-full">Pro: 2min max</span>
            <% "premium" -> %>
              <span class="bg-purple-100 text-purple-700 px-2 py-1 rounded-full">Premium: 5min max</span>
            <% _ -> %>
              <span class="bg-gray-100 text-gray-700 px-2 py-1 rounded-full">30s max</span>
          <% end %>
        </div>
      </div>

      <%= if @video_section do %>
        <!-- Existing Video -->
        <div class="bg-gradient-to-br from-purple-50 to-blue-50 border border-purple-200 rounded-lg p-4 mb-4">
          <div class="flex items-center space-x-4">
            <div class="flex-shrink-0">
              <div class="w-16 h-16 bg-gradient-to-br from-purple-500 to-blue-600 rounded-lg flex items-center justify-center">
                <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
                </svg>
              </div>
            </div>

            <div class="flex-1">
              <h4 class="font-medium text-gray-900">Video Introduction Active</h4>
              <p class="text-sm text-gray-600 mb-2">
                Duration: <%= format_video_duration(get_in(@video_section.content, ["duration"])) %> •
                Position: <%= format_position_name(get_in(@video_section.content, ["position"])) %>
              </p>

              <!-- Video Preview -->
              <%= if get_in(@video_section.content, ["video_url"]) do %>
                <video class="w-24 h-16 object-cover rounded border mt-2" controls>
                  <source src={get_in(@video_section.content, ["video_url"])} type="video/webm">
                  <source src={get_in(@video_section.content, ["video_url"])} type="video/mp4">
                  Your browser does not support the video tag.
                </video>
              <% end %>
            </div>

            <div class="flex flex-col space-y-2">
              <button
                phx-click="edit_video_intro"
                class="bg-purple-100 hover:bg-purple-200 text-purple-700 px-3 py-2 rounded-lg text-sm font-medium transition-colors">
                <svg class="w-4 h-4 mr-1 inline" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
                </svg>
                Replace
              </button>
              <button
                phx-click="delete_video_intro"
                phx-value-section_id={@video_section.id}
                phx-data-confirm="Are you sure you want to delete your video introduction?"
                class="bg-red-100 hover:bg-red-200 text-red-700 px-3 py-2 rounded-lg text-sm font-medium transition-colors">
                <svg class="w-4 h-4 mr-1 inline" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
                </svg>
                Delete
              </button>
            </div>
          </div>
        </div>
      <% else %>
        <!-- No Video - Upload Options -->
        <div class="border-2 border-dashed border-gray-300 rounded-lg p-8 text-center hover:border-purple-400 transition-colors">
          <div class="w-16 h-16 bg-gradient-to-br from-purple-500 to-blue-600 rounded-full flex items-center justify-center mx-auto mb-4">
            <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
            </svg>
          </div>

          <h4 class="text-lg font-medium text-gray-900 mb-2">Add Video Introduction</h4>
          <p class="text-gray-600 mb-6">
            Welcome visitors with a personal video that showcases your personality and expertise.
            <%= case Map.get(@current_user, :subscription_tier, "free") do %>
              <% "free" -> %> <br><span class="text-sm text-gray-500">Free plan: Videos up to 30 seconds</span>
              <% "pro" -> %> <br><span class="text-sm text-blue-600">Pro plan: Videos up to 2 minutes</span>
              <% "premium" -> %> <br><span class="text-sm text-purple-600">Premium plan: Videos up to 5 minutes</span>
              <% _ -> %> <br><span class="text-sm text-gray-500">Videos up to 30 seconds</span>
            <% end %>
          </p>

          <div class="flex flex-col sm:flex-row gap-3 justify-center">
            <button
              phx-click="show_video_recorder"
              class="bg-purple-600 hover:bg-purple-700 text-white px-6 py-3 rounded-lg font-medium transition-colors inline-flex items-center justify-center">
              <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
              </svg>
              Record Video
            </button>

            <button
              phx-click="show_video_uploader"
              class="bg-gray-100 hover:bg-gray-200 text-gray-700 px-6 py-3 rounded-lg font-medium transition-colors inline-flex items-center justify-center">
              <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/>
              </svg>
              Upload Video
            </button>
          </div>

          <div class="mt-4 text-xs text-gray-500">
            Supported formats: MP4, WebM, MOV • Max file size: 50MB
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  def render_video_recorder_modal(assigns) do
    ~H"""
    <%= if Map.get(assigns, :show_video_recorder, false) do %>
      <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4"
          phx-window-keydown="close_modal_on_escape"
          phx-key="Escape">
        <.live_component
          module={EnhancedVideoIntroComponent}
          id={"video-intro-recorder-modal-#{@portfolio.id}"}
          portfolio={Map.get(assigns, :portfolio, %{})}
          current_user={Map.get(assigns, :current_user, %{})}
        />
      </div>
    <% end %>
    """
  end

  def render_resume_import_modal(assigns) do
    ~H"""
    <%= if Map.get(assigns, :show_resume_import, false) do %>
      <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4"
          phx-window-keydown="close_modal_on_escape"
          phx-key="Escape">
        <div class="bg-white rounded-xl shadow-2xl max-w-2xl w-full max-h-[90vh] overflow-hidden"
            phx-click-away="close_resume_import">
          <!-- Resume import content here -->
          <!-- (Keep existing content but add phx-click-away) -->
        </div>
      </div>
    <% end %>
    """
  end

  def render_design_tab(assigns) do
    # Safely extract customization data
    customization = Map.get(assigns, :customization, %{})

    ~H"""
    <div class="space-y-6">
      <!-- Color Scheme -->
      <div class="bg-white rounded-xl shadow-sm border p-6">
        <h3 class="text-lg font-bold text-gray-900 mb-4">Color Scheme</h3>

        <!-- WRAP IN FORM TAG -->
        <form phx-change="update_customization" phx-submit="update_customization" class="space-y-6">
          <!-- Portfolio Layout Selection -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-3">Portfolio Layout</label>
            <select
              name="portfolio_layout"
              value={Map.get(customization, "portfolio_layout", "dashboard")}
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
              <option value="single_column" selected={Map.get(customization, "portfolio_layout") == "single_column"}>Single Column</option>
              <option value="dashboard" selected={Map.get(customization, "portfolio_layout") == "dashboard"}>Dashboard</option>
              <option value="grid" selected={Map.get(customization, "portfolio_layout") == "grid"}>Grid Layout</option>
              <option value="timeline" selected={Map.get(customization, "portfolio_layout") == "timeline"}>Timeline</option>
            </select>
          </div>

          <!-- Color Presets -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-3">Quick Presets</label>
            <div class="grid grid-cols-2 gap-3">
              <%= for preset <- get_color_suggestions() do %>
                <button
                  type="button"
                  phx-click="apply_color_preset"
                  phx-value-preset={Jason.encode!(preset)}
                  class="flex items-center space-x-3 p-3 border border-gray-200 rounded-lg hover:border-gray-300 transition-colors text-left">
                  <div class="flex space-x-1">
                    <div class="w-4 h-4 rounded" style={"background-color: #{preset.primary}"}></div>
                    <div class="w-4 h-4 rounded" style={"background-color: #{preset.secondary}"}></div>
                    <div class="w-4 h-4 rounded" style={"background-color: #{preset.accent}"}></div>
                  </div>
                  <span class="text-sm font-medium text-gray-900"><%= preset.name %></span>
                </button>
              <% end %>
            </div>
          </div>

          <!-- Individual Color Inputs -->
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Primary Color</label>
              <div class="flex items-center space-x-2">
                <input
                  type="color"
                  name="primary_color"
                  value={Map.get(customization, "primary_color", "#1e40af")}
                  class="w-12 h-10 border border-gray-300 rounded-lg cursor-pointer">
                <input
                  type="text"
                  name="primary_color_text"
                  value={Map.get(customization, "primary_color", "#1e40af")}
                  class="flex-1 px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 text-sm font-mono">
              </div>
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Secondary Color</label>
              <div class="flex items-center space-x-2">
                <input
                  type="color"
                  name="secondary_color"
                  value={Map.get(customization, "secondary_color", "#64748b")}
                  class="w-12 h-10 border border-gray-300 rounded-lg cursor-pointer">
                <input
                  type="text"
                  name="secondary_color_text"
                  value={Map.get(customization, "secondary_color", "#64748b")}
                  class="flex-1 px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 text-sm font-mono">
              </div>
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Accent Color</label>
              <div class="flex items-center space-x-2">
                <input
                  type="color"
                  name="accent_color"
                  value={Map.get(customization, "accent_color", "#3b82f6")}
                  class="w-12 h-10 border border-gray-300 rounded-lg cursor-pointer">
                <input
                  type="text"
                  name="accent_color_text"
                  value={Map.get(customization, "accent_color", "#3b82f6")}
                  class="flex-1 px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 text-sm font-mono">
              </div>
            </div>
          </div>
        </form>
      </div>

      <!-- Typography & Layout -->
      <div class="bg-white rounded-xl shadow-sm border p-6">
        <h3 class="text-lg font-bold text-gray-900 mb-4">Typography & Layout</h3>

        <!-- SEPARATE FORM FOR TYPOGRAPHY -->
        <form phx-change="update_customization" phx-submit="update_customization" class="space-y-6">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <!-- Font Family -->
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Font Family</label>
              <select
                name="font_family"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
                <option value="inter" selected={Map.get(customization, "font_family") == "inter"}>Inter (Modern)</option>
                <option value="system" selected={Map.get(customization, "font_family") == "system"}>System Default</option>
                <option value="serif" selected={Map.get(customization, "font_family") == "serif"}>Serif (Classic)</option>
                <option value="mono" selected={Map.get(customization, "font_family") == "mono"}>Monospace (Tech)</option>
              </select>
            </div>

            <!-- Layout Style -->
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Layout Style</label>
              <select
                name="layout_style"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
                <option value="modern" selected={Map.get(customization, "layout_style") == "modern"}>Modern</option>
                <option value="minimal" selected={Map.get(customization, "layout_style") == "minimal"}>Minimal</option>
                <option value="creative" selected={Map.get(customization, "layout_style") == "creative"}>Creative</option>
                <option value="professional" selected={Map.get(customization, "layout_style") == "professional"}>Professional</option>
              </select>
            </div>
          </div>

          <!-- Hero Style -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-3">Hero Section Style</label>
            <div class="grid grid-cols-1 md:grid-cols-4 gap-3">
              <%= for style <- ["gradient", "image", "video", "minimal"] do %>
                <button
                  type="button"
                  phx-click="update_hero_style"
                  phx-value-style={style}
                  class={[
                    "p-4 border-2 rounded-lg transition-colors text-center",
                    if(Map.get(customization, "hero_style") == style,
                      do: "border-blue-600 bg-blue-50",
                      else: "border-gray-200 hover:border-gray-300")
                  ]}>
                  <div class="text-sm font-medium text-gray-900 capitalize"><%= style %></div>
                  <div class="text-xs text-gray-600 mt-1"><%= get_hero_style_description(style) %></div>
                </button>
              <% end %>
            </div>
          </div>
        </form>
      </div>
    </div>
    """
  end

  defp render_section_form_fields(assigns, section) do
    section_type = section.section_type

    case section_type do
      "hero" -> render_hero_section_form(assigns)
      "about" -> render_about_section_form(assigns)
      "experience" -> render_experience_section_form(assigns)
      "education" -> render_education_section_form(assigns)
      "skills" -> render_skills_section_form(assigns)
      "projects" -> render_projects_section_form(assigns)
      "testimonials" -> render_testimonials_section_form(assigns)
      "contact" -> render_contact_section_form(assigns)
      "custom" -> render_custom_section_form(assigns)
      _ -> render_standard_section_form(assigns)
    end
  end


  def render_section_card(assigns) do
    assigns = assign(assigns, :section_gradient, get_section_gradient(assigns.section.section_type))
    assigns = assign(assigns, :section_preview, get_section_content_preview(assigns.section))

    ~H"""
    <div class={[
      "bg-white rounded-xl border border-gray-200 transition-all duration-300 group relative",
      "hover:shadow-lg hover:border-gray-300",
      "max-h-80 min-h-48 flex flex-col",  # Max height with min height, allows dashboard layout flexibility
      unless(@section.visible, do: "opacity-75", else: "opacity-100")
    ]}
    style={unless(@section.visible, do: "background-color: #f9fafb;", else: "")}
    data-section-id={@section.id}
    id={"section-#{@section.id}"}>

      <!-- Card Header - Fixed Height -->
      <div class={[
        "relative p-4 border-b border-gray-100 bg-gradient-to-br flex-shrink-0",
        @section_gradient
      ]}>
        <div class="flex items-center space-x-3 pr-4">
          <div class="w-10 h-10 bg-white/20 backdrop-blur-sm rounded-lg flex items-center justify-center">
            <%= raw(get_section_icon(@section.section_type)) %>
          </div>
          <div class="flex-1 min-w-0">  <!-- Added min-w-0 for text truncation -->
            <h3 class="font-bold text-white text-lg drop-shadow-sm truncate"><%= @section.title %></h3>
            <div class="flex items-center space-x-2">
              <span class="text-sm text-white/80 truncate"><%= format_section_type(@section.section_type) %></span>
              <%= unless @section.visible do %>
                <span class="inline-flex items-center px-2 py-1 text-xs font-medium bg-yellow-100 text-yellow-800 rounded-full flex-shrink-0">
                  Hidden
                </span>
              <% end %>
            </div>
          </div>

          <!-- Action Icons - Original Layout (No Dropdowns) -->
          <div class="flex items-center space-x-2 flex-shrink-0">
            <!-- Visibility Toggle -->
            <button
              phx-click="toggle_section_visibility"
              phx-value-section_id={@section.id}
              class={[
                "p-2 rounded-lg transition-colors",
                if(@section.visible,
                  do: "text-white/80 hover:text-white hover:bg-white/20",
                  else: "text-white/60 hover:text-white/80 hover:bg-white/10")
              ]}
              title={if @section.visible, do: "Hide section", else: "Show section"}>
              <%= if @section.visible do %>
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
                </svg>
              <% else %>
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.878 9.878L3 3m6.878 6.878L12 12m0 0l3.122 3.122m0 0L21 21"/>
                </svg>
              <% end %>
            </button>

            <!-- Edit -->
            <button
              phx-click="edit_section"
              phx-value-section_id={@section.id}
              class="p-2 text-white/80 hover:text-white hover:bg-white/20 rounded-lg transition-colors"
              title="Edit section">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
              </svg>
            </button>

            <!-- Duplicate -->
            <button
              phx-click="duplicate_section"
              phx-value-section_id={@section.id}
              class="p-2 text-white/80 hover:text-white hover:bg-white/20 rounded-lg transition-colors"
              title="Duplicate section">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/>
              </svg>
            </button>

            <!-- Attach Media -->
            <button
              phx-click="attach_section_media"
              phx-value-section_id={@section.id}
              class="p-2 text-white/80 hover:text-white hover:bg-white/20 rounded-lg transition-colors"
              title="Attach media">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.172 7l-6.586 6.586a2 2 0 102.828 2.828l6.414-6.586a4 4 0 00-5.656-5.656l-6.415 6.585a6 6 0 108.486 8.486L20.5 13"/>
              </svg>
            </button>

            <!-- Delete -->
            <button
              phx-click="delete_section"
              phx-value-section_id={@section.id}
              data-confirm="Are you sure you want to delete this section?"
              class="p-2 text-red-200 hover:text-red-100 hover:bg-red-500/20 rounded-lg transition-colors"
              title="Delete section">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
              </svg>
            </button>
          </div>
        </div>
      </div>

      <!-- Scrollable Card Content - Takes remaining space, respects max height -->
      <div class="flex-1 overflow-hidden flex flex-col">
        <div class="p-4 overflow-y-auto flex-1 scrollbar-thin scrollbar-thumb-gray-300 scrollbar-track-gray-100 max-h-48">
          <!-- Section Preview with Better Formatting -->
          <div class="text-sm text-gray-600 mb-3 leading-relaxed">
            <%= @section_preview %>
          </div>

          <!-- Additional Content Based on Section Type -->
          <%= render_section_card_details(@section) %>
        </div>

        <!-- Card Footer - Simplified -->
        <div class="flex-shrink-0 px-4 py-3 bg-gray-50 border-t border-gray-100">
          <div class="flex items-center justify-between">
            <div class="text-xs text-gray-500">
              Last updated: <%= time_ago(Map.get(@section, :updated_at, @section.inserted_at)) %>
            </div>
            <button
              phx-click="edit_section"
              phx-value-section_id={@section.id}
              class="text-xs text-blue-600 hover:text-blue-700 font-medium">
              Edit
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def render_enhanced_section_card(assigns) do
    section_preview = get_section_content_preview(assigns.section)
    section_stats = get_section_stats(assigns.section)

    assigns = assigns
    |> assign(:section_preview, section_preview)
    |> assign(:section_stats, section_stats)
    |> assign(:section_gradient, get_section_gradient(assigns.section.section_type))

    ~H"""
    <div class={[
      "bg-white rounded-xl border border-gray-200 transition-all duration-300 group relative",
      "hover:shadow-lg hover:border-gray-300",
      unless(@section.visible, do: "opacity-75", else: "opacity-100")
    ]}
    style={unless(@section.visible, do: "background-color: #f9fafb;", else: "")}
    data-section-id={@section.id}
    id={"section-#{@section.id}"}>

      <!-- Card Header -->
      <div class={[
        "relative p-4 border-b border-gray-100 bg-gradient-to-br",
        @section_gradient
      ]}>
        <div class="flex items-center space-x-3 pr-4">
          <div class="w-10 h-10 bg-white/20 backdrop-blur-sm rounded-lg flex items-center justify-center">
            <%= raw(get_section_icon(@section.section_type)) %>
          </div>
          <div class="flex-1">
            <h3 class="font-bold text-white text-lg drop-shadow-sm"><%= @section.title %></h3>
            <div class="flex items-center space-x-2">
              <span class="text-sm text-white/80"><%= format_section_type(@section.section_type) %></span>
              <%= unless @section.visible do %>
                <span class="inline-flex items-center px-2 py-1 text-xs font-medium bg-yellow-100 text-yellow-800 rounded-full">
                  Hidden
                </span>
              <% end %>
            </div>
          </div>

          <!-- Action Icons (keeping existing functionality) -->
          <div class="flex items-center space-x-2">
            <!-- Visibility Toggle -->
            <button
              phx-click="toggle_section_visibility"
              phx-value-section_id={@section.id}
              class="p-2 text-white/80 hover:text-white hover:bg-white/20 rounded-lg transition-colors"
              title={if @section.visible, do: "Hide section", else: "Show section"}>
              <%= if @section.visible do %>
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
                </svg>
              <% else %>
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.878 9.878L3 3m6.878 6.878L12 12m0 0l3.122 3.122m0 0L21 21"/>
                </svg>
              <% end %>
            </button>

            <!-- Edit -->
            <button
              phx-click="edit_section"
              phx-value-section_id={@section.id}
              class="p-2 text-white/80 hover:text-white hover:bg-white/20 rounded-lg transition-colors"
              title="Edit section">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
              </svg>
            </button>

            <!-- Duplicate -->
            <button
              phx-click="duplicate_section"
              phx-value-section_id={@section.id}
              class="p-2 text-white/80 hover:text-white hover:bg-white/20 rounded-lg transition-colors"
              title="Duplicate section">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/>
              </svg>
            </button>

            <!-- Attach Media -->
            <button
              phx-click="attach_section_media"
              phx-value-section_id={@section.id}
              class="p-2 text-white/80 hover:text-white hover:bg-white/20 rounded-lg transition-colors"
              title="Attach media">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.172 7l-6.586 6.586a2 2 0 102.828 2.828l6.414-6.586a4 4 0 00-5.656-5.656l-6.415 6.585a6 6 0 108.486 8.486L20.5 13"/>
              </svg>
            </button>

            <!-- Delete -->
            <button
              phx-click="delete_section"
              phx-value-section_id={@section.id}
              phx-data-confirm="Are you sure you want to delete this section?"
              class="p-2 text-red-200 hover:text-red-100 hover:bg-red-500/20 rounded-lg transition-colors"
              title="Delete section">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
              </svg>
            </button>
          </div>
        </div>
      </div>

      <!-- Enhanced Card Content -->
      <div class="p-6">
        <!-- Type-specific section preview -->
        <div class="text-sm text-gray-600 mb-3">
          <%= @section_preview %>
        </div>

        <!-- Section statistics/metadata -->
        <%= if @section_stats do %>
          <div class="flex items-center space-x-4 text-xs text-gray-500">
            <%= for stat <- @section_stats do %>
              <span class="flex items-center space-x-1">
                <span class="w-2 h-2 bg-gray-300 rounded-full"></span>
                <span><%= stat %></span>
              </span>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_section_card_details(section) do
    content = section.content || %{}

    case to_string(section.section_type) do
      "hero" ->
        assigns = %{content: content}
        ~H"""
        <div class="space-y-2 text-xs">
          <%= if Map.get(@content, "headline") do %>
            <div><span class="font-medium">Headline:</span> <%= Map.get(@content, "headline") %></div>
          <% end %>
          <%= if Map.get(@content, "tagline") do %>
            <div><span class="font-medium">Tagline:</span> <%= Map.get(@content, "tagline") %></div>
          <% end %>
          <%= if Map.get(@content, "cta_text") do %>
            <div><span class="font-medium">CTA:</span> <%= Map.get(@content, "cta_text") %></div>
          <% end %>
        </div>
        """

      "experience" ->
        items = Map.get(content, "items", [])
        assigns = %{items: items}
        ~H"""
        <div class="space-y-3">
          <%= for {item, index} <- Enum.with_index(Enum.take(@items, 2)) do %>
            <div class="text-xs border-l-2 border-blue-200 pl-2">
              <div class="font-medium text-gray-800"><%= Map.get(item, "title", "Position") %></div>
              <div class="text-gray-600"><%= Map.get(item, "company", "Company") %></div>
              <%= if Map.get(item, "current") do %>
                <span class="inline-block px-1 py-0.5 bg-green-100 text-green-700 rounded text-xs">Current</span>
              <% end %>
            </div>
          <% end %>
          <%= if length(@items) > 2 do %>
            <div class="text-xs text-gray-500">+ <%= length(@items) - 2 %> more positions</div>
          <% end %>
        </div>
        """

      "skills" ->
        categories = Map.get(content, "categories", [])
        assigns = %{categories: categories}
        ~H"""
        <div class="space-y-2">
          <%= for {category, index} <- Enum.with_index(Enum.take(@categories, 3)) do %>
            <div class="text-xs">
              <div class="font-medium text-gray-800"><%= Map.get(category, "name", "Category") %></div>
              <div class="text-gray-600">
                <%= Map.get(category, "skills", []) |> Enum.take(3) |> Enum.join(", ") %>
                <%= if length(Map.get(category, "skills", [])) > 3 do %>
                  <span class="text-gray-400">+<%= length(Map.get(category, "skills", [])) - 3 %> more</span>
                <% end %>
              </div>
            </div>
          <% end %>
          <%= if length(@categories) > 3 do %>
            <div class="text-xs text-gray-500">+ <%= length(@categories) - 3 %> more categories</div>
          <% end %>
        </div>
        """

      "projects" ->
        items = Map.get(content, "items", [])
        assigns = %{items: items}
        ~H"""
        <div class="space-y-3">
          <%= for {item, index} <- Enum.with_index(Enum.take(@items, 2)) do %>
            <div class="text-xs border-l-2 border-purple-200 pl-2">
              <div class="font-medium text-gray-800"><%= Map.get(item, "title", "Project") %></div>
              <%= if Map.get(item, "technologies") do %>
                <div class="text-gray-600 mb-1"><%= Map.get(item, "technologies") %></div>
              <% end %>
              <div class="flex space-x-2">
                <%= if Map.get(item, "demo_url") && Map.get(item, "demo_url") != "" do %>
                  <span class="px-1 py-0.5 bg-blue-100 text-blue-700 rounded text-xs">Demo</span>
                <% end %>
                <%= if Map.get(item, "source_url") && Map.get(item, "source_url") != "" do %>
                  <span class="px-1 py-0.5 bg-gray-100 text-gray-700 rounded text-xs">Source</span>
                <% end %>
              </div>
            </div>
          <% end %>
          <%= if length(@items) > 2 do %>
            <div class="text-xs text-gray-500">+ <%= length(@items) - 2 %> more projects</div>
          <% end %>
        </div>
        """

      _ ->
        # Default content display for other section types
        main_content = Map.get(content, "content", Map.get(content, "main_content", ""))
        assigns = %{main_content: main_content}
        if main_content != "" do
          ~H"""
          <div class="text-xs text-gray-600 leading-relaxed">
            <%= truncate_text(@main_content, 200) %>
          </div>
          """
        else
          ~H"""
          <div class="text-xs text-gray-400 italic">
            No content configured yet
          </div>
          """
        end
    end
  end

  def render_layout_options(assigns) do
    ~H"""
    <!-- Portfolio Layout Style -->
    <div class="bg-white rounded-xl shadow-sm border p-6">
      <h3 class="text-lg font-bold text-gray-900 mb-4">Portfolio Layout</h3>

      <form phx-change="update_customization" class="space-y-6">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-3">Choose your portfolio layout style</label>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <%= for {layout_id, layout_info} <- get_portfolio_layouts() do %>
              <label class="relative">
                <input
                  type="radio"
                  name="portfolio_layout"
                  value={layout_id}
                  checked={@customization["portfolio_layout"] == layout_id}
                  class="sr-only peer">
                <div class="p-4 border-2 border-gray-200 rounded-lg cursor-pointer peer-checked:border-blue-500 peer-checked:bg-blue-50 hover:border-gray-300 transition-colors">
                  <div class="flex items-start space-x-3">
                    <div class="flex-shrink-0 w-12 h-12 bg-gray-100 rounded-lg flex items-center justify-center">
                      <%= raw(layout_info.icon) %>
                    </div>
                    <div class="flex-1">
                      <h4 class="font-medium text-gray-900"><%= layout_info.name %></h4>
                      <p class="text-sm text-gray-600 mt-1"><%= layout_info.description %></p>
                    </div>
                  </div>
                </div>
              </label>
            <% end %>
          </div>
        </div>
      </form>
    </div>
    """
  end

  defp get_portfolio_layouts do
    %{
      "single_column" => %{
        name: "Single Column",
        description: "Traditional single-column layout with sections stacked vertically",
        icon: "<svg class='w-6 h-6 text-gray-600' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M4 6h16M4 10h16M4 14h16M4 18h16'/></svg>"
      },
      "dashboard" => %{
        name: "Dashboard",
        description: "Card-based layout with varying sized sections like a dashboard",
        icon: "<svg class='w-6 h-6 text-gray-600' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M4 5a1 1 0 011-1h4a1 1 0 011 1v7a1 1 0 01-1 1H5a1 1 0 01-1-1V5zM14 5a1 1 0 011-1h4a1 1 0 011 1v2a1 1 0 01-1 1h-4a1 1 0 01-1-1V5zM14 12a1 1 0 011-1h4a1 1 0 011 1v7a1 1 0 01-1 1h-4a1 1 0 01-1-1v-7z'/></svg>"
      },
      "grid" => %{
        name: "Grid Layout",
        description: "Pinterest/Behance-style masonry grid layout",
        icon: "<svg class='w-6 h-6 text-gray-600' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z'/></svg>"
      },
      "timeline" => %{
        name: "Timeline",
        description: "Chronological timeline layout perfect for career progression",
        icon: "<svg class='w-6 h-6 text-gray-600' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z'/></svg>"
      }
    }
  end

  defp get_section_content_preview(section) do
    content = section.content || %{}

    case to_string(section.section_type) do
      "hero" ->
        headline = Map.get(content, "headline", "")
        tagline = Map.get(content, "tagline", "")

        cond do
          headline != "" && tagline != "" -> "#{headline} • #{tagline}"
          headline != "" -> headline
          tagline != "" -> tagline
          true -> "No headline or tagline set"
        end

      "about" ->
        about_content = Map.get(content, "content", "")
        highlights = Map.get(content, "highlights", [])

        cond do
          about_content != "" -> truncate_text(about_content, 100)
          length(highlights) > 0 -> "#{length(highlights)} highlights added"
          true -> "No about content added"
        end

      "experience" ->
        items = Map.get(content, "items", [])
        if length(items) > 0 do
          latest = List.first(items)
          company = Map.get(latest, "company", "")
          title = Map.get(latest, "title", "")

          if company != "" && title != "" do
            "Latest: #{title} at #{company} • #{length(items)} total"
          else
            "#{length(items)} work experience#{if length(items) == 1, do: "", else: "s"}"
          end
        else
          "No work experience added"
        end

      "education" ->
        items = Map.get(content, "items", [])
        if length(items) > 0 do
          latest = List.first(items)
          degree = Map.get(latest, "degree", "")
          institution = Map.get(latest, "institution", "")

          if degree != "" && institution != "" do
            "Latest: #{degree} from #{institution} • #{length(items)} total"
          else
            "#{length(items)} education item#{if length(items) == 1, do: "", else: "s"}"
          end
        else
          "No education added"
        end

      "skills" ->
        categories = Map.get(content, "categories", [])
        if length(categories) > 0 do
          total_skills = categories
          |> Enum.map(&(Map.get(&1, "skills", []) |> length()))
          |> Enum.sum()

          "#{length(categories)} categories • #{total_skills} skills total"
        else
          "No skills categorized"
        end

      "projects" ->
        items = Map.get(content, "items", [])
        if length(items) > 0 do
          featured = Enum.find(items, &Map.get(&1, "featured", false)) || List.first(items)
          project_title = Map.get(featured, "title", "")

          if project_title != "" do
            "Featured: #{project_title} • #{length(items)} total"
          else
            "#{length(items)} project#{if length(items) == 1, do: "", else: "s"}"
          end
        else
          "No projects added"
        end

      "testimonials" ->
        items = Map.get(content, "items", [])
        if length(items) > 0 do
          latest = List.first(items)
          name = Map.get(latest, "name", "")
          company = Map.get(latest, "company", "")

          if name != "" && company != "" do
            "Latest from #{name} at #{company} • #{length(items)} total"
          else
            "#{length(items)} testimonial#{if length(items) == 1, do: "", else: "s"}"
          end
        else
          "No testimonials added"
        end

      "contact" ->
        email = Map.get(content, "email", "")
        phone = Map.get(content, "phone", "")
        location = Map.get(content, "location", "")
        form_enabled = Map.get(content, "contact_form_enabled", false)

        info_parts = [email, phone, location] |> Enum.reject(&(&1 == ""))
        contact_info = if length(info_parts) > 0, do: Enum.join(info_parts, " • "), else: ""

        form_text = if form_enabled, do: "Contact form enabled", else: ""

        cond do
          contact_info != "" && form_text != "" -> "#{contact_info} • #{form_text}"
          contact_info != "" -> contact_info
          form_text != "" -> form_text
          true -> "No contact information set"
        end

      "certifications" ->
        items = Map.get(content, "items", [])
        if length(items) > 0 do
          latest = List.first(items)
          cert_name = Map.get(latest, "name", "")
          issuer = Map.get(latest, "issuer", "")

          if cert_name != "" && issuer != "" do
            "Latest: #{cert_name} from #{issuer} • #{length(items)} total"
          else
            "#{length(items)} certification#{if length(items) == 1, do: "", else: "s"}"
          end
        else
          "No certifications added"
        end

      "achievements" ->
        items = Map.get(content, "items", [])
        if length(items) > 0 do
          latest = List.first(items)
          achievement_title = Map.get(latest, "title", "")
          organization = Map.get(latest, "organization", "")

          if achievement_title != "" && organization != "" do
            "Latest: #{achievement_title} from #{organization} • #{length(items)} total"
          else
            "#{length(items)} achievement#{if length(items) == 1, do: "", else: "s"}"
          end
        else
          "No achievements added"
        end

      "services" ->
        items = Map.get(content, "items", [])
        if length(items) > 0 do
          pricing_info = items
          |> Enum.map(&Map.get(&1, "price", ""))
          |> Enum.reject(&(&1 == ""))

          if length(pricing_info) > 0 do
            "#{length(items)} services • Pricing configured"
          else
            "#{length(items)} service#{if length(items) == 1, do: "", else: "s"} • No pricing"
          end
        else
          "No services offered"
        end

      "blog" ->
        items = Map.get(content, "items", [])
        if length(items) > 0 do
          latest = List.first(items)
          post_title = Map.get(latest, "title", "")
          category = Map.get(latest, "category", "")

          if post_title != "" && category != "" do
            "Latest: #{truncate_text(post_title, 30)} (#{category}) • #{length(items)} total"
          else
            "#{length(items)} blog post#{if length(items) == 1, do: "", else: "s"}"
          end
        else
          "No blog posts added"
        end

      "gallery" ->
        images = Map.get(content, "images", [])
        layout_style = Map.get(content, "layout_style", "grid")

        if length(images) > 0 do
          "#{length(images)} image#{if length(images) == 1, do: "", else: "s"} • #{String.capitalize(layout_style)} layout"
        else
          "No images in gallery"
        end

      "custom" ->
        custom_title = Map.get(content, "title", "")
        layout_type = Map.get(content, "layout_type", "text")
        custom_content = Map.get(content, "content", "")

        cond do
          custom_title != "" && custom_content != "" ->
            "#{custom_title} • #{String.capitalize(layout_type)} layout"
          custom_title != "" ->
            "#{custom_title} • No content added"
          custom_content != "" ->
            "#{String.capitalize(layout_type)} layout • #{truncate_text(custom_content, 50)}"
          true ->
            "#{String.capitalize(layout_type)} layout • No content"
        end

      "published_articles" ->
        articles_count = length(Map.get(content, "articles", []))
        total_views = Map.get(content, "total_views", 0)
        total_revenue = Map.get(content, "total_revenue", 0)

        if articles_count > 0 do
          metrics = []
          metrics = if total_views > 0, do: ["#{format_number(total_views)} views" | metrics], else: metrics
          metrics = if total_revenue > 0, do: ["$#{:erlang.float_to_binary(total_revenue, decimals: 2)} earned" | metrics], else: metrics

          base_text = "#{articles_count} published article#{if articles_count == 1, do: "", else: "s"}"
          if length(metrics) > 0, do: "#{base_text} • #{Enum.join(metrics, " • ")}", else: base_text
        else
          "No published articles yet"
        end

      _ ->
        # Fallback for unknown section types
        main_content = Map.get(content, "content", Map.get(content, "main_content", ""))
        if main_content != "" do
          truncate_text(main_content, 100)
        else
          "No content added yet"
        end
    end
  end

  defp truncate_text(text, max_length) when is_binary(text) do
    if String.length(text) > max_length do
      String.slice(text, 0, max_length) <> "..."
    else
      text
    end
  end
  defp truncate_text(_, _), do: "No content"

  defp truncate_text(text) when is_binary(text) do
    if String.length(text) > 100 do
      String.slice(text, 0, 100) <> "..."
    else
      text
    end
  end

  defp get_section_gradient(section_type) do
    case to_string(section_type) do
      "intro" -> "from-blue-500 to-purple-600"
      "about" -> "from-green-500 to-teal-600"
      "experience" -> "from-purple-500 to-pink-600"
      "education" -> "from-indigo-500 to-blue-600"
      "skills" -> "from-yellow-500 to-orange-600"
      "projects" -> "from-red-500 to-pink-600"
      "certifications" -> "from-emerald-500 to-cyan-600"
      "achievements" -> "from-amber-500 to-yellow-600"
      "services" -> "from-violet-500 to-purple-600"
      "blog" -> "from-slate-500 to-gray-600"
      "gallery" -> "from-rose-500 to-pink-600"
      "testimonials" -> "from-cyan-500 to-blue-600"
      "contact" -> "from-green-500 to-emerald-600"
      "custom" -> "from-gray-500 to-slate-600"
      "published_articles" -> "from-indigo-500 to-purple-600"
      _ -> "from-gray-400 to-gray-600"
    end
  end

  defp get_section_icon(section_type) do
    case to_string(section_type) do
      "hero" -> "<svg class='w-5 h-5 text-white' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6'/></svg>"
      "about" -> "<svg class='w-5 h-5 text-white' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z'/></svg>"
      "experience" -> "<svg class='w-5 h-5 text-white' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2-2v2m8 0V4a2 2 0 00-2-2h-4a2 2 0 00-2-2v2m8 0V4a2 2 0 00-2-2h-4a2 2 0 00-2-2v2'/></svg>"
      "education" -> "<svg class='w-5 h-5 text-white' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.246 18 16.5 18c-1.746 0-3.332.477-4.5 1.253'/></svg>"
      "skills" -> "<svg class='w-5 h-5 text-white' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M13 10V3L4 14h7v7l9-11h-7z'/></svg>"
      "projects" -> "<svg class='w-5 h-5 text-white' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10'/></svg>"
      "achievements" -> "<svg class='w-5 h-5 text-white' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M9 12l2 2 4-4M7.835 4.697a3.42 3.42 0 001.946-.806 3.42 3.42 0 014.438 0 3.42 3.42 0 001.946.806 3.42 3.42 0 013.138 3.138 3.42 3.42 0 00.806 1.946 3.42 3.42 0 010 4.438 3.42 3.42 0 00-.806 1.946 3.42 3.42 0 01-3.138 3.138 3.42 3.42 0 00-1.946.806 3.42 3.42 0 01-4.438 0 3.42 3.42 0 00-1.946-.806 3.42 3.42 0 01-3.138-3.138 3.42 3.42 0 00-.806-1.946 3.42 3.42 0 010-4.438 3.42 3.42 0 00.806-1.946 3.42 3.42 0 013.138-3.138z'/></svg>"
      "published_articles" -> "<svg class='w-5 h-5 text-white' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M19 20H5a2 2 0 01-2-2V6a2 2 0 012-2h10a1 1 0 01.707.293l5 5A1 1 0 0121 10v8a2 2 0 01-2 2z'/><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M9 12h6m-6 4h6'/></svg>"
      _ -> "<svg class='w-5 h-5 text-white' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z'/></svg>"
    end
  end

  defp format_section_type(section_type) do
    section_type
    |> to_string()
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp render_default_content(assigns) do
    ~H"""
    <%= if Map.get(@content, "content") do %>
      <div class="prose prose-lg max-w-none text-gray-700">
        <%= format_content_with_paragraphs(Map.get(@content, "content")) %>
      </div>
    <% else %>
      <div class="text-center text-gray-500 py-12">
        <p>No content added yet.</p>
      </div>
    <% end %>
    """
  end

  def render_hero_section_modal(assigns) do
    content = get_section_content_map(assigns.editing_section)
    assigns = assign(assigns, :content, content)

    ~H"""
    <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4"
        phx-window-keydown="close_modal_on_escape"
        phx-key="Escape">
      <div class="bg-white rounded-xl shadow-2xl max-w-4xl w-full max-h-[90vh] overflow-hidden"
          phx-click-away="close_section_modal">
        <!-- Header -->
        <div class="flex items-center justify-between p-6 border-b border-gray-200">
          <h3 class="text-lg font-bold text-gray-900 flex items-center">
            <div class="w-8 h-8 bg-gradient-to-br from-blue-500 to-purple-600 rounded-lg flex items-center justify-center mr-3">
              <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6"/>
              </svg>
            </div>
            Edit Hero Section
          </h3>
          <button phx-click="close_section_modal" class="text-gray-400 hover:text-gray-600">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </button>
        </div>

        <!-- Content -->
        <div class="p-6 overflow-y-auto max-h-[calc(90vh-140px)]">
          <form phx-submit="save_section" class="space-y-6">
            <input type="hidden" name="section_id" value={assigns.editing_section.id} />

            <!-- Section Title -->
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Section Title</label>
              <input
                type="text"
                name="title"
                value={assigns.editing_section.title}
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
            </div>

            <!-- Hero Content Fields -->
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Headline</label>
                <input
                  type="text"
                  name="headline"
                  value={Map.get(@content, "headline", "")}
                  placeholder="Your Name Here"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Tagline</label>
                <input
                  type="text"
                  name="tagline"
                  value={Map.get(@content, "tagline", "")}
                  placeholder="Professional Title"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
              </div>
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Description</label>
              <textarea
                name="description"
                rows="4"
                placeholder="Brief description about yourself..."
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"><%= Map.get(@content, "description", "") %></textarea>
            </div>

            <!-- Video Introduction Section -->
            <div class="border-t pt-6">
              <div class="flex items-center justify-between mb-4">
                <div>
                  <h4 class="text-lg font-medium text-gray-900">Video Introduction</h4>
                  <p class="text-sm text-gray-600">Add a personal video to your hero section</p>
                </div>
                <div class="flex items-center space-x-2">
                  <span class="text-xs text-gray-500">
                    <%= case Map.get(assigns, :current_user, %{}) |> Map.get(:subscription_tier, "free") do %>
                      <% "free" -> %>Max: 1 minute
                      <% "pro" -> %>Max: 2 minutes
                      <% "premium" -> %>Max: 5 minutes
                      <% _ -> %>Max: 1 minute
                    <% end %>
                  </span>
                </div>
              </div>

              <!-- Video Options -->
              <div class="space-y-4">
                <!-- Video Type Selection -->
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-2">Video Type</label>
                  <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
                    <%= for {type, label, description} <- [
                      {"none", "No Video", "Text-only hero section"},
                      {"background", "Background Video", "Video plays behind text"},
                      {"introduction", "Video Introduction", "Dedicated video intro"}
                    ] do %>
                      <label class="relative">
                        <input
                          type="radio"
                          name="video_type"
                          value={type}
                          checked={Map.get(@content, "video_type", "none") == type}
                          class="sr-only peer">
                        <div class="p-4 border-2 border-gray-200 rounded-lg cursor-pointer peer-checked:border-blue-500 peer-checked:bg-blue-50 hover:border-gray-300 transition-colors">
                          <div class="font-medium text-gray-900"><%= label %></div>
                          <div class="text-sm text-gray-600 mt-1"><%= description %></div>
                        </div>
                      </label>
                    <% end %>
                  </div>
                </div>

                <!-- Video Upload/Record Options (show when video type is selected) -->
                <%= if Map.get(@content, "video_type", "none") != "none" do %>
                  <div class="bg-gray-50 p-4 rounded-lg">
                    <div class="flex items-center justify-between mb-3">
                      <h5 class="font-medium text-gray-900">Video Source</h5>
                      <%= if Map.get(@content, "video_url") do %>
                        <span class="text-sm text-green-600 flex items-center">
                          <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                          </svg>
                          Video configured
                        </span>
                      <% end %>
                    </div>

                    <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
                      <!-- Record New Video -->
                      <button
                        type="button"
                        phx-click="start_hero_video_recording"
                        class="p-4 border-2 border-dashed border-gray-300 rounded-lg hover:border-purple-400 hover:bg-purple-50 transition-colors text-center group">
                        <svg class="w-8 h-8 text-gray-400 group-hover:text-purple-600 mx-auto mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
                        </svg>
                        <div class="text-sm font-medium text-gray-900 group-hover:text-purple-900">Record Video</div>
                        <div class="text-xs text-gray-600 group-hover:text-purple-700">Use your camera</div>
                      </button>

                      <!-- Upload Video -->
                      <button
                        type="button"
                        phx-click="show_hero_video_uploader"
                        class="p-4 border-2 border-dashed border-gray-300 rounded-lg hover:border-blue-400 hover:bg-blue-50 transition-colors text-center group">
                        <svg class="w-8 h-8 text-gray-400 group-hover:text-blue-600 mx-auto mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/>
                        </svg>
                        <div class="text-sm font-medium text-gray-900 group-hover:text-blue-900">Upload Video</div>
                        <div class="text-xs text-gray-600 group-hover:text-blue-700">From your device</div>
                      </button>
                    </div>

                    <!-- Current Video Preview -->
                    <%= if Map.get(@content, "video_url") do %>
                      <div class="mt-4 p-3 bg-white rounded-lg border">
                        <div class="flex items-center justify-between">
                          <div class="flex items-center space-x-3">
                            <video class="w-16 h-12 object-cover rounded" controls>
                              <source src={Map.get(@content, "video_url")} type="video/webm">
                              <source src={Map.get(@content, "video_url")} type="video/mp4">
                            </video>
                            <div>
                              <div class="text-sm font-medium text-gray-900">Current Video</div>
                              <div class="text-xs text-gray-600">
                                Duration: <%= Map.get(@content, "video_duration", "Unknown") %>
                              </div>
                            </div>
                          </div>
                          <button
                            type="button"
                            phx-click="remove_hero_video"
                            class="text-red-600 hover:text-red-700 text-sm">
                            Remove
                          </button>
                        </div>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>
            </div>

            <!-- Call to Action -->
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">CTA Button Text</label>
                <input
                  type="text"
                  name="cta_text"
                  value={Map.get(@content, "cta_text", "")}
                  placeholder="Get In Touch"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">CTA Button Link</label>
                <input
                  type="url"
                  name="cta_link"
                  value={Map.get(@content, "cta_link", "")}
                  placeholder="https://example.com/contact"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
              </div>
            </div>

            <!-- Section Visibility -->
            <div class="flex items-center">
              <input
                type="checkbox"
                id="hero_section_visible"
                name="visible"
                value="true"
                checked={assigns.editing_section.visible}
                class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded">
              <label for="hero_section_visible" class="ml-2 block text-sm text-gray-900">
                Show this section on portfolio
              </label>
            </div>

            <!-- Modal Actions -->
            <div class="flex items-center justify-end space-x-3 pt-6 border-t border-gray-200">
              <button
                type="button"
                phx-click="close_section_modal"
                class="px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50 transition-colors">
                Cancel
              </button>
              <button
                type="submit"
                class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors">
                Save Hero Section
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  def render_section_modal(assigns) do
    ~H"""
    <%= case normalize_section_type(@editing_section.section_type) do %>
      <% :code_showcase -> %>
        <.live_component
          module={FrestylWeb.PortfolioLive.Components.CodeShowcaseModalComponent}
          {Map.merge(assigns, %{id: "code-showcase-modal"})}
        />
      <% :media_showcase -> %>
        <.live_component
          module={FrestylWeb.PortfolioLive.Components.MediaShowcaseModalComponent}
          {Map.merge(assigns, %{id: "media-showcase-modal"})}
        />
      <% :experience -> %>
        <.live_component
          module={FrestylWeb.PortfolioLive.Components.ExperienceModalComponent}
          {Map.merge(assigns, %{id: "experience-modal"})}
        />
      <% :skills -> %>
        <.live_component
          module={FrestylWeb.PortfolioLive.Components.SkillsModalComponent}
          {Map.merge(assigns, %{id: "skills-modal"})}
        />
      <% :projects -> %>
        <.live_component
          module={FrestylWeb.PortfolioLive.Components.ProjectsModalComponent}
          {Map.merge(assigns, %{id: "projects-modal"})}
        />
      <% :testimonials -> %>
        <.live_component
          module={FrestylWeb.PortfolioLive.Components.TestimonialsModalComponent}
          {Map.merge(assigns, %{id: "testimonials-modal"})}
        />
      <% :hero -> %>
        <.live_component
          module={FrestylWeb.PortfolioLive.Components.HeroAboutModalComponent}
          {Map.merge(assigns, %{id: "hero-modal"})}
        />
      <% :about -> %>
        <.live_component
          module={FrestylWeb.PortfolioLive.Components.HeroAboutModalComponent}
          {Map.merge(assigns, %{id: "about-modal"})}
        />
      <% :contact -> %>
        <.live_component
          module={FrestylWeb.PortfolioLive.Components.ContactModalComponent}
          {Map.merge(assigns, %{id: "contact-modal"})}
        />
      <% :published_articles -> %>
        <.live_component
          module={FrestylWeb.PortfolioLive.Components.PublishedArticlesModalComponent}
          {Map.merge(assigns, %{id: "published-articles-modal"})}
        />
      <% :collaborations -> %>
        <.live_component
          module={FrestylWeb.PortfolioLive.Components.CollaborationsModalComponent}
          {Map.merge(assigns, %{id: "collaborations-modal"})}
        />
      <% :certifications -> %>
        <.live_component
          module={FrestylWeb.PortfolioLive.Components.CertificationsModalComponent}
          {Map.merge(assigns, %{id: "certifications-modal"})}
        />
      <% :achievements -> %>
        <.live_component
          module={FrestylWeb.PortfolioLive.Components.AchievementsModalComponent}
          {Map.merge(assigns, %{id: "achievements-modal"})}
        />
      <% :services -> %>
        <.live_component
          module={FrestylWeb.PortfolioLive.Components.ServicesModalComponent}
          {Map.merge(assigns, %{id: "services-modal"})}
        />
      <% :education -> %>
        <.live_component
          module={FrestylWeb.PortfolioLive.Components.EducationModalComponent}
          {Map.merge(assigns, %{id: "education-modal"})}
        />
      <% :custom -> %>
        <.live_component
          module={FrestylWeb.PortfolioLive.Components.CustomModalComponent}
          {Map.merge(assigns, %{id: "custom-modal"})}
        />
      <% _ -> %>
        <%= render_standard_section_modal(assigns) %>
    <% end %>
    """
  end

  def render_section_creation_modal(assigns) do
    professional_type = get_current_professional_type(assigns.customization)
    {suggested_sections, all_sections} = get_sections_for_professional_type(professional_type)

    ~H"""
    <div class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50">
      <div class="relative top-8 mx-auto p-5 border max-w-3xl shadow-lg rounded-xl bg-white mb-8">

        <!-- Modal Header -->
        <div class="flex items-center justify-between p-6 border-b border-gray-200">
          <div>
            <h3 class="text-xl font-bold text-gray-900">Add New Section</h3>
            <p class="text-gray-600">Choose any section type for your portfolio</p>
          </div>
          <button phx-click="close_section_creation_modal" class="text-gray-400 hover:text-gray-600">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </button>
        </div>

        <!-- Section Selection -->
        <div class="p-6 space-y-6">

          <!-- Suggested for Your Profession -->
          <div>
            <h4 class="text-lg font-semibold text-gray-900 mb-3 flex items-center">
              <span class="w-2 h-2 bg-blue-500 rounded-full mr-2"></span>
              Suggested for <%= String.capitalize(professional_type) %>
            </h4>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
              <%= for {section_id, name, category, icon} <- suggested_sections do %>
                <button
                  phx-click="create_section"
                  phx-value-section_type={section_id}
                  class="flex items-center p-4 border-2 border-blue-200 bg-blue-50 rounded-lg hover:border-blue-300 hover:bg-blue-100 transition-colors text-left">
                  <span class="text-2xl mr-3"><%= icon %></span>
                  <div>
                    <div class="font-medium text-gray-900"><%= name %></div>
                    <div class="text-sm text-blue-600"><%= category %></div>
                  </div>
                </button>
              <% end %>
            </div>
          </div>

          <!-- All Available Sections -->
          <div>
            <h4 class="text-lg font-semibold text-gray-900 mb-3 flex items-center">
              <span class="w-2 h-2 bg-gray-400 rounded-full mr-2"></span>
              All Available Sections
            </h4>
            <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
              <%= for {section_id, name, category, icon} <- all_sections do %>
                <button
                  phx-click="create_section"
                  phx-value-section_type={section_id}
                  class="flex items-center p-3 border border-gray-200 rounded-lg hover:border-gray-300 hover:bg-gray-50 transition-colors text-left">
                  <span class="text-xl mr-3"><%= icon %></span>
                  <div>
                    <div class="font-medium text-gray-900 text-sm"><%= name %></div>
                    <div class="text-xs text-gray-500"><%= category %></div>
                  </div>
                </button>
              <% end %>
            </div>
          </div>

          <!-- Custom Section Builder -->
          <div class="border-t pt-6">
            <h4 class="text-lg font-semibold text-gray-900 mb-3 flex items-center">
              <span class="w-2 h-2 bg-green-500 rounded-full mr-2"></span>
              Create Custom Section
            </h4>
            <div class="bg-green-50 border border-green-200 rounded-lg p-4">
              <p class="text-sm text-green-700 mb-3">
                Create a completely custom section with your own content and layout.
              </p>
              <button
                phx-click="create_section"
                phx-value-section_type="custom"
                class="flex items-center px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors">
                <span class="text-xl mr-2">⚙️</span>
                Create Custom Section
              </button>
            </div>
          </div>

        </div>
      </div>
    </div>
    """
  end

  def render_standard_section_modal(assigns) do
    ~H"""
    <div class="flex items-center justify-between p-6 border-b border-gray-200">
      <h3 class="text-lg font-bold text-gray-900">
        Edit <%= Map.get(assigns, :editing_section, %{}) |> Map.get(:title, "Section") %>
      </h3>
      <button
        phx-click="close_section_modal"
        class="text-gray-400 hover:text-gray-600">
        <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
        </svg>
      </button>
    </div>

    <div class="p-6 overflow-y-auto max-h-[calc(90vh-140px)]">
      <%= if Map.get(assigns, :editing_section) do %>
        <form phx-submit="save_section" class="space-y-6">
          <input type="hidden" name="section_id" value={assigns.editing_section.id} />

          <!-- Section Title -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Section Title</label>
            <input
              type="text"
              name="title"
              value={assigns.editing_section.title}
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
          </div>

          <!-- Section Visibility -->
          <div class="flex items-center">
            <input
              type="checkbox"
              id="section_visible"
              name="visible"
              value="true"
              checked={assigns.editing_section.visible}
              class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded">
            <label for="section_visible" class="ml-2 block text-sm text-gray-900">
              Show this section on portfolio
            </label>
          </div>

          <!-- Basic content field for now -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Content</label>
            <textarea
              name="content"
              rows="8"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              placeholder="Add your content here..."><%= get_section_content_safe(assigns.editing_section) %></textarea>
          </div>

          <!-- Modal Actions -->
          <div class="flex items-center justify-end space-x-3 pt-6 border-t border-gray-200">
            <button
              type="button"
              phx-click="close_section_modal"
              class="px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50 transition-colors">
              Cancel
            </button>
            <button
              type="submit"
              class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors">
              Save Section
            </button>
          </div>
        </form>
      <% end %>
    </div>
    """
  end

  defp render_hero_section_form(assigns) do
    content = get_section_content_map(assigns.editing_section)

    ~H"""
    <div class="space-y-6">
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Headline</label>
          <input type="text" name="headline" value={Map.get(content, "headline", "")}
                placeholder="Your Name Here"
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500" />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Tagline</label>
          <input type="text" name="tagline" value={Map.get(content, "tagline", "")}
                placeholder="Professional Title"
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500" />
        </div>
      </div>

      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Description</label>
        <textarea name="description" rows="4"
                  placeholder="Brief description about yourself..."
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500"><%= Map.get(content, "description", "") %></textarea>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">CTA Button Text</label>
          <input type="text" name="cta_text" value={Map.get(content, "cta_text", "")}
                placeholder="Get In Touch"
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500" />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">CTA Button Link</label>
          <input type="text" name="cta_link" value={Map.get(content, "cta_link", "")}
                placeholder="#contact"
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500" />
        </div>
      </div>
    </div>
    """
  end

  defp render_about_section_form(assigns) do
    content = get_section_content_map(assigns.editing_section)

    ~H"""
    <div class="space-y-6">
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">About Content</label>
        <textarea name="content" rows="8"
                  placeholder="Tell your story..."
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500"><%= Map.get(content, "content", "") %></textarea>
      </div>

      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Profile Image URL</label>
        <input type="url" name="image_url" value={Map.get(content, "image_url", "")}
              placeholder="https://example.com/profile.jpg"
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500" />
      </div>
    </div>
    """
  end

  defp render_experience_section_form(assigns) do
    content = get_section_content_map(assigns.editing_section)
    assigns = assign(assigns, :items, Map.get(content, "items", []))

    ~H"""
    <div class="space-y-6">
      <div class="bg-blue-50 p-4 rounded-lg">
        <p class="text-sm text-blue-700">Add your work experience, internships, and professional history.</p>
      </div>

      <!-- Experience Items -->
      <div id="experience-items" class="space-y-4">
        <%= for {item, index} <- Enum.with_index(@items) do %>
          <div class="border border-gray-200 rounded-lg p-4 bg-gray-50">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Job Title</label>
                <input
                  type="text"
                  name={"items[#{index}][title]"}
                  value={Map.get(item, "title", "")}
                  placeholder="Software Engineer"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Company</label>
                <input
                  type="text"
                  name={"items[#{index}][company]"}
                  value={Map.get(item, "company", "")}
                  placeholder="Company Name"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
              </div>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mt-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Start Date</label>
                <input
                  type="month"
                  name={"items[#{index}][start_date]"}
                  value={Map.get(item, "start_date", "")}
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">End Date</label>
                <input
                  type="month"
                  name={"items[#{index}][end_date]"}
                  value={Map.get(item, "end_date", "")}
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
              </div>

              <div class="flex items-center pt-6">
                <input
                  type="checkbox"
                  id={"current_#{index}"}
                  name={"items[#{index}][current]"}
                  checked={Map.get(item, "current", false)}
                  class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded">
                <label for={"current_#{index}"} class="ml-2 block text-sm text-gray-900">
                  Current Position
                </label>
              </div>
            </div>

            <div class="mt-4">
              <label class="block text-sm font-medium text-gray-700 mb-1">Location</label>
              <input
                type="text"
                name={"items[#{index}][location]"}
                value={Map.get(item, "location", "")}
                placeholder="City, State or Remote"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
            </div>

            <div class="mt-4">
              <label class="block text-sm font-medium text-gray-700 mb-1">Responsibilities & Achievements</label>
              <textarea
                name={"items[#{index}][description]"}
                rows="4"
                placeholder="• Led a team of 5 developers&#10;• Increased system performance by 40%&#10;• Implemented new features using React and Node.js"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"><%= Map.get(item, "description", "") %></textarea>
            </div>

            <div class="mt-4 flex justify-end">
              <button
                type="button"
                phx-click="remove_section_item"
                phx-value-section_id={@editing_section.id}
                phx-value-item_index={index}
                class="text-red-600 hover:text-red-700 text-sm font-medium">
                Remove Experience
              </button>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Add Experience Button -->
      <button
        type="button"
        phx-click="add_section_item"
        phx-value-section_id={@editing_section.id}
        class="w-full border-2 border-dashed border-gray-300 rounded-lg p-6 text-gray-500 hover:border-gray-400 hover:text-gray-600 transition-colors">
        <svg class="w-6 h-6 mx-auto mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
        </svg>
        Add Work Experience
      </button>
    </div>
    """
  end

  defp render_education_section_form(assigns) do
    content = get_section_content_map(assigns.editing_section)
    assigns = assign(assigns, :items, Map.get(content, "items", []))

    ~H"""
    <div class="space-y-6">
      <div class="bg-indigo-50 p-4 rounded-lg">
        <p class="text-sm text-indigo-700">Add your educational background, degrees, and certifications.</p>
      </div>

      <!-- Education Items -->
      <div id="education-items" class="space-y-4">
        <%= for {item, index} <- Enum.with_index(@items) do %>
          <div class="border border-gray-200 rounded-lg p-4 bg-gray-50">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Degree/Certification</label>
                <input
                  type="text"
                  name={"items[#{index}][degree]"}
                  value={Map.get(item, "degree", "")}
                  placeholder="Bachelor of Science in Computer Science"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500" />
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Institution</label>
                <input
                  type="text"
                  name={"items[#{index}][institution]"}
                  value={Map.get(item, "institution", "")}
                  placeholder="University Name"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500" />
              </div>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mt-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Start Date</label>
                <input
                  type="month"
                  name={"items[#{index}][start_date]"}
                  value={Map.get(item, "start_date", "")}
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500" />
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">End Date</label>
                <input
                  type="month"
                  name={"items[#{index}][end_date]"}
                  value={Map.get(item, "end_date", "")}
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500" />
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">GPA (Optional)</label>
                <input
                  type="text"
                  name={"items[#{index}][gpa]"}
                  value={Map.get(item, "gpa", "")}
                  placeholder="3.8/4.0"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500" />
              </div>
            </div>

            <div class="mt-4">
              <label class="block text-sm font-medium text-gray-700 mb-1">Description (Optional)</label>
              <textarea
                name={"items[#{index}][description]"}
                rows="3"
                placeholder="Relevant coursework, honors, activities, or achievements..."
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"><%= Map.get(item, "description", "") %></textarea>
            </div>

            <div class="mt-4 flex justify-end">
              <button
                type="button"
                phx-click="remove_section_item"
                phx-value-section_id={@editing_section.id}
                phx-value-item_index={index}
                class="text-red-600 hover:text-red-700 text-sm font-medium">
                Remove Education
              </button>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Add Education Button -->
      <button
        type="button"
        phx-click="add_section_item"
        phx-value-section_id={@editing_section.id}
        class="w-full border-2 border-dashed border-gray-300 rounded-lg p-6 text-gray-500 hover:border-gray-400 hover:text-gray-600 transition-colors">
        <svg class="w-6 h-6 mx-auto mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
        </svg>
        Add Education
      </button>
    </div>
    """
  end

  defp render_skills_section_form(assigns) do
    content = get_section_content_map(assigns.editing_section)
    assigns = assign(assigns, :categories, Map.get(content, "categories", []))

    ~H"""
    <div class="space-y-6">
      <div class="bg-green-50 p-4 rounded-lg">
        <p class="text-sm text-green-700">Organize your skills into categories like "Technical Skills", "Soft Skills", etc.</p>
      </div>

      <!-- Skills Categories -->
      <div id="skills-categories" class="space-y-4">
        <%= for {category, index} <- Enum.with_index(@categories) do %>
          <div class="border border-gray-200 rounded-lg p-4 bg-gray-50">
            <div class="mb-4">
              <label class="block text-sm font-medium text-gray-700 mb-1">Category Name</label>
              <input
                type="text"
                name={"categories[#{index}][name]"}
                value={Map.get(category, "name", "")}
                placeholder="Technical Skills"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-green-500" />
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Skills (comma-separated)</label>
              <textarea
                name={"categories[#{index}][skills]"}
                rows="3"
                placeholder="JavaScript, React, Node.js, Python, PostgreSQL, AWS"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-green-500"><%= Enum.join(Map.get(category, "skills", []), ", ") %></textarea>
            </div>

            <div class="mt-4 flex justify-end">
              <button
                type="button"
                phx-click="remove_skills_category"
                phx-value-section_id={@editing_section.id}
                phx-value-category_index={index}
                class="text-red-600 hover:text-red-700 text-sm font-medium">
                Remove Category
              </button>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Add Category Button -->
      <button
        type="button"
        phx-click="add_skills_category"
        phx-value-section_id={@editing_section.id}
        class="w-full border-2 border-dashed border-gray-300 rounded-lg p-6 text-gray-500 hover:border-gray-400 hover:text-gray-600 transition-colors">
        <svg class="w-6 h-6 mx-auto mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
        </svg>
        Add Skills Category
      </button>
    </div>
    """
  end

  defp render_projects_section_form(assigns) do
    content = get_section_content_map(assigns.editing_section)
    assigns = assign(assigns, :items, Map.get(content, "items", []))

    ~H"""
    <div class="space-y-6">
      <div class="bg-purple-50 p-4 rounded-lg">
        <p class="text-sm text-purple-700">Showcase your best projects, case studies, and portfolio pieces.</p>
      </div>

      <!-- Project Items -->
      <div id="projects-items" class="space-y-4">
        <%= for {item, index} <- Enum.with_index(@items) do %>
          <div class="border border-gray-200 rounded-lg p-4 bg-gray-50">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Project Title</label>
                <input
                  type="text"
                  name={"items[#{index}][title]"}
                  value={Map.get(item, "title", "")}
                  placeholder="E-commerce Platform"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500" />
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Technologies Used</label>
                <input
                  type="text"
                  name={"items[#{index}][technologies]"}
                  value={Map.get(item, "technologies", "")}
                  placeholder="React, Node.js, PostgreSQL"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500" />
              </div>
            </div>

            <div class="mt-4">
              <label class="block text-sm font-medium text-gray-700 mb-1">Project Description</label>
              <textarea
                name={"items[#{index}][description]"}
                rows="4"
                placeholder="Describe the project, your role, key features, and impact..."
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500"><%= Map.get(item, "description", "") %></textarea>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Live Demo URL (Optional)</label>
                <input
                  type="url"
                  name={"items[#{index}][demo_url]"}
                  value={Map.get(item, "demo_url", "")}
                  placeholder="https://myproject.com"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500" />
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Source Code URL (Optional)</label>
                <input
                  type="url"
                  name={"items[#{index}][source_url]"}
                  value={Map.get(item, "source_url", "")}
                  placeholder="https://github.com/username/project"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500" />
              </div>
            </div>

            <div class="mt-4">
              <label class="block text-sm font-medium text-gray-700 mb-1">Project Image URL (Optional)</label>
              <input
                type="url"
                name={"items[#{index}][image_url]"}
                value={Map.get(item, "image_url", "")}
                placeholder="https://example.com/project-screenshot.jpg"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500" />
            </div>

            <div class="mt-4 flex justify-end">
              <button
                type="button"
                phx-click="remove_section_item"
                phx-value-section_id={@editing_section.id}
                phx-value-item_index={index}
                class="text-red-600 hover:text-red-700 text-sm font-medium">
                Remove Project
              </button>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Add Project Button -->
      <button
        type="button"
        phx-click="add_section_item"
        phx-value-section_id={@editing_section.id}
        class="w-full border-2 border-dashed border-gray-300 rounded-lg p-6 text-gray-500 hover:border-gray-400 hover:text-gray-600 transition-colors">
        <svg class="w-6 h-6 mx-auto mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
        </svg>
        Add Project
      </button>
    </div>
    """
  end

  defp render_testimonials_section_form(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Testimonials</label>
        <div class="text-sm text-gray-500 mb-4">
          Add client testimonials, recommendations, or reviews.
        </div>
        <div id="testimonials-items">
          <!-- Testimonials will be rendered here -->
        </div>
      </div>
    </div>
    """
  end

  defp render_contact_section_form(assigns) do
    content = get_section_content_map(assigns.editing_section)

    ~H"""
    <div class="space-y-6">
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Email</label>
          <input type="email" name="email" value={Map.get(content, "email", "")}
                placeholder="your@email.com"
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500" />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Phone</label>
          <input type="tel" name="phone" value={Map.get(content, "phone", "")}
                placeholder="+1 (555) 123-4567"
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500" />
        </div>
      </div>

      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Location</label>
        <input type="text" name="location" value={Map.get(content, "location", "")}
              placeholder="City, State"
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500" />
      </div>

      <div class="flex items-center">
        <input type="checkbox" name="contact_form_enabled"
              checked={Map.get(content, "contact_form_enabled", false)}
              class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded" />
        <label class="ml-2 block text-sm text-gray-700">
          Enable contact form
        </label>
      </div>
    </div>
    """
  end

  defp render_custom_section_form(assigns) do
    content = get_section_content_map(assigns.editing_section)

    ~H"""
    <div class="space-y-6">
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Custom Content</label>
        <textarea name="content" rows="8"
                  placeholder="Add your custom content here..."
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500"><%= Map.get(content, "content", "") %></textarea>
      </div>

      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Layout Type</label>
        <select name="layout_type" class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500">
          <option value="text" selected={Map.get(content, "layout_type") == "text"}>Text Only</option>
          <option value="image_text" selected={Map.get(content, "layout_type") == "image_text"}>Image + Text</option>
          <option value="video" selected={Map.get(content, "layout_type") == "video"}>Video</option>
          <option value="embed" selected={Map.get(content, "layout_type") == "embed"}>Embed Code</option>
        </select>
      </div>
    </div>
    """
  end

  defp render_published_articles_section_form(assigns) do
    content = get_section_content_map(assigns.editing_section)

    ~H"""
    <div class="space-y-6">
      <!-- Section Title -->
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Section Title</label>
        <input
          type="text"
          name="headline"
          value={Map.get(content, "headline", "")}
          placeholder="Published Articles"
          class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500" />
      </div>

      <!-- Settings -->
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Display Style</label>
          <select name="display_style" class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500">
            <option value="grid" selected={Map.get(content, "display_style") == "grid"}>Grid Layout</option>
            <option value="list" selected={Map.get(content, "display_style") == "list"}>List Layout</option>
            <option value="featured" selected={Map.get(content, "display_style") == "featured"}>Featured Layout</option>
          </select>
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Max Articles</label>
          <input
            type="number"
            name="max_articles"
            value={Map.get(content, "max_articles", 12)}
            min="1"
            max="50"
            class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500" />
        </div>
      </div>

      <!-- Toggles -->
      <div class="space-y-3">
        <div class="flex items-center">
          <input
            type="checkbox"
            id="show_metrics"
            name="show_metrics"
            checked={Map.get(content, "show_metrics", true)}
            class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded">
          <label for="show_metrics" class="ml-2 block text-sm text-gray-900">
            Show article metrics (views, engagement, revenue)
          </label>
        </div>

        <div class="flex items-center">
          <input
            type="checkbox"
            id="show_collaboration_details"
            name="show_collaboration_details"
            checked={Map.get(content, "show_collaboration_details", false)}
            class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded">
          <label for="show_collaboration_details" class="ml-2 block text-sm text-gray-900">
            Show collaboration details and contributor percentages
          </label>
        </div>
      </div>
    </div>
    """
  end

  defp render_standard_section_form(assigns) do
    ~H"""
    <div class="space-y-4">
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Section Title</label>
        <input type="text" name="title" value={@editing_section.title}
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500" />
      </div>

      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Content</label>
        <textarea name="main_content" rows="8"
                  placeholder="Add your content here..."
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500"><%= get_section_content(@editing_section) %></textarea>
      </div>
    </div>
    """
  end

  # Helper function to get section content as map
  defp get_section_content_map(section) do
    case section.content do
      content when is_map(content) -> content
      content when is_binary(content) -> Jason.decode!(content)
      _ -> %{}
    end
  rescue
    _ -> %{}
  end

  # Helper function to get section content as string
  defp get_section_content(section) do
    case section.content do
      content when is_binary(content) -> content
      content when is_map(content) -> Map.get(content, "content", "")
      _ -> ""
    end
  end

  defp get_hero_style_description(style) do
    case style do
      "gradient" -> "Colorful background gradients"
      "image" -> "Background image with overlay"
      "video" -> "Background video integration"
      "minimal" -> "Clean and simple design"
      _ -> "Standard styling"
    end
  end

  defp render_section_preview(section) do
    content = section.content || %{}

    case section.section_type do
      "hero" ->
        headline = Map.get(content, "headline", "")
        tagline = Map.get(content, "tagline", "")

        if String.length(headline) > 0 do
          "#{headline}" <> if String.length(tagline) > 0, do: " • #{tagline}", else: ""
        else
          "No headline set"
        end

      "about" ->
        about_content = Map.get(content, "content", "")
        if String.length(about_content) > 0 do
          String.slice(about_content, 0, 100) <> if String.length(about_content) > 100, do: "...", else: ""
        else
          "No content added yet"
        end

      "custom" ->
        title = Map.get(content, "title", "")
        layout_type = Map.get(content, "layout_type", "text")

        if String.length(title) > 0 do
          "#{title} (#{String.capitalize(layout_type)} layout)"
        else
          "#{String.capitalize(layout_type)} layout • No title set"
        end

      _ ->
        items = Map.get(content, "items", [])
        "#{length(items)} items configured"
    end
  end

  defp format_content_with_paragraphs(content) when is_binary(content) do
    content
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&("<p class=\"mb-4\">#{&1}</p>"))
    |> Enum.join("")
    |> raw()
  end
  defp format_content_with_paragraphs(_), do: ""

  def published_articles_section(assigns) do
    ~H"""
    <section class="py-12 bg-gray-50">
      <div class="max-w-6xl mx-auto px-4">
        <div class="text-center mb-8">
          <h2 class="text-3xl font-bold text-gray-900 mb-4">
            <%= @section.content["headline"] %>
          </h2>
          <%= if @section.content["subtitle"] do %>
            <p class="text-lg text-gray-600 max-w-2xl mx-auto">
              <%= @section.content["subtitle"] %>
            </p>
          <% end %>
        </div>

        <!-- Platform Filter -->
        <%= if length(@available_platforms) > 1 do %>
          <div class="flex justify-center mb-8">
            <div class="flex space-x-2 bg-white rounded-lg p-1 border border-gray-200">
              <button class="px-4 py-2 rounded-md bg-indigo-100 text-indigo-700 font-medium">All</button>
              <%= for platform <- @available_platforms do %>
                <button class="px-4 py-2 rounded-md text-gray-600 hover:bg-gray-100 transition-colors">
                  <%= String.capitalize(platform) %>
                </button>
              <% end %>
            </div>
          </div>
        <% end %>

        <!-- Articles Grid -->
        <div class={"grid gap-6 #{grid_class(@section.content["display_style"])}"}>
          <%= for article <- @articles do %>
            <article class="bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden hover:shadow-md transition-shadow">
              <!-- Article Header -->
              <div class="p-6">
                <div class="flex items-start justify-between mb-3">
                  <h3 class="text-xl font-semibold text-gray-900 mb-2 line-clamp-2">
                    <a href={article.external_url} target="_blank" class="hover:text-indigo-600 transition-colors">
                      <%= article.document.title %>
                    </a>
                  </h3>
                  <span class={"px-2 py-1 text-xs rounded-full #{platform_badge_class(article.platform)}"}>
                    <%= String.capitalize(article.platform) %>
                  </span>
                </div>

                <!-- Article Excerpt -->
                <%= if article.document.metadata["excerpt"] do %>
                  <p class="text-gray-600 mb-4 line-clamp-3">
                    <%= article.document.metadata["excerpt"] %>
                  </p>
                <% end %>

                <!-- Collaboration Info -->
                <%= if @section.content["show_collaboration_details"] and has_collaborators?(article) do %>
                  <div class="flex items-center space-x-4 mb-4 text-sm text-gray-500">
                    <div class="flex items-center">
                      <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.196-2.121M9 4a3 3 0 11-6 0 3 3 0 016 0zM19 4a3 3 0 11-6 0 3 3 0 016 0zM5 20h5v-2a3 3 0 00-5.196-2.121M17 4a3 3 0 11-6 0 3 3 0 016 0z"/>
                      </svg>
                      <%= get_contributor_count(article) %> contributors
                    </div>
                    <div>Your contribution: <%= get_user_contribution_percentage(article, @current_user) %>%</div>
                  </div>
                <% end %>

                <!-- Metrics -->
                <%= if @section.content["show_metrics"] and article.platform_metrics do %>
                  <div class="flex items-center justify-between text-sm">
                    <div class="flex space-x-4 text-gray-500">
                      <%= if article.platform_metrics["views"] do %>
                        <span class="flex items-center">
                          <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
                          </svg>
                          <%= format_number(article.platform_metrics["views"]) %> views
                        </span>
                      <% end %>

                      <%= if article.platform_metrics["engagement"] do %>
                        <span class="flex items-center">
                          <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z"/>
                          </svg>
                          <%= format_number(article.platform_metrics["engagement"]) %>
                        </span>
                      <% end %>

                      <%= if article.revenue_attribution && article.revenue_attribution > 0 do %>
                        <span class="flex items-center text-green-600">
                          <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1"/>
                          </svg>
                          $<%= :erlang.float_to_binary(Decimal.to_float(article.revenue_attribution), decimals: 2) %>
                        </span>
                      <% end %>
                    </div>

                    <time class="text-gray-400" datetime={article.syndicated_at}>
                      <%= Calendar.strftime(article.syndicated_at, "%b %d, %Y") %>
                    </time>
                  </div>
                <% end %>
              </div>

              <!-- Article Footer -->
              <div class="px-6 py-3 bg-gray-50 border-t border-gray-200">
                <div class="flex items-center justify-between">
                  <div class="flex items-center space-x-2 text-sm text-gray-500">
                    <%= if article.document.metadata["read_time"] do %>
                      <span><%= article.document.metadata["read_time"] %> min read</span>
                      <span>•</span>
                    <% end %>
                    <span><%= count_words(article.document) %> words</span>
                  </div>

                  <div class="flex space-x-2">
                    <a
                      href={article.external_url}
                      target="_blank"
                      class="text-indigo-600 hover:text-indigo-800 text-sm font-medium"
                    >
                      Read on <%= String.capitalize(article.platform) %>
                      <svg class="w-3 h-3 inline ml-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/>
                      </svg>
                    </a>
                  </div>
                </div>
              </div>
            </article>
          <% end %>
        </div>

        <!-- Load More Button -->
        <%= if @has_more_articles do %>
          <div class="text-center mt-8">
            <button class="bg-white border border-gray-300 text-gray-700 px-6 py-3 rounded-lg hover:bg-gray-50 transition-colors">
              Load More Articles
            </button>
          </div>
        <% end %>
      </div>
    </section>
    """
  end

  defp grid_class("list"), do: "space-y-6"
  defp grid_class("featured"), do: "grid lg:grid-cols-3 gap-6"
  defp grid_class(_), do: "grid md:grid-cols-2 lg:grid-cols-3 gap-6"

  defp platform_badge_class("medium"), do: "bg-green-100 text-green-800"
  defp platform_badge_class("linkedin"), do: "bg-blue-100 text-blue-800"
  defp platform_badge_class("hashnode"), do: "bg-indigo-100 text-indigo-800"
  defp platform_badge_class(_), do: "bg-gray-100 text-gray-800"

  defp has_collaborators?(article) do
    case article.collaboration_revenue_splits do
      nil -> false
      splits when map_size(splits) > 1 -> true
      _ -> false
    end
  end

  defp get_contributor_count(article) do
    case article.collaboration_revenue_splits do
      nil -> 1
      splits -> map_size(splits)
    end
  end

  defp get_user_contribution_percentage(article, user) do
    case article.collaboration_revenue_splits do
      nil -> 100
      splits -> Map.get(splits, to_string(user.id), %{})["percentage"] || 0
    end
  end

  defp format_number(nil), do: "0"
  defp format_number(num) when num >= 1000, do: "#{Float.round(num/1000, 1)}k"
  defp format_number(num), do: Integer.to_string(num)

  defp count_words(document) do
    # Count words across all text blocks
    document.blocks
    |> Enum.filter(&(&1.block_type == :text))
    |> Enum.map(fn block ->
      text = get_in(block.content_data, ["text"]) || ""
      String.split(text, ~r/\s+/) |> length()
    end)
    |> Enum.sum()
  end

  defp render_hero_form_fields(assigns) do
    assigns = assign(assigns, :content, assigns.section.content || %{})

    ~H"""
    <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Headline</label>
        <input
          type="text"
          name="headline"
          value={Map.get(@content, "headline", "")}
          class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-gray-500 focus:border-gray-500"
          placeholder="Your Name or Main Message" />
      </div>

      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Tagline</label>
        <input
          type="text"
          name="tagline"
          value={Map.get(@content, "tagline", "")}
          class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-gray-500 focus:border-gray-500"
          placeholder="Professional Title or Specialty" />
      </div>
    </div>

    <div>
      <label class="block text-sm font-medium text-gray-700 mb-2">Description</label>
      <textarea
        name="description"
        rows="3"
        class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-gray-500 focus:border-gray-500"
        placeholder="Brief introduction about yourself..."><%= Map.get(@content, "description", "") %></textarea>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Call-to-Action Text</label>
        <input
          type="text"
          name="cta_text"
          value={Map.get(@content, "cta_text", "")}
          class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-gray-500 focus:border-gray-500"
          placeholder="Get In Touch" />
      </div>

      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Call-to-Action Link</label>
        <input
          type="url"
          name="cta_link"
          value={Map.get(@content, "cta_link", "")}
          class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-gray-500 focus:border-gray-500"
          placeholder="https://example.com/contact" />
      </div>
    </div>
    """
  end

  defp render_about_form_fields(assigns) do
    assigns = assign(assigns, :content, assigns.section.content || %{})
    assigns = assign(assigns, :highlights_text, format_highlights_for_input(Map.get(assigns.content, "highlights", [])))

    ~H"""
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-2">About Content</label>
      <textarea
        name="content"
        rows="6"
        class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-gray-500 focus:border-gray-500"
        placeholder="Tell your story, background, and what makes you unique..."><%= Map.get(@content, "content", "") %></textarea>
    </div>

    <div>
      <label class="block text-sm font-medium text-gray-700 mb-2">Profile Image URL</label>
      <input
        type="url"
        name="image_url"
        value={Map.get(@content, "image_url", "")}
        class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-gray-500 focus:border-gray-500"
        placeholder="https://example.com/your-photo.jpg" />
    </div>

    <div>
      <label class="block text-sm font-medium text-gray-700 mb-2">Key Highlights</label>
      <textarea
        name="highlights"
        rows="3"
        class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-gray-500 focus:border-gray-500"
        placeholder="• 5+ years of experience in design&#10;• Award-winning creative work&#10;• Trusted by 50+ clients"><%= @highlights_text %></textarea>
      <div class="text-xs text-gray-500 mt-1">Enter each highlight on a new line starting with •</div>
    </div>
    """
  end

  defp render_custom_form_fields(assigns) do
    assigns = assign(assigns, :content, assigns.section.content || %{})
    assigns = assign(assigns, :layout_type, Map.get(assigns.content, "layout_type", "text"))

    ~H"""
    <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Custom Title</label>
        <input
          type="text"
          name="custom_title"
          value={Map.get(@content, "title", "")}
          class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-gray-500 focus:border-gray-500"
          placeholder="Section Title" />
      </div>

      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Layout Type</label>
        <select
          name="layout_type"
          class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-gray-500 focus:border-gray-500">
          <option value="text" selected={@layout_type == "text"}>Text Only</option>
          <option value="image_text" selected={@layout_type == "image_text"}>Image + Text</option>
          <option value="gallery" selected={@layout_type == "gallery"}>Image Gallery</option>
          <option value="video" selected={@layout_type == "video"}>Video</option>
          <option value="embed" selected={@layout_type == "embed"}>Embed Code</option>
        </select>
      </div>
    </div>

    <div>
      <label class="block text-sm font-medium text-gray-700 mb-2">Content</label>
      <textarea
        name="content"
        rows="6"
        class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-gray-500 focus:border-gray-500"
        placeholder="Add your custom content here..."><%= Map.get(@content, "content", "") %></textarea>
    </div>

    <%= if @layout_type == "video" do %>
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Video URL</label>
        <input
          type="url"
          name="video_url"
          value={Map.get(@content, "video_url", "")}
          class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-gray-500 focus:border-gray-500"
          placeholder="https://youtube.com/watch?v=..." />
      </div>
    <% end %>

    <%= if @layout_type == "embed" do %>
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Embed Code</label>
        <textarea
          name="embed_code"
          rows="4"
          class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-gray-500 focus:border-gray-500 font-mono text-sm"
          placeholder='<iframe src="..." width="100%" height="400"></iframe>'><%= Map.get(@content, "embed_code", "") %></textarea>
      </div>
    <% end %>

    <!-- Styling Options -->
    <div class="border-t border-gray-200 pt-6">
      <h4 class="text-sm font-medium text-gray-900 mb-4">Styling Options</h4>

      <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Background Color</label>
          <input
            type="color"
            name="background_color"
            value={Map.get(@content, "background_color", "#ffffff")}
            class="w-full h-10 border border-gray-300 rounded-lg cursor-pointer">
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Text Color</label>
          <input
            type="color"
            name="text_color"
            value={Map.get(@content, "text_color", "#000000")}
            class="w-full h-10 border border-gray-300 rounded-lg cursor-pointer">
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Padding</label>
          <select
            name="padding"
            class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-gray-500 focus:border-gray-500">
            <option value="compact" selected={Map.get(@content, "padding") == "compact"}>Compact</option>
            <option value="normal" selected={Map.get(@content, "padding") == "normal"}>Normal</option>
            <option value="spacious" selected={Map.get(@content, "padding") == "spacious"}>Spacious</option>
          </select>
        </div>
      </div>

      <div class="mt-4">
        <div class="flex items-center">
          <input
            type="checkbox"
            id="show_border"
            name="show_border"
            value="true"
            checked={Map.get(@content, "show_border", false)}
            class="h-4 w-4 text-gray-600 focus:ring-gray-500 border-gray-300 rounded">
          <label for="show_border" class="ml-2 block text-sm text-gray-900">
            Show section border
          </label>
        </div>
      </div>

      <div class="mt-4">
        <label class="block text-sm font-medium text-gray-700 mb-2">Custom CSS</label>
        <textarea
          name="custom_css"
          rows="3"
          class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-gray-500 focus:border-gray-500 font-mono text-sm"
          placeholder="/* Add custom CSS for this section */"
        ><%= Map.get(@content, "custom_css", "") %></textarea>
      </div>
    </div>
    """
  end

  defp render_default_form_fields(assigns) do
    assigns = assign(assigns, :content, assigns.section.content || %{})
    assigns = assign(assigns, :items, Map.get(assigns.content, "items", []))
    assigns = assign(assigns, :is_list_section, assigns.section.section_type in ["experience", "skills", "projects", "testimonials"])

    ~H"""
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-2">Content</label>
      <textarea
        name="content"
        rows="6"
        class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-gray-500 focus:border-gray-500"
        placeholder="Add your content here..."><%= Map.get(@content, "content", "") %></textarea>
    </div>

    <!-- Dynamic item management for list-based sections -->
    <%= if @is_list_section do %>
      <div class="border-t border-gray-200 pt-6">
        <div class="flex items-center justify-between mb-4">
          <h4 class="text-sm font-medium text-gray-900">
            <%= case @section.section_type do %>
              <% "experience" -> %> Work Experience Items
              <% "skills" -> %> Skill Categories
              <% "projects" -> %> Project Items
              <% "testimonials" -> %> Testimonial Items
              <% _ -> %> Items
            <% end %>
          </h4>
          <button
            type="button"
            phx-click="add_section_item"
            phx-value-section_id={@section.id}
            class="bg-gray-100 hover:bg-gray-200 text-gray-700 px-3 py-1 rounded-md text-sm font-medium">
            <svg class="w-4 h-4 mr-1 inline" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
            </svg>
            Add Item
          </button>
        </div>

        <!-- Items list would be rendered here -->
        <div class="space-y-3">
          <%= for {item, index} <- Enum.with_index(@items) do %>
            <div class="flex items-center space-x-3 p-3 bg-gray-50 rounded-lg">
              <div class="flex-1">
                <input
                  type="text"
                  name={"items[#{index}][title]"}
                  value={Map.get(item, "title", "")}
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-gray-500 focus:border-gray-500 text-sm"
                  placeholder="Item title..." />
              </div>
              <button
                type="button"
                phx-click="remove_section_item"
                phx-value-section_id={@section.id}
                phx-value-item_index={index}
                class="p-2 text-red-600 hover:text-red-700 hover:bg-red-50 rounded-md">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
                </svg>
              </button>
            </div>
          <% end %>
        </div>
      </div>
    <% end %>
    """
  end

  defp format_highlights_for_input(highlights) when is_list(highlights) do
    highlights
    |> Enum.map(&("• " <> &1))
    |> Enum.join("\n")
  end
  defp format_highlights_for_input(_), do: ""

  defp render_education_content(assigns) do
    assigns = assign(assigns, :items, Map.get(assigns.content, "items", []))

    ~H"""
    <%= if length(@items) > 0 do %>
      <div class="space-y-8">
        <%= for item <- @items do %>
          <div class="flex space-x-4">
            <div class="flex-shrink-0">
              <div class="w-12 h-12 bg-indigo-600 rounded-full flex items-center justify-center">
                <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.746 0 3.332.477 4.5 1.253v13C20.832 18.477 19.246 18 17.5 18c-1.746 0-3.332.477-4.5 1.253"/>
                </svg>
              </div>
            </div>
            <div class="flex-1">
              <h4 class="text-xl font-semibold text-gray-900">
                <%= Map.get(item, "degree", "Degree") %>
              </h4>
              <p class="text-indigo-600 font-medium">
                <%= Map.get(item, "institution", "Institution Name") %>
              </p>
              <p class="text-gray-600 text-sm mb-3">
                <%= Map.get(item, "duration", "Duration") %>
              </p>
              <%= if Map.get(item, "description") do %>
                <p class="text-gray-700">
                  <%= Map.get(item, "description") %>
                </p>
              <% end %>
              <%= if Map.get(item, "gpa") do %>
                <p class="text-gray-600 text-sm mt-2">
                  GPA: <%= Map.get(item, "gpa") %>
                </p>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    <% else %>
      <div class="text-center text-gray-500 py-12">
        <p>No education items added yet.</p>
      </div>
    <% end %>
    """
  end

  defp render_certifications_content(assigns) do
    assigns = assign(assigns, :items, Map.get(assigns.content, "items", []))

    ~H"""
    <%= if length(@items) > 0 do %>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <%= for item <- @items do %>
          <div class="bg-white rounded-lg p-6 shadow-sm border hover:shadow-md transition-shadow">
            <div class="flex items-start space-x-4">
              <div class="flex-shrink-0">
                <div class="w-12 h-12 bg-green-600 rounded-lg flex items-center justify-center">
                  <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4M7.835 4.697a3.42 3.42 0 001.946-.806 3.42 3.42 0 014.438 0 3.42 3.42 0 001.946.806 3.42 3.42 0 013.138 3.138 3.42 3.42 0 00.806 1.946 3.42 3.42 0 010 4.438 3.42 3.42 0 00-.806 1.946 3.42 3.42 0 01-3.138 3.138 3.42 3.42 0 00-1.946.806 3.42 3.42 0 01-4.438 0 3.42 3.42 0 00-1.946-.806 3.42 3.42 0 01-3.138-3.138 3.42 3.42 0 00-.806-1.946 3.42 3.42 0 010-4.438 3.42 3.42 0 00.806-1.946 3.42 3.42 0 013.138-3.138z"/>
                  </svg>
                </div>
              </div>
              <div class="flex-1">
                <h4 class="text-lg font-semibold text-gray-900">
                  <%= Map.get(item, "name", "Certification Name") %>
                </h4>
                <p class="text-green-600 font-medium">
                  <%= Map.get(item, "issuer", "Issuing Organization") %>
                </p>
                <p class="text-gray-600 text-sm mb-2">
                  Earned: <%= Map.get(item, "date", "Date") %>
                </p>
                <%= if Map.get(item, "expiry") do %>
                  <p class="text-gray-600 text-sm mb-2">
                    Expires: <%= Map.get(item, "expiry") %>
                  </p>
                <% end %>
                <%= if Map.get(item, "credential_id") do %>
                  <p class="text-gray-500 text-xs font-mono">
                    ID: <%= Map.get(item, "credential_id") %>
                  </p>
                <% end %>
                <%= if Map.get(item, "url") do %>
                  <a
                    href={Map.get(item, "url")}
                    target="_blank"
                    class="inline-flex items-center text-green-600 hover:text-green-700 font-medium text-sm mt-2">
                    Verify
                    <svg class="w-3 h-3 ml-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/>
                    </svg>
                  </a>
                <% end %>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    <% else %>
      <div class="text-center text-gray-500 py-12">
        <p>No certifications added yet.</p>
      </div>
    <% end %>
    """
  end

  defp render_achievements_content(assigns) do
    assigns = assign(assigns, :items, Map.get(assigns.content, "items", []))

    ~H"""
    <%= if length(@items) > 0 do %>
      <div class="space-y-6">
        <%= for item <- @items do %>
          <div class="bg-gradient-to-r from-yellow-50 to-orange-50 border border-yellow-200 rounded-xl p-6">
            <div class="flex items-start space-x-4">
              <div class="flex-shrink-0">
                <div class="w-12 h-12 bg-gradient-to-br from-yellow-500 to-orange-500 rounded-full flex items-center justify-center">
                  <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z"/>
                  </svg>
                </div>
              </div>
              <div class="flex-1">
                <h4 class="text-xl font-semibold text-gray-900 mb-2">
                  <%= Map.get(item, "title", "Achievement Title") %>
                </h4>
                <%= if Map.get(item, "organization") do %>
                  <p class="text-orange-600 font-medium mb-2">
                    <%= Map.get(item, "organization") %>
                  </p>
                <% end %>
                <%= if Map.get(item, "date") do %>
                  <p class="text-gray-600 text-sm mb-3">
                    <%= Map.get(item, "date") %>
                  </p>
                <% end %>
                <%= if Map.get(item, "description") do %>
                  <p class="text-gray-700">
                    <%= Map.get(item, "description") %>
                  </p>
                <% end %>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    <% else %>
      <div class="text-center text-gray-500 py-12">
        <p>No achievements added yet.</p>
      </div>
    <% end %>
    """
  end

  defp render_services_content(assigns) do
    assigns = assign(assigns, :items, Map.get(assigns.content, "items", []))

    ~H"""
    <%= if length(@items) > 0 do %>
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
        <%= for item <- @items do %>
          <div class="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden hover:shadow-lg transition-all group">
            <!-- Service Header -->
            <div class="bg-gradient-to-br from-purple-600 to-blue-600 p-6 text-white">
              <h4 class="text-xl font-semibold mb-2">
                <%= Map.get(item, "title", "Service Title") %>
              </h4>
              <%= if Map.get(item, "price") do %>
                <div class="text-2xl font-bold">
                  $<%= Map.get(item, "price") %>
                  <%= if Map.get(item, "price_type") do %>
                    <span class="text-sm font-normal opacity-90">/<%= Map.get(item, "price_type") %></span>
                  <% end %>
                </div>
              <% end %>
            </div>

            <!-- Service Content -->
            <div class="p-6">
              <%= if Map.get(item, "description") do %>
                <p class="text-gray-700 mb-4">
                  <%= Map.get(item, "description") %>
                </p>
              <% end %>

              <!-- Service Features -->
              <%= if Map.get(item, "features") do %>
                <ul class="space-y-2 mb-6">
                  <%= for feature <- String.split(Map.get(item, "features", ""), "\n") do %>
                    <%= if String.trim(feature) != "" do %>
                      <li class="flex items-center text-gray-700">
                        <svg class="w-4 h-4 text-green-500 mr-2 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                        </svg>
                        <%= String.trim(feature) %>
                      </li>
                    <% end %>
                  <% end %>
                </ul>
              <% end %>

              <!-- CTA Button -->
              <%= if Map.get(item, "booking_enabled") do %>
                <button class="w-full bg-purple-600 hover:bg-purple-700 text-white font-medium py-3 px-6 rounded-lg transition-colors">
                  Book Service
                </button>
              <% else %>
                <button class="w-full bg-gray-100 hover:bg-gray-200 text-gray-700 font-medium py-3 px-6 rounded-lg transition-colors">
                  Learn More
                </button>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    <% else %>
      <div class="text-center text-gray-500 py-12">
        <p>No services added yet.</p>
      </div>
    <% end %>
    """
  end

  defp render_blog_content(assigns) do
    assigns = assign(assigns, :items, Map.get(assigns.content, "items", []))

    ~H"""
    <%= if length(@items) > 0 do %>
      <div class="space-y-8">
        <%= for item <- @items do %>
          <article class="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden hover:shadow-md transition-shadow">
            <%= if Map.get(item, "featured_image") do %>
              <img
                src={Map.get(item, "featured_image")}
                alt={Map.get(item, "title", "Blog Post")}
                class="w-full h-48 object-cover" />
            <% end %>

            <div class="p-6">
              <div class="flex items-center space-x-4 mb-4">
                <%= if Map.get(item, "category") do %>
                  <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-blue-100 text-blue-800">
                    <%= Map.get(item, "category") %>
                  </span>
                <% end %>
                <%= if Map.get(item, "published_date") do %>
                  <span class="text-gray-500 text-sm">
                    <%= Map.get(item, "published_date") %>
                  </span>
                <% end %>
                <%= if Map.get(item, "read_time") do %>
                  <span class="text-gray-500 text-sm">
                    <%= Map.get(item, "read_time") %> min read
                  </span>
                <% end %>
              </div>

              <h4 class="text-xl font-semibold text-gray-900 mb-3">
                <%= Map.get(item, "title", "Blog Post Title") %>
              </h4>

              <%= if Map.get(item, "excerpt") do %>
                <p class="text-gray-700 mb-4">
                  <%= Map.get(item, "excerpt") %>
                </p>
              <% end %>

              <div class="flex items-center justify-between">
                <%= if Map.get(item, "author") do %>
                  <div class="flex items-center space-x-2">
                    <div class="w-8 h-8 bg-gray-300 rounded-full flex items-center justify-center">
                      <svg class="w-4 h-4 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
                      </svg>
                    </div>
                    <span class="text-sm text-gray-600">
                      <%= Map.get(item, "author") %>
                    </span>
                  </div>
                <% end %>

                <%= if Map.get(item, "url") do %>
                  <a
                    href={Map.get(item, "url")}
                    target="_blank"
                    class="inline-flex items-center text-blue-600 hover:text-blue-700 font-medium">
                    Read More
                    <svg class="w-4 h-4 ml-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/>
                    </svg>
                  </a>
                <% end %>
              </div>
            </div>
          </article>
        <% end %>
      </div>
    <% else %>
      <div class="text-center text-gray-500 py-12">
        <p>No blog posts added yet.</p>
      </div>
    <% end %>
    """
  end

  defp render_gallery_content(assigns) do
    assigns = assign(assigns, :images, Map.get(assigns.content, "images", []))
    assigns = assign(assigns, :layout_style, Map.get(assigns.content, "layout_style", "grid"))

    ~H"""
    <%= if length(@images) > 0 do %>
      <div class={[
        case @layout_style do
          "masonry" -> "columns-1 md:columns-2 lg:columns-3 gap-4 space-y-4"
          "carousel" -> "flex space-x-4 overflow-x-auto pb-4"
          _ -> "grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6"
        end
      ]}>
        <%= for {image, index} <- Enum.with_index(@images) do %>
          <div class={[
            "group cursor-pointer",
            if(@layout_style == "carousel", do: "flex-shrink-0 w-80", else: "")
          ]}>
            <div class="relative overflow-hidden rounded-lg shadow-md hover:shadow-lg transition-shadow">
              <img
                src={Map.get(image, "url", "")}
                alt={Map.get(image, "caption", "Gallery Image #{index + 1}")}
                class="w-full h-auto object-cover group-hover:scale-105 transition-transform duration-300" />

              <!-- Image Overlay -->
              <div class="absolute inset-0 bg-black bg-opacity-0 group-hover:bg-opacity-30 transition-all duration-300 flex items-center justify-center">
                <svg class="w-8 h-8 text-white opacity-0 group-hover:opacity-100 transition-opacity duration-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0zM10 7v3m0 0v3m0-3h3m-3 0H7"/>
                </svg>
              </div>
            </div>

            <%= if Map.get(image, "caption") do %>
              <p class="text-gray-600 text-sm mt-2 text-center">
                <%= Map.get(image, "caption") %>
              </p>
            <% end %>
          </div>
        <% end %>
      </div>
    <% else %>
      <div class="text-center text-gray-500 py-12">
        <div class="w-16 h-16 bg-gray-200 rounded-lg flex items-center justify-center mx-auto mb-4">
          <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
          </svg>
        </div>
        <p>No images added to gallery yet.</p>
      </div>
    <% end %>
    """
  end

  defp error_to_string(:too_large), do: "File is too large (max 5MB)"
  defp error_to_string(:too_many_files), do: "Only one file allowed"
  defp error_to_string(:not_accepted), do: "File type not supported"
  defp error_to_string(error), do: "Upload error: #{error}"

end
