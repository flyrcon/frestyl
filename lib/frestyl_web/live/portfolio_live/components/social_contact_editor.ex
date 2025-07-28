# lib/frestyl_web/live/portfolio_live/components/social_contact_editor.ex

defmodule FrestylWeb.PortfolioLive.Components.SocialContactEditor do
  @moduledoc """
  Editor for social links and contact information in the unified header system.
  """

  use FrestylWeb, :live_component
  import FrestylWeb.CoreComponents

  @impl true
  def update(assigns, socket) do
    portfolio = assigns.portfolio
    customization = portfolio.customization || %{}

    social_links = Map.get(customization, "social_links", [])
    contact_info = Map.get(customization, "contact_info", %{})

    {:ok, socket
      |> assign(assigns)
      |> assign(:social_links, social_links)
      |> assign(:contact_info, contact_info)
      |> assign(:show_add_social, false)
      |> assign(:editing_social_index, nil)
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="social-contact-editor space-y-6">
      <!-- Social Links Section -->
      <div class="bg-white rounded-xl shadow-sm border p-6">
        <div class="flex items-center justify-between mb-4">
          <div>
            <h3 class="text-lg font-bold text-gray-900 flex items-center">
              <svg class="w-5 h-5 mr-2 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.684 13.342C8.886 12.938 9 12.482 9 12c0-.482-.114-.938-.316-1.342m0 2.684a3 3 0 110-2.684m0 2.684l6.632 3.316m-6.632-6l6.632-3.316m0 0a3 3 0 105.367-2.684 3 3 0 00-5.367 2.684zm0 9.316a3 3 0 105.367 2.684 3 3 0 00-5.367-2.684z"/>
              </svg>
              Social Links
            </h3>
            <p class="text-gray-600 text-sm">Add your social media profiles to the portfolio header</p>
          </div>
          <button
            phx-click="add_social_link"
            phx-target={@myself}
            class="px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors text-sm font-medium">
            <svg class="w-4 h-4 mr-1 inline" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
            </svg>
            Add Social Link
          </button>
        </div>

        <!-- Existing Social Links -->
        <%= if length(@social_links) > 0 do %>
          <div class="space-y-3 mb-4">
            <%= for {social_link, index} <- Enum.with_index(@social_links) do %>
              <div class="flex items-center gap-3 p-3 bg-gray-50 rounded-lg">
                <div class="w-10 h-10 bg-gray-200 rounded-lg flex items-center justify-center">
                  <%= render_social_icon(Map.get(social_link, "platform", "link")) %>
                </div>
                <div class="flex-1">
                  <p class="font-medium text-gray-900"><%= format_platform_name(Map.get(social_link, "platform", "link")) %></p>
                  <p class="text-sm text-gray-600 truncate"><%= Map.get(social_link, "url", "") %></p>
                </div>
                <div class="flex items-center gap-2">
                  <button
                    phx-click="edit_social_link"
                    phx-value-index={index}
                    phx-target={@myself}
                    class="p-2 text-gray-500 hover:text-gray-700 rounded">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
                    </svg>
                  </button>
                  <button
                    phx-click="remove_social_link"
                    phx-value-index={index}
                    phx-target={@myself}
                    class="p-2 text-red-500 hover:text-red-700 rounded">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
                    </svg>
                  </button>
                </div>
              </div>
            <% end %>
          </div>
        <% else %>
          <div class="text-center py-8 text-gray-500">
            <svg class="w-12 h-12 mx-auto mb-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1" d="M8.684 13.342C8.886 12.938 9 12.482 9 12c0-.482-.114-.938-.316-1.342m0 2.684a3 3 0 110-2.684m0 2.684l6.632 3.316m-6.632-6l6.632-3.316m0 0a3 3 0 105.367-2.684 3 3 0 00-5.367 2.684zm0 9.316a3 3 0 105.367 2.684 3 3 0 00-5.367-2.684z"/>
            </svg>
            <p class="text-sm">No social links added yet</p>
            <p class="text-xs mt-1">Add links to your professional profiles</p>
          </div>
        <% end %>

        <!-- Add/Edit Social Link Form -->
        <%= if @show_add_social || @editing_social_index do %>
          <div class="border-t pt-4">
            <form phx-submit="save_social_link" phx-target={@myself} class="space-y-4">
              <%= if @editing_social_index do %>
                <input type="hidden" name="index" value={@editing_social_index}>
              <% end %>

              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-2">Platform</label>
                  <select
                    name="platform"
                    class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500">
                    <%= for platform <- get_social_platforms() do %>
                      <option value={platform.id}
                              selected={get_current_platform(@editing_social_index, @social_links) == platform.id}>
                        <%= platform.name %>
                      </option>
                    <% end %>
                  </select>
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-2">URL</label>
                  <input
                    type="url"
                    name="url"
                    value={get_current_url(@editing_social_index, @social_links)}
                    placeholder="https://..."
                    class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
                    required>
                </div>
              </div>

              <div class="flex items-center gap-3">
                <button
                  type="submit"
                  class="px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors font-medium">
                  <%= if @editing_social_index, do: "Update Link", else: "Add Link" %>
                </button>
                <button
                  type="button"
                  phx-click="cancel_social_form"
                  phx-target={@myself}
                  class="px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors">
                  Cancel
                </button>
              </div>
            </form>
          </div>
        <% end %>
      </div>

      <!-- Contact Information Section -->
      <div class="bg-white rounded-xl shadow-sm border p-6">
        <div class="mb-6">
          <h3 class="text-lg font-bold text-gray-900 flex items-center">
            <svg class="w-5 h-5 mr-2 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
            </svg>
            Contact Information
          </h3>
          <p class="text-gray-600 text-sm">Add your contact details to the portfolio header</p>
        </div>

        <form phx-submit="save_contact_info" phx-target={@myself} class="space-y-4">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Email</label>
              <input
                type="email"
                name="email"
                value={Map.get(@contact_info, "email", "")}
                placeholder="your@email.com"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500">
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Phone</label>
              <input
                type="tel"
                name="phone"
                value={Map.get(@contact_info, "phone", "")}
                placeholder="+1 (555) 123-4567"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500">
            </div>
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Location (Optional)</label>
            <input
              type="text"
              name="location"
              value={Map.get(@contact_info, "location", "")}
              placeholder="City, State/Country"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500">
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Website (Optional)</label>
            <input
              type="url"
              name="website"
              value={Map.get(@contact_info, "website", "")}
              placeholder="https://yourwebsite.com"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500">
          </div>

          <button
            type="submit"
            class="px-6 py-3 bg-gray-900 text-white rounded-lg hover:bg-gray-800 transition-colors font-medium">
            Update Contact Info
          </button>
        </form>
      </div>

      <!-- Header Preview -->
      <div class="bg-gray-50 rounded-xl border-2 border-dashed border-gray-300 p-6">
        <h4 class="font-medium text-gray-900 mb-4">Header Preview</h4>
        <div class="bg-white rounded-lg p-4 border">
          <%= render_header_preview(assigns) %>
        </div>
        <p class="text-xs text-gray-500 mt-2">This shows how your social links and contact info will appear in the portfolio header</p>
      </div>
    </div>
    """
  end

  # ============================================================================
  # SOCIAL PLATFORM DEFINITIONS
  # ============================================================================

  defp get_social_platforms do
    [
      %{id: "linkedin", name: "LinkedIn"},
      %{id: "twitter", name: "Twitter/X"},
      %{id: "github", name: "GitHub"},
      %{id: "dribbble", name: "Dribbble"},
      %{id: "behance", name: "Behance"},
      %{id: "instagram", name: "Instagram"},
      %{id: "youtube", name: "YouTube"},
      %{id: "facebook", name: "Facebook"},
      %{id: "tiktok", name: "TikTok"},
      %{id: "medium", name: "Medium"},
      %{id: "website", name: "Personal Website"},
      %{id: "other", name: "Other"}
    ]
  end

  defp render_social_icon(platform) do
    assigns = %{platform: platform}

    case platform do
      "linkedin" -> ~H"""
        <svg class="w-5 h-5 text-blue-600" fill="currentColor" viewBox="0 0 24 24">
          <path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433c-1.144 0-2.063-.926-2.063-2.065 0-1.138.92-2.063 2.063-2.063 1.14 0 2.064.925 2.064 2.063 0 1.139-.925 2.065-2.064 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z"/>
        </svg>
      """
      "twitter" -> ~H"""
        <svg class="w-5 h-5 text-blue-400" fill="currentColor" viewBox="0 0 24 24">
          <path d="M23.953 4.57a10 10 0 01-2.825.775 4.958 4.958 0 002.163-2.723c-.951.555-2.005.959-3.127 1.184a4.92 4.92 0 00-8.384 4.482C7.69 8.095 4.067 6.13 1.64 3.162a4.822 4.822 0 00-.666 2.475c0 1.71.87 3.213 2.188 4.096a4.904 4.904 0 01-2.228-.616v.06a4.923 4.923 0 003.946 4.827 4.996 4.996 0 01-2.212.085 4.936 4.936 0 004.604 3.417 9.867 9.867 0 01-6.102 2.105c-.39 0-.779-.023-1.17-.067a13.995 13.995 0 007.557 2.209c9.053 0 13.998-7.496 13.998-13.985 0-.21 0-.42-.015-.63A9.935 9.935 0 0024 4.59z"/>
        </svg>
      """
      "github" -> ~H"""
        <svg class="w-5 h-5 text-gray-800" fill="currentColor" viewBox="0 0 24 24">
          <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/>
        </svg>
      """
      _ -> ~H"""
        <svg class="w-5 h-5 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1"/>
        </svg>
      """
    end
  end

  defp format_platform_name(platform) do
    case platform do
      "linkedin" -> "LinkedIn"
      "twitter" -> "Twitter/X"
      "github" -> "GitHub"
      "dribbble" -> "Dribbble"
      "behance" -> "Behance"
      "instagram" -> "Instagram"
      "youtube" -> "YouTube"
      "facebook" -> "Facebook"
      "tiktok" -> "TikTok"
      "medium" -> "Medium"
      "website" -> "Website"
      _ -> "Link"
    end
  end

  defp render_header_preview(assigns) do
    ~H"""
    <div class="space-y-3">
      <!-- Portfolio Title & Description would be here -->
      <div>
        <h3 class="text-lg font-bold text-gray-900"><%= @portfolio.title %></h3>
        <%= if @portfolio.description do %>
          <p class="text-gray-600 text-sm"><%= @portfolio.description %></p>
        <% end %>
      </div>

      <!-- Social Links Preview -->
      <%= if length(@social_links) > 0 do %>
        <div class="flex items-center gap-2">
          <span class="text-xs text-gray-500 mr-2">Social:</span>
          <%= for social_link <- Enum.take(@social_links, 5) do %>
            <div class="w-6 h-6 bg-gray-100 rounded flex items-center justify-center">
              <%= render_social_icon(Map.get(social_link, "platform", "link")) %>
            </div>
          <% end %>
        </div>
      <% end %>

      <!-- Contact Info Preview -->
      <%= if @contact_info["email"] || @contact_info["phone"] do %>
        <div class="text-xs text-gray-600 space-y-1">
          <%= if @contact_info["email"] do %>
            <div class="flex items-center gap-1">
              <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
              </svg>
              <span><%= @contact_info["email"] %></span>
            </div>
          <% end %>
          <%= if @contact_info["phone"] do %>
            <div class="flex items-center gap-1">
              <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z"/>
              </svg>
              <span><%= @contact_info["phone"] %></span>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # EVENT HANDLERS
  # ============================================================================

  @impl true
  def handle_event("add_social_link", _params, socket) do
    {:noreply, assign(socket, :show_add_social, true)}
  end

  @impl true
  def handle_event("edit_social_link", %{"index" => index}, socket) do
    {:noreply, socket
      |> assign(:editing_social_index, String.to_integer(index))
      |> assign(:show_add_social, false)
    }
  end

  @impl true
  def handle_event("remove_social_link", %{"index" => index}, socket) do
    index = String.to_integer(index)
    updated_links = List.delete_at(socket.assigns.social_links, index)

    send(self(), {:update_social_links, updated_links})

    {:noreply, assign(socket, :social_links, updated_links)}
  end

  @impl true
  def handle_event("save_social_link", params, socket) do
    social_link = %{
      "platform" => params["platform"],
      "url" => params["url"]
    }

    updated_links = if params["index"] do
      # Update existing
      index = String.to_integer(params["index"])
      List.replace_at(socket.assigns.social_links, index, social_link)
    else
      # Add new
      socket.assigns.social_links ++ [social_link]
    end

    send(self(), {:update_social_links, updated_links})

    {:noreply, socket
      |> assign(:social_links, updated_links)
      |> assign(:show_add_social, false)
      |> assign(:editing_social_index, nil)
    }
  end

  @impl true
  def handle_event("cancel_social_form", _params, socket) do
    {:noreply, socket
      |> assign(:show_add_social, false)
      |> assign(:editing_social_index, nil)
    }
  end

  @impl true
  def handle_event("save_contact_info", params, socket) do
    contact_info = Map.take(params, ["email", "phone", "location", "website"])

    send(self(), {:update_contact_info, contact_info})

    {:noreply, assign(socket, :contact_info, contact_info)}
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp get_current_platform(nil, _social_links), do: "linkedin"
  defp get_current_platform(index, social_links) do
    case Enum.at(social_links, index) do
      nil -> "linkedin"
      social_link -> Map.get(social_link, "platform", "linkedin")
    end
  end

  defp get_current_url(nil, _social_links), do: ""
  defp get_current_url(index, social_links) do
    case Enum.at(social_links, index) do
      nil -> ""
      social_link -> Map.get(social_link, "url", "")
    end
  end
end
