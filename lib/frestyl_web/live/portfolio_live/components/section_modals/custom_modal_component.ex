# lib/frestyl_web/live/portfolio_live/components/section_modals/custom_modal_component.ex
defmodule FrestylWeb.PortfolioLive.Components.CustomModalComponent do
  @moduledoc """
  Specialized modal for editing custom sections - flexible content builder with layout options
  """
  use FrestylWeb, :live_component
  alias FrestylWeb.PortfolioLive.Components.BaseSectionModalComponent

  def update(assigns, socket) do
    content = get_section_content(assigns.editing_section)

    socket = socket
    |> assign(assigns)
    |> assign(:content, content)
    |> assign(:modal_title, "Edit Custom Section")
    |> assign(:modal_description, "Create flexible content with custom layouts and styling")
    |> assign(:section_type, :custom)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <.live_component
      module={BaseSectionModalComponent}
      id="custom-modal"
      editing_section={@editing_section}
      modal_title={@modal_title}
      modal_description={@modal_description}
      section_type={@section_type}
      myself={@myself}>

      <!-- Custom Section Specific Fields -->
      <div class="space-y-6">

        <!-- Content Type Selection -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Content Type</label>
          <select
            name="content_type"
            class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
            <option value="text" selected={get_content_type(@content) == "text"}>Rich Text</option>
            <option value="text_image" selected={get_content_type(@content) == "text_image"}>Text + Image</option>
            <option value="media_gallery" selected={get_content_type(@content) == "media_gallery"}>Media Gallery</option>
            <option value="video_embed" selected={get_content_type(@content) == "video_embed"}>Video Embed</option>
            <option value="code_block" selected={get_content_type(@content) == "code_block"}>Code Block</option>
            <option value="quote_callout" selected={get_content_type(@content) == "quote_callout"}>Quote/Callout</option>
            <option value="stats_cards" selected={get_content_type(@content) == "stats_cards"}>Stats Cards</option>
            <option value="timeline" selected={get_content_type(@content) == "timeline"}>Timeline</option>
            <option value="mixed_content" selected={get_content_type(@content) == "mixed_content"}>Mixed Content</option>
          </select>
        </div>

        <!-- Primary Content -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Primary Content</label>
          <textarea
            name="content"
            rows="6"
            class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            placeholder="Enter your custom content here. Supports HTML, Markdown, or plain text..."><%= Map.get(@content, "content", "") %></textarea>
          <p class="text-sm text-gray-500 mt-1">Supports HTML, Markdown formatting, and custom styling</p>
        </div>

        <!-- Layout Configuration -->
        <div class="border rounded-lg p-4 bg-gray-50">
          <h4 class="font-medium text-gray-900 mb-4">Layout Configuration</h4>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
            <div>
              <label class="block text-xs font-medium text-gray-700 mb-1">Layout Template</label>
              <select
                name="layout_template"
                class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500">
                <option value="single_column" selected={get_layout_template(@content) == "single_column"}>Single Column</option>
                <option value="two_column" selected={get_layout_template(@content) == "two_column"}>Two Column</option>
                <option value="three_column" selected={get_layout_template(@content) == "three_column"}>Three Column</option>
                <option value="sidebar_left" selected={get_layout_template(@content) == "sidebar_left"}>Sidebar Left</option>
                <option value="sidebar_right" selected={get_layout_template(@content) == "sidebar_right"}>Sidebar Right</option>
                <option value="hero_banner" selected={get_layout_template(@content) == "hero_banner"}>Hero Banner</option>
                <option value="card_grid" selected={get_layout_template(@content) == "card_grid"}>Card Grid</option>
                <option value="full_width" selected={get_layout_template(@content) == "full_width"}>Full Width</option>
              </select>
            </div>
            <div>
              <label class="block text-xs font-medium text-gray-700 mb-1">Content Alignment</label>
              <select
                name="content_alignment"
                class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500">
                <option value="left" selected={get_content_alignment(@content) == "left"}>Left</option>
                <option value="center" selected={get_content_alignment(@content) == "center"}>Center</option>
                <option value="right" selected={get_content_alignment(@content) == "right"}>Right</option>
                <option value="justify" selected={get_content_alignment(@content) == "justify"}>Justify</option>
              </select>
            </div>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div>
              <label class="block text-xs font-medium text-gray-700 mb-1">Padding</label>
              <select
                name="padding"
                class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500">
                <option value="none" selected={get_padding(@content) == "none"}>None</option>
                <option value="small" selected={get_padding(@content) == "small"}>Small</option>
                <option value="medium" selected={get_padding(@content) == "medium"}>Medium</option>
                <option value="large" selected={get_padding(@content) == "large"}>Large</option>
              </select>
            </div>
            <div>
              <label class="block text-xs font-medium text-gray-700 mb-1">Margin</label>
              <select
                name="margin"
                class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500">
                <option value="none" selected={get_margin(@content) == "none"}>None</option>
                <option value="small" selected={get_margin(@content) == "small"}>Small</option>
                <option value="medium" selected={get_margin(@content) == "medium"}>Medium</option>
                <option value="large" selected={get_margin(@content) == "large"}>Large</option>
              </select>
            </div>
            <div>
              <label class="block text-xs font-medium text-gray-700 mb-1">Border Style</label>
              <select
                name="border_style"
                class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500">
                <option value="none" selected={get_border_style(@content) == "none"}>None</option>
                <option value="solid" selected={get_border_style(@content) == "solid"}>Solid</option>
                <option value="dashed" selected={get_border_style(@content) == "dashed"}>Dashed</option>
                <option value="rounded" selected={get_border_style(@content) == "rounded"}>Rounded</option>
                <option value="shadow" selected={get_border_style(@content) == "shadow"}>Shadow</option>
              </select>
            </div>
          </div>
        </div>

        <!-- Media Assets -->
        <div class="border rounded-lg p-4 bg-gray-50">
          <div class="flex items-center justify-between mb-4">
            <h4 class="font-medium text-gray-900">Media Assets</h4>
            <button
              type="button"
              phx-click="add_media_asset"
              phx-target={@myself}
              class="px-3 py-1 bg-purple-600 text-white text-sm rounded-md hover:bg-purple-700 transition-colors">
              + Add Media
            </button>
          </div>

          <div class="space-y-3" id="media-assets-container">
            <%= for {asset, index} <- Enum.with_index(get_media_assets(@content)) do %>
              <div class="border rounded p-3 bg-white">
                <div class="grid grid-cols-1 md:grid-cols-3 gap-3 mb-3">
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Media Type</label>
                    <select
                      name={"media_assets[#{index}][type]"}
                      class="w-full px-2 py-1 text-xs border border-gray-300 rounded focus:ring-1 focus:ring-purple-500">
                      <option value="image" selected={Map.get(asset, "type") == "image"}>Image</option>
                      <option value="video" selected={Map.get(asset, "type") == "video"}>Video</option>
                      <option value="audio" selected={Map.get(asset, "type") == "audio"}>Audio</option>
                      <option value="document" selected={Map.get(asset, "type") == "document"}>Document</option>
                      <option value="embed" selected={Map.get(asset, "type") == "embed"}>Embed Code</option>
                    </select>
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Position</label>
                    <select
                      name={"media_assets[#{index}][position]"}
                      class="w-full px-2 py-1 text-xs border border-gray-300 rounded focus:ring-1 focus:ring-purple-500">
                      <option value="top" selected={Map.get(asset, "position") == "top"}>Top</option>
                      <option value="bottom" selected={Map.get(asset, "position") == "bottom"}>Bottom</option>
                      <option value="left" selected={Map.get(asset, "position") == "left"}>Left</option>
                      <option value="right" selected={Map.get(asset, "position") == "right"}>Right</option>
                      <option value="center" selected={Map.get(asset, "position") == "center"}>Center</option>
                      <option value="background" selected={Map.get(asset, "position") == "background"}>Background</option>
                    </select>
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Size</label>
                    <select
                      name={"media_assets[#{index}][size]"}
                      class="w-full px-2 py-1 text-xs border border-gray-300 rounded focus:ring-1 focus:ring-purple-500">
                      <option value="small" selected={Map.get(asset, "size") == "small"}>Small</option>
                      <option value="medium" selected={Map.get(asset, "size") == "medium"}>Medium</option>
                      <option value="large" selected={Map.get(asset, "size") == "large"}>Large</option>
                      <option value="full" selected={Map.get(asset, "size") == "full"}>Full Width</option>
                    </select>
                  </div>
                </div>

                <div class="grid grid-cols-1 md:grid-cols-2 gap-3 mb-3">
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">URL/Source</label>
                    <input
                      type="url"
                      name={"media_assets[#{index}][url]"}
                      value={Map.get(asset, "url", "")}
                      placeholder="https://example.com/media.jpg"
                      class="w-full px-2 py-1 text-xs border border-gray-300 rounded focus:ring-1 focus:ring-purple-500" />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Alt Text/Caption</label>
                    <input
                      type="text"
                      name={"media_assets[#{index}][alt_text]"}
                      value={Map.get(asset, "alt_text", "")}
                      placeholder="Descriptive text"
                      class="w-full px-2 py-1 text-xs border border-gray-300 rounded focus:ring-1 focus:ring-purple-500" />
                  </div>
                </div>

                <div class="flex justify-end">
                  <button
                    type="button"
                    phx-click="remove_media_asset"
                    phx-target={@myself}
                    phx-value-index={index}
                    class="text-xs text-red-600 hover:text-red-800">
                    Remove
                  </button>
                </div>
              </div>
            <% end %>

            <%= if Enum.empty?(get_media_assets(@content)) do %>
              <div class="text-center py-4 text-gray-500 text-sm">
                No media assets added yet. Click "Add Media" to include images, videos, or embeds.
              </div>
            <% end %>
          </div>
        </div>

        <!-- Custom Styling -->
        <div class="border rounded-lg p-4 bg-gray-50">
          <h4 class="font-medium text-gray-900 mb-4">Custom Styling</h4>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
            <div>
              <label class="block text-xs font-medium text-gray-700 mb-1">Background Color</label>
              <div class="flex space-x-2">
                <input
                  type="color"
                  name="background_color"
                  value={Map.get(@content, "background_color", "#ffffff")}
                  class="w-12 h-8 border border-gray-300 rounded" />
                <input
                  type="text"
                  name="background_color_hex"
                  value={Map.get(@content, "background_color", "#ffffff")}
                  placeholder="#ffffff"
                  class="flex-1 px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
              </div>
            </div>
            <div>
              <label class="block text-xs font-medium text-gray-700 mb-1">Text Color</label>
              <div class="flex space-x-2">
                <input
                  type="color"
                  name="text_color"
                  value={Map.get(@content, "text_color", "#000000")}
                  class="w-12 h-8 border border-gray-300 rounded" />
                <input
                  type="text"
                  name="text_color_hex"
                  value={Map.get(@content, "text_color", "#000000")}
                  placeholder="#000000"
                  class="flex-1 px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
              </div>
            </div>
          </div>

          <div class="mb-4">
            <label class="block text-xs font-medium text-gray-700 mb-1">Custom CSS Classes</label>
            <input
              type="text"
              name="css_classes"
              value={Map.get(@content, "css_classes", "")}
              placeholder="custom-class another-class"
              class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
            <p class="text-xs text-gray-500 mt-1">Space-separated CSS classes</p>
          </div>

          <div>
            <label class="block text-xs font-medium text-gray-700 mb-1">Custom CSS (Advanced)</label>
            <textarea
              name="custom_css"
              rows="4"
              class="w-full px-2 py-1 text-sm font-mono border border-gray-300 rounded focus:ring-1 focus:ring-blue-500"
              placeholder=".custom-section {
              background: linear-gradient(45deg, #f0f0f0, #e0e0e0);
              border-radius: 8px;
              }"
            >
          <%= Map.get(@content, "custom_css", "") %></textarea>
            <p class="text-xs text-gray-500 mt-1">Advanced: Add custom CSS for this section</p>
          </div>
        </div>

        <!-- Interactive Elements -->
        <div class="border rounded-lg p-4 bg-gray-50">
          <div class="flex items-center justify-between mb-4">
            <h4 class="font-medium text-gray-900">Interactive Elements</h4>
            <button
              type="button"
              phx-click="add_interactive_element"
              phx-target={@myself}
              class="px-3 py-1 bg-green-600 text-white text-sm rounded-md hover:bg-green-700 transition-colors">
              + Add Element
            </button>
          </div>

          <div class="space-y-3" id="interactive-elements-container">
            <%= for {element, index} <- Enum.with_index(get_interactive_elements(@content)) do %>
              <div class="border rounded p-3 bg-white">
                <div class="grid grid-cols-1 md:grid-cols-2 gap-3 mb-3">
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Element Type</label>
                    <select
                      name={"interactive_elements[#{index}][type]"}
                      class="w-full px-2 py-1 text-xs border border-gray-300 rounded focus:ring-1 focus:ring-green-500">
                      <option value="button" selected={Map.get(element, "type") == "button"}>Button</option>
                      <option value="link" selected={Map.get(element, "type") == "link"}>Link</option>
                      <option value="form" selected={Map.get(element, "type") == "form"}>Form</option>
                      <option value="modal_trigger" selected={Map.get(element, "type") == "modal_trigger"}>Modal Trigger</option>
                      <option value="accordion" selected={Map.get(element, "type") == "accordion"}>Accordion</option>
                      <option value="tabs" selected={Map.get(element, "type") == "tabs"}>Tabs</option>
                    </select>
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Label/Text</label>
                    <input
                      type="text"
                      name={"interactive_elements[#{index}][label]"}
                      value={Map.get(element, "label", "")}
                      placeholder="Click Me, Learn More, Contact"
                      class="w-full px-2 py-1 text-xs border border-gray-300 rounded focus:ring-1 focus:ring-green-500" />
                  </div>
                </div>

                <div class="grid grid-cols-1 md:grid-cols-2 gap-3 mb-3">
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Action/URL</label>
                    <input
                      type="text"
                      name={"interactive_elements[#{index}][action]"}
                      value={Map.get(element, "action", "")}
                      placeholder="https://example.com, #contact, mailto:"
                      class="w-full px-2 py-1 text-xs border border-gray-300 rounded focus:ring-1 focus:ring-green-500" />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Style</label>
                    <select
                      name={"interactive_elements[#{index}][style]"}
                      class="w-full px-2 py-1 text-xs border border-gray-300 rounded focus:ring-1 focus:ring-green-500">
                      <option value="primary" selected={Map.get(element, "style") == "primary"}>Primary</option>
                      <option value="secondary" selected={Map.get(element, "style") == "secondary"}>Secondary</option>
                      <option value="outline" selected={Map.get(element, "style") == "outline"}>Outline</option>
                      <option value="ghost" selected={Map.get(element, "style") == "ghost"}>Ghost</option>
                      <option value="link" selected={Map.get(element, "style") == "link"}>Link Style</option>
                    </select>
                  </div>
                </div>

                <div class="flex justify-end">
                  <button
                    type="button"
                    phx-click="remove_interactive_element"
                    phx-target={@myself}
                    phx-value-index={index}
                    class="text-xs text-red-600 hover:text-red-800">
                    Remove
                  </button>
                </div>
              </div>
            <% end %>

            <%= if Enum.empty?(get_interactive_elements(@content)) do %>
              <div class="text-center py-4 text-gray-500 text-sm">
                No interactive elements added yet. Click "Add Element" to include buttons, links, or forms.
              </div>
            <% end %>
          </div>
        </div>

        <!-- Display Settings -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div class="flex items-center">
            <input
              type="checkbox"
              id="enable_animations"
              name="enable_animations"
              value="true"
              checked={Map.get(@content, "enable_animations", false)}
              class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded">
            <label for="enable_animations" class="ml-2 block text-sm text-gray-900">
              Enable animations
            </label>
          </div>
          <div class="flex items-center">
            <input
              type="checkbox"
              id="responsive_design"
              name="responsive_design"
              value="true"
              checked={Map.get(@content, "responsive_design", true)}
              class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded">
            <label for="responsive_design" class="ml-2 block text-sm text-gray-900">
              Mobile responsive
            </label>
          </div>
          <div class="flex items-center">
            <input
              type="checkbox"
              id="allow_html"
              name="allow_html"
              value="true"
              checked={Map.get(@content, "allow_html", false)}
              class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded">
            <label for="allow_html" class="ml-2 block text-sm text-gray-900">
              Allow HTML content
            </label>
          </div>
          <div class="flex items-center">
            <input
              type="checkbox"
              id="enable_markdown"
              name="enable_markdown"
              value="true"
              checked={Map.get(@content, "enable_markdown", true)}
              class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded">
            <label for="enable_markdown" class="ml-2 block text-sm text-gray-900">
              Enable Markdown formatting
            </label>
          </div>
        </div>

      </div>
    </.live_component>
    """
  end

  def handle_event("add_media_asset", _params, socket) do
    content = socket.assigns.content
    current_assets = get_media_assets(content)

    new_asset = %{
      "type" => "image",
      "position" => "center",
      "size" => "medium",
      "url" => "",
      "alt_text" => ""
    }

    updated_content = put_media_assets(content, current_assets ++ [new_asset])

    {:noreply, assign(socket, :content, updated_content)}
  end

  def handle_event("remove_media_asset", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    content = socket.assigns.content
    current_assets = get_media_assets(content)

    updated_assets = List.delete_at(current_assets, index)
    updated_content = put_media_assets(content, updated_assets)

    {:noreply, assign(socket, :content, updated_content)}
  end

  def handle_event("add_interactive_element", _params, socket) do
    content = socket.assigns.content
    current_elements = get_interactive_elements(content)

    new_element = %{
      "type" => "button",
      "label" => "",
      "action" => "",
      "style" => "primary"
    }

    updated_content = put_interactive_elements(content, current_elements ++ [new_element])

    {:noreply, assign(socket, :content, updated_content)}
  end

  def handle_event("remove_interactive_element", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    content = socket.assigns.content
    current_elements = get_interactive_elements(content)

    updated_elements = List.delete_at(current_elements, index)
    updated_content = put_interactive_elements(content, updated_elements)

    {:noreply, assign(socket, :content, updated_content)}
  end

  defp get_section_content(section) do
    case section.content do
      content when is_map(content) -> content
      content when is_binary(content) -> %{"content" => content, "content_type" => "text"}
      _ -> %{"content_type" => "text"}
    end
  end

  defp get_content_type(content), do: Map.get(content, "content_type", "text")
  defp get_layout_template(content), do: Map.get(content, "layout_template", "single_column")
  defp get_content_alignment(content), do: Map.get(content, "content_alignment", "left")
  defp get_padding(content), do: Map.get(content, "padding", "medium")
  defp get_margin(content), do: Map.get(content, "margin", "medium")
  defp get_border_style(content), do: Map.get(content, "border_style", "none")

  defp get_media_assets(content), do: Map.get(content, "media_assets", [])
  defp put_media_assets(content, assets), do: Map.put(content, "media_assets", assets)

  defp get_interactive_elements(content), do: Map.get(content, "interactive_elements", [])
  defp put_interactive_elements(content, elements), do: Map.put(content, "interactive_elements", elements)
end
