# lib/frestyl_web/live/portfolio_live/components/section_modals/services_modal_component.ex
defmodule FrestylWeb.PortfolioLive.Components.ServicesModalComponent do
  @moduledoc """
  Specialized modal for editing services sections - business packages, pricing, features
  """
  use FrestylWeb, :live_component
  alias FrestylWeb.PortfolioLive.Components.BaseSectionModalComponent

  def update(assigns, socket) do
    content = get_section_content(assigns.editing_section)

    socket = socket
    |> assign(assigns)
    |> assign(:content, content)
    |> assign(:modal_title, "Edit Services")
    |> assign(:modal_description, "Configure your service offerings and pricing")
    |> assign(:section_type, :services)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <.live_component
      module={BaseSectionModalComponent}
      id="services-modal"
      editing_section={@editing_section}
      modal_title={@modal_title}
      modal_description={@modal_description}
      section_type={@section_type}
      myself={@myself}>

      <!-- Services Specific Fields -->
      <div class="space-y-6">

        <!-- Section Description -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Services Overview</label>
          <textarea
            name="description"
            rows="3"
            class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            placeholder="Overview of your professional services and what you offer..."><%= Map.get(@content, "description", "") %></textarea>
        </div>

        <!-- Display Settings -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Layout Style</label>
            <select
              name="layout_style"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
              <option value="cards" selected={get_layout_style(@content) == "cards"}>Service Cards</option>
              <option value="pricing_table" selected={get_layout_style(@content) == "pricing_table"}>Pricing Table</option>
              <option value="packages" selected={get_layout_style(@content) == "packages"}>Package Tiers</option>
              <option value="list" selected={get_layout_style(@content) == "list"}>Simple List</option>
            </select>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Services Per Row</label>
            <select
              name="services_per_row"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
              <option value="1" selected={get_services_per_row(@content) == 1}>1 Column</option>
              <option value="2" selected={get_services_per_row(@content) == 2}>2 Columns</option>
              <option value="3" selected={get_services_per_row(@content) == 3}>3 Columns</option>
              <option value="4" selected={get_services_per_row(@content) == 4}>4 Columns</option>
            </select>
          </div>
        </div>

        <!-- Service Items -->
        <div class="border rounded-lg p-4 bg-gray-50">
          <div class="flex items-center justify-between mb-4">
            <h4 class="font-medium text-gray-900">Service Offerings</h4>
            <button
              type="button"
              phx-click="add_service"
              phx-target={@myself}
              class="px-3 py-1 bg-emerald-600 text-white text-sm rounded-md hover:bg-emerald-700 transition-colors">
              + Add Service
            </button>
          </div>

          <div class="space-y-6" id="services-container">
            <%= for {service, index} <- Enum.with_index(Map.get(@content, "services", [])) do %>
              <div class="border rounded-lg p-4 bg-white relative">
                <!-- Remove button -->
                <button
                  type="button"
                  phx-click="remove_service"
                  phx-target={@myself}
                  phx-value-index={index}
                  class="absolute top-2 right-2 p-1 text-red-500 hover:text-red-700">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                  </svg>
                </button>

                <!-- Service basic info -->
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Service Name</label>
                    <input
                      type="text"
                      name={"services[#{index}][name]"}
                      value={Map.get(service, "name", "")}
                      placeholder="Web Development, Consulting, Design"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-emerald-500" />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Service Category</label>
                    <input
                      type="text"
                      name={"services[#{index}][category]"}
                      value={Map.get(service, "category", "")}
                      placeholder="Development, Strategy, Creative"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-emerald-500" />
                  </div>
                </div>

                <!-- Description -->
                <div class="mb-4">
                  <label class="block text-xs font-medium text-gray-700 mb-1">Service Description</label>
                  <textarea
                    name={"services[#{index}][description]"}
                    rows="3"
                    class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-emerald-500"
                    placeholder="Detailed description of what this service includes..."><%= Map.get(service, "description", "") %></textarea>
                </div>

                <!-- Pricing -->
                <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-4">
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Pricing Type</label>
                    <select
                      name={"services[#{index}][pricing_type]"}
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-emerald-500">
                      <option value="fixed" selected={Map.get(service, "pricing_type") == "fixed"}>Fixed Price</option>
                      <option value="hourly" selected={Map.get(service, "pricing_type") == "hourly"}>Hourly Rate</option>
                      <option value="monthly" selected={Map.get(service, "pricing_type") == "monthly"}>Monthly</option>
                      <option value="project" selected={Map.get(service, "pricing_type") == "project"}>Per Project</option>
                      <option value="custom" selected={Map.get(service, "pricing_type") == "custom"}>Custom Quote</option>
                    </select>
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Price</label>
                    <input
                      type="text"
                      name={"services[#{index}][price]"}
                      value={Map.get(service, "price", "")}
                      placeholder="$1,500, $150/hr, Starting at $500"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-emerald-500" />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Currency</label>
                    <select
                      name={"services[#{index}][currency]"}
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-emerald-500">
                      <option value="USD" selected={Map.get(service, "currency", "USD") == "USD"}>USD ($)</option>
                      <option value="EUR" selected={Map.get(service, "currency") == "EUR"}>EUR (€)</option>
                      <option value="GBP" selected={Map.get(service, "currency") == "GBP"}>GBP (£)</option>
                      <option value="CAD" selected={Map.get(service, "currency") == "CAD"}>CAD ($)</option>
                    </select>
                  </div>
                </div>

                <!-- Features/Deliverables -->
                <div class="mb-4">
                  <label class="block text-xs font-medium text-gray-700 mb-1">Features/Deliverables</label>
                  <textarea
                    name={"services[#{index}][features]"}
                    rows="3"
                    class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-emerald-500"
                    placeholder="• Custom website design&#10;• Mobile responsive layout&#10;• SEO optimization&#10;• 30 days support"><%= format_features_for_textarea(Map.get(service, "features", [])) %></textarea>
                  <p class="text-xs text-gray-500 mt-1">Use bullet points (•) for each feature</p>
                </div>

                <!-- Timeline and process -->
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Typical Timeline</label>
                    <input
                      type="text"
                      name={"services[#{index}][timeline]"}
                      value={Map.get(service, "timeline", "")}
                      placeholder="2-4 weeks, 1-2 months"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-emerald-500" />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Availability</label>
                    <select
                      name={"services[#{index}][availability]"}
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-emerald-500">
                      <option value="available" selected={Map.get(service, "availability") == "available"}>Available</option>
                      <option value="limited" selected={Map.get(service, "availability") == "limited"}>Limited Spots</option>
                      <option value="waitlist" selected={Map.get(service, "availability") == "waitlist"}>Waitlist Only</option>
                      <option value="unavailable" selected={Map.get(service, "availability") == "unavailable"}>Not Available</option>
                    </select>
                  </div>
                </div>

                <!-- Service links -->
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Portfolio/Examples URL</label>
                    <input
                      type="url"
                      name={"services[#{index}][portfolio_url]"}
                      value={Map.get(service, "portfolio_url", "")}
                      placeholder="https://example.com/portfolio"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-emerald-500" />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Booking/Contact URL</label>
                    <input
                      type="url"
                      name={"services[#{index}][booking_url]"}
                      value={Map.get(service, "booking_url", "")}
                      placeholder="https://calendly.com/yourname"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-emerald-500" />
                  </div>
                </div>

                <!-- Service flags -->
                <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                  <div class="flex items-center">
                    <input
                      type="checkbox"
                      id={"featured_service_#{index}"}
                      name={"services[#{index}][featured]"}
                      value="true"
                      checked={Map.get(service, "featured", false)}
                      class="h-4 w-4 text-emerald-600 focus:ring-emerald-500 border-gray-300 rounded">
                    <label for={"featured_service_#{index}"} class="ml-2 block text-xs text-gray-900">
                      Featured service
                    </label>
                  </div>
                  <div class="flex items-center">
                    <input
                      type="checkbox"
                      id={"popular_#{index}"}
                      name={"services[#{index}][popular]"}
                      value="true"
                      checked={Map.get(service, "popular", false)}
                      class="h-4 w-4 text-emerald-600 focus:ring-emerald-500 border-gray-300 rounded">
                    <label for={"popular_#{index}"} class="ml-2 block text-xs text-gray-900">
                      Most popular
                    </label>
                  </div>
                  <div class="flex items-center">
                    <input
                      type="checkbox"
                      id={"rush_available_#{index}"}
                      name={"services[#{index}][rush_available]"}
                      value="true"
                      checked={Map.get(service, "rush_available", false)}
                      class="h-4 w-4 text-emerald-600 focus:ring-emerald-500 border-gray-300 rounded">
                    <label for={"rush_available_#{index}"} class="ml-2 block text-xs text-gray-900">
                      Rush delivery available
                    </label>
                  </div>
                </div>
              </div>
            <% end %>

            <%= if length(Map.get(@content, "services", [])) == 0 do %>
              <div class="text-center py-8 text-gray-500">
                <svg class="w-12 h-12 mx-auto mb-3 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2-2v2m8 0V6a2 2 0 002 2h2a2 2 0 002-2V6m0 0v6a2 2 0 01-2 2H6a2 2 0 01-2-2V6a2 2 0 012-2h12a2 2 0 012 2z"/>
                </svg>
                <p>No services added yet</p>
                <p class="text-sm">Click "Add Service" to showcase your professional offerings</p>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Payment & Booking Settings -->
        <div class="border rounded-lg p-4 bg-gray-50">
          <h4 class="font-medium text-gray-900 mb-4">Payment & Booking</h4>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
            <div>
              <label class="block text-xs font-medium text-gray-700 mb-1">Payment Methods Accepted</label>
              <input
                type="text"
                name="payment_methods"
                value={Enum.join(Map.get(@content, "payment_methods", []), ", ")}
                placeholder="PayPal, Stripe, Bank Transfer, Crypto"
                class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-emerald-500" />
              <p class="text-xs text-gray-500 mt-1">Separate with commas</p>
            </div>
            <div>
              <label class="block text-xs font-medium text-gray-700 mb-1">Payment Terms</label>
              <select
                name="payment_terms"
                class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-emerald-500">
                <option value="upfront" selected={Map.get(@content, "payment_terms") == "upfront"}>100% Upfront</option>
                <option value="50_50" selected={Map.get(@content, "payment_terms") == "50_50"}>50% Upfront, 50% Completion</option>
                <option value="monthly" selected={Map.get(@content, "payment_terms") == "monthly"}>Monthly Billing</option>
                <option value="milestone" selected={Map.get(@content, "payment_terms") == "milestone"}>Milestone-based</option>
                <option value="net_30" selected={Map.get(@content, "payment_terms") == "net_30"}>Net 30</option>
              </select>
            </div>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label class="block text-xs font-medium text-gray-700 mb-1">Booking Calendar URL</label>
              <input
                type="url"
                name="booking_calendar"
                value={Map.get(@content, "booking_calendar", "")}
                placeholder="https://calendly.com/yourname/consultation"
                class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-emerald-500" />
            </div>
            <div>
              <label class="block text-xs font-medium text-gray-700 mb-1">Consultation Fee</label>
              <input
                type="text"
                name="consultation_fee"
                value={Map.get(@content, "consultation_fee", "")}
                placeholder="Free, $100, $150/hour"
                class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-emerald-500" />
            </div>
          </div>
        </div>

        <!-- Display Settings -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div class="flex items-center">
            <input
              type="checkbox"
              id="show_pricing"
              name="show_pricing"
              value="true"
              checked={Map.get(@content, "show_pricing", true)}
              class="h-4 w-4 text-emerald-600 focus:ring-emerald-500 border-gray-300 rounded">
            <label for="show_pricing" class="ml-2 block text-sm text-gray-900">
              Show pricing information
            </label>
          </div>
          <div class="flex items-center">
            <input
              type="checkbox"
              id="show_timeline"
              name="show_timeline"
              value="true"
              checked={Map.get(@content, "show_timeline", true)}
              class="h-4 w-4 text-emerald-600 focus:ring-emerald-500 border-gray-300 rounded">
            <label for="show_timeline" class="ml-2 block text-sm text-gray-900">
              Show delivery timelines
            </label>
          </div>
          <div class="flex items-center">
            <input
              type="checkbox"
              id="show_availability"
              name="show_availability"
              value="true"
              checked={Map.get(@content, "show_availability", true)}
              class="h-4 w-4 text-emerald-600 focus:ring-emerald-500 border-gray-300 rounded">
            <label for="show_availability" class="ml-2 block text-sm text-gray-900">
              Show availability status
            </label>
          </div>
          <div class="flex items-center">
            <input
              type="checkbox"
              id="enable_booking_buttons"
              name="enable_booking_buttons"
              value="true"
              checked={Map.get(@content, "enable_booking_buttons", true)}
              class="h-4 w-4 text-emerald-600 focus:ring-emerald-500 border-gray-300 rounded">
            <label for="enable_booking_buttons" class="ml-2 block text-sm text-gray-900">
              Enable booking buttons
            </label>
          </div>
        </div>

      </div>
    </.live_component>
    """
  end

  def handle_event("add_service", _params, socket) do
    content = socket.assigns.content
    current_services = Map.get(content, "services", [])

    new_service = %{
      "name" => "",
      "category" => "",
      "description" => "",
      "pricing_type" => "fixed",
      "price" => "",
      "currency" => "USD",
      "features" => [],
      "timeline" => "",
      "availability" => "available",
      "portfolio_url" => "",
      "booking_url" => "",
      "featured" => false,
      "popular" => false,
      "rush_available" => false
    }

    updated_content = Map.put(content, "services", current_services ++ [new_service])

    {:noreply, assign(socket, :content, updated_content)}
  end

  def handle_event("remove_service", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    content = socket.assigns.content
    current_services = Map.get(content, "services", [])

    updated_services = List.delete_at(current_services, index)
    updated_content = Map.put(content, "services", updated_services)

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
    Map.get(content, "layout_style", "cards")
  end

  defp get_services_per_row(content) do
    Map.get(content, "services_per_row", 3)
  end

  defp format_features_for_textarea(features) when is_list(features) do
    features
    |> Enum.map(fn feature ->
      feature = if is_map(feature), do: Map.get(feature, "text", feature), else: feature
      if String.starts_with?(feature, "•"), do: feature, else: "• #{feature}"
    end)
    |> Enum.join("\n")
  end
  defp format_features_for_textarea(_), do: ""
end
