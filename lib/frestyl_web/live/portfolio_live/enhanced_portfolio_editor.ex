# lib/frestyl_web/live/portfolio_live/enhanced_portfolio_editor.ex

defmodule FrestylWeb.PortfolioLive.EnhancedPortfolioEditor do
  @moduledoc """
  Enhanced Portfolio Editor LiveView - mobile-first design with dynamic sections
  """

  use FrestylWeb, :live_view

  alias Frestyl.Portfolios
  alias Frestyl.Portfolios.{Portfolio, EnhancedSectionSystem}
  alias Frestyl.Media
  alias Phoenix.PubSub
  alias FrestylWeb.PortfolioLive.EnhancedVideoIntroComponent

  alias FrestylWeb.PortfolioLive.Components.{
  DynamicSectionModal,
  EnhancedSectionRenderer,
  EnhancedLayoutRenderer,
  LayoutPickerComponent
}

@impl true
def mount(%{"id" => portfolio_id}, session, socket) do
  IO.puts("🔧 MOUNTING Enhanced Portfolio Editor for portfolio: #{portfolio_id}")

  # Subscribe to PubSub channels if connected
  if connected?(socket) do
    # ONLY subscribe to ONE channel to avoid loops
    PubSub.subscribe(Frestyl.PubSub, "portfolio_preview:#{portfolio_id}")
    IO.puts("🔧 Subscribed to: portfolio_preview:#{portfolio_id}")
  end

  # Get current user from session
  current_user = get_current_user_from_session(session)
  IO.puts("🔧 Current user: #{inspect(current_user && current_user.id)}")

  # Load portfolio and sections
  case load_portfolio_data(portfolio_id) do
    {:ok, portfolio, sections} ->
      IO.puts("🔧 Successfully loaded portfolio with #{length(sections)} sections")

      # Initialize socket with all required assigns
      socket = socket
        |> assign_core_data(current_user, portfolio, sections)
        |> assign_modal_states()
        |> assign_ui_states()
        |> assign_editor_states()
        |> assign(:video_tab, "record")  # Add video tab state

      {:ok, socket}

    {:error, reason} ->
      IO.puts("🔧 Failed to load portfolio: #{inspect(reason)}")

      {:ok, socket
        |> assign(:current_user, current_user)
        |> put_flash(:error, "Portfolio not found or access denied")
        |> redirect(to: ~p"/portfolios")}
  end
end

defp load_portfolio_data(portfolio_id) do
  case Portfolios.get_portfolio_with_sections(portfolio_id) do
    {:ok, %{} = portfolio_data} ->
      # Extract portfolio and sections from the loaded data
      portfolio = normalize_portfolio(portfolio_data)
      sections = extract_sections(portfolio_data)

      {:ok, portfolio, sections}

    {:error, _reason} = error ->
      error

    other ->
      IO.inspect(other, label: "🔧 Unexpected portfolio data structure")
      {:error, :invalid_structure}
  end
end

defp normalize_portfolio(portfolio_data) do
  # Ensure we have a proper portfolio struct/map
  case portfolio_data do
    %{id: _id} = portfolio ->
      portfolio
    %{"id" => _id} = portfolio ->
      portfolio
    _ ->
      IO.puts("🔧 Warning: Portfolio data missing ID field")
      portfolio_data
  end
end

defp extract_sections(portfolio_data) do
  # Try different ways to get sections
  sections = portfolio_data
    |> Map.get(:sections, [])
    |> case do
      [] -> Map.get(portfolio_data, "sections", [])
      sections -> sections
    end

  # Ensure sections is a list
  case sections do
    sections when is_list(sections) -> sections
    _ -> []
  end
end

defp assign_core_data(socket, current_user, portfolio, sections) do
  hero_section = find_hero_section(sections)
  customization = get_portfolio_customization(portfolio)

  socket
  |> assign(:current_user, current_user)
  |> assign(:portfolio, portfolio)
  |> assign(:sections, sections)
  |> assign(:hero_section, hero_section)
  |> assign(:customization, customization)
end

defp assign_modal_states(socket) do
  socket
  |> assign(:show_video_intro_modal, false)
  |> assign(:show_upload_option, false)
  |> assign(:show_video_preview_modal, false)
  |> assign(:show_section_modal, false)
  |> assign(:show_create_dropdown, false)
  |> assign(:show_resume_import_modal, false)
  |> assign(:video_tab, "record")
end

defp assign_ui_states(socket) do
  socket
  |> assign(:active_tab, "sections")
  |> assign(:preview_mode, :editor)
  |> assign(:preview_device, "desktop")
  |> assign(:current_section_type, nil)
  |> assign(:editing_section, nil)
end

defp assign_editor_states(socket) do
  socket
  |> assign(:editor_mode, :edit)
  |> assign(:autosave_enabled, true)
  |> assign(:last_saved, DateTime.utc_now())
end

  # Event Handlers
  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    IO.puts("🎯 SWITCH TAB CALLED with tab: #{tab}")
    IO.puts("🎯 CURRENT ACTIVE TAB: #{socket.assigns.active_tab}")

    # Only update if the tab is actually changing
    if socket.assigns.active_tab != tab do
      socket = socket
        |> assign(:active_tab, tab)
        |> assign(:tab_changed_at, System.system_time(:millisecond))  # Force re-render

      IO.puts("🎯 NEW ACTIVE TAB: #{socket.assigns.active_tab}")
      {:noreply, socket}
    else
      IO.puts("🎯 TAB UNCHANGED, NO RE-RENDER")
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => "design"}, socket) do
    IO.puts("🎨 Switching to design tab")
    {:noreply, assign(socket, :active_tab, "design")}
  end

  @impl true
  def handle_event("toggle_preview", _params, socket) do
    new_mode = if Map.get(socket.assigns, :preview_mode, :editor) == :split, do: :editor, else: :split
    {:noreply, assign(socket, :preview_mode, new_mode)}
  end

  @impl true
  def handle_event("toggle_create_dropdown", _params, socket) do
    current_state = Map.get(socket.assigns, :show_create_dropdown, false)
    {:noreply, assign(socket, :show_create_dropdown, !current_state)}
  end

  @impl true
  def handle_event("close_create_dropdown", _params, socket) do
    {:noreply, assign(socket, :show_create_dropdown, false)}
  end

  @impl true
  def handle_event("create_section", %{"section_type" => section_type}, socket) do
    IO.puts("🆕 CREATE SECTION: #{section_type}")

    section_attrs = %{
      portfolio_id: socket.assigns.portfolio.id,
      section_type: String.to_atom(section_type),
      title: generate_default_section_title(section_type),
      content: get_default_content_for_type(section_type),
      visible: true,
      position: length(socket.assigns.sections) + 1
    }

    case Portfolios.create_portfolio_section(section_attrs) do
      {:ok, new_section} ->
        IO.puts("✅ Section created: #{new_section.id}")
        updated_sections = socket.assigns.sections ++ [new_section]

        # Single broadcast
        broadcast_portfolio_update(
          socket.assigns.portfolio.id,
          updated_sections,
          socket.assigns.customization,
          :sections
        )

        {:noreply, socket
          |> assign(:sections, updated_sections)
          |> assign(:show_create_dropdown, false)
          |> put_flash(:info, "✅ #{section_type} section created!")}

      {:error, changeset} ->
        IO.puts("❌ Failed to create section: #{inspect(changeset.errors)}")
        {:noreply, put_flash(socket, :error, "Failed to create section")}
    end
  end

  defp create_section_with_modal(socket, params) do
    section_type = params["section_type"]
    title = params["title"]
    visible = params["visible"] == "true"

    # Extract content from form params
    content = extract_content_from_params(section_type, params)

    new_section = %{
      id: :rand.uniform(10000),
      title: title,
      section_type: String.to_atom(section_type),
      content: content,
      position: length(socket.assigns.sections) + 1,
      visible: visible
    }

    updated_sections = socket.assigns.sections ++ [new_section]

    {:noreply, socket
    |> assign(:sections, updated_sections)
    |> assign(:show_section_modal, false)
    |> assign(:current_section_type, nil)
    |> assign(:editing_section, nil)
    |> put_flash(:info, "Section created successfully!")}
  end

  @impl true
  def handle_event("edit_section", %{"section_id" => section_id}, socket) do
    section_id = String.to_integer(section_id)
    section = Enum.find(socket.assigns.sections, &(&1.id == section_id))

    if section do
      {:noreply, socket
        |> assign(:show_section_modal, true)
        |> assign(:current_section_type, to_string(section.section_type))
        |> assign(:editing_section, section)}
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  def handle_event("save_section", params, socket) do
    IO.puts("🔥 SAVE SECTION: #{inspect(params["action"])}")

    case params["action"] do
      "create" ->
        create_section_with_modal(socket, params)
      "update" ->
        update_section_with_validation(socket, params)
      _ ->
        {:noreply, put_flash(socket, :error, "Invalid section action")}
    end
  end

  @impl true
  def handle_event("show_create_dropdown", _params, socket) do
    {:noreply, assign(socket, :show_create_dropdown, true)}
  end

  @impl true
  def handle_event("close_create_dropdown", _params, socket) do
    {:noreply, assign(socket, :show_create_dropdown, false)}
  end

  @impl true
  def handle_event("toggle_section_visibility", %{"section_id" => section_id}, socket) do
    section_id = String.to_integer(section_id)
    IO.puts("🔄 TOGGLE SECTION VISIBILITY: #{section_id}")

    case Enum.find(socket.assigns.sections, &(&1.id == section_id)) do
      nil ->
        {:noreply, put_flash(socket, :error, "Section not found")}

      section ->
        new_visibility = !section.visible

        case Portfolios.update_portfolio_section(section, %{visible: new_visibility}) do
          {:ok, updated_section} ->
            updated_sections = update_section_in_list(socket.assigns.sections, updated_section)

            # Single broadcast
            broadcast_portfolio_update(
              socket.assigns.portfolio.id,
              updated_sections,
              socket.assigns.customization,
              :sections
            )

            {:noreply, socket
              |> assign(:sections, updated_sections)
              |> put_flash(:info, "Section #{if new_visibility, do: "shown", else: "hidden"}")}

          {:error, changeset} ->
            error_message = extract_changeset_errors(changeset) |> Enum.join(", ")
            {:noreply, put_flash(socket, :error, "Failed to update visibility: #{error_message}")}
        end
    end
  end

  @impl true
  def handle_event("edit_section", %{"section_id" => section_id}, socket) do
    section_id = String.to_integer(section_id)

    case Enum.find(socket.assigns.sections, &(&1.id == section_id)) do
      nil ->
        {:noreply, put_flash(socket, :error, "Section not found")}
      section ->
        {:noreply, socket
          |> assign(:show_section_modal, true)
          |> assign(:editing_section, section)
          |> assign(:current_section_type, to_string(section.section_type))
          |> assign(:section_changeset_errors, [])}
    end
  end

  @impl true
  def handle_event("delete_section", %{"section_id" => section_id}, socket) do
    section_id = String.to_integer(section_id)
    IO.puts("🔥 DELETE SECTION: #{section_id}")

    case Enum.find(socket.assigns.sections, &(&1.id == section_id)) do
      nil ->
        {:noreply, put_flash(socket, :error, "Section not found")}

      section ->
        case Portfolios.delete_portfolio_section(section) do
          {:ok, _} ->
            updated_sections = Enum.filter(socket.assigns.sections, &(&1.id != section_id))

            # Single broadcast
            broadcast_portfolio_update(
              socket.assigns.portfolio.id,
              updated_sections,
              socket.assigns.customization,
              :sections
            )

            {:noreply, socket
              |> assign(:sections, updated_sections)
              |> put_flash(:info, "Section deleted")}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to delete section")}
        end
    end
  end

  defp update_section_with_validation(socket, params) do
    section_id = params["section_id"] |> String.to_integer()

    IO.puts("🔧 UPDATING SECTION: id=#{section_id}")

    case Enum.find(socket.assigns.sections, &(&1.id == section_id)) do
      nil ->
        IO.puts("❌ Section not found: #{section_id}")
        {:noreply, put_flash(socket, :error, "Section not found")}

      section ->
        case build_section_update_attrs(params, section) do
          {:ok, update_attrs} ->
            IO.puts("🔧 UPDATE ATTRS: #{inspect(update_attrs)}")

            case Portfolios.update_portfolio_section(section, update_attrs) do
              {:ok, updated_section} ->
                IO.puts("✅ Section updated successfully")
                IO.puts("✅ Updated section content: #{inspect(updated_section.content)}")

                # Update sections list in socket
                updated_sections = update_section_in_list(socket.assigns.sections, updated_section)

                # Broadcast to ALL views with proper data format
                broadcast_portfolio_update(
                  socket.assigns.portfolio.id,
                  updated_sections,
                  socket.assigns.customization
                )

                # Update socket state
                new_socket = socket
                  |> assign(:sections, updated_sections)
                  |> assign(:show_section_modal, false)
                  |> assign(:editing_section, nil)
                  |> assign(:section_changeset_errors, [])
                  |> put_flash(:info, "✅ Section updated successfully!")

                IO.puts("✅ Socket and broadcasts complete")
                {:noreply, new_socket}

              {:error, changeset} ->
                IO.puts("❌ SECTION UPDATE FAILED: #{inspect(changeset.errors)}")
                error_messages = extract_changeset_errors(changeset)
                error_message = Enum.join(error_messages, ", ")

                {:noreply, socket
                  |> put_flash(:error, "Failed to update section: #{error_message}")
                  |> assign(:section_changeset_errors, changeset.errors)}
            end

          {:error, reason} ->
            IO.puts("❌ INVALID FORM DATA: #{reason}")
            {:noreply, put_flash(socket, :error, "Invalid form data: #{reason}")}
        end
    end
  end

  defp update_section_with_modal_fixed(socket, params) do
    section_id = String.to_integer(params["section_id"])
    title = params["title"]
    visible = params["visible"] == "true"

    IO.puts("🔧 UPDATING SECTION: id=#{section_id}, title=#{title}, visible=#{visible}")

    # Find the section
    section = Enum.find(socket.assigns.sections, &(&1.id == section_id))

    if section do
      content = extract_content_from_params(to_string(section.section_type), params)

      update_attrs = %{
        title: title,
        content: content,
        visible: visible
      }

      IO.puts("🔧 UPDATE ATTRS: #{inspect(update_attrs)}")

      # Use the CORRECT function name - check your Portfolios module
      case Portfolios.update_portfolio_section(section, update_attrs) do
        {:ok, updated_section} ->
          IO.puts("✅ SECTION UPDATED IN DATABASE")

          updated_sections = Enum.map(socket.assigns.sections, fn s ->
            if s.id == section_id, do: updated_section, else: s
          end)

          # Broadcast with COMPREHENSIVE data
          broadcast_portfolio_update(socket.assigns.portfolio.id, updated_sections, socket.assigns.customization)

          {:noreply, socket
          |> assign(:sections, updated_sections)
          |> assign(:show_section_modal, false)
          |> assign(:current_section_type, nil)
          |> assign(:editing_section, nil)
          |> put_flash(:info, "Section updated and saved successfully!")}

        {:error, changeset} ->
          IO.puts("❌ SECTION UPDATE FAILED: #{inspect(changeset.errors)}")
          {:noreply, put_flash(socket, :error, "Failed to save section: #{inspect(changeset.errors)}")}
      end
    else
      IO.puts("❌ SECTION NOT FOUND: #{section_id}")
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  defp build_section_update_attrs(params, section) do
    IO.puts("🔧 BUILDING UPDATE ATTRS")
    IO.puts("🔧 Section type: #{section.section_type}")

    # Extract basic fields
    title = params["title"] |> String.trim()
    visible = params["visible"] == "true"

    IO.puts("🔧 Title: '#{title}'")
    IO.puts("🔧 Visible: #{visible}")

    # Handle title validation
    final_title = case title do
      "" ->
        # Generate a default title based on section type if empty
        generate_default_section_title(section.section_type)
      title ->
        title
    end

    IO.puts("🔧 Final title: '#{final_title}'")

    # Build content based on section type
    case build_section_content(params, section.section_type) do
      {:ok, content} ->
        update_attrs = %{
          title: final_title,
          visible: visible,
          content: content
        }

        IO.puts("🔧 Built update attrs: #{inspect(update_attrs)}")
        {:ok, update_attrs}

      {:error, reason} ->
        {:error, reason}
    end
  end


  defp build_section_content(section_type, params) do
    IO.puts("🔧 BUILDING SECTION CONTENT: #{section_type}")
    IO.puts("🔧 PARAMS: #{inspect(params)}")

    case section_type do
      "experience" ->
        # Build experience content with backward compatibility
        jobs = extract_experience_items_from_params(params)
        %{
          "items" => jobs,
          "jobs" => jobs  # Keep backward compatibility
        }

      "projects" ->
        # Build projects content
        projects = extract_project_items_from_params(params)
        %{
          "items" => projects
        }

      "education" ->
        # Build education content
        education_items = extract_education_items_from_params(params)
        %{
          "items" => education_items
        }

      "skills" ->
        # Build skills content with categorization support
        skills_content = extract_skills_from_params(params)
        %{
          "skills" => Map.get(skills_content, "skills", []),
          "categories" => Map.get(skills_content, "categories", %{}),
          "display_style" => Map.get(skills_content, "display_style", "categorized"),
          "show_proficiency" => Map.get(skills_content, "show_proficiency", true)
        }

      "hero" ->
        # Build hero content
        %{
          "headline" => Map.get(params, "headline", ""),
          "tagline" => Map.get(params, "tagline", ""),
          "description" => Map.get(params, "description", ""),
          "cta_text" => Map.get(params, "cta_text", ""),
          "cta_link" => Map.get(params, "cta_link", ""),
          "video_url" => Map.get(params, "video_url", ""),
          "video_type" => Map.get(params, "video_type", "none"),
          "social_links" => extract_social_links_from_params(params)
        }

      "intro" ->
        # Build intro/about content
        %{
          "story" => Map.get(params, "story", ""),
          "highlights" => extract_array_from_params(params, "highlights"),
          "personality_traits" => extract_array_from_params(params, "personality_traits"),
          "fun_facts" => extract_array_from_params(params, "fun_facts")
        }

      "contact" ->
        # Build contact content
        %{
          "headline" => Map.get(params, "headline", ""),
          "description" => Map.get(params, "description", ""),
          "email" => Map.get(params, "email", ""),
          "phone" => Map.get(params, "phone", ""),
          "location" => Map.get(params, "location", ""),
          "availability" => Map.get(params, "availability", ""),
          "booking_link" => Map.get(params, "booking_link", ""),
          "social_links" => extract_social_links_from_params(params)
        }

      "testimonials" ->
        # Build testimonials content
        testimonials = extract_testimonial_items_from_params(params)
        %{
          "items" => testimonials
        }

      "services" ->
        # Build services content
        services = extract_service_items_from_params(params)
        %{
          "items" => services
        }

      _ ->
        # Default content structure
        %{
          "content" => Map.get(params, "content", ""),
          "description" => Map.get(params, "description", "")
        }
    end
  end

  defp build_experience_content(params) do
    IO.puts("🔧 Building experience content")
    IO.puts("🔧 Items param: #{inspect(params["items"])}")

    jobs = case params["items"] do
      items when is_map(items) ->
        items
        |> Enum.map(fn {_key, job_data} ->
          IO.puts("🔧 Processing job: #{inspect(job_data)}")

          %{
            "title" => job_data["title"] || "",
            "company" => job_data["company"] || "",
            "description" => job_data["description"] || "",
            "start_date" => job_data["start_date"] || "",
            "end_date" => job_data["end_date"] || "",
            "current" => job_data["is_current"] == "true" || job_data["current"] == "true",
            "location" => job_data["location"] || "",
            "employment_type" => job_data["employment_type"] || "",
            # Add duration field for enhanced_section_renderer compatibility
            "duration" => build_duration_string(job_data["start_date"], job_data["end_date"], job_data["is_current"])
          }
        end)
        |> Enum.filter(fn job ->
          # Keep jobs that have at least a title or company
          job["title"] != "" || job["company"] != ""
        end)

      _ ->
        IO.puts("🔧 No valid items found")
        []
    end

    IO.puts("🔧 Final jobs: #{inspect(jobs)}")

    # CRITICAL: Save in BOTH formats for compatibility
    content = %{
      "jobs" => jobs,        # Your current format
      "items" => jobs        # Enhanced section renderer format
    }

    {:ok, content}
  end

  defp build_duration_string(start_date, end_date, is_current) do
    cond do
      is_current == "true" ->
        if start_date && start_date != "", do: "#{start_date} - Present", else: "Present"
      end_date && end_date != "" && start_date && start_date != "" ->
        "#{start_date} - #{end_date}"
      start_date && start_date != "" ->
        "#{start_date}"
      true ->
        ""
    end
  end

  defp build_education_content(params) do
    education = case params["items"] do
      items when is_map(items) ->
        items
        |> Enum.map(fn {_key, edu_data} ->
          %{
            "degree" => edu_data["degree"] || "",
            "institution" => edu_data["institution"] || "",
            "year" => edu_data["year"] || "",
            "description" => edu_data["description"] || "",
            # Enhanced renderer compatibility
            "title" => edu_data["degree"] || "",
            "company" => edu_data["institution"] || "",
            "duration" => edu_data["year"] || ""
          }
        end)
        |> Enum.filter(fn edu ->
          edu["degree"] != "" || edu["institution"] != ""
        end)
      _ -> []
    end

    # Save in both formats
    {:ok, %{
      "education" => education,
      "items" => education
    }}
  end


  defp build_skills_content(params) do
    skills = case params["content"] do
      content when is_binary(content) ->
        content
        |> String.split([",", "\n", ";"])
        |> Enum.map(&String.trim/1)
        |> Enum.filter(&(&1 != ""))
      _ -> []
    end

    # Enhanced renderer compatibility
    {:ok, %{
      "skills" => skills,
      "content" => params["content"] || "",
      "items" => Enum.map(skills, fn skill -> %{"name" => skill, "title" => skill} end)
    }}
  end

  defp build_projects_content(params) do
    projects = case params["items"] do
      items when is_map(items) ->
        items
        |> Enum.map(fn {_key, project_data} ->
          %{
            "title" => project_data["title"] || "",
            "description" => project_data["description"] || "",
            "url" => project_data["url"] || "",
            "technologies" => project_data["technologies"] || "",
            # Enhanced renderer compatibility
            "company" => project_data["client"] || "",
            "duration" => project_data["timeline"] || ""
          }
        end)
        |> Enum.filter(fn project ->
          project["title"] != ""
        end)
      _ -> []
    end

    # Save in both formats
    {:ok, %{
      "projects" => projects,
      "items" => projects
    }}
  end

  defp build_about_content(params) do
    {:ok, %{"content" => params["content"] || ""}}
  end

  defp build_contact_content(params) do
    {:ok, %{
      "email" => params["email"] || "",
      "phone" => params["phone"] || "",
      "location" => params["location"] || "",
      "content" => params["content"] || ""
    }}
  end

  defp build_generic_content(params) do
    {:ok, %{"content" => params["content"] || ""}}
  end

  defp convert_section_to_serializable_map(section) do
    %{
      id: section.id,
      title: section.title,
      section_type: section.section_type,
      content: section.content,
      position: section.position,
      visible: section.visible,
      portfolio_id: section.portfolio_id,
      inserted_at: section.inserted_at,
      updated_at: section.updated_at
    }
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

