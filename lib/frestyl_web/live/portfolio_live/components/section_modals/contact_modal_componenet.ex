# lib/frestyl_web/live/portfolio_live/components/section_modals/contact_modal_component.ex
defmodule FrestylWeb.PortfolioLive.Components.ContactModalComponent do
  @moduledoc """
  Specialized modal for editing contact sections - contact methods, forms, availability
  """
  use FrestylWeb, :live_component
  alias FrestylWeb.PortfolioLive.Components.BaseSectionModalComponent

  def update(assigns, socket) do
    content = get_section_content(assigns.editing_section)

    socket = socket
    |> assign(assigns)
    |> assign(:content, content)
    |> assign(:modal_title, "Edit Contact Section")
    |> assign(:modal_description, "Configure how people can reach you")
    |> assign(:section_type, :contact)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <.live_component
      module={BaseSectionModalComponent}
      id="contact-modal"
      editing_section={@editing_section}
      modal_title={@modal_title}
      modal_description={@modal_description}
      section_type={@section_type}
      myself={@myself}>

      <!-- Contact Specific Fields -->
      <div class="space-y-6">

        <!-- Section Description -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Contact Message</label>
          <textarea
            name="description"
            rows="3"
            class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            placeholder="Let's connect! I'm always interested in new opportunities..."><%= Map.get(@content, "description", "") %></textarea>
        </div>

        <!-- Primary Contact Information -->
        <div class="border rounded-lg p-4 bg-gray-50">
          <h4 class="font-medium text-gray-900 mb-4">Contact Information</h4>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label class="block text-xs font-medium text-gray-700 mb-1">Email Address</label>
              <input
                type="email"
                name="email"
                value={Map.get(@content, "email", "")}
                placeholder="your@email.com"
                class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
            </div>
            <div>
              <label class="block text-xs font-medium text-gray-700 mb-1">Phone Number</label>
              <input
                type="tel"
                name="phone"
                value={Map.get(@content, "phone", "")}
                placeholder="+1 (555) 123-4567"
                class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
            </div>
            <div>
              <label class="block text-xs font-medium text-gray-700 mb-1">Location</label>
              <input
                type="text"
                name="location"
                value={Map.get(@content, "location", "")}
                placeholder="New York, NY or Remote"
                class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
            </div>
            <div>
              <label class="block text-xs font-medium text-gray-700 mb-1">Timezone</label>
              <select
                name="timezone"
                class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500">
                <option value="" selected={Map.get(@content, "timezone", "") == ""}>Select Timezone</option>
                <option value="EST" selected={Map.get(@content, "timezone") == "EST"}>Eastern (EST)</option>
                <option value="CST" selected={Map.get(@content, "timezone") == "CST"}>Central (CST)</option>
                <option value="MST" selected={Map.get(@content, "timezone") == "MST"}>Mountain (MST)</option>
                <option value="PST" selected={Map.get(@content, "timezone") == "PST"}>Pacific (PST)</option>
                <option value="UTC" selected={Map.get(@content, "timezone") == "UTC"}>UTC</option>
                <option value="GMT" selected={Map.get(@content, "timezone") == "GMT"}>GMT</option>
                <option value="CET" selected={Map.get(@content, "timezone") == "CET"}>Central European (CET)</option>
              </select>
            </div>
          </div>
        </div>

        <!-- Contact Methods -->
        <div class="border rounded-lg p-4 bg-gray-50">
          <div class="flex items-center justify-between mb-4">
            <h4 class="font-medium text-gray-900">Contact Methods</h4>
            <button
              type="button"
              phx-click="add_contact_method"
              phx-target={@myself}
              class="px-3 py-1 bg-blue-600 text-white text-sm rounded-md hover:bg-blue-700 transition-colors">
              + Add Method
            </button>
          </div>

          <div class="space-y-3" id="contact-methods-container">
            <%= for {method, index} <- Enum.with_index(get_contact_methods(@content)) do %>
              <div class="border rounded p-3 bg-white">
                <div class="grid grid-cols-1 md:grid-cols-3 gap-3 mb-3">
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Method</label>
                    <select
                      name={"contact_methods[#{index}][type]"}
                      class="w-full px-2 py-1 text-xs border border-gray-300 rounded focus:ring-1 focus:ring-blue-500">
                      <option value="email" selected={Map.get(method, "type") == "email"}>📧 Email</option>
                      <option value="phone" selected={Map.get(method, "type") == "phone"}>📞 Phone</option>
                      <option value="whatsapp" selected={Map.get(method, "type") == "whatsapp"}>💬 WhatsApp</option>
                      <option value="linkedin" selected={Map.get(method, "type") == "linkedin"}>💼 LinkedIn</option>
                      <option value="telegram" selected={Map.get(method, "type") == "telegram"}>✈️ Telegram</option>
                      <option value="discord" selected={Map.get(method, "type") == "discord"}>🎮 Discord</option>
                      <option value="slack" selected={Map.get(method, "type") == "slack"}>💬 Slack</option>
                      <option value="calendly" selected={Map.get(method, "type") == "calendly"}>📅 Calendly</option>
                      <option value="other" selected={Map.get(method, "type") == "other"}>🔗 Other</option>
                    </select>
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Label</label>
                    <input
                      type="text"
                      name={"contact_methods[#{index}][label]"}
                      value={Map.get(method, "label", "")}
                      placeholder="Business Email, Personal Phone"
                      class="w-full px-2 py-1 text-xs border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Value/Link</label>
                    <input
                      type="text"
                      name={"contact_methods[#{index}][value]"}
                      value={Map.get(method, "value", "")}
                      placeholder="contact@example.com, +1234567890"
                      class="w-full px-2 py-1 text-xs border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
                  </div>
                </div>

                <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
                  <div class="flex items-center">
                    <input
                      type="checkbox"
                      id={"preferred_#{index}"}
                      name={"contact_methods[#{index}][preferred]"}
                      value="true"
                      checked={Map.get(method, "preferred", false)}
                      class="h-3 w-3 text-blue-600 focus:ring-blue-500 border-gray-300 rounded">
                    <label for={"preferred_#{index}"} class="ml-1 block text-xs text-gray-900">
                      Preferred method
                    </label>
                  </div>
                  <div class="flex justify-end">
                    <button
                      type="button"
                      phx-click="remove_contact_method"
                      phx-target={@myself}
                      phx-value-index={index}
                      class="text-xs text-red-600 hover:text-red-800">
                      Remove
                    </button>
                  </div>
                </div>
              </div>
            <% end %>

            <%= if Enum.empty?(get_contact_methods(@content)) do %>
              <div class="text-center py-4 text-gray-500 text-sm">
                No contact methods added yet. Click "Add Method" to provide ways to reach you.
              </div>
            <% end %>
          </div>
        </div>

        <!-- Availability Settings -->
        <div class="border rounded-lg p-4 bg-gray-50">
          <h4 class="font-medium text-gray-900 mb-4">Availability</h4>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
            <div>
              <label class="block text-xs font-medium text-gray-700 mb-1">Current Status</label>
              <select
                name="availability_status"
                class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500">
                <option value="available" selected={get_availability_status(@content) == "available"}>🟢 Available</option>
                <option value="busy" selected={get_availability_status(@content) == "busy"}>🟡 Busy</option>
                <option value="unavailable" selected={get_availability_status(@content) == "unavailable"}>🔴 Unavailable</option>
                <option value="selective" selected={get_availability_status(@content) == "selective"}>🟠 Selective</option>
              </select>
            </div>
            <div>
              <label class="block text-xs font-medium text-gray-700 mb-1">Response Time</label>
              <select
                name="response_time"
                class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500">
                <option value="within_hour" selected={get_response_time(@content) == "within_hour"}>Within 1 hour</option>
                <option value="same_day" selected={get_response_time(@content) == "same_day"}>Same day</option>
                <option value="24_hours" selected={get_response_time(@content) == "24_hours"}>Within 24 hours</option>
                <option value="48_hours" selected={get_response_time(@content) == "48_hours"}>Within 48 hours</option>
                <option value="week" selected={get_response_time(@content) == "week"}>Within a week</option>
              </select>
            </div>
          </div>

          <div>
            <label class="block text-xs font-medium text-gray-700 mb-1">Availability Note</label>
            <textarea
              name="availability_note"
              rows="2"
              class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500"
              placeholder="Currently accepting new projects. Best reached via email..."><%= Map.get(@content, "availability_note", "") %></textarea>
          </div>
        </div>

        <!-- Contact Form Settings -->
        <div class="border rounded-lg p-4 bg-gray-50">
          <h4 class="font-medium text-gray-900 mb-4">Contact Form</h4>

          <div class="space-y-4">
            <div class="flex items-center">
              <input
                type="checkbox"
                id="show_contact_form"
                name="show_contact_form"
                value="true"
                checked={Map.get(@content, "show_contact_form", true)}
                class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded">
              <label for="show_contact_form" class="ml-2 block text-sm text-gray-900">
                Show contact form
              </label>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="block text-xs font-medium text-gray-700 mb-1">Form Submit URL</label>
                <input
                  type="url"
                  name="form_action"
                  value={Map.get(@content, "form_action", "")}
                  placeholder="https://formspree.io/f/your-form-id"
                  class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
              </div>
              <div>
                <label class="block text-xs font-medium text-gray-700 mb-1">Success Message</label>
                <input
                  type="text"
                  name="success_message"
                  value={Map.get(@content, "success_message", "")}
                  placeholder="Thanks! I'll get back to you soon."
                  class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500" />
              </div>
            </div>

            <!-- Form field options -->
            <div>
              <label class="block text-xs font-medium text-gray-700 mb-2">Required Form Fields</label>
              <div class="space-y-2">
                <div class="flex items-center">
                  <input
                    type="checkbox"
                    id="require_name"
                    name="require_name"
                    value="true"
                    checked={get_form_field_required(@content, "name")}
                    class="h-3 w-3 text-blue-600 focus:ring-blue-500 border-gray-300 rounded">
                  <label for="require_name" class="ml-2 block text-xs text-gray-900">Name</label>
                </div>
                <div class="flex items-center">
                  <input
                    type="checkbox"
                    id="require_email"
                    name="require_email"
                    value="true"
                    checked={get_form_field_required(@content, "email")}
                    class="h-3 w-3 text-blue-600 focus:ring-blue-500 border-gray-300 rounded">
                  <label for="require_email" class="ml-2 block text-xs text-gray-900">Email</label>
                </div>
                <div class="flex items-center">
                  <input
                    type="checkbox"
                    id="require_phone"
                    name="require_phone"
                    value="true"
                    checked={get_form_field_required(@content, "phone")}
                    class="h-3 w-3 text-blue-600 focus:ring-blue-500 border-gray-300 rounded">
                  <label for="require_phone" class="ml-2 block text-xs text-gray-900">Phone</label>
                </div>
                <div class="flex items-center">
                  <input
                    type="checkbox"
                    id="require_company"
                    name="require_company"
                    value="true"
                    checked={get_form_field_required(@content, "company")}
                    class="h-3 w-3 text-blue-600 focus:ring-blue-500 border-gray-300 rounded">
                  <label for="require_company" class="ml-2 block text-xs text-gray-900">Company</label>
                </div>
                <div class="flex items-center">
                  <input
                    type="checkbox"
                    id="require_budget"
                    name="require_budget"
                    value="true"
                    checked={get_form_field_required(@content, "budget")}
                    class="h-3 w-3 text-blue-600 focus:ring-blue-500 border-gray-300 rounded">
                  <label for="require_budget" class="ml-2 block text-xs text-gray-900">Budget Range</label>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Display Settings -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div class="flex items-center">
            <input
              type="checkbox"
              id="show_availability"
              name="show_availability"
              value="true"
              checked={Map.get(@content, "show_availability", true)}
              class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded">
            <label for="show_availability" class="ml-2 block text-sm text-gray-900">
              Show availability status
            </label>
          </div>
          <div class="flex items-center">
            <input
              type="checkbox"
              id="show_response_time"
              name="show_response_time"
              value="true"
              checked={Map.get(@content, "show_response_time", true)}
              class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded">
            <label for="show_response_time" class="ml-2 block text-sm text-gray-900">
              Show response time
            </label>
          </div>
          <div class="flex items-center">
            <input
              type="checkbox"
              id="show_location"
              name="show_location"
              value="true"
              checked={Map.get(@content, "show_location", true)}
              class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded">
            <label for="show_location" class="ml-2 block text-sm text-gray-900">
              Show location/timezone
            </label>
          </div>
          <div class="flex items-center">
            <input
              type="checkbox"
              id="enable_direct_links"
              name="enable_direct_links"
              value="true"
              checked={Map.get(@content, "enable_direct_links", true)}
              class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded">
            <label for="enable_direct_links" class="ml-2 block text-sm text-gray-900">
              Enable clickable contact links
            </label>
          </div>
        </div>

      </div>
    </.live_component>
    """
  end

  def handle_event("add_contact_method", _params, socket) do
    content = socket.assigns.content
    current_methods = get_contact_methods(content)

    new_method = %{
      "type" => "email",
      "label" => "",
      "value" => "",
      "preferred" => false
    }

    updated_content = put_contact_methods(content, current_methods ++ [new_method])

    {:noreply, assign(socket, :content, updated_content)}
  end

  def handle_event("remove_contact_method", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    content = socket.assigns.content
    current_methods = get_contact_methods(content)

    updated_methods = List.delete_at(current_methods, index)
    updated_content = put_contact_methods(content, updated_methods)

    {:noreply, assign(socket, :content, updated_content)}
  end

  defp get_section_content(section) do
    case section.content do
      content when is_map(content) -> content
      content when is_binary(content) -> %{"description" => content}
      _ -> %{}
    end
  end

  defp get_contact_methods(content) do
    Map.get(content, "contact_methods", [])
  end

  defp put_contact_methods(content, methods) do
    Map.put(content, "contact_methods", methods)
  end

  defp get_availability_status(content) do
    Map.get(content, "availability_status", "available")
  end

  defp get_response_time(content) do
    Map.get(content, "response_time", "24_hours")
  end

  defp get_form_field_required(content, field) do
    form_settings = Map.get(content, "form_settings", %{})
    required_fields = Map.get(form_settings, "required_fields", ["name", "email"])
    field in required_fields
  end
end
