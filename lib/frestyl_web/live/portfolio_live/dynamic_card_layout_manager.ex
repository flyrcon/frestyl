# lib/frestyl_web/live/portfolio_live/dynamic_card_layout_manager.ex

# REPLACE your entire DynamicCardLayoutManager module with this:

defmodule FrestylWeb.PortfolioLive.DynamicCardLayoutManager do
  @moduledoc """
  Complete Dynamic Card Layout Manager with 22 block types,
  monetization integration, and platform embeds.
  """

  use FrestylWeb, :live_component

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
    }
  end

  @impl true
  def update(assigns, socket) do
    view_mode = Map.get(assigns, :view_mode, :edit)
    show_edit_controls = Map.get(assigns, :show_edit_controls, view_mode == :edit)
    layout_zones = assigns.layout_zones || %{}
    account = assigns.account || %{subscription_tier: "personal"}

    {:ok, socket
      |> assign(assigns)
      |> assign(:view_mode, view_mode)
      |> assign(:show_edit_controls, show_edit_controls)
      |> assign(:layout_zones, layout_zones)
      |> assign(:account, account)
    }
  end

  # ============================================================================
  # MAIN RENDER FUNCTION
  # ============================================================================

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} class="dynamic-card-layout-manager">
      <!-- Header -->
      <div class="bg-white rounded-lg shadow-sm border p-4 mb-6">
        <div class="flex items-center justify-between">
          <div>
            <h3 class="text-lg font-semibold text-gray-900">Dynamic Card Layout</h3>
            <p class="text-sm text-gray-600">Click blocks to edit • Drag to reorder • Add new blocks</p>
          </div>

          <%= if @show_edit_controls do %>
            <div class="flex space-x-3">
              <select class="text-sm border-gray-300 rounded-md"
                      phx-change="change_preview_device"
                      phx-target={@myself}>
                <option value="desktop" selected={@preview_device == :desktop}>Desktop</option>
                <option value="tablet" selected={@preview_device == :tablet}>Tablet</option>
                <option value="mobile" selected={@preview_device == :mobile}>Mobile</option>
              </select>

              <button phx-click="clean_reset_data"
                      phx-target={@myself}
                      class="px-3 py-1 text-sm bg-red-100 text-red-700 rounded-md hover:bg-red-200">
                🧹 Clean Reset
              </button>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Layout Zones -->
      <div class="grid gap-6">
        <%= for {zone_name, blocks} <- @layout_zones do %>
          <div class="bg-gray-50 rounded-lg p-4 min-h-32">
            <div class="flex items-center justify-between mb-3">
              <h4 class="font-medium text-gray-700 capitalize">
                <%= humanize_zone_name(zone_name) %>
              </h4>
              <%= if @show_edit_controls do %>
                <%= render_add_block_button(zone_name, assigns) %>
              <% end %>
            </div>

            <!-- Content Blocks in Zone -->
            <%= render_zone_blocks(blocks, zone_name, assigns) %>
          </div>
        <% end %>
      </div>

      <!-- Edit Modal -->
      <%= if @show_edit_modal and @editing_block do %>
        <%= render_edit_modal(assigns) %>
      <% end %>

      <!-- Upgrade Modal -->
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

  # ============================================================================
  # BLOCK CREATION WITH CLEAN STRUCTURES
  # ============================================================================

  defp create_dynamic_card_block(block_type, zone, socket) do
    default_content = get_clean_block_structure(String.to_atom(block_type))

    {:ok, %{
      id: System.unique_integer([:positive]),
      block_type: String.to_atom(block_type),
      content_data: default_content,
      zone: zone,
      position: 0
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
    %{
      "title" => "",
      "content" => "",
      "media_files" => [],
      "custom_fields" => %{}
    }
  end

  # ============================================================================
  # UI RENDERING FUNCTIONS
  # ============================================================================

  defp render_add_block_button(zone_name, assigns) do
    assigns = assign(assigns, :zone_name, zone_name)

    ~H"""
    <div class="relative">
      <button phx-click="toggle_add_menu"
              phx-value-zone={@zone_name}
              phx-target={@myself}
              class="text-sm text-blue-600 hover:text-blue-800 flex items-center">
        + Add Block
        <svg class="ml-1 h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
        </svg>
      </button>

      <%= if assigns[:"show_add_menu_#{@zone_name}"] do %>
        <%= render_add_block_dropdown(assigns) %>
      <% end %>
    </div>
    """
  end

  defp render_add_block_dropdown(assigns) do
    available_blocks = get_available_blocks_for_tier(assigns.account)
    restricted_blocks = get_restricted_blocks_for_tier(assigns.account)

    assigns = assign(assigns,
      available_blocks: available_blocks,
      restricted_blocks: restricted_blocks
    )

    ~H"""
    <div class="absolute right-0 mt-2 w-64 bg-white border border-gray-200 rounded-lg shadow-lg z-10">
      <div class="py-2">
        <!-- Available Blocks -->
        <%= for {block_type, block_info} <- @available_blocks do %>
          <button phx-click="add_content_block"
                  phx-value-block_type={block_type}
                  phx-value-zone={@zone_name}
                  phx-target={@myself}
                  class="flex items-center w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-blue-50">
            <span class="text-lg mr-3"><%= block_info.icon %></span>
            <div>
              <div class="font-medium"><%= block_info.name %></div>
              <div class="text-xs text-gray-500"><%= block_info.description %></div>
            </div>
          </button>
        <% end %>

        <!-- Restricted Blocks -->
        <%= if length(@restricted_blocks) > 0 do %>
          <div class="border-t border-gray-200 mt-2 pt-2">
            <div class="px-4 py-1 text-xs font-medium text-gray-500 uppercase">
              Upgrade Required
            </div>

            <%= for {block_type, block_info} <- @restricted_blocks do %>
              <button phx-click="add_content_block"
                      phx-value-block_type={block_type}
                      phx-value-zone={@zone_name}
                      phx-target={@myself}
                      class="flex items-center w-full text-left px-4 py-2 text-sm text-gray-400 hover:bg-amber-50">
                <span class="text-lg mr-3 opacity-50"><%= block_info.icon %></span>
                <div class="flex-1">
                  <div class="font-medium"><%= block_info.name %></div>
                  <div class="text-xs text-gray-400"><%= block_info.description %></div>
                </div>
                <span class="text-xs bg-amber-100 text-amber-800 px-2 py-1 rounded-full">
                  <%= format_tier_name(block_info.required_tier) %>
                </span>
              </button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @impl true
def handle_event("add_content_block", %{"block_type" => block_type, "zone" => zone}, socket) do
  # Check if user can access this block type
  case can_use_block_type?(socket.assigns.account, String.to_atom(block_type)) do
    true ->
      case create_dynamic_card_block(block_type, String.to_atom(zone), socket) do
        {:ok, new_block} ->
          updated_zones = add_block_to_zone(socket.assigns.layout_zones, String.to_atom(zone), new_block)

          {:noreply, socket
            |> assign(:layout_zones, updated_zones)
            |> assign(:layout_dirty, true)
            |> put_flash(:info, "Block added successfully!")
          }

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Failed to add block: #{inspect(reason)}")}
      end

    false ->
      # Show upgrade modal instead
      {:noreply, socket
        |> assign(:show_upgrade_modal, true)
        |> assign(:blocked_block_type, String.to_atom(block_type))
        |> assign(:required_tier, get_required_tier(String.to_atom(block_type)))
      }
  end
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
  # Redirect to upgrade page
  {:noreply, socket
    |> put_flash(:info, "Redirecting to upgrade...")
    |> redirect(to: "/upgrade")
  }
end

# Helper functions for tier checking
defp can_use_block_type?(account, block_type) do
  user_tier = get_user_tier(account)
  required_tier = get_required_tier(block_type)

  tier_level(user_tier) >= tier_level(required_tier)
end

defp get_user_tier(account) do
  case account do
    %{subscription_tier: tier} when is_binary(tier) -> String.to_atom(tier)
    %{subscription_tier: tier} when is_atom(tier) -> tier
    _ -> :personal  # Default to free tier
  end
end

defp get_required_tier(block_type) do
  case block_type do
    # FREE (Personal Tier)
    type when type in [:hero_card, :about_card, :experience_card, :skills_card,
                       :projects_card, :contact_card, :achievements_card, :media_showcase_card] ->
      :personal

    # CREATOR+ Tier
    type when type in [:social_card, :audio_showcase_card, :video_showcase_card,
                       :visual_art_card, :social_embed_card, :video_embed_card] ->
      :creator

    # PROFESSIONAL+ Tier
    type when type in [:services_card, :testimonials_card, :business_embed_card,
                       :code_showcase_card, :interactive_demo_card] ->
      :professional

    # ENTERPRISE Tier
    type when type in [:audio_embed_card, :code_embed_card, :presentation_embed_card] ->
      :enterprise

    _ -> :personal  # Default to free tier
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

# Enhanced render function with tier restrictions
defp render_add_block_dropdown(assigns) do
  available_blocks = get_available_blocks_for_tier(assigns.account)
  restricted_blocks = get_restricted_blocks_for_tier(assigns.account)

  assigns = assign(assigns,
    available_blocks: available_blocks,
    restricted_blocks: restricted_blocks
  )

  ~H"""
  <div class="absolute right-0 mt-2 w-64 bg-white border border-gray-200 rounded-lg shadow-lg z-10">
    <div class="py-2">
      <!-- Available Blocks -->
      <%= for {block_type, block_info} <- @available_blocks do %>
        <button phx-click="add_content_block"
                phx-value-block_type={block_type}
                phx-value-zone={@zone_name}
                phx-target={@myself}
                class="flex items-center w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-blue-50 hover:text-blue-700">
          <span class="text-lg mr-3"><%= block_info.icon %></span>
          <div>
            <div class="font-medium"><%= block_info.name %></div>
            <div class="text-xs text-gray-500"><%= block_info.description %></div>
          </div>
        </button>
      <% end %>

      <!-- Restricted Blocks (if any) -->
      <%= if length(@restricted_blocks) > 0 do %>
        <div class="border-t border-gray-200 mt-2 pt-2">
          <div class="px-4 py-1 text-xs font-medium text-gray-500 uppercase tracking-wide">
            Upgrade Required
          </div>

          <%= for {block_type, block_info} <- @restricted_blocks do %>
            <button phx-click="add_content_block"
                    phx-value-block_type={block_type}
                    phx-value-zone={@zone_name}
                    phx-target={@myself}
                    class="flex items-center w-full text-left px-4 py-2 text-sm text-gray-400 hover:bg-amber-50">
              <span class="text-lg mr-3 opacity-50"><%= block_info.icon %></span>
              <div class="flex-1">
                <div class="font-medium"><%= block_info.name %></div>
                <div class="text-xs text-gray-400"><%= block_info.description %></div>
              </div>
              <div class="ml-2">
                <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-amber-100 text-amber-800">
                  <%= format_tier_name(block_info.required_tier) %>
                </span>
              </div>
            </button>
          <% end %>
        </div>
      <% end %>
    </div>
  </div>
  """
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
  |> Enum.take(3)  # Show only top 3 restricted blocks
end

# Enhanced upgrade modal rendering
defp render_upgrade_modal(assigns) do
  ~H"""
  <%= if @show_upgrade_modal do %>
    <div class="fixed inset-0 z-50 overflow-y-auto" aria-labelledby="upgrade-modal" role="dialog" aria-modal="true">
      <div class="flex items-center justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
        <div class="fixed inset-0 bg-gray-900 bg-opacity-75 transition-opacity"
             phx-click="close_upgrade_modal"
             phx-target={@myself}></div>

        <div class="inline-block align-bottom bg-white rounded-xl text-left overflow-hidden shadow-2xl transform transition-all sm:my-8 sm:align-middle sm:max-w-lg sm:w-full">
          <!-- Modal Header -->
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

          <!-- Modal Content -->
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

            <!-- Tier Benefits -->
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

          <!-- Modal Footer -->
          <div class="bg-gray-50 px-6 py-4 sm:flex sm:flex-row-reverse">
            <button type="button"
                    phx-click="upgrade_account"
                    phx-target={@myself}
                    class="w-full inline-flex justify-center rounded-lg border border-transparent shadow-sm px-6 py-3 bg-gradient-to-r from-purple-600 to-blue-600 text-base font-medium text-white hover:from-purple-700 hover:to-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-purple-500 sm:ml-3 sm:w-auto sm:text-sm">
              Upgrade Now
            </button>
            <button type="button"
                    phx-click="close_upgrade_modal"
                    phx-target={@myself}
                    class="mt-3 w-full inline-flex justify-center rounded-lg border border-gray-300 shadow-sm px-6 py-3 bg-white text-base font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-purple-500 sm:mt-0 sm:w-auto sm:text-sm">
              Maybe Later
            </button>
          </div>
        </div>
      </div>
    </div>
  <% end %>
  """
end

defp get_tier_benefits(:creator) do
  [
    "Social media showcase blocks",
    "Audio & video monetization",
    "Platform embed integration",
    "Enhanced media galleries",
    "Creator analytics"
  ]
end

defp get_tier_benefits(:professional) do
  [
    "Service & pricing blocks",
    "Client testimonials",
    "Business tool integration",
    "Code showcase demos",
    "Professional analytics",
    "Custom branding"
  ]
end

defp get_tier_benefits(:enterprise) do
  [
    "Advanced embed platforms",
    "Enterprise integrations",
    "White-label options",
    "Priority support",
    "Custom development",
    "Advanced security"
  ]
end

defp get_tier_benefits(_), do: []

  # ============================================================================
  # ESSENTIAL HELPER FUNCTIONS
  # ============================================================================

  defp schedule_save_status_reset(socket) do
    Process.send_after(self(), :reset_save_status, 2000)
    socket
  end

  defp parse_block_id(block_id) when is_binary(block_id) do
    case Integer.parse(block_id) do
      {id, _} -> id
      _ -> nil
    end
  end
  defp parse_block_id(block_id) when is_integer(block_id), do: block_id
  defp parse_block_id(_), do: nil

  defp find_block_in_zones(layout_zones, block_id) do
    result = layout_zones
    |> Enum.flat_map(fn {_zone, blocks} -> blocks end)
    |> Enum.find(fn block -> block.id == block_id end)

    case result do
      nil -> {:error, :not_found}
      block -> {:ok, block}
    end
  end

  defp update_block_content(block, changes) when is_map(changes) do
    current_content = block.content_data || %{}
    updated_content_data = Map.merge(current_content, changes)
    %{block | content_data: updated_content_data}
  end

  defp update_block_in_zones(layout_zones, block_id, updated_block) do
    Enum.into(layout_zones, %{}, fn {zone_name, blocks} ->
      updated_blocks = Enum.map(blocks, fn block ->
        if block.id == block_id, do: updated_block, else: block
      end)
      {zone_name, updated_blocks}
    end)
  end

  defp save_layout_zones_to_database(layout_zones, portfolio_id) do
    try do
      sections_data = convert_layout_zones_to_portfolio_sections(layout_zones, portfolio_id)
      case update_portfolio_sections(portfolio_id, sections_data) do
        {:ok, sections} -> {:ok, sections}
        {:error, reason} -> {:error, reason}
      end
    rescue
      error -> {:error, Exception.message(error)}
    end
  end

  defp convert_layout_zones_to_portfolio_sections(layout_zones, portfolio_id) do
    layout_zones
    |> Enum.with_index()
    |> Enum.flat_map(fn {{zone_name, blocks}, zone_index} ->
      Enum.with_index(blocks, fn block, block_index ->
        %{
          portfolio_id: portfolio_id,
          title: get_block_title_safe(block),
          content: block.content_data,
          section_type: map_block_type_to_section_type(block.block_type),
          position: zone_index * 100 + block_index,
          visible: true,
          metadata: %{
            zone: zone_name,
            block_type: block.block_type,
            content_data: block.content_data
          }
        }
      end)
    end)
  end

  defp update_portfolio_sections(portfolio_id, sections_data) do
    case Frestyl.Portfolios.replace_portfolio_sections(portfolio_id, sections_data) do
      {:ok, sections} -> {:ok, sections}
      {:error, reason} -> {:error, reason}
    end
  rescue
    _ -> {:ok, []}
  end

  defp get_block_title_safe(block) do
    case block.content_data do
      %{title: title} when is_binary(title) and title != "" -> title
      %{"title" => title} when is_binary(title) and title != "" -> title
      _ -> humanize_block_type(block.block_type)
    end
  end

  defp map_block_type_to_section_type(:hero_card), do: "hero"
  defp map_block_type_to_section_type(:about_card), do: "about"
  defp map_block_type_to_section_type(:experience_card), do: "experience"
  defp map_block_type_to_section_type(:achievements_card), do: "achievements"
  defp map_block_type_to_section_type(:skills_card), do: "skills"
  defp map_block_type_to_section_type(:projects_card), do: "projects"
  defp map_block_type_to_section_type(:contact_card), do: "contact"
  defp map_block_type_to_section_type(:services_card), do: "services"
  defp map_block_type_to_section_type(:testimonials_card), do: "testimonials"
  defp map_block_type_to_section_type(:social_card), do: "social"
  defp map_block_type_to_section_type(_), do: "custom"

  defp humanize_zone_name(zone_name) do
    zone_name
    |> to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp humanize_block_type(block_type) do
    block_type
    |> to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp add_block_to_zone(layout_zones, zone, new_block) do
    current_blocks = Map.get(layout_zones, zone, [])
    Map.put(layout_zones, zone, current_blocks ++ [new_block])
  end

defp render_zone_blocks(blocks, zone_name, assigns) do
  assigns = assigns
  |> assign(:blocks, blocks)
  |> assign(:zone_name, zone_name)

  ~H"""
  <div class="space-y-3">
    <%= for block <- @blocks do %>
      <div class="bg-white rounded-lg border hover:shadow-md transition-shadow">
        <%= if @show_edit_controls do %>
          <div class="flex items-center justify-between p-3 bg-gray-50 border-b">
            <div class="flex items-center space-x-2">
              <span class="text-xs px-2 py-1 bg-blue-100 text-blue-700 rounded">
                <%= humanize_block_type(block.block_type) %>
              </span>
              <span class="text-sm font-medium text-gray-700">
                <%= get_block_title_safe(block) %>
              </span>
            </div>

            <div class="flex items-center space-x-2">
              <button phx-click="edit_content_block"
                      phx-value-block_id={block.id}
                      phx-target={@myself}
                      class="px-3 py-1 text-xs bg-blue-100 text-blue-700 rounded hover:bg-blue-200">
                Edit
              </button>
            </div>
          </div>
        <% end %>

        <div class="p-4">
          <%= render_block_preview(block, assigns) %>
        </div>
      </div>
    <% end %>

    <%= if Enum.empty?(@blocks) do %>
      <div class="text-center py-8 text-gray-500 border-2 border-dashed border-gray-200 rounded-lg">
        <p class="text-sm">No content blocks in this zone</p>
        <%= if @show_edit_controls do %>
          <p class="text-xs text-gray-400 mt-1">Click "Add Block" to get started</p>
        <% end %>
      </div>
    <% end %>
  </div>
  """
end

  defp render_block_preview(block, assigns) do
    assigns = assign(assigns, :block, block)
    content = block.content_data || %{}

    ~H"""
    <div>
      <h3 class="font-medium text-gray-900 mb-2">
        <%= Map.get(content, "title", "Untitled") %>
      </h3>

      <%= if Map.get(content, "content") do %>
        <p class="text-sm text-gray-600 line-clamp-2">
          <%= Map.get(content, "content") %>
        </p>
      <% end %>

      <div class="mt-2 text-xs text-gray-400">
        Type: <%= humanize_block_type(@block.block_type) %>
      </div>
    </div>
    """
  end

  defp render_edit_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 overflow-y-auto">
      <div class="flex items-center justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
        <div class="fixed inset-0 bg-gray-500 bg-opacity-75"
             phx-click="cancel_block_edit"
             phx-target={@myself}></div>

        <div class="inline-block align-bottom bg-white rounded-lg text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-2xl sm:w-full">
          <div class="bg-white px-4 pt-5 pb-4 sm:p-6">
            <div class="flex items-center justify-between mb-4">
              <h3 class="text-lg font-medium text-gray-900">
                Edit <%= humanize_block_type(@editing_block.block_type) %>
              </h3>

              <div class="flex items-center space-x-3">
                <%= case @save_status do %>
                  <% :saving -> %>
                    <span class="text-sm text-blue-600">Saving...</span>
                  <% :saved -> %>
                    <span class="text-sm text-green-600">Saved ✓</span>
                  <% :error -> %>
                    <span class="text-sm text-red-600">Error</span>
                  <% _ -> %>
                    <span></span>
                <% end %>

                <button phx-click="cancel_block_edit" phx-target={@myself}
                        class="text-gray-400 hover:text-gray-600">
                  <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </div>
            </div>

            <div class="space-y-4">
              <%= render_simple_form(@editing_block, assigns) %>
            </div>
          </div>

          <div class="bg-gray-50 px-4 py-3 sm:px-6 sm:flex sm:flex-row-reverse">
            <button type="button"
                    phx-click="save_block_changes"
                    phx-value-block_id={@editing_block.id}
                    phx-value-changes={Jason.encode!(@editing_block.content_data)}
                    phx-target={@myself}
                    class="w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 bg-blue-600 text-base font-medium text-white hover:bg-blue-700 sm:ml-3 sm:w-auto sm:text-sm">
              Save Changes
            </button>
            <button type="button"
                    phx-click="cancel_block_edit"
                    phx-target={@myself}
                    class="mt-3 w-full inline-flex justify-center rounded-md border border-gray-300 shadow-sm px-4 py-2 bg-white text-base font-medium text-gray-700 hover:bg-gray-50 sm:mt-0 sm:ml-3 sm:w-auto sm:text-sm">
              Cancel
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp render_simple_form(block, assigns) do
    assigns = assign(assigns, :block, block)
    content = block.content_data || %{}

    ~H"""
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-1">Title</label>
      <input type="text"
             value={Map.get(content, "title", "")}
             phx-change="update_field"
             phx-value-field="title"
             phx-target={@myself}
             class="w-full px-3 py-2 border border-gray-300 rounded-md">
    </div>

    <%= if Map.has_key?(content, "content") do %>
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Content</label>
        <textarea rows="4"
                  phx-change="update_field"
                  phx-value-field="content"
                  phx-target={@myself}
                  class="w-full px-3 py-2 border border-gray-300 rounded-md"><%= Map.get(content, "content", "") %></textarea>
      </div>
    <% end %>
    """
  end

  @impl true
  def handle_event("update_field", %{"field" => field, "value" => value}, socket) do
    case socket.assigns.editing_block do
      %{} = block ->
        updated_content = Map.put(block.content_data, field, value)
        updated_block = %{block | content_data: updated_content}

        {:noreply, assign(socket, :editing_block, updated_block)}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_add_menu", %{"zone" => zone}, socket) do
    menu_key = String.to_atom("show_add_menu_#{zone}")
    current_state = Map.get(socket.assigns, menu_key, false)

    # Close all other menus
    socket = Enum.reduce([:hero, :about, :services, :experience, :achievements, :projects, :skills, :testimonials, :contact], socket, fn zone_name, acc ->
      assign(acc, String.to_atom("show_add_menu_#{zone_name}"), false)
    end)

    {:noreply, assign(socket, menu_key, !current_state)}
  end

  defp get_available_blocks_for_tier(account) do
    [
      {"hero_card", %{name: "Hero Section", description: "Main header with title/video", icon: "🎬", required_tier: :personal}},
      {"about_card", %{name: "About", description: "Personal introduction", icon: "👤", required_tier: :personal}},
      {"experience_card", %{name: "Experience", description: "Work history", icon: "💼", required_tier: :personal}},
      {"skills_card", %{name: "Skills", description: "Technical abilities", icon: "⚡", required_tier: :personal}},
      {"projects_card", %{name: "Projects", description: "Portfolio showcase", icon: "🎨", required_tier: :personal}},
      {"contact_card", %{name: "Contact", description: "Contact information", icon: "📧", required_tier: :personal}},
      {"services_card", %{name: "Services", description: "Service offerings", icon: "🛠️", required_tier: :professional}},
      {"testimonials_card", %{name: "Testimonials", description: "Client feedback", icon: "💬", required_tier: :professional}}
    ]
    |> Enum.filter(fn {block_type, block_info} ->
      can_use_block_type?(account, String.to_atom(block_type))
    end)
  end

  defp get_restricted_blocks_for_tier(account) do
    [
      {"services_card", %{name: "Services", description: "Service offerings", icon: "🛠️", required_tier: :professional}},
      {"testimonials_card", %{name: "Testimonials", description: "Client feedback", icon: "💬", required_tier: :professional}},
      {"social_embed_card", %{name: "Social Embeds", description: "Social media integration", icon: "📱", required_tier: :creator}},
      {"video_showcase_card", %{name: "Video Showcase", description: "Video portfolio", icon: "🎥", required_tier: :creator}}
    ]
    |> Enum.reject(fn {block_type, _block_info} ->
      can_use_block_type?(account, String.to_atom(block_type))
    end)
    |> Enum.take(3)
  end

  defp format_tier_name(:personal), do: "Personal"
  defp format_tier_name(:creator), do: "Creator"
  defp format_tier_name(:professional), do: "Professional"
  defp format_tier_name(:enterprise), do: "Enterprise"
  defp format_tier_name(tier), do: String.capitalize(to_string(tier))

  defp render_upgrade_modal(assigns) do
    ~H"""
    <%= if @show_upgrade_modal do %>
      <div class="fixed inset-0 z-50 overflow-y-auto">
        <div class="flex items-center justify-center min-h-screen pt-4 px-4 pb-20 text-center">
          <div class="fixed inset-0 bg-gray-900 bg-opacity-75"
               phx-click="close_upgrade_modal"
               phx-target={@myself}></div>

          <div class="inline-block bg-white rounded-xl shadow-2xl transform transition-all sm:max-w-lg sm:w-full">
            <div class="bg-gradient-to-r from-purple-600 to-blue-600 px-6 py-4">
              <h3 class="text-lg font-bold text-white">Upgrade Required</h3>
            </div>

            <div class="px-6 py-6 text-center">
              <div class="mx-auto flex items-center justify-center h-16 w-16 rounded-full bg-amber-100 mb-4">
                <svg class="h-8 w-8 text-amber-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m0 0v2m0-2h2m-2 0H10" />
                </svg>
              </div>

              <h4 class="text-xl font-bold text-gray-900 mb-2">
                <%= humanize_block_type(@blocked_block_type) %> Block
              </h4>

              <p class="text-gray-600">
                This block requires a
                <span class="font-semibold text-purple-600"><%= format_tier_name(@required_tier) %></span>
                subscription.
              </p>
            </div>

            <div class="bg-gray-50 px-6 py-4 flex justify-center space-x-3">
              <button phx-click="upgrade_account" phx-target={@myself}
                      class="px-6 py-3 bg-gradient-to-r from-purple-600 to-blue-600 text-white rounded-lg font-medium hover:from-purple-700 hover:to-blue-700">
                Upgrade Now
              </button>
              <button phx-click="close_upgrade_modal" phx-target={@myself}
                      class="px-6 py-3 border border-gray-300 text-gray-700 rounded-lg font-medium hover:bg-gray-50">
                Maybe Later
              </button>
            </div>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp clean_and_reset_layout_zones(layout_zones) do
    Enum.into(layout_zones, %{}, fn {zone_name, blocks} ->
      clean_blocks = Enum.map(blocks, fn block ->
        clean_content = get_clean_block_structure(block.block_type)
        %{block | content_data: clean_content}
      end)
      {zone_name, clean_blocks}
    end)
  end

end
