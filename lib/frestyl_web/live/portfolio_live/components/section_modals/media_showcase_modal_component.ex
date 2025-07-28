# lib/frestyl_web/live/portfolio_live/components/section_modals/media_showcase_modal_component.ex
defmodule FrestylWeb.PortfolioLive.Components.MediaShowcaseModalComponent do
  @moduledoc """
  Specialized modal for editing media showcase sections - galleries, portfolios, visual work
  """
  use FrestylWeb, :live_component
  alias FrestylWeb.PortfolioLive.Components.BaseSectionModalComponent

  def update(assigns, socket) do
    content = get_section_content(assigns.editing_section)

    socket = socket
    |> assign(assigns)
    |> assign(:content, content)
    |> assign(:modal_title, "Edit Media Showcase")
    |> assign(:modal_description, "Curate your visual portfolio and media gallery")
    |> assign(:section_type, :media_showcase)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <.live_component
      module={BaseSectionModalComponent}
      id="media-showcase-modal"
      editing_section={@editing_section}
      modal_title={@modal_title}
      modal_description={@modal_description}
      section_type={@section_type}
      myself={@myself}>

      <!-- Media Showcase Specific Fields -->
      <div class="space-y-6">

        <!-- Section Description -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Gallery Description</label>
          <textarea
            name="description"
            rows="3"
            class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            placeholder="Describe your visual work and artistic approach..."><%= Map.get(@content, "description", "") %></textarea>
        </div>

        <!-- Gallery Settings -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Gallery Type</label>
            <select
              name="gallery_type"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
              <option value="masonry" selected={get_gallery_type(@content) == "masonry"}>Masonry Grid</option>
              <option value="grid" selected={get_gallery_type(@content) == "grid"}>Uniform Grid</option>
              <option value="carousel" selected={get_gallery_type(@content) == "carousel"}>Carousel</option>
              <option value="slideshow" selected={get_gallery_type(@content) == "slideshow"}>Slideshow</option>
              <option value="featured" selected={get_gallery_type(@content) == "featured"}>Featured + Grid</option>
            </select>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Items Per Row</label>
            <select
              name="items_per_row"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
              <option value="2" selected={get_items_per_row(@content) == 2}>2 Items</option>
              <option value="3" selected={get_items_per_row(@content) == 3}>3 Items</option>
              <option value="4" selected={get_items_per_row(@content) == 4}>4 Items</option>
              <option value="5" selected={get_items_per_row(@content) == 5}>5 Items</option>
            </select>
          </div>
        </div>

        <!-- Media Categories -->
        <div class="border rounded-lg p-4 bg-gray-50">
          <div class="flex items-center justify-between mb-4">
            <h4 class="font-medium text-gray-900">Media Categories</h4>
            <button
              type="button"
              phx-click="add_media_category"
              phx-target={@myself}
              class="px-3 py-1 bg-purple-600 text-white text-sm rounded-md hover:bg-purple-700 transition-colors">
              + Add Category
            </button>
          </div>

          <div class="space-y-4" id="media-categories-container">
            <%= for {category_name, category_items} <- get_media_categories(@content) do %>
              <div class="border rounded-lg p-4 bg-white relative">
                <!-- Remove button -->
                <button
                  type="button"
                  phx-click="remove_media_category"
                  phx-target={@myself}
                  phx-value-category={category_name}
                  class="absolute top-2 right-2 p-1 text-red-500 hover:text-red-700">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                  </svg>
                </button>

                <!-- Category name -->
                <div class="mb-4">
                  <label class="block text-xs font-medium text-gray-700 mb-1">Category Name</label>
                  <input
                    type="text"
                    name={"media_categories[#{category_name}][name]"}
                    value={category_name}
                    placeholder="Photography, Design Work, Video Projects"
                    class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-purple-500" />
                </div>

                <!-- Media items in category -->
                <div class="mb-4">
                  <label class="block text-xs font-medium text-gray-700 mb-2">Media Items</label>
                  <div class="space-y-3" id={"media-items-#{String.replace(category_name, " ", "-")}-container"}>
                    <%= for {item, item_index} <- Enum.with_index(category_items) do %>
                      <div class="border border-gray-200 rounded p-3 bg-gray-50">
                        <div class="grid grid-cols-1 md:grid-cols-2 gap-3 mb-3">
                          <div>
                            <label class="block text-xs font-medium text-gray-700 mb-1">Title</label>
                            <input
                              type="text"
                              name={"media_categories[#{category_name}][items][#{item_index}][title]"}
                              value={Map.get(item, "title", "")}
                              placeholder="Project Title"
                              class="w-full px-2 py-1 text-xs border border-gray-300 rounded focus:ring-1 focus:ring-purple-500" />
                          </div>
                          <div>
                            <label class="block text-xs font-medium text-gray-700 mb-1">Media Type</label>
                            <select
                              name={"media_categories[#{category_name}][items][#{item_index}][media_type]"}
                              class="w-full px-2 py-1 text-xs border border-gray-300 rounded focus:ring-1 focus:ring-purple-500">
                              <option value="image" selected={Map.get(item, "media_type") == "image"}>Image</option>
                              <option value="video" selected={Map.get(item, "media_type") == "video"}>Video</option>
                              <option value="audio" selected={Map.get(item, "media_type") == "audio"}>Audio</option>
                              <option value="document" selected={Map.get(item, "media_type") == "document"}>Document</option>
                            </select>
                          </div>
                        </div>

                        <div class="grid grid-cols-1 md:grid-cols-2 gap-3 mb-3">
                          <div>
                            <label class="block text-xs font-medium text-gray-700 mb-1">Media URL</label>
                            <input
                              type="url"
                              name={"media_categories[#{category_name}][items][#{item_index}][url]"}
                              value={Map.get(item, "url", "")}
                              placeholder="https://example.com/image.jpg"
                              class="w-full px-2 py-1 text-xs border border-gray-300 rounded focus:ring-1 focus:ring-purple-500" />
                          </div>
                          <div>
                            <label class="block text-xs font-medium text-gray-700 mb-1">Thumbnail URL</label>
                            <input
                              type="url"
                              name={"media_categories[#{category_name}][items][#{item_index}][thumbnail_url]"}
                              value={Map.get(item, "thumbnail_url", "")}
                              placeholder="https://example.com/thumb.jpg"
                              class="w-full px-2 py-1 text-xs border border-gray-300 rounded focus:ring-1 focus:ring-purple-500" />
                          </div>
                        </div>

                        <div class="mb-3">
                          <label class="block text-xs font-medium text-gray-700 mb-1">Caption/Description</label>
                          <textarea
                            name={"media_categories[#{category_name}][items][#{item_index}][caption]"}
                            rows="2"
                            class="w-full px-2 py-1 text-xs border border-gray-300 rounded focus:ring-1 focus:ring-purple-500"
                            placeholder="Brief description or story behind this piece..."><%= Map.get(item, "caption", "") %></textarea>
                        </div>

                        <div class="grid grid-cols-1 md:grid-cols-3 gap-3 mb-3">
                          <div>
                            <label class="block text-xs font-medium text-gray-700 mb-1">Alt Text</label>
                            <input
                              type="text"
                              name={"media_categories[#{category_name}][items][#{item_index}][alt_text]"}
                              value={Map.get(item, "alt_text", "")}
                              placeholder="Descriptive alt text"
                              class="w-full px-2 py-1 text-xs border border-gray-300 rounded focus:ring-1 focus:ring-purple-500" />
                          </div>
                          <div>
                            <label class="block text-xs font-medium text-gray-700 mb-1">Created Date</label>
                            <input
                              type="text"
                              name={"media_categories[#{category_name}][items][#{item_index}][created_date]"}
                              value={Map.get(item, "created_date", "")}
                              placeholder="2023"
                              class="w-full px-2 py-1 text-xs border border-gray-300 rounded focus:ring-1 focus:ring-purple-500" />
                          </div>
                          <div>
                            <label class="block text-xs font-medium text-gray-700 mb-1">Sort Order</label>
                            <input
                              type="number"
                              name={"media_categories[#{category_name}][items][#{item_index}][sort_order]"}
                              value={Map.get(item, "sort_order", item_index)}
                              min="0"
                              class="w-full px-2 py-1 text-xs border border-gray-300 rounded focus:ring-1 focus:ring-purple-500" />
                          </div>
                        </div>

                        <!-- Item flags -->
                        <div class="flex flex-wrap gap-3">
                          <div class="flex items-center">
                            <input
                              type="checkbox"
                              id={"featured_#{category_name}_#{item_index}"}
                              name={"media_categories[#{category_name}][items][#{item_index}][featured]"}
                              value="true"
                              checked={Map.get(item, "featured", false)}
                              class="h-3 w-3 text-purple-600 focus:ring-purple-500 border-gray-300 rounded">
                            <label for={"featured_#{category_name}_#{item_index}"} class="ml-1 block text-xs text-gray-900">
                              Featured
                            </label>
                          </div>
                          <div class="flex items-center">
                            <input
                              type="checkbox"
                              id={"lightbox_#{category_name}_#{item_index}"}
                              name={"media_categories[#{category_name}][items][#{item_index}][enable_lightbox]"}
                              value="true"
                              checked={Map.get(item, "enable_lightbox", true)}
                              class="h-3 w-3 text-purple-600 focus:ring-purple-500 border-gray-300 rounded">
                            <label for={"lightbox_#{category_name}_#{item_index}"} class="ml-1 block text-xs text-gray-900">
                              Lightbox
                            </label>
                          </div>
                        </div>

                        <!-- Remove item button -->
                        <button
                          type="button"
                          phx-click="remove_media_item"
                          phx-target={@myself}
                          phx-value-category={category_name}
                          phx-value-index={item_index}
                          class="mt-2 text-xs text-red-600 hover:text-red-800">
                          Remove Item
                        </button>
                      </div>
                    <% end %>
                  </div>

                  <button
                    type="button"
                    phx-click="add_media_item"
                    phx-target={@myself}
                    phx-value-category={category_name}
                    class="mt-2 text-sm text-purple-600 hover:text-purple-700">
                    + Add Media Item
                  </button>
                </div>
              </div>
            <% end %>

            <%= if Enum.empty?(get_media_categories(@content)) do %>
              <div class="text-center py-8 text-gray-500">
                <svg class="w-12 h-12 mx-auto mb-3 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
                </svg>
                <p>No media categories yet</p>
                <p class="text-sm">Click "Add Category" to organize your visual work</p>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Display Settings -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div class="flex items-center">
            <input
              type="checkbox"
              id="show_captions"
              name="show_captions"
              value="true"
              checked={Map.get(@content, "show_captions", true)}
              class="h-4 w-4 text-purple-600 focus:ring-purple-500 border-gray-300 rounded">
            <label for="show_captions" class="ml-2 block text-sm text-gray-900">
              Show captions
            </label>
          </div>
          <div class="flex items-center">
            <input
              type="checkbox"
              id="enable_lightbox"
              name="enable_lightbox"
              value="true"
              checked={Map.get(@content, "enable_lightbox", true)}
              class="h-4 w-4 text-purple-600 focus:ring-purple-500 border-gray-300 rounded">
            <label for="enable_lightbox" class="ml-2 block text-sm text-gray-900">
              Enable lightbox
            </label>
          </div>
          <div class="flex items-center">
            <input
              type="checkbox"
              id="show_metadata"
              name="show_metadata"
              value="true"
              checked={Map.get(@content, "show_metadata", false)}
              class="h-4 w-4 text-purple-600 focus:ring-purple-500 border-gray-300 rounded">
            <label for="show_metadata" class="ml-2 block text-sm text-gray-900">
              Show metadata (dates, etc.)
            </label>
          </div>
          <div class="flex items-center">
            <input
              type="checkbox"
              id="enable_filtering"
              name="enable_filtering"
              value="true"
              checked={Map.get(@content, "enable_filtering", false)}
              class="h-4 w-4 text-purple-600 focus:ring-purple-500 border-gray-300 rounded">
            <label for="enable_filtering" class="ml-2 block text-sm text-gray-900">
              Enable category filtering
            </label>
          </div>
        </div>

      </div>
    </.live_component>
    """
  end

  def handle_event("add_media_category", _params, socket) do
    content = socket.assigns.content
    current_categories = get_media_categories(content)

    new_category_name = "New Category"
    updated_categories = Map.put(current_categories, new_category_name, [])
    updated_content = put_media_categories(content, updated_categories)

    {:noreply, assign(socket, :content, updated_content)}
  end

  def handle_event("remove_media_category", %{"category" => category_name}, socket) do
    content = socket.assigns.content
    current_categories = get_media_categories(content)

    updated_categories = Map.delete(current_categories, category_name)
    updated_content = put_media_categories(content, updated_categories)

    {:noreply, assign(socket, :content, updated_content)}
  end

  def handle_event("add_media_item", %{"category" => category_name}, socket) do
    content = socket.assigns.content
    current_categories = get_media_categories(content)

    new_item = %{
      "title" => "",
      "media_type" => "image",
      "url" => "",
      "thumbnail_url" => "",
      "caption" => "",
      "alt_text" => "",
      "created_date" => "",
      "sort_order" => 0,
      "featured" => false,
      "enable_lightbox" => true
    }

    current_items = Map.get(current_categories, category_name, [])
    updated_items = current_items ++ [new_item]
    updated_categories = Map.put(current_categories, category_name, updated_items)
    updated_content = put_media_categories(content, updated_categories)

    {:noreply, assign(socket, :content, updated_content)}
  end

  def handle_event("remove_media_item", %{"category" => category_name, "index" => index_str}, socket) do
    index = String.to_integer(index_str)
    content = socket.assigns.content
    current_categories = get_media_categories(content)

    current_items = Map.get(current_categories, category_name, [])
    updated_items = List.delete_at(current_items, index)
    updated_categories = Map.put(current_categories, category_name, updated_items)
    updated_content = put_media_categories(content, updated_categories)

    {:noreply, assign(socket, :content, updated_content)}
  end

  defp get_section_content(section) do
    case section.content do
      content when is_map(content) -> content
      content when is_binary(content) -> %{"description" => content}
      _ -> %{}
    end
  end

  defp get_gallery_type(content) do
    layout_settings = Map.get(content, "layout_settings", %{})
    Map.get(layout_settings, "gallery_type", "masonry")
  end

  defp get_items_per_row(content) do
    layout_settings = Map.get(content, "layout_settings", %{})
    Map.get(layout_settings, "items_per_row", 3)
  end

  defp get_media_categories(content) do
    Map.get(content, "media_categories", %{})
  end

  defp put_media_categories(content, categories) do
    Map.put(content, "media_categories", categories)
  end
end
