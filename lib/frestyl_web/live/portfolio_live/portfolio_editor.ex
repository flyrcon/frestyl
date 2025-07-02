# lib/frestyl_web/live/portfolio_live/portfolio_editor.ex
# UNIFIED PORTFOLIO EDITOR - Replaces all manager modules

defmodule FrestylWeb.PortfolioLive.PortfolioEditor do
  use FrestylWeb, :live_view

  import Ecto.Query
  alias Frestyl.Repo

  alias Frestyl.{Accounts, Analytics, Channels, Portfolios, Streaming}
  alias Frestyl.Portfolios.ContentBlock
  alias Frestyl.Stories.MediaBinding
  alias Frestyl.Accounts.{User, Account}
  alias FrestylWeb.PortfolioLive.PortfolioPerformance

  alias FrestylWeb.PortfolioLive.Components.{ContentRenderer, SectionEditor, MediaLibrary, VideoRecorder}

  # ============================================================================
  # MOUNT - Account-Aware Foundation
  # ============================================================================

  @impl true
  def mount(%{"id" => portfolio_id}, _session, socket) do
    start_time = System.monotonic_time(:millisecond)
    user = socket.assigns.current_user

    # Fix 1: Remove the wrong function call - params doesn't exist here
    # portfolio = get_portfolio_from_params(params, user)  # REMOVE THIS LINE

    # Load portfolio with account context
    case load_portfolio_with_account_and_blocks(portfolio_id, user) do
      {:ok, portfolio, account, content_blocks} ->
        # Account-based feature permissions
        features = get_account_features(account)
        limits = get_account_limits(account)

        # Load portfolio data
        sections = load_portfolio_sections(portfolio.id)
        media_library = load_portfolio_media(portfolio.id)

        # Monetization & streaming data (account-dependent)
        monetization_data = load_monetization_data(portfolio, account)
        streaming_config = load_streaming_config(portfolio, account)

        # Template system with brand control hooks
        available_layouts = get_available_layouts(account)
        brand_constraints = get_brand_constraints(account)

        # Fix 2: Remove duplicate account loading since you already have it from the case statement
        # account = case Frestyl.Accounts.list_user_accounts(user.id) do
        #   [account | _] -> Map.put_new(account, :subscription_tier, "personal")
        #   [] -> %{subscription_tier: "personal"}
        # end

        socket = socket
        |> assign_core_data(portfolio, account, user)
        |> assign_features_and_limits(features, limits)
        |> assign_content_data(sections, media_library, content_blocks)
        |> assign_monetization_data(monetization_data, streaming_config)
        # Fix 3: Pass the correct parameters to assign_design_system
        |> assign_design_system(portfolio, account)  # Changed from (available_layouts, brand_constraints)
        |> assign_ui_state()
        |> assign_live_preview_state()

        load_time = System.monotonic_time(:millisecond) - start_time
        # Fix 4: Add safe call for performance tracking
        track_portfolio_editor_load_safe(portfolio_id, load_time)

        socket = if socket.assigns.show_live_preview do
          broadcast_preview_update(socket)
          socket
        else
          socket
        end

        {:ok, socket}

      {:error, :not_found} ->
        {:ok, socket |> put_flash(:error, "Portfolio not found") |> redirect(to: "/portfolios")}

      {:error, :unauthorized} ->
        {:ok, socket |> put_flash(:error, "Access denied") |> redirect(to: "/portfolios")}
    end
  end

  defp assign_live_preview_state(socket) do
    portfolio = socket.assigns.portfolio

    socket
    |> assign(:show_live_preview, true)
    |> assign(:preview_token, generate_preview_token(portfolio.id))
    |> assign(:preview_mobile_view, false)
    |> assign(:pending_changes, %{})  # CRITICAL: Initialize this
    |> assign(:debounce_timer, nil)   # CRITICAL: Initialize this
  end

  defp generate_preview_token(portfolio_id) do
    :crypto.hash(:sha256, "preview_#{portfolio_id}_#{Date.utc_today()}")
    |> Base.encode16(case: :lower)
  end

  @impl true
  def handle_event("toggle_live_preview", _params, socket) do
    show_preview = !socket.assigns.show_live_preview

    socket = assign(socket, :show_live_preview, show_preview)

    if show_preview do
      # Broadcast initial preview data
      broadcast_preview_update(socket)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_preview_mobile", _params, socket) do
    mobile_view = !socket.assigns.preview_mobile_view

    # Broadcast viewport change to preview
    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "portfolio_preview:#{socket.assigns.portfolio.id}",
      {:viewport_change, mobile_view}
    )

    {:noreply, assign(socket, :preview_mobile_view, mobile_view)}
  end

  @impl true
  def handle_event("update_color", %{"field" => field, "value" => color}, socket) do
    IO.puts("="*50)
    IO.puts("🎨 COLOR CHANGE START: #{field} = #{color}")
    IO.puts("🔍 Before - socket.assigns.customization: #{inspect(socket.assigns.customization)}")
    IO.puts("🔍 Before - socket.assigns.portfolio.customization: #{inspect(socket.assigns.portfolio.customization)}")
    IO.puts("🔍 Before - socket.assigns.primary_color: #{inspect(socket.assigns[:primary_color])}")

    # Use portfolio customization as source of truth
    current_customization = socket.assigns.portfolio.customization || %{}
    IO.puts("🔍 Current customization from portfolio: #{inspect(current_customization)}")

    updated_customization = Map.put(current_customization, field, color)
    IO.puts("🔍 Updated customization: #{inspect(updated_customization)}")

    case Portfolios.update_portfolio(socket.assigns.portfolio, %{customization: updated_customization}) do
      {:ok, updated_portfolio} ->
        IO.puts("✅ Database update successful")
        IO.puts("🔍 Updated portfolio.customization: #{inspect(updated_portfolio.customization)}")

        socket = socket
        |> assign(:portfolio, updated_portfolio)
        |> assign(:customization, updated_portfolio.customization)
        |> assign(:unsaved_changes, false)

        # Update individual color assigns
        socket = case field do
          "primary_color" -> assign(socket, :primary_color, color)
          "accent_color" -> assign(socket, :accent_color, color)
          "secondary_color" -> assign(socket, :secondary_color, color)
          _ -> socket
        end

        IO.puts("🔍 After - socket.assigns.customization: #{inspect(socket.assigns.customization)}")
        IO.puts("🔍 After - socket.assigns.primary_color: #{inspect(socket.assigns[:primary_color])}")
        IO.puts("="*50)

        {:noreply, socket}

      {:error, changeset} ->
        IO.puts("❌ Database update failed: #{inspect(changeset.errors)}")
        IO.puts("="*50)
        error_msg = format_changeset_errors(changeset)
        {:noreply, put_flash(socket, :error, "Failed to save color: #{error_msg}")}
    end
  end

  @impl true
  def handle_event("change_theme", %{"theme" => theme}, socket) do
    IO.puts("🎭 CHANGE THEME: #{theme} (no refresh)")

    case Portfolios.update_portfolio(socket.assigns.portfolio, %{theme: theme}) do
      {:ok, updated_portfolio} ->
        IO.puts("✅ Theme saved: #{theme}")

        # DON'T redirect or refresh, just update socket
        socket = socket
        |> assign(:portfolio, updated_portfolio)
        |> assign(:current_theme, theme)
        |> assign(:unsaved_changes, false)

        {:noreply, socket}  # NO push_event or redirects

      {:error, changeset} ->
        error_msg = format_changeset_errors(changeset)
        {:noreply, put_flash(socket, :error, "Failed to save theme: #{error_msg}")}
    end
  end

  @impl true
  def handle_event("update_layout", %{"value" => layout_value}, socket) do
    IO.puts("🎨 UPDATE LAYOUT: #{layout_value} (no refresh)")

    # Use portfolio customization as source of truth
    current_customization = socket.assigns.portfolio.customization || %{}
    updated_customization = Map.put(current_customization, "layout", layout_value)

    case Portfolios.update_portfolio(socket.assigns.portfolio, %{customization: updated_customization}) do
      {:ok, updated_portfolio} ->
        IO.puts("✅ Layout saved: #{layout_value}")

        # DON'T redirect or refresh, just update socket
        socket = socket
        |> assign(:portfolio, updated_portfolio)
        |> assign(:customization, updated_customization)
        |> assign(:portfolio_layout, layout_value)
        |> assign(:unsaved_changes, false)

        {:noreply, socket}  # NO push_event or redirects

      {:error, changeset} ->
        error_msg = format_changeset_errors(changeset)
        {:noreply, put_flash(socket, :error, "Failed to save layout: #{error_msg}")}
    end
  end


  @impl true
  def handle_event("update_layout", %{"value" => layout_value}, socket) do
    IO.puts("="*50)
    IO.puts("🎯 LAYOUT CHANGE START: #{layout_value}")
    IO.puts("🔍 LAYOUT - socket.assigns.customization: #{inspect(socket.assigns.customization)}")
    IO.puts("🔍 LAYOUT - socket.assigns.portfolio.customization: #{inspect(socket.assigns.portfolio.customization)}")



    # CRITICAL: Preserve existing customization instead of using defaults
    current_customization = socket.assigns.customization || %{}
    updated_customization = Map.put(current_customization, "layout", layout_value)

    # IMMEDIATE UI update (optimistic)
    socket = socket
    |> assign(:customization, updated_customization)
    |> assign(:portfolio_layout, layout_value)
    |> assign(:unsaved_changes, true)

    # IMMEDIATE database save to prevent overwriting
    case Portfolios.update_portfolio(socket.assigns.portfolio, %{customization: updated_customization}) do
      {:ok, updated_portfolio} ->
        IO.puts("✅ Layout saved with preserved colors: #{inspect(updated_customization)}")

        socket = socket
        |> assign(:portfolio, updated_portfolio)
        |> assign(:unsaved_changes, false)

        # IMMEDIATE live preview update
        if socket.assigns.show_live_preview do
          css = generate_simple_preview_css(updated_customization, updated_portfolio.theme)

          Phoenix.PubSub.broadcast(
            Frestyl.PubSub,
            "portfolio_preview:#{socket.assigns.portfolio.id}",
            {:preview_update, updated_customization, css}
          )
        end

        {:noreply, socket}

      {:error, changeset} ->
        error_msg = format_changeset_errors(changeset)
        {:noreply, put_flash(socket, :error, "Failed to save layout: #{error_msg}")}
    end
  end

  @impl true
  def handle_event("toggle_add_section_dropdown", _params, socket) do
    current_state = socket.assigns[:show_add_section_dropdown] || false
    {:noreply, assign(socket, :show_add_section_dropdown, !current_state)}
  end

  @impl true
  def handle_event("close_add_section_dropdown", _params, socket) do
    {:noreply, assign(socket, :show_add_section_dropdown, false)}
  end

  @impl true
  def handle_event("add_section", %{"section_type" => section_type}, socket) do
    portfolio = socket.assigns.portfolio
    sections = socket.assigns.sections
    next_position = length(sections) + 1

    section_attrs = %{
      portfolio_id: portfolio.id,
      section_type: section_type,
      title: get_default_title_for_type(section_type),
      content: get_default_content_for_type(section_type),
      visible: true,
      position: next_position
    }

    case Portfolios.create_section(section_attrs) do
      {:ok, new_section} ->
        updated_sections = sections ++ [new_section]

        socket = socket
        |> assign(:sections, updated_sections)
        |> assign(:show_add_section_dropdown, false)
        |> put_flash(:info, "#{format_section_type(section_type)} section added successfully!")
        |> assign(:unsaved_changes, false)

        {:noreply, socket}

      {:error, changeset} ->
        error_msg = format_changeset_errors(changeset)
        {:noreply, put_flash(socket, :error, "Failed to add section: #{error_msg}")}
    end
  end

  @impl true
  def handle_event("edit_section", %{"section_id" => section_id}, socket) do
    IO.puts("🔥 EDIT SECTION CALLED: section_id=#{section_id}")

    section_id_int = String.to_integer(section_id)
    section = Enum.find(socket.assigns.sections, &(&1.id == section_id_int))

    IO.puts("🔥 FOUND SECTION: #{inspect(section)}")

    if section do
      socket = socket
      |> assign(:editing_section, section)
      |> assign(:active_tab, :content)
      |> assign(:section_edit_mode, true)  # CHANGE THIS LINE
      |> assign(:editing_mode, :section_edit)  # ADD THIS LINE
      |> put_flash(:info, "Editing section: #{section.title}")

      IO.puts("🔥 SOCKET UPDATED - editing_section: #{inspect(socket.assigns.editing_section)}")

      {:noreply, socket}
    else
      IO.puts("🔥 SECTION NOT FOUND")
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  @impl true
  def handle_event("close_section_editor", _params, socket) do
    socket = socket
    |> assign(:editing_section, nil)
    |> assign(:section_edit_mode, false)

    {:noreply, socket}
  end

  @impl true
  def handle_event("save_section", %{"section_id" => section_id}, socket) do
    section_id_int = String.to_integer(section_id)

    # Find the section that was being edited
    section = Enum.find(socket.assigns.sections, &(&1.id == section_id_int))

    if section do
      socket = socket
      |> assign(:editing_section, nil)
      |> assign(:section_edit_mode, false)
      |> put_flash(:info, "Section '#{section.title}' saved successfully!")

      {:noreply, socket}
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  @impl true
  def handle_event("toggle_section_visibility", %{"section-id" => section_id}, socket) do
    section_id_int = String.to_integer(section_id)
    sections = socket.assigns.sections
    section = Enum.find(sections, &(&1.id == section_id_int))

    if section do
      case Portfolios.update_section(section, %{visible: !section.visible}) do
        {:ok, updated_section} ->
          updated_sections = Enum.map(sections, fn s ->
            if s.id == section_id_int, do: updated_section, else: s
          end)

          visibility_text = if updated_section.visible, do: "shown", else: "hidden"

          socket = socket
          |> assign(:sections, updated_sections)
          |> put_flash(:info, "Section \"#{updated_section.title}\" is now #{visibility_text}")
          |> assign(:unsaved_changes, false)

          # Broadcast to live preview
          if socket.assigns.show_live_preview do
            Phoenix.PubSub.broadcast(
              Frestyl.PubSub,
              "portfolio_preview:#{socket.assigns.portfolio.id}",
              {:sections_updated, updated_sections}
            )
          end

          {:noreply, socket}

        {:error, changeset} ->
          error_msg = format_changeset_errors(changeset)
          {:noreply, put_flash(socket, :error, "Failed to update visibility: #{error_msg}")}
      end
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  @impl true
  def handle_event("duplicate_section", %{"section-id" => section_id}, socket) do
    section_id_int = String.to_integer(section_id)
    sections = socket.assigns.sections
    section = Enum.find(sections, &(&1.id == section_id_int))

    if section do
      next_position = length(sections) + 1

      duplicate_attrs = %{
        portfolio_id: section.portfolio_id,
        section_type: section.section_type,
        title: "#{section.title} (Copy)",
        content: section.content,
        visible: false,
        position: next_position
      }

      case Portfolios.create_section(duplicate_attrs) do
        {:ok, new_section} ->
          updated_sections = sections ++ [new_section]

          socket = socket
          |> assign(:sections, updated_sections)
          |> put_flash(:info, "Section duplicated successfully! The copy is hidden by default.")
          |> assign(:unsaved_changes, false)

          {:noreply, socket}

        {:error, changeset} ->
          error_msg = format_changeset_errors(changeset)
          {:noreply, put_flash(socket, :error, "Failed to duplicate section: #{error_msg}")}
      end
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  @impl true
  def handle_event("share_portfolio", _params, socket) do
    portfolio = socket.assigns.portfolio
    share_url = "#{FrestylWeb.Endpoint.url()}/p/#{portfolio.slug}"

    socket = socket
    |> assign(:share_url, share_url)
    |> assign(:show_share_modal, true)

    {:noreply, socket}
  end

  @impl true
  def handle_event("close_share_modal", _params, socket) do
    {:noreply, assign(socket, :show_share_modal, false)}
  end

  @impl true
  def handle_event("save_portfolio", _params, socket) do
    portfolio = socket.assigns.portfolio

    case Portfolios.update_portfolio(portfolio, %{updated_at: DateTime.utc_now()}) do
      {:ok, updated_portfolio} ->
        socket = socket
        |> assign(:portfolio, updated_portfolio)
        |> assign(:unsaved_changes, false)
        |> put_flash(:info, "Portfolio saved successfully!")

        {:noreply, socket}

      {:error, changeset} ->
        error_msg = format_changeset_errors(changeset)
        {:noreply, put_flash(socket, :error, "Failed to save portfolio: #{error_msg}")}
    end
  end

  @impl true
  def handle_event("open_media_library", _params, socket) do
    socket = socket
    |> assign(:show_media_library, true)

    {:noreply, socket}
  end

  @impl true
  def handle_event("import_resume", _params, socket) do
    socket = socket
    |> assign(:show_resume_import_modal, true)

    {:noreply, socket}
  end

  @impl true
  def handle_event("add_video_intro", _params, socket) do
    socket = socket
    |> assign(:show_video_intro, true)
    |> assign(:video_intro_editing, true)

    {:noreply, socket}
  end

  @impl true
  def handle_event("edit_video_intro", _params, socket) do
    {:noreply, assign(socket, :show_video_intro, true)}
  end

  @impl true
  def handle_event("close_media_library", _params, socket) do
    {:noreply, assign(socket, :show_media_library, false)}
  end

  @impl true
  def handle_event("close_resume_import", _params, socket) do
    {:noreply, assign(socket, :show_resume_import_modal, false)}
  end

  @impl true
  def handle_event("close_video_intro", _params, socket) do
    {:noreply, assign(socket, :show_video_intro, false)}
  end