defp extract_changeset_errors(%Ecto.Changeset{errors: errors}) do
  Enum.map(errors, fn {field, {message, _details}} ->
    "#{field} #{message}"
  end)
end
defp extract_changeset_errors(_), do: ["Unknown error"]

  @impl true
  def handle_event("close_section_modal", _params, socket) do
    {:noreply, socket
    |> assign(:show_section_modal, false)
    |> assign(:current_section_type, nil)
    |> assign(:editing_section, nil)}
  end

  @impl true
  def handle_event("close_modal_on_escape", _params, socket) do
    {:noreply, socket
    |> assign(:show_section_modal, false)
    |> assign(:current_section_type, nil)
    |> assign(:editing_section, nil)}
  end

  @impl true
  def handle_event("move_section_up", %{"section_id" => section_id}, socket) do
    {:noreply, put_flash(socket, :info, "Section reordering coming soon!")}
  end

  @impl true
  def handle_event("move_section_down", %{"section_id" => section_id}, socket) do
    {:noreply, put_flash(socket, :info, "Section reordering coming soon!")}
  end

  defp generate_default_section_title(section_type) do
    case to_string(section_type) do
      "experience" -> "Work Experience"
      "work_experience" -> "Work Experience"
      "education" -> "Education"
      "skills" -> "Skills"
      "projects" -> "Projects"
      "about" -> "About"
      "contact" -> "Contact"
      "achievements" -> "Achievements"
      "certifications" -> "Certifications"
      _ -> "Portfolio Section"
    end
  end

  defp get_default_content_for_type(section_type) do
    case section_type do
      "experience" -> %{
        "jobs" => [],
        "items" => []
      }
      "education" -> %{
        "education" => [],
        "items" => []
      }
      "skills" -> %{
        "skills" => [],
        "content" => "",
        "items" => []
      }
      "projects" -> %{
        "projects" => [],
        "items" => []
      }
      "about" -> %{
        "content" => ""
      }
      "contact" -> %{
        "email" => "",
        "phone" => "",
        "location" => "",
        "content" => ""
      }
      _ -> %{
        "content" => ""
      }
    end
  end

  defp extract_changeset_errors(changeset) do
    changeset.errors
    |> Enum.map(fn {field, {message, _details}} ->
      "#{field} #{message}"
    end)
  end

  defp update_section_in_list(sections, updated_section) do
    IO.puts("🔄 Updating section #{updated_section.id} in list")
    IO.puts("🔄 Updated section visibility: #{updated_section.visible}")

    updated_list = Enum.map(sections, fn section ->
      if section.id == updated_section.id do
        IO.puts("🔄 Found matching section, replacing with updated data")
        updated_section
      else
        section
      end
    end)

    IO.puts("🔄 Section list updated")
    updated_list
  end



  @impl true
  def handle_event("publish_portfolio", _params, socket) do
    {:noreply, put_flash(socket, :info, "Portfolio publishing feature coming soon!")}
  end

  @impl true
  def handle_event("set_preview_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, :preview_device, mode)}
  end

  @impl true
  def handle_event("change_color_scheme", %{"scheme" => scheme}, socket) do
    IO.puts("🎨 COLOR SCHEME CHANGE: #{scheme}")

    customization_params = %{"color_scheme" => scheme}

    case Portfolios.update_portfolio_customization_by_id(socket.assigns.portfolio.id, customization_params) do
      {:ok, updated_portfolio} ->
        # Single broadcast
        broadcast_portfolio_update(
          updated_portfolio.id,
          socket.assigns.sections,
          updated_portfolio.customization,
          :customization
        )

        {:noreply, socket
          |> assign(:portfolio, updated_portfolio)
          |> assign(:customization, updated_portfolio.customization)
          |> put_flash(:info, "Color scheme updated to #{scheme}!")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update color scheme")}
    end
  end

  @impl true
  def handle_event("change_font_style", %{"font" => font}, socket) do
    IO.puts("🔤 FONT CHANGE: #{font}")

    customization_params = %{"font_style" => font}

    case Portfolios.update_portfolio_customization_by_id(socket.assigns.portfolio.id, customization_params) do
      {:ok, updated_portfolio} ->
        # Single broadcast
        broadcast_portfolio_update(
          updated_portfolio.id,
          socket.assigns.sections,
          updated_portfolio.customization,
          :customization
        )

        {:noreply, socket
          |> assign(:portfolio, updated_portfolio)
          |> assign(:customization, updated_portfolio.customization)
          |> put_flash(:info, "Font updated to #{font}!")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update font")}
    end
  end

  @impl true
  def handle_event("change_primary_color", %{"color" => color}, socket) do
    IO.puts("🎨 PRIMARY COLOR CHANGE: #{color}")

    customization_params = %{"primary_color" => color}

    case Portfolios.update_portfolio_customization_by_id(socket.assigns.portfolio.id, customization_params) do
      {:ok, updated_portfolio} ->
        # Single broadcast
        broadcast_portfolio_update(
          updated_portfolio.id,
          socket.assigns.sections,
          updated_portfolio.customization,
          :customization
        )

        {:noreply, socket
          |> assign(:portfolio, updated_portfolio)
          |> assign(:customization, updated_portfolio.customization)
          |> push_event("update_css_variables", updated_portfolio.customization)
          |> put_flash(:info, "Primary color updated!")}

      {:error, changeset} ->
        error_message = extract_changeset_errors(changeset) |> Enum.join(", ")
        {:noreply, put_flash(socket, :error, "Failed to update primary color: #{error_message}")}
    end
  end

  @impl true
  def handle_event("change_secondary_color", %{"color" => color}, socket) do
    IO.puts("🎨 SECONDARY COLOR CHANGE: #{color}")

    customization_params = %{"secondary_color" => color}

    case Portfolios.update_portfolio_customization_by_id(socket.assigns.portfolio.id, customization_params) do
      {:ok, updated_portfolio} ->
        # Single broadcast
        broadcast_portfolio_update(
          updated_portfolio.id,
          socket.assigns.sections,
          updated_portfolio.customization,
          :customization
        )

        {:noreply, socket
          |> assign(:portfolio, updated_portfolio)
          |> assign(:customization, updated_portfolio.customization)
          |> push_event("update_css_variables", updated_portfolio.customization)
          |> put_flash(:info, "Secondary color updated!")}

      {:error, changeset} ->
        error_message = extract_changeset_errors(changeset) |> Enum.join(", ")
        {:noreply, put_flash(socket, :error, "Failed to update secondary color: #{error_message}")}
    end
  end

  @impl true
  def handle_event("change_accent_color", %{"color" => color}, socket) do
    IO.puts("🎨 ACCENT COLOR CHANGE: #{color}")

    customization_params = %{"accent_color" => color}

    case Portfolios.update_portfolio_customization_by_id(socket.assigns.portfolio.id, customization_params) do
      {:ok, updated_portfolio} ->
        # Single broadcast
        broadcast_portfolio_update(
          updated_portfolio.id,
          socket.assigns.sections,
          updated_portfolio.customization,
          :customization
        )

        {:noreply, socket
          |> assign(:portfolio, updated_portfolio)
          |> assign(:customization, updated_portfolio.customization)
          |> push_event("update_css_variables", updated_portfolio.customization)
          |> put_flash(:info, "Accent color updated!")}

      {:error, changeset} ->
        error_message = extract_changeset_errors(changeset) |> Enum.join(", ")
        {:noreply, put_flash(socket, :error, "Failed to update accent color: #{error_message}")}
    end
  end

  @impl true
  def handle_event("change_section_spacing", %{"spacing" => spacing}, socket) do
    IO.puts("📏 SPACING CHANGE: #{spacing}")

    customization_params = %{"section_spacing" => spacing}

    case Portfolios.update_portfolio_customization_by_id(socket.assigns.portfolio.id, customization_params) do
      {:ok, updated_portfolio} ->
        # Single broadcast
        broadcast_portfolio_update(
          updated_portfolio.id,
          socket.assigns.sections,
          updated_portfolio.customization,
          :customization
        )

        {:noreply, socket
          |> assign(:portfolio, updated_portfolio)
          |> assign(:customization, updated_portfolio.customization)
          |> push_event("update_css_variables", updated_portfolio.customization)
          |> put_flash(:info, "Section spacing updated!")}

      {:error, changeset} ->
        error_message = extract_changeset_errors(changeset) |> Enum.join(", ")
        {:noreply, put_flash(socket, :error, "Failed to update section spacing: #{error_message}")}
    end
  end

  @impl true
  def handle_event("change_layout_style", %{"layout" => layout_style}, socket) do
    IO.puts("🎨 LAYOUT CHANGE: #{layout_style}")

    customization_params = %{"layout_style" => layout_style}

    case Portfolios.update_portfolio_customization_by_id(socket.assigns.portfolio.id, customization_params) do
      {:ok, updated_portfolio} ->
        # Single broadcast
        broadcast_portfolio_update(
          updated_portfolio.id,
          socket.assigns.sections,
          updated_portfolio.customization,
          :customization
        )

        {:noreply, socket
          |> assign(:portfolio, updated_portfolio)
          |> assign(:customization, updated_portfolio.customization)
          |> push_event("update_css_variables", updated_portfolio.customization)
          |> push_event("layout_changed", %{layout: layout_style})
          |> put_flash(:info, "Layout updated!")}

      {:error, changeset} ->
        error_message = extract_changeset_errors(changeset) |> Enum.join(", ")
        {:noreply, put_flash(socket, :error, "Failed to update layout: #{error_message}")}
    end
  end

  @impl true
  def handle_event("export_portfolio", %{"format" => format}, socket) do
    case format do
      "pdf" ->
        {:noreply, put_flash(socket, :info, "PDF export feature coming soon! Your portfolio will be exported as a professional PDF document.")}
      "html" ->
        {:noreply, put_flash(socket, :info, "HTML export feature coming soon! Your portfolio will be exported as a static website.")}
      _ ->
        {:noreply, put_flash(socket, :error, "Invalid export format")}
    end
  end

  @impl true
  def handle_event("backup_portfolio", _params, socket) do
    {:noreply, put_flash(socket, :info, "Backup feature coming soon! This will create a complete backup of your portfolio.")}
  end

  @impl true
  def handle_event("reset_portfolio", _params, socket) do
    {:noreply, put_flash(socket, :info, "Portfolio reset feature coming soon! This will remove all sections and reset customizations.")}
  end

  @impl true
  def handle_event("delete_portfolio", _params, socket) do
    {:noreply, put_flash(socket, :error, "Portfolio deletion feature coming soon! Use this with extreme caution.")}
  end

  @impl true
  def handle_event("add_array_item", %{"field" => field_name}, socket) do
    # Update the component's internal state to add a new array item
    current_data = Map.get(socket.assigns, :form_data, %{})
    current_array = Map.get(current_data, field_name, [])
    updated_array = current_array ++ [""]
    updated_data = Map.put(current_data, field_name, updated_array)

    {:noreply, assign(socket, :form_data, updated_data)}
  end

  @impl true
  def handle_event("remove_array_item", %{"field" => field_name, "index" => index}, socket) do
    current_data = Map.get(socket.assigns, :form_data, %{})
    current_array = Map.get(current_data, field_name, [])
    index = String.to_integer(index)
    updated_array = List.delete_at(current_array, index)
    updated_data = Map.put(current_data, field_name, updated_array)

    {:noreply, assign(socket, :form_data, updated_data)}
  end

  @impl true
  def handle_event("add_complex_array_item", %{"field" => field_name}, socket) do
    current_data = Map.get(socket.assigns, :form_data, %{})
    current_array = Map.get(current_data, field_name, [])
    updated_array = current_array ++ [%{}]
    updated_data = Map.put(current_data, field_name, updated_array)

    {:noreply, assign(socket, :form_data, updated_data)}
  end

  @impl true
  def handle_event("remove_complex_array_item", %{"field" => field_name, "index" => index}, socket) do
    current_data = Map.get(socket.assigns, :form_data, %{})
    current_array = Map.get(current_data, field_name, [])
    index = String.to_integer(index)
    updated_array = List.delete_at(current_array, index)
    updated_data = Map.put(current_data, field_name, updated_array)

    {:noreply, assign(socket, :form_data, updated_data)}
  end

  @impl true
  def handle_event("add_map_item", %{"field" => field_name}, socket) do
    # Handle adding map items (like social links)
    {:noreply, socket}
  end

  @impl true
  def handle_event("remove_map_item", %{"field" => field_name, "key" => key}, socket) do
    # Handle removing map items
    {:noreply, socket}
  end

  # Video intro

  @impl true
  def handle_event("toggle_video_intro_modal", _params, socket) do
    current_state = Map.get(socket.assigns, :show_video_intro_modal, false)
    new_state = !current_state

    IO.puts("🎬 VIDEO MODAL: Toggle from #{current_state} to #{new_state}")

    {:noreply, assign(socket, :show_video_intro_modal, new_state)}
  end


  @impl true
  def handle_event("close_video_intro_modal", _params, socket) do
    IO.puts("🎬 VIDEO MODAL: Closing modal")
    {:noreply, assign(socket, :show_video_intro_modal, false)}
  end

  @impl true
  def handle_event("save_video_intro", params, socket) do
    video_data = %{
      "video_url" => params["video_url"],
      "video_title" => params["video_title"],
      "video_description" => params["video_description"],
      "video_source" => "upload",
      "video_uploaded_at" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    case Portfolios.update_portfolio_customization_by_id(socket.assigns.portfolio.id, video_data) do
      {:ok, updated_portfolio} ->
        broadcast_portfolio_update(
          updated_portfolio.id,
          socket.assigns.sections,
          updated_portfolio.customization
        )

        {:noreply, socket
          |> assign(:portfolio, updated_portfolio)
          |> assign(:customization, updated_portfolio.customization)
          |> assign(:show_video_intro_modal, false)
          |> put_flash(:info, "Video introduction saved successfully!")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to save video introduction")}
    end
  end


  @impl true
  def handle_event("remove_video_intro", _params, socket) do
    video_removal = %{
      "video_url" => nil,
      "video_title" => nil,
      "video_description" => nil,
      "video_position" => nil
    }

    case Portfolios.update_portfolio_customization_by_id(socket.assigns.portfolio.id, video_removal) do
      {:ok, updated_portfolio} ->
        broadcast_portfolio_update(
          updated_portfolio.id,
          socket.assigns.sections,
          updated_portfolio.customization
        )

        {:noreply, socket
          |> assign(:portfolio, updated_portfolio)
          |> assign(:customization, updated_portfolio.customization)
          |> put_flash(:info, "Video introduction removed")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to remove video introduction")}
    end
  end

  @impl true
  def handle_event("modal_overlay_clicked", _params, socket) do
    IO.puts("🎬 Modal overlay clicked - closing modal")
    {:noreply, assign(socket, :show_video_intro_modal, false)}
  end

  @impl true
  def handle_event("modal_content_clicked", _params, socket) do
    IO.puts("🎬 Modal content clicked - keeping modal open")
    {:noreply, socket}
  end

  @impl true
  def handle_event("modal_keydown", %{"key" => "Escape"}, socket) do
    IO.puts("🎬 ESC key pressed - closing modal")
    {:noreply, assign(socket, :show_video_intro_modal, false)}
  end

  @impl true
  def handle_event("modal_keydown", %{"key" => _other_key}, socket) do
    # Ignore other keys
    {:noreply, socket}
  end

  @impl true
  def handle_event("debug_assigns", _params, socket) do
    IO.puts("🔍 ALL SOCKET ASSIGNS:")
    IO.puts("🔍 #{inspect(Map.keys(socket.assigns))}")
    IO.puts("🔍 show_video_intro_modal: #{inspect(Map.get(socket.assigns, :show_video_intro_modal))}")
    {:noreply, socket}
  end

  # Resume import

  @impl true
  def handle_event("show_import_resume", _params, socket) do
    {:noreply, assign(socket, :show_import_resume_modal, true)}
  end

  @impl true
  def handle_event("close_import_resume_modal", _params, socket) do
    {:noreply, assign(socket, :show_import_resume_modal, false)}
  end

  @impl true
  def handle_event("import_resume_data", params, socket) do
    IO.puts("📄 IMPORTING RESUME DATA: #{inspect(params)}")

    case process_resume_import(params, socket) do
      {:ok, new_sections} ->
        updated_sections = socket.assigns.sections ++ new_sections

        # Broadcast the update
        broadcast_portfolio_update(
          socket.assigns.portfolio.id,
          updated_sections,
          socket.assigns.customization
        )

        {:noreply, socket
        |> assign(:sections, updated_sections)
        |> assign(:show_import_resume_modal, false)
        |> put_flash(:info, "Resume imported successfully! Added #{length(new_sections)} sections.")}

      {:error, reason} ->
        {:noreply, socket
        |> put_flash(:error, "Failed to import resume: #{reason}")}
    end
  end

  # Process resume import data
  defp process_resume_import(params, socket) do
    try do
      # Extract resume data from params
      resume_data = Map.get(params, "resume_data", %{})

      new_sections = []

      # Create experience section if data exists
      new_sections = if Map.has_key?(resume_data, "experience") && length(Map.get(resume_data, "experience", [])) > 0 do
        experience_section = create_experience_section_from_resume(resume_data["experience"], socket)
        [experience_section | new_sections]
      else
        new_sections
      end

      # Create education section if data exists
      new_sections = if Map.has_key?(resume_data, "education") && length(Map.get(resume_data, "education", [])) > 0 do
        education_section = create_education_section_from_resume(resume_data["education"], socket)
        [education_section | new_sections]
      else
        new_sections
      end

      # Create skills section if data exists
      new_sections = if Map.has_key?(resume_data, "skills") && length(Map.get(resume_data, "skills", [])) > 0 do
        skills_section = create_skills_section_from_resume(resume_data["skills"], socket)
        [skills_section | new_sections]
      else
        new_sections
      end

      # Create contact section if data exists
      new_sections = if Map.has_key?(resume_data, "contact") do
        contact_section = create_contact_section_from_resume(resume_data["contact"], socket)
        [contact_section | new_sections]
      else
        new_sections
      end

      {:ok, Enum.reverse(new_sections)}

    rescue
      e ->
        IO.puts("❌ Resume import error: #{inspect(e)}")
        {:error, "Failed to process resume data"}
    end
  end

  # Create experience section from resume data
  defp create_experience_section_from_resume(experience_data, socket) do
    content = %{
      "items" => experience_data,
      "jobs" => experience_data  # Backward compatibility
    }

    %{
      id: :rand.uniform(10000),
      title: "Work Experience",
      section_type: :experience,
      content: content,
      position: length(socket.assigns.sections) + 1,
      visible: true
    }
  end

  # Create education section from resume data
  defp create_education_section_from_resume(education_data, socket) do
    content = %{
      "items" => education_data
    }

    %{
      id: :rand.uniform(10000),
      title: "Education",
      section_type: :education,
      content: content,
      position: length(socket.assigns.sections) + 2,
      visible: true
    }
  end

  # Create skills section from resume data
  defp create_skills_section_from_resume(skills_data, socket) do
    content = %{
      "skills" => skills_data,
      "display_style" => "flat_list",
      "show_proficiency" => false
    }

    %{
      id: :rand.uniform(10000),
      title: "Skills",
      section_type: :skills,
      content: content,
      position: length(socket.assigns.sections) + 3,
      visible: true
    }
  end

  # Create contact section from resume data
  defp create_contact_section_from_resume(contact_data, socket) do
    content = %{
      "headline" => "Get In Touch",
      "description" => "Let's connect and discuss opportunities.",
      "email" => Map.get(contact_data, "email", ""),
      "phone" => Map.get(contact_data, "phone", ""),
      "location" => Map.get(contact_data, "location", ""),
      "social_links" => Map.get(contact_data, "social_links", %{})
    }

    %{
      id: :rand.uniform(10000),
      title: "Contact",
      section_type: :contact,
      content: content,
      position: length(socket.assigns.sections) + 4,
      visible: true
    }
  end

  defp has_video_intro?(portfolio) when is_map(portfolio) do
    customization = portfolio.customization || %{}
    video_url = Map.get(customization, "video_url")
    video_url && video_url != ""
  end

  defp has_video_intro?(_), do: false

  defp get_current_video_url(portfolio) do
    customization = portfolio.customization || %{}
    Map.get(customization, "video_url", "")
  end

  defp get_current_video_title(portfolio) do
    customization = portfolio.customization || %{}
    Map.get(customization, "video_title", "")
  end

  defp get_current_video_description(portfolio) do
    customization = portfolio.customization || %{}
    Map.get(customization, "video_description", "")
  end

  defp get_current_video_position_safe(assigns) do
    case assigns[:portfolio] do
      %{} = portfolio ->
        customization = portfolio.customization || %{}
        Map.get(customization, "video_position", "hero")
      _ -> "hero"
    end
  end


  # ============================================================================
  # SAFE HELPER FUNCTIONS - Handle nil portfolio/user gracefully
  # ============================================================================

  defp get_max_video_duration_safe(assigns) do
    case {assigns[:current_user], assigns[:portfolio]} do
      {%{} = user, _} -> get_max_video_duration(user)
      {_, %{}} -> 1  # Default to 1 minute if no user but have portfolio
      _ -> 1  # Default fallback
    end
  end

  defp get_account_tier_message_safe(assigns) do
    case assigns[:current_user] do
      %{} = user -> get_account_tier_message(user)
      _ -> "Record your introduction video"
    end
  end

  defp get_current_video_url_safe(assigns) do
    case assigns[:portfolio] do
      %{} = portfolio -> get_current_video_url(portfolio)
      _ -> ""
    end
  end

  defp get_current_video_title_safe(assigns) do
    case assigns[:portfolio] do
      %{} = portfolio -> get_current_video_title(portfolio)
      _ -> ""
    end
  end

  defp get_current_video_description_safe(assigns) do
    case assigns[:portfolio] do
      %{} = portfolio -> get_current_video_description(portfolio)
      _ -> ""
    end
  end


  defp convert_section_to_map(section) do
    %{
      id: section.id,
      title: section.title,
      section_type: section.section_type,
      content: section.content,
      position: section.position,
      visible: section.visible,
      portfolio_id: section.portfolio_id,
      inserted_at: section.inserted_at,
      updated_at: section.updated_at
    }
  end

  # Helper Functions
  defp assign_ui_state(socket) do
    socket
    |> assign(:active_tab, "sections")
    |> assign(:preview_mode, :editor)
    |> assign(:preview_device, "desktop")
    |> assign(:show_section_modal, false)
    |> assign(:show_create_dropdown, false)
    |> assign(:current_section_type, nil)
    |> assign(:editing_section, nil)
  end

  defp assign_editor_state(socket) do
    socket
    |> assign(:editor_mode, :edit)
    |> assign(:autosave_enabled, true)
    |> assign(:last_saved, DateTime.utc_now())
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
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

  defp get_sections_from_portfolio(portfolio) do
    case Map.get(portfolio, :sections) do
      sections when is_list(sections) -> sections
      _ ->
        case Map.get(portfolio, "sections") do
          sections when is_list(sections) -> sections
          _ -> []
        end
    end
  end

  defp update_section_with_modal(socket, params) do
    section_id = String.to_integer(params["section_id"])
    title = params["title"]
    visible = params["visible"] == "true"

    # Find the section
    section = Enum.find(socket.assigns.sections, &(&1.id == section_id))

    if section do
      content = extract_content_from_params(to_string(section.section_type), params)

      # Use the correct function name from Portfolios module
      case Portfolios.update_section(section, %{title: title, content: content, visible: visible}) do
        {:ok, updated_section} ->
          updated_sections = Enum.map(socket.assigns.sections, fn s ->
            if s.id == section_id, do: updated_section, else: s
          end)

          # Broadcast to BOTH channels
          broadcast_portfolio_update(socket.assigns.portfolio.id, updated_sections, socket.assigns.customization)

          {:noreply, socket
          |> assign(:sections, updated_sections)
          |> assign(:show_section_modal, false)
          |> assign(:current_section_type, nil)
          |> assign(:editing_section, nil)
          |> put_flash(:info, "Section updated successfully!")}

        {:error, changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to update section: #{inspect(changeset.errors)}")}
      end
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end


  defp extract_content_from_params(section_type, params) do
    # Simple content extraction - adapt based on your section types
    case section_type do
      "intro" ->
        %{
          "summary" => params["summary"] || "",
          "website" => params["website"] || "",
          "social_links" => %{}
        }
      "experience" ->
        %{
          "jobs" => [%{
            "title" => params["title"] || "",
            "company" => params["company"] || "",
            "description" => params["description"] || "",
            "start_date" => params["start_date"] || "",
            "end_date" => params["end_date"] || "",
            "current" => params["current"] == "true"
          }]
        }
      "contact" ->
        %{
          "email" => params["email"] || "",
          "phone" => params["phone"] || "",
          "location" => params["location"] || "",
          "social_links" => %{}
        }
      _ ->
        %{
          "content" => params["content"] || "Add your content here..."
        }
    end
  end

  defp generate_preview_css(customization) do
    layout_style = Map.get(customization, "layout_style", "mobile_single")
    color_scheme = Map.get(customization, "color_scheme", "blue")
    font_style = Map.get(customization, "font_style", "inter")
    section_spacing = Map.get(customization, "section_spacing", "normal")
    corner_radius = Map.get(customization, "corner_radius", "rounded")

    # Color scheme definitions
    colors = case color_scheme do
      "blue" -> %{primary: "#3B82F6", secondary: "#1D4ED8", accent: "#60A5FA"}
      "purple" -> %{primary: "#8B5CF6", secondary: "#7C3AED", accent: "#A78BFA"}
      "green" -> %{primary: "#10B981", secondary: "#059669", accent: "#34D399"}
      "red" -> %{primary: "#EF4444", secondary: "#DC2626", accent: "#F87171"}
      "orange" -> %{primary: "#F97316", secondary: "#EA580C", accent: "#FB923C"}
      "pink" -> %{primary: "#EC4899", secondary: "#DB2777", accent: "#F472B6"}
      "dark" -> %{primary: "#1F2937", secondary: "#111827", accent: "#374151"}
      "slate" -> %{primary: "#475569", secondary: "#334155", accent: "#64748B"}
      "neutral" -> %{primary: "#525252", secondary: "#404040", accent: "#737373"}
      "midnight" -> %{primary: "#0F172A", secondary: "#1E293B", accent: "#334155"}
      "charcoal" -> %{primary: "#18181B", secondary: "#27272A", accent: "#3F3F46"}
      "graphite" -> %{primary: "#171717", secondary: "#262626", accent: "#525252"}
      _ -> %{primary: "#3B82F6", secondary: "#1D4ED8", accent: "#60A5FA"}
    end

    # Font families
    font_family = case font_style do
      "inter" -> "Inter, system-ui, sans-serif"
      "poppins" -> "Poppins, system-ui, sans-serif"
      "playfair" -> "Playfair Display, Georgia, serif"
      "source_sans" -> "Source Sans Pro, system-ui, sans-serif"
      _ -> "Inter, system-ui, sans-serif"
    end

    # Spacing values
    spacing = case section_spacing do
      "compact" -> "0.5rem"
      "normal" -> "1rem"
      "spacious" -> "2rem"
      _ -> "1rem"
    end

    # Border radius values
    radius = case corner_radius do
      "sharp" -> "0"
      "rounded" -> "0.5rem"
      "very-rounded" -> "1rem"
      _ -> "0.5rem"
    end

    """
    .portfolio-preview {
      font-family: #{font_family};
      --primary-color: #{colors.primary};
      --secondary-color: #{colors.secondary};
      --accent-color: #{colors.accent};
      --section-spacing: #{spacing};
      --border-radius: #{radius};
    }

    .portfolio-preview h1, .portfolio-preview h2, .portfolio-preview h3 {
      color: var(--primary-color);
    }

    .portfolio-preview .section-card {
      margin-bottom: var(--section-spacing);
      border-radius: var(--border-radius);
      border-color: var(--accent-color);
    }

    .portfolio-preview .layout-#{layout_style} {
      #{get_layout_css(layout_style)}
    }
    """
  end

  defp get_layout_css(layout_style) do
    case layout_style do
      "mobile_single" -> "display: flex; flex-direction: column; gap: 1rem;"
      "grid_uniform" -> "display: grid; grid-template-columns: repeat(2, 1fr); gap: 1rem;"
      "dashboard" -> "display: grid; grid-template-columns: 2fr 1fr; gap: 1rem;"
      "creative_modern" -> "display: grid; grid-template-columns: 1fr 1fr; gap: 1.5rem; transform: rotate(0.5deg);"
      _ -> "display: flex; flex-direction: column; gap: 1rem;"
    end
  end

  @impl true
  def handle_info({:update_portfolio_design, design_update}, socket) do
    # NO re-broadcasting here - just update state
    case Portfolios.update_portfolio_customization_by_id(socket.assigns.portfolio.id, design_update) do
      {:ok, updated_portfolio} ->
        {:noreply, socket
          |> assign(:portfolio, updated_portfolio)
          |> assign(:customization, updated_portfolio.customization)
          |> put_flash(:info, "Portfolio design updated successfully!")}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update portfolio design")}
    end
  end

  defp format_section_type_title(section_type) do
    section_type
    |> to_string()
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <!-- Simple inline navigation -->
    <nav class="fixed top-0 left-0 right-0 bg-white border-b border-gray-200 z-40">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex justify-between items-center h-16">
          <div class="flex items-center">
            <div class="w-8 h-8 bg-gradient-to-br from-blue-600 to-purple-600 rounded-lg flex items-center justify-center mr-3">
              <span class="text-white font-bold text-sm">F</span>
            </div>
            <span class="text-xl font-bold text-gray-900">Frestyl Portfolio Editor</span>
          </div>
          <div class="flex items-center space-x-3">
            <span class="text-sm text-gray-700">
              <%= Map.get(assigns[:current_user] || %{}, :name, "User") %>
            </span>
          </div>
        </div>
      </div>
    </nav>

    <div class="pt-16 min-h-screen bg-gray-50">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">

        <!-- Editor Header -->
        <div class="bg-white rounded-xl shadow-sm border mb-6">
          <div class="p-6 border-b border-gray-200">
            <div class="flex flex-col sm:flex-row sm:items-center justify-between">
              <div>
                <h1 class="text-2xl font-bold text-gray-900 flex items-center">
                  <div class="w-8 h-8 bg-gradient-to-br from-blue-600 to-purple-600 rounded-lg flex items-center justify-center mr-3">
                    <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
                    </svg>
                  </div>
                  Editing: <%= Map.get(assigns[:portfolio] || %{}, :title, "Untitled Portfolio") %>
                </h1>
                <p class="text-gray-600 mt-1">Create your professional portfolio with smart sections</p>
              </div>

              <div class="flex items-center space-x-3 mt-4 sm:mt-0">
                <!-- Preview Toggle -->
                <button
                  phx-click="toggle_preview"
                  class={[
                    "flex items-center px-3 py-2 rounded-lg text-sm font-medium transition-colors",
                    if(Map.get(assigns, :preview_mode, :editor) == :split,
                      do: "bg-blue-100 text-blue-700",
                      else: "bg-gray-100 text-gray-700 hover:bg-gray-200")
                  ]}>
                  <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
                  </svg>
                  <%= if Map.get(assigns, :preview_mode, :editor) == :split, do: "Hide Preview", else: "Show Preview" %>
                </button>

                <!-- Publish Button -->
                <button phx-click="publish_portfolio"
                        class="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors font-medium">
                  <svg class="w-4 h-4 inline mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 10l7-7m0 0l7 7m-7-7v18"/>
                  </svg>
                  Publish
                </button>
              </div>
            </div>
          </div>

          <div class="enhanced-portfolio-editor">
            <!-- Tab Navigation -->
            <div class="border-b border-gray-200 mb-6">
              <nav class="flex space-x-8">
                <button
                  phx-click="switch_tab"
                  phx-value-tab="sections"
                  class={[
                    "py-2 px-1 border-b-2 font-medium text-sm",
                    if(@active_tab == "sections", do: "border-blue-500 text-blue-600", else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300")
                  ]}>
                  📄 Sections
                </button>
                <button
                  phx-click="switch_tab"
                  phx-value-tab="design"
                  class={[
                    "py-2 px-1 border-b-2 font-medium text-sm",
                    if(@active_tab == "design", do: "border-blue-500 text-blue-600", else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300")
                  ]}>
                  🎨 Design
                </button>
                <button
                  phx-click="switch_tab"
                  phx-value-tab="settings"
                  class={[
                    "py-2 px-1 border-b-2 font-medium text-sm",
                    if(@active_tab == "settings", do: "border-blue-500 text-blue-600", else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300")
                  ]}>
                  ⚙️ Settings
                </button>
              </nav>
            </div>


          </div>
        </div>

        <!-- Main Content Area -->
        <div class={[
          "grid gap-8",
          if(Map.get(assigns, :preview_mode, :editor) == :split,
            do: "lg:grid-cols-12",
            else: "grid-cols-1")
        ]}>
          <!-- Editor Panel -->
          <div class={[
            if(Map.get(assigns, :preview_mode, :editor) == :split,
              do: "lg:col-span-7 col-span-1",
              else: "col-span-1")
          ]}>
            <%= case Map.get(assigns, :active_tab, "sections") do %>
              <% "sections" -> %>
                <%= render_sections_tab(assigns) %>
              <% "design" -> %>
                <%= render_design_tab(assigns) %>
              <% "settings" -> %>
                <%= render_settings_tab(assigns) %>
              <% _ -> %>
                <%= render_sections_tab(assigns) %>
            <% end %>
          </div>

          <!-- Preview Panel -->
          <%= if Map.get(assigns, :preview_mode, :editor) == :split do %>
            <div class="lg:col-span-5 col-span-1">
              <div class="bg-white rounded-xl shadow-sm border overflow-hidden lg:sticky lg:top-8">
                <div class="p-4 bg-gray-50 border-b border-gray-200">
                  <div class="flex items-center justify-between">
                    <h3 class="font-medium text-gray-900">Live Preview</h3>
                    <div class="flex items-center space-x-2">
                      <div class="flex bg-gray-200 rounded-lg p-1">
                        <button phx-click="set_preview_mode"
                                phx-value-mode="mobile"
                                class={[
                                  "px-2 py-1 rounded text-xs font-medium transition-colors",
                                  if(Map.get(assigns, :preview_device, "desktop") == "mobile",
                                    do: "bg-white text-gray-900 shadow-sm",
                                    else: "text-gray-600")
                                ]}>
                          📱 Mobile
                        </button>
                        <button phx-click="set_preview_mode"
                                phx-value-mode="desktop"
                                class={[
                                  "px-2 py-1 rounded text-xs font-medium transition-colors",
                                  if(Map.get(assigns, :preview_device, "desktop") == "desktop",
                                    do: "bg-white text-gray-900 shadow-sm",
                                    else: "text-gray-600")
                                ]}>
                          💻 Desktop
                        </button>
                      </div>
                    </div>
                  </div>
                </div>
                <div class="h-96 overflow-y-auto bg-gray-100 p-4">
                  <!-- Apply dynamic CSS -->
                  <style>
                    <%= generate_preview_css(assigns[:customization] || %{}) %>
                  </style>

                  <div class={[
                    "bg-white rounded-lg shadow-sm overflow-hidden transition-all duration-300 portfolio-preview",
                    "layout-#{Map.get(assigns[:customization] || %{}, "layout_style", "mobile_single")}",
                    if(Map.get(assigns, :preview_device, "desktop") == "mobile", do: "max-w-sm mx-auto", else: "w-full")
                  ]}>
                    <div class="p-6">
                      <h3 class="font-bold text-lg mb-4">
                        <%= Map.get(assigns[:portfolio] || %{}, :title, "Portfolio Preview") %>
                      </h3>

                      <!-- Show current customization with visual styling -->
                      <div class={[
                        "space-y-4",
                        "layout-#{Map.get(assigns[:customization] || %{}, "layout_style", "mobile_single")}"
                      ]}>
                        <div class="section-card border rounded-lg p-3" style="border-color: var(--accent-color)">
                          <h4 class="font-medium text-sm">Active Layout</h4>
                          <p class="text-xs text-gray-500 capitalize">
                            <%= Map.get(assigns[:customization] || %{}, "layout_style", "mobile_single") |> String.replace("_", " ") %>
                          </p>
                        </div>
                        <div class="section-card border rounded-lg p-3" style="border-color: var(--accent-color)">
                          <h4 class="font-medium text-sm">Color Scheme</h4>
                          <p class="text-xs text-gray-500 capitalize">
                            <%= Map.get(assigns[:customization] || %{}, "color_scheme", "blue") %>
                          </p>
                          <div class="flex space-x-1 mt-2">
                            <div class="w-3 h-3 rounded" style="background-color: var(--primary-color)"></div>
                            <div class="w-3 h-3 rounded" style="background-color: var(--secondary-color)"></div>
                            <div class="w-3 h-3 rounded" style="background-color: var(--accent-color)"></div>
                          </div>
                        </div>
                        <div class="section-card border rounded-lg p-3" style="border-color: var(--accent-color)">
                          <h4 class="font-medium text-sm">Typography</h4>
                          <p class="text-xs text-gray-500 capitalize">
                            <%= Map.get(assigns[:customization] || %{}, "font_style", "inter") %>
                          </p>
                        </div>
                        <div class="section-card border rounded-lg p-3" style="border-color: var(--accent-color)">
                          <h4 class="font-medium text-sm">Spacing</h4>
                          <p class="text-xs text-gray-500 capitalize">
                            <%= Map.get(assigns[:customization] || %{}, "section_spacing", "normal") %>
                          </p>
                        </div>

                        <%= for section <- Enum.take(assigns[:sections] || [], 3) do %>
                          <div class="section-card border rounded-lg p-3" style="border-color: var(--accent-color)">
                            <h4 class="font-medium text-sm"><%= section.title %></h4>
                            <p class="text-xs text-gray-500"><%= String.capitalize(to_string(section.section_type)) %></p>
                          </div>
                        <% end %>

                        <%= if length(assigns[:sections] || []) > 3 do %>
                          <div class="text-center text-xs text-gray-500">
                            + <%= length(assigns[:sections] || []) - 3 %> more sections
                          </div>
                        <% end %>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>

    <!-- Section Creation Dropdown -->
    <%= if Map.get(assigns, :show_create_dropdown, false) do %>
      <%= render_section_creation_dropdown(assigns) %>
    <% end %>

    <!-- Section Modal -->
    <%= if Map.get(assigns, :show_section_modal, false) do %>
      <.live_component
        module={FrestylWeb.PortfolioLive.Components.DynamicSectionModal}
        id="section-modal"
        section_type={Map.get(assigns, :current_section_type, "intro")}
        editing_section={Map.get(assigns, :editing_section, nil)} />
    <% end %>
    """
  end

  # Sections Tab Renderer
defp render_sections_tab(assigns) do
  ~H"""
  <div class="sections-tab space-y-6">
    <!-- Video Intro Section -->
    <div class="bg-white rounded-xl shadow-sm border p-6">
      <div class="flex items-center justify-between mb-4">
        <div>
          <h3 class="text-lg font-bold text-gray-900 flex items-center">
            <svg class="w-5 h-5 mr-2 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
            </svg>
            Video Introduction
          </h3>
          <p class="text-gray-600">Add a personal video introduction to your portfolio</p>
        </div>
        <button
          phx-click="toggle_video_intro_modal"
          class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors font-medium">
          <%= if has_video_intro?(@portfolio) do %>
            Edit Video
          <% else %>
            Add Video
          <% end %>
        </button>
      </div>

      <!-- Current Video Display -->
      <%= if has_video_intro?(@portfolio) do %>
        <div class="mt-4 p-4 bg-gray-50 rounded-lg">
          <div class="flex items-center justify-between">
            <div class="flex items-center">
              <div class="w-16 h-12 bg-gray-200 rounded flex items-center justify-center mr-3">
                <svg class="w-6 h-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.828 14.828a4 4 0 01-5.656 0M9 10h1m4 0h1m-6 4h8m-8-4a9 9 0 118 0 9 9 0 01-8 0z"/>
                </svg>
              </div>
              <div>
                <p class="font-medium text-gray-900">Video Introduction Added</p>
                <p class="text-sm text-gray-600">Click "Edit Video" to update or remove</p>
              </div>
            </div>
            <button
              phx-click="remove_video_intro"
              class="px-3 py-1 text-red-600 hover:bg-red-50 rounded text-sm">
              Remove
            </button>
          </div>
        </div>
      <% else %>
        <div class="mt-4 p-6 border-2 border-dashed border-gray-300 rounded-lg text-center">
          <svg class="w-12 h-12 mx-auto text-gray-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
          </svg>
          <h4 class="text-lg font-medium text-gray-900 mb-2">Add Video Introduction</h4>
          <p class="text-gray-600 mb-4">Make a great first impression with a personal video introduction</p>
          <button
            phx-click="toggle_video_intro_modal"
            class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors">
            Add Video
          </button>
        </div>
      <% end %>
    </div>

    <!-- Enhanced Sections Management -->
    <div class="bg-white rounded-xl shadow-sm border p-6">
      <div class="flex flex-col sm:flex-row sm:items-center justify-between mb-6 gap-4">
        <div>
          <h3 class="text-lg font-bold text-gray-900">Portfolio Sections</h3>
          <p class="text-gray-600">Build your portfolio by adding different sections</p>
        </div>

        <!-- Action Buttons -->
        <div class="flex flex-col sm:flex-row gap-3">
          <!-- Import Resume Button (Secondary) -->
            <button
              phx-click="show_import_resume"
              class="flex items-center px-4 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 transition-colors font-medium border border-gray-300">
              <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/>
              </svg>
              Import Resume
            </button>

          <!-- Add Section Button (Primary) -->
          <button
            phx-click="show_create_dropdown"
            class="flex items-center px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors font-medium">
            <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
            </svg>
            Add Section
          </button>
        </div>
      </div>

      <!-- Quick Tips -->
      <div class="mb-6 p-4 bg-blue-50 border border-blue-200 rounded-lg">
        <div class="flex items-start">
          <svg class="w-5 h-5 text-blue-600 mt-0.5 mr-3 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
          </svg>
          <div>
            <h4 class="font-medium text-blue-900 mb-1">💡 Quick Start Tips</h4>
            <p class="text-sm text-blue-800">
              <strong>New to portfolios?</strong> Import your resume to automatically create sections,
              then customize them. <strong>Starting fresh?</strong> Add sections manually for full control.
            </p>
          </div>
        </div>
      </div>

      <!-- Existing Sections Display with ALL FUNCTIONALITY -->
      <div class="space-y-4">
        <%= for section <- @sections do %>
          <div class="flex items-center justify-between p-4 border border-gray-200 rounded-lg hover:shadow-sm transition-shadow">
            <div class="flex items-center">
              <div class="w-10 h-10 bg-gray-100 rounded-lg flex items-center justify-center mr-3">
                <span class="text-lg"><%= get_section_icon(section.section_type) %></span>
              </div>
              <div>
                <h4 class="font-medium text-gray-900"><%= section.title || format_section_type_title(section.section_type) %></h4>
                <p class="text-sm text-gray-600">
                  <%= if section.visible, do: "Visible", else: "Hidden" %> •
                  Position <%= section.position %>
                </p>
              </div>
            </div>

            <div class="flex items-center space-x-2">
              <!-- Edit Button -->
              <button
                phx-click="edit_section"
                phx-value-section_id={section.id}
                class="p-2 text-gray-400 hover:text-blue-600 hover:bg-blue-50 rounded-lg transition-colors"
                title="Edit section">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
                </svg>
              </button>

              <!-- EXISTING: Move Up/Down Buttons -->
              <div class="flex flex-col">
                <button
                  phx-click="move_section_up"
                  phx-value-section_id={section.id}
                  class="p-1 text-gray-400 hover:text-gray-600 hover:bg-gray-50 rounded transition-colors"
                  title="Move up">
                  <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7"/>
                  </svg>
                </button>
                <button
                  phx-click="move_section_down"
                  phx-value-section_id={section.id}
                  class="p-1 text-gray-400 hover:text-gray-600 hover:bg-gray-50 rounded transition-colors"
                  title="Move down">
                  <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>
                  </svg>
                </button>
              </div>

              <!-- Visibility Toggle -->
              <button
                phx-click="toggle_section_visibility"
                phx-value-section_id={section.id}
                class={[
                  "p-2 rounded-lg transition-colors",
                  if(section.visible,
                    do: "text-green-600 hover:bg-green-50",
                    else: "text-gray-400 hover:bg-gray-50")
                ]}
                title={if(section.visible, do: "Hide section", else: "Show section")}>
                <%= if section.visible do %>
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
                  </svg>
                <% else %>
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.878 9.878L3 3m6.878 6.878L21 21"/>
                  </svg>
                <% end %>
              </button>

              <!-- Delete Button -->
              <button
                phx-click="delete_section"
                phx-value-section_id={section.id}
                phx-confirm="Are you sure you want to delete this section?"
                class="p-2 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                title="Delete section">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
                </svg>
              </button>
            </div>
          </div>
        <% end %>

        <%= if Enum.empty?(@sections) do %>
          <div class="text-center py-12">
            <svg class="w-16 h-16 mx-auto text-gray-300 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>
            </svg>
            <h4 class="text-lg font-medium text-gray-900 mb-2">No sections yet</h4>
            <p class="text-gray-600 mb-6">Start building your portfolio by adding your first section or importing from your resume</p>
            <div class="flex flex-col sm:flex-row items-center justify-center gap-3">
              <button
                phx-click="show_import_resume"
                class="px-4 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 transition-colors">
                Import Resume
              </button>
              <span class="text-gray-400">or</span>
              <button
                phx-click="show_create_dropdown"
                class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors">
                Add Your First Section
              </button>
            </div>
          </div>
        <% end %>
      </div>
    </div>
  </div>

  <!-- NEW FEATURE: Enhanced Video Intro Modal with Tab Navigation and Camera Initialization -->
  <%= if Map.get(assigns, :show_video_intro_modal, false) do %>
    <%= render_video_intro_modal(assigns) %>
  <% end %>

  <!-- EXISTING: Resume Import Modal -->
  <%= if Map.get(assigns, :show_resume_import_modal, false) do %>
    <%= render_resume_import_modal(assigns) %>
  <% end %>
  """
end

  defp render_resume_import_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div class="bg-white rounded-xl shadow-2xl max-w-4xl w-full max-h-[90vh] overflow-hidden">
        <!-- Modal Header -->
        <div class="p-6 border-b border-gray-200 bg-gradient-to-r from-green-50 to-blue-50">
          <div class="flex items-center justify-between">
            <div>
              <h3 class="text-xl font-bold text-gray-900">Import from Resume</h3>
              <p class="text-gray-600 mt-1">Upload your resume to automatically create portfolio sections</p>
            </div>
            <button
              phx-click="close_import_resume"
              class="p-2 text-gray-400 hover:text-gray-600 rounded-lg hover:bg-white hover:shadow-sm transition-all">
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>
        </div>

        <!-- Modal Content -->
        <div class="p-6">
          <!-- Resume Parser Component -->
          <.live_component
            module={FrestylWeb.PortfolioLive.ResumeParser}
            id="resume-import"
            portfolio={@portfolio}
            current_user={@current_user}
            target={@myself} />
        </div>
      </div>
    </div>
    """
  end

  defp render_design_tab(assigns) do
    ~H"""
    <div class="design-tab space-y-6" phx-update="replace" id="design-tab-container">
      <div class="bg-white rounded-xl shadow-sm border p-6">
        <h2 class="text-xl font-bold text-gray-900 mb-6">Portfolio Design</h2>

        <!-- Layout Picker Component -->
        <%= if @active_tab == "design" do %>
          <.live_component
            module={FrestylWeb.PortfolioLive.Components.LayoutPickerComponent}
            id={"layout-picker-design-#{@portfolio.id}"}
            portfolio={@portfolio}
          />
        <% end %>
      </div>
    </div>
    """
  end

  # Settings Tab Renderer
  defp render_settings_tab(assigns) do
    portfolio = Map.get(assigns, :portfolio, %{})
    customization = Map.get(assigns, :customization, %{})
    sections = Map.get(assigns, :sections, [])

    ~H"""
    <div class="settings-tab space-y-6">

      <!-- Portfolio Info -->
      <div class="bg-white rounded-xl shadow-sm border p-6">
        <h3 class="text-lg font-bold text-gray-900 mb-4">Portfolio Information</h3>

        <div class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Portfolio Title</label>
            <input type="text"
                   name="title"
                   value={Map.get(portfolio, :title, "")}
                   phx-change="update_portfolio_info"
                   phx-debounce="1000"
                   class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                   placeholder="Your Portfolio Title">
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Description</label>
            <textarea name="description"
                      rows="3"
                      phx-change="update_portfolio_info"
                      phx-debounce="1000"
                      class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 resize-y"
                      placeholder="Describe your portfolio..."><%= Map.get(portfolio, :description, "") %></textarea>
          </div>
        </div>
      </div>

      <!-- Privacy & Sharing -->
      <div class="bg-white rounded-xl shadow-sm border p-6">
        <h3 class="text-lg font-bold text-gray-900 mb-4">Privacy & Sharing</h3>

        <div class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-3">Portfolio Visibility</label>
            <div class="space-y-3">
              <label class="relative flex items-start cursor-pointer">
                <input type="radio"
                       name="visibility"
                       value="public"
                       class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 mt-1">
                <div class="ml-3">
                  <div class="text-sm font-medium text-gray-900">Public</div>
                  <div class="text-sm text-gray-600">Anyone can find and view your portfolio</div>
                </div>
              </label>
              <label class="relative flex items-start cursor-pointer">
                <input type="radio"
                       name="visibility"
                       value="unlisted"
                       class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 mt-1">
                <div class="ml-3">
                  <div class="text-sm font-medium text-gray-900">Unlisted</div>
                  <div class="text-sm text-gray-600">Only people with the link can view</div>
                </div>
              </label>
              <label class="relative flex items-start cursor-pointer">
                <input type="radio"
                       name="visibility"
                       value="private"
                       checked="true"
                       class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 mt-1">
                <div class="ml-3">
                  <div class="text-sm font-medium text-gray-900">Private</div>
                  <div class="text-sm text-gray-600">Only you can view (perfect for drafts)</div>
                </div>
              </label>
            </div>
          </div>

          <!-- Portfolio URL -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Portfolio URL</label>
            <div class="flex">
              <span class="inline-flex items-center px-3 rounded-l-lg border border-r-0 border-gray-300 bg-gray-50 text-gray-500 text-sm">
                frestyl.com/
              </span>
              <input type="text"
                     name="slug"
                     value={Map.get(portfolio, :slug, "")}
                     phx-change="update_portfolio_slug"
                     phx-debounce="1000"
                     class="flex-1 px-3 py-2 border border-gray-300 rounded-r-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                     placeholder="your-name">
            </div>
            <p class="mt-1 text-sm text-gray-500">Choose a custom URL for your portfolio</p>
          </div>
        </div>
      </div>

      <!-- Portfolio Stats -->
      <div class="bg-white rounded-xl shadow-sm border p-6">
        <h3 class="text-lg font-bold text-gray-900 mb-4">Portfolio Stats</h3>

        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div class="text-center p-4 bg-blue-50 rounded-lg">
            <div class="text-2xl font-bold text-blue-600"><%= length(sections) %></div>
            <div class="text-sm text-blue-700">Total Sections</div>
          </div>
          <div class="text-center p-4 bg-green-50 rounded-lg">
            <div class="text-2xl font-bold text-green-600">
              <%= Enum.count(sections, fn s -> Map.get(s, :visible, true) end) %>
            </div>
            <div class="text-sm text-green-700">Visible Sections</div>
          </div>
          <div class="text-center p-4 bg-purple-50 rounded-lg">
            <div class="text-2xl font-bold text-purple-600">Active</div>
            <div class="text-sm text-purple-700">Status</div>
          </div>
        </div>
      </div>

      <!-- Export & Actions -->
      <div class="bg-white rounded-xl shadow-sm border p-6">
        <h3 class="text-lg font-bold text-gray-900 mb-6">Portfolio Actions</h3>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <!-- Export Options -->
          <button phx-click="export_portfolio" phx-value-format="pdf"
                  class="group relative p-4 border border-gray-200 rounded-xl hover:border-blue-300 hover:shadow-sm transition-all text-left">
            <div class="flex items-center">
              <div class="w-10 h-10 bg-blue-100 rounded-lg flex items-center justify-center mr-3 group-hover:bg-blue-200 transition-colors">
                <svg class="w-5 h-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                </svg>
              </div>
              <div>
                <h4 class="font-medium text-gray-900 group-hover:text-blue-900">Export PDF</h4>
                <p class="text-sm text-gray-500">Download as PDF</p>
              </div>
            </div>
          </button>

          <button phx-click="backup_portfolio"
                  class="group relative p-4 border border-gray-200 rounded-xl hover:border-green-300 hover:shadow-sm transition-all text-left">
            <div class="flex items-center">
              <div class="w-10 h-10 bg-green-100 rounded-lg flex items-center justify-center mr-3 group-hover:bg-green-200 transition-colors">
                <svg class="w-5 h-5 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"/>
                </svg>
              </div>
              <div>
                <h4 class="font-medium text-gray-900 group-hover:text-green-900">Create Backup</h4>
                <p class="text-sm text-gray-500">Save complete copy</p>
              </div>
            </div>
          </button>
        </div>
      </div>

      <!-- Danger Zone -->
      <div class="bg-red-50 rounded-xl border border-red-200 p-6">
        <h3 class="text-lg font-bold text-red-900 mb-4 flex items-center">
          <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L4.082 15.5c-.77.833.192 2.5 1.732 2.5z"/>
          </svg>
          Danger Zone
        </h3>

        <div class="space-y-3">
          <button phx-click="reset_portfolio"
                  phx-data-confirm="Reset portfolio? This will remove all sections but keep basic info."
                  class="w-full p-3 bg-white border border-yellow-300 rounded-lg text-yellow-800 hover:bg-yellow-50 transition-colors text-sm font-medium">
            Reset Portfolio
          </button>

          <button phx-click="delete_portfolio"
                  phx-data-confirm="⚠️ DELETE PORTFOLIO? This cannot be undone!"
                  class="w-full p-3 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors text-sm font-medium">
            Delete Forever
          </button>
        </div>
      </div>
    </div>
    """
  end

  defp render_section_preview(section) do
    assigns = %{section: section}

    ~H"""
    <div class="section-preview bg-white rounded-lg border border-gray-200 p-6 mb-4">
      <div class="flex items-center justify-between mb-4">
        <div class="flex items-center">
          <div class="w-10 h-10 bg-gray-100 rounded-lg flex items-center justify-center mr-3">
            <span class="text-lg"><%= get_section_icon(@section.section_type) %></span>
          </div>
          <div>
            <h4 class="font-medium text-gray-900"><%= @section.title %></h4>
            <p class="text-sm text-gray-600">
              <%= if @section.visible, do: "Visible", else: "Hidden" %> •
              Position <%= @section.position %>
            </p>
          </div>
        </div>

        <div class="flex items-center space-x-2">
          <button
            phx-click="edit_section"
            phx-value-section_id={@section.id}
            class="p-2 text-gray-400 hover:text-blue-600 hover:bg-blue-50 rounded-lg transition-colors">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
            </svg>
          </button>

          <button
            phx-click="toggle_section_visibility"
            phx-value-section_id={@section.id}
            class={[
              "p-2 rounded-lg transition-colors",
              if(@section.visible,
                do: "text-green-600 hover:bg-green-50",
                else: "text-gray-400 hover:bg-gray-50")
            ]}>
            <%= if @section.visible do %>
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
              </svg>
            <% else %>
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.878 9.878L3 3m6.878 6.878L21 21"/>
              </svg>
            <% end %>
          </button>

          <button
            phx-click="delete_section"
            phx-value-section_id={@section.id}
            phx-confirm="Are you sure you want to delete this section?"
            class="p-2 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
            </svg>
          </button>
        </div>
      </div>

      <!-- Enhanced Content Preview -->
      <div class="section-content-preview">
        <%= render_section_content_preview(@section) %>
      </div>
    </div>
    """
  end

  defp render_video_intro_section(assigns) do
    # Check if we have valid portfolio data
    portfolio = assigns[:portfolio]
    current_user = assigns[:current_user]

    unless portfolio && current_user do
      # Return empty div if missing required data
      ~H"""
      <div class="bg-yellow-100 border border-yellow-400 rounded-xl p-4">
        <p class="text-yellow-800">Loading video introduction settings...</p>
      </div>
      """
    else
      ~H"""
      <div class="bg-white rounded-xl shadow-sm border p-6">
        <div class="flex items-center justify-between mb-4">
          <div>
            <h3 class="text-lg font-bold text-gray-900 flex items-center">
              <svg class="w-5 h-5 mr-2 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
              </svg>
              Video Introduction
            </h3>
            <p class="text-gray-600">
              Record a <%= get_max_video_duration_safe(assigns) %>-minute personal introduction
            </p>
          </div>
          <button
            phx-click="toggle_video_intro_modal"
            class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors font-medium">
            <%= if has_video_intro?(portfolio) do %>
              Manage Video
            <% else %>
              Record Video
            <% end %>
          </button>
        </div>

        <!-- Current Video Status -->
        <%= if has_video_intro?(portfolio) do %>
          <div class="mt-4 p-4 bg-blue-50 rounded-lg border border-blue-200">
            <div class="flex items-start justify-between">
              <div class="flex items-start">
                <div class="w-16 h-12 bg-blue-200 rounded flex items-center justify-center mr-3 flex-shrink-0">
                  <svg class="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.828 14.828a4 4 0 01-5.656 0M9 10h1m4 0h1m-6 4h8m-8-4a9 9 0 118 0 9 9 0 01-8 0z"/>
                  </svg>
                </div>
                <div>
                  <p class="font-medium text-blue-900">Video Introduction Active</p>
                  <p class="text-sm text-blue-700 mt-1">
                    Video uploaded successfully
                  </p>
                  <div class="flex items-center mt-2 space-x-4">
                    <span class="text-xs bg-green-200 text-green-800 px-2 py-1 rounded-full">
                      Active
                    </span>
                  </div>
                </div>
              </div>
              <div class="flex space-x-2">
                <button
                  phx-click="preview_video_intro"
                  class="px-3 py-1 text-blue-600 hover:bg-blue-100 rounded text-sm font-medium">
                  Preview
                </button>
                <button
                  phx-click="remove_video_intro"
                  phx-confirm="Are you sure you want to remove your video introduction?"
                  class="px-3 py-1 text-red-600 hover:bg-red-50 rounded text-sm">
                  Remove
                </button>
              </div>
            </div>
          </div>
        <% else %>
          <div class="mt-4 p-6 border-2 border-dashed border-gray-300 rounded-lg text-center">
            <svg class="w-12 h-12 mx-auto text-gray-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
            </svg>
            <h4 class="text-lg font-medium text-gray-900 mb-2">Record Your Introduction</h4>
            <p class="text-gray-600 mb-2">
              Make a great first impression with a personal video introduction
            </p>
            <p class="text-sm text-blue-600 mb-4">
              <%= get_account_tier_message_safe(assigns) %>
            </p>
            <button
              phx-click="toggle_video_intro_modal"
              class="px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors font-medium">
              Start Recording
            </button>
          </div>
        <% end %>
      </div>
      """
    end
  end

  defp render_section_form_errors(assigns) do
    ~H"""
    <%= if Map.get(assigns, :section_changeset_errors, []) != [] do %>
      <div class="mb-4 p-4 bg-red-50 border border-red-200 rounded-lg">
        <h4 class="text-sm font-medium text-red-800 mb-2">Please fix the following errors:</h4>
        <ul class="text-sm text-red-700 space-y-1">
          <%= for {field, {message, _details}} <- @section_changeset_errors do %>
            <li>• <%= String.capitalize(to_string(field)) %> <%= message %></li>
          <% end %>
        </ul>
      </div>
    <% end %>
    """
  end

  defp render_section_content_preview(section) do
    try do
      # Use the enhanced section renderer for preview
      FrestylWeb.PortfolioLive.Components.EnhancedSectionRenderer.render_section_content(
        section.content,
        %{section: section}
      )
    rescue
      _ ->
        # Fallback to simple preview
        render_simple_content_preview(section)
    end
  end

  defp render_simple_content_preview(section) do
    content = section.content || %{}

    case to_string(section.section_type) do
      "experience" ->
        jobs = Map.get(content, "jobs", Map.get(content, "items", []))
        case jobs do
          [job | _] when is_map(job) ->
            """
            <div class="text-sm text-gray-600">
              <p><strong>#{Map.get(job, "title", "")}</strong> at #{Map.get(job, "company", "")}</p>
              <p>#{String.slice(Map.get(job, "description", ""), 0, 100)}...</p>
            </div>
            """
          _ ->
            "<p class=\"text-sm text-gray-500\">No experience entries</p>"
        end

      "skills" ->
        skills = Map.get(content, "skills", [])
        if length(skills) > 0 do
          skills_preview = skills |> Enum.take(5) |> Enum.join(", ")
          "<p class=\"text-sm text-gray-600\">#{skills_preview}#{if length(skills) > 5, do: "...", else: ""}</p>"
        else
          "<p class=\"text-sm text-gray-500\">No skills listed</p>"
        end

      _ ->
        description = Map.get(content, "content", Map.get(content, "description", ""))
        if description != "" do
          "<p class=\"text-sm text-gray-600\">#{String.slice(description, 0, 150)}...</p>"
        else
          "<p class=\"text-sm text-gray-500\">No content</p>"
        end
    end
  end

  defp get_max_video_duration(user) do
    # Simple default until you integrate account tiers
    case Map.get(user || %{}, :account_tier, :free) do
      :pro -> 2
      :premium -> 3
      _ -> 1
    end
  end

  defp get_account_tier_message(user) do
    case get_max_video_duration(user) do
      1 -> "Free tier: Up to 1 minute recording"
      2 -> "Pro tier: Up to 2 minute recording"
      3 -> "Premium tier: Up to 3 minute recording"
      _ -> "Record your introduction video"
    end
  end

  defp get_current_video_url(portfolio) do
    customization = portfolio.customization || %{}
    Map.get(customization, "video_url", "")
  end

  defp get_current_video_title(portfolio) do
    customization = portfolio.customization || %{}
    Map.get(customization, "video_title", "")
  end

  defp get_current_video_description(portfolio) do
    customization = portfolio.customization || %{}
    Map.get(customization, "video_description", "")
  end

  defp get_video_intro_info(portfolio) do
    customization = portfolio.customization || %{}

    cond do
      Map.get(customization, "video_recorded_at") ->
        "Recorded on #{format_date(Map.get(customization, "video_recorded_at"))}"
      Map.get(customization, "video_url") ->
        "Video uploaded"
      true ->
        "Video available"
    end
  end

  defp get_video_duration(portfolio) do
    customization = portfolio.customization || %{}
    duration = Map.get(customization, "video_duration", 0)

    if duration > 0 do
      minutes = div(duration, 60)
      seconds = rem(duration, 60)
      "#{minutes}:#{String.pad_leading(to_string(seconds), 2, "0")}"
    else
      "Unknown"
    end
  end

  defp format_date(date_string) when is_binary(date_string) do
    case DateTime.from_iso8601(date_string) do
      {:ok, datetime, _} -> Calendar.strftime(datetime, "%B %d, %Y")
      _ -> "Recently"
    end
  end
  defp format_date(_), do: "Recently"

  # Section Creation Dropdown
  defp render_section_creation_dropdown(assigns) do
    # Get organized categories in priority order
    organized_categories = get_organized_section_categories()
    assigns = Map.put(assigns, :organized_categories, organized_categories)

    ~H"""
    <div class="fixed inset-0 bg-black bg-opacity-25 flex items-start justify-center pt-20 z-50"
        phx-click="close_create_dropdown">
      <div class="bg-white rounded-xl shadow-2xl max-w-5xl w-full mx-4 max-h-[85vh] overflow-hidden"
          phx-click-away="close_create_dropdown">

        <!-- Enhanced Header -->
        <div class="p-6 border-b border-gray-200 bg-gradient-to-r from-blue-50 to-purple-50">
          <div class="flex items-center justify-between">
            <div>
              <h3 class="text-xl font-bold text-gray-900">Add New Section</h3>
              <p class="text-gray-600 mt-1">Choose from our organized collection of portfolio sections</p>
            </div>
            <button phx-click="close_create_dropdown"
                    class="p-2 text-gray-400 hover:text-gray-600 rounded-lg hover:bg-white hover:shadow-sm transition-all">
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>

          <!-- Quick Stats -->
          <div class="flex items-center mt-4 space-x-6 text-sm text-gray-600">
            <div class="flex items-center">
              <div class="w-2 h-2 bg-green-500 rounded-full mr-2"></div>
              <span><%= get_total_section_count() %> section types available</span>
            </div>
            <div class="flex items-center">
              <div class="w-2 h-2 bg-blue-500 rounded-full mr-2"></div>
              <span>Organized into <%= length(@organized_categories) %> categories</span>
            </div>
          </div>
        </div>

        <!-- Category Navigation (Optional - for large collections) -->
        <div class="px-6 py-3 bg-gray-50 border-b border-gray-200">
          <div class="flex items-center space-x-4 overflow-x-auto">
            <%= for {category_key, category_data} <- @organized_categories do %>
              <button class="flex-shrink-0 px-3 py-1 text-sm font-medium text-gray-600 hover:text-gray-900 hover:bg-white rounded-lg transition-all"
                      onclick={"document.getElementById('category-#{category_key}').scrollIntoView({behavior: 'smooth'})"}>
                <span class="mr-1"><%= category_data.icon %></span>
                <%= category_data.name %>
                <span class="ml-1 text-xs text-gray-400">(<%= length(category_data.sections) %>)</span>
              </button>
            <% end %>
          </div>
        </div>

        <!-- Main Content Area -->
        <div class="p-6 overflow-y-auto max-h-[60vh] bg-gray-25">
          <%= for {category_key, category_data} <- @organized_categories do %>
            <div class="mb-8" id={"category-#{category_key}"}>
              <!-- Enhanced Category Header -->
              <div class="flex items-center mb-6">
                <div class="w-12 h-12 rounded-xl flex items-center justify-center mr-4"
                    style={"background: linear-gradient(135deg, #{category_data.color} 0%, #{darken_color(category_data.color)} 100%)"}>
                  <span class="text-white text-xl"><%= category_data.icon %></span>
                </div>
                <div class="flex-1">
                  <div class="flex items-center">
                    <h4 class="text-lg font-bold text-gray-900"><%= category_data.name %></h4>
                    <%= if category_data.badge do %>
                      <span class="ml-3 px-2 py-1 text-xs font-semibold bg-green-100 text-green-800 rounded-full">
                        <%= category_data.badge %>
                      </span>
                    <% end %>
                  </div>
                  <p class="text-sm text-gray-600 mt-1"><%= category_data.description %></p>
                </div>
              </div>

              <!-- Section Cards Grid -->
              <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                <%= for {section_key, section_config} <- category_data.sections do %>
                  <button phx-click="create_section"
                          phx-value-section_type={section_key}
                          class="section-type-card text-left p-4 border-2 border-gray-200 rounded-xl hover:border-blue-300 hover:shadow-lg transition-all duration-200 group bg-white">
                    <div class="flex items-start">
                      <!-- Enhanced Icon -->
                      <div class="w-11 h-11 rounded-xl flex items-center justify-center mr-3 group-hover:scale-110 transition-transform"
                          style={"background: linear-gradient(135deg, #{category_data.color} 0%, #{darken_color(category_data.color)} 100%)"}>
                        <span class="text-white text-lg"><%= section_config.icon %></span>
                      </div>

                      <!-- Content -->
                      <div class="flex-1 min-w-0">
                        <h5 class="font-semibold text-gray-900 group-hover:text-blue-600 transition-colors text-sm">
                          <%= section_config.name %>
                        </h5>
                        <p class="text-xs text-gray-600 mt-1 line-clamp-2 leading-relaxed">
                          <%= section_config.description %>
                        </p>

                        <!-- Enhanced Features/Tags -->
                        <div class="flex items-center mt-2 space-x-1">
                          <%= if Map.get(section_config, :supports_video) do %>
                            <span class="inline-flex items-center px-1.5 py-0.5 rounded text-xs font-medium bg-purple-100 text-purple-800">
                              📹
                            </span>
                          <% end %>
                          <%= if Map.get(section_config, :supports_media) do %>
                            <span class="inline-flex items-center px-1.5 py-0.5 rounded text-xs font-medium bg-blue-100 text-blue-800">
                              🖼️
                            </span>
                          <% end %>
                          <%= if Map.get(section_config, :is_hero) do %>
                            <span class="inline-flex items-center px-1.5 py-0.5 rounded text-xs font-medium bg-yellow-100 text-yellow-800">
                              ⭐
                            </span>
                          <% end %>
                        </div>
                      </div>
                    </div>

                    <!-- Hover Effect Arrow -->
                    <div class="opacity-0 group-hover:opacity-100 transition-opacity mt-3 flex justify-end">
                      <svg class="w-4 h-4 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 8l4 4m0 0l-4 4m4-4H3"/>
                      </svg>
                    </div>
                  </button>
                <% end %>
              </div>
            </div>
          <% end %>

          <!-- Help Footer -->
          <div class="mt-8 p-4 bg-blue-50 border border-blue-200 rounded-xl">
            <div class="flex items-start">
              <svg class="w-5 h-5 text-blue-600 mt-0.5 mr-3 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
              </svg>
              <div>
                <h5 class="font-medium text-blue-900 mb-1">Need help choosing?</h5>
                <p class="text-sm text-blue-800">
                  Start with <strong>Essential</strong> sections, then add <strong>Professional</strong> sections to showcase your expertise.
                  <strong>Business</strong> sections are great for freelancers and agencies.
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

defp render_video_intro_modal(assigns) do
  ~H"""
  <div
    id="video-modal-overlay"
    class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50"
    style="z-index: 9999;"
    phx-click="modal_overlay_clicked"
    phx-window-keydown="modal_keydown"
    phx-key="Escape">

    <div
      id="video-modal-content"
      class="bg-white rounded-xl max-w-4xl w-full mx-4 max-h-[95vh] overflow-hidden"
      phx-click="modal_content_clicked">

      <!-- Modal Header -->
      <div class="p-6 border-b border-gray-200 bg-gradient-to-r from-red-50 to-blue-50">
        <div class="flex items-center justify-between">
          <div>
            <h3 class="text-xl font-bold text-gray-900 flex items-center">
              <div class="w-10 h-10 bg-red-100 rounded-full flex items-center justify-center mr-3">
                <svg class="w-6 h-6 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
                </svg>
              </div>
              Video Introduction
            </h3>
            <p class="text-gray-600 mt-1">
              Record or upload a <%= get_max_video_duration_safe(assigns) %>-minute introduction video
            </p>
          </div>
          <button
            phx-click="close_video_intro_modal"
            class="p-2 text-gray-400 hover:text-gray-600 rounded-lg hover:bg-gray-100 transition-all">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </button>
        </div>

        <!-- Account Tier Info -->
        <div class="mt-4 flex items-center justify-between">
          <div class="flex items-center text-sm text-gray-600">
            <svg class="w-4 h-4 mr-2 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
            </svg>
            <%= get_account_tier_message_safe(assigns) %>
          </div>
          <div class="text-sm text-green-600 font-medium">
            HD Quality • <%= get_max_video_duration_safe(assigns) %> min max
          </div>
        </div>
      </div>

      <!-- NEW FEATURE: Tab Navigation -->
      <div class="border-b border-gray-200">
        <nav class="flex">
          <button
            phx-click="switch_video_tab"
            phx-value-tab="record"
            class={[
              "px-6 py-3 font-medium text-sm border-b-2 transition-colors",
              if(Map.get(assigns, :video_tab, "record") == "record",
                do: "border-red-500 text-red-600 bg-red-50",
                else: "border-transparent text-gray-500 hover:text-gray-700")
            ]}>
            🎥 Record New
          </button>
          <button
            phx-click="switch_video_tab"
            phx-value-tab="upload"
            class={[
              "px-6 py-3 font-medium text-sm border-b-2 transition-colors",
              if(Map.get(assigns, :video_tab, "record") == "upload",
                do: "border-blue-500 text-blue-600 bg-blue-50",
                else: "border-transparent text-gray-500 hover:text-gray-700")
            ]}>
            📤 Upload Existing
          </button>
        </nav>
      </div>

      <!-- Main Content -->
      <div class="overflow-y-auto max-h-[70vh]">
        <%= case Map.get(assigns, :video_tab, "record") do %>
          <% "record" -> %>
            <%= render_video_recording_tab(assigns) %>
          <% "upload" -> %>
            <%= render_video_upload_tab(assigns) %>
        <% end %>
      </div>
    </div>
  </div>
  """
end

@impl true
def handle_event("switch_video_tab", %{"tab" => tab}, socket) do
  IO.puts("🎬 Switching video tab to: #{tab}")
  {:noreply, assign(socket, :video_tab, tab)}
end

  defp render_video_recording_tab(assigns) do
    ~H"""
    <div class="p-6">
      <!-- Enhanced Video Recording Component Integration -->
      <.live_component
        module={FrestylWeb.PortfolioLive.EnhancedVideoIntroComponent}
        id={"video-intro-recorder-modal-#{@portfolio.id}"}
        portfolio={@portfolio}
        current_user={@current_user}
        max_duration={get_max_video_duration_safe(assigns) * 60}
        mode="modal"
        auto_initialize={true}
        show_upload_option={false}
        on_video_saved="video_intro_saved"
        on_video_deleted="video_intro_deleted"
      />

      <!-- Recording Instructions -->
      <div class="mt-6 bg-blue-50 border border-blue-200 rounded-xl p-4">
        <h5 class="font-semibold text-blue-900 mb-3 flex items-center">
          <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
          </svg>
          📹 Recording Tips for Success
        </h5>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm text-blue-800">
          <div>
            <h6 class="font-medium mb-2">📸 Visual Setup:</h6>
            <ul class="space-y-1">
              <li>• Ensure good lighting on your face</li>
              <li>• Position camera at eye level</li>
              <li>• Clean, professional background</li>
              <li>• Look directly at the camera</li>
            </ul>
          </div>
          <div>
            <h6 class="font-medium mb-2">🎤 Audio & Content:</h6>
            <ul class="space-y-1">
              <li>• Speak clearly and at normal pace</li>
              <li>• Keep introduction to 30-90 seconds</li>
              <li>• Introduce yourself and your expertise</li>
              <li>• End with a call-to-action</li>
            </ul>
          </div>
        </div>
      </div>
    </div>
    """
  end


defp render_video_upload_tab(assigns) do
  ~H"""
  <div class="p-6">
    <div class="max-w-2xl mx-auto">
      <!-- Upload Tips -->
      <div class="mt-8 bg-green-50 border border-green-200 rounded-xl p-4">
        <h5 class="font-semibold text-green-900 mb-2 flex items-center">
          <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
          </svg>
          💡 Upload Tips
        </h5>
        <ul class="text-sm text-green-800 space-y-1">
          <li>• Upload your video to YouTube, Vimeo, or a file hosting service first</li>
          <li>• Ensure your video is publicly accessible (not private)</li>
          <li>• Test the URL in a browser before adding it here</li>
          <li>• HD quality (720p or higher) recommended for best results</li>
        </ul>
      </div>
    </div>
  </div>
  """
end


  @impl true
  def handle_event("start_recording", _params, socket) do
    # For now, just show a message. Later, integrate with your recording component
    {:noreply, socket
      |> put_flash(:info, "Recording feature will be integrated with EnhancedVideoIntroComponent")}
  end

  @impl true
  def handle_event("show_upload_option", _params, socket) do
    {:noreply, assign(socket, :show_upload_option, true)}
  end

  @impl true
  def handle_event("hide_upload_option", _params, socket) do
    {:noreply, assign(socket, :show_upload_option, false)}
  end

  @impl true
  def handle_event("upload_video_intro", params, socket) do
    video_data = %{
      "video_url" => params["video_url"],
      "video_source" => "upload",
      "video_uploaded_at" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    case Portfolios.update_portfolio_customization_by_id(socket.assigns.portfolio.id, video_data) do
      {:ok, updated_portfolio} ->
        broadcast_portfolio_update(
          updated_portfolio.id,
          socket.assigns.sections,
          updated_portfolio.customization
        )

        {:noreply, socket
          |> assign(:portfolio, updated_portfolio)
          |> assign(:customization, updated_portfolio.customization)
          |> assign(:show_video_intro_modal, false)
          |> assign(:show_upload_option, false)
          |> put_flash(:info, "Video uploaded successfully!")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to upload video")}
    end
  end

@impl true
def handle_event("video_intro_saved", %{"video_data" => video_data}, socket) do
  IO.puts("🎬 Video intro saved successfully")

  # Update portfolio with video data
  case Portfolios.update_portfolio_customization_by_id(socket.assigns.portfolio.id, video_data) do
    {:ok, updated_portfolio} ->
      # Single broadcast
      broadcast_portfolio_update(
        updated_portfolio.id,
        socket.assigns.sections,
        updated_portfolio.customization,
        :customization
      )

      {:noreply, socket
        |> assign(:portfolio, updated_portfolio)
        |> assign(:customization, updated_portfolio.customization)
        |> assign(:show_video_intro_modal, false)
        |> put_flash(:info, "🎉 Video introduction saved successfully!")}

    {:error, _changeset} ->
      {:noreply, put_flash(socket, :error, "Failed to save video introduction")}
  end
end

  @impl true
  def handle_event("video_intro_deleted", _params, socket) do
    IO.puts("🎬 Video intro deleted")

    video_removal = %{
      "video_url" => nil,
      "video_title" => nil,
      "video_description" => nil,
      "video_position" => nil
    }

    case Portfolios.update_portfolio_customization_by_id(socket.assigns.portfolio.id, video_removal) do
      {:ok, updated_portfolio} ->
        # Single broadcast
        broadcast_portfolio_update(
          updated_portfolio.id,
          socket.assigns.sections,
          updated_portfolio.customization,
          :customization
        )

        {:noreply, socket
          |> assign(:portfolio, updated_portfolio)
          |> assign(:customization, updated_portfolio.customization)
          |> put_flash(:info, "Video introduction removed")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to remove video introduction")}
    end
  end

  @impl true
  def handle_event("preview_video_intro", _params, socket) do
    # Open video preview modal or redirect to preview
    {:noreply, socket
      |> assign(:show_video_preview_modal, true)}
  end

  @impl true
  def handle_event("toggle_advanced_options", _params, socket) do
    current_state = Map.get(socket.assigns, :show_advanced_options, false)
    {:noreply, assign(socket, :show_advanced_options, !current_state)}
  end

  @impl true
  def handle_event("update_custom_css", %{"custom_css" => custom_css}, socket) do
    customization_params = %{"custom_css" => custom_css}

    case Portfolios.update_portfolio_customization_by_id(socket.assigns.portfolio, customization_params) do
      {:ok, updated_portfolio} ->
        {:noreply, socket
          |> assign(:portfolio, updated_portfolio)
          |> put_flash(:info, "Custom CSS updated")}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update custom CSS")}
    end
  end

  @impl true
  def handle_event("update_seo_settings", params, socket) do
    seo_params = Map.take(params, ["meta_title", "meta_description"])

    case Portfolios.update_portfolio_customization_by_id(socket.assigns.portfolio, seo_params) do
      {:ok, updated_portfolio} ->
        {:noreply, socket
          |> assign(:portfolio, updated_portfolio)
          |> put_flash(:info, "SEO settings updated")}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update SEO settings")}
    end
  end

  @impl true
  def handle_event("migrate_to_new_design", _params, socket) do
    # Migrate legacy customizations to new system
    legacy_customization = socket.assigns.portfolio.customization || %{}

    # Map old layout types to new ones
    new_layout = case Map.get(legacy_customization, "layout") do
      "dashboard" -> "workspace"
      "timeline" -> "single"
      "magazine" -> "single"
      "minimal" -> "single"
      _ -> "single"
    end

    # Map old color schemes
    new_color_scheme = case Map.get(legacy_customization, "color_scheme") do
      "blue" -> "professional"
      "purple" -> "creative"
      "green" -> "tech"
      "orange" -> "warm"
      _ -> "professional"
    end

    migration_params = %{
      "layout_style" => new_layout,
      "color_scheme" => new_color_scheme,
      "typography" => "sans",
      "migrated_to_new_design" => true,
      "migration_date" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "legacy_backup" => Map.take(legacy_customization, ["layout", "theme", "color_scheme"])
    }

    case Portfolios.update_portfolio_customization_by_id(socket.assigns.portfolio, migration_params) do
      {:ok, updated_portfolio} ->
        {:noreply, socket
          |> assign(:portfolio, updated_portfolio)
          |> put_flash(:info, "Successfully migrated to new design system!")}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to migrate design settings")}
    end
  end

  defp find_hero_section(sections) when is_list(sections) do
    Enum.find(sections, fn section ->
      section_type = Map.get(section, :section_type) || Map.get(section, "section_type")
      to_string(section_type) in ["hero", "intro", "video_intro"]
    end)
  end
  defp find_hero_section(_), do: nil

  defp get_organized_section_categories do
    # Get all sections from the enhanced section system
    all_sections = EnhancedSectionSystem.get_sections_by_category()

    # Define our organized category structure with proper ordering and metadata
    [
      {
        "essential",
        %{
          name: "Essential",
          description: "The fundamental sections every portfolio needs",
          icon: "⭐",
          color: "#3B82F6",
          badge: "Most Popular",
          sections: filter_sections_by_keys(all_sections, [
            "intro", "about", "experience", "skills", "projects", "contact"
          ])
        }
      },
      {
        "professional",
        %{
          name: "Professional Development",
          description: "Showcase your growth, credentials, and expertise",
          icon: "🎓",
          color: "#059669",
          badge: nil,
          sections: filter_sections_by_keys(all_sections, [
            "education", "certifications", "achievements", "speaking",
            "publications", "timeline"
          ])
        }
      },
      {
        "business",
        %{
          name: "Business & Services",
          description: "Perfect for freelancers, consultants, and service providers",
          icon: "💼",
          color: "#7C3AED",
          badge: nil,
          sections: filter_sections_by_keys(all_sections, [
            "services", "pricing", "process", "faq"
          ])
        }
      },
      {
        "creative",
        %{
          name: "Creative & Media",
          description: "Showcase your creative work and media content",
          icon: "🎨",
          color: "#DB2777",
          badge: nil,
          sections: filter_sections_by_keys(all_sections, [
            "gallery", "video", "writing", "media", "portfolio_showcase"
          ])
        }
      },
      {
        "social_proof",
        %{
          name: "Social Proof & Network",
          description: "Build trust through testimonials and connections",
          icon: "💬",
          color: "#10B981",
          badge: nil,
          sections: filter_sections_by_keys(all_sections, [
            "testimonials", "case_studies", "team", "network"
          ])
        }
      },
      {
        "flexible",
        %{
          name: "Flexible & Advanced",
          description: "Custom solutions and advanced integrations",
          icon: "⚙️",
          color: "#F59E0B",
          badge: nil,
          sections: filter_sections_by_keys(all_sections, [
            "custom", "cta", "embed"
          ])
        }
      }
    ]
  end

  defp filter_sections_by_keys(all_sections, target_keys) do
    all_sections
    |> Enum.flat_map(fn {_category, sections} -> sections end)
    |> Enum.filter(fn {section_key, _config} -> section_key in target_keys end)
    |> Enum.sort_by(fn {section_key, _config} ->
      Enum.find_index(target_keys, &(&1 == section_key)) || 999
    end)
  end

  # Helper function to get total section count for stats
  defp get_total_section_count do
    EnhancedSectionSystem.get_sections_by_category()
    |> Enum.map(fn {_category, sections} -> length(sections) end)
    |> Enum.sum()
  end

  defp get_portfolio_customization(portfolio) when is_map(portfolio) do
    customization = Map.get(portfolio, :customization) || Map.get(portfolio, "customization") || %{}

    # Ensure it's a map
    case customization do
      map when is_map(map) -> map
      _ -> %{}
    end
  end
  defp get_portfolio_customization(_), do: %{}

  defp get_current_user_from_session(session) do
    # Adjust this based on how you store user data in session
    case session do
      %{"user_token" => token} when is_binary(token) ->
        # Load user from token - adjust this to match your auth system
        case Frestyl.Accounts.get_user_by_session_token(token) do
          %{} = user -> user
          _ -> nil
        end
      %{"current_user" => user} when is_map(user) ->
        user
      _ ->
        # Default user for demo/development
        %{id: 1, name: "Demo User", email: "demo@example.com", account_tier: :free}
    end
  end

  defp get_default_customization do
    %{
      "layout_style" => "mobile_single",
      "color_scheme" => "blue",
      "font_style" => "inter",
      "section_spacing" => "normal",
      "corner_radius" => "rounded"
    }
  end

  defp update_section(socket, params) do
    section_id = String.to_integer(params["section_id"])
    section = Enum.find(socket.assigns.sections, &(&1.id == section_id))

    if section do
      title = params["title"]
      visible = params["visible"] == "true"
      content = extract_section_content_from_params(to_string(section.section_type), params)

      case Portfolios.update_section(section, %{title: title, content: content, visible: visible}) do
        {:ok, updated_section} ->
          updated_sections = Enum.map(socket.assigns.sections, fn s ->
            if s.id == section_id, do: updated_section, else: s
          end)

          hero_section = if to_string(section.section_type) == "hero" do
            updated_section
          else
            socket.assigns.hero_section
          end

          {:noreply, socket
          |> assign(:sections, updated_sections)
          |> assign(:hero_section, hero_section)
          |> assign(:show_section_modal, false)
          |> assign(:current_section_type, nil)
          |> assign(:editing_section, nil)
          |> put_flash(:info, "Section updated successfully")}

        {:error, changeset} ->
          {:noreply, socket
          |> put_flash(:error, "Failed to update section: #{inspect(changeset.errors)}")}
      end
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  defp extract_complex_array_from_params(params, field_key, field_config) do
    IO.puts("🔍 EXTRACTING COMPLEX ARRAY: #{field_key}")

    item_fields = Map.get(field_config, :item_fields, %{})

    # Find all items by looking for indexed parameters
    item_indices = params
    |> Map.keys()
    |> Enum.filter(&String.starts_with?(&1, "#{field_key}["))
    |> Enum.map(fn key ->
      case Regex.run(~r/#{field_key}\[(\d+)\]/, key) do
        [_, index] -> String.to_integer(index)
        _ -> nil
      end
    end)
    |> Enum.filter(&(&1 != nil))
    |> Enum.uniq()
    |> Enum.sort()

    # Extract each item
    items = Enum.map(item_indices, fn index ->
      Enum.reduce(item_fields, %{}, fn {sub_field_name, _sub_field_config}, item_acc ->
        sub_field_key = "#{field_key}[#{index}][#{sub_field_name}]"
        value = params[sub_field_key] || ""
        Map.put(item_acc, Atom.to_string(sub_field_name), value)
      end)
    end)

    %{field_key => items}
  end

  defp extract_section_content_from_params(section_type, params) do
    IO.puts("🔍 EXTRACTING CONTENT FOR: #{section_type}")

    # Simplified content extraction that doesn't rely on complex field configs
    case section_type do
      "intro" ->
        %{
          "summary" => params["summary"] || params["content"] || "",
          "website" => params["website"] || "",
          "email" => params["email"] || "",
          "phone" => params["phone"] || ""
        }

      "experience" ->
        %{
          "title" => params["title"] || params["job_title"] || "",
          "company" => params["company"] || "",
          "description" => params["description"] || params["content"] || "",
          "start_date" => params["start_date"] || "",
          "end_date" => params["end_date"] || "",
          "current" => params["current"] == "true"
        }

      "skills" ->
        skills_text = params["skills"] || params["content"] || ""
        skills = if skills_text != "" do
          skills_text
          |> String.split([",", "\n", ";"])
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))
        else
          []
        end

        %{
          "skills" => skills,
          "description" => params["description"] || ""
        }

      "contact" ->
        %{
          "email" => params["email"] || "",
          "phone" => params["phone"] || "",
          "location" => params["location"] || "",
          "website" => params["website"] || ""
        }

      _ ->
        # Generic fallback for any section type
        %{
          "content" => params["content"] || params["description"] || "Add your content here...",
          "title" => params["title"] || "",
          "description" => params["description"] || "",
          "main_content" => params["main_content"] || params["content"] || ""
        }
    end
  end

  defp extract_content_from_params(section_type, params) do
    IO.puts("🔍 SIMPLE CONTENT EXTRACTION FOR: #{section_type}")
    IO.puts("🔍 PARAMS: #{inspect(Map.keys(params))}")

    # Just grab the main content field and title
    content = %{
      "content" => params["content"] || params["description"] || params["summary"] || "",
      "title" => params["title"] || "",
      "description" => params["description"] || ""
    }

    # Add any other fields that exist in params
    additional_content = params
    |> Enum.filter(fn {key, value} ->
      key not in ["title", "content", "description", "visible", "section_id", "_target", "action"] and
      value != "" and not is_nil(value)
    end)
    |> Map.new()

    final_content = Map.merge(content, additional_content)

    IO.puts("🔍 FINAL CONTENT: #{inspect(final_content)}")
    final_content
  end

  # Missing function: get_default_customization/0
  defp get_default_customization do
    %{
      "layout_style" => "mobile_single",
      "color_scheme" => "blue",
      "font_style" => "inter",
      "section_spacing" => "normal",
      "corner_radius" => "rounded",
      "theme" => "professional",
      "primary_color" => "#3B82F6",
      "secondary_color" => "#1D4ED8",
      "accent_color" => "#60A5FA"
    }
  end

  # Missing function: get_current_user_from_session/1
  defp get_current_user_from_session(_session) do
    # This should extract user from session - implement based on your auth system
    %{id: 1, name: "Demo User", email: "demo@example.com"}
  end

  # Missing function: update_section_in_list/2
  defp update_section_in_list(sections, updated_section) do
    Enum.map(sections, fn section ->
      if section.id == updated_section.id do
        updated_section
      else
        section
      end
    end)
  end

  defp extract_customization_params(params) do
    IO.puts("🔍 EXTRACTING CUSTOMIZATION FROM: #{inspect(params)}")

    # Define all possible customization fields that your system supports
    valid_customization_fields = [
      "primary_color", "secondary_color", "accent_color",
      "font_family", "font_style", "layout_style", "hero_style",
      "portfolio_layout", "color_scheme", "theme",
      "section_spacing", "corner_radius", "border_radius",
      "custom_css", "professional_type"
    ]

    # Filter and extract only valid customization fields
    result = params
    |> Enum.filter(fn {key, value} ->
      is_valid = key in valid_customization_fields and
                not is_nil(value) and
                value != "" and
                key != "_target"  # Exclude LiveView form metadata

      if is_valid do
        IO.puts("✅ VALID CUSTOMIZATION PARAM: #{key} = #{value}")
      else
        IO.puts("❌ FILTERED OUT: #{key} = #{inspect(value)}")
      end

      is_valid
    end)
    |> Map.new()

    IO.puts("🔍 EXTRACTION RESULT: #{inspect(result)}")
    result
  end

  # Add this function to handle content extraction from form params:
  defp extract_content_from_params(section_type, params) do
    IO.puts("🔍 EXTRACTING CONTENT FOR: #{section_type}")
    IO.puts("🔍 FROM PARAMS: #{inspect(params)}")

    # Basic content extraction - adapt based on your section types
    content = case section_type do
      "intro" ->
        %{
          "summary" => params["summary"] || params["content"] || "",
          "website" => params["website"] || "",
          "social_links" => extract_social_links(params)
        }

      "experience" ->
        %{
          "jobs" => extract_jobs_from_params(params)
        }

      "contact" ->
        %{
          "email" => params["email"] || "",
          "phone" => params["phone"] || "",
          "location" => params["location"] || "",
          "social_links" => extract_social_links(params)
        }

      "skills" ->
        %{
          "skills" => extract_skills_from_params(params),
          "description" => params["description"] || params["content"] || ""
        }

      _ ->
        # Generic content for other section types
        %{
          "content" => params["content"] || params["description"] || "Add your content here...",
          "title" => params["title"] || "",
          "description" => params["description"] || ""
        }
    end

    IO.puts("🔍 EXTRACTED CONTENT: #{inspect(content)}")
    content
  end

  defp extract_experience_items_from_params(params) do
    extract_complex_items_from_params(params, "experience", %{
      "title" => :string,
      "company" => :string,
      "start_date" => :string,
      "end_date" => :string,
      "location" => :string,
      "description" => :text,
      "achievements" => :array,
      "skills_used" => :array,
      "is_current" => :boolean
    })
  end

  # Extract project items with proper structure
  defp extract_project_items_from_params(params) do
    extract_complex_items_from_params(params, "projects", %{
      "title" => :string,
      "subtitle" => :string,
      "client" => :string,
      "duration" => :string,
      "status" => :string,
      "description" => :text,
      "technologies" => :array,
      "live_url" => :string,
      "github_url" => :string,
      "featured" => :boolean
    })
  end

  # Extract education items
  defp extract_education_items_from_params(params) do
    extract_complex_items_from_params(params, "education", %{
      "degree" => :string,
      "institution" => :string,
      "start_date" => :string,
      "end_date" => :string,
      "location" => :string,
      "description" => :text,
      "relevant_coursework" => :array,
      "status" => :string
    })
  end

  # Extract testimonial items
  defp extract_testimonial_items_from_params(params) do
    extract_complex_items_from_params(params, "testimonials", %{
      "quote" => :text,
      "author" => :string,
      "title" => :string,
      "company" => :string,
      "photo" => :string,
      "rating" => :string
    })
  end

  # Extract service items
  defp extract_service_items_from_params(params) do
    extract_complex_items_from_params(params, "services", %{
      "name" => :string,
      "description" => :text,
      "duration" => :string,
      "price_range" => :string,
      "includes" => :array,
      "booking_link" => :string,
      "featured" => :boolean
    })
  end

  # Generic complex items extractor
  defp extract_complex_items_from_params(params, field_prefix, field_schema) do
    IO.puts("🔍 EXTRACTING COMPLEX ITEMS: #{field_prefix}")

    # Find all item indices by looking for indexed parameters
    item_indices = params
    |> Map.keys()
    |> Enum.filter(&String.starts_with?(&1, "#{field_prefix}["))
    |> Enum.map(fn key ->
      case Regex.run(~r/#{field_prefix}\[(\d+)\]/, key) do
        [_, index_str] -> String.to_integer(index_str)
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.sort()

    IO.puts("🔍 Found #{length(item_indices)} items")

    # Extract each item
    Enum.map(item_indices, fn index ->
      item = %{}

      # Extract fields based on schema
      item = Enum.reduce(field_schema, item, fn {field_name, field_type}, acc ->
        key = "#{field_prefix}[#{index}][#{field_name}]"
        value = Map.get(params, key, "")

        processed_value = case field_type do
          :boolean -> value == "true"
          :array ->
            # Handle array fields (like achievements, skills_used)
            array_key = "#{field_prefix}[#{index}][#{field_name}][]"
            array_values = params
            |> Enum.filter(fn {k, _v} -> String.starts_with?(k, array_key) end)
            |> Enum.map(fn {_k, v} -> v end)
            |> Enum.reject(&(&1 == ""))

            if length(array_values) > 0, do: array_values, else: []
          _ -> value
        end

        Map.put(acc, field_name, processed_value)
      end)

      # Only include items that have meaningful content
      if has_meaningful_content?(item) do
        item
      else
        nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  # Extract skills with category support
  defp extract_skills_from_params(params) do
    # Check if we have categorized skills
    categories = extract_skill_categories_from_params(params)

    if map_size(categories) > 0 do
      %{
        "categories" => categories,
        "display_style" => Map.get(params, "display_style", "categorized"),
        "show_proficiency" => Map.get(params, "show_proficiency", "true") == "true"
      }
    else
      # Fall back to simple skills list
      skills = extract_array_from_params(params, "skills")
      %{
        "skills" => skills,
        "display_style" => "flat_list",
        "show_proficiency" => false
      }
    end
  end

  # Extract skill categories
  defp extract_skill_categories_from_params(params) do
    # This would extract categorized skills - implement based on your form structure
    # For now, return empty map to use simple skills
    %{}
  end

  # Extract social links
  defp extract_social_links_from_params(params) do
    social_platforms = ["linkedin", "github", "twitter", "instagram", "facebook", "website"]

    Enum.reduce(social_platforms, %{}, fn platform, acc ->
      key = "social_#{platform}"
      value = Map.get(params, key, "")
      if value != "" do
        Map.put(acc, platform, value)
      else
        acc
      end
    end)
  end

  # Extract simple arrays
  defp extract_array_from_params(params, field_name) do
    # Look for array parameters like field_name[]
    array_key = "#{field_name}[]"

    params
    |> Enum.filter(fn {k, _v} -> String.starts_with?(k, array_key) end)
    |> Enum.map(fn {_k, v} -> v end)
    |> Enum.reject(&(&1 == ""))
  end

  # Check if item has meaningful content
  defp has_meaningful_content?(item) when is_map(item) do
    item
    |> Map.values()
    |> Enum.any?(fn value ->
      case value do
        str when is_binary(str) -> String.trim(str) != ""
        list when is_list(list) -> length(list) > 0
        bool when is_boolean(bool) -> true
        _ -> false
      end
    end)
  end
  defp has_meaningful_content?(_), do: false

  # Update the existing extract_content_from_params function to use the new build_section_content
  defp extract_content_from_params(section_type, params) do
    build_section_content(section_type, params)
  end

  # Helper function to extract social links from params
  defp extract_social_links(params) do
    social_platforms = ["linkedin", "twitter", "github", "website", "instagram"]

    social_platforms
    |> Enum.reduce(%{}, fn platform, acc ->
      key = "social_#{platform}"
      case params[key] do
        nil -> acc
        "" -> acc
        url -> Map.put(acc, platform, url)
      end
    end)
  end

  # Helper function to extract jobs from experience params
  defp extract_jobs_from_params(params) do
    # Look for job-related fields
    job = %{
      "title" => params["job_title"] || params["title"] || "",
      "company" => params["company"] || "",
      "description" => params["job_description"] || params["description"] || params["content"] || "",
      "start_date" => params["start_date"] || "",
      "end_date" => params["end_date"] || "",
      "current" => params["current"] == "true"
    }

    # Return as array (can be extended to handle multiple jobs)
    [job]
  end

  # Helper function to extract skills from params
  defp extract_skills_from_params(params) do
    skills_text = params["skills"] || params["content"] || ""

    # Split by comma, newline, or semicolon and clean up
    skills_text
    |> String.split(~r/[,\n;]/)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(fn skill -> %{"name" => skill} end)
  end

  @impl true
  def handle_event("update_customization", params, socket) do
    IO.puts("🎨 CUSTOMIZATION UPDATE RECEIVED")
    IO.puts("🎨 PARAMS: #{inspect(params)}")

    # Simple extraction - just get the first non-metadata param
    customization_param = params
    |> Enum.find(fn {key, value} ->
      key not in ["_target", "_csrf_token"] and value != ""
    end)

    case customization_param do
      {field, value} ->
        IO.puts("🎨 UPDATING: #{field} = #{value}")

        # Update customization directly
        updated_customization = Map.put(socket.assigns.customization, field, value)

        # Try to save to database
        case Portfolios.update_portfolio_customization_by_id(socket.assigns.portfolio.id, %{field => value}) do
          {:ok, updated_portfolio} ->
            IO.puts("✅ CUSTOMIZATION SAVED")

            {:noreply, socket
            |> assign(:portfolio, updated_portfolio)
            |> assign(:customization, updated_portfolio.customization)}

          {:error, reason} ->
            IO.puts("❌ SAVE FAILED: #{inspect(reason)}")

            # Still update UI even if save fails
            {:noreply, socket
            |> assign(:customization, updated_customization)
            |> put_flash(:error, "Design change applied but not saved")}
        end

      nil ->
        IO.puts("❌ NO VALID CUSTOMIZATION PARAM FOUND")
        {:noreply, socket}
    end
  end

    # Catch-all for unhandled events
  @impl true
  def handle_event(event_name, params, socket) do
    IO.puts("🔥 Unhandled event: #{event_name} with params: #{inspect(params)}")
    {:noreply, socket}
  end

  defp broadcast_portfolio_update(portfolio_id, sections, customization, update_type \\ :general) do
    IO.puts("📡 BROADCASTING: #{update_type} for portfolio #{portfolio_id}")

    update_data = %{
      sections: sections,
      customization: customization,
      updated_at: DateTime.utc_now(),
      portfolio_id: portfolio_id,
      update_type: update_type
    }

    # ONLY send ONE message type to avoid loops
    message = case update_type do
      :sections -> {:sections_updated, sections}
      :customization -> {:customization_updated, customization}
      _ -> {:portfolio_updated, update_data}
    end

    # ONLY broadcast to necessary channels
    channels = case update_type do
      :sections -> ["portfolio_preview:#{portfolio_id}"]
      :customization -> ["portfolio_preview:#{portfolio_id}", "portfolio_show:#{portfolio_id}"]
      _ -> ["portfolio_preview:#{portfolio_id}"]
    end

    Enum.each(channels, fn channel ->
      PubSub.broadcast(Frestyl.PubSub, channel, message)
    end)
  end



  defp generate_css_from_customization(customization) do
    layout_style = Map.get(customization, "layout_style", "single")
    color_scheme = Map.get(customization, "color_scheme", "professional")
    typography = Map.get(customization, "typography", "sans")

    """
    :root {
      --layout-style: #{layout_style};
      --color-scheme: #{color_scheme};
      --typography: #{typography};
      --primary-color: #{get_color_scheme_primary(color_scheme)};
      --secondary-color: #{get_color_scheme_secondary(color_scheme)};
      --accent-color: #{get_color_scheme_accent(color_scheme)};
    }

    .portfolio-layout.#{layout_style}-layout {
      /* Layout-specific styles will be handled by EnhancedLayoutRenderer */
    }
    """
  end

  defp get_color_scheme_primary(scheme) do
    case scheme do
      "professional" -> "#1e40af"
      "creative" -> "#7c3aed"
      "tech" -> "#059669"
      "warm" -> "#ea580c"
      _ -> "#1e40af"
    end
  end

  defp get_color_scheme_secondary(scheme) do
    case scheme do
      "professional" -> "#3b82f6"
      "creative" -> "#a855f7"
      "tech" -> "#10b981"
      "warm" -> "#f97316"
      _ -> "#3b82f6"
    end
  end

  defp get_color_scheme_accent(scheme) do
    case scheme do
      "professional" -> "#60a5fa"
      "creative" -> "#c084fc"
      "tech" -> "#34d399"
      "warm" -> "#fb923c"
      _ -> "#60a5fa"
    end
  end

  # Color scheme definitions
  defp get_color_schemes do
    %{
      "blue" => ["#3B82F6", "#1D4ED8", "#60A5FA"],
      "purple" => ["#8B5CF6", "#7C3AED", "#A78BFA"],
      "green" => ["#10B981", "#059669", "#34D399"],
      "red" => ["#EF4444", "#DC2626", "#F87171"],
      "orange" => ["#F97316", "#EA580C", "#FB923C"],
      "pink" => ["#EC4899", "#DB2777", "#F472B6"],
      "indigo" => ["#6366F1", "#4F46E5", "#818CF8"],
      "gray" => ["#6B7280", "#4B5563", "#9CA3AF"]
    }
  end

  # Font options
  defp get_font_options do
    %{
      "inter" => %{
        name: "Inter",
        css_name: "Inter, system-ui, sans-serif",
        description: "Modern and clean, great for professional portfolios"
      },
      "poppins" => %{
        name: "Poppins",
        css_name: "Poppins, system-ui, sans-serif",
        description: "Friendly and approachable, perfect for creative work"
      },
      "playfair" => %{
        name: "Playfair Display",
        css_name: "Playfair Display, Georgia, serif",
        description: "Elegant serif font for sophisticated portfolios"
      },
      "source_sans" => %{
        name: "Source Sans Pro",
        css_name: "Source Sans Pro, system-ui, sans-serif",
        description: "Clean and readable, ideal for text-heavy content"
      }
    }
  end

  # Section helper functions
  defp get_section_icon(section_type) do
    case EnhancedSectionSystem.get_section_config(to_string(section_type)) do
      %{icon: icon} -> icon
      _ -> "📄"
    end
  end

  defp get_section_color(section_type) do
    case EnhancedSectionSystem.get_section_config(to_string(section_type)) do
      %{category: "introduction"} -> "#3B82F6"
      %{category: "professional"} -> "#059669"
      %{category: "education"} -> "#7C3AED"
      %{category: "skills"} -> "#DC2626"
      %{category: "work"} -> "#EA580C"
      %{category: "creative"} -> "#DB2777"
      %{category: "business"} -> "#1F2937"
      %{category: "recognition"} -> "#F59E0B"
      %{category: "credentials"} -> "#6366F1"
      %{category: "social_proof"} -> "#10B981"
      %{category: "content"} -> "#8B5CF6"
      %{category: "network"} -> "#06B6D4"
      %{category: "contact"} -> "#EF4444"
      %{category: "narrative"} -> "#F97316"
      _ -> "#6B7280"
    end
  end

  defp get_section_color_by_category(category) do
    case category do
      "introduction" -> "#3B82F6"
      "professional" -> "#059669"
      "education" -> "#7C3AED"
      "skills" -> "#DC2626"
      "work" -> "#EA580C"
      "creative" -> "#DB2777"
      "business" -> "#1F2937"
      "recognition" -> "#F59E0B"
      "credentials" -> "#6366F1"
      "social_proof" -> "#10B981"
      "content" -> "#8B5CF6"
      "network" -> "#06B6D4"
      "contact" -> "#EF4444"
      "narrative" -> "#F97316"
      _ -> "#6B7280"
    end
  end

  defp darken_color(hex_color) do
    case hex_color do
      "#3B82F6" -> "#1D4ED8"
      "#059669" -> "#047857"
      "#7C3AED" -> "#5B21B6"
      "#DC2626" -> "#B91C1C"
      "#EA580C" -> "#C2410C"
      "#DB2777" -> "#BE185D"
      "#1F2937" -> "#111827"
      "#F59E0B" -> "#D97706"
      "#6366F1" -> "#4F46E5"
      "#10B981" -> "#059669"
      "#8B5CF6" -> "#7C3AED"
      "#06B6D4" -> "#0891B2"
      "#EF4444" -> "#DC2626"
      "#F97316" -> "#EA580C"
      _ -> "#4B5563"
    end
  end

  defp get_section_type_name(section_type) do
    case EnhancedSectionSystem.get_section_config(to_string(section_type)) do
      %{name: name} -> name
      _ -> String.capitalize(to_string(section_type))
    end
  end

  # PubSub handlers
  @impl true
  def handle_info({:section_updated, section}, socket) do
    updated_sections = Enum.map(socket.assigns.sections, fn s ->
      if s.id == section.id, do: section, else: s
    end)

    hero_section = if to_string(section.section_type) == "hero" do
      section
    else
      socket.assigns.hero_section
    end

    {:noreply, socket
    |> assign(:sections, updated_sections)
    |> assign(:hero_section, hero_section)}
  end

  @impl true
  def handle_info({:portfolio_updated, data}, socket) do
    sections = Map.get(data, :sections, socket.assigns.sections)
    customization = Map.get(data, :customization, socket.assigns.customization)

    {:noreply, socket
      |> assign(:sections, sections)
      |> assign(:customization, customization)}
  end

  @impl true
  def handle_info({:sections_updated, sections}, socket) do
    {:noreply, assign(socket, :sections, sections)}
  end

  @impl true
  def handle_info({:portfolio_sections_changed, data}, socket) do
    IO.puts("📥 Received portfolio_sections_changed message")

    sections = Map.get(data, :sections, socket.assigns.sections)
    customization = Map.get(data, :customization, socket.assigns.customization)

    {:noreply, socket
      |> assign(:sections, sections)
      |> assign(:customization, customization)}
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:comprehensive_update, data}, socket) do
    IO.puts("📥 Received comprehensive_update")

    sections = Map.get(data, :sections, socket.assigns.sections)
    customization = Map.get(data, :customization, socket.assigns.customization)

    {:noreply, socket
      |> assign(:sections, sections)
      |> assign(:customization, customization)}
  end

  @impl true
  def handle_info({:sections_updated, sections}, socket) do
    IO.puts("📥 Received sections_updated with #{length(sections)} sections")

    # Convert serializable maps back to proper structs if needed
    proper_sections = Enum.map(sections, fn section ->
      case section do
        %{__struct__: _} -> section  # Already a struct
        map when is_map(map) ->      # Convert map to struct-like format
          struct = %{
            id: map["id"] || map[:id],
            title: map["title"] || map[:title],
            section_type: map["section_type"] || map[:section_type],
            content: map["content"] || map[:content] || %{},
            position: map["position"] || map[:position],
            visible: map["visible"] || map[:visible],
            portfolio_id: map["portfolio_id"] || map[:portfolio_id],
            inserted_at: map["inserted_at"] || map[:inserted_at],
            updated_at: map["updated_at"] || map[:updated_at]
          }
          struct
      end
    end)

    {:noreply, assign(socket, :sections, proper_sections)}
  end

  defp debug_socket_state(socket, label) do
    IO.puts("🐛 #{label}")
    IO.puts("🐛 Portfolio ID: #{socket.assigns.portfolio.id}")
    IO.puts("🐛 Sections: #{length(socket.assigns.sections)}")
    IO.puts("🐛 Customization: #{inspect(Map.keys(socket.assigns.customization))}")
    IO.puts("🐛 ====================================")
    socket
  end

  defp debug_section_update(params, section) do
    IO.puts("=== DEBUG SECTION UPDATE ===")
    IO.puts("Section ID: #{section.id}")
    IO.puts("Section Type: #{section.section_type}")
    IO.puts("Current Title: #{section.title}")
    IO.puts("Form Title: #{inspect(params["title"])}")
    IO.puts("Form Items: #{inspect(params["items"])}")
    IO.puts("Form Content: #{inspect(params["content"])}")
    IO.puts("Form Visible: #{inspect(params["visible"])}")
    IO.puts("=============================")
  end

  defp debug_section_content(section) do
    IO.puts("🔍 SECTION DEBUG: #{section.title}")
    IO.puts("🔍 Section type: #{section.section_type}")
    IO.puts("🔍 Content keys: #{inspect(Map.keys(section.content || %{}))}")

    case section.section_type do
      :experience ->
        jobs = Map.get(section.content || %{}, "jobs", [])
        items = Map.get(section.content || %{}, "items", [])
        IO.puts("🔍 Jobs count: #{length(jobs)}")
        IO.puts("🔍 Items count: #{length(items)}")
        if length(jobs) > 0, do: IO.puts("🔍 First job: #{inspect(Enum.at(jobs, 0))}")
      _ ->
        IO.puts("🔍 Content: #{inspect(section.content)}")
    end
  end
end
