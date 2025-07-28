# lib/frestyl_web/live/portfolio_live/components/section_modals/achievements_modal_component.ex
defmodule FrestylWeb.PortfolioLive.Components.AchievementsModalComponent do
  @moduledoc """
  Specialized modal for editing achievements sections - awards, recognition, metrics
  """
  use FrestylWeb, :live_component
  alias FrestylWeb.PortfolioLive.Components.BaseSectionModalComponent

  def update(assigns, socket) do
    content = get_section_content(assigns.editing_section)

    socket = socket
    |> assign(assigns)
    |> assign(:content, content)
    |> assign(:modal_title, "Edit Achievements")
    |> assign(:modal_description, "Showcase your awards, recognition, and key accomplishments")
    |> assign(:section_type, :achievements)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <.live_component
      module={BaseSectionModalComponent}
      id="achievements-modal"
      editing_section={@editing_section}
      modal_title={@modal_title}
      modal_description={@modal_description}
      section_type={@section_type}
      myself={@myself}>

      <!-- Achievements Specific Fields -->
      <div class="space-y-6">

        <!-- Section Description -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Section Description</label>
          <textarea
            name="description"
            rows="3"
            class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            placeholder="Overview of your key achievements and recognition..."><%= Map.get(@content, "description", "") %></textarea>
        </div>

        <!-- Display Style -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Display Style</label>
          <select
            name="display_style"
            class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
            <option value="grid" selected={Map.get(@content, "display_style") == "grid"}>Award Grid</option>
            <option value="timeline" selected={Map.get(@content, "display_style") == "timeline"}>Timeline</option>
            <option value="featured" selected={Map.get(@content, "display_style") == "featured"}>Featured + Grid</option>
            <option value="stats" selected={Map.get(@content, "display_style") == "stats"}>Stats Dashboard</option>
          </select>
        </div>

        <!-- Awards -->
        <div class="border rounded-lg p-4 bg-gray-50">
          <div class="flex items-center justify-between mb-4">
            <h4 class="font-medium text-gray-900">Awards & Recognition</h4>
            <button
              type="button"
              phx-click="add_award"
              phx-target={@myself}
              class="px-3 py-1 bg-yellow-600 text-white text-sm rounded-md hover:bg-yellow-700 transition-colors">
              + Add Award
            </button>
          </div>

          <div class="space-y-4" id="awards-container">
            <%= for {award, index} <- Enum.with_index(Map.get(@content, "awards", [])) do %>
              <div class="border rounded-lg p-4 bg-white relative">
                <!-- Remove button -->
                <button
                  type="button"
                  phx-click="remove_award"
                  phx-target={@myself}
                  phx-value-index={index}
                  class="absolute top-2 right-2 p-1 text-red-500 hover:text-red-700">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                  </svg>
                </button>

                <!-- Award basic info -->
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Award Title</label>
                    <input
                      type="text"
                      name={"awards[#{index}][title]"}
                      value={Map.get(award, "title", "")}
                      placeholder="Best Developer Award, Employee of the Year"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-yellow-500" />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Awarding Organization</label>
                    <input
                      type="text"
                      name={"awards[#{index}][organization]"}
                      value={Map.get(award, "organization", "")}
                      placeholder="Company Name, Industry Association"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-yellow-500" />
                  </div>
                </div>

                <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-4">
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Date Received</label>
                    <input
                      type="text"
                      name={"awards[#{index}][date]"}
                      value={Map.get(award, "date", "")}
                      placeholder="March 2023"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-yellow-500" />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Category</label>
                    <select
                      name={"awards[#{index}][category]"}
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-yellow-500">
                      <option value="professional" selected={Map.get(award, "category") == "professional"}>Professional</option>
                      <option value="academic" selected={Map.get(award, "category") == "academic"}>Academic</option>
                      <option value="industry" selected={Map.get(award, "category") == "industry"}>Industry</option>
                      <option value="community" selected={Map.get(award, "category") == "community"}>Community</option>
                      <option value="innovation" selected={Map.get(award, "category") == "innovation"}>Innovation</option>
                      <option value="leadership" selected={Map.get(award, "category") == "leadership"}>Leadership</option>
                    </select>
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Level</label>
                    <select
                      name={"awards[#{index}][level]"}
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-yellow-500">
                      <option value="international" selected={Map.get(award, "level") == "international"}>International</option>
                      <option value="national" selected={Map.get(award, "level") == "national"}>National</option>
                      <option value="regional" selected={Map.get(award, "level") == "regional"}>Regional</option>
                      <option value="local" selected={Map.get(award, "level") == "local"}>Local</option>
                      <option value="corporate" selected={Map.get(award, "level") == "corporate"}>Corporate</option>
                    </select>
                  </div>
                </div>

                <!-- Description -->
                <div class="mb-4">
                  <label class="block text-xs font-medium text-gray-700 mb-1">Description</label>
                  <textarea
                    name={"awards[#{index}][description]"}
                    rows="3"
                    class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-yellow-500"
                    placeholder="What this award recognizes and why you received it..."><%= Map.get(award, "description", "") %></textarea>
                </div>

                <!-- Media and verification -->
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Award Image/Certificate URL</label>
                    <input
                      type="url"
                      name={"awards[#{index}][image_url]"}
                      value={Map.get(award, "image_url", "")}
                      placeholder="https://example.com/certificate.jpg"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-yellow-500" />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Verification/News URL</label>
                    <input
                      type="url"
                      name={"awards[#{index}][verification_url]"}
                      value={Map.get(award, "verification_url", "")}
                      placeholder="https://news.com/award-announcement"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-yellow-500" />
                  </div>
                </div>

                <!-- Award flags -->
                <div class="flex items-center space-x-4">
                  <div class="flex items-center">
                    <input
                      type="checkbox"
                      id={"featured_award_#{index}"}
                      name={"awards[#{index}][featured]"}
                      value="true"
                      checked={Map.get(award, "featured", false)}
                      class="h-3 w-3 text-yellow-600 focus:ring-yellow-500 border-gray-300 rounded">
                    <label for={"featured_award_#{index}"} class="ml-1 block text-xs text-gray-900">
                      Featured
                    </label>
                  </div>
                  <div class="flex items-center">
                    <input
                      type="checkbox"
                      id={"verified_#{index}"}
                      name={"awards[#{index}][verified]"}
                      value="true"
                      checked={Map.get(award, "verified", false)}
                      class="h-3 w-3 text-yellow-600 focus:ring-yellow-500 border-gray-300 rounded">
                    <label for={"verified_#{index}"} class="ml-1 block text-xs text-gray-900">
                      Verified
                    </label>
                  </div>
                </div>
              </div>
            <% end %>

            <%= if length(Map.get(@content, "awards", [])) == 0 do %>
              <div class="text-center py-6 text-gray-500">
                <svg class="w-10 h-10 mx-auto mb-2 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"/>
                </svg>
                <p class="text-sm">No awards added yet</p>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Key Metrics/Stats -->
        <div class="border rounded-lg p-4 bg-gray-50">
          <div class="flex items-center justify-between mb-4">
            <h4 class="font-medium text-gray-900">Key Metrics & Stats</h4>
            <button
              type="button"
              phx-click="add_metric"
              phx-target={@myself}
              class="px-3 py-1 bg-blue-600 text-white text-sm rounded-md hover:bg-blue-700 transition-colors">
              + Add Metric
            </button>
          </div>

          <div class="space-y-3" id="metrics-container">
            <%= for {metric, index} <- Enum.with_index(Map.get(@content, "metrics", [])) do %>
              <div class="border rounded p-3 bg-white flex items-center space-x-3">
                <div class="flex-1 grid grid-cols-1 md:grid-cols-3 gap-3">
                  <div>
                    <input
                      type="text"
                      name={"metrics[#{index}][label]"}
                      value={Map.get(metric, "label", "")}
                      placeholder="Projects Completed, Revenue Generated"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
                  </div>
                  <div>
                    <input
                      type="text"
                      name={"metrics[#{index}][value]"}
                      value={Map.get(metric, "value", "")}
                      placeholder="100+, $1M+, 95%"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
                  </div>
                  <div>
                    <input
                      type="text"
                      name={"metrics[#{index}][context]"}
                      value={Map.get(metric, "context", "")}
                      placeholder="Last 2 years, Career total"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
                  </div>
                </div>
                <button
                  type="button"
                  phx-click="remove_metric"
                  phx-target={@myself}
                  phx-value-index={index}
                  class="p-1 text-red-500 hover:text-red-700">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                  </svg>
                </button>
              </div>
            <% end %>

            <%= if Enum.empty?(Map.get(@content, "metrics", [])) do %>
              <div class="text-center py-4 text-gray-500 text-sm">
                No metrics added yet. Click "Add Metric" to showcase key achievements.
              </div>
            <% end %>
          </div>
        </div>

        <!-- Recognition/Media Coverage -->
        <div class="border rounded-lg p-4 bg-gray-50">
          <div class="flex items-center justify-between mb-4">
            <h4 class="font-medium text-gray-900">Media Coverage & Recognition</h4>
            <button
              type="button"
              phx-click="add_recognition"
              phx-target={@myself}
              class="px-3 py-1 bg-purple-600 text-white text-sm rounded-md hover:bg-purple-700 transition-colors">
              + Add Recognition
            </button>
          </div>

          <div class="space-y-4" id="recognition-container">
            <%= for {recognition, index} <- Enum.with_index(Map.get(@content, "recognition", [])) do %>
              <div class="border rounded p-3 bg-white">
                <div class="grid grid-cols-1 md:grid-cols-2 gap-3 mb-3">
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Publication/Source</label>
                    <input
                      type="text"
                      name={"recognition[#{index}][source]"}
                      value={Map.get(recognition, "source", "")}
                      placeholder="TechCrunch, Forbes, Local News"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-purple-500" />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Type</label>
                    <select
                      name={"recognition[#{index}][type]"}
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-purple-500">
                      <option value="article" selected={Map.get(recognition, "type") == "article"}>Article/Feature</option>
                      <option value="interview" selected={Map.get(recognition, "type") == "interview"}>Interview</option>
                      <option value="podcast" selected={Map.get(recognition, "type") == "podcast"}>Podcast</option>
                      <option value="video" selected={Map.get(recognition, "type") == "video"}>Video</option>
                      <option value="mention" selected={Map.get(recognition, "type") == "mention"}>Mention</option>
                      <option value="quote" selected={Map.get(recognition, "type") == "quote"}>Quote</option>
                    </select>
                  </div>
                </div>

                <div class="grid grid-cols-1 md:grid-cols-2 gap-3 mb-3">
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Title/Headline</label>
                    <input
                      type="text"
                      name={"recognition[#{index}][title]"}
                      value={Map.get(recognition, "title", "")}
                      placeholder="How This Developer Changed Everything"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-purple-500" />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Date</label>
                    <input
                      type="text"
                      name={"recognition[#{index}][date]"}
                      value={Map.get(recognition, "date", "")}
                      placeholder="March 2023"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-purple-500" />
                  </div>
                </div>

                <div class="mb-3">
                  <label class="block text-xs font-medium text-gray-700 mb-1">URL</label>
                  <input
                    type="url"
                    name={"recognition[#{index}][url]"}
                    value={Map.get(recognition, "url", "")}
                    placeholder="https://techcrunch.com/article"
                    class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-purple-500" />
                </div>

                <div class="flex justify-end">
                  <button
                    type="button"
                    phx-click="remove_recognition"
                    phx-target={@myself}
                    phx-value-index={index}
                    class="text-xs text-red-600 hover:text-red-800">
                    Remove
                  </button>
                </div>
              </div>
            <% end %>

            <%= if length(Map.get(@content, "recognition", [])) == 0 do %>
              <div class="text-center py-4 text-gray-500 text-sm">
                No media coverage added yet. Click "Add Recognition" to showcase press mentions.
              </div>
            <% end %>
          </div>
        </div>

        <!-- Display Settings -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div class="flex items-center">
            <input
              type="checkbox"
              id="show_metrics"
              name="show_metrics"
              value="true"
              checked={Map.get(@content, "show_metrics", true)}
              class="h-4 w-4 text-yellow-600 focus:ring-yellow-500 border-gray-300 rounded">
            <label for="show_metrics" class="ml-2 block text-sm text-gray-900">
              Show key metrics
            </label>
          </div>
          <div class="flex items-center">
            <input
              type="checkbox"
              id="show_verification"
              name="show_verification"
              value="true"
              checked={Map.get(@content, "show_verification", true)}
              class="h-4 w-4 text-yellow-600 focus:ring-yellow-500 border-gray-300 rounded">
            <label for="show_verification" class="ml-2 block text-sm text-gray-900">
              Show verification badges
            </label>
          </div>
          <div class="flex items-center">
            <input
              type="checkbox"
              id="show_dates"
              name="show_dates"
              value="true"
              checked={Map.get(@content, "show_dates", true)}
              class="h-4 w-4 text-yellow-600 focus:ring-yellow-500 border-gray-300 rounded">
            <label for="show_dates" class="ml-2 block text-sm text-gray-900">
              Show award dates
            </label>
          </div>
          <div class="flex items-center">
            <input
              type="checkbox"
              id="show_categories"
              name="show_categories"
              value="true"
              checked={Map.get(@content, "show_categories", false)}
              class="h-4 w-4 text-yellow-600 focus:ring-yellow-500 border-gray-300 rounded">
            <label for="show_categories" class="ml-2 block text-sm text-gray-900">
              Show award categories
            </label>
          </div>
        </div>

      </div>
    </.live_component>
    """
  end

  def handle_event("add_award", _params, socket) do
    content = socket.assigns.content
    current_awards = Map.get(content, "awards", [])

    new_award = %{
      "title" => "",
      "organization" => "",
      "date" => "",
      "category" => "professional",
      "level" => "corporate",
      "description" => "",
      "image_url" => "",
      "verification_url" => "",
      "featured" => false,
      "verified" => false
    }

    updated_content = Map.put(content, "awards", current_awards ++ [new_award])

    {:noreply, assign(socket, :content, updated_content)}
  end

  def handle_event("remove_award", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    content = socket.assigns.content
    current_awards = Map.get(content, "awards", [])

    updated_awards = List.delete_at(current_awards, index)
    updated_content = Map.put(content, "awards", updated_awards)

    {:noreply, assign(socket, :content, updated_content)}
  end

  def handle_event("add_metric", _params, socket) do
    content = socket.assigns.content
    current_metrics = Map.get(content, "metrics", [])

    new_metric = %{
      "label" => "",
      "value" => "",
      "context" => ""
    }

    updated_content = Map.put(content, "metrics", current_metrics ++ [new_metric])

    {:noreply, assign(socket, :content, updated_content)}
  end

  def handle_event("remove_metric", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    content = socket.assigns.content
    current_metrics = Map.get(content, "metrics", [])

    updated_metrics = List.delete_at(current_metrics, index)
    updated_content = Map.put(content, "metrics", updated_metrics)

    {:noreply, assign(socket, :content, updated_content)}
  end

  def handle_event("add_recognition", _params, socket) do
    content = socket.assigns.content
    current_recognition = Map.get(content, "recognition", [])

    new_recognition = %{
      "source" => "",
      "type" => "article",
      "title" => "",
      "date" => "",
      "url" => ""
    }

    updated_content = Map.put(content, "recognition", current_recognition ++ [new_recognition])

    {:noreply, assign(socket, :content, updated_content)}
  end

  def handle_event("remove_recognition", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    content = socket.assigns.content
    current_recognition = Map.get(content, "recognition", [])

    updated_recognition = List.delete_at(current_recognition, index)
    updated_content = Map.put(content, "recognition", updated_recognition)

    {:noreply, assign(socket, :content, updated_content)}
  end

  defp get_section_content(section) do
    case section.content do
      content when is_map(content) -> content
      content when is_binary(content) -> %{"description" => content}
      _ -> %{}
    end
  end
end
