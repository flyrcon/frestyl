# lib/frestyl_web/live/portfolio_live/dynamic_card_layout_manager.ex
defmodule FrestylWeb.PortfolioLive.DynamicCardLayoutManager do
  @moduledoc """
  Enhanced Dynamic Card Layout Manager with modal-based editing capabilities.
  Provides comprehensive content block editing with auto-save functionality.
  """

  use FrestylWeb, :live_component
  alias Frestyl.Portfolios.ContentBlocks.DynamicCardBlocks
  alias Frestyl.Accounts.BrandSettings

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
      |> assign(:block_changes, %{})
      |> assign(:save_status, :idle)  # :idle, :saving, :saved, :error
      |> assign(:show_edit_modal, false)
      |> assign(:editing_block, nil)
    }
  end

  @impl true
  def update(assigns, socket) do
    view_mode = Map.get(assigns, :view_mode, :edit)
    show_edit_controls = Map.get(assigns, :show_edit_controls, view_mode == :edit)
    layout_config = get_current_layout_config(assigns.portfolio, assigns.brand_settings)
    layout_zones = assigns.layout_zones || %{}

    {:ok, socket
      |> assign(assigns)
      |> assign(:view_mode, view_mode)
      |> assign(:show_edit_controls, show_edit_controls)
      |> assign(:layout_config, layout_config)
      |> assign(:layout_zones, layout_zones)
    }
  end

  # ============================================================================
  # MODAL-BASED EDITING EVENT HANDLERS
  # ============================================================================

  @impl true
  def handle_event("edit_content_block", %{"block_id" => block_id}, socket) do
    block_id_int = parse_block_id(block_id)

    case find_block_in_zones(socket.assigns.layout_zones, block_id_int) do
      {:ok, block} ->
        {:noreply, socket
          |> assign(:editing_block_id, block_id_int)
          |> assign(:editing_block, block)
          |> assign(:show_edit_modal, true)
          |> assign(:block_changes, %{})
          |> assign(:save_status, :idle)
        }

      {:error, :not_found} ->
        {:noreply, socket |> put_flash(:error, "Block not found")}
    end
  end

  @impl true
  def handle_event("save_block_changes", %{"block_id" => block_id, "changes" => changes}, socket) do
    block_id_int = parse_block_id(block_id)

    # Set saving status
    socket = assign(socket, :save_status, :saving)

    case find_block_in_zones(socket.assigns.layout_zones, block_id_int) do
      {:ok, current_block} ->
        updated_block = update_block_content(current_block, changes)
        updated_zones = update_block_in_zones(socket.assigns.layout_zones, block_id_int, updated_block)

        # Convert to portfolio sections and save to database
        case save_layout_zones_to_database(updated_zones, socket.assigns.portfolio.id) do
          {:ok, _sections} ->
            # Notify parent component of update
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
      |> assign(:block_changes, %{})
      |> assign(:save_status, :idle)
    }
  end

  @impl true
  def handle_event("add_list_item", %{"block_id" => block_id, "field" => field}, socket) do
    block_id_int = parse_block_id(block_id)

    case socket.assigns.editing_block do
      %{id: ^block_id_int} = block ->
        updated_content = add_item_to_list_field(block.content_data, field)
        updated_block = %{block | content_data: updated_content}

        {:noreply, assign(socket, :editing_block, updated_block)}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("remove_list_item", %{"block_id" => block_id, "field" => field, "index" => idx}, socket) do
    block_id_int = parse_block_id(block_id)
    index = String.to_integer(idx)

    case socket.assigns.editing_block do
      %{id: ^block_id_int} = block ->
        updated_content = remove_item_from_list_field(block.content_data, field, index)
        updated_block = %{block | content_data: updated_content}

        {:noreply, assign(socket, :editing_block, updated_block)}

      _ ->
        {:noreply, socket}
    end
  end

  # Complete update_field event handlers for DynamicCardLayoutManager

  @impl true
  def handle_event("update_field", %{"field" => field, "value" => value}, socket) do
    case socket.assigns.editing_block do
      %{} = block ->
        # Cancel previous auto-save timer
        if socket.assigns[:auto_save_timer] do
          Process.cancel_timer(socket.assigns.auto_save_timer)
        end

        # Update block content
        updated_content = update_block_field_value(block.content_data, field, value)
        updated_block = %{block | content_data: updated_content}

        # Schedule auto-save after 1.5 seconds of inactivity
        auto_save_timer = schedule_auto_save(block.id, 1500)

        {:noreply, socket
          |> assign(:editing_block, updated_block)
          |> assign(:auto_save_timer, auto_save_timer)
          |> assign(:unsaved_changes, true)
        }

      _ ->
        {:noreply, socket}
    end
  end

  # Handle form submissions from the modal (catches Phoenix LiveView form format)
  @impl true
  def handle_event("update_field", params, socket) when is_map(params) do
    # Extract field and value from form parameters safely
    {field, value} = case params do
      %{"_target" => [field]} when is_binary(field) ->
        # Phoenix LiveView form format - get the value using the field name
        value = Map.get(params, field, "")
        {field, value}

      %{"field" => field, "value" => value} ->
        # Direct format
        {field, value}

      _ ->
        # Fallback - try to find any field that's not a system parameter
        params
        |> Enum.reject(fn {key, _} -> key in ["_target", "_csrf_token"] end)
        |> case do
          [{field, value}] -> {field, value}
          _ -> {"title", ""}  # ultimate fallback
        end
    end

    # Call the main handler with cleaned parameters
    handle_event("update_field", %{"field" => field, "value" => value}, socket)
  end

  defp create_dynamic_card_block(block_type, zone, socket) do
    # Create default content based on block type (no external dependency)
    default_content = case String.to_atom(block_type) do
      :hero_card -> %{
        "title" => "Welcome to My Portfolio",
        "subtitle" => "Professional services and expertise",
        "call_to_action" => %{"text" => "Get Started", "url" => "#contact"},
        "background_type" => "color",
        "video_aspect_ratio" => "16:9"
      }
      :about_card -> %{
        "title" => "About Me",
        "content" => "Tell your story here...",
        "highlights" => []
      }
      :experience_card -> %{
        "title" => "Experience",
        "jobs" => []
      }
      :achievement_card -> %{
        "title" => "Achievements",
        "achievements" => []
      }
      :service_card -> %{
        "title" => "Service",
        "description" => "Service description",
        "price" => nil
      }
      :project_card -> %{
        "title" => "Project",
        "description" => "Project description",
        "technologies" => [],
        "url" => ""
      }
      :contact_card -> %{
        "title" => "Contact",
        "email" => "",
        "phone" => "",
        "address" => ""
      }
      :text_card -> %{
        "title" => "New Section",
        "content" => "Add your content here..."
      }
      _ -> %{
        "title" => "New Block",
        "content" => "Content goes here..."
      }
    end

    {:ok, %{
      id: System.unique_integer([:positive]),
      block_type: String.to_atom(block_type),
      content_data: default_content,
      zone: zone,
      position: 0
    }}
  rescue
    error ->
      {:error, "Failed to create block: #{Exception.message(error)}"}
  end

  # Helper functions that support the update_field handlers

  defp schedule_auto_save(block_id, delay_ms) do
    Process.send_after(self(), {:auto_save_block, block_id}, delay_ms)
  end

  defp update_block_field_value(content_data, field, value) do
    # Handle nested field updates (e.g., "call_to_action_text" -> ["call_to_action", "text"])
    cond do
      String.contains?(field, "_") && field != "call_to_action" ->
        # Handle array item updates (e.g., "job_0_title")
        case parse_array_field(field) do
          {array_field, index, sub_field} ->
            update_array_item_field(content_data, array_field, index, sub_field, value)

          _ ->
            # Regular field update
            Map.put(content_data, field, value)
        end

      field == "call_to_action_text" ->
        current_cta = Map.get(content_data, "call_to_action", %{})
        updated_cta = Map.put(current_cta, "text", value)
        Map.put(content_data, "call_to_action", updated_cta)

      field == "call_to_action_url" ->
        current_cta = Map.get(content_data, "call_to_action", %{})
        updated_cta = Map.put(current_cta, "url", value)
        Map.put(content_data, "call_to_action", updated_cta)

      true ->
        # Regular field update
        Map.put(content_data, field, value)
    end
  end

  defp parse_array_field(field) do
    # Parse fields like "job_0_title" into {"jobs", 0, "title"}
    case String.split(field, "_", parts: 3) do
      [array_name, index_str, sub_field] ->
        case Integer.parse(index_str) do
          {index, _} ->
            array_field = case array_name do
              "job" -> "jobs"
              "achievement" -> "achievements"
              "skill" -> "skills"
              "project" -> "projects"
              "highlight" -> "highlights"
              _ -> array_name
            end
            {array_field, index, sub_field}

          _ -> nil
        end

      _ -> nil
    end
  end

  defp update_array_item_field(content_data, array_field, index, sub_field, value) do
    current_array = Map.get(content_data, array_field, [])

    if index < length(current_array) do
      updated_array = List.update_at(current_array, index, fn item ->
        Map.put(item, sub_field, value)
      end)
      Map.put(content_data, array_field, updated_array)
    else
      content_data
    end
  end

  @impl true
  def handle_info({:auto_save_block, block_id}, socket) do
    if socket.assigns.editing_block_id == block_id do
      # Trigger save if block is still being edited
      changes = socket.assigns.editing_block.content_data

      send_update(__MODULE__,
        id: socket.assigns.id,
        action: :save_block_changes,
        block_id: block_id,
        changes: changes
      )
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info(:reset_save_status, socket) do
    {:noreply, assign(socket, :save_status, :idle)}
  end

  # ============================================================================
  # EXISTING EVENT HANDLERS (preserved from original)
  # ============================================================================

  @impl true
  def handle_event("start_editing_block", %{"block_id" => block_id}, socket) do
    # Legacy handler - redirect to new modal system
    handle_event("edit_content_block", %{"block_id" => block_id}, socket)
  end

  @impl true
  def handle_event("add_content_block", %{"zone" => zone} = params, socket) do
    IO.puts("🔥 Adding default text block to #{zone} (no block_type specified)")

    # Default to text_card if no block_type specified
    block_type = Map.get(params, "block_type", "text_card")

    case create_dynamic_card_block(block_type, String.to_atom(zone), socket) do
      {:ok, new_block} ->
        updated_zones = add_block_to_zone(socket.assigns.layout_zones, String.to_atom(zone), new_block)

        {:noreply, socket
          |> assign(:layout_zones, updated_zones)
          |> assign(:layout_dirty, true)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to add block: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("toggle_add_menu", %{"zone" => zone}, socket) do
    menu_key = String.to_atom("show_add_menu_#{zone}")
    current_state = Map.get(socket.assigns, menu_key, false)

    # Close all other menus first
    # Toggle the clicked menu
    {:noreply, assign(socket, menu_key, !current_state)}
  end

  @impl true
  def handle_event("update_field", %{"field" => field, "value" => value}, socket) do
    case socket.assigns.editing_block do
      %{} = block ->
        updated_content = Map.put(block.content_data, field, value)
        updated_block = %{block | content_data: updated_content}

        # Auto-save after 1 second of inactivity
        Process.send_after(self(), {:auto_save_block, block.id}, 1000)

        {:noreply, assign(socket, :editing_block, updated_block)}

      _ ->
        {:noreply, socket}
    end
  end

  # ============================================================================
  # RENDER FUNCTIONS
  # ============================================================================

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} class="dynamic-card-layout-manager">
      <!-- Main Layout Manager Content -->
      <div class="space-y-6">
        <!-- Layout Controls -->
        <%= if @show_edit_controls do %>
          <div class="bg-white rounded-lg shadow-sm border p-4">
            <div class="flex items-center justify-between mb-4">
              <h3 class="text-lg font-semibold text-gray-900">Dynamic Card Layout</h3>
              <div class="flex space-x-3">
                <select class="text-sm border-gray-300 rounded-md"
                        phx-change="change_preview_device"
                        phx-target={@myself}>
                  <option value="desktop" selected={@preview_device == :desktop}>Desktop</option>
                  <option value="tablet" selected={@preview_device == :tablet}>Tablet</option>
                  <option value="mobile" selected={@preview_device == :mobile}>Mobile</option>
                </select>

                <button phx-click="toggle_layout_preview"
                        phx-target={@myself}
                        class="px-3 py-1 text-sm bg-blue-100 text-blue-700 rounded-md hover:bg-blue-200">
                  Preview Mode
                </button>
              </div>
            </div>
          </div>
        <% end %>

        <!-- Layout Zones -->
        <div class="grid gap-6">
          <%= for {zone_name, blocks} <- @layout_zones do %>
            <div class="bg-gray-50 rounded-lg p-4 min-h-32">
              <div class="flex items-center justify-between mb-3">
                <h4 class="font-medium text-gray-700 capitalize">
                  <%= humanize_zone_name(zone_name) %>
                </h4>
                <%= if @show_edit_controls do %>
                  <div class="relative">
                    <button phx-click="toggle_add_menu"
                            phx-value-zone={zone_name}
                            phx-target={@myself}
                            class="text-sm text-blue-600 hover:text-blue-800 flex items-center">
                      + Add Block
                      <svg class="ml-1 h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                      </svg>
                    </button>

                    <!-- Dropdown menu for block types -->
                    <%= if assigns[:"show_add_menu_#{zone_name}"] do %>
                      <div class="absolute right-0 mt-2 w-48 bg-white border border-gray-200 rounded-md shadow-lg z-10">
                        <div class="py-1">
                          <button phx-click="add_content_block"
                                  phx-value-block_type="hero_card"
                                  phx-value-zone={zone_name}
                                  phx-target={@myself}
                                  class="block w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100">
                            Hero Section
                          </button>
                          <button phx-click="add_content_block"
                                  phx-value-block_type="about_card"
                                  phx-value-zone={zone_name}
                                  phx-target={@myself}
                                  class="block w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100">
                            About Section
                          </button>
                          <button phx-click="add_content_block"
                                  phx-value-block_type="experience_card"
                                  phx-value-zone={zone_name}
                                  phx-target={@myself}
                                  class="block w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100">
                            Experience Section
                          </button>
                          <button phx-click="add_content_block"
                                  phx-value-block_type="achievement_card"
                                  phx-value-zone={zone_name}
                                  phx-target={@myself}
                                  class="block w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100">
                            Achievement Section
                          </button>
                          <button phx-click="add_content_block"
                                  phx-value-block_type="contact_card"
                                  phx-value-zone={zone_name}
                                  phx-target={@myself}
                                  class="block w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100">
                            Contact Section
                          </button>
                        </div>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>

              <!-- Content Blocks in Zone -->
              <div class="space-y-3">
                <%= for block <- blocks do %>
                  <div class="bg-white rounded-lg border hover:shadow-md transition-shadow">
                    <!-- Edit Controls (top bar) -->
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
                                  class="px-3 py-1 text-xs bg-blue-100 text-blue-700 rounded hover:bg-blue-200 transition-colors">
                            Edit
                          </button>

                          <button phx-click="remove_content_block"
                                  phx-value-block_id={block.id}
                                  phx-target={@myself}
                                  class="px-3 py-1 text-xs bg-red-100 text-red-700 rounded hover:bg-red-200 transition-colors">
                            Remove
                          </button>
                        </div>
                      </div>
                    <% end %>

                    <!-- Block Content Preview -->
                    <div class="p-4">
                      <%= render_block_content_preview(block, assigns) %>
                    </div>
                  </div>
                <% end %>

                <%= if Enum.empty?(blocks) do %>
                  <div class="text-center py-8 text-gray-500 border-2 border-dashed border-gray-200 rounded-lg">
                    <div class="flex flex-col items-center">
                      <svg class="w-8 h-8 mb-2 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
                      </svg>
                      <p class="text-sm">No content blocks in this zone</p>
                      <%= if @show_edit_controls do %>
                        <p class="text-xs text-gray-400 mt-1">Click "Add Block" to get started</p>
                      <% end %>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Edit Modal -->
      <%= if @show_edit_modal and @editing_block do %>
        <%= render_edit_modal(assigns) %>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # MODAL RENDERING FUNCTIONS
  # ============================================================================

  defp render_edit_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 overflow-y-auto" aria-labelledby="modal-title" role="dialog" aria-modal="true">
      <!-- Background overlay -->
      <div class="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
        <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity"
             phx-click="cancel_block_edit"
             phx-target={@myself}></div>

        <!-- Modal panel -->
        <div class="inline-block align-bottom bg-white rounded-lg text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-2xl sm:w-full">
          <!-- Modal Header -->
          <div class="bg-white px-4 pt-5 pb-4 sm:p-6 sm:pb-4">
            <div class="flex items-center justify-between mb-4">
              <h3 class="text-lg font-medium text-gray-900" id="modal-title">
                Edit <%= humanize_block_type(@editing_block.block_type) %>
              </h3>

              <!-- Save Status Indicator -->
              <div class="flex items-center space-x-3">
                <%= case @save_status do %>
                  <% :saving -> %>
                    <div class="flex items-center text-blue-600">
                      <svg class="animate-spin -ml-1 mr-2 h-4 w-4" fill="none" viewBox="0 0 24 24">
                        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                      </svg>
                      <span class="text-sm">Saving...</span>
                    </div>
                  <% :saved -> %>
                    <div class="flex items-center text-green-600">
                      <svg class="h-4 w-4 mr-2" fill="currentColor" viewBox="0 0 20 20">
                        <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" />
                      </svg>
                      <span class="text-sm">Saved ✓</span>
                    </div>
                  <% :error -> %>
                    <div class="flex items-center text-red-600">
                      <svg class="h-4 w-4 mr-2" fill="currentColor" viewBox="0 0 20 20">
                        <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
                      </svg>
                      <span class="text-sm">Error</span>
                    </div>
                  <% _ -> %>
                    <div></div>
                <% end %>

                <button phx-click="cancel_block_edit"
                        phx-target={@myself}
                        class="text-gray-400 hover:text-gray-600">
                  <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </div>
            </div>

            <!-- Modal Content -->
            <div class="space-y-4">
              <%= render_block_type_form(@editing_block, assigns) %>
            </div>
          </div>

          <!-- Modal Footer -->
          <div class="bg-gray-50 px-4 py-3 sm:px-6 sm:flex sm:flex-row-reverse">
            <button type="button"
                    phx-click="save_block_changes"
                    phx-value-block_id={@editing_block.id}
                    phx-value-changes={Jason.encode!(@editing_block.content_data)}
                    phx-target={@myself}
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
        </div>
      </div>
    </div>
    """
  end

  defp render_block_content_preview(%{block_type: :hero_card} = block, assigns) do
    assigns = assign(assigns, :block, block)
    content = block.content_data || %{}

    ~H"""
    <div class="hero-preview bg-gradient-to-r from-blue-500 to-purple-600 text-white p-6 rounded-lg">
      <h1 class="text-2xl font-bold mb-2">
        <%= Map.get(content, "title", "Hero Title") %>
      </h1>
      <%= if Map.get(content, "subtitle") do %>
        <p class="text-lg opacity-90 mb-4">
          <%= Map.get(content, "subtitle") %>
        </p>
      <% end %>
      <%= if get_nested_value(content, ["call_to_action", "text"]) do %>
        <button class="px-4 py-2 bg-white text-blue-600 rounded font-medium">
          <%= get_nested_value(content, ["call_to_action", "text"]) %>
        </button>
      <% end %>
      <div class="mt-3 text-xs opacity-75">
        Background: <%= Map.get(content, "background_type", "color") %>
        <%= if Map.get(content, "background_type") == "video" do %>
          | Aspect: <%= Map.get(content, "video_aspect_ratio", "16:9") %>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_block_content_preview(%{block_type: :about_card} = block, assigns) do
    assigns = assign(assigns, :block, block)
    content = block.content_data || %{}
    highlights = Map.get(content, "highlights", [])

    ~H"""
    <div class="about-preview">
      <h2 class="text-xl font-semibold text-gray-900 mb-3">
        <%= Map.get(content, "title", "About") %>
      </h2>

      <p class="text-gray-600 mb-4 line-clamp-3">
        <%= Map.get(content, "content", "About content goes here...") %>
      </p>

      <%= if length(highlights) > 0 do %>
        <div class="border-t pt-3">
          <h4 class="text-sm font-medium text-gray-700 mb-2">Key Highlights:</h4>
          <ul class="text-sm text-gray-600 space-y-1">
            <%= for highlight <- Enum.take(highlights, 3) do %>
              <li class="flex items-center">
                <span class="w-1.5 h-1.5 bg-blue-500 rounded-full mr-2"></span>
                <%= highlight %>
              </li>
            <% end %>
            <%= if length(highlights) > 3 do %>
              <li class="text-xs text-gray-400">... and <%= length(highlights) - 3 %> more</li>
            <% end %>
          </ul>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_block_content_preview(%{block_type: :experience_card} = block, assigns) do
    assigns = assign(assigns, :block, block)
    content = block.content_data || %{}
    jobs = Map.get(content, "jobs", [])

    ~H"""
    <div class="experience-preview">
      <h2 class="text-xl font-semibold text-gray-900 mb-3">
        <%= Map.get(content, "title", "Experience") %>
      </h2>

      <%= if length(jobs) > 0 do %>
        <div class="space-y-3">
          <%= for job <- Enum.take(jobs, 2) do %>
            <div class="border-l-2 border-blue-500 pl-3">
              <h4 class="font-medium text-gray-900">
                <%= Map.get(job, "title", "Job Title") %>
              </h4>
              <p class="text-sm text-gray-600">
                <%= Map.get(job, "company", "Company") %>
                <%= if Map.get(job, "duration") do %>
                  • <%= Map.get(job, "duration") %>
                <% end %>
              </p>
              <%= if Map.get(job, "description") do %>
                <p class="text-xs text-gray-500 mt-1 line-clamp-2">
                  <%= String.slice(Map.get(job, "description"), 0, 100) %>...
                </p>
              <% end %>
            </div>
          <% end %>
          <%= if length(jobs) > 2 do %>
            <p class="text-xs text-gray-400">... and <%= length(jobs) - 2 %> more positions</p>
          <% end %>
        </div>
      <% else %>
        <p class="text-gray-500 text-sm">No work experience added yet</p>
      <% end %>
    </div>
    """
  end

  defp render_block_content_preview(%{block_type: :achievement_card} = block, assigns) do
    assigns = assign(assigns, :block, block)
    content = block.content_data || %{}
    achievements = Map.get(content, "achievements", [])

    ~H"""
    <div class="achievement-preview">
      <h2 class="text-xl font-semibold text-gray-900 mb-3">
        <%= Map.get(content, "title", "Achievements") %>
      </h2>

      <%= if length(achievements) > 0 do %>
        <div class="space-y-2">
          <%= for achievement <- Enum.take(achievements, 3) do %>
            <div class="bg-yellow-50 border border-yellow-200 rounded p-2">
              <h4 class="font-medium text-yellow-800 text-sm">
                <%= Map.get(achievement, "title", "Achievement") %>
              </h4>
              <%= if Map.get(achievement, "date") do %>
                <p class="text-xs text-yellow-600">
                  <%= Map.get(achievement, "date") %>
                </p>
              <% end %>
              <%= if Map.get(achievement, "description") do %>
                <p class="text-xs text-yellow-700 mt-1 line-clamp-1">
                  <%= Map.get(achievement, "description") %>
                </p>
              <% end %>
            </div>
          <% end %>
          <%= if length(achievements) > 3 do %>
            <p class="text-xs text-gray-400">... and <%= length(achievements) - 3 %> more achievements</p>
          <% end %>
        </div>
      <% else %>
        <p class="text-gray-500 text-sm">No achievements added yet</p>
      <% end %>
    </div>
    """
  end

  defp render_block_content_preview(%{block_type: :contact_card} = block, assigns) do
    assigns = assign(assigns, :block, block)
    content = block.content_data || %{}

    ~H"""
    <div class="contact-preview bg-gray-50 p-4 rounded">
      <h2 class="text-xl font-semibold text-gray-900 mb-3">
        <%= Map.get(content, "title", "Contact") %>
      </h2>

      <div class="space-y-2 text-sm">
        <%= if Map.get(content, "email") && Map.get(content, "email") != "" do %>
          <div class="flex items-center">
            <span class="w-4 h-4 text-gray-400 mr-2">📧</span>
            <%= Map.get(content, "email") %>
          </div>
        <% end %>

        <%= if Map.get(content, "phone") && Map.get(content, "phone") != "" do %>
          <div class="flex items-center">
            <span class="w-4 h-4 text-gray-400 mr-2">📞</span>
            <%= Map.get(content, "phone") %>
          </div>
        <% end %>

        <%= if Map.get(content, "address") && Map.get(content, "address") != "" do %>
          <div class="flex items-center">
            <span class="w-4 h-4 text-gray-400 mr-2">📍</span>
            <%= Map.get(content, "address") %>
          </div>
        <% end %>

        <%= if Map.get(content, "email") == "" and Map.get(content, "phone") == "" and Map.get(content, "address") == "" do %>
          <p class="text-gray-500">No contact information added yet</p>
        <% end %>
      </div>
    </div>
    """
  end

  # Fallback for any other block types
  defp render_block_content_preview(block, assigns) do
    assigns = assign(assigns, :block, block)
    content = block.content_data || %{}

    ~H"""
    <div class="generic-preview">
      <h2 class="text-lg font-semibold text-gray-900 mb-2">
        <%= Map.get(content, "title", "Content Block") %>
      </h2>

      <p class="text-gray-600 text-sm line-clamp-3">
        <%= Map.get(content, "content", "Content goes here...") %>
      </p>

      <div class="mt-2 text-xs text-gray-400">
        Block Type: <%= humanize_block_type(@block.block_type) %>
      </div>
    </div>
    """
  end

  # Helper function for nested value access
  defp get_nested_value(map, keys, default \\ "") do
    Enum.reduce(keys, map, fn key, acc ->
      case acc do
        %{} -> Map.get(acc, key)
        _ -> default
      end
    end) || default
  end

  # ============================================================================
  # BLOCK TYPE SPECIFIC FORM RENDERING
  # ============================================================================

  defp render_block_type_form(%{block_type: :hero_card} = block, assigns) do
    assigns = assign(assigns, :block, block)
    content = block.content_data || %{}

    ~H"""
    <form phx-change="update_field" phx-target={@myself}>
      <!-- Title Field -->
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Title</label>
        <input type="text"
               name="title"
               value={Map.get(content, "title", "")}
               phx-debounce="300"
               class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
      </div>

      <!-- Subtitle Field -->
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Subtitle</label>
        <input type="text"
               name="subtitle"
               value={Map.get(content, "subtitle", "")}
               phx-debounce="300"
               class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
      </div>

      <!-- Call to Action -->
      <div class="space-y-3">
        <label class="block text-sm font-medium text-gray-700">Call to Action</label>

        <div>
          <label class="block text-xs text-gray-600 mb-1">Button Text</label>
          <input type="text"
                 name="call_to_action_text"
                 value={get_nested_value(content, ["call_to_action", "text"], "")}
                 phx-debounce="300"
                 class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
        </div>

        <div>
          <label class="block text-xs text-gray-600 mb-1">Button URL</label>
          <input type="url"
                 name="call_to_action_url"
                 value={get_nested_value(content, ["call_to_action", "url"], "")}
                 phx-debounce="300"
                 class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
        </div>
      </div>

      <!-- Background Type -->
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Background Type</label>
        <select name="background_type"
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
          <option value="color" selected={Map.get(content, "background_type") == "color"}>Solid Color</option>
          <option value="gradient" selected={Map.get(content, "background_type") == "gradient"}>Gradient</option>
          <option value="image" selected={Map.get(content, "background_type") == "image"}>Image</option>
          <option value="video" selected={Map.get(content, "background_type") == "video"}>Video</option>
        </select>
      </div>

      <!-- Video Aspect Ratio (show only if background type is video) -->
      <%= if Map.get(content, "background_type") == "video" do %>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Video Aspect Ratio</label>
          <select name="video_aspect_ratio"
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
            <option value="16:9" selected={Map.get(content, "video_aspect_ratio") == "16:9"}>16:9 Standard</option>
            <option value="1:1" selected={Map.get(content, "video_aspect_ratio") == "1:1"}>1:1 Square</option>
            <option value="4:3" selected={Map.get(content, "video_aspect_ratio") == "4:3"}>4:3 Classic</option>
            <option value="21:9" selected={Map.get(content, "video_aspect_ratio") == "21:9"}>21:9 Cinematic</option>
          </select>
        </div>
      <% end %>
    </form>
    """
  end

  defp render_block_type_form(%{block_type: :about_card} = block, assigns) do
    assigns = assign(assigns, :block, block)
    content = block.content_data || %{}
    highlights = Map.get(content, "highlights", [])

    ~H"""
    <form phx-change="update_field" phx-target={@myself}>
      <!-- Title Field -->
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Title</label>
        <input type="text"
               name="title"
               value={Map.get(content, "title", "")}
               phx-debounce="300"
               class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
      </div>

      <!-- Content Field -->
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Content</label>
        <textarea name="content"
                  rows="4"
                  phx-debounce="300"
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"><%= Map.get(content, "content", "") %></textarea>
      </div>

      <!-- Highlights List -->
      <div>
        <div class="flex items-center justify-between mb-2">
          <label class="block text-sm font-medium text-gray-700">Highlights</label>
          <button type="button"
                  phx-click="add_list_item"
                  phx-value-block_id={@block.id}
                  phx-value-field="highlights"
                  phx-target={@myself}
                  class="text-sm text-blue-600 hover:text-blue-800">
            + Add Highlight
          </button>
        </div>

        <div class="space-y-2">
          <%= for {highlight, index} <- Enum.with_index(highlights) do %>
            <div class="flex items-center space-x-2">
              <input type="text"
                     value={highlight}
                     name={"highlight_#{index}"}
                     phx-debounce="300"
                     class="flex-1 px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
              <button type="button"
                      phx-click="remove_list_item"
                      phx-value-block_id={@block.id}
                      phx-value-field="highlights"
                      phx-value-index={index}
                      phx-target={@myself}
                      class="text-red-600 hover:text-red-800">
                <svg class="h-4 w-4" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
                </svg>
              </button>
            </div>
          <% end %>
        </div>
      </div>
    </form>
    """
  end

  defp render_block_type_form(%{block_type: :experience_card} = block, assigns) do
    assigns = assign(assigns, :block, block)
    content = block.content_data || %{}
    jobs = Map.get(content, "jobs", [])

    ~H"""
    <form phx-change="update_field" phx-target={@myself}>
      <!-- Title Field -->
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Title</label>
        <input type="text"
               name="title"
               value={Map.get(content, "title", "")}
               phx-debounce="300"
               class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
      </div>

      <!-- Jobs List -->
      <div>
        <div class="flex items-center justify-between mb-2">
          <label class="block text-sm font-medium text-gray-700">Work Experience</label>
          <button type="button"
                  phx-click="add_list_item"
                  phx-value-block_id={@block.id}
                  phx-value-field="jobs"
                  phx-target={@myself}
                  class="text-sm text-blue-600 hover:text-blue-800">
            + Add Job
          </button>
        </div>

        <div class="space-y-4">
          <%= for {job, index} <- Enum.with_index(jobs) do %>
            <div class="border border-gray-200 rounded-lg p-4">
              <div class="flex items-center justify-between mb-3">
                <h4 class="text-sm font-medium text-gray-900">Job #<%= index + 1 %></h4>
                <button type="button"
                        phx-click="remove_list_item"
                        phx-value-block_id={@block.id}
                        phx-value-field="jobs"
                        phx-value-index={index}
                        phx-target={@myself}
                        class="text-red-600 hover:text-red-800">
                  Remove
                </button>
              </div>

              <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
                <div>
                  <label class="block text-xs text-gray-600 mb-1">Job Title</label>
                  <input type="text"
                         value={Map.get(job, "title", "")}
                         name={"job_#{index}_title"}
                         phx-debounce="300"
                         class="w-full px-2 py-1 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-blue-500">
                </div>

                <div>
                  <label class="block text-xs text-gray-600 mb-1">Company</label>
                  <input type="text"
                         value={Map.get(job, "company", "")}
                         name={"job_#{index}_company"}
                         phx-debounce="300"
                         class="w-full px-2 py-1 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-blue-500">
                </div>

                <div>
                  <label class="block text-xs text-gray-600 mb-1">Duration</label>
                  <input type="text"
                         value={Map.get(job, "duration", "")}
                         name={"job_#{index}_duration"}
                         placeholder="e.g., 2020-2023"
                         phx-debounce="300"
                         class="w-full px-2 py-1 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-blue-500">
                </div>

                <div class="md:col-span-2">
                  <label class="block text-xs text-gray-600 mb-1">Description</label>
                  <textarea rows="2"
                            name={"job_#{index}_description"}
                            phx-debounce="300"
                            class="w-full px-2 py-1 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-blue-500"><%= Map.get(job, "description", "") %></textarea>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </form>
    """
  end

  defp render_block_type_form(%{block_type: :achievement_card} = block, assigns) do
    assigns = assign(assigns, :block, block)
    content = block.content_data || %{}
    achievements = Map.get(content, "achievements", [])

    ~H"""
    <form phx-change="update_field" phx-target={@myself}>
      <!-- Title Field -->
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Title</label>
        <input type="text"
               name="title"
               value={Map.get(content, "title", "")}
               phx-debounce="300"
               class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
      </div>

      <!-- Achievements List -->
      <div>
        <div class="flex items-center justify-between mb-2">
          <label class="block text-sm font-medium text-gray-700">Achievements</label>
          <button type="button"
                  phx-click="add_list_item"
                  phx-value-block_id={@block.id}
                  phx-value-field="achievements"
                  phx-target={@myself}
                  class="text-sm text-blue-600 hover:text-blue-800">
            + Add Achievement
          </button>
        </div>

        <div class="space-y-4">
          <%= for {achievement, index} <- Enum.with_index(achievements) do %>
            <div class="border border-gray-200 rounded-lg p-4">
              <div class="flex items-center justify-between mb-3">
                <h4 class="text-sm font-medium text-gray-900">Achievement #<%= index + 1 %></h4>
                <button type="button"
                        phx-click="remove_list_item"
                        phx-value-block_id={@block.id}
                        phx-value-field="achievements"
                        phx-value-index={index}
                        phx-target={@myself}
                        class="text-red-600 hover:text-red-800">
                  Remove
                </button>
              </div>

              <div class="space-y-3">
                <div>
                  <label class="block text-xs text-gray-600 mb-1">Achievement Title</label>
                  <input type="text"
                         value={Map.get(achievement, "title", "")}
                         name={"achievement_#{index}_title"}
                         phx-debounce="300"
                         class="w-full px-2 py-1 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-blue-500">
                </div>

                <div>
                  <label class="block text-xs text-gray-600 mb-1">Description</label>
                  <textarea rows="2"
                            name={"achievement_#{index}_description"}
                            phx-debounce="300"
                            class="w-full px-2 py-1 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-blue-500"><%= Map.get(achievement, "description", "") %></textarea>
                </div>

                <div>
                  <label class="block text-xs text-gray-600 mb-1">Date</label>
                  <input type="text"
                         value={Map.get(achievement, "date", "")}
                         name={"achievement_#{index}_date"}
                         placeholder="e.g., March 2023"
                         phx-debounce="300"
                         class="w-full px-2 py-1 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-blue-500">
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </form>
    """
  end

  # Default form for other block types
  defp render_block_type_form(block, assigns) do
    assigns = assign(assigns, :block, block)
    content = block.content_data || %{}

    ~H"""
    <form phx-change="update_field" phx-target={@myself}>
      <!-- Title Field -->
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Title</label>
        <input type="text"
               name="title"
               value={Map.get(content, "title", "")}
               phx-debounce="300"
               class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
      </div>

      <!-- Content Field -->
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Content</label>
        <textarea name="content"
                  rows="4"
                  phx-debounce="300"
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"><%= Map.get(content, "content", "") %></textarea>
      </div>
    </form>
    """
  end

  # ============================================================================
  # CONTENT BLOCK EDITOR RENDERING
  # ============================================================================

  defp render_content_block_editor(block, assigns) do
    assigns = assign(assigns, :block, block)

    ~H"""
    <div class="flex items-center justify-between">
      <div class="flex-1">
        <h5 class="font-medium text-gray-900">
          <%= get_block_title_safe(@block) %>
        </h5>
        <p class="text-sm text-gray-600 mt-1">
          <%= get_block_description_safe(@block) %>
        </p>
      </div>

      <%= if @show_edit_controls do %>
        <div class="flex items-center space-x-2">
          <button phx-click="edit_content_block"
                  phx-value-block_id={@block.id}
                  phx-target={@myself}
                  class="px-3 py-1 text-sm bg-blue-100 text-blue-700 rounded-md hover:bg-blue-200 transition-colors">
            Edit
          </button>

          <button phx-click="remove_content_block"
                  phx-value-block_id={@block.id}
                  phx-target={@myself}
                  class="px-3 py-1 text-sm bg-red-100 text-red-700 rounded-md hover:bg-red-200 transition-colors">
            Remove
          </button>
        </div>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

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
    # Safely merge the changes into the existing content_data
    current_content = block.content_data || %{}
    updated_content_data = Map.merge(current_content, changes)
    %{block | content_data: updated_content_data}
  end

  defp update_block_content(block, _invalid_changes) do
    # If changes is not a map, return block unchanged
    IO.puts("Invalid changes format, block unchanged")
    block
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

  defp schedule_save_status_reset(socket) do
    Process.send_after(self(), :reset_save_status, 2000)
    socket
  end


  defp add_item_to_list_field(content_data, field) do
    current_list = Map.get(content_data, field, [])
    new_item = case field do
      "highlights" -> ""
      "jobs" -> %{"title" => "", "company" => "", "duration" => "", "description" => ""}
      "achievements" -> %{"title" => "", "description" => "", "date" => ""}
      _ -> ""
    end
    Map.put(content_data, field, current_list ++ [new_item])
  end

  defp remove_item_from_list_field(content_data, field, index) do
    current_list = Map.get(content_data, field, [])
    updated_list = List.delete_at(current_list, index)
    Map.put(content_data, field, updated_list)
  end

  defp get_nested_value(map, keys, default) do
    Enum.reduce(keys, map, fn key, acc ->
      case acc do
        %{} -> Map.get(acc, key)
        _ -> default
      end
    end) || default
  end

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

  defp get_block_title_safe(block) do
    case block.content_data do
      %{title: title} when is_binary(title) and title != "" -> title
      %{"title" => title} when is_binary(title) and title != "" -> title
      _ -> humanize_block_type(block.block_type)
    end
  end

  defp get_block_description_safe(block) do
    content_data = block.content_data || %{}

    description = case content_data do
      %{description: desc} when is_binary(desc) -> desc
      %{"description" => desc} when is_binary(desc) -> desc
      %{content: content} when is_binary(content) -> content
      %{"content" => content} when is_binary(content) -> content
      %{subtitle: subtitle} when is_binary(subtitle) -> subtitle
      %{"subtitle" => subtitle} when is_binary(subtitle) -> subtitle
      _ -> "Click to edit this block"
    end

    if String.length(description) > 60 do
      String.slice(description, 0, 60) <> "..."
    else
      description
    end
  end

  defp map_block_type_to_section_type(:hero_card), do: "hero"
  defp map_block_type_to_section_type(:about_card), do: "about"
  defp map_block_type_to_section_type(:service_card), do: "services"
  defp map_block_type_to_section_type(:project_card), do: "portfolio"
  defp map_block_type_to_section_type(:contact_card), do: "contact"
  defp map_block_type_to_section_type(:skill_card), do: "skills"
  defp map_block_type_to_section_type(:testimonial_card), do: "testimonials"
  defp map_block_type_to_section_type(:experience_card), do: "experience"
  defp map_block_type_to_section_type(:achievement_card), do: "achievements"
  defp map_block_type_to_section_type(_), do: "text"

  defp get_current_layout_config(portfolio, brand_settings) do
    %{
      layout_type: get_portfolio_layout(portfolio),
      brand_settings: brand_settings,
      customization: portfolio.customization || %{}
    }
  end

  defp get_portfolio_layout(portfolio) do
    case portfolio.customization do
      %{"layout" => layout} when is_binary(layout) -> layout
      _ -> portfolio.theme || "dynamic_card_layout"
    end
  end

  defp add_block_to_zone(layout_zones, zone, new_block) do
    current_blocks = Map.get(layout_zones, zone, [])
    Map.put(layout_zones, zone, current_blocks ++ [new_block])
  end
end
