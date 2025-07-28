# lib/frestyl_web/live/portfolio_live/components/section_modals/hero_about_modal_component.ex
defmodule FrestylWeb.PortfolioLive.Components.HeroAboutModalComponent do
  @moduledoc """
  Specialized modal for editing hero/about sections - headlines, CTAs, background media
  """
  use FrestylWeb, :live_component
  alias FrestylWeb.PortfolioLive.Components.BaseSectionModalComponent

  def update(assigns, socket) do
    content = get_section_content(assigns.editing_section)
    section_type = get_section_type(assigns.editing_section.section_type)

    socket = socket
    |> assign(assigns)
    |> assign(:content, content)
    |> assign(:modal_title, get_modal_title(section_type))
    |> assign(:modal_description, get_modal_description(section_type))
    |> assign(:section_type, section_type)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <.live_component
      module={BaseSectionModalComponent}
      id="hero-about-modal"
      editing_section={@editing_section}
      modal_title={@modal_title}
      modal_description={@modal_description}
      section_type={@section_type}
      myself={@myself}>

      <!-- Hero/About Specific Fields -->
      <div class="space-y-6">

        <!-- Main Content -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Headline/Name</label>
            <input
              type="text"
              name="headline"
              value={Map.get(@content, "headline", "")}
              placeholder="Your Name or Main Headline"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Tagline/Subtitle</label>
            <input
              type="text"
              name="tagline"
              value={Map.get(@content, "tagline", "")}
              placeholder="Professional Title or Tagline"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
          </div>
        </div>

        <!-- Description -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Description</label>
          <textarea
            name="description"
            rows="4"
            class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            placeholder="Write a compelling description about yourself or your work..."><%= Map.get(@content, "description", "") %></textarea>
        </div>

        <!-- Professional Summary (for About sections) -->
        <%= if @section_type == :about do %>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Professional Summary</label>
            <textarea
              name="summary"
              rows="3"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              placeholder="Brief professional summary highlighting key achievements..."><%= Map.get(@content, "summary", "") %></textarea>
          </div>
        <% end %>

        <!-- Media Settings -->
        <div class="border rounded-lg p-4 bg-gray-50">
          <h4 class="font-medium text-gray-900 mb-4">Background & Media</h4>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
            <div>
              <label class="block text-xs font-medium text-gray-700 mb-1">Background Type</label>
              <select
                name="background_type"
                class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500">
                <option value="color" selected={get_background_type(@content) == "color"}>Solid Color</option>
                <option value="gradient" selected={get_background_type(@content) == "gradient"}>Gradient</option>
                <option value="image" selected={get_background_type(@content) == "image"}>Background Image</option>
                <option value="video" selected={get_background_type(@content) == "video"}>Background Video</option>
              </select>
            </div>
            <div>
              <label class="block text-xs font-medium text-gray-700 mb-1">Text Alignment</label>
              <select
                name="text_alignment"
                class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500">
                <option value="left" selected={get_text_alignment(@content) == "left"}>Left</option>
                <option value="center" selected={get_text_alignment(@content) == "center"}>Center</option>
                <option value="right" selected={get_text_alignment(@content) == "right"}>Right</option>
              </select>
            </div>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
            <div>
              <label class="block text-xs font-medium text-gray-700 mb-1">Background Image/Video URL</label>
              <input
                type="url"
                name="background_url"
                value={Map.get(@content, "background_url", "")}
                placeholder="https://example.com/background.jpg"
                class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
            </div>
            <div>
              <label class="block text-xs font-medium text-gray-700 mb-1">Profile Image URL</label>
              <input
                type="url"
                name="profile_image"
                value={Map.get(@content, "profile_image", "")}
                placeholder="https://example.com/headshot.jpg"
                class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
            </div>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label class="block text-xs font-medium text-gray-700 mb-1">Background Color</label>
              <input
                type="color"
                name="background_color"
                value={Map.get(@content, "background_color", "#ffffff")}
                class="w-full h-10 border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
            </div>
            <div>
              <label class="block text-xs font-medium text-gray-700 mb-1">Text Color</label>
              <input
                type="color"
                name="text_color"
                value={Map.get(@content, "text_color", "#000000")}
                class="w-full h-10 border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
            </div>
          </div>
        </div>

        <!-- Call-to-Action Buttons -->
        <div class="border rounded-lg p-4 bg-gray-50">
          <div class="flex items-center justify-between mb-4">
            <h4 class="font-medium text-gray-900">Call-to-Action Buttons</h4>
            <button
              type="button"
              phx-click="add_cta_button"
              phx-target={@myself}
              class="px-3 py-1 bg-blue-600 text-white text-sm rounded-md hover:bg-blue-700 transition-colors">
              + Add Button
            </button>
          </div>

          <div class="space-y-3" id="cta-buttons-container">
            <%= for {button, index} <- Enum.with_index(get_cta_buttons(@content)) do %>
              <div class="border rounded p-3 bg-white flex items-center space-x-3">
                <div class="flex-1 grid grid-cols-1 md:grid-cols-3 gap-3">
                  <div>
                    <input
                      type="text"
                      name={"cta_buttons[#{index}][text]"}
                      value={Map.get(button, "text", "")}
                      placeholder="Button Text"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
                  </div>
                  <div>
                    <input
                      type="url"
                      name={"cta_buttons[#{index}][url]"}
                      value={Map.get(button, "url", "")}
                      placeholder="https://example.com or #contact"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
                  </div>
                  <div>
                    <select
                      name={"cta_buttons[#{index}][style]"}
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500">
                      <option value="primary" selected={Map.get(button, "style") == "primary"}>Primary</option>
                      <option value="secondary" selected={Map.get(button, "style") == "secondary"}>Secondary</option>
                      <option value="outline" selected={Map.get(button, "style") == "outline"}>Outline</option>
                      <option value="ghost" selected={Map.get(button, "style") == "ghost"}>Ghost</option>
                    </select>
                  </div>
                </div>
                <button
                  type="button"
                  phx-click="remove_cta_button"
                  phx-target={@myself}
                  phx-value-index={index}
                  class="p-1 text-red-500 hover:text-red-700">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                  </svg>
                </button>
              </div>
            <% end %>

            <%= if Enum.empty?(get_cta_buttons(@content)) do %>
              <div class="text-center py-4 text-gray-500 text-sm">
                No CTA buttons added yet. Click "Add Button" to create action buttons.
              </div>
            <% end %>
          </div>
        </div>

        <!-- Social Media Links -->
        <div class="border rounded-lg p-4 bg-gray-50">
          <h4 class="font-medium text-gray-900 mb-4">Social Media Links</h4>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label class="block text-xs font-medium text-gray-700 mb-1">LinkedIn</label>
              <input
                type="url"
                name="social_linkedin"
                value={get_social_link(@content, "linkedin")}
                placeholder="https://linkedin.com/in/yourname"
                class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
            </div>
            <div>
              <label class="block text-xs font-medium text-gray-700 mb-1">Twitter</label>
              <input
                type="url"
                name="social_twitter"
                value={get_social_link(@content, "twitter")}
                placeholder="https://twitter.com/yourhandle"
                class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
            </div>
            <div>
              <label class="block text-xs font-medium text-gray-700 mb-1">GitHub</label>
              <input
                type="url"
                name="social_github"
                value={get_social_link(@content, "github")}
                placeholder="https://github.com/yourusername"
                class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
            </div>
            <div>
              <label class="block text-xs font-medium text-gray-700 mb-1">Instagram</label>
              <input
                type="url"
                name="social_instagram"
                value={get_social_link(@content, "instagram")}
                placeholder="https://instagram.com/yourhandle"
                class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
            </div>
            <div>
              <label class="block text-xs font-medium text-gray-700 mb-1">Portfolio Website</label>
              <input
                type="url"
                name="social_website"
                value={get_social_link(@content, "website")}
                placeholder="https://yourwebsite.com"
                class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
            </div>
            <div>
              <label class="block text-xs font-medium text-gray-700 mb-1">Email</label>
              <input
                type="email"
                name="social_email"
                value={get_social_link(@content, "email")}
                placeholder="your@email.com"
                class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
            </div>
          </div>
        </div>

        <!-- Key Highlights/Stats -->
        <%= if @section_type == :about do %>
          <div class="border rounded-lg p-4 bg-gray-50">
            <div class="flex items-center justify-between mb-4">
              <h4 class="font-medium text-gray-900">Key Highlights</h4>
              <button
                type="button"
                phx-click="add_highlight"
                phx-target={@myself}
                class="px-3 py-1 bg-green-600 text-white text-sm rounded-md hover:bg-green-700 transition-colors">
                + Add Highlight
              </button>
            </div>

            <div class="space-y-3" id="highlights-container">
              <%= for {highlight, index} <- Enum.with_index(get_highlights(@content)) do %>
                <div class="border rounded p-3 bg-white flex items-center space-x-3">
                  <div class="flex-1 grid grid-cols-1 md:grid-cols-2 gap-3">
                    <div>
                      <input
                        type="text"
                        name={"highlights[#{index}][title]"}
                        value={Map.get(highlight, "title", "")}
                        placeholder="Years Experience, Projects Completed, etc."
                        class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
                    </div>
                    <div>
                      <input
                        type="text"
                        name={"highlights[#{index}][value]"}
                        value={Map.get(highlight, "value", "")}
                        placeholder="5+, 100+, Award Winner"
                        class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
                    </div>
                  </div>
                  <button
                    type="button"
                    phx-click="remove_highlight"
                    phx-target={@myself}
                    phx-value-index={index}
                    class="p-1 text-red-500 hover:text-red-700">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                    </svg>
                  </button>
                </div>
              <% end %>

              <%= if Enum.empty?(get_highlights(@content)) do %>
                <div class="text-center py-4 text-gray-500 text-sm">
                  No highlights added yet. Click "Add Highlight" to showcase key stats.
                </div>
              <% end %>
            </div>
          </div>
        <% end %>

        <!-- Display Settings -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div class="flex items-center">
            <input
              type="checkbox"
              id="show_social_links"
              name="show_social_links"
              value="true"
              checked={Map.get(@content, "show_social_links", true)}
              class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded">
            <label for="show_social_links" class="ml-2 block text-sm text-gray-900">
              Show social media links
            </label>
          </div>
          <div class="flex items-center">
            <input
              type="checkbox"
              id="show_profile_image"
              name="show_profile_image"
              value="true"
              checked={Map.get(@content, "show_profile_image", true)}
              class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded">
            <label for="show_profile_image" class="ml-2 block text-sm text-gray-900">
              Show profile image
            </label>
          </div>
          <div class="flex items-center">
            <input
              type="checkbox"
              id="enable_parallax"
              name="enable_parallax"
              value="true"
              checked={Map.get(@content, "enable_parallax", false)}
              class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded">
            <label for="enable_parallax" class="ml-2 block text-sm text-gray-900">
              Enable parallax effect
            </label>
          </div>
          <div class="flex items-center">
            <input
              type="checkbox"
              id="fullscreen_hero"
              name="fullscreen_hero"
              value="true"
              checked={Map.get(@content, "fullscreen_hero", false)}
              class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded">
            <label for="fullscreen_hero" class="ml-2 block text-sm text-gray-900">
              Full-screen height
            </label>
          </div>
        </div>

      </div>
    </.live_component>
    """
  end

  def handle_event("add_cta_button", _params, socket) do
    content = socket.assigns.content
    current_buttons = get_cta_buttons(content)

    new_button = %{
      "text" => "",
      "url" => "",
      "style" => "primary"
    }

    updated_content = put_cta_buttons(content, current_buttons ++ [new_button])

    {:noreply, assign(socket, :content, updated_content)}
  end

  def handle_event("remove_cta_button", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    content = socket.assigns.content
    current_buttons = get_cta_buttons(content)

    updated_buttons = List.delete_at(current_buttons, index)
    updated_content = put_cta_buttons(content, updated_buttons)

    {:noreply, assign(socket, :content, updated_content)}
  end

  def handle_event("add_highlight", _params, socket) do
    content = socket.assigns.content
    current_highlights = get_highlights(content)

    new_highlight = %{
      "title" => "",
      "value" => ""
    }

    updated_content = put_highlights(content, current_highlights ++ [new_highlight])

    {:noreply, assign(socket, :content, updated_content)}
  end

  def handle_event("remove_highlight", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    content = socket.assigns.content
    current_highlights = get_highlights(content)

    updated_highlights = List.delete_at(current_highlights, index)
    updated_content = put_highlights(content, updated_highlights)

    {:noreply, assign(socket, :content, updated_content)}
  end

  defp get_section_content(section) do
    case section.content do
      content when is_map(content) -> content
      content when is_binary(content) -> %{"description" => content}
      _ -> %{}
    end
  end

  defp get_section_type(section_type) when is_atom(section_type), do: section_type
  defp get_section_type(section_type) when is_binary(section_type) do
    case section_type do
      "hero" -> :hero
      "about" -> :about
      "intro" -> :hero
      "narrative" -> :about
      _ -> :hero
    end
  end

  defp get_modal_title(section_type) do
    case section_type do
      :hero -> "Edit Hero Section"
      :about -> "Edit About Section"
      _ -> "Edit Section"
    end
  end

  defp get_modal_description(section_type) do
    case section_type do
      :hero -> "Create an impactful first impression with headlines and CTAs"
      :about -> "Share your story and professional background"
      _ -> "Customize your section content"
    end
  end

  defp get_background_type(content) do
    Map.get(content, "background_type", "color")
  end

  defp get_text_alignment(content) do
    Map.get(content, "text_alignment", "center")
  end

  defp get_cta_buttons(content) do
    Map.get(content, "cta_buttons", [])
  end

  defp put_cta_buttons(content, buttons) do
    Map.put(content, "cta_buttons", buttons)
  end

  defp get_highlights(content) do
    Map.get(content, "highlights", [])
  end

  defp put_highlights(content, highlights) do
    Map.put(content, "highlights", highlights)
  end

  defp get_social_link(content, platform) do
    social_links = Map.get(content, "social_links", %{})
    Map.get(social_links, platform, "")
  end
end
