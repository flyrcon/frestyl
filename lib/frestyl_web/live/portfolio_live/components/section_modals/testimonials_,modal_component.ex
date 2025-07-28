# lib/frestyl_web/live/portfolio_live/components/section_modals/testimonials_modal_component.ex
defmodule FrestylWeb.PortfolioLive.Components.TestimonialsModalComponent do
  @moduledoc """
  Specialized modal for editing testimonials sections - client reviews, ratings, recommendations
  """
  use FrestylWeb, :live_component
  alias FrestylWeb.PortfolioLive.Components.BaseSectionModalComponent

  def update(assigns, socket) do
    content = get_section_content(assigns.editing_section)

    socket = socket
    |> assign(assigns)
    |> assign(:content, content)
    |> assign(:modal_title, "Edit Testimonials")
    |> assign(:modal_description, "Showcase client reviews and recommendations")
    |> assign(:section_type, :testimonials)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <.live_component
      module={BaseSectionModalComponent}
      id="testimonials-modal"
      editing_section={@editing_section}
      modal_title={@modal_title}
      modal_description={@modal_description}
      section_type={@section_type}
      myself={@myself}>

      <!-- Testimonials Specific Fields -->
      <div class="space-y-6">

        <!-- Section Description -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Section Description</label>
          <textarea
            name="description"
            rows="3"
            class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            placeholder="What clients say about working with you..."><%= Map.get(@content, "description", "") %></textarea>
        </div>

        <!-- Display Settings -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Layout Style</label>
            <select
              name="layout_style"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
              <option value="grid" selected={get_layout_style(@content) == "grid"}>Grid Layout</option>
              <option value="carousel" selected={get_layout_style(@content) == "carousel"}>Carousel</option>
              <option value="masonry" selected={get_layout_style(@content) == "masonry"}>Masonry</option>
              <option value="featured" selected={get_layout_style(@content) == "featured"}>Featured + Grid</option>
            </select>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Items Per Row</label>
            <select
              name="items_per_row"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
              <option value="1" selected={get_items_per_row(@content) == 1}>1 Column</option>
              <option value="2" selected={get_items_per_row(@content) == 2}>2 Columns</option>
              <option value="3" selected={get_items_per_row(@content) == 3}>3 Columns</option>
            </select>
          </div>
        </div>

        <!-- Testimonial Items -->
        <div class="border rounded-lg p-4 bg-gray-50">
          <div class="flex items-center justify-between mb-4">
            <h4 class="font-medium text-gray-900">Client Testimonials</h4>
            <button
              type="button"
              phx-click="add_testimonial"
              phx-target={@myself}
              class="px-3 py-1 bg-green-600 text-white text-sm rounded-md hover:bg-green-700 transition-colors">
              + Add Testimonial
            </button>
          </div>

          <div class="space-y-6" id="testimonials-container">
            <%= for {testimonial, index} <- Enum.with_index(Map.get(@content, "items", [])) do %>
              <div class="border rounded-lg p-4 bg-white relative">
                <!-- Remove button -->
                <button
                  type="button"
                  phx-click="remove_testimonial"
                  phx-target={@myself}
                  phx-value-index={index}
                  class="absolute top-2 right-2 p-1 text-red-500 hover:text-red-700">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                  </svg>
                </button>

                <!-- Testimonial content -->
                <div class="mb-4">
                  <label class="block text-xs font-medium text-gray-700 mb-1">Testimonial Content</label>
                  <textarea
                    name={"items[#{index}][content]"}
                    rows="4"
                    class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500"
                    placeholder="The testimonial content goes here. What did the client say about your work?"><%= Map.get(testimonial, "content", "") %></textarea>
                </div>

                <!-- Client information -->
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Client Name</label>
                    <input
                      type="text"
                      name={"items[#{index}][name]"}
                      value={Map.get(testimonial, "name", "")}
                      placeholder="John Smith"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Job Title</label>
                    <input
                      type="text"
                      name={"items[#{index}][title]"}
                      value={Map.get(testimonial, "title", "")}
                      placeholder="CEO, Marketing Director"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
                  </div>
                </div>

                <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Company</label>
                    <input
                      type="text"
                      name={"items[#{index}][company]"}
                      value={Map.get(testimonial, "company", "")}
                      placeholder="Company Name"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Relationship</label>
                    <select
                      name={"items[#{index}][relationship]"}
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500">
                      <option value="client" selected={Map.get(testimonial, "relationship") == "client"}>Client</option>
                      <option value="colleague" selected={Map.get(testimonial, "relationship") == "colleague"}>Colleague</option>
                      <option value="supervisor" selected={Map.get(testimonial, "relationship") == "supervisor"}>Supervisor</option>
                      <option value="partner" selected={Map.get(testimonial, "relationship") == "partner"}>Business Partner</option>
                      <option value="vendor" selected={Map.get(testimonial, "relationship") == "vendor"}>Vendor/Contractor</option>
                    </select>
                  </div>
                </div>

                <!-- Project and date information -->
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Project/Service</label>
                    <input
                      type="text"
                      name={"items[#{index}][project]"}
                      value={Map.get(testimonial, "project", "")}
                      placeholder="Website Redesign, Brand Strategy"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Date</label>
                    <input
                      type="text"
                      name={"items[#{index}][date]"}
                      value={Map.get(testimonial, "date", "")}
                      placeholder="March 2023"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
                  </div>
                </div>

                <!-- Rating and media -->
                <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-4">
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Rating (1-5)</label>
                    <select
                      name={"items[#{index}][rating]"}
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500">
                      <option value="5" selected={Map.get(testimonial, "rating", 5) == 5}>⭐⭐⭐⭐⭐ (5)</option>
                      <option value="4" selected={Map.get(testimonial, "rating", 5) == 4}>⭐⭐⭐⭐ (4)</option>
                      <option value="3" selected={Map.get(testimonial, "rating", 5) == 3}>⭐⭐⭐ (3)</option>
                      <option value="2" selected={Map.get(testimonial, "rating", 5) == 2}>⭐⭐ (2)</option>
                      <option value="1" selected={Map.get(testimonial, "rating", 5) == 1}>⭐ (1)</option>
                    </select>
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Avatar Image URL</label>
                    <input
                      type="url"
                      name={"items[#{index}][avatar_image]"}
                      value={Map.get(testimonial, "avatar_image", "")}
                      placeholder="https://example.com/avatar.jpg"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Company Logo URL</label>
                    <input
                      type="url"
                      name={"items[#{index}][company_logo]"}
                      value={Map.get(testimonial, "company_logo", "")}
                      placeholder="https://example.com/logo.png"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
                  </div>
                </div>

                <!-- Verification and social -->
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Verification URL</label>
                    <input
                      type="url"
                      name={"items[#{index}][verification_url]"}
                      value={Map.get(testimonial, "verification_url", "")}
                      placeholder="https://linkedin.com/in/client or review platform"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Platform</label>
                    <select
                      name={"items[#{index}][platform]"}
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500">
                      <option value="personal" selected={Map.get(testimonial, "platform") == "personal"}>Personal</option>
                      <option value="linkedin" selected={Map.get(testimonial, "platform") == "linkedin"}>LinkedIn</option>
                      <option value="google" selected={Map.get(testimonial, "platform") == "google"}>Google Reviews</option>
                      <option value="upwork" selected={Map.get(testimonial, "platform") == "upwork"}>Upwork</option>
                      <option value="fiverr" selected={Map.get(testimonial, "platform") == "fiverr"}>Fiverr</option>
                      <option value="clutch" selected={Map.get(testimonial, "platform") == "clutch"}>Clutch</option>
                      <option value="other" selected={Map.get(testimonial, "platform") == "other"}>Other</option>
                    </select>
                  </div>
                </div>

                <!-- Additional context -->
                <div class="mb-4">
                  <label class="block text-xs font-medium text-gray-700 mb-1">Additional Context (Optional)</label>
                  <textarea
                    name={"items[#{index}][context]"}
                    rows="2"
                    class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500"
                    placeholder="Additional background about the project or relationship..."><%= Map.get(testimonial, "context", "") %></textarea>
                </div>

                <!-- Testimonial flags -->
                <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                  <div class="flex items-center">
                    <input
                      type="checkbox"
                      id={"featured_#{index}"}
                      name={"items[#{index}][featured]"}
                      value="true"
                      checked={Map.get(testimonial, "featured", false)}
                      class="h-4 w-4 text-green-600 focus:ring-green-500 border-gray-300 rounded">
                    <label for={"featured_#{index}"} class="ml-2 block text-xs text-gray-900">
                      Featured testimonial
                    </label>
                  </div>
                  <div class="flex items-center">
                    <input
                      type="checkbox"
                      id={"verified_#{index}"}
                      name={"items[#{index}][verified]"}
                      value="true"
                      checked={Map.get(testimonial, "verified", false)}
                      class="h-4 w-4 text-green-600 focus:ring-green-500 border-gray-300 rounded">
                    <label for={"verified_#{index}"} class="ml-2 block text-xs text-gray-900">
                      Verified review
                    </label>
                  </div>
                  <div class="flex items-center">
                    <input
                      type="checkbox"
                      id={"show_company_#{index}"}
                      name={"items[#{index}][show_company]"}
                      value="true"
                      checked={Map.get(testimonial, "show_company", true)}
                      class="h-4 w-4 text-green-600 focus:ring-green-500 border-gray-300 rounded">
                    <label for={"show_company_#{index}"} class="ml-2 block text-xs text-gray-900">
                      Show company info
                    </label>
                  </div>
                </div>
              </div>
            <% end %>

            <%= if length(Map.get(@content, "items", [])) == 0 do %>
              <div class="text-center py-8 text-gray-500">
                <svg class="w-12 h-12 mx-auto mb-3 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"/>
                </svg>
                <p>No testimonials added yet</p>
                <p class="text-sm">Click "Add Testimonial" to showcase client feedback</p>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Display Settings -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div class="flex items-center">
            <input
              type="checkbox"
              id="show_ratings"
              name="show_ratings"
              value="true"
              checked={get_display_setting(@content, "show_ratings", true)}
              class="h-4 w-4 text-green-600 focus:ring-green-500 border-gray-300 rounded">
            <label for="show_ratings" class="ml-2 block text-sm text-gray-900">
              Show star ratings
            </label>
          </div>
          <div class="flex items-center">
            <input
              type="checkbox"
              id="show_avatars"
              name="show_avatars"
              value="true"
              checked={get_display_setting(@content, "show_avatars", true)}
              class="h-4 w-4 text-green-600 focus:ring-green-500 border-gray-300 rounded">
            <label for="show_avatars" class="ml-2 block text-sm text-gray-900">
              Show client avatars
            </label>
          </div>
          <div class="flex items-center">
            <input
              type="checkbox"
              id="show_company_logos"
              name="show_company_logos"
              value="true"
              checked={get_display_setting(@content, "show_company_logos", true)}
              class="h-4 w-4 text-green-600 focus:ring-green-500 border-gray-300 rounded">
            <label for="show_company_logos" class="ml-2 block text-sm text-gray-900">
              Show company logos
            </label>
          </div>
          <div class="flex items-center">
            <input
              type="checkbox"
              id="show_verification"
              name="show_verification"
              value="true"
              checked={get_display_setting(@content, "show_verification", false)}
              class="h-4 w-4 text-green-600 focus:ring-green-500 border-gray-300 rounded">
            <label for="show_verification" class="ml-2 block text-sm text-gray-900">
              Show verification badges
            </label>
          </div>
        </div>

      </div>
    </.live_component>
    """
  end

  def handle_event("add_testimonial", _params, socket) do
    content = socket.assigns.content
    current_items = Map.get(content, "items", [])

    new_testimonial = %{
      "content" => "",
      "name" => "",
      "title" => "",
      "company" => "",
      "relationship" => "client",
      "project" => "",
      "date" => "",
      "rating" => 5,
      "avatar_image" => "",
      "company_logo" => "",
      "verification_url" => "",
      "platform" => "personal",
      "context" => "",
      "featured" => false,
      "verified" => false,
      "show_company" => true
    }

    updated_content = Map.put(content, "items", current_items ++ [new_testimonial])

    {:noreply, assign(socket, :content, updated_content)}
  end

  def handle_event("remove_testimonial", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    content = socket.assigns.content
    current_items = Map.get(content, "items", [])

    updated_items = List.delete_at(current_items, index)
    updated_content = Map.put(content, "items", updated_items)

    {:noreply, assign(socket, :content, updated_content)}
  end

  defp get_section_content(section) do
    case section.content do
      content when is_map(content) -> content
      content when is_binary(content) -> %{"description" => content}
      _ -> %{}
    end
  end

  defp get_layout_style(content) do
    display_settings = Map.get(content, "display_settings", %{})
    Map.get(display_settings, "layout", "grid")
  end

  defp get_items_per_row(content) do
    display_settings = Map.get(content, "display_settings", %{})
    Map.get(display_settings, "items_per_row", 2)
  end

  defp get_display_setting(content, setting, default) do
    display_settings = Map.get(content, "display_settings", %{})
    Map.get(display_settings, setting, default)
  end
end