@impl true
def handle_event("reorder_sections", %{"sections" => section_ids}, socket) when is_list(section_ids) do
  sections = socket.assigns.sections

  # Reorder sections based on new order
  ordered_sections = section_ids
  |> Enum.with_index(1)
  |> Enum.map(fn {section_id_str, new_position} ->
    section_id = String.to_integer(section_id_str)
    section = Enum.find(sections, &(&1.id == section_id))

    if section && section.position != new_position do
      case Portfolios.update_section(section, %{position: new_position}) do
        {:ok, updated_section} -> updated_section
        {:error, _} -> section
      end
    else
      section
    end
  end)
  |> Enum.filter(& &1)  # Remove any nils
  |> Enum.sort_by(& &1.position)

  {:noreply, socket
  |> assign(:sections, ordered_sections)
  |> put_flash(:info, "Section order updated")}
end

@impl true
def handle_event("reorder_sections", %{"old_index" => old_index, "new_index" => new_index}, socket) do
  old_idx = String.to_integer(old_index)
  new_idx = String.to_integer(new_index)
  sections = socket.assigns.sections |> Enum.sort_by(& &1.position)

  if old_idx != new_idx and old_idx < length(sections) and new_idx < length(sections) do
    # Reorder the list
    section_to_move = Enum.at(sections, old_idx)
    reordered_sections = sections
    |> List.delete_at(old_idx)
    |> List.insert_at(new_idx, section_to_move)

    # Update positions in database
    updated_sections = reordered_sections
    |> Enum.with_index(1)
    |> Enum.map(fn {section, position} ->
      if section.position != position do
        case Portfolios.update_section(section, %{position: position}) do
          {:ok, updated} -> updated
          {:error, _} -> section
        end
      else
        section
      end
    end)

    {:noreply, socket
    |> assign(:sections, updated_sections)
    |> put_flash(:info, "Section order updated")}
  else
    {:noreply, socket}
  end
