# lib/frestyl_web/live/portfolio_live/dynamic_card_layout_manager.ex - PHASE 1 ENHANCED
defmodule FrestylWeb.PortfolioLive.DynamicCardLayoutManager do
  @moduledoc """
  Dynamic Card Layout Manager with Video Support and Enhanced Block Controls.
  Phase 1: Video playback, visibility controls, block management.
  """

  use FrestylWeb, :live_component
  alias Frestyl.Portfolios.ContentBlocks.DynamicCardBlocks
  alias Frestyl.Portfolios
  alias Frestyl.Accounts.BrandSettings
  import Phoenix.LiveView.Helpers
  alias FrestylWeb.PortfolioLive.DynamicCardPublicRenderer

  # ============================================================================
  # COMPONENT LIFECYCLE
  # ============================================================================

  @impl true
  def mount(socket) do
    {:ok, socket
      |> assign(:layout_mode, :edit)
      |> assign(:active_category, :service_provider)
      |> assign(:preview_device, :desktop)
      |> assign(:brand_preview_mode, false)
      |> assign(:block_drag_active, false)
      |> assign(:layout_dirty, false)
      |> assign(:editing_block_id, nil)
      |> assign(:editing_block, nil)
      |> assign(:block_changes, %{})
      |> assign(:save_status, :idle)
      |> assign(:show_edit_modal, false)
      |> assign(:show_upgrade_modal, false)
      |> assign(:blocked_block_type, nil)
      |> assign(:required_tier, nil)
      |> assign(:auto_save_timer, nil)
      |> assign(:playing_video_id, nil) # Track which video is playing
      |> assign(:show_video_controls, %{}) # Track video control states
    }
  end

  @impl true
  def update(assigns, socket) do
    view_mode = Map.get(assigns, :view_mode, :edit)
    show_edit_controls = Map.get(assigns, :show_edit_controls, view_mode == :edit)
    layout_zones = assigns.layout_zones || %{}
    layout_config = get_current_layout_config(assigns.portfolio, assigns.brand_settings)
    account = assigns.account || %{subscription_tier: "personal"}

    {:ok, socket
      |> assign(assigns)
      |> assign(:view_mode, view_mode)
      |> assign(:show_edit_controls, show_edit_controls)
      |> assign(:layout_zones, layout_zones)
      |> assign(:layout_config, layout_config) # New: assign layout_config
      |> assign(:account, account)
      |> assign(:editing_block_id, nil)
      |> assign(:block_changes, %{})
    }
  end

  # ============================================================================
  # MAIN RENDER FUNCTION
  # ============================================================================

  @impl true
  def render(assigns) do
    ~H"""
    <div class="dynamic-card-layout-manager"
          id={"layout-manager-#{@portfolio.id}"}
          phx-hook="VideoPlayer">

      <%= if Map.get(assigns, :show_edit_controls, false) do %>
        <div class="layout-edit-interface flex h-full">
          <div class="layout-sidebar bg-white border-r border-gray-200 w-80 p-4">
            <%= render_editor_sidebar(assigns) %>
          </div>

          <div class="layout-canvas flex-1 p-6 bg-gray-50">
            <%= render_layout_zones_editor(assigns) %>
          </div>
        </div>
      <% else %>
        <.live_component
          module={DynamicCardPublicRenderer}
          id={"public-renderer-#{@portfolio.id}"}
          portfolio={@portfolio}
          layout_zones={@layout_zones}
          layout_config={@layout_config}
          public_view_settings={get_public_view_settings(@portfolio)}
          view_type={Map.get(assigns, :view_type, :public)}
          show_edit_controls={false} />
      <% end %>

      <%= if @show_edit_modal and @editing_block do %>
        <%= render_edit_modal(assigns) %>
      <% end %>

      <%= render_upgrade_modal(assigns) %>
    </div>
    """
  end

  # ============================================================================
  # MONETIZATION-AWARE EVENT HANDLERS
  # ============================================================================

  @impl true
  def handle_event("add_content_block", %{"block_type" => block_type, "zone" => zone}, socket) do
    block_type_atom = String.to_atom(block_type)

    case can_use_block_type?(socket.assigns.account, block_type_atom) do
      true ->
        case create_dynamic_card_block(block_type, String.to_atom(zone), socket) do
          {:ok, new_block} ->
            updated_zones = add_block_to_zone(socket.assigns.layout_zones, String.to_atom(zone), new_block)

            {:noreply, socket
              |> assign(:layout_zones, updated_zones)
              |> assign(:layout_dirty, true)
              |> put_flash(:info, "#{humanize_block_type(block_type_atom)} added!")
            }

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, "Failed to add block: #{inspect(reason)}")}
        end

      false ->
        {:noreply, socket
          |> assign(:show_upgrade_modal, true)
          |> assign(:blocked_block_type, block_type_atom)
          |> assign(:required_tier, get_required_tier(block_type_atom))
        }
    end
  end

  @impl true
  def handle_event("edit_content_block", %{"block_id" => block_id}, socket) do
    block_id_int = parse_block_id(block_id)

    case find_block_in_zones(socket.assigns.layout_zones, block_id_int) do
      {:ok, block} ->
        {:noreply, socket
          |> assign(:editing_block_id, block_id_int)
          |> assign(:editing_block, block)
          |> assign(:show_edit_modal, true)
          |> assign(:save_status, :idle)
        }

      {:error, :not_found} ->
        {:noreply, socket |> put_flash(:error, "Block not found")}
    end
  end

  @impl true
  def handle_event("save_block_changes", %{"block_id" => block_id, "changes" => changes_json}, socket) do
    block_id_int = parse_block_id(block_id)

    changes = case Jason.decode(changes_json) do
      {:ok, decoded} -> decoded
      {:error, _} -> %{}
    end

    socket = assign(socket, :save_status, :saving)

    case find_block_in_zones(socket.assigns.layout_zones, block_id_int) do
      {:ok, current_block} ->
        updated_block = update_block_content(current_block, changes)
        updated_zones = update_block_in_zones(socket.assigns.layout_zones, block_id_int, updated_block)

        case save_layout_zones_to_database(updated_zones, socket.assigns.portfolio.id) do
          {:ok, _sections} ->
            send(self(), {:block_updated, block_id_int, updated_zones})

            {:noreply, socket
              |> assign(:layout_zones, updated_zones)
              |> assign(:editing_block, updated_block)
              |> assign(:save_status, :saved)
              |> schedule_save_status_reset()
            }

          {:error, reason} ->
            {:noreply, socket
              |> assign(:save_status, :error)
              |> put_flash(:error, "Failed to save: #{inspect(reason)}")
            }
        end

      {:error, :not_found} ->
        {:noreply, socket |> put_flash(:error, "Block not found")}
    end
  end

  @impl true
  def handle_event("cancel_block_edit", _params, socket) do
    {:noreply, socket
      |> assign(:editing_block_id, nil)
      |> assign(:editing_block, nil)
      |> assign(:show_edit_modal, false)
      |> assign(:save_status, :idle)
    }
  end

  @impl true
  def handle_event("close_upgrade_modal", _params, socket) do
    {:noreply, socket
      |> assign(:show_upgrade_modal, false)
      |> assign(:blocked_block_type, nil)
      |> assign(:required_tier, nil)
    }
  end

  @impl true
  def handle_event("upgrade_account", _params, socket) do
    {:noreply, socket
      |> put_flash(:info, "Redirecting to upgrade...")
      |> redirect(to: "/upgrade")
    }
  end

  @impl true
  def handle_event("clean_reset_data", _params, socket) do
    # Clean reset - convert messy data to clean structures
    cleaned_zones = clean_and_reset_layout_zones(socket.assigns.layout_zones)

    case save_layout_zones_to_database(cleaned_zones, socket.assigns.portfolio.id) do
      {:ok, _sections} ->
        send(self(), {:block_updated, "reset", cleaned_zones})

        {:noreply, socket
          |> assign(:layout_zones, cleaned_zones)
          |> put_flash(:info, "✨ Data cleaned and reset! All blocks now have clean structures.")
        }

      {:error, reason} ->
        {:noreply, socket |> put_flash(:error, "Reset failed: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("toggle_block_visibility", %{"block_id" => block_id}, socket) do
    block_id_int = String.to_integer(block_id)

    case Portfolios.get_section(block_id_int) do
      nil ->
        {:noreply, put_flash(socket, :error, "Section not found")}

      section ->
        case Portfolios.update_section(section, %{visible: !section.visible}) do
          {:ok, updated_section} ->
            # Update the layout zones with new visibility
            updated_zones = update_block_visibility_in_zones(
              socket.assigns.layout_zones,
              block_id_int,
              updated_section.visible
            )

            {:noreply,
              socket
              |> assign(:layout_zones, updated_zones)
              |> put_flash(:info, if(updated_section.visible, do: "Block shown", else: "Block hidden"))
            }

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to update visibility")}
        end
    end
  end

  @impl true
  def handle_event("delete_block", %{"block_id" => block_id}, socket) do
    block_id_int = String.to_integer(block_id)

    case Portfolios.get_section(block_id_int) do
      nil ->
        {:noreply, put_flash(socket, :error, "Section not found")}

      section ->
        case Portfolios.delete_section(section) do
          {:ok, _deleted_section} ->
            # Remove from layout zones
            updated_zones = remove_block_from_zones(socket.assigns.layout_zones, block_id_int)

            {:noreply,
              socket
              |> assign(:layout_zones, updated_zones)
              |> put_flash(:info, "Block deleted successfully")
            }

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to delete block")}
        end
    end
  end

  @impl true
  def handle_event("edit_block", %{"block_id" => block_id}, socket) do
    # Send event to parent to open modal editor
    send(self(), {:open_block_editor, block_id})
    {:noreply, socket}
  end

  @impl true
  def handle_event("attach_media", %{"block_id" => block_id}, socket) do
    # Send event to parent to open media attachment modal
    send(self(), {:open_media_attachment, block_id})
    {:noreply, socket}
  end

  @impl true
  def handle_event("play_video", %{"block_id" => block_id, "video_url" => video_url}, socket) do
    {:noreply,
      socket
      |> assign(:playing_video_id, block_id)
      |> push_event("play_video", %{block_id: block_id, video_url: video_url})
    }
  end

  @impl true
  def handle_event("pause_video", %{"block_id" => block_id}, socket) do
    {:noreply,
      socket
      |> assign(:playing_video_id, nil)
      |> push_event("pause_video", %{block_id: block_id})
    }
  end

  @impl true
  def handle_event("toggle_video_controls", %{"block_id" => block_id}, socket) do
    current_controls = socket.assigns.show_video_controls
    new_controls = Map.update(current_controls, block_id, true, &(!&1))

    {:noreply, assign(socket, :show_video_controls, new_controls)}
  end

  # ============================================================================
  # MONETIZATION & TIER LOGIC
  # ============================================================================

  defp can_use_block_type?(account, block_type) do
    user_tier = get_user_tier(account)
    required_tier = get_required_tier(block_type)
    tier_level(user_tier) >= tier_level(required_tier)
  end

  defp get_user_tier(account) do
    case account do
      %{subscription_tier: tier} when is_binary(tier) -> String.to_atom(tier)
      %{subscription_tier: tier} when is_atom(tier) -> tier
      _ -> :personal
    end
  end

  defp get_required_tier(block_type) do
    case block_type do
      # FREE (Personal Tier) - 8 blocks
      type when type in [:hero_card, :about_card, :experience_card, :skills_card,
                         :projects_card, :contact_card, :achievements_card, :media_showcase_card] ->
        :personal

      # CREATOR+ Tier - 6 blocks
      type when type in [:social_card, :audio_showcase_card, :video_showcase_card,
                         :visual_art_card, :social_embed_card, :video_embed_card] ->
        :creator

      # PROFESSIONAL+ Tier - 5 blocks
      type when type in [:services_card, :testimonials_card, :business_embed_card,
                         :code_showcase_card, :interactive_demo_card] ->
        :professional

      # ENTERPRISE Tier - 3 blocks
      type when type in [:audio_embed_card, :code_embed_card, :presentation_embed_card] ->
        :enterprise

      _ -> :personal
    end
  end

  defp tier_level(:personal), do: 0
  defp tier_level(:creator), do: 1
  defp tier_level(:professional), do: 2
  defp tier_level(:enterprise), do: 3
  defp tier_level(_), do: 0

  defp format_tier_name(:personal), do: "Personal"
  defp format_tier_name(:creator), do: "Creator"
  defp format_tier_name(:professional), do: "Professional"
  defp format_tier_name(:enterprise), do: "Enterprise"
  defp format_tier_name(tier), do: String.capitalize(to_string(tier))

  defp get_tier_benefits(:personal) do
    [
      "Access to essential content blocks",
      "Standard portfolio features",
      "Basic customization options"
    ]
  end

  defp get_tier_benefits(:creator) do
    get_tier_benefits(:personal) ++ [
      "All Personal tier features",
      "Advanced media blocks (audio, video showcase)",
      "Social media integration",
      "Priority support"
    ]
  end

  defp get_tier_benefits(:professional) do
    get_tier_benefits(:creator) ++ [
      "All Creator tier features",
      "Premium business blocks (services, testimonials)",
      "Interactive content support",
      "Custom domain support"
    ]
  end

  defp get_tier_benefits(:enterprise) do
    get_tier_benefits(:professional) ++ [
      "All Professional tier features",
      "Enterprise-grade embeds (audio, code, presentations)",
      "Dedicated account manager",
      "Advanced analytics"
    ]
  end

  # ============================================================================
  # BLOCK CREATION WITH CLEAN STRUCTURES
  # ============================================================================

  defp create_dynamic_card_block(block_type, zone, _socket) do
    default_content = get_clean_block_structure(String.to_atom(block_type))

    {:ok, %{
      id: System.unique_integer([:positive]),
      block_type: String.to_atom(block_type),
      content_data: default_content,
      zone: zone,
      position: 0,
      visible: true # New: blocks are visible by default
    }}
  rescue
    error -> {:error, "Failed to create block: #{Exception.message(error)}"}
  end

  defp get_clean_block_structure(:hero_card) do
    %{
      "title" => "",
      "subtitle" => "",
      "video_url" => "",
      "video_aspect_ratio" => "16:9",
      "call_to_action" => %{"text" => "", "url" => ""},
      "background_type" => "color",
      "social_links" => %{"linkedin" => "", "github" => "", "twitter" => "", "website" => ""},
      "media_files" => [],
      "custom_fields" => %{}
    }
  end

  defp get_clean_block_structure(:about_card) do
    %{
      "title" => "",
      "content" => "",
      "highlights" => [""],  # Start with one empty highlight
      "location" => "",
      "availability" => "",
      "media_files" => [],
      "custom_fields" => %{}
    }
  end

  defp get_clean_block_structure(:experience_card) do
    %{
      "title" => "",
      "jobs" => [%{  # Start with one empty job
        "title" => "",
        "company" => "",
        "location" => "",
        "employment_type" => "",
        "start_date" => "",
        "end_date" => "",
        "current" => false,
        "description" => "",
        "achievements" => [],
        "skills" => [],
        "media_files" => [],
        "custom_fields" => %{}
      }]
    }
  end

  # Add all other block structures here...
  defp get_clean_block_structure(block_type) do
    case block_type do
      :video_hero -> %{
        "headline" => "Captivating Hero Video",
        "subtitle" => "Showcase your story",
        "video_url" => nil, # Placeholder, will be populated by media attachment
        "overlay_text" => true,
        "call_to_action" => %{"text" => "Explore More", "url" => "#"}
      }
      _ -> %{
        "title" => "",
        "content" => "",
        "media_files" => [],
        "custom_fields" => %{}
      }
    end
  end

  defp schedule_save_status_reset(socket) do
    # Cancel any existing timer
    if socket.assigns[:save_status_timer] do
      Process.cancel_timer(socket.assigns.save_status_timer)
    end

    # Schedule a message to reset save status after 3 seconds
    timer = Process.send_after(self(), {:reset_save_status, socket.assigns.myself}, 3000)

    assign(socket, :save_status_timer, timer)
  end

  @impl true
  def handle_info({:reset_save_status, component_pid}, socket) do
    if socket.assigns.myself == component_pid do
      {:noreply, assign(socket, :save_status, nil)}
    else
      {:noreply, socket}
    end
  end


  # ============================================================================
  # UI RENDERING FUNCTIONS
  # ============================================================================

  defp render_editor_sidebar(assigns) do
    assigns = assign(assigns,
      available_blocks: get_available_blocks_for_tier(assigns.account),
      restricted_blocks: get_restricted_blocks_for_tier(assigns.account)
    )

    ~H"""
    <div class="space-y-6">
      <h3 class="text-lg font-semibold text-gray-900">Content Blocks</h3>

      <div class="space-y-2">
        <%= for {block_type_key, block_info} <- @available_blocks do %>
          <div class="p-3 border border-gray-200 rounded-lg cursor-pointer hover:bg-gray-50"
              phx-click="add_content_block"
              phx-value-block_type={block_type_key}
              phx-value-zone={:body} # Default to body zone for now
              phx-target={@myself}>
            <div class="font-medium text-sm"><%= block_info.name %></div>
            <div class="text-xs text-gray-500"><%= block_info.description %></div>
          </div>
        <% end %>
      </div>

      <div class="pt-4 border-t border-gray-200">
        <button phx-click="add_content_block"
                phx-value-block_type="video_hero" # Ensure this maps to your create_dynamic_card_block
                phx-value-zone={:header} # Example zone, adjust as needed
                phx-target={@myself}
                class="w-full px-3 py-2 bg-purple-600 text-white rounded-lg text-sm hover:bg-purple-700 flex items-center justify-center">
          <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
          </svg>
          Add Video Block
        </button>
      </div>

      <div class="pt-4 border-t border-gray-200">
        <h4 class="font-medium text-gray-900 mb-2">Layout Options</h4>
        <button phx-click="save_layout" phx-target={@myself}
                class="w-full px-3 py-2 bg-blue-600 text-white rounded-lg text-sm hover:bg-blue-700">
          Save Layout
        </button>
        <button phx-click="clean_reset_data" phx-target={@myself}
                      class="px-3 py-1 text-sm bg-red-100 text-red-700 rounded-md hover:bg-red-200 mt-2 w-full">
                🧹 Clean Reset
        </button>
      </div>
    </div>
    """
  end

  defp render_layout_zones_editor(assigns) do
    layout_zones = Map.get(assigns, :layout_zones, %{})

    ~H"""
    <div class="layout-zones-editor space-y-8">
      <h2 class="text-2xl font-bold text-gray-900">Portfolio Layout</h2>

      <%= if map_size(layout_zones) > 0 do %>
        <div class="space-y-6">
          <%= for {zone_name, blocks} <- layout_zones do %>
            <div class="layout-zone border-2 border-dashed border-purple-200 rounded-lg p-4 bg-purple-50"
                data-zone={zone_name}>

              <h3 class="text-md font-medium text-purple-900 mb-3 capitalize flex items-center">
                <div class="w-3 h-3 bg-purple-600 rounded-full mr-2"></div>
                <%= String.replace(to_string(zone_name), "_", " ") %> Zone
              </h3>

              <%= if length(blocks) > 0 do %>
                <div class="space-y-3">
                  <%= for block <- blocks do %>
                    <%= render_editable_content_block(block, zone_name, assigns) %>
                  <% end %>
                </div>
              <% else %>
                <div class="empty-zone-placeholder h-32 border-2 border-dashed border-gray-300 rounded-lg flex items-center justify-center text-gray-500">
                  <div class="text-center">
                    <svg class="w-8 h-8 mx-auto mb-2 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
                    </svg>
                    <p class="text-sm">Drop blocks here</p>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      <% else %>
        <div class="text-center py-12">
          <p class="text-gray-500">No layout zones configured</p>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_editable_content_block(block, zone_name, assigns) do
    # DEBUG: Print block structure to find the KeyError source
    IO.puts("🔍 DEBUG BLOCK STRUCTURE:")
    IO.puts("🔍 Block ID: #{Map.get(block, :id)}")
    IO.puts("🔍 Block keys: #{inspect(Map.keys(block))}")
    IO.puts("🔍 Has :content? #{Map.has_key?(block, :content)}")
    IO.puts("🔍 Has :content_data? #{Map.has_key?(block, :content_data)}")
    IO.puts("🔍 Zone: #{zone_name}")

    # Safely determine if this block is hidden
    is_hidden = !get_block_visibility(block)
    block_classes = if is_hidden, do: "opacity-50", else: ""

    assigns = assigns
    |> assign(:block, block)
    |> assign(:zone_name, zone_name)
    |> assign(:is_hidden, is_hidden)
    |> assign(:block_classes, block_classes)

    ~H"""
    <div class={"dynamic-card-block relative group #{@block_classes}"}
        data-block-id={get_block_id(@block)}>

      <!-- Mobile-First Block Controls Overlay -->
      <div class="block-controls absolute top-2 right-2 z-10 opacity-0 group-hover:opacity-100 transition-opacity duration-200">
        <div class="flex items-center space-x-1 bg-black bg-opacity-75 rounded-lg p-1">

          <!-- Edit Button -->
          <button phx-click="edit_block"
                  phx-value-block_id={get_block_id(@block)}
                  phx-target={@myself}
                  class="p-2 text-white hover:text-blue-300 transition-colors"
                  title="Edit block">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
            </svg>
          </button>

          <!-- Visibility Toggle -->
          <button phx-click="toggle_block_visibility"
                  phx-value-block_id={get_block_id(@block)}
                  phx-target={@myself}
                  class="p-2 text-white hover:text-yellow-300 transition-colors"
                  title={if @is_hidden, do: "Show block", else: "Hide block"}>
            <%= if @is_hidden do %>
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.878 9.878L3 3m6.878 6.878L21 21"/>
              </svg>
            <% else %>
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7C7.523 19 3.732 16.057 2.458 12z"/>
              </svg>
            <% end %>
          </button>

          <!-- Media/Attach Button -->
          <button phx-click="attach_media"
                  phx-value-block_id={get_block_id(@block)}
                  phx-target={@myself}
                  class="p-2 text-white hover:text-green-300 transition-colors"
                  title="Attach media">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.172 7l-6.586 6.586a2 2 0 102.828 2.828l6.414-6.586a4 4 0 00-5.656-5.656l-6.415 6.585a6 6 0 108.486 8.486L20.5 13"/>
            </svg>
          </button>

          <!-- Delete Button -->
          <button phx-click="delete_block"
                  phx-value-block_id={get_block_id(@block)}
                  phx-target={@myself}
                  onclick="return confirm('Are you sure you want to delete this block?')"
                  class="p-2 text-white hover:text-red-300 transition-colors"
                  title="Delete block">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
            </svg>
          </button>

        </div>
      </div>

      <!-- Block Content with Safe Rendering -->
      <div class="block-content">
        <%= render_block_content_safe(@block, assigns) %>
      </div>
    </div>
    """
  end

  defp render_block_content_safe(block, assigns) do
    try do
      render_block_content(block, assigns)
    rescue
      KeyError ->
        IO.puts("🚨 KeyError caught in render_block_content_safe")
        render_fallback_block_content(block, assigns)
    end
  end

  defp render_fallback_block_content(block, assigns) do
    block_type = get_block_type_safe(block)
    content_data = get_block_content_safe(block)

    assigns = assigns
    |> assign(:block, block)
    |> assign(:content_data, content_data)
    |> assign(:block_type, block_type)

    ~H"""
    <div class="fallback-block bg-yellow-50 border border-yellow-200 rounded-lg p-4">
      <h4 class="font-medium text-yellow-800">Block: <%= @block_type %></h4>
      <p class="text-sm text-yellow-700">Content rendering fallback mode</p>
      <p class="text-xs text-yellow-600 mt-2">ID: <%= get_block_id(@block) %></p>
    </div>
    """
  end

  defp get_block_id(block) do
    Map.get(block, :id) || Map.get(block, "id")
  end

  defp get_block_visibility(block) do
    Map.get(block, :visible, true) || Map.get(block, "visible", true)
  end

  defp get_block_type_safe(block) do
    Map.get(block, :section_type) ||
    Map.get(block, :block_type) ||
    Map.get(block, "section_type") ||
    Map.get(block, "block_type") ||
    :content_block
  end

  defp get_block_title_safe(block) do
    Map.get(block, :title) ||
    Map.get(block, "title") ||
    "Untitled Block"
  end

  defp get_block_content_safe(block) do
    case block do
      %{content_data: content} when is_map(content) -> content
      %{content: content} when is_map(content) -> content
      %{"content_data" => content} when is_map(content) -> content
      %{"content" => content} when is_map(content) -> content
      _ -> %{}
    end
  end

  defp get_public_view_settings(portfolio) do
    customization = portfolio.customization || %{}

    %{
      layout_type: Map.get(customization, "public_layout_type", "dashboard"),
      enable_sticky_nav: Map.get(customization, "enable_sticky_nav", true),
      enable_back_to_top: Map.get(customization, "enable_back_to_top", true),
      mobile_expansion_style: Map.get(customization, "mobile_expansion_style", "in_place"),
      video_autoplay: Map.get(customization, "video_autoplay", "muted"),
      gallery_lightbox: Map.get(customization, "gallery_lightbox", true),
      color_scheme: Map.get(customization, "color_scheme", "professional"),
      font_family: Map.get(customization, "font_family", "inter"),
      enable_animations: Map.get(customization, "enable_animations", true)
    }
  end

  defp render_video_hero_block(assigns) do
    block = assigns.block
    content = get_block_content_safe(block)

    # Load associated media
    section_media = get_section_media(block.id)
    video_media = Enum.find(section_media, &is_video_media?/1)

    assigns = assigns
    |> assign(:content, content)
    |> assign(:video_media, video_media)
    |> assign(:video_url, get_video_url_from_content(content, video_media))
    |> assign(:thumbnail_url, get_thumbnail_url_from_content(content, video_media))
    |> assign(:is_playing, assigns.playing_video_id == to_string(block.id))

    ~H"""
    <div class="video-hero-block relative bg-gray-900 rounded-lg overflow-hidden min-h-[300px]">
      <!-- Video content rendering here... -->
      <%= if @video_url do %>
        <!-- Existing video rendering code -->
        <div class="video-container">
          <p class="text-white p-4">Video: <%= @video_url %></p>
        </div>
      <% else %>
        <!-- No Video - Setup State -->
        <div class="flex items-center justify-center h-full text-white">
          <div class="text-center">
            <svg class="w-16 h-16 mx-auto mb-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
            </svg>
            <h3 class="text-lg font-medium mb-2">Video Block</h3>
            <p class="text-gray-300 mb-4">Ready for video content</p>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp get_video_url_from_content(content, video_media) do
    cond do
      video_media && is_video_media?(video_media) ->
        get_video_url(video_media)
      Map.has_key?(content, "video_url") ->
        Map.get(content, "video_url")
      true ->
        nil
    end
  end

  defp get_video_url(media) do
    if is_external_video?(media) do
      case media.external_video_platform do
        "youtube" -> "https://www.youtube.com/watch?v=#{media.external_video_id}"
        "vimeo" -> "https://vimeo.com/#{media.external_video_id}"
        _ -> nil
      end
    else
      "/uploads/#{media.file_path}"
    end
  end

  defp render_standard_block(assigns) do
    block = assigns.block
    content = Map.get(block, :content, %{}) || Map.get(block, :content_data, %{})

    # Handle both content and content_data for compatibility
    content = if Map.size(content) == 0 do
      Map.get(block, :content_data, %{})
    else
      content
    end

    ~H"""
    <div class="standard-block bg-white rounded-lg border border-gray-200 p-6 hover:shadow-md transition-shadow">
      <div class="flex items-start justify-between mb-4">
        <div class="flex-1">
          <h3 class="font-semibold text-gray-900 mb-1">
            <%= Map.get(block, :title, "Untitled Block") %>
          </h3>
          <p class="text-sm text-gray-600 capitalize">
            <%= get_display_block_type(block) %>
          </p>
        </div>
      </div>

      <div class="text-sm text-gray-600">
        <%= case Map.get(get_content_safe(assigns), "main_content") || Map.get(get_content_safe(assigns), "summary") || Map.get(get_content_safe(assigns), "headline") do %>
          <% content when is_binary(content) and content != "" -> %>
            <%= String.slice(content, 0, 120) %><%= if String.length(content) > 120, do: "...", else: "" %>
          <% _ -> %>
            <em>No content added yet</em>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_layout_zones_public(assigns) do
    # Public rendering - only show visible blocks
    layout_zones = Map.get(assigns, :layout_zones, %{})

    ~H"""
    <div class="layout-zones-public">
      <%= if map_size(layout_zones) > 0 do %>
        <%= for {zone_name, blocks} <- layout_zones do %>
          <section class={"layout-zone-#{zone_name} py-8"} data-zone={zone_name}>
            <%= for block <- blocks do %>
              <%= if Map.get(block, :visible, true) do %>
                <%= render_block_content_public(block, assigns) %>
              <% end %>
            <% end %>
          </section>
        <% end %>
      <% end %>
    </div>
    """
  end

  defp get_display_block_type(block) do
    block_type = Map.get(block, :section_type) || Map.get(block, :block_type) ||
                 Map.get(block, "section_type") || Map.get(block, "block_type") || "content"

    block_type
    |> to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

    # Helper function to safely extract preview content
  defp get_preview_content(content) when is_map(content) do
    # Try different content field names
    Map.get(content, "main_content") ||
    Map.get(content, "summary") ||
    Map.get(content, "headline") ||
    Map.get(content, "description") ||
    extract_jobs_preview(content) ||
    extract_skills_preview(content) ||
    ""
  end
  defp get_preview_content(_), do: ""

  defp extract_jobs_preview(%{"jobs" => jobs}) when is_list(jobs) and length(jobs) > 0 do
    job = List.first(jobs)
    case job do
      %{"title" => title, "company" => company} -> "#{title} at #{company}"
      %{"title" => title} -> title
      _ -> "Experience entry"
    end
  end
  defp extract_jobs_preview(_), do: nil

  defp extract_skills_preview(%{"skills" => skills}) when is_list(skills) and length(skills) > 0 do
    skills |> Enum.take(3) |> Enum.join(", ")
  end
  defp extract_skills_preview(_), do: nil

  defp get_public_content(content) when is_map(content) do
    Map.get(content, "main_content") ||
    Map.get(content, "summary") ||
    Map.get(content, "description") ||
    render_jobs_content(content) ||
    render_skills_content(content) ||
    ""
  end
  defp get_public_content(_), do: ""

  defp render_block_content(block, assigns) do
    assigns = assign(assigns, :block, block)
    block_type = get_block_type_safe(block)

    case block_type do
      type when type in [:video_hero, "video_hero"] ->
        render_video_hero_block(assigns)
      type when type in [:experience, :experience_card, "experience", "experience_card"] ->
        render_experience_block(assigns)
      type when type in [:skills, :skills_card, "skills", "skills_card"] ->
        render_skills_block(assigns)
      _ ->
        render_standard_block(assigns)
    end
  end

  defp render_experience_block(assigns) do
    block = assigns.block
    content = get_block_content_safe(block)
    jobs = Map.get(content, "jobs", [])

    assigns = assigns
    |> assign(:content, content)
    |> assign(:jobs, jobs)

    ~H"""
    <div class="experience-block bg-white rounded-lg border border-gray-200 p-6 hover:shadow-md transition-shadow">
      <div class="flex items-start justify-between mb-4">
        <div class="flex-1">
          <h3 class="font-semibold text-gray-900 mb-1">
            <%= get_block_title_safe(@block) %>
          </h3>
          <p class="text-sm text-gray-600">
            Experience • <%= length(@jobs) %> <%= if length(@jobs) == 1, do: "position", else: "positions" %>
          </p>
        </div>
      </div>

      <!-- Jobs Preview -->
      <div class="space-y-3">
        <%= for {job, index} <- Enum.with_index(Enum.take(@jobs, 2)) do %>
          <div class="text-sm">
            <p class="font-medium text-gray-900">
              <%= Map.get(job, "title", "Position") %>
            </p>
            <p class="text-gray-600">
              <%= Map.get(job, "company", "Company") %>
            </p>
          </div>
        <% end %>

        <%= if length(@jobs) > 2 do %>
          <p class="text-xs text-gray-500">
            + <%= length(@jobs) - 2 %> more positions
          </p>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_skills_block(assigns) do
    block = assigns.block
    content = get_block_content_safe(block)
    skills = Map.get(content, "skills", [])

    assigns = assigns
    |> assign(:content, content)
    |> assign(:skills, skills)

    ~H"""
    <div class="skills-block bg-white rounded-lg border border-gray-200 p-6 hover:shadow-md transition-shadow">
      <div class="flex items-start justify-between mb-4">
        <div class="flex-1">
          <h3 class="font-semibold text-gray-900 mb-1">
            <%= get_block_title_safe(@block) %>
          </h3>
          <p class="text-sm text-gray-600">
            Skills • <%= length(@skills) %> <%= if length(@skills) == 1, do: "skill", else: "skills" %>
          </p>
        </div>
      </div>

      <!-- Skills Preview -->
      <div class="flex flex-wrap gap-1">
        <%= for skill <- Enum.take(@skills, 6) do %>
          <span class="inline-block bg-blue-100 text-blue-800 px-2 py-1 rounded text-xs">
            <%= skill %>
          </span>
        <% end %>

        <%= if length(@skills) > 6 do %>
          <span class="inline-block bg-gray-100 text-gray-600 px-2 py-1 rounded text-xs">
            +<%= length(@skills) - 6 %> more
          </span>
        <% end %>
      </div>
    </div>
    """
  end

  # Update the standard block renderer to use safe helpers
  defp render_standard_block(assigns) do
    block = assigns.block
    content = get_block_content_safe(block)
    assigns = assign(assigns, :content, content)

    ~H"""
    <div class="standard-block bg-white rounded-lg border border-gray-200 p-6 hover:shadow-md transition-shadow">
      <div class="flex items-start justify-between mb-4">
        <div class="flex-1">
          <h3 class="font-semibold text-gray-900 mb-1">
            <%= get_block_title_safe(@block) %>
          </h3>
          <p class="text-sm text-gray-600 capitalize">
            <%= get_display_block_type(@block) %>
          </p>
        </div>
      </div>

      <!-- Content Preview -->
      <div class="text-sm text-gray-600">
        <%= case get_preview_content(get_content_safe(assigns)) do %>
          <% content when is_binary(content) and content != "" -> %>
            <%= String.slice(content, 0, 120) %><%= if String.length(content) > 120, do: "...", else: "" %>
          <% _ -> %>
            <em>No content added yet</em>
        <% end %>
      </div>
    </div>
    """
  end

  defp get_content_safe(assigns_or_block) do
    case assigns_or_block do
      %{content_data: content} when is_map(content) -> content
      %{content: content} when is_map(content) -> content
      %{"content_data" => content} when is_map(content) -> content
      %{"content" => content} when is_map(content) -> content
      _ -> %{}
    end
  end

  # Update visibility helper functions for events
  defp update_block_visibility_in_zones(layout_zones, block_id, visible) do
    Enum.reduce(layout_zones, %{}, fn {zone_name, blocks}, acc ->
      updated_blocks = Enum.map(blocks, fn block ->
        if get_block_id(block) == block_id do
          Map.put(block, :visible, visible)
        else
          block
        end
      end)
      Map.put(acc, zone_name, updated_blocks)
    end)
  end

  defp remove_block_from_zones(layout_zones, block_id) do
    Enum.reduce(layout_zones, %{}, fn {zone_name, blocks}, acc ->
      updated_blocks = Enum.reject(blocks, fn block ->
        get_block_id(block) == block_id
      end)
      Map.put(acc, zone_name, updated_blocks)
    end)
  end

  defp render_block_content_public(block, assigns) do
    assigns = assign(assigns, :block, block)

    # Handle both section_type and block_type for compatibility
    block_type = Map.get(block, :section_type) || Map.get(block, :block_type) ||
                 Map.get(block, "section_type") || Map.get(block, "block_type")

    case block_type do
      type when type in [:video_hero, "video_hero"] -> render_video_hero_public(assigns)
      _ -> render_standard_block_public(assigns)
    end
  end

  defp render_jobs_content(%{"jobs" => jobs}) when is_list(jobs) and length(jobs) > 0 do
    jobs
    |> Enum.map(fn job ->
      title = Map.get(job, "title", "")
      company = Map.get(job, "company", "")
      description = Map.get(job, "description", "")

      """
      <div class="mb-6">
        <h3 class="text-xl font-semibold">#{title}</h3>
        <p class="text-gray-600 mb-2">#{company}</p>
        <p>#{description}</p>
      </div>
      """
    end)
    |> Enum.join("")
  end
  defp render_jobs_content(_), do: nil

  defp render_skills_content(%{"skills" => skills}) when is_list(skills) and length(skills) > 0 do
    skills_html = skills
    |> Enum.map(&"<span class='inline-block bg-blue-100 text-blue-800 px-3 py-1 rounded-full text-sm mr-2 mb-2'>#{&1}</span>")
    |> Enum.join("")

    "<div class='flex flex-wrap'>#{skills_html}</div>"
  end
  defp render_skills_content(_), do: nil

  defp render_video_hero_public(assigns) do
    # Similar to editor version but without edit controls
    block = assigns.block
    content = Map.get(block, :content, %{}) # Updated to content_data
    section_media = get_section_media(block.id)
    video_media = Enum.find(section_media, &is_video_media?/1)

    assigns = assigns
    |> assign(:content, content)
    |> assign(:video_media, video_media)
    |> assign(:video_url, get_video_url_from_content(content, video_media))
    |> assign(:thumbnail_url, get_thumbnail_url_from_content(content, video_media))

    ~H"""
    <div class="video-hero-public relative bg-gray-900 overflow-hidden min-h-[500px]">
      <%= if @video_url do %>
        <div class="video-container relative w-full h-full">
          <div class="video-thumbnail relative w-full h-full cursor-pointer"
               data-video-url={@video_url}
               data-embed-url={if @video_media, do: get_embed_url(@video_media), else: nil}>

            <%= if @thumbnail_url do %>
              <img src={@thumbnail_url}
                   alt="Video thumbnail"
                   class="w-full h-full object-cover">
            <% else %>
              <div class="w-full h-full bg-gradient-to-br from-purple-900 to-blue-900"></div>
            <% end %>

            <div class="absolute inset-0 flex items-center justify-center">
              <div class="bg-black bg-opacity-50 rounded-full p-6 hover:bg-opacity-70 transition-all duration-200 transform hover:scale-110">
                <svg class="w-16 h-16 text-white" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M8 5v14l11-7z"/>
                </svg>
              </div>
            </div>
          </div>

          <%
            content = get_content_safe(assigns)
          %>
          <%= if Map.get(content, "overlay_text", true) do %>
            <div class="absolute inset-0 bg-black bg-opacity-30 flex items-center justify-center">
              <div class="text-center text-white p-8">
                <h1 class="text-5xl md:text-6xl font-bold mb-6">
                  <%= Map.get(content, "headline", "Welcome") %>
                </h1>
                <!-- ... rest stays exactly the same, just @content becomes content -->
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_standard_block_public(assigns) do
    # Standard public block rendering
    block = assigns.block
    content = Map.get(block, :content, %{}) || Map.get(block, :content_data, %{})

    # Handle both content and content_data for compatibility
    content = if Map.size(content) == 0 do
      Map.get(block, :content_data, %{})
    else
      content
    end

    ~H"""
    <div class="standard-block-public max-w-4xl mx-auto px-6 py-8">
      <h2 class="text-3xl font-bold text-gray-900 mb-6">
        <%= Map.get(block, :title, "Untitled") %>
      </h2>
      <div class="prose prose-lg max-w-none">
        <%= case Map.get(content, "main_content") || Map.get(content, "summary") do %>
          <% content when is_binary(content) and content != "" -> %>
            <%= raw(content) %>
          <% _ -> %>
            <p class="text-gray-600">Content coming soon...</p>
        <% end %>
      </div>
    </div>
    """
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp get_current_layout_config(portfolio, brand_settings) do
    %{
      theme: portfolio.theme || "professional",
      customization: portfolio.customization || %{},
      brand_settings: brand_settings
    }
  end

  defp get_block_type_safe(block) do
    case block do
      %{block_type: block_type} -> block_type
      %{type: type} -> type
      %{"block_type" => block_type} -> block_type
      %{"type" => type} -> type
      _ -> "text_card"
    end
  end

  defp get_block_name_safe(block) do
    case block do
      %{name: name} when is_binary(name) -> name
      %{"name" => name} when is_binary(name) -> name
      %{title: title} when is_binary(title) -> title
      %{"title" => title} when is_binary(title) -> title
      _ -> "Content Block"
    end
  end

  defp get_block_category_safe(block) do
    case block do
      %{category: category} -> String.capitalize(to_string(category))
      %{"category" => category} -> String.capitalize(to_string(category))
      _ -> "General"
    end
  end

  defp update_block_visibility_in_zones(layout_zones, block_id, visible) do
    Enum.reduce(layout_zones, %{}, fn {zone_name, blocks}, acc ->
      updated_blocks = Enum.map(blocks, fn block ->
        if block.id == block_id do
          Map.put(block, :visible, visible)
        else
          block
        end
      end)
      Map.put(acc, zone_name, updated_blocks)
    end)
  end

  defp remove_block_from_zones(layout_zones, block_id) do
    Enum.reduce(layout_zones, %{}, fn {zone_name, blocks}, acc ->
      updated_blocks = Enum.reject(blocks, fn block ->
        block.id == block_id
      end)
      Map.put(acc, zone_name, updated_blocks)
    end)
  end

  defp add_block_to_zone(layout_zones, zone_name, new_block) do
    Map.update(layout_zones, zone_name, [new_block], fn existing_blocks ->
      existing_blocks ++ [new_block]
    end)
  end

  defp update_block_in_zones(layout_zones, block_id, updated_block) do
    Enum.reduce(layout_zones, %{}, fn {zone_name, blocks}, acc ->
      updated_blocks = Enum.map(blocks, fn block ->
        if block.id == block_id do
          updated_block
        else
          block
        end
      end)
      Map.put(acc, zone_name, updated_blocks)
    end)
  end

  defp find_block_in_zones(layout_zones, block_id) do
    Enum.find_value(layout_zones, fn {_zone_name, blocks} ->
      Enum.find(blocks, fn block -> block.id == block_id end)
    end)
    |> case do
      nil -> {:error, :not_found}
      block -> {:ok, block}
    end
  end

  defp parse_block_id(block_id) do
    if is_binary(block_id), do: String.to_integer(block_id), else: block_id
  end

  defp update_block_content(block, changes) do
    # Merge changes into existing content_data
    %{block | content_data: Map.merge(block.content_data, changes)}
  end

  defp save_layout_zones_to_database(layout_zones, portfolio_id) do
    # This is a placeholder. You'll need to implement the actual database saving logic.
    # It should iterate through layout_zones and create/update/delete Frestyl.Portfolios.Section records.
    # For now, it just simulates success.
    IO.puts("Simulating saving layout zones to database for portfolio #{portfolio_id}...")
    # Example: Portfolios.sync_sections_from_layout(portfolio_id, layout_zones)
    {:ok, %{sections_synced: true}}
  end

  defp clean_and_reset_layout_zones(layout_zones) do
    # This is a placeholder for a more complex data cleaning/migration function.
    # For now, it simply re-applies the default clean structure for existing blocks.
    Enum.reduce(layout_zones, %{}, fn {zone_name, blocks}, acc ->
      cleaned_blocks = Enum.map(blocks, fn block ->
        cleaned_content = get_clean_block_structure(block.block_type)
        %{block | content_data: cleaned_content}
      end)
      Map.put(acc, zone_name, cleaned_blocks)
    end)
  end

  defp schedule_save_status_reset(socket) do
    # Cancel any existing timer
    if socket.assigns[:save_status_timer] do
      Process.cancel_timer(socket.assigns.save_status_timer)
    end

    # Schedule a message to reset save status after 3 seconds
    timer = Process.send_after(self(), {:reset_save_status, socket.assigns.myself}, 3000)

    assign(socket, :save_status_timer, timer)
  end

  @impl true
  def handle_info({:reset_save_status, component_pid}, socket) do
    if socket.assigns.myself == component_pid do
      {:noreply, assign(socket, :save_status, nil)}
    else
      {:noreply, socket}
    end
  end

  defp get_section_media(section_id) do
    try do
      # Assuming Portfolios.list_section_media takes a section ID and returns a list of media records
      # If your media fetching logic is different, adjust this.
      Portfolios.list_section_media(section_id)
    rescue
      _ -> []
    end
  end

  defp is_video_media?(media) do
    case media do
      %{file_type: file_type} when is_binary(file_type) ->
        String.starts_with?(file_type, "video/") or file_type == "video/external"
      %{is_external_video: true} -> true
      _ -> false
    end
  end

  defp get_thumbnail_url_from_content(content, video_media) do
    cond do
      video_media && Map.get(video_media, :video_thumbnail_url) ->
        video_media.video_thumbnail_url
      video_media && is_external_video?(video_media) ->
        get_external_thumbnail_url(video_media)
      Map.has_key?(content, "poster_image") ->
        Map.get(content, "poster_image")
      true ->
        nil
    end
  end

  defp get_thumbnail_url_from_content(content, video_media) do
    cond do
      video_media && Map.get(video_media, :video_thumbnail_url) ->
        video_media.video_thumbnail_url
      video_media && is_external_video?(video_media) ->
        get_external_thumbnail_url(video_media)
      Map.has_key?(content, "poster_image") ->
        Map.get(content, "poster_image")
      true ->
        nil
    end
  end

  defp is_external_video?(media) do
    Map.get(media, :is_external_video, false)
  end

  defp get_embed_url(media) do
    if is_external_video?(media) do
      case media.external_video_platform do
        "youtube" -> "https://www.youtube.com/embed/#{media.external_video_id}?autoplay=1"
        "vimeo" -> "https://player.vimeo.com/video/#{media.external_video_id}?autoplay=1"
        _ -> nil
      end
    else
      nil
    end
  end

  defp get_external_thumbnail_url(media) do
    case media.external_video_platform do
      "youtube" -> "https://img.youtube.com/vi/#{media.external_video_id}/maxresdefault.jpg"
      "vimeo" -> nil  # Would need API call
      _ -> nil
    end
  end


  defp get_all_block_types do
    [
      # FREE (Personal Tier) - 8 blocks
      {"hero_card", %{name: "Hero Section", description: "Main header with title/video", icon: "🎬", required_tier: :personal}},
      {"about_card", %{name: "About", description: "Personal introduction", icon: "👤", required_tier: :personal}},
      {"experience_card", %{name: "Experience", description: "Work history", icon: "💼", required_tier: :personal}},
      {"skills_card", %{name: "Skills", description: "Technical abilities", icon: "⚡", required_tier: :personal}},
      {"projects_card", %{name: "Projects", description: "Portfolio showcase", icon: "🎨", required_tier: :personal}},
      {"contact_card", %{name: "Contact", description: "Contact information", icon: "📧", required_tier: :personal}},
      {"achievements_card", %{name: "Achievements", description: "Awards and milestones", icon: "🏆", required_tier: :personal}},
      {"media_showcase_card", %{name: "Media Gallery", description: "Photos and videos", icon: "📸", required_tier: :personal}},
      {"video_hero", %{name: "Video Hero", description: "A large video background section", icon: "🎥", required_tier: :personal}}, # Added new video hero block

      # CREATOR+ Tier - 6 blocks
      {"social_card", %{name: "Social Media", description: "Social platform showcase", icon: "📱", required_tier: :creator}},
      {"audio_showcase_card", %{name: "Audio Showcase", description: "Music and podcasts", icon: "🎵", required_tier: :creator}},
      {"video_showcase_card", %{name: "Video Showcase", description: "Video portfolio", icon: "🎥", required_tier: :creator}},
      {"visual_art_card", %{name: "Visual Art", description: "Art and design portfolio", icon: "🎨", required_tier: :creator}},
      {"social_embed_card", %{name: "Social Embeds", description: "Embedded social content", icon: "📲", required_tier: :creator}},
      {"video_embed_card", %{name: "Video Embeds", description: "YouTube, TikTok embeds", icon: "📺", required_tier: :creator}},

      # PROFESSIONAL+ Tier - 5 blocks
      {"services_card", %{name: "Services", description: "Service offerings with pricing", icon: "🛠️", required_tier: :professional}},
      {"testimonials_card", %{name: "Testimonials", description: "Client feedback and reviews", icon: "💬", required_tier: :professional}},
      {"business_embed_card", %{name: "Business Tools", description: "Calendly, forms, maps", icon: "📊", required_tier: :professional}},
      {"code_showcase_card", %{name: "Code Showcase", description: "Programming demos", icon: "💻", required_tier: :professional}},
      {"interactive_demo_card", %{name: "Interactive Demo", description: "Live app demos", icon: "🚀", required_tier: :professional}},

      # ENTERPRISE Tier - 3 blocks
      {"audio_embed_card", %{name: "Audio Embeds", description: "Spotify, podcast embeds", icon: "🎧", required_tier: :enterprise}},
      {"code_embed_card", %{name: "Code Embeds", description: "GitHub, CodePen embeds", icon: "⚡", required_tier: :enterprise}},
      {"presentation_embed_card", %{name: "Presentations", description: "Slides, Figma embeds", icon: "📋", required_tier: :enterprise}}
    ]
  end

  defp get_available_blocks_for_tier(account) do
    get_all_block_types()
    |> Enum.filter(fn {block_type, _block_info} ->
      can_use_block_type?(account, String.to_atom(block_type))
    end)
  end

  defp get_restricted_blocks_for_tier(account) do
    get_all_block_types()
    |> Enum.reject(fn {block_type, _block_info} ->
      can_use_block_type?(account, String.to_atom(block_type))
    end)
    |> Enum.take(3) # Show only top 3 restricted blocks
  end

  defp humanize_block_type(block_type) when is_atom(block_type) do
    block_type
    |> to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  # This function needs to be implemented to render the actual edit modal for a block
  defp render_edit_modal(assigns) do
    # This is a placeholder. You'll need a way to render the specific editor for the editing_block.
    # It might involve another LiveComponent or a form based on the block type.
    editing_block = assigns.editing_block
    block_id = assigns.editing_block_id
    save_status = assigns.save_status

    ~H"""
    <div class="fixed inset-0 z-50 overflow-y-auto" aria-labelledby="edit-modal" role="dialog" aria-modal="true">
      <div class="flex items-center justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
        <div class="fixed inset-0 bg-gray-900 bg-opacity-75 transition-opacity"
             phx-click="cancel_block_edit"
             phx-target={@myself}></div>

        <div class="inline-block align-bottom bg-white rounded-xl text-left overflow-hidden shadow-2xl transform transition-all sm:my-8 sm:align-middle sm:max-w-xl sm:w-full">
          <div class="bg-gradient-to-r from-blue-600 to-indigo-600 px-6 py-4">
            <div class="flex items-center justify-between">
              <h3 class="text-lg font-bold text-white">
                Edit <%= humanize_block_type(Map.get(editing_block, :block_type, :block)) %>
              </h3>
              <button phx-click="cancel_block_edit"
                      phx-target={@myself}
                      class="text-white hover:text-gray-200">
                <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>
          </div>

          <div class="px-6 py-6">
            <form phx-submit="save_block_changes" phx-target={@myself}>
              <input type="hidden" name="block_id" value={block_id}/>

              <div class="space-y-4 mb-6">
                <div>
                  <label for="block-title" class="block text-sm font-medium text-gray-700">Title</label>
                  <input type="text" name="changes[title]" id="block-title"
                         value={Map.get(editing_block.content_data, "title", "")}
                         class="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:outline-none focus:ring-blue-500 focus:border-blue-500 sm:text-sm"/>
                </div>

                <%= if Map.get(editing_block, :block_type) == :video_hero do %>
                  <div>
                    <label for="video-url" class="block text-sm font-medium text-gray-700">Video URL</label>
                    <input type="text" name="changes[video_url]" id="video-url"
                           value={Map.get(editing_block.content_data, "video_url", "")}
                           class="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:outline-none focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
                           placeholder="Enter YouTube or Vimeo URL"/>
                    <p class="mt-2 text-xs text-gray-500">For uploaded videos, use the "Attach Media" button.</p>
                  </div>
                <% end %>

                </div>

              <div class="text-right text-sm font-medium mt-4">
                <%= case save_status do %>
                  <% :idle -> %> <span class="text-gray-500"></span>
                  <% :saving -> %> <span class="text-blue-500 animate-pulse">Saving...</span>
                  <% :saved -> %> <span class="text-green-500">Saved!</span>
                  <% :error -> %> <span class="text-red-500">Error!</span>
                <% end %>
              </div>

              <div class="bg-gray-50 px-6 py-4 mt-6 sm:flex sm:flex-row-reverse rounded-b-xl">
                <button type="submit"
                        class="w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 bg-blue-600 text-base font-medium text-white hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 sm:ml-3 sm:w-auto sm:text-sm">
                  Save Changes
                </button>
                <button type="button"
                        phx-click="cancel_block_edit"
                        phx-target={@myself}
                        class="mt-3 w-full inline-flex justify-center rounded-md border border-gray-300 shadow-sm px-4 py-2 bg-white text-base font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 sm:mt-0 sm:ml-3 sm:w-auto sm:text-sm">
                  Cancel
                </button>
              </div>
            </form>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp render_upgrade_modal(assigns) do
    ~H"""
    <%= if @show_upgrade_modal do %>
      <div class="fixed inset-0 z-50 overflow-y-auto" aria-labelledby="upgrade-modal" role="dialog" aria-modal="true">
        <div class="flex items-center justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
          <div class="fixed inset-0 bg-gray-900 bg-opacity-75 transition-opacity"
               phx-click="close_upgrade_modal"
               phx-target={@myself}></div>

          <div class="inline-block align-bottom bg-white rounded-xl text-left overflow-hidden shadow-2xl transform transition-all sm:my-8 sm:align-middle sm:max-w-lg sm:w-full">
            <div class="bg-gradient-to-r from-purple-600 to-blue-600 px-6 py-4">
              <div class="flex items-center justify-between">
                <h3 class="text-lg font-bold text-white">
                  Upgrade Required
                </h3>
                <button phx-click="close_upgrade_modal"
                        phx-target={@myself}
                        class="text-white hover:text-gray-200">
                  <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </div>
            </div>

            <div class="px-6 py-6">
              <div class="text-center mb-6">
                <div class="mx-auto flex items-center justify-center h-16 w-16 rounded-full bg-amber-100 mb-4">
                  <svg class="h-8 w-8 text-amber-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m0 0v2m0-2h2m-2 0H10m4-6V7a3 3 0 00-6 0v4m4 0H8m8 0a2 2 0 012 2v4a2 2 0 01-2 2H8a2 2 0 01-2-2v-4a2 2 0 012-2" />
                  </svg>
                </div>

                <h4 class="text-xl font-bold text-gray-900 mb-2">
                  <%= humanize_block_type(@blocked_block_type) %> Block
                </h4>

                <p class="text-gray-600">
                  This block type requires a
                  <span class="font-semibold text-purple-600"><%= format_tier_name(@required_tier) %></span>
                  subscription or higher.
                </p>
              </div>

              <div class="bg-gray-50 rounded-lg p-4 mb-6">
                <h5 class="font-semibold text-gray-900 mb-2">
                  <%= format_tier_name(@required_tier) %> Plan Includes:
                </h5>
                <ul class="text-sm text-gray-600 space-y-1">
                  <%= for benefit <- get_tier_benefits(@required_tier) do %>
                    <li class="flex items-center">
                      <svg class="h-4 w-4 text-green-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
                        <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" />
                      </svg>
                      <%= benefit %>
                    </li>
                  <% end %>
                </ul>
              </div>
            </div>

            <div class="bg-gray-50 px-6 py-4 sm:flex sm:flex-row-reverse rounded-b-xl">
              <button type="button"
                      phx-click="upgrade_account"
                      phx-target={@myself}
                      class="w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 bg-purple-600 text-base font-medium text-white hover:bg-purple-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-purple-500 sm:ml-3 sm:w-auto sm:text-sm">
                Upgrade Account
              </button>
              <button type="button"
                      phx-click="close_upgrade_modal"
                      phx-target={@myself}
                      class="mt-3 w-full inline-flex justify-center rounded-md border border-gray-300 shadow-sm px-4 py-2 bg-white text-base font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 sm:mt-0 sm:ml-3 sm:w-auto sm:text-sm">
                Cancel
              </button>
            </div>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp humanize_zone_name(zone_name) do
    zone_name
    |> to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end
end
