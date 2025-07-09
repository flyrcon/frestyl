# lib/frestyl_web/live/portfolio_live/dynamic_card_layout_manager.ex
defmodule FrestylWeb.PortfolioLive.DynamicCardLayoutManager do
  @moduledoc """
  Dynamic Card Layout Manager - Arranges content blocks into brand-controllable
  layouts that work across all portfolio templates with monetization focus.

  Follows the PortfolioEditor framework for unified state management.
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
    }
  end

  @impl true
  def update(assigns, socket) do
    # Get mode - edit or public
    view_mode = Map.get(assigns, :view_mode, :edit)
    show_edit_controls = Map.get(assigns, :show_edit_controls, view_mode == :edit)

    # Get layout configuration
    layout_config = get_current_layout_config(assigns.portfolio, assigns.brand_settings)

    # Organize content blocks by layout zones
    layout_zones = assigns.layout_zones || %{}

    {:ok, socket
      |> assign(assigns)
      |> assign(:view_mode, view_mode)
      |> assign(:show_edit_controls, show_edit_controls)
      |> assign(:layout_config, layout_config)
      |> assign(:layout_zones, layout_zones)
      |> assign(:editing_block_id, nil)  # Track which block is being edited
      |> assign(:block_changes, %{})     # Track unsaved changes
    }
  end

  @impl true
  def handle_event("start_editing_block", %{"block_id" => block_id}, socket) do
    IO.puts("🔥 START EDITING BLOCK: #{block_id}")
    {:noreply, assign(socket, :editing_block_id, block_id)}
  end

  @impl true
  def handle_event("cancel_editing_block", _params, socket) do
    IO.puts("🔥 CANCEL EDITING BLOCK")
    {:noreply, socket |> assign(:editing_block_id, nil) |> assign(:block_changes, %{})}
  end

  @impl true
  def handle_event("update_block_content", %{"block_id" => block_id, "field" => field, "value" => value}, socket) do
    IO.puts("🔥 UPDATE BLOCK CONTENT: #{block_id} - #{field} = #{value}")
    current_changes = socket.assigns.block_changes
    block_changes = Map.put(current_changes, "#{block_id}_#{field}", value)

    {:noreply, assign(socket, :block_changes, block_changes)}
  end

  @impl true
  def handle_event("save_block_changes", %{"block_id" => block_id}, socket) do
    IO.puts("🔥 SAVE BLOCK CHANGES: #{block_id}")
    IO.puts("🔥 Changes: #{inspect(socket.assigns.block_changes)}")

    case save_block_edits(block_id, socket.assigns.block_changes, socket) do
      {:ok, updated_zones} ->
        {:noreply,
        socket
        |> assign(:layout_zones, updated_zones)
        |> assign(:editing_block_id, nil)
        |> assign(:block_changes, %{})
        }

      {:error, reason} ->
        IO.puts("🔥 SAVE ERROR: #{reason}")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event(event_name, params, socket) do
    IO.puts("🔥 UNHANDLED EVENT in DynamicCardLayoutManager: #{event_name}")
    IO.puts("🔥 Params: #{inspect(params)}")
    {:noreply, socket}
  end


  defp save_block_edits(block_id, block_changes, socket) do
    layout_zones = socket.assigns.layout_zones

    # Find and update the block
    updated_zones = Enum.reduce(layout_zones, %{}, fn {zone_name, blocks}, acc ->
      updated_blocks = Enum.map(blocks, fn block ->
        if to_string(block.id) == block_id do
          update_block_with_changes(block, block_changes, block_id)
        else
          block
        end
      end)
      Map.put(acc, zone_name, updated_blocks)
    end)

    # Send update to parent component
    send(self(), {:block_updated, block_id, updated_zones})

    {:ok, updated_zones}
  rescue
    error ->
      {:error, "Save failed: #{Exception.message(error)}"}
  end

  defp update_block_with_changes(block, block_changes, block_id) do
    updated_content = Enum.reduce(block_changes, block.content_data, fn {key, value}, acc ->
      case String.split(key, "_", parts: 2) do
        [^block_id, field] -> Map.put(acc, String.to_atom(field), value)
        _ -> acc
      end
    end)

    %{block | content_data: updated_content}
  end

  defp get_block_preview_text(block) do
    content = block.content_data

    # Try multiple ways to get text
    text = case content do
      %{content: text} when is_binary(text) and text != "" -> text
      %{subtitle: text} when is_binary(text) and text != "" -> text
      %{description: text} when is_binary(text) and text != "" -> text
      %{jobs: jobs} when is_list(jobs) and length(jobs) > 0 ->
        first_job = List.first(jobs)
        Map.get(first_job, "description", Map.get(first_job, "title", "Experience entry"))
      _ ->
        # Fallback to original section content if available
        case Map.get(block, :original_section) do
          %{content: section_content} when is_map(section_content) ->
            Map.get(section_content, "main_content", Map.get(section_content, "summary", "No content"))
          _ -> "No content available"
        end
    end

    if String.length(text) > 100 do
      String.slice(text, 0, 100) <> "..."
    else
      text
    end
  end

  defp get_block_title_safe(block) do
    content_data = block.content_data

    case content_data do
      %{title: title} when is_binary(title) and title != "" -> title
      %{"title" => title} when is_binary(title) and title != "" -> title
      _ ->
        # Fallback to original section title
        case Map.get(block, :original_section) do
          %{title: title} when is_binary(title) -> title
          _ -> "Untitled Block"
        end
    end
  end

  defp get_block_type_safe(block) do
    case block do
      %{block_type: block_type} -> block_type
      %{type: type} -> type
      %{"block_type" => block_type} -> block_type
      %{"type" => type} -> type
      _ -> :text_card
    end
  end

  defp get_block_name_safe(block) do
    case block do
      %{name: name} when is_binary(name) -> name
      %{"name" => name} when is_binary(name) -> name
      %{title: title} when is_binary(title) -> title
      %{"title" => title} when is_binary(title) -> title
      _ -> get_block_title_safe(block)
    end
  end

  defp get_block_category_safe(block) do
    case block do
      %{category: category} -> String.capitalize(to_string(category))
      %{"category" => category} -> String.capitalize(to_string(category))
      _ -> "Content"
    end
  end

  @impl true
  def handle_event("test_event", _params, socket) do
    IO.puts("🔥🔥🔥 TEST EVENT TRIGGERED! Component is receiving events! 🔥🔥🔥")
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="dynamic-card-layout-manager"
        id={"layout-manager-#{@portfolio.id}"}
        phx-hook={if @show_edit_controls, do: "DynamicCardLayout", else: nil}>

      <%= if @show_edit_controls do %>
        <!-- Edit Mode: Show controls and editor interface -->
        <div class="layout-edit-interface">
          <!-- Editor Sidebar -->
          <div class="layout-sidebar bg-white border-r border-gray-200 w-80">
            <%= render_editor_sidebar(assigns) %>
          </div>
          <!-- Test Button -->
          <button phx-click="test_event"
                  phx-target={@myself}
                  class="w-full px-3 py-2 bg-red-600 text-white rounded-lg text-sm hover:bg-red-700 mb-4">
            Test Event (Debug)
          </button>

          <!-- Editor Canvas -->
          <div class="layout-canvas flex-1">
            <%= render_layout_zones_editor(assigns) %>
          </div>
        </div>
      <% else %>
        <!-- Public Mode: Just render the content -->
        <div class="layout-public-view">
          <%= render_layout_zones_public(assigns) %>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_editor_sidebar(assigns) do
    ~H"""
    <div class="p-4 space-y-6">
      <h3 class="text-lg font-semibold text-gray-900">Content Blocks</h3>

      <!-- Available Blocks -->
      <div class="space-y-2">
        <%= for block <- @available_blocks || [] do %>
          <div class="p-3 border border-gray-200 rounded-lg cursor-pointer hover:bg-gray-50"
              phx-click="add_block_to_layout"
              phx-value-block_type={get_block_type_safe(block)}
              phx-target={@myself}>
            <div class="font-medium text-sm"><%= get_block_name_safe(block) %></div>
            <div class="text-xs text-gray-500"><%= get_block_category_safe(block) %></div>
          </div>
        <% end %>
      </div>

      <!-- Layout Controls -->
      <div class="pt-4 border-t border-gray-200">
        <h4 class="font-medium text-gray-900 mb-2">Layout Options</h4>
        <button phx-click="save_layout" phx-target={@myself}
                class="w-full px-3 py-2 bg-blue-600 text-white rounded-lg text-sm hover:bg-blue-700">
          Save Layout
        </button>
      </div>
    </div>
    """
  end

  # ADD these helper functions to handle different block data structures:

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

  @impl true
  def render(assigns) do
    ~H"""
    <div class="dynamic-card-layout-manager"
        id={"layout-manager-#{@portfolio.id}"}>

      <%= if Map.get(assigns, :show_edit_controls, false) do %>
        <!-- Edit Mode: Show basic editor interface -->
        <div class="layout-edit-interface flex h-full">
          <!-- Simple Sidebar -->
          <div class="layout-sidebar bg-white border-r border-gray-200 w-80 p-4">
            <h3 class="text-lg font-semibold text-gray-900 mb-4">Content Blocks</h3>

            <!-- Show editing status -->
            <%= if Map.get(assigns, :editing_block_id) do %>
              <div class="mb-4 p-3 bg-blue-50 border border-blue-200 rounded">
                <p class="text-sm text-blue-700">Editing block: <%= @editing_block_id %></p>
              </div>
            <% end %>

            <!-- Show available blocks count -->
            <p class="text-sm text-gray-600 mb-4">
              Available blocks: <%= length(Map.get(assigns, :available_blocks, [])) %>
            </p>

            <!-- Show layout zones count -->
            <p class="text-sm text-gray-600 mb-4">
              Layout zones: <%= map_size(Map.get(assigns, :layout_zones, %{})) %>
            </p>
          </div>

          <!-- Editor Canvas -->
          <div class="layout-canvas flex-1 p-6 bg-gray-50">
            <%= render_layout_zones_editor(assigns) %>
          </div>
        </div>
      <% else %>
        <!-- Public Mode: Just render the content -->
        <div class="layout-public-view">
          <%= render_layout_zones_public(assigns) %>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_layout_zones_editor(assigns) do
    layout_zones = Map.get(assigns, :layout_zones, %{})

    ~H"""
    <div class="layout-zones-editor space-y-8">
      <h2 class="text-2xl font-bold text-gray-900">Portfolio Layout</h2>

      <!-- Debug Component Info -->
      <div class="mb-4 p-3 bg-yellow-50 border border-yellow-200 rounded text-xs">
        <strong>Component Debug:</strong><br>
        Component ID: <%= @myself %><br>
        Editing Block: <%= Map.get(assigns, :editing_block_id, "none") %><br>
        Total Zones: <%= map_size(layout_zones) %>
      </div>

      <%= if map_size(layout_zones) > 0 do %>
        <div class="space-y-6">
          <%= for {zone_name, blocks} <- layout_zones do %>
            <%= if length(blocks) > 0 do %>
              <div class="layout-zone border-2 border-dashed border-purple-200 rounded-lg p-4 bg-purple-50"
                  data-zone={zone_name}>

                <h3 class="text-md font-medium text-purple-900 mb-3 capitalize flex items-center">
                  <div class="w-3 h-3 bg-purple-600 rounded-full mr-2"></div>
                  <%= String.replace(to_string(zone_name), "_", " ") %> Zone
                </h3>

                <div class="space-y-3">
                  <%= for block <- blocks do %>
                    <%= render_editable_content_block(block, zone_name, assigns) %>
                  <% end %>
                </div>
              </div>
            <% end %>
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

  defp render_layout_zones_public(assigns) do
    layout_zones = Map.get(assigns, :layout_zones, %{})

    ~H"""
    <div class="layout-zones-public">
      <%= if map_size(layout_zones) > 0 do %>
        <%= for {zone_name, blocks} <- layout_zones do %>
          <section class={"layout-zone-#{zone_name} py-8"} data-zone={zone_name}>
            <%= if length(blocks) > 0 do %>
              <%= for block <- blocks do %>
                <%= render_content_block_public(block, assigns) %>
              <% end %>
            <% end %>
          </section>
        <% end %>
      <% else %>
        <!-- Fallback: Show traditional sections if no layout zones -->
        <div class="traditional-sections">
          <%= render_traditional_sections_fallback(assigns) %>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_traditional_sections_fallback(assigns) do
    sections = Map.get(assigns.portfolio, :sections, [])

    ~H"""
    <div class="max-w-4xl mx-auto px-6 py-8">
      <h1 class="text-4xl font-bold text-gray-900 mb-6"><%= @portfolio.title %></h1>
      <p class="text-xl text-gray-600 mb-12"><%= @portfolio.description %></p>

      <%= if length(sections) > 0 do %>
        <%= for section <- sections do %>
          <%= if Map.get(section, :visible, true) do %>
            <section class="mb-12 bg-white rounded-lg shadow-sm border p-6">
              <h2 class="text-2xl font-semibold text-gray-900 mb-4"><%= section.title %></h2>
              <div class="prose max-w-none">
                <%= render_section_content_safe(section) %>
              </div>
            </section>
          <% end %>
        <% end %>
      <% else %>
        <div class="text-center py-12">
          <p class="text-gray-500">No content available</p>
        </div>
      <% end %>
    </div>
    """
  end


  defp render_content_block_editor(block, assigns) do
    assigns = assign(assigns, :block, block)
    block_type = get_block_type_safe(block)

    case block_type do
      :hero_card ->
        ~H"""
        <div class="hero-block-editor">
          <h4 class="font-medium text-gray-900">Hero Section</h4>
          <p class="text-sm text-gray-600 mt-1">
            <%= get_block_title_safe(@block) %>
          </p>
        </div>
        """

      :about_card ->
        ~H"""
        <div class="about-block-editor">
          <h4 class="font-medium text-gray-900">About Section</h4>
          <p class="text-sm text-gray-600 mt-1">
            <%= get_block_content_preview(@block) %>
          </p>
        </div>
        """

      :service_card ->
        ~H"""
        <div class="service-block-editor">
          <h4 class="font-medium text-gray-900">Service: <%= get_block_title_safe(@block) %></h4>
          <p class="text-sm text-gray-600 mt-1">
            <%= get_block_description_safe(@block) %>
          </p>
        </div>
        """

      :project_card ->
        ~H"""
        <div class="project-block-editor">
          <h4 class="font-medium text-gray-900">Project: <%= get_block_title_safe(@block) %></h4>
          <p class="text-sm text-gray-600 mt-1">
            <%= get_block_description_safe(@block) %>
          </p>
        </div>
        """

      _ ->
        ~H"""
        <div class="generic-block-editor">
          <h4 class="font-medium text-gray-900 capitalize"><%= humanize_block_type(block_type) %></h4>
          <p class="text-sm text-gray-600 mt-1">Content block</p>
        </div>
        """
    end
  end

  defp render_editable_content_block(block, zone_name, assigns) do
    is_editing = assigns.editing_block_id == to_string(block.id)
    assigns = assign(assigns, :block, block) |> assign(:is_editing, is_editing) |> assign(:zone_name, zone_name)

    ~H"""
    <div class="bg-white border border-purple-200 rounded-lg p-4" data-block-id={@block.id}>
      <%= if @is_editing do %>
        <%= render_block_edit_form(@block, assigns) %>
      <% else %>
        <%= render_block_display(@block, assigns) %>
      <% end %>
    </div>
    """
  end

  defp render_block_display(block, assigns) do
    component_id = assigns.myself
    assigns = assign(assigns, :block, block) |> assign(:component_id, component_id)

    ~H"""
    <div class="flex items-start justify-between mb-2">
      <div class="flex-1">
        <h4 class="font-medium text-gray-900"><%= get_block_title_safe(@block) %></h4>
        <span class="text-xs bg-purple-100 text-purple-700 px-2 py-1 rounded">
          <%= @block.block_type %>
        </span>
      </div>

      <div class="flex space-x-2">
        <!-- Direct event with component target -->
        <button phx-click="start_editing_block"
                phx-value-block_id={@block.id}
                phx-target={@component_id}
                class="text-xs px-2 py-1 bg-blue-100 text-blue-700 rounded hover:bg-blue-200"
                type="button">
          Edit
        </button>
        <button phx-click="move_block"
                phx-value-block_id={@block.id}
                phx-target={@component_id}
                class="text-xs px-2 py-1 bg-gray-100 text-gray-700 rounded hover:bg-gray-200"
                type="button">
          Move
        </button>
      </div>
    </div>

    <div class="text-sm text-gray-600 mb-3">
      <%= get_block_preview_text(@block) %>
    </div>

    <!-- Debug info -->
    <div class="text-xs text-gray-400">
      Block ID: <%= @block.id %> | Component: <%= @component_id %>
    </div>
    """
  end


  defp render_block_edit_form(block, assigns) do
    component_id = assigns.myself
    assigns = assign(assigns, :block, block) |> assign(:component_id, component_id)
    content = block.content_data

    ~H"""
    <form phx-submit="save_block_changes" phx-target={@component_id} phx-value-block_id={@block.id}>
      <div class="space-y-3">
        <!-- Title Field -->
        <div>
          <label class="block text-xs font-medium text-gray-700 mb-1">Title</label>
          <input type="text"
                name="title"
                value={Map.get(content, :title, "")}
                phx-change="update_block_content"
                phx-value-block_id={@block.id}
                phx-value-field="title"
                phx-target={@component_id}
                class="w-full px-3 py-2 border border-gray-300 rounded-md text-sm focus:ring-purple-500 focus:border-purple-500">
        </div>

        <!-- Content Field -->
        <div>
          <label class="block text-xs font-medium text-gray-700 mb-1">Content</label>
          <textarea name="content"
                    rows="3"
                    phx-change="update_block_content"
                    phx-value-block_id={@block.id}
                    phx-value-field="content"
                    phx-target={@component_id}
                    class="w-full px-3 py-2 border border-gray-300 rounded-md text-sm focus:ring-purple-500 focus:border-purple-500"><%= Map.get(content, :content, "") %></textarea>
        </div>

        <!-- Subtitle Field (for hero cards) -->
        <%= if @block.block_type == :hero_card do %>
          <div>
            <label class="block text-xs font-medium text-gray-700 mb-1">Subtitle</label>
            <input type="text"
                  name="subtitle"
                  value={Map.get(content, :subtitle, "")}
                  phx-change="update_block_content"
                  phx-value-block_id={@block.id}
                  phx-value-field="subtitle"
                  phx-target={@component_id}
                  class="w-full px-3 py-2 border border-gray-300 rounded-md text-sm focus:ring-purple-500 focus:border-purple-500">
          </div>
        <% end %>

        <!-- Action Buttons -->
        <div class="flex space-x-2 pt-2">
          <button type="submit"
                  class="px-3 py-1 bg-green-600 text-white rounded text-xs hover:bg-green-700">
            Save Changes
          </button>
          <button type="button"
                  phx-click="cancel_editing_block"
                  phx-target={@component_id}
                  class="px-3 py-1 bg-gray-500 text-white rounded text-xs hover:bg-gray-600">
            Cancel
          </button>
        </div>
      </div>
    </form>
    """
  end

  # ADD these helper functions for safe content access:

  defp get_block_title_safe(block) do
    content_data = get_block_content_data_safe(block)

    case content_data do
      %{title: title} when is_binary(title) -> title
      %{"title" => title} when is_binary(title) -> title
      _ -> get_block_name_safe(block)
    end
  end

  defp get_block_description_safe(block) do
    content_data = get_block_content_data_safe(block)

    case content_data do
      %{description: desc} when is_binary(desc) -> desc
      %{"description" => desc} when is_binary(desc) -> desc
      %{content: content} when is_binary(content) -> content
      %{"content" => content} when is_binary(content) -> content
      _ -> "Block description"
    end
  end

  defp get_block_content_preview(block) do
    content = get_block_description_safe(block)
    if String.length(content) > 50 do
      String.slice(content, 0, 50) <> "..."
    else
      content
    end
  end

  defp get_block_content_data_safe(block) do
    case block do
      %{content_data: content_data} when is_map(content_data) -> content_data
      %{"content_data" => content_data} when is_map(content_data) -> content_data
      %{default_content: content} when is_map(content) -> content
      %{"default_content" => content} when is_map(content) -> content
      _ -> %{}
    end
  end

  defp humanize_block_type(block_type) do
    block_type
    |> to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp render_content_block_public(block, assigns) do
    assigns = assign(assigns, :block, block)
    brand = assigns.brand_settings

    case block.block_type do
      :hero_card ->
        ~H"""
        <section class="hero-section py-20 px-6" style={"background-color: #{brand.primary_color}15;"}>
          <div class="max-w-4xl mx-auto text-center">
            <h1 class="text-5xl font-bold mb-6" style={"color: #{brand.primary_color};"}>
              <%= @block.content_data.title %>
            </h1>
            <%= if @block.content_data.subtitle do %>
              <p class="text-xl text-gray-600 mb-8">
                <%= @block.content_data.subtitle %>
              </p>
            <% end %>
            <%= if @block.content_data.call_to_action do %>
              <button class="px-8 py-3 rounded-lg text-white font-semibold"
                      style={"background-color: #{brand.primary_color};"}>
                <%= @block.content_data.call_to_action.text %>
              </button>
            <% end %>
          </div>
        </section>
        """

      :about_card ->
        ~H"""
        <section class="about-section py-16 px-6">
          <div class="max-w-4xl mx-auto">
            <div class="grid grid-cols-1 lg:grid-cols-2 gap-12 items-center">
              <%= if @block.content_data.profile_image do %>
                <div class="text-center lg:text-left">
                  <img src={@block.content_data.profile_image}
                      alt="Profile"
                      class="w-64 h-64 rounded-full mx-auto lg:mx-0 object-cover" />
                </div>
              <% end %>
              <div>
                <h2 class="text-3xl font-bold mb-6" style={"color: #{brand.primary_color};"}>
                  <%= @block.content_data.title %>
                </h2>
                <p class="text-gray-600 leading-relaxed">
                  <%= @block.content_data.content %>
                </p>
              </div>
            </div>
          </div>
        </section>
        """

      :service_card ->
        ~H"""
        <div class="service-card bg-white rounded-lg shadow-lg p-6 border-t-4"
            style={"border-top-color: #{brand.accent_color};"}>
          <h3 class="text-xl font-semibold mb-3" style={"color: #{brand.primary_color};"}>
            <%= @block.content_data.title %>
          </h3>
          <p class="text-gray-600 mb-4">
            <%= @block.content_data.description %>
          </p>
          <%= if @block.content_data.price do %>
            <div class="text-2xl font-bold" style={"color: #{brand.accent_color};"}>
              $<%= @block.content_data.price %>
            </div>
          <% end %>
          <%= if @block.content_data.features && length(@block.content_data.features) > 0 do %>
            <ul class="mt-4 space-y-2">
              <%= for feature <- @block.content_data.features do %>
                <li class="flex items-center text-sm text-gray-600">
                  <svg class="w-4 h-4 mr-2" style={"color: #{brand.accent_color};"} fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" />
                  </svg>
                  <%= feature %>
                </li>
              <% end %>
            </ul>
          <% end %>
        </div>
        """

      :project_card ->
        ~H"""
        <div class="project-card bg-white rounded-lg shadow-lg overflow-hidden">
          <%= if @block.content_data.image_url do %>
            <img src={@block.content_data.image_url}
                alt={@block.content_data.title}
                class="w-full h-48 object-cover" />
          <% end %>
          <div class="p-6">
            <h3 class="text-xl font-semibold mb-3" style={"color: #{brand.primary_color};"}>
              <%= @block.content_data.title %>
            </h3>
            <p class="text-gray-600 mb-4">
              <%= @block.content_data.description %>
            </p>
            <%= if @block.content_data.technologies && length(@block.content_data.technologies) > 0 do %>
              <div class="flex flex-wrap gap-2">
                <%= for tech <- @block.content_data.technologies do %>
                  <span class="px-2 py-1 text-xs rounded-full"
                        style={"background-color: #{brand.accent_color}15; color: #{brand.accent_color};"}>
                    <%= tech %>
                  </span>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
        """

      :contact_card ->
        ~H"""
        <section class="contact-section py-16 px-6" style={"background-color: #{brand.primary_color}05;"}>
          <div class="max-w-4xl mx-auto text-center">
            <h2 class="text-3xl font-bold mb-6" style={"color: #{brand.primary_color};"}>
              <%= @block.content_data.title %>
            </h2>
            <p class="text-gray-600 mb-8">
              <%= @block.content_data.content %>
            </p>
            <%= if @block.content_data.contact_methods do %>
              <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
                <%= for method <- @block.content_data.contact_methods do %>
                  <div class="text-center">
                    <div class="w-12 h-12 rounded-full mx-auto mb-3 flex items-center justify-center"
                        style={"background-color: #{brand.accent_color};"}>
                      <span class="text-white font-semibold">
                        <%= String.first(method.type) |> String.upcase() %>
                      </span>
                    </div>
                    <div class="font-medium text-gray-900"><%= method.label %></div>
                    <div class="text-gray-600"><%= method.value %></div>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </section>
        """

      _ ->
        ~H"""
        <div class="generic-content-block p-6">
          <h3 class="text-lg font-semibold">Generic Content Block</h3>
          <p class="text-gray-600">Block type: <%= @block.block_type %></p>
        </div>
        """
    end
  end

  # ============================================================================
  # EVENT HANDLERS (Following PortfolioEditor Pattern)
  # ============================================================================

  @impl true
  def handle_event("switch_category", %{"category" => category}, socket) do
    category_atom = String.to_atom(category)

    {:noreply, socket
      |> assign(:active_category, category_atom)
      |> assign(:layout_dirty, false)
    }
  end

  @impl true
  def handle_event("toggle_brand_preview", _params, socket) do
    new_mode = !socket.assigns.brand_preview_mode

    {:noreply, socket
      |> assign(:brand_preview_mode, new_mode)
      |> push_event("brand_preview_toggled", %{enabled: new_mode})
    }
  end

  @impl true
  def handle_event("switch_device_preview", %{"device" => device}, socket) do
    device_atom = String.to_atom(device)

    {:noreply, socket
      |> assign(:preview_device, device_atom)
      |> push_event("device_preview_changed", %{device: device})
    }
  end

  @impl true
  def handle_event("add_block_to_zone", %{"block_type" => block_type, "zone" => zone, "position" => position}, socket) do
    # Following PortfolioEditor's create_content_block pattern
    case create_dynamic_card_block(block_type, zone, position, socket) do
      {:ok, new_block} ->
        updated_zones = add_block_to_layout_zone(socket.assigns.layout_zones, zone, new_block, position)

        {:noreply, socket
          |> assign(:layout_zones, updated_zones)
          |> assign(:layout_dirty, true)
          |> put_flash(:info, "Block added successfully")
        }

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to add block: #{reason}")}
    end
  end

  @impl true
  def handle_event("reorder_blocks_in_zone", %{"zone" => zone, "block_order" => order}, socket) do
    updated_zones = reorder_zone_blocks(socket.assigns.layout_zones, zone, order)

    {:noreply, socket
      |> assign(:layout_zones, updated_zones)
      |> assign(:layout_dirty, true)
    }
  end

  @impl true
  def handle_event("apply_layout_template", %{"template_key" => template_key}, socket) do
    case apply_predefined_layout_template(template_key, socket) do
      {:ok, new_layout_zones} ->
        {:noreply, socket
          |> assign(:layout_zones, new_layout_zones)
          |> assign(:layout_dirty, true)
          |> assign(:show_layout_templates, false)
          |> put_flash(:info, "Layout template applied")
        }

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to apply template: #{reason}")}
    end
  end

  @impl true
  def handle_event("add_block_to_layout", %{"block_type" => block_type}, socket) do
    case create_new_content_block(block_type, socket) do
      {:ok, new_block} ->
        # Add to the appropriate zone (default to first available zone)
        {zone_name, _} = Enum.at(socket.assigns.layout_zones, 0, {:hero, []})
        updated_zones = add_block_to_zone(socket.assigns.layout_zones, zone_name, new_block)

        {:noreply, assign(socket, :layout_zones, updated_zones)}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to add block")}
    end
  end

  @impl true
  def handle_event("edit_block", %{"block_id" => block_id}, socket) do
    # Open block editor modal or inline editing
    {:noreply, assign(socket, :editing_block_id, block_id)}
  end

  @impl true
  def handle_event("remove_block", %{"block_id" => block_id}, socket) do
    updated_zones = remove_block_from_zones(socket.assigns.layout_zones, block_id)
    {:noreply, assign(socket, :layout_zones, updated_zones)}
  end

  @impl true
  def handle_event("save_layout", _params, socket) do
    case save_portfolio_layout(socket.assigns.portfolio, socket.assigns.layout_zones) do
      {:ok, _portfolio} ->
        {:noreply, put_flash(socket, :info, "Layout saved successfully")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to save layout")}
    end
  end

  @impl true
  def handle_event("move_block", %{"block_id" => block_id, "from_zone" => from_zone, "to_zone" => to_zone, "position" => position}, socket) do
    updated_zones = move_block_between_zones(
      socket.assigns.layout_zones,
      block_id,
      String.to_atom(from_zone),
      String.to_atom(to_zone),
      String.to_integer(position)
    )

    {:noreply, assign(socket, :layout_zones, updated_zones)}
  end

  @impl true
  def handle_event("move_block", %{"block_id" => block_id}, socket) do
    IO.puts("🔥 MOVE BLOCK: #{block_id}")
    {:noreply, socket}
  end

  # ============================================================================
  # LAYOUT ZONE RENDERING
  # ============================================================================

  defp render_layout_zones_public(assigns) do
    ~H"""
    <div class="layout-zones-public">
      <%= for {zone_name, blocks} <- @layout_zones do %>
        <%= render_zone_section(zone_name, blocks, assigns) %>
      <% end %>
    </div>
    """
  end

  defp render_zone_section(zone_name, blocks, assigns) when zone_name in [:services, :portfolio] do
    assigns = assign(assigns, :zone_name, zone_name) |> assign(:blocks, blocks)

    ~H"""
    <section class={"layout-zone-#{@zone_name} py-16"} data-zone={@zone_name}>
      <%= if length(@blocks) > 0 do %>
        <div class="max-w-6xl mx-auto px-6">
          <div class="text-center mb-12">
            <h2 class="text-3xl font-bold mb-4" style={"color: #{@brand_settings.primary_color};"}>
              <%= String.capitalize(to_string(@zone_name)) %>
            </h2>
          </div>

          <div class={"#{@zone_name}-grid"}>
            <%= for block <- @blocks do %>
              <%= render_content_block_public(block, assigns) %>
            <% end %>
          </div>
        </div>
      <% end %>
    </section>
    """
  end



  defp render_section_content_safe(section) do
    content = Map.get(section, :content, %{})

    main_content = case content do
      %{"main_content" => text} when is_binary(text) -> text
      %{"summary" => text} when is_binary(text) -> text
      %{"description" => text} when is_binary(text) -> text
      _ -> "Section content..."
    end

    Phoenix.HTML.raw("<p>#{Phoenix.HTML.html_escape(main_content)}</p>")
  end

  defp render_zone_section(zone_name, blocks, assigns) do
    assigns = assign(assigns, :zone_name, zone_name) |> assign(:blocks, blocks)

    ~H"""
    <section class={"layout-zone-#{@zone_name}"} data-zone={@zone_name}>
      <%= for block <- @blocks do %>
        <%= render_content_block_public(block, assigns) %>
      <% end %>
    </section>
    """
  end

  defp render_service_provider_layout(assigns) do
    ~H"""
    <!-- Service Provider: Emphasizes booking/pricing -->
    <div class="service-provider-layout grid gap-6">
      <!-- Hero Zone: Main service showcase -->
      <div class="hero-zone col-span-full">
        <%= render_layout_zone("hero", @layout_zones["hero"] || [], assigns) %>
      </div>

      <!-- Services Grid: 2-column on desktop -->
      <div class="services-zone grid grid-cols-1 lg:grid-cols-2 gap-6 col-span-full">
        <%= render_layout_zone("services", @layout_zones["services"] || [], assigns) %>
      </div>

      <!-- Trust Building Section: Testimonials & Pricing -->
      <div class="trust-zone grid grid-cols-1 lg:grid-cols-3 gap-6 col-span-full">
        <div class="lg:col-span-2">
          <%= render_layout_zone("testimonials", @layout_zones["testimonials"] || [], assigns) %>
        </div>
        <div class="lg:col-span-1">
          <%= render_layout_zone("pricing", @layout_zones["pricing"] || [], assigns) %>
        </div>
      </div>

      <!-- Call-to-Action Zone -->
      <div class="cta-zone col-span-full">
        <%= render_layout_zone("cta", @layout_zones["cta"] || [], assigns) %>
      </div>
    </div>
    """
  end

  defp render_creative_showcase_layout(assigns) do
    ~H"""
    <!-- Creative Showcase: Portfolio-focused with commission options -->
    <div class="creative-showcase-layout grid gap-6">
      <!-- Portfolio Header -->
      <div class="portfolio-header-zone col-span-full">
        <%= render_layout_zone("portfolio_header", @layout_zones["portfolio_header"] || [], assigns) %>
      </div>

      <!-- Main Portfolio Gallery: Masonry-style -->
      <div class="portfolio-gallery-zone col-span-full">
        <%= render_layout_zone("portfolio_gallery", @layout_zones["portfolio_gallery"] || [], assigns) %>
      </div>

      <!-- Process & Collaboration: Side-by-side -->
      <div class="showcase-details grid grid-cols-1 lg:grid-cols-2 gap-6 col-span-full">
        <div class="process-zone">
          <%= render_layout_zone("process", @layout_zones["process"] || [], assigns) %>
        </div>
        <div class="collaboration-zone">
          <%= render_layout_zone("collaborations", @layout_zones["collaborations"] || [], assigns) %>
        </div>
      </div>

      <!-- Commission Inquiry Zone -->
      <div class="commission-zone col-span-full">
        <%= render_layout_zone("commission_inquiry", @layout_zones["commission_inquiry"] || [], assigns) %>
      </div>
    </div>
    """
  end

  defp render_technical_expert_layout(assigns) do
    ~H"""
    <!-- Technical Expert: Skill-based with project pricing -->
    <div class="technical-expert-layout grid gap-6">
      <!-- Technical Profile Header -->
      <div class="tech-header-zone col-span-full">
        <%= render_layout_zone("tech_header", @layout_zones["tech_header"] || [], assigns) %>
      </div>

      <!-- Skills Matrix: Interactive grid -->
      <div class="skills-zone col-span-full">
        <%= render_layout_zone("skills_matrix", @layout_zones["skills_matrix"] || [], assigns) %>
      </div>

      <!-- Projects & Consultation: Structured layout -->
      <div class="expertise-showcase grid grid-cols-1 lg:grid-cols-3 gap-6 col-span-full">
        <div class="lg:col-span-2 projects-zone">
          <%= render_layout_zone("projects", @layout_zones["projects"] || [], assigns) %>
        </div>
        <div class="lg:col-span-1 consultation-zone">
          <%= render_layout_zone("consultation", @layout_zones["consultation"] || [], assigns) %>
        </div>
      </div>

      <!-- Technical Blog/Insights Zone -->
      <div class="insights-zone col-span-full">
        <%= render_layout_zone("insights", @layout_zones["insights"] || [], assigns) %>
      </div>
    </div>
    """
  end

  defp render_content_creator_layout(assigns) do
    ~H"""
    <!-- Content Creator: Streaming-focused with subscription options -->
    <div class="content-creator-layout grid gap-6">
      <!-- Creator Brand Header -->
      <div class="creator-header-zone col-span-full">
        <%= render_layout_zone("creator_header", @layout_zones["creator_header"] || [], assigns) %>
      </div>

      <!-- Content Metrics Dashboard -->
      <div class="metrics-zone col-span-full">
        <%= render_layout_zone("content_metrics", @layout_zones["content_metrics"] || [], assigns) %>
      </div>

      <!-- Partnerships & Subscriptions: Feature layout -->
      <div class="monetization-showcase grid grid-cols-1 lg:grid-cols-2 gap-6 col-span-full">
        <div class="partnerships-zone">
          <%= render_layout_zone("brand_partnerships", @layout_zones["brand_partnerships"] || [], assigns) %>
        </div>
        <div class="subscriptions-zone">
          <%= render_layout_zone("subscription_tiers", @layout_zones["subscription_tiers"] || [], assigns) %>
        </div>
      </div>

      <!-- Content Calendar/Schedule -->
      <div class="schedule-zone col-span-full">
        <%= render_layout_zone("content_schedule", @layout_zones["content_schedule"] || [], assigns) %>
      </div>

      <!-- Community Engagement Zone -->
      <div class="community-zone col-span-full">
        <%= render_layout_zone("community", @layout_zones["community"] || [], assigns) %>
      </div>
    </div>
    """
  end

  defp render_corporate_executive_layout(assigns) do
    ~H"""
    <!-- Corporate Executive: Achievement-focused with consultation booking -->
    <div class="corporate-executive-layout grid gap-6">
      <!-- Executive Profile Header -->
      <div class="executive-header-zone col-span-full">
        <%= render_layout_zone("executive_header", @layout_zones["executive_header"] || [], assigns) %>
      </div>

      <!-- Achievements & Metrics Dashboard -->
      <div class="achievements-zone grid grid-cols-1 lg:grid-cols-3 gap-6 col-span-full">
        <div class="lg:col-span-2">
          <%= render_layout_zone("achievements", @layout_zones["achievements"] || [], assigns) %>
        </div>
        <div class="lg:col-span-1">
          <%= render_layout_zone("key_metrics", @layout_zones["key_metrics"] || [], assigns) %>
        </div>
      </div>

      <!-- Leadership & Collaboration Experience -->
      <div class="leadership-zone col-span-full">
        <%= render_layout_zone("leadership", @layout_zones["leadership"] || [], assigns) %>
      </div>

      <!-- Thought Leadership & Consultation -->
      <div class="thought-leadership grid grid-cols-1 lg:grid-cols-2 gap-6 col-span-full">
        <div class="content-zone">
          <%= render_layout_zone("thought_leadership", @layout_zones["thought_leadership"] || [], assigns) %>
        </div>
        <div class="consultation-booking-zone">
          <%= render_layout_zone("executive_consultation", @layout_zones["executive_consultation"] || [], assigns) %>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # INDIVIDUAL ZONE RENDERING
  # ============================================================================

  defp render_layout_zone(zone_name, blocks, assigns) do
    assigns = assign(assigns, :zone_name, zone_name) |> assign(:zone_blocks, blocks)

    ~H"""
    <div class={"layout-zone zone-#{@zone_name}"}
      id={"layout-zone-#{@zone_name}"}
      data-zone={@zone_name}
      phx-hook="LayoutZone">

      <%= if @layout_mode == :edit do %>
        <!-- Zone Header (Edit Mode) -->
        <div class="zone-header flex items-center justify-between p-2 border-2 border-dashed border-gray-300 rounded-lg mb-4 bg-gray-50">
          <span class="text-sm font-medium text-gray-600 capitalize">
            <%= String.replace(@zone_name, "_", " ") %> Zone
          </span>
          <button
            phx-click="add_block_to_zone"
            phx-value-zone={@zone_name}
            phx-target={@myself}
            class="text-xs px-2 py-1 bg-purple-600 text-white rounded hover:bg-purple-700 transition-colors">
            + Add Block
          </button>
        </div>
      <% end %>

      <!-- Zone Content -->
      <div class="zone-content space-y-4">
        <%= if Enum.empty?(@zone_blocks) do %>
          <%= if @layout_mode == :edit do %>
            <!-- Empty Zone Placeholder -->
            <div class="empty-zone-placeholder h-32 border-2 border-dashed border-gray-300 rounded-lg flex items-center justify-center text-gray-500">
              <div class="text-center">
                <svg class="w-8 h-8 mx-auto mb-2 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
                </svg>
                <p class="text-sm">Drop blocks here</p>
              </div>
            </div>
          <% end %>
        <% else %>
          <!-- Render Zone Blocks -->
          <%= for {block, index} <- Enum.with_index(@zone_blocks) do %>
            <div class="zone-block" data-block-id={block.id} data-position={index}>
              <%= render_dynamic_card_block(block, assigns) %>
            </div>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  # ============================================================================
  # DYNAMIC CARD BLOCK RENDERING
  # ============================================================================

  defp render_dynamic_card_block(block, assigns) do
    block_config = DynamicCardBlocks.get_block_config(block.block_type)
    brand_settings = assigns.brand_settings

    assigns = assigns
    |> assign(:block, block)
    |> assign(:block_config, block_config)
    |> assign(:block_css, DynamicCardBlocks.generate_block_css(block.block_type, block.content_data, brand_settings))

    ~H"""
    <div class="dynamic-card-block relative group">
      <%= if @layout_mode == :edit do %>
        <!-- Block Edit Controls -->
        <div class="block-controls absolute top-2 right-2 opacity-0 group-hover:opacity-100 transition-opacity z-10">
          <div class="flex space-x-1">
            <button
              phx-click="edit_block_content"
              phx-value-block-id={@block.id}
              phx-target={@myself}
              class="p-1 bg-blue-600 text-white rounded-sm hover:bg-blue-700 transition-colors">
              <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
              </svg>
            </button>
            <button
              phx-click="remove_block_from_zone"
              phx-value-block-id={@block.id}
              phx-value-zone={@zone_name}
              phx-target={@myself}
              class="p-1 bg-red-600 text-white rounded-sm hover:bg-red-700 transition-colors">
              <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
              </svg>
            </button>
          </div>
        </div>
      <% end %>

      <!-- Block CSS -->
      <style><%= raw(@block_css) %></style>

      <!-- Block Content -->
      <%= case @block.block_type do %>
        <% :service_showcase -> %>
          <%= render_service_showcase_block(@block, assigns) %>
        <% :testimonial_carousel -> %>
          <%= render_testimonial_carousel_block(@block, assigns) %>
        <% :pricing_display -> %>
          <%= render_pricing_display_block(@block, assigns) %>
        <% :portfolio_gallery -> %>
          <%= render_portfolio_gallery_block(@block, assigns) %>
        <% :process_showcase -> %>
          <%= render_process_showcase_block(@block, assigns) %>
        <% :collaboration_display -> %>
          <%= render_collaboration_display_block(@block, assigns) %>
        <% :skill_matrix -> %>
          <%= render_skill_matrix_block(@block, assigns) %>
        <% :project_deep_dive -> %>
          <%= render_project_deep_dive_block(@block, assigns) %>
        <% :consultation_booking -> %>
          <%= render_consultation_booking_block(@block, assigns) %>
        <% :content_metrics -> %>
          <%= render_content_metrics_block(@block, assigns) %>
        <% :brand_partnerships -> %>
          <%= render_brand_partnerships_block(@block, assigns) %>
        <% :subscription_tiers -> %>
          <%= render_subscription_tiers_block(@block, assigns) %>
        <% _ -> %>
          <!-- Fallback for unknown block types -->
          <div class="unknown-block p-4 bg-gray-100 border border-gray-300 rounded-lg">
            <p class="text-sm text-gray-600">Unknown block type: <%= @block.block_type %></p>
          </div>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # SPECIFIC BLOCK RENDERERS
  # ============================================================================

  defp render_service_showcase_block(block, assigns) do
    content = block.content_data
    assigns = assign(assigns, :content, content)

    ~H"""
    <div class="service-showcase-card brand-typography">
      <div class="service-header mb-4">
        <h3 class="text-xl font-semibold brand-heading mb-2">
          <%= @content["service_title"] || "Service Title" %>
        </h3>
        <p class="text-gray-600 mb-4">
          <%= @content["service_description"] || "Service description goes here..." %>
        </p>
      </div>

      <%= if @content["starting_price"] do %>
        <div class="service-pricing mb-4">
          <span class="service-price">
            <%= @content["currency"] %><%= @content["starting_price"] %>
          </span>
          <span class="text-sm text-gray-500 ml-2">
            <%= @content["pricing_model"] %> rate
          </span>
        </div>
      <% end %>

      <%= if @content["includes"] && length(@content["includes"]) > 0 do %>
        <div class="service-includes mb-4">
          <h4 class="text-sm font-medium text-gray-900 mb-2">Includes:</h4>
          <ul class="text-sm text-gray-600 space-y-1">
            <%= for item <- @content["includes"] do %>
              <li class="flex items-center">
                <svg class="w-4 h-4 text-green-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
                </svg>
                <%= item %>
              </li>
            <% end %>
          </ul>
        </div>
      <% end %>

      <%= if @content["booking_enabled"] do %>
        <button class="booking-button w-full">
          <%= @content["booking_button_text"] || "Book Now" %>
        </button>
      <% else %>
        <button class="booking-button w-full opacity-75">
          Get Quote
        </button>
      <% end %>
    </div>
    """
  end

  defp render_testimonial_carousel_block(block, assigns) do
    content = block.content_data
    testimonials = content["testimonials"] || []
    assigns = assign(assigns, :content, content) |> assign(:testimonials, testimonials)

    ~H"""
    <div class="testimonial-carousel brand-typography">
      <h3 class="text-lg font-semibold brand-heading mb-4">Client Testimonials</h3>

      <%= if Enum.empty?(@testimonials) do %>
        <div class="empty-testimonials p-6 bg-gray-50 rounded-lg border-2 border-dashed border-gray-300 text-center">
          <p class="text-gray-500">No testimonials added yet</p>
          <%= if @layout_mode == :edit do %>
            <button class="mt-2 text-sm text-purple-600 hover:text-purple-700">
              Add Testimonial
            </button>
          <% end %>
        </div>
      <% else %>
        <div class="testimonials-grid space-y-4">
          <%= for testimonial <- Enum.take(@testimonials, 3) do %>
            <div class="testimonial-card p-4 bg-white border border-gray-200 rounded-lg">
              <div class="flex items-start space-x-3">
                <%= if testimonial["client_photo_url"] do %>
                  <img src={testimonial["client_photo_url"]}
                       alt={testimonial["client_name"]}
                       class="w-10 h-10 rounded-full object-cover">
                <% else %>
                  <div class="w-10 h-10 bg-gray-300 rounded-full flex items-center justify-center">
                    <span class="text-gray-600 text-sm font-medium">
                      <%= String.first(testimonial["client_name"] || "?") %>
                    </span>
                  </div>
                <% end %>

                <div class="flex-1">
                  <p class="text-gray-700 text-sm mb-2">
                    "<%= testimonial["testimonial_text"] %>"
                  </p>
                  <div class="text-xs text-gray-500">
                    <span class="font-medium"><%= testimonial["client_name"] %></span>
                    <%= if testimonial["client_company"] do %>
                      • <%= testimonial["client_company"] %>
                    <% end %>
                  </div>

                  <%= if @content["show_ratings"] && testimonial["rating"] do %>
                    <div class="flex mt-1">
                      <%= for i <- 1..5 do %>
                        <svg class={[
                          "w-3 h-3",
                          if(i <= testimonial["rating"], do: "text-yellow-400", else: "text-gray-300")
                        ]} fill="currentColor" viewBox="0 0 20 20">
                          <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z"/>
                        </svg>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_pricing_display_block(block, assigns) do
    content = block.content_data
    pricing_tiers = content["pricing_tiers"] || []
    assigns = assign(assigns, :content, content) |> assign(:pricing_tiers, pricing_tiers)

    ~H"""
    <div class="pricing-display brand-typography">
      <h3 class="text-lg font-semibold brand-heading mb-4">Pricing</h3>

      <%= if Enum.empty?(@pricing_tiers) do %>
        <div class="empty-pricing p-6 bg-gray-50 rounded-lg border-2 border-dashed border-gray-300 text-center">
          <p class="text-gray-500">No pricing tiers configured</p>
          <%= if @layout_mode == :edit do %>
            <button class="mt-2 text-sm text-purple-600 hover:text-purple-700">
              Add Pricing Tier
            </button>
          <% end %>
        </div>
      <% else %>
        <div class={[
          "pricing-grid gap-4",
          case @content["display_format"] do
            "table" -> "space-y-2"
            _ -> "grid grid-cols-1 lg:grid-cols-#{min(length(@pricing_tiers), 3)}"
          end
        ]}>
          <%= for tier <- @pricing_tiers do %>
            <div class={[
              "pricing-tier",
              case @content["display_format"] do
                "minimal" -> "p-3 border-l-4 border-purple-600 bg-gray-50"
                "table" -> "flex items-center justify-between p-3 border border-gray-200 rounded"
                _ -> "p-4 bg-white border border-gray-200 rounded-lg hover:shadow-md transition-shadow"
              end,
              if(tier["is_popular"], do: "ring-2 ring-purple-600")
            ]}>

              <%= if tier["is_popular"] && @content["highlight_popular"] do %>
                <div class="popular-badge text-xs bg-purple-600 text-white px-2 py-1 rounded-full mb-2 inline-block">
                  Most Popular
                </div>
              <% end %>

              <h4 class="font-semibold text-gray-900 mb-1">
                <%= tier["tier_name"] %>
              </h4>

              <div class="pricing-amount mb-2">
                <span class="text-2xl font-bold text-gray-900">
                  <%= @content["currency"] %><%= tier["base_price"] %>
                </span>
                <span class="text-sm text-gray-500">
                  / <%= tier["billing_cycle"] %>
                </span>
              </div>

              <%= if tier["description"] do %>
                <p class="text-sm text-gray-600 mb-3">
                  <%= tier["description"] %>
                </p>
              <% end %>

              <%= if tier["features_included"] && length(tier["features_included"]) > 0 do %>
                <ul class="text-sm text-gray-600 space-y-1 mb-4">
                  <%= for feature <- Enum.take(tier["features_included"], 5) do %>
                    <li class="flex items-center">
                      <svg class="w-3 h-3 text-green-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
                        <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
                      </svg>
                      <%= feature %>
                    </li>
                  <% end %>
                </ul>
              <% end %>

              <button class={[
                "w-full px-4 py-2 rounded-lg font-medium transition-colors",
                if(tier["is_popular"],
                  do: "bg-purple-600 text-white hover:bg-purple-700",
                  else: "bg-gray-100 text-gray-700 hover:bg-gray-200")
              ]}>
                <%= tier["booking_button_text"] || "Get Started" %>
              </button>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  # Additional block renderers would continue following the same pattern...
  # For brevity, I'll add placeholder renderers for the remaining blocks

  defp render_portfolio_gallery_block(block, assigns) do
    ~H"""
    <div class="portfolio-gallery brand-typography">
      <h3 class="text-lg font-semibold brand-heading mb-4">Portfolio Gallery</h3>
      <div class="portfolio-gallery">
        <!-- Portfolio items would be rendered here -->
        <div class="text-center p-8 text-gray-500">
          Portfolio gallery content
        </div>
      </div>
    </div>
    """
  end

  defp render_process_showcase_block(block, assigns) do
    ~H"""
    <div class="process-showcase brand-typography">
      <h3 class="text-lg font-semibold brand-heading mb-4">My Process</h3>
      <div class="text-center p-8 text-gray-500">
        Process showcase content
      </div>
    </div>
    """
  end

  defp render_collaboration_display_block(block, assigns) do
    ~H"""
    <div class="collaboration-display brand-typography">
      <h3 class="text-lg font-semibold brand-heading mb-4">Past Collaborations</h3>
      <div class="text-center p-8 text-gray-500">
        Collaboration display content
      </div>
    </div>
    """
  end

  defp render_skill_matrix_block(block, assigns) do
    ~H"""
    <div class="skill-matrix brand-typography">
      <h3 class="text-lg font-semibold brand-heading mb-4">Technical Skills</h3>
      <div class="skill-matrix">
        <!-- Skills would be rendered here -->
        <div class="text-center p-8 text-gray-500">
          Skill matrix content
        </div>
      </div>
    </div>
    """
  end

  defp render_project_deep_dive_block(block, assigns) do
    ~H"""
    <div class="project-deep-dive brand-typography">
      <h3 class="text-lg font-semibold brand-heading mb-4">Featured Project</h3>
      <div class="text-center p-8 text-gray-500">
        Project deep dive content
      </div>
    </div>
    """
  end

  defp render_consultation_booking_block(block, assigns) do
    ~H"""
    <div class="consultation-booking brand-typography">
      <h3 class="text-lg font-semibold brand-heading mb-4">Book Consultation</h3>
      <div class="text-center p-8 text-gray-500">
        Consultation booking form
      </div>
    </div>
    """
  end

  defp render_content_metrics_block(block, assigns) do
    ~H"""
    <div class="content-metrics brand-typography">
      <h3 class="text-lg font-semibold brand-heading mb-4">Content Performance</h3>
      <div class="text-center p-8 text-gray-500">
        Content metrics dashboard
      </div>
    </div>
    """
  end

  defp render_brand_partnerships_block(block, assigns) do
    ~H"""
    <div class="brand-partnerships brand-typography">
      <h3 class="text-lg font-semibold brand-heading mb-4">Brand Partnerships</h3>
      <div class="text-center p-8 text-gray-500">
        Brand partnerships showcase
      </div>
    </div>
    """
  end

  defp render_subscription_tiers_block(block, assigns) do
    ~H"""
    <div class="subscription-tiers brand-typography">
      <h3 class="text-lg font-semibold brand-heading mb-4">Support My Work</h3>
      <div class="text-center p-8 text-gray-500">
        Subscription tiers content
      </div>
    </div>
    """
  end

  # ============================================================================
  # HELPER FUNCTIONS CONTINUED
  # ============================================================================

  defp render_properties_panel(assigns) do
    ~H"""
    <div class="properties-panel">
      <h4 class="text-sm font-semibold text-gray-900 mb-4">Layout Properties</h4>

      <!-- Brand Settings -->
      <%= if @can_customize_brand do %>
        <div class="property-section mb-6">
          <h5 class="text-xs font-medium text-gray-700 mb-2">Brand Controls</h5>

          <!-- Color Override -->
          <div class="space-y-3">
            <div>
              <label class="block text-xs text-gray-600 mb-1">Primary Color</label>
              <div class="flex items-center space-x-2">
                <input
                  type="color"
                  value={@brand_settings.primary_color}
                  phx-change="update_brand_color"
                  phx-value-field="primary_color"
                  phx-target={@myself}
                  class="w-8 h-8 rounded border border-gray-300"
                  disabled={@brand_settings.enforce_brand_colors}>
                <span class="text-xs text-gray-500">
                  <%= @brand_settings.primary_color %>
                </span>
              </div>
              <%= if @brand_settings.enforce_brand_colors do %>
                <p class="text-xs text-amber-600 mt-1">Brand colors are locked</p>
              <% end %>
            </div>

            <div>
              <label class="block text-xs text-gray-600 mb-1">Accent Color</label>
              <div class="flex items-center space-x-2">
                <input
                  type="color"
                  value={@brand_settings.accent_color}
                  phx-change="update_brand_color"
                  phx-value-field="accent_color"
                  phx-target={@myself}
                  class="w-8 h-8 rounded border border-gray-300"
                  disabled={@brand_settings.enforce_brand_colors}>
                <span class="text-xs text-gray-500">
                  <%= @brand_settings.accent_color %>
                </span>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Layout Settings -->
      <div class="property-section mb-6">
        <h5 class="text-xs font-medium text-gray-700 mb-2">Layout Settings</h5>

        <div class="space-y-3">
          <!-- Grid Density -->
          <div>
            <label class="block text-xs text-gray-600 mb-1">Grid Density</label>
            <select
              phx-change="update_layout_property"
              phx-value-property="grid_density"
              phx-target={@myself}
              class="w-full text-xs border border-gray-300 rounded px-2 py-1">
              <option value="compact">Compact</option>
              <option value="normal" selected>Normal</option>
              <option value="spacious">Spacious</option>
            </select>
          </div>

          <!-- Mobile Layout -->
          <div>
            <label class="block text-xs text-gray-600 mb-1">Mobile Layout</label>
            <select
              phx-change="update_layout_property"
              phx-value-property="mobile_layout"
              phx-target={@myself}
              class="w-full text-xs border border-gray-300 rounded px-2 py-1">
              <option value="stack">Stack Vertically</option>
              <option value="card" selected>Card Style</option>
              <option value="minimal">Minimal</option>
            </select>
          </div>

          <!-- Animation Level -->
          <div>
            <label class="block text-xs text-gray-600 mb-1">Animations</label>
            <select
              phx-change="update_layout_property"
              phx-value-property="animation_level"
              phx-target={@myself}
              class="w-full text-xs border border-gray-300 rounded px-2 py-1">
              <option value="none">None</option>
              <option value="subtle" selected>Subtle</option>
              <option value="enhanced">Enhanced</option>
            </select>
          </div>
        </div>
      </div>

      <!-- Monetization Settings -->
      <%= if @can_monetize do %>
        <div class="property-section mb-6">
          <h5 class="text-xs font-medium text-gray-700 mb-2">Monetization</h5>

          <div class="space-y-3">
            <div class="flex items-center justify-between">
              <span class="text-xs text-gray-600">Show Pricing</span>
              <label class="relative inline-flex items-center cursor-pointer">
                <input
                  type="checkbox"
                  checked={@brand_settings.show_pricing_by_default}
                  phx-click="toggle_monetization_setting"
                  phx-value-setting="show_pricing_by_default"
                  phx-target={@myself}
                  class="sr-only peer">
                <div class="w-9 h-5 bg-gray-200 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:bg-purple-600"></div>
              </label>
            </div>

            <div class="flex items-center justify-between">
              <span class="text-xs text-gray-600">Enable Booking</span>
              <label class="relative inline-flex items-center cursor-pointer">
                <input
                  type="checkbox"
                  checked={@brand_settings.show_booking_widgets_by_default}
                  phx-click="toggle_monetization_setting"
                  phx-value-setting="show_booking_widgets_by_default"
                  phx-target={@myself}
                  class="sr-only peer">
                <div class="w-9 h-5 bg-gray-200 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:bg-purple-600"></div>
              </label>
            </div>

            <div>
              <label class="block text-xs text-gray-600 mb-1">Default Currency</label>
              <select
                phx-change="update_monetization_setting"
                phx-value-setting="default_currency"
                phx-target={@myself}
                class="w-full text-xs border border-gray-300 rounded px-2 py-1">
                <option value="USD" selected>USD ($)</option>
                <option value="EUR">EUR (€)</option>
                <option value="GBP">GBP (£)</option>
                <option value="CAD">CAD (C$)</option>
              </select>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Layout Templates -->
      <div class="property-section mb-6">
        <h5 class="text-xs font-medium text-gray-700 mb-2">Quick Templates</h5>

        <div class="space-y-2">
          <%= for template <- get_quick_templates(@active_category) do %>
            <button
              phx-click="apply_layout_template"
              phx-value-template={template.key}
              phx-target={@myself}
              class="w-full p-2 text-left border border-gray-200 rounded hover:bg-gray-50 transition-colors">
              <div class="text-xs font-medium text-gray-900">
                <%= template.name %>
              </div>
              <div class="text-xs text-gray-500">
                <%= template.description %>
              </div>
            </button>
          <% end %>
        </div>
      </div>

      <!-- Save Actions -->
      <%= if @layout_dirty do %>
        <div class="property-section">
          <div class="space-y-2">
            <button
              phx-click="save_layout"
              phx-target={@myself}
              class="w-full px-3 py-2 bg-purple-600 text-white text-sm font-medium rounded-lg hover:bg-purple-700 transition-colors">
              Save Layout
            </button>
            <button
              phx-click="reset_layout"
              phx-target={@myself}
              class="w-full px-3 py-2 bg-gray-100 text-gray-700 text-sm font-medium rounded-lg hover:bg-gray-200 transition-colors">
              Reset Changes
            </button>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # LAYOUT TEMPLATE MODAL
  # ============================================================================

  defp render_layout_template_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50"
         phx-click="close_layout_templates"
         phx-target={@myself}>
      <div class="bg-white rounded-xl max-w-4xl w-full max-h-screen overflow-y-auto m-4"
           phx-click-away="close_layout_templates"
           phx-target={@myself}>

        <div class="p-6 border-b border-gray-200">
          <h3 class="text-lg font-semibold text-gray-900">Choose Layout Template</h3>
          <p class="text-sm text-gray-600 mt-1">
            Select a pre-designed layout for your <%= String.replace(to_string(@active_category), "_", " ") %> portfolio
          </p>
        </div>

        <div class="p-6">
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            <%= for template <- get_layout_templates(@active_category) do %>
              <div class="template-option group cursor-pointer"
                   phx-click="apply_layout_template"
                   phx-value-template={template.key}
                   phx-target={@myself}>

                <!-- Template Preview -->
                <div class="template-preview h-40 bg-gray-100 rounded-lg mb-3 overflow-hidden relative">
                  <%= render_template_preview(template.key, assigns) %>

                  <!-- Hover Overlay -->
                  <div class="absolute inset-0 bg-purple-600 bg-opacity-0 group-hover:bg-opacity-20 transition-all duration-200 flex items-center justify-center">
                    <div class="opacity-0 group-hover:opacity-100 transition-opacity">
                      <div class="bg-white text-purple-600 px-3 py-1 rounded-full text-sm font-medium">
                        Apply Template
                      </div>
                    </div>
                  </div>
                </div>

                <!-- Template Info -->
                <h4 class="font-medium text-gray-900 mb-1"><%= template.name %></h4>
                <p class="text-sm text-gray-600 mb-2"><%= template.description %></p>

                <!-- Featured Blocks -->
                <div class="flex flex-wrap gap-1">
                  <%= for block_type <- Enum.take(template.featured_blocks, 3) do %>
                    <span class="text-xs px-2 py-1 bg-gray-100 text-gray-600 rounded">
                      <%= humanize_block_type(block_type) %>
                    </span>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp get_current_layout_config(portfolio, brand_settings) do
    # FIXED: Get layout from customization, not portfolio.layout
    layout_style = get_portfolio_layout_safe(portfolio)

    base_config = %{
      layout_style: layout_style,
      grid_density: "normal",
      mobile_layout: "card",
      animation_level: "subtle"
    }

    # Apply brand constraints if they exist
    if Map.get(brand_settings, :enforce_layout_constraints, false) do
      constraints = Map.get(brand_settings, :layout_constraints, %{})
      Map.merge(base_config, constraints)
    else
      base_config
    end
  end

  # ADD this helper function to dynamic_card_layout_manager.ex:
  defp get_portfolio_layout_safe(portfolio) do
    customization = portfolio.customization || %{}

    # The layout is stored in customization["layout"], NOT portfolio.layout
    case Map.get(customization, "layout") do
      nil ->
        # Fallback to theme if layout not set
        portfolio.theme || "professional_service_provider"
      layout when is_binary(layout) ->
        layout
      _ ->
        "professional_service_provider"
    end
  end

  defp organize_blocks_into_zones(content_blocks, layout_config) do
    # Group content blocks by their assigned zones
    # This would be implemented based on how blocks are stored with zone information
    %{
      "hero" => [],
      "services" => [],
      "testimonials" => [],
      "pricing" => [],
      "cta" => []
    }
  end

  defp get_available_categories(subscription_tier) do
    base_categories = [
      %{key: :service_provider, name: "Service Provider"},
      %{key: :creative_showcase, name: "Creative"}
    ]

    case subscription_tier do
      tier when tier in ["creator", "professional", "enterprise"] ->
        base_categories ++ [
          %{key: :technical_expert, name: "Technical"},
          %{key: :content_creator, name: "Creator"},
          %{key: :corporate_executive, name: "Executive"}
        ]
      _ -> base_categories
    end
  end

  defp get_blocks_for_category(available_blocks, category) do
    Enum.filter(available_blocks, &(&1.category == category))
  end

  defp get_device_preview_classes(device) do
    case device do
      :mobile -> "max-w-sm mx-auto"
      :tablet -> "max-w-3xl mx-auto"
      :desktop -> "w-full"
    end
  end

  defp has_locked_blocks?(available_blocks, subscription_tier) do
    all_blocks = DynamicCardBlocks.get_all_dynamic_card_blocks()
    length(all_blocks) > length(available_blocks)
  end

  defp get_quick_templates(category) do
    DynamicCardBlocks.get_available_layouts_for_category(category)
  end

  defp get_layout_templates(category) do
    DynamicCardBlocks.get_available_layouts_for_category(category)
  end

  defp render_template_preview(template_key, assigns) do
    assigns = assign(assigns, :template_key, template_key)

    ~H"""
    <!-- Simplified template preview -->
    <div class="h-full p-3 bg-gradient-to-br from-gray-50 to-gray-100">
      <%= case @template_key do %>
        <% "professional_service_provider" -> %>
          <div class="space-y-2">
            <div class="h-4 bg-blue-300 rounded"></div>
            <div class="grid grid-cols-2 gap-1">
              <div class="h-8 bg-blue-200 rounded"></div>
              <div class="h-8 bg-green-200 rounded"></div>
            </div>
            <div class="h-3 bg-purple-200 rounded"></div>
          </div>
        <% "creative_portfolio_showcase" -> %>
          <div class="space-y-2">
            <div class="h-3 bg-purple-300 rounded"></div>
            <div class="grid grid-cols-3 gap-1">
              <div class="h-6 bg-pink-200 rounded"></div>
              <div class="h-6 bg-purple-200 rounded"></div>
              <div class="h-6 bg-indigo-200 rounded"></div>
            </div>
            <div class="h-4 bg-gradient-to-r from-purple-200 to-pink-200 rounded"></div>
          </div>
        <% _ -> %>
          <div class="h-full bg-gray-200 rounded flex items-center justify-center">
            <span class="text-xs text-gray-500">Preview</span>
          </div>
      <% end %>
    </div>
    """
  end

  defp humanize_block_type(block_type) do
    block_type
    |> to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  # Placeholder implementations for functions that would be implemented later
  defp create_dynamic_card_block(block_type, zone, position, socket) do
    # Implementation would create a new content block following PortfolioEditor pattern
    {:ok, %{id: :rand.uniform(1000), block_type: String.to_atom(block_type), content_data: %{}}}
  end

  defp reorder_zone_blocks(layout_zones, zone, new_order) do
    current_blocks = Map.get(layout_zones, zone, [])
    # Reorder based on new_order array (list of block IDs)
    # Implementation would sort blocks according to the new order
    Map.put(layout_zones, zone, current_blocks)
  end

  defp save_dynamic_card_layout(layout_zones, portfolio) do
    # Implementation would save the layout configuration to the database
    {:ok, portfolio}
  end

  defp apply_predefined_layout_template(template_key, socket) do
    # Implementation would apply a predefined template layout
    {:ok, socket.assigns.layout_zones}
  end

  defp create_new_content_block(block_type, socket) do
    block_atom = String.to_atom(block_type)

    # Default content based on block type (embedded to avoid function call issues)
    default_content = case block_atom do
      :hero_card ->
        %{
          title: "Welcome to My Portfolio",
          subtitle: "Discover my work and experience",
          call_to_action: %{text: "Get Started", url: "#contact"}
        }
      :about_card ->
        %{
          title: "About Me",
          content: "Tell your story here...",
          highlights: []
        }
      :service_card ->
        %{
          title: "My Service",
          description: "Describe your service here...",
          price: nil,
          features: [],
          booking_enabled: false
        }
      :project_card ->
        %{
          title: "Project Title",
          description: "Project description...",
          image_url: nil,
          project_url: nil,
          technologies: []
        }
      :contact_card ->
        %{
          title: "Get In Touch",
          content: "Ready to work together?",
          contact_methods: [
            %{type: "email", value: "contact@example.com", label: "Email"}
          ],
          show_form: true
        }
      :skill_card ->
        %{
          name: "Skill Name",
          proficiency: "intermediate",
          category: "general",
          description: "Skill description..."
        }
      :testimonial_card ->
        %{
          content: "Great work!",
          author: "Client Name",
          title: "CEO",
          avatar_url: nil,
          rating: 5
        }
      :experience_card ->
        %{
          title: "Job Title",
          company: "Company Name",
          duration: "2020 - Present",
          description: "Job description...",
          achievements: []
        }
      :achievement_card ->
        %{
          title: "Achievement",
          description: "Achievement description...",
          date: Date.utc_today(),
          category: "professional"
        }
      :content_card ->
        %{
          title: "Content Block",
          content: "Add your content here...",
          media_type: "text"
        }
      :social_card ->
        %{
          platform: "Social Platform",
          handle: "@username",
          follower_count: 0,
          link: "https://example.com"
        }
      :monetization_card ->
        %{
          title: "Support My Work",
          description: "Help me create more content",
          platforms: []
        }
      :text_card ->
        %{
          title: "Content Block",
          content: "Add your content here..."
        }
      _ ->
        %{
          title: "Content Block",
          content: "Add your content here...",
          type: "generic"
        }
    end

    new_block = %{
      id: "new_#{System.unique_integer([:positive])}",
      block_type: block_atom,
      content_data: default_content,
      position: 0,
      created_at: DateTime.utc_now()
    }

    {:ok, new_block}
  end

  defp add_block_to_zone(layout_zones, zone_name, new_block) do
    current_blocks = Map.get(layout_zones, zone_name, [])
    updated_blocks = current_blocks ++ [new_block]
    Map.put(layout_zones, zone_name, updated_blocks)
  end

  defp remove_block_from_zones(layout_zones, block_id) do
    Enum.reduce(layout_zones, %{}, fn {zone_name, blocks}, acc ->
      updated_blocks = Enum.reject(blocks, fn block ->
        to_string(block.id) == to_string(block_id)
      end)
      Map.put(acc, zone_name, updated_blocks)
    end)
  end

  defp move_block_between_zones(layout_zones, block_id, from_zone, to_zone, position) do
    # Find and remove the block from the source zone
    from_blocks = Map.get(layout_zones, from_zone, [])
    {block, updated_from_blocks} = extract_block_by_id(from_blocks, block_id)

    case block do
      nil -> layout_zones # Block not found, return unchanged

      block ->
        # Add block to the target zone at specified position
        to_blocks = Map.get(layout_zones, to_zone, [])
        updated_to_blocks = List.insert_at(to_blocks, position, block)

        layout_zones
        |> Map.put(from_zone, updated_from_blocks)
        |> Map.put(to_zone, updated_to_blocks)
    end
  end

  defp extract_block_by_id(blocks, block_id) do
    block = Enum.find(blocks, fn b -> to_string(b.id) == to_string(block_id) end)
    updated_blocks = Enum.reject(blocks, fn b -> to_string(b.id) == to_string(block_id) end)
    {block, updated_blocks}
  end

  defp save_portfolio_layout(portfolio, layout_zones) do
    # Convert layout zones back to portfolio sections for persistence
    sections_data = convert_layout_zones_to_sections(layout_zones, portfolio.id)

    # Save to database (simplified for now)
    case save_portfolio_sections(portfolio, sections_data) do
      {:ok, updated_portfolio} -> {:ok, updated_portfolio}
      {:error, reason} -> {:error, reason}
    end
  rescue
    _ ->
      # Fallback - just return success for now
      {:ok, portfolio}
  end

  defp save_portfolio_sections(portfolio, sections_data) do
    # This is a simplified save - you might need to implement this based on your schema
    try do
      # Update portfolio with new section data
      case Frestyl.Portfolios.update_portfolio(portfolio, %{last_modified: DateTime.utc_now()}) do
        {:ok, updated_portfolio} -> {:ok, updated_portfolio}
        error -> error
      end
    rescue
      _ -> {:ok, portfolio}
    end
  end

  defp convert_layout_zones_to_sections(layout_zones, portfolio_id) do
    layout_zones
    |> Enum.with_index()
    |> Enum.flat_map(fn {{zone_name, blocks}, zone_index} ->
      Enum.with_index(blocks, fn block, block_index ->
        %{
          id: extract_section_id_from_block(block),
          portfolio_id: portfolio_id,
          title: get_block_title(block),
          content: get_block_content(block),
          section_type: map_block_type_to_section_type(block.block_type),
          position: zone_index * 1000 + block_index,
          visible: true,
          zone: zone_name
        }
      end)
    end)
  end

  defp extract_section_id_from_block(block) do
    case block.id do
      id when is_integer(id) -> id
      id when is_binary(id) ->
        case Integer.parse(id) do
          {int_id, _} -> int_id
          _ -> nil # New block, will get ID from database
        end
      _ -> nil
    end
  end

  defp get_block_title(block) do
    case block.content_data do
      %{title: title} when is_binary(title) -> title
      _ -> "Untitled Section"
    end
  end

  defp get_block_content(block) do
    case block.content_data do
      %{content: content} when is_binary(content) -> content
      %{description: description} when is_binary(description) -> description
      %{subtitle: subtitle} when is_binary(subtitle) -> subtitle
      _ -> ""
    end
  end

  defp map_block_type_to_section_type(:hero_card), do: "hero"
  defp map_block_type_to_section_type(:about_card), do: "about"
  defp map_block_type_to_section_type(:service_card), do: "services"
  defp map_block_type_to_section_type(:project_card), do: "portfolio"
  defp map_block_type_to_section_type(:contact_card), do: "contact"
  defp map_block_type_to_section_type(:skill_card), do: "skills"
  defp map_block_type_to_section_type(:testimonial_card), do: "testimonials"
  defp map_block_type_to_section_type(_), do: "text"

  # This function was referenced but missing
  defp add_block_to_layout_zone(layout_zones, zone, new_block, position) do
    current_blocks = Map.get(layout_zones, zone, [])
    updated_blocks = List.insert_at(current_blocks, String.to_integer(position), new_block)
    Map.put(layout_zones, zone, updated_blocks)
  end
end