end

  @impl true
  def handle_event("save_section", %{"section_id" => section_id}, socket) do
    section_id_int = String.to_integer(section_id)
    editing_section = socket.assigns.editing_section

    if editing_section && editing_section.id == section_id_int do
      # The section should already be saved from content updates
      updated_sections = Enum.map(socket.assigns.sections, fn s ->
        if s.id == section_id_int, do: editing_section, else: s
      end)

      socket = socket
      |> assign(:sections, updated_sections)
      |> assign(:editing_section, editing_section)
      |> assign(:unsaved_changes, false)
      |> put_flash(:info, "Section '#{editing_section.title}' saved successfully!")

      {:noreply, socket}
    else
      {:noreply, put_flash(socket, :error, "Section not found or not being edited")}
    end
  end

  @impl true
  def handle_event("update_section_field", %{"section_id" => section_id, "field" => field, "value" => value}, socket) do
    IO.puts("🔥 UPDATE SECTION FIELD: section_id=#{section_id}, field=#{field}, value=#{inspect(value)}")

    section_id_int = String.to_integer(section_id)
    sections = socket.assigns.sections
    section_to_update = Enum.find(sections, &(&1.id == section_id_int))

    if section_to_update do
      # Handle different field types
      update_params = case field do
        "title" ->
          %{title: value}
        "description" ->
          current_content = section_to_update.content || %{}
          updated_content = Map.put(current_content, "description", value)
          %{content: updated_content}
        "headline" ->
          current_content = section_to_update.content || %{}
          updated_content = Map.put(current_content, "headline", value)
          %{content: updated_content}
        "summary" ->
          current_content = section_to_update.content || %{}
          updated_content = Map.put(current_content, "summary", value)
          %{content: updated_content}
        "location" ->
          current_content = section_to_update.content || %{}
          updated_content = Map.put(current_content, "location", value)
          %{content: updated_content}
        "visible" ->
          %{visible: String.to_existing_atom(value)}
        _ ->
          current_content = section_to_update.content || %{}
          updated_content = Map.put(current_content, field, value)
          %{content: updated_content}
      end

      case Portfolios.update_section(section_to_update, update_params) do
        {:ok, updated_section} ->
          IO.puts("✅ Section updated successfully in database")

          updated_sections = Enum.map(sections, fn s ->
            if s.id == section_id_int, do: updated_section, else: s
          end)

          # Update editing_section if it's the same section
          editing_section = if socket.assigns[:editing_section] &&
                              socket.assigns.editing_section.id == section_id_int do
            updated_section
          else
            socket.assigns[:editing_section]
          end

          # Broadcast to live preview
          if socket.assigns.show_live_preview do
            Phoenix.PubSub.broadcast(
              Frestyl.PubSub,
              "portfolio_preview:#{socket.assigns.portfolio.id}",
              {:sections_updated, updated_sections}
            )
          end

          {:noreply, socket
          |> assign(:sections, updated_sections)
          |> assign(:editing_section, editing_section)
          |> assign(:unsaved_changes, false)
          |> put_flash(:info, "Section updated successfully")}

        {:error, changeset} ->
          error_msg = format_changeset_errors(changeset)
          {:noreply, put_flash(socket, :error, "Failed to update section: #{error_msg}")}
      end
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  defp get_user_account_safe(user) do
    try do
      # Try the function that we know exists from project knowledge
      case Frestyl.Accounts.list_user_accounts(user.id) do
        [account | _] ->
          # Ensure subscription_tier is present
          account
          |> Map.put_new(:subscription_tier, "personal")
          |> ensure_subscription_tier_is_string()
        [] ->
          %{subscription_tier: "personal"}
      end
    rescue
      _ ->
        # Fallback: try user's direct fields
        %{
          subscription_tier: get_user_subscription_tier(user)
        }
    end
  end

  # Helper to ensure subscription_tier is a string
  defp ensure_subscription_tier_is_string(account) do
    case Map.get(account, :subscription_tier) do
      tier when is_atom(tier) -> Map.put(account, :subscription_tier, Atom.to_string(tier))
      tier when is_binary(tier) -> account
      _ -> Map.put(account, :subscription_tier, "personal")
    end
  end

  # Helper to get subscription tier from user
  defp get_user_subscription_tier(user) do
    cond do
      Map.has_key?(user, :subscription_tier) && user.subscription_tier ->
        case user.subscription_tier do
          tier when is_atom(tier) -> Atom.to_string(tier)
          tier when is_binary(tier) -> tier
          _ -> "personal"
        end
      Map.has_key?(user, :account) && user.account ->
        get_user_subscription_tier(user.account)
      true ->
        "personal"
    end
  end

  # Add this helper function for safe performance tracking
  defp track_portfolio_editor_load_safe(portfolio_id, load_time) do
    if Code.ensure_loaded?(PortfolioPerformance) do
      PortfolioPerformance.track_portfolio_editor_load(portfolio_id, load_time)
    end
  rescue
    _ -> :ok
  end

  defp assign_core_data(socket, portfolio, account, user) do
    socket
    |> assign(:portfolio, portfolio)
    |> assign(:account, account)
    |> assign(:current_user, user)
    |> assign(:page_title, "Edit #{portfolio.title}")
  end

  defp assign_features_and_limits(socket, features, limits) do
    socket
    |> assign(:features, features)
    |> assign(:limits, limits)
  end

  defp assign_content_data(socket, sections, media_library, content_blocks) do
    socket
    |> assign(:sections, sections)
    |> assign(:media_library, media_library)
    |> assign(:content_blocks, content_blocks)
  end

  defp assign_monetization_data(socket, monetization_data, streaming_config) do
    socket
    |> assign(:monetization_data, monetization_data)
    |> assign(:streaming_config, streaming_config)
  end

  defp assign_design_system(socket, portfolio, account) do
    customization = portfolio.customization || %{}

    IO.puts("🔍 ASSIGN_DESIGN_SYSTEM called")
    IO.puts("🔍 Portfolio customization: #{inspect(customization)}")

    # CRITICAL: Don't use || operator which overrides existing values
    # Use Map.get with proper nil checking instead

    portfolio_layout = Map.get(customization, "layout", "minimal")

    # FIXED: Only use defaults if the key doesn't exist at all, not if it's a different value
    primary_color = case Map.get(customization, "primary_color") do
      nil -> "#374151"
      color when is_binary(color) -> color
      _ -> "#374151"
    end

    secondary_color = case Map.get(customization, "secondary_color") do
      nil -> "#6b7280"
      color when is_binary(color) -> color
      _ -> "#6b7280"
    end

    accent_color = case Map.get(customization, "accent_color") do
      nil -> "#059669"
      color when is_binary(color) -> color
      _ -> "#059669"
    end

    background_color = case Map.get(customization, "background_color") do
      nil -> "#ffffff"
      color when is_binary(color) -> color
      _ -> "#ffffff"
    end

    text_color = case Map.get(customization, "text_color") do
      nil -> "#1f2937"
      color when is_binary(color) -> color
      _ -> "#1f2937"
    end

    IO.puts("🔍 Extracted colors:")
    IO.puts("  primary: #{primary_color}")
    IO.puts("  accent: #{accent_color}")
    IO.puts("  secondary: #{secondary_color}")

    socket
    |> assign(:portfolio_layout, portfolio_layout)
    |> assign(:primary_color, primary_color)
    |> assign(:secondary_color, secondary_color)
    |> assign(:accent_color, accent_color)
    |> assign(:background_color, background_color)
    |> assign(:text_color, text_color)
    |> assign(:customization, customization)
    |> assign(:available_layouts, get_available_layouts(account))
    |> assign(:brand_constraints, get_brand_constraints(account))
  end


  defp assign_ui_state(socket) do
    timestamp = System.system_time(:millisecond)

    socket
    |> assign(:active_tab, :overview)
    |> assign(:show_preview, false)
    |> assign(:unsaved_changes, false)
    |> assign(:show_add_section_dropdown, false)
    |> assign(:show_share_modal, false)
    |> assign(:show_media_library, false)
    |> assign(:show_resume_import_modal, false)
    |> assign(:show_video_intro, false)
    |> assign(:show_main_menu, false)
    |> assign(:editing_section, nil)
    |> assign(:section_edit_mode, false)
    |> assign(:pending_changes, %{})
    |> assign(:debounce_timer, nil)
    |> assign(:media_section_id, nil)
    |> assign(:last_updated, timestamp)
    |> assign(:force_render, 0)
    |> assign(:refresh_count, 0)
    |> assign(:current_theme, nil)
    |> assign(:current_layout, nil)
  end

  # ============================================================================
  # ACCOUNT & PERMISSION HELPERS
  # ============================================================================

  defp load_portfolio_with_account(portfolio_id, user) do
    case Portfolios.get_portfolio_with_account(portfolio_id) do
      nil ->
        {:error, :not_found}

      %{portfolio: portfolio, account: account} ->
        if can_edit_portfolio?(portfolio, account, user) do
          {:ok, portfolio, account}
        else
          {:error, :unauthorized}
        end
    end
  end

  defp load_portfolio_with_account_and_blocks(portfolio_id, user) do
    case Portfolios.get_portfolio(portfolio_id) do
      nil ->
        {:error, :not_found}

      portfolio ->
        # Get user's account
        accounts = Frestyl.Accounts.list_user_accounts(user.id)
        account = List.first(accounts) || %{subscription_tier: "personal"}

        if can_edit_portfolio?(portfolio, account, user) do
          # Load content blocks organized by section
          content_blocks = load_content_blocks_by_section(portfolio_id)
          {:ok, portfolio, account, content_blocks}
        else
          {:error, :unauthorized}
        end
    end
  end

  defp get_subscription_tier(account) when is_map(account) do
    Map.get(account, :subscription_tier, "personal")
  end

  defp get_subscription_tier(_), do: "personal"

  defp load_content_blocks_by_section(portfolio_id) do
    try do
      # Load portfolio sections with their content
      sections = Portfolios.list_portfolio_sections(portfolio_id)

      # Organize content blocks by section
      Enum.reduce(sections, %{}, fn section, acc ->
        Map.put(acc, section.id, format_content_blocks(section))
      end)
    rescue
      _ -> %{}
    end
  end

  defp format_content_blocks(section) do
    content = section.content || %{}

    # Extract different types of content blocks
    %{
      text_blocks: extract_text_blocks(content),
      media_blocks: extract_media_blocks(content),
      list_blocks: extract_list_blocks(content),
      custom_blocks: extract_custom_blocks(content)
    }
  end

  defp extract_text_blocks(content) do
    [
      %{type: "description", content: content["description"] || ""},
      %{type: "summary", content: content["summary"] || ""},
      %{type: "bio", content: content["bio"] || ""}
    ]
    |> Enum.filter(fn block -> String.length(block.content) > 0 end)
  end

  defp extract_media_blocks(content) do
    content["media_items"] || []
  end

  defp extract_list_blocks(content) do
    %{
      skills: content["skills"] || [],
      achievements: content["achievements"] || [],
      responsibilities: content["responsibilities"] || []
    }
  end

  defp extract_custom_blocks(content) do
    # Handle any custom content structures
    content
    |> Map.drop(["description", "summary", "bio", "media_items", "skills", "achievements", "responsibilities"])
    |> Enum.map(fn {key, value} -> %{type: key, content: value} end)
  end

  defp can_edit_portfolio?(portfolio, _account, user) do
    # Check if user owns the portfolio or has edit permissions
    portfolio.user_id == user.id
  end

  defp get_account_features(account) do
    subscription_tier = Map.get(account, :subscription_tier, "personal")
    case subscription_tier do
      "enterprise" -> [:all_features]
      "professional" -> [:advanced_templates, :custom_css, :analytics]
      "creator" -> [:basic_templates, :media_library]
      _ -> [:basic_features]
    end
  end

  defp get_account_limits(account) do
    subscription_tier = Map.get(account, :subscription_tier, "personal")
    case subscription_tier do
      "enterprise" -> %{max_sections: -1, max_media: -1, max_templates: -1}
      "professional" -> %{max_sections: 20, max_media: 1000, max_templates: -1}
      "creator" -> %{max_sections: 10, max_media: 100, max_templates: 10}
      _ -> %{max_sections: 5, max_media: 50, max_templates: 3}
    end
  end

  defp get_available_layouts(_account) do
    ["minimal", "dashboard", "gallery", "timeline"]
  end

  defp get_brand_constraints(_account) do
    %{custom_css: false, white_label: false}
  end

  # ============================================================================
  # MONETIZATION & STREAMING FOUNDATION
  # ============================================================================

  defp load_monetization_data(user, account) do
    # Safe access to subscription_tier with fallback
    subscription_tier = Map.get(account, :subscription_tier, "personal")

    case subscription_tier do
      tier when tier in ["professional", "creator", "enterprise"] ->
        %{
          streaming_key: get_streaming_key(user.id),
          scheduled_streams: get_scheduled_streams(user.id),
          stream_analytics: get_stream_analytics(user.id),
          rtmp_config: get_rtmp_config(user.id),
          subscription_tier: tier,
          streaming_enabled: true,  # ADD THIS
          monetization_enabled: true  # ADD THIS
        }
      _ ->
        %{
          streaming_key: nil,
          scheduled_streams: [],
          stream_analytics: %{},
          rtmp_config: %{},
          subscription_tier: "personal",
          upgrade_required: true,
          streaming_enabled: false,  # ADD THIS
          monetization_enabled: false  # ADD THIS
        }
    end
  end

  defp load_streaming_config(portfolio, account) do
    %{
      streaming_key: get_streaming_key(portfolio.id),
      scheduled_streams: load_scheduled_streams(portfolio.id),
      stream_analytics: load_stream_analytics(portfolio.id),
      rtmp_config: get_rtmp_config(account)
    }
  end

  defp get_monetization_features_for_tier(subscription_tier) do
    case subscription_tier do
      "personal" -> [:tip_jar]
      "creator" -> [:tip_jar, :booking_fees, :digital_products]
      "creator_plus" -> [:tip_jar, :booking_fees, :digital_products, :subscription_content, :commission_free]
      _ -> []
    end
  end

  defp get_portfolio_revenue_streams(_portfolio_id) do
    # Stub - implement based on your revenue system
    []
  end

  defp get_account_payment_methods(_account_id) do
    # Stub - implement based on your payment system
    []
  end

  defp calculate_portfolio_earnings(_portfolio_id) do
    # Stub - implement based on your earnings system
    %{total: 0, this_month: 0}
  end

  defp get_payout_schedule(_account_id) do
    # Stub - implement based on your payout system
    nil
  end

  defp get_commission_rate(subscription_tier) do
    case subscription_tier do
      "personal" -> 0.15  # 15% commission
      "creator" -> 0.10   # 10% commission
      "creator_plus" -> 0.0  # No commission
      _ -> 0.15
    end
  end


  # ============================================================================
  # BRAND CONTROL SYSTEM
  # ============================================================================

  defp get_default_brand_constraints do
    %{
      # Ready for brand enforcement
      primary_colors: ["#1e40af", "#7c3aed", "#059669", "#dc2626"], # Can be locked to single brand color
      secondary_colors: ["#64748b", "#6b7280", "#9ca3af"],
      accent_colors: ["#f59e0b", "#ef4444", "#8b5cf6", "#06b6d4"],

      # Typography constraints
      allowed_fonts: ["Inter", "Merriweather", "JetBrains Mono"],
      font_size_scale: %{min: 0.875, max: 2.25},

      # Layout constraints
      max_sections: 20,
      spacing_scale: [0.5, 1, 1.5, 2, 3, 4],

      # Future brand enforcement hook
      enforce_brand: false, # Can be flipped to true
      brand_locked_elements: [] # Can include ["primary_color", "typography", "layout"]
    }
  end

  defp generate_design_tokens(portfolio, brand_constraints) do
    customization = portfolio.customization || %{}

    %{
      # Color tokens (brand-controllable)
      primary: get_constrained_color(customization["primary_color"], brand_constraints.primary_colors),
      secondary: get_constrained_color(customization["secondary_color"], brand_constraints.secondary_colors),
      accent: get_constrained_color(customization["accent_color"], brand_constraints.accent_colors),

      # Typography tokens
      font_family: get_constrained_font(customization["font_family"], brand_constraints.allowed_fonts),
      font_scale: brand_constraints.font_size_scale,

      # Layout tokens
      spacing_scale: brand_constraints.spacing_scale,
      max_width: "1200px",

      # Component tokens
      border_radius: "0.5rem",
      shadow_scale: ["sm", "md", "lg", "xl"]
    }
  end

  defp get_constrained_color(user_color, allowed_colors) do
    if user_color in allowed_colors do
      user_color
    else
      List.first(allowed_colors)
    end
  end

  defp get_constrained_font(user_font, allowed_fonts) do
    if user_font in allowed_fonts do
      user_font
    else
      List.first(allowed_fonts)
    end
  end

  # ============================================================================
  # UNIFIED EVENT HANDLING
  # ============================================================================

  def debug_portfolio_customization(portfolio_id) do
    case Portfolios.get_portfolio(portfolio_id) do
      nil -> IO.inspect("Portfolio not found")
      portfolio ->
        IO.inspect(portfolio.customization, label: "📊 Database customization")
        IO.inspect(portfolio.theme, label: "📊 Database theme")
    end
  end


  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    IO.inspect(tab, label: "📋 Tab changed to")
    IO.inspect(socket.assigns.customization, label: "📋 Customization when changing tab")

    tab_atom = String.to_atom(tab)
    {:noreply, assign(socket, :active_tab, tab_atom)}
  end


  @impl true
  def handle_event("toggle_preview", _params, socket) do
    {:noreply, assign(socket, :show_preview, !socket.assigns[:show_preview])}
  end

  @impl true
  def handle_event("close_preview", _params, socket) do
    {:noreply, assign(socket, :show_preview, false)}
  end

  @impl true
  def handle_event("update_title", %{"value" => title}, socket) do
    case Portfolios.update_portfolio(socket.assigns.portfolio, %{title: title}) do
      {:ok, portfolio} ->
        {:noreply, socket |> assign(:portfolio, portfolio) |> assign(:unsaved_changes, false)}
      {:error, _} ->
        {:noreply, socket |> assign(:unsaved_changes, true)}
    end
  end

  @impl true
  def handle_event("update_description", %{"value" => description}, socket) do
    case Portfolios.update_portfolio(socket.assigns.portfolio, %{description: description}) do
      {:ok, portfolio} ->
        {:noreply, socket |> assign(:portfolio, portfolio) |> assign(:unsaved_changes, false)}
      {:error, _} ->
        {:noreply, socket |> assign(:unsaved_changes, true)}
    end
  end

  @impl true
  def handle_event("update_visibility", %{"value" => visibility}, socket) do
    visibility_atom = String.to_atom(visibility)
    case Portfolios.update_portfolio(socket.assigns.portfolio, %{visibility: visibility_atom}) do
      {:ok, portfolio} ->
        {:noreply, socket |> assign(:portfolio, portfolio) |> assign(:unsaved_changes, false)}
      {:error, _} ->
        {:noreply, socket |> assign(:unsaved_changes, true)}
    end
  end

  @impl true
  def handle_event("update_color", %{"field" => field, "value" => color}, socket) do
    IO.puts("🎨 UPDATE COLOR (immediate): #{field} = #{color}")

    # Get current customization and update immediately
    current_customization = socket.assigns.customization || %{}
    updated_customization = Map.put(current_customization, field, color)

    # IMMEDIATE UI update first (prevents reversion)
    socket = socket
    |> assign(:customization, updated_customization)
    |> assign(:unsaved_changes, true)

    # Update individual color assigns for immediate UI feedback
    socket = case field do
      "primary_color" -> assign(socket, :primary_color, color)
      "accent_color" -> assign(socket, :accent_color, color)
      "secondary_color" -> assign(socket, :secondary_color, color)
      _ -> socket
    end

    # IMMEDIATE database save (no debouncing for colors to prevent reversion)
    case Portfolios.update_portfolio(socket.assigns.portfolio, %{customization: updated_customization}) do
      {:ok, updated_portfolio} ->
        IO.puts("✅ Color saved to database immediately")

        socket = socket
        |> assign(:portfolio, updated_portfolio)
        |> assign(:unsaved_changes, false)

        # IMMEDIATE live preview update
        if socket.assigns.show_live_preview do
          css = generate_simple_preview_css(updated_customization, updated_portfolio.theme)

          IO.puts("🔥 BROADCASTING COLOR UPDATE...")
          Phoenix.PubSub.broadcast(
            Frestyl.PubSub,
            "portfolio_preview:#{socket.assigns.portfolio.id}",
            {:preview_update, updated_customization, css}
          )
        end

        {:noreply, socket}

      {:error, changeset} ->
        error_msg = format_changeset_errors(changeset)
        IO.puts("❌ Failed to save color: #{error_msg}")
        {:noreply, put_flash(socket, :error, "Failed to save color: #{error_msg}")}
    end
  end

  @impl true
  def handle_event("update_layout", %{"value" => layout_value}, socket) do
    IO.puts("🎨 UPDATE LAYOUT (debounced): #{layout_value}")

    # Store pending changes
    pending_changes = Map.put(socket.assigns[:pending_changes] || %{}, "layout", layout_value)
    socket = assign(socket, :pending_changes, pending_changes)

    # Cancel existing timer
    if socket.assigns[:debounce_timer] do
      Process.cancel_timer(socket.assigns.debounce_timer)
    end

    # Set new debounce timer
    timer = Process.send_after(self(), :save_pending_changes, 300)
    socket = assign(socket, :debounce_timer, timer)

    # Immediate UI update (optimistic)
    updated_customization = Map.merge(socket.assigns.customization || %{}, pending_changes)

    socket = socket
    |> assign(:customization, updated_customization)
    |> assign(:portfolio_layout, layout_value)
    |> assign(:unsaved_changes, true)

    # Broadcast to live preview immediately
    if socket.assigns.show_live_preview do
      css = generate_simple_preview_css(updated_customization, socket.assigns.portfolio.theme)

      Phoenix.PubSub.broadcast(
        Frestyl.PubSub,
        "portfolio_preview:#{socket.assigns.portfolio.id}",
        {:preview_update, updated_customization, css}
      )
    end

    {:noreply, socket}
  end


  # Add placeholder handlers for other events
  @impl true
  def handle_event("add_section", _params, socket) do
    {:noreply, put_flash(socket, :info, "Add section functionality coming soon")}
  end

  @impl true
  def handle_event("publish_portfolio", _params, socket) do
    {:noreply, put_flash(socket, :info, "Portfolio published successfully!")}
  end

  @impl true
  def handle_event("delete_portfolio", _params, socket) do
    case Portfolios.delete_portfolio(socket.assigns.portfolio) do
      {:ok, _} ->
        {:noreply, socket |> put_flash(:info, "Portfolio deleted") |> redirect(to: "/portfolios")}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete portfolio")}
    end
  end

  @impl true
  def handle_event("update_section", params, socket) do
    case update_section_content(params, socket) do
      {:ok, updated_socket} ->
        {:noreply, updated_socket |> assign(:unsaved_changes, false)}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update section: #{format_errors(changeset)}")}
    end
  end

  @impl true
  def handle_event("add_section", %{"type" => section_type}, socket) do
    if can_add_section?(socket) do
      case create_new_section(section_type, socket) do
        {:ok, new_section} ->
          updated_sections = socket.assigns.sections ++ [new_section]

          {:noreply,
           socket
           |> assign(:sections, updated_sections)
           |> assign(:editing_section, new_section)
           |> assign(:editing_mode, :section_edit)
           |> put_flash(:info, "Section added successfully")}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Failed to add section: #{reason}")}
      end
    else
      {:noreply, put_flash(socket, :error, "Section limit reached for your subscription")}
    end
  end

  @impl true
  def handle_event("delete_section", %{"section-id" => section_id}, socket) do
    section_id_int = String.to_integer(section_id)
    sections = socket.assigns.sections
    section_to_delete = Enum.find(sections, &(&1.id == section_id_int))

    if section_to_delete do
      case Portfolios.delete_section(section_to_delete) do
        {:ok, _deleted_section} ->
          updated_sections = Enum.reject(sections, &(&1.id == section_id_int))

          # Reindex positions
          updated_sections = updated_sections
          |> Enum.with_index(1)
          |> Enum.map(fn {section, index} ->
            if section.position != index do
              {:ok, updated} = Portfolios.update_section(section, %{position: index})
              updated
            else
              section
            end
          end)

          # Broadcast to live preview
          if socket.assigns.show_live_preview do
            Phoenix.PubSub.broadcast(
              Frestyl.PubSub,
              "portfolio_preview:#{socket.assigns.portfolio.id}",
              {:sections_updated, updated_sections}
            )
          end

          socket = socket
          |> assign(:sections, updated_sections)
          |> assign(:editing_section, nil)
          |> assign(:section_edit_mode, false)
          |> assign(:unsaved_changes, false)
          |> put_flash(:info, "Section '#{section_to_delete.title}' deleted successfully")

          {:noreply, socket}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to delete section")}
      end
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end


  @impl true
  def handle_event("toggle_monetization", %{"section_id" => section_id}, socket) do
    if socket.assigns.can_monetize do
      case toggle_section_monetization(section_id, socket) do
        {:ok, updated_socket} ->
          {:noreply, updated_socket |> put_flash(:info, "Monetization settings updated")}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, reason)}
      end
    else
      {:noreply, put_flash(socket, :error, "Upgrade to Creator to enable monetization")}
    end
  end

  @impl true
  def handle_event("create_content_block", %{"section_id" => section_id, "block_type" => block_type}, socket) do
    # Check if user can create this block type
    if can_create_block_type?(block_type, socket) do
      case create_new_content_block(section_id, block_type, socket.assigns.user) do
        {:ok, block} ->
          updated_blocks = update_section_blocks_cache(socket.assigns.content_blocks, section_id, block)

          {:noreply,
          socket
          |> assign(:content_blocks, updated_blocks)
          |> assign(:editing_block, block)
          |> assign(:editing_mode, :block_detail)
          |> put_flash(:info, "Content block created successfully")}

        {:error, changeset} ->
          errors = format_errors(changeset)
          {:noreply, put_flash(socket, :error, "Failed to create block: #{errors}")}
      end
    else
      {:noreply, put_flash(socket, :error, "Block type not available for your subscription tier")}
    end
  end

  @impl true
  def handle_event("edit_content_block", %{"block_id" => block_id}, socket) do
    try do
      block = ContentBlock.get_with_media!(block_id)
      {:noreply,
      socket
      |> assign(:editing_block, block)
      |> assign(:editing_mode, :block_detail)}
    rescue
      Ecto.NoResultsError ->
        {:noreply, put_flash(socket, :error, "Content block not found")}
    end
  end

  @impl true
  def handle_event("open_block_builder", %{"section_id" => section_id}, socket) do
    available_blocks = get_available_block_types_for_account(socket)

    {:noreply,
    socket
    |> assign(:block_builder_open, true)
    |> assign(:block_builder_section_id, section_id)
    |> assign(:available_block_types, available_blocks)}
  end

    @impl true
  def handle_event("add_media_to_block", %{"block_id" => block_id, "media_file_id" => media_file_id, "binding_type" => binding_type}, socket) do
    block = ContentBlock.get_with_media!(block_id)
    media_file = Portfolios.get_media_file!(media_file_id)

    result = case binding_type do
      "simple" ->
        # Simple portfolio media attachment
        ContentBlock.add_portfolio_media(block, media_file)

      binding_type when binding_type in ["background_audio", "hover_audio", "modal_image"] ->
        # Interactive story-style media binding
        binding_config = %{
          type: String.to_atom(binding_type),
          selector: "#block-#{block.id}",
          sync_data: %{},
          trigger_config: get_default_trigger_config(binding_type),
          display_config: get_default_display_config(binding_type)
        }
        ContentBlock.add_media_binding(block, media_file, binding_config)

      _ ->
        {:error, "Invalid binding type"}
    end

    case result do
      {:ok, _binding} ->
        updated_block = ContentBlock.get_with_media!(block_id)
        {:noreply,
         socket
         |> assign(:editing_block, updated_block)
         |> put_flash(:info, "Media added to block successfully")}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to add media: #{format_errors(changeset)}")}
    end
  end

  @impl true
  def handle_event("close_block_builder", _params, socket) do
    {:noreply, assign(socket, :block_builder_open, false)}
  end

  @impl true
  def handle_event("create_enhancement_channel", %{"type" => enhancement_type}, socket) do
    portfolio = socket.assigns.portfolio
    user = socket.assigns.current_user

    case Channels.create_portfolio_enhancement_channel(portfolio, enhancement_type, user) do
      {:ok, channel} ->
        # Redirect to new channel with portfolio context
        {:noreply,
        socket
        |> put_flash(:info, "Collaboration channel created!")
        |> redirect(to: ~p"/channels/#{channel.id}?source=portfolio&portfolio_id=#{portfolio.id}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create collaboration channel")}
    end
  end

  @impl true
  def handle_event("apply_story_template", %{"template_type" => template_type}, socket) do
    portfolio = socket.assigns.portfolio
    user = socket.assigns.current_user

    case Lab.Templates.apply_to_portfolio(portfolio, template_type, user) do
      {:ok, updated_portfolio} ->
        # Update portfolio with story structure
        story_fields = %{
          story_type: updated_portfolio.story_type,
          narrative_structure: updated_portfolio.narrative_structure,
          target_audience: updated_portfolio.target_audience || "professional"
        }

        case Portfolios.update_portfolio(portfolio, story_fields) do
          {:ok, portfolio_with_story} ->
            {:noreply,
            socket
            |> assign(:portfolio, portfolio_with_story)
            |> put_flash(:info, "Story template applied! Your portfolio now follows #{template_type} structure.")
            |> push_event("story_template_applied", %{template: template_type})}

          {:error, changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to apply story template: #{format_errors(changeset)}")}
        end

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Story template not available: #{reason}")}
    end
  end

  @impl true
  def handle_event("add_studio_content", %{"content_type" => content_type, "studio_url" => url}, socket) do
    portfolio = socket.assigns.portfolio

    case content_type do
      "background_music" ->
        audio_settings = Map.merge(portfolio.audio_settings || %{}, %{
          "background_music_enabled" => true,
          "background_music_url" => url,
          "auto_play_policy" => "hover"
        })

        case Portfolios.update_portfolio(portfolio, %{audio_settings: audio_settings}) do
          {:ok, updated_portfolio} ->
            {:noreply,
            socket
            |> assign(:portfolio, updated_portfolio)
            |> put_flash(:info, "Background music added!")
            |> push_event("audio_added", %{type: "background", url: url})}

          {:error, changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to add music: #{format_errors(changeset)}")}
        end

      "voice_intro" ->
        audio_settings = Map.merge(portfolio.audio_settings || %{}, %{
          "voice_intro_enabled" => true,
          "voice_intro_url" => url
        })

        case Portfolios.update_portfolio(portfolio, %{audio_settings: audio_settings}) do
          {:ok, updated_portfolio} ->
            {:noreply,
            socket
            |> assign(:portfolio, updated_portfolio)
            |> put_flash(:info, "Voice introduction added!")
            |> push_event("audio_added", %{type: "voice_intro", url: url})}

          {:error, changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to add voice intro: #{format_errors(changeset)}")}
        end
    end
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp generate_simple_preview_css(customization, theme) do
    primary_color = Map.get(customization, "primary_color", "#374151")
    accent_color = Map.get(customization, "accent_color", "#059669")
    secondary_color = Map.get(customization, "secondary_color", "#6b7280")
    layout = Map.get(customization, "layout", "minimal")

    """
    <style>
    :root {
      --primary-color: #{primary_color};
      --accent-color: #{accent_color};
      --secondary-color: #{secondary_color};
    }

    body {
      font-family: #{get_theme_font(theme)};
      line-height: 1.6;
      margin: 0;
      padding: 0;
    }

    .portfolio-container {
      background: var(--primary-color);
      color: #ffffff;
      min-height: 100vh;
      padding: 2rem;
    }

    .portfolio-header h1 {
      color: #ffffff;
      margin-bottom: 0.5rem;
    }

    .portfolio-header p {
      color: rgba(255, 255, 255, 0.9);
    }

    .section {
      margin-bottom: 2rem;
      padding: 1.5rem;
      border-radius: 8px;
      background: rgba(255, 255, 255, 0.1);
      #{get_layout_css(layout)}
    }

    .section h2.accent {
      color: var(--accent-color);
    }

    .section-content {
      color: rgba(255, 255, 255, 0.95);
      line-height: 1.6;
    }

    /* Smooth transitions for live updates */
    * {
      transition: background-color 0.3s ease,
                  color 0.3s ease,
                  border-color 0.3s ease;
    }

    @media (max-width: 768px) {
      .portfolio-container {
        padding: 1rem;
      }
      .section {
        margin-bottom: 1rem;
        padding: 1rem;
      }
    }
    </style>
    """
  end

  defp get_theme_font("minimal"), do: "'Inter', sans-serif"
  defp get_theme_font("professional"), do: "'Merriweather', serif"
  defp get_theme_font("creative"), do: "'Poppins', sans-serif"
  defp get_theme_font(_), do: "'Inter', sans-serif"

  defp get_layout_css("dashboard") do
    "display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 1rem;"
  end

  defp get_layout_css("gallery") do
    "display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 0.5rem;"
  end

  defp get_layout_css(_), do: ""

  defp get_theme_base_css("minimal") do
    """
    .portfolio-container {
      background: linear-gradient(135deg, var(--primary-color) 0%, #{darken_color("#374151", 20)} 100%);
    }
    """
  end

  defp get_theme_base_css("professional") do
    """
    .portfolio-container {
      background: linear-gradient(to bottom, var(--primary-color) 0%, #{darken_color("#1e40af", 10)} 100%);
    }
    """
  end

  defp get_theme_base_css("creative") do
    """
    .portfolio-container {
      background: linear-gradient(135deg, var(--primary-color) 0%, var(--accent-color) 50%, var(--secondary-color) 100%);
    }
    """
  end

  defp get_theme_base_css(_), do: get_theme_base_css("minimal")

  defp get_advanced_layout_css("dashboard") do
    """
    .portfolio-sections {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
      gap: 2rem;
    }

    .section {
      display: flex;
      flex-direction: column;
      height: fit-content;
    }
    """
  end

  defp get_advanced_layout_css("gallery") do
    """
    .portfolio-sections {
      columns: 3;
      column-gap: 1rem;
    }

    .section {
      break-inside: avoid;
      margin-bottom: 1rem;
    }

    @media (max-width: 768px) {
      .portfolio-sections {
        columns: 1;
      }
    }
    """
  end

  defp get_advanced_layout_css(_), do: ""

  # Helper function to darken colors (simple version)
  defp darken_color(hex_color, _percentage) do
    # Simple darkening - in production you might want a more sophisticated approach
    case hex_color do
      "#374151" -> "#1f2937"
      "#1e40af" -> "#1e3a8a"
      _ -> "#1f2937"
    end
  end

  # Function 2: Live preview CSS (same as simple for now)
  defp generate_live_preview_css(customization, theme) do
    generate_simple_preview_css(customization, theme)
  end

  # Function 3: Broadcast preview updates
  defp broadcast_preview_update(socket) do
    if socket.assigns.show_live_preview do
      css = generate_simple_preview_css(socket.assigns.customization || %{}, socket.assigns.portfolio.theme)

      Phoenix.PubSub.broadcast(
        Frestyl.PubSub,
        "portfolio_preview:#{socket.assigns.portfolio.id}",
        {:preview_update, socket.assigns.customization || %{}, css}
      )
    end
  end

  defp can_add_section?(socket) do
    current_count = socket.assigns.section_count
    max_sections = socket.assigns.max_sections

    max_sections == -1 or current_count < max_sections
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {field, errors} -> "#{field}: #{Enum.join(errors, ", ")}" end)
    |> Enum.join("; ")
  end

  defp create_new_content_block(section_id, block_type, user) do
    next_position = get_next_block_position(section_id)

    ContentBlock.create_for_portfolio_section(section_id, %{
      block_uuid: Ecto.UUID.generate(),
      block_type: String.to_atom(block_type),
      position: next_position,
      content_data: get_default_content_for_block_type(block_type),
      layout_config: get_default_layout_config(block_type),
      media_limit: get_default_media_limit(block_type),
      requires_subscription_tier: get_required_tier_for_block(block_type),
      is_premium_feature: is_premium_block_type?(block_type)
    })
  end

  defp get_available_block_types do
    base_blocks = [
      %{type: "text", name: "Text Block", description: "Rich text content", category: "basic"},
      %{type: "responsibility", name: "Responsibility", description: "Job responsibility with media", category: "portfolio"},
      %{type: "skill_item", name: "Skill", description: "Individual skill with proficiency", category: "portfolio"},
      %{type: "project_card", name: "Project", description: "Project showcase card", category: "portfolio"},
      %{type: "achievement", name: "Achievement", description: "Award or accomplishment", category: "portfolio"},
      %{type: "testimonial_item", name: "Testimonial", description: "Client testimonial", category: "portfolio"},

      # Story blocks (merged from Stories.ContentBlock)
      %{type: "image", name: "Image Block", description: "Single image with caption", category: "story"},
      %{type: "gallery", name: "Image Gallery", description: "Multiple images in grid", category: "story"},
      %{type: "video", name: "Video Block", description: "Embedded video content", category: "story"},
      %{type: "quote", name: "Quote Block", description: "Highlighted quotation", category: "story"},
      %{type: "timeline", name: "Timeline", description: "Chronological timeline", category: "story"},
      %{type: "bullet_list", name: "Bullet List", description: "Structured list with bullets", category: "story"},

      # Layout blocks
      %{type: "grid_container", name: "Grid Layout", description: "Custom grid layout", category: "layout"},
      %{type: "card_stack", name: "Card Stack", description: "Stackable cards", category: "layout"},
      %{type: "feature_highlight", name: "Feature Highlight", description: "Prominent feature display", category: "layout"}
    ]

    # Add monetization blocks if user can monetize
    monetization_blocks = [
      %{type: "service_package", name: "Service Package", description: "Packaged service offering", category: "monetization"},
      %{type: "booking_widget", name: "Booking Widget", description: "Calendar booking integration", category: "monetization"},
      %{type: "pricing_tier", name: "Pricing Tier", description: "Service pricing tier", category: "monetization"},
      %{type: "hourly_rate", name: "Hourly Rate", description: "Hourly service pricing", category: "monetization"},
      %{type: "consultation_offer", name: "Consultation", description: "Free consultation offer", category: "monetization"},
      %{type: "payment_button", name: "Payment Button", description: "Direct payment integration", category: "monetization"}
    ]

    # Add streaming blocks if user can stream
    streaming_blocks = [
      %{type: "live_session_embed", name: "Live Session", description: "Embedded live streaming", category: "streaming"},
      %{type: "scheduled_stream", name: "Scheduled Stream", description: "Upcoming stream announcement", category: "streaming"},
      %{type: "recording_showcase", name: "Recording Showcase", description: "Past recording display", category: "streaming"},
      %{type: "availability_calendar", name: "Availability Calendar", description: "Live session booking", category: "streaming"},
      %{type: "stream_archive", name: "Stream Archive", description: "Collection of past streams", category: "streaming"}
    ]

    # Return blocks based on account capabilities - this will need socket.assigns access
    base_blocks ++ monetization_blocks ++ streaming_blocks
  end

  def get_available_block_types_for_account(socket) do
    all_blocks = get_available_block_types()

    # Filter based on account features
    Enum.filter(all_blocks, fn block ->
      case block.category do
        "monetization" -> socket.assigns.can_monetize
        "streaming" -> socket.assigns.can_stream
        _ -> true  # Basic, portfolio, story, and layout blocks always available
      end
    end)
  end

  defp update_section_blocks_cache(cache, section_id, new_block) do
    current_blocks = Map.get(cache, section_id, [])
    Map.put(cache, section_id, [new_block | current_blocks])
  end

  defp count_total_blocks(content_blocks) do
    content_blocks
    |> Map.values()
    |> List.flatten()
    |> length()
  end

  defp get_next_block_position(section_id) do
    blocks = Portfolios.list_content_blocks_for_section(section_id)
    case blocks do
      [] -> 0
      blocks ->
        blocks
        |> Enum.map(& &1.position)
        |> Enum.max()
        |> Kernel.+(1)
    end
  end

  defp get_streaming_key(user_id) do
    # Generate a streaming key based on user ID
    "sk_user_#{user_id}_" <>
      (:crypto.strong_rand_bytes(16) |> Base.encode64() |> binary_part(0, 16))
  end

  defp get_scheduled_streams(user_id) do
    case Streaming.get_scheduled_streams(user_id) do
      {:ok, streams} -> streams
      _ -> []
    end
  rescue
    _ -> []
  end

  defp get_stream_analytics(user_id) do
    case Analytics.get_stream_analytics(user_id) do
      {:ok, analytics} -> analytics
      _ -> %{}
    end
  rescue
    _ -> %{}
  end

  defp load_streaming_config(portfolio, account) do
    subscription_tier = Map.get(account, :subscription_tier, "personal")

    case subscription_tier do
      tier when tier in ["professional", "creator", "enterprise"] ->
        %{
          streaming_key: get_portfolio_streaming_key(portfolio.id),
          scheduled_streams: load_scheduled_streams(portfolio.id),
          stream_analytics: load_stream_analytics(portfolio.id),
          rtmp_config: get_portfolio_rtmp_config(portfolio.id),
          subscription_tier: tier,
          streaming_enabled: true
        }
      _ ->
        %{
          streaming_key: nil,
          scheduled_streams: [],
          stream_analytics: %{},
          rtmp_config: %{},
          subscription_tier: "personal",
          streaming_enabled: false,
          upgrade_required: true
        }
    end
  end

  # Safe implementations of the missing functions
  defp load_scheduled_streams(portfolio_id) do
    try do
      # Try to get scheduled streams for this portfolio
      # This would typically query a database table
      case get_portfolio_scheduled_streams(portfolio_id) do
        {:ok, streams} -> streams
        _ -> []
      end
    rescue
      _ -> []
    end
  end

  defp load_stream_analytics(portfolio_id) do
    try do
      # Try to get stream analytics for this portfolio
      case get_portfolio_stream_analytics(portfolio_id) do
        {:ok, analytics} -> analytics
        _ -> %{}
      end
    rescue
      _ -> %{}
    end
  end

  # Helper functions for database queries (implement these based on your schema)
  defp get_portfolio_streaming_key(portfolio_id) do
    # Generate or retrieve streaming key for portfolio
    "sk_portfolio_#{portfolio_id}_" <>
      (:crypto.strong_rand_bytes(16) |> Base.encode64() |> binary_part(0, 16))
  end

  defp get_portfolio_scheduled_streams(portfolio_id) do
    # If you have a ScheduledStreams table/schema
    try do
      if Code.ensure_loaded?(Frestyl.Streaming.ScheduledStream) do
        # Example query - adjust based on your schema
        streams = Frestyl.Repo.all(
          from s in Frestyl.Streaming.ScheduledStream,
          where: s.portfolio_id == ^portfolio_id,
          where: s.scheduled_at > ^DateTime.utc_now(),
          order_by: [asc: s.scheduled_at]
        )
        {:ok, streams}
      else
        {:ok, []}
      end
    rescue
      _ -> {:ok, []}
    end
  end

  defp get_portfolio_stream_analytics(portfolio_id) do
    # If you have a StreamAnalytics table/schema
    try do
      if Code.ensure_loaded?(Frestyl.Analytics.StreamAnalytics) do
        # Example query - adjust based on your schema
        analytics = Frestyl.Repo.one(
          from a in Frestyl.Analytics.StreamAnalytics,
          where: a.portfolio_id == ^portfolio_id,
          select: %{
            total_streams: a.total_streams,
            total_viewers: a.total_viewers,
            average_duration: a.average_duration,
            last_stream: a.last_stream_at
          }
        )
        {:ok, analytics || %{}}
      else
        {:ok, %{}}
      end
    rescue
      _ -> {:ok, %{}}
    end
  end

  defp get_portfolio_rtmp_config(portfolio_id) do
    # Basic RTMP configuration for portfolio streaming
    %{
      server: "rtmp://stream.frestyl.com/live/",
      stream_key: get_portfolio_streaming_key(portfolio_id),
      backup_server: "rtmp://backup.frestyl.com/live/"
    }
  end

  defp get_rtmp_config(user_id) do
    case Streaming.get_rtmp_config(user_id) do
      {:ok, config} -> config
      _ -> %{}
    end
  rescue
    _ -> %{}
  end

  defp get_default_content_for_block_type("text"), do: %{"content" => ""}
  defp get_default_content_for_block_type("responsibility"), do: %{"text" => "", "impact_metrics" => []}
  defp get_default_content_for_block_type("skill_item"), do: %{"name" => "", "proficiency" => "intermediate"}
  defp get_default_content_for_block_type("service_package"), do: %{"name" => "", "price" => 0}
  defp get_default_content_for_block_type(_), do: %{}

  defp get_default_media_limit("text"), do: 2
  defp get_default_media_limit("project_card"), do: 8
  defp get_default_media_limit(_), do: 3


  # Placeholder functions for implementation in subsequent prompts
  defp load_portfolio_sections(portfolio_id), do: Portfolios.list_portfolio_sections(portfolio_id)
  defp load_portfolio_media(portfolio_id), do: Portfolios.list_portfolio_media(portfolio_id)
  defp load_portfolio_services(portfolio_id), do: []
  defp load_pricing_config(portfolio_id), do: %{}
  defp load_booking_calendar(portfolio_id), do: %{}
  defp load_revenue_analytics(portfolio_id, account), do: %{}
  defp load_payment_config(account_id), do: %{}
  defp get_custom_brand_config(account_id), do: nil

  defp update_section_content(params, socket) do
    # Implementation for next prompt
    {:ok, socket}
  end

  defp create_new_section(section_type, socket) do
    # Implementation for next prompt
    {:ok, %{id: 1, type: section_type, title: "New Section"}}
  end

  defp delete_section_by_id(section_id, socket) do
    # Implementation for next prompt
    {:ok, socket.assigns.sections}
  end

  defp toggle_section_monetization(section_id, socket) do
    # Implementation for next prompt
    {:ok, socket}
  end

  # Helper function to determine if portfolio needs story enhancement
  defp missing_story_structure?(portfolio) do
    is_nil(portfolio.story_type) || is_nil(portfolio.narrative_structure)
  end

  defp text_heavy_without_audio?(portfolio) do
    sections = Portfolios.list_portfolio_sections(portfolio.id)

    has_text_content = Enum.any?(sections, fn section ->
      content = section.content || %{}
      text_fields = ["summary", "description", "content", "about"]

      Enum.any?(text_fields, fn field ->
        text = Map.get(content, field, "")
        String.length(text) > 200
      end)
    end)

    has_audio = portfolio.audio_settings["background_music_enabled"] ||
                portfolio.audio_settings["voice_intro_enabled"]

    has_text_content && !has_audio
  end

    defp can_create_block_type?(block_type, socket) do
    block_atom = String.to_atom(block_type)

    cond do
      ContentBlock.is_monetization_block?(block_atom) ->
        socket.assigns.can_monetize

      ContentBlock.is_streaming_block?(block_atom) ->
        socket.assigns.can_stream

      true ->
        true  # Basic blocks always allowed
    end
  end

  defp get_required_tier_for_block(block_type) do
    block_atom = String.to_atom(block_type)

    cond do
      ContentBlock.is_monetization_block?(block_atom) -> "creator"
      ContentBlock.is_streaming_block?(block_atom) -> "creator"
      block_type in ["media_showcase", "timeline", "gallery"] -> "professional"
      true -> nil
    end
  end

  defp is_premium_block_type?(block_type) do
    block_atom = String.to_atom(block_type)
    ContentBlock.is_monetization_block?(block_atom) || ContentBlock.is_streaming_block?(block_atom)
  end

  defp get_default_layout_config("grid_container"), do: %{"columns" => 2, "gap" => "1rem"}
  defp get_default_layout_config("gallery"), do: %{"layout" => "masonry", "columns" => 3}
  defp get_default_layout_config("timeline"), do: %{"orientation" => "vertical", "show_dates" => true}
  defp get_default_layout_config(_), do: %{}

  defp get_default_trigger_config("hover_audio"), do: %{"event" => "mouseenter", "delay" => 0}
  defp get_default_trigger_config("background_audio"), do: %{"autoplay" => false, "loop" => true}
  defp get_default_trigger_config("modal_image"), do: %{"event" => "click", "overlay" => true}
  defp get_default_trigger_config(_), do: %{}

  defp get_default_display_config("modal_image"), do: %{"size" => "large", "position" => "center"}
  defp get_default_display_config("background_audio"), do: %{"volume" => 0.3, "fade_in" => true}
  defp get_default_display_config(_), do: %{}

  # UPDATED: Enhanced content defaults for merged block types
  defp get_default_content_for_block_type("text"), do: %{"content" => ""}
  defp get_default_content_for_block_type("responsibility"), do: %{"text" => "", "impact_metrics" => []}
  defp get_default_content_for_block_type("skill_item"), do: %{"name" => "", "proficiency" => "intermediate"}
  defp get_default_content_for_block_type("service_package"), do: %{"name" => "", "price" => 0, "description" => ""}
  defp get_default_content_for_block_type("image"), do: %{"caption" => "", "alt_text" => ""}
  defp get_default_content_for_block_type("gallery"), do: %{"images" => [], "caption" => ""}
  defp get_default_content_for_block_type("video"), do: %{"url" => "", "title" => "", "description" => ""}
  defp get_default_content_for_block_type("quote"), do: %{"text" => "", "author" => "", "source" => ""}
  defp get_default_content_for_block_type("timeline"), do: %{"events" => []}
  defp get_default_content_for_block_type("bullet_list"), do: %{"items" => [""]}
  defp get_default_content_for_block_type("booking_widget"), do: %{"calendar_id" => "", "duration" => 30}
  defp get_default_content_for_block_type("live_session_embed"), do: %{"stream_key" => "", "title" => ""}
  defp get_default_content_for_block_type(_), do: %{}

  # UPDATED: Media limits for merged block types
  defp get_default_media_limit("text"), do: 2
  defp get_default_media_limit("project_card"), do: 8
  defp get_default_media_limit("gallery"), do: 20
  defp get_default_media_limit("image"), do: 1
  defp get_default_media_limit("video"), do: 1
  defp get_default_media_limit("media_showcase"), do: 15
  defp get_default_media_limit(_), do: 3

  defp get_next_block_position(section_id) do
    blocks = ContentBlock.list_for_section(section_id)
    case blocks do
      [] -> 0
      blocks ->
        blocks
        |> Enum.map(& &1.position)
        |> Enum.max()
        |> Kernel.+(1)
    end
  end

  defp get_monetization_analytics(portfolio_id, account_id) do
    # Stub implementation - replace with actual analytics logic
    %{
      revenue_trend: get_revenue_trend(portfolio_id),
      top_products: get_top_selling_products(portfolio_id),
      conversion_rate: calculate_conversion_rate(portfolio_id),
      visitor_to_customer: calculate_visitor_conversion(portfolio_id),
      total_views: get_portfolio_views(portfolio_id),
      total_purchases: get_total_purchases(portfolio_id)
    }
  end

  defp get_revenue_trend(_portfolio_id) do
    # Return last 30 days of revenue data
    # Stub implementation
    []
  end

  defp get_top_selling_products(_portfolio_id) do
    # Return top selling products/services
    # Stub implementation
    []
  end

  defp calculate_conversion_rate(_portfolio_id) do
    # Calculate conversion rate from views to purchases
    # Stub implementation
    0.0
  end

  defp calculate_visitor_conversion(_portfolio_id) do
    # Calculate visitor to customer conversion
    # Stub implementation
    0.0
  end

  defp get_portfolio_views(portfolio_id) do
    try do
      Frestyl.Portfolios.get_total_visits(portfolio_id)
    rescue
      _ -> 0
    end
  end

  defp get_total_purchases(_portfolio_id) do
    # Get total purchases for this portfolio
    # Stub implementation
    0
  end

  defp get_revenue_summary(monetization_data) do
    earnings = Map.get(monetization_data, :earnings, %{total: 0, this_month: 0})
    analytics = Map.get(monetization_data, :analytics, %{})

    %{
      total_revenue: Map.get(earnings, :total, 0),
      monthly_revenue: Map.get(earnings, :this_month, 0),
      conversion_rate: Map.get(analytics, :conversion_rate, 0.0),
      total_transactions: Map.get(analytics, :total_purchases, 0)
    }
  end

  # Alternative quick fix - just use safe access:
  defp assign_monetization_data(socket, user, account) do
    try do
      monetization_data = load_monetization_data(user, account)
      assign(socket, :monetization_data, monetization_data)
    rescue
      error ->
        Logger.error("Failed to load monetization data: #{inspect(error)}")
        # Assign default monetization data
        default_data = %{
          streaming_key: nil,
          scheduled_streams: [],
          stream_analytics: %{},
          rtmp_config: %{},
          subscription_tier: get_subscription_tier(account),
          error: true
        }
        assign(socket, :monetization_data, default_data)
    end
  end

  defp get_default_title_for_type("intro"), do: "Introduction"
  defp get_default_title_for_type("experience"), do: "Professional Experience"
  defp get_default_title_for_type("education"), do: "Education"
  defp get_default_title_for_type("skills"), do: "Skills & Expertise"
  defp get_default_title_for_type("projects"), do: "Projects"
  defp get_default_title_for_type("featured_project"), do: "Featured Project"
  defp get_default_title_for_type("achievements"), do: "Achievements"
  defp get_default_title_for_type("testimonial"), do: "Testimonials"
  defp get_default_title_for_type("contact"), do: "Contact Information"
  defp get_default_title_for_type(_), do: "New Section"

  defp get_default_content_for_type("intro") do
    %{
      "headline" => "Hello, I'm [Your Name]",
      "summary" => "A passionate professional focused on creating exceptional experiences.",
      "cta_text" => "Get in touch"
    }
  end

  defp get_default_content_for_type("experience") do
    %{
      "experiences" => [
        %{
          "title" => "Your Job Title",
          "company" => "Company Name",
          "duration" => "Start Date - End Date",
          "description" => "Brief description of your role and achievements."
        }
      ]
    }
  end

  defp get_default_content_for_type("skills") do
    %{
      "skill_categories" => %{
        "Technical" => [
          %{"name" => "Your Skill", "proficiency" => "advanced", "years" => 3}
        ]
      }
    }
  end

  defp get_default_content_for_type("projects") do
    %{
      "projects" => [
        %{
          "title" => "Project Title",
          "description" => "Brief description of the project and your role.",
          "technologies" => [],
          "links" => %{"github" => "", "live" => ""}
        }
      ]
    }
  end

  defp get_default_content_for_type(_type) do
    %{"main_content" => "Add your content here..."}
  end

  defp format_section_type(section_type) do
    case section_type do
      :intro -> "Introduction"
      :experience -> "Experience"
      :skills -> "Skills"
      :education -> "Education"
      :projects -> "Projects"
      :featured_project -> "Featured Project"
      :case_study -> "Case Study"
      :contact -> "Contact"
      :testimonial -> "Testimonial"
      :achievements -> "Achievements"
      :media_showcase -> "Media Showcase"
      "intro" -> "Introduction"
      "experience" -> "Experience"
      "skills" -> "Skills"
      "education" -> "Education"
      "projects" -> "Projects"
      "featured_project" -> "Featured Project"
      "case_study" -> "Case Study"
      "contact" -> "Contact"
      "testimonial" -> "Testimonial"
      "achievements" -> "Achievements"
      "media_showcase" -> "Media Showcase"
      _ -> "Section"
    end
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map_join(", ", fn {field, errors} ->
      "#{field}: #{Enum.join(errors, ", ")}"
    end)
  end


  defp move_section(sections, old_index, new_index) do
    if old_index >= 0 and old_index < length(sections) and
      new_index >= 0 and new_index < length(sections) and
      old_index != new_index do

      section = Enum.at(sections, old_index)
      sections_without_moved = List.delete_at(sections, old_index)
      reordered_sections = List.insert_at(sections_without_moved, new_index, section)

      {:ok, reordered_sections}
    else
      {:error, "Invalid indices for section reordering"}
    end
  end

  defp update_section_positions(sections) do
    sections
    |> Enum.with_index(1)
    |> Enum.map(fn {section, index} ->
      case Portfolios.update_section(section, %{position: index}) do
        {:ok, updated_section} -> updated_section
        {:error, _} -> section
      end
    end)
  end

  # ============================================================================
  # SECTION TYPE HELPERS - ADD THESE AT THE END OF YOUR FILE
  # ============================================================================

  defp get_section_types do
    %{
      "intro" => %{
        title: "Introduction",
        description: "Welcome message and personal summary",
        emoji: "👋"
      },
      "experience" => %{
        title: "Professional Experience",
        description: "Work history and job experience",
        emoji: "💼"
      },
      "education" => %{
        title: "Education",
        description: "Academic background and qualifications",
        emoji: "🎓"
      },
      "skills" => %{
        title: "Skills & Expertise",
        description: "Technical and professional skills",
        emoji: "⚡"
      },
      "projects" => %{
        title: "Projects",
        description: "Portfolio of work and projects",
        emoji: "🛠️"
      },
      "featured_project" => %{
        title: "Featured Project",
        description: "Highlight a specific project",
        emoji: "🚀"
      },
      "achievements" => %{
        title: "Achievements",
        description: "Awards, certifications, and accomplishments",
        emoji: "🏆"
      },
      "testimonial" => %{
        title: "Testimonials",
        description: "Client and colleague recommendations",
        emoji: "💬"
      },
      "contact" => %{
        title: "Contact Information",
        description: "How to get in touch",
        emoji: "📧"
      }
    }
  end

  defp get_section_emoji(section_type) do
    section_type_string = case section_type do
      atom when is_atom(atom) -> Atom.to_string(atom)
      string when is_binary(string) -> string
      _ -> "unknown"
    end

    case section_type_string do
      "intro" -> "👋"
      "experience" -> "💼"
      "education" -> "🎓"
      "skills" -> "⚡"
      "projects" -> "🛠️"
      "featured_project" -> "🚀"
      "media_showcase" -> "🖼️"
      "achievements" -> "🏆"
      "testimonial" -> "💬"
      "contact" -> "📧"
      "case_study" -> "📊"
      "timeline" -> "📅"
      "story" -> "📖"
      "custom" -> "📝"
      _ -> "📄"
    end
  end

  defp get_section_preview(section) do
    content = section.content || %{}

    section_type_string = case section.section_type do
      atom when is_atom(atom) -> Atom.to_string(atom)
      string when is_binary(string) -> string
      _ -> "unknown"
    end

    case section_type_string do
      "intro" ->
        content["headline"] || content["summary"] || "Introduction section"
      "experience" ->
        experiences = content["experiences"] || []
        case experiences do
          [first | _] when is_map(first) ->
            "#{Map.get(first, "title", "")} at #{Map.get(first, "company", "")}"
          [] -> "Professional experience"
          _ -> "Professional experience"
        end
      "skills" ->
        skill_categories = content["skill_categories"] || %{}
        skill_count = skill_categories |> Map.values() |> List.flatten() |> length()
        "#{skill_count} skills across #{map_size(skill_categories)} categories"
      "projects" ->
        projects = content["projects"] || []
        case projects do
          [first | _] when is_map(first) -> Map.get(first, "title", "Project showcase")
          [] -> "Project portfolio"
          _ -> "Project portfolio"
        end
      "media_showcase" ->
        "Media gallery and showcase"
      "case_study" ->
        Map.get(content, "title", "Detailed case study")
      "timeline" ->
        events = Map.get(content, "events", [])
        event_count = if is_list(events), do: length(events), else: 0
        "Timeline with #{event_count} events"
      _ ->
        content["main_content"] || content["description"] || content["summary"] || "Content section"
    end
  end

  defp format_relative_time(datetime) do
    try do
      # Convert NaiveDateTime to DateTime if needed
      utc_datetime = case datetime do
        %DateTime{} = dt -> dt
        %NaiveDateTime{} = ndt -> DateTime.from_naive!(ndt, "Etc/UTC")
        _ -> DateTime.utc_now()
      end

      case DateTime.diff(DateTime.utc_now(), utc_datetime, :second) do
        diff when diff < 60 -> "Just now"
        diff when diff < 3600 -> "#{div(diff, 60)}m ago"
        diff when diff < 86400 -> "#{div(diff, 3600)}h ago"
        diff when diff < 604800 -> "#{div(diff, 86400)}d ago"
        _ ->
          # For older dates, show actual date
          Calendar.strftime(utc_datetime, "%b %d, %Y")
      end
    rescue
      _ -> "Recently"
    end
  end

  defp build_preview_url(portfolio, customization) do
    # Generate preview token
    token = :crypto.hash(:sha256, "preview_#{portfolio.id}_#{Date.utc_today()}")
            |> Base.encode16(case: :lower)

    # Base URL that matches your route
    preview_url = "/portfolios/#{portfolio.id}/preview/#{token}"

    IO.puts("🔍 PREVIEW URL GENERATED: #{preview_url}")
    IO.puts("🔍 CUSTOMIZATION PASSED: #{inspect(customization)}")

    preview_url
  end

  # ============================================================================
  # MISSING EVENT HANDLERS - ADD THESE TO YOUR handle_event FUNCTIONS
  # ============================================================================

  @impl true
  def handle_event("toggle_main_menu", _params, socket) do
    current_state = socket.assigns[:show_main_menu] || false
    {:noreply, assign(socket, :show_main_menu, !current_state)}
  end

  @impl true
  def handle_event("close_main_menu", _params, socket) do
    {:noreply, assign(socket, :show_main_menu, false)}
  end

  @impl true
  def handle_event("manage_section_media", %{"section-id" => section_id}, socket) do
    socket = socket
    |> assign(:show_media_library, true)
    |> assign(:media_section_id, section_id)

    {:noreply, socket}
  end

end
