defmodule FrestylWeb.PortfolioLive.Components.CustomFields do
  use Phoenix.LiveComponent
  import Phoenix.HTML.Form

  def render(assigns) do
    ~H"""
    <div class="custom-fields-manager">
      <!-- Field Definitions Header -->
      <div class="flex items-center justify-between mb-6">
        <div>
          <h3 class="text-lg font-semibold text-gray-900">Custom Fields</h3>
          <p class="text-sm text-gray-600 mt-1">Add custom fields to capture unique information</p>
        </div>
        <div class="flex space-x-3">
          <button phx-click="show_template_selector" phx-target={@myself}
                  class="px-4 py-2 border border-gray-300 rounded-lg text-sm font-medium text-gray-700 hover:bg-gray-50">
            Use Template
          </button>
          <button phx-click="add_custom_field" phx-target={@myself}
                  class="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700">
            Add Field
          </button>
        </div>
      </div>

      <!-- Template Selector Modal -->
      <%= if @show_template_selector do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div class="bg-white rounded-xl shadow-xl max-w-2xl w-full mx-4 max-h-[80vh] overflow-y-auto">
            <div class="p-6 border-b border-gray-200">
              <div class="flex items-center justify-between">
                <h3 class="text-lg font-semibold text-gray-900">Choose Field Template</h3>
                <button phx-click="hide_template_selector" phx-target={@myself}
                        class="text-gray-400 hover:text-gray-600">
                  <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                  </svg>
                </button>
              </div>
            </div>
            <div class="p-6">
              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <%= for {template_key, template_fields} <- @available_templates do %>
                  <div class="border border-gray-200 rounded-lg p-4 hover:border-blue-300 cursor-pointer transition-colors"
                       phx-click="apply_template" phx-value-template={template_key} phx-target={@myself}>
                    <h4 class="font-medium text-gray-900 mb-2"><%= template_display_name(template_key) %></h4>
                    <p class="text-sm text-gray-600 mb-3"><%= template_description(template_key) %></p>
                    <div class="text-xs text-gray-500">
                      Fields: <%= Enum.map(template_fields, & &1.field_label) |> Enum.join(", ") %>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Custom Field Definitions List -->
      <%= if Enum.any?(@field_definitions) do %>
        <div class="space-y-4 mb-6">
          <%= for {definition, index} <- Enum.with_index(@field_definitions) do %>
            <div class="bg-white border border-gray-200 rounded-lg p-4">
              <div class="flex items-start justify-between">
                <div class="flex-1">
                  <div class="flex items-center space-x-3 mb-2">
                    <span class="text-sm font-medium text-gray-900"><%= definition.field_label %></span>
                    <span class="px-2 py-1 bg-gray-100 text-gray-700 text-xs rounded-full">
                      <%= String.replace(definition.field_type, "_", " ") |> String.capitalize() %>
                    </span>
                    <%= if definition.is_required do %>
                      <span class="px-2 py-1 bg-red-100 text-red-700 text-xs rounded-full">Required</span>
                    <% end %>
                  </div>

                  <%= if definition.field_description do %>
                    <p class="text-sm text-gray-600"><%= definition.field_description %></p>
                  <% end %>

                  <!-- Field Validation Rules Preview -->
                  <%= if definition.validation_rules && map_size(definition.validation_rules) > 0 do %>
                    <div class="mt-2 text-xs text-gray-500">
                      Validation: <%= format_validation_rules(definition.validation_rules) %>
                    </div>
                  <% end %>
                </div>

                <div class="flex items-center space-x-2 ml-4">
                  <button phx-click="edit_field_definition" phx-value-id={definition.id} phx-target={@myself}
                          class="p-1 text-gray-400 hover:text-blue-600">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
                    </svg>
                  </button>
                  <button phx-click="delete_field_definition" phx-value-id={definition.id} phx-target={@myself}
                          data-confirm="Are you sure? This will also delete all values for this field."
                          class="p-1 text-gray-400 hover:text-red-600">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
                    </svg>
                  </button>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>

      <!-- Field Editor Modal -->
      <%= if @editing_field do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div class="bg-white rounded-xl shadow-xl max-w-lg w-full mx-4 max-h-[90vh] overflow-y-auto">
            <.live_component
              module={FrestylWeb.PortfolioLive.Components.CustomFieldEditor}
              id="field-editor"
              field_definition={@editing_field}
              portfolio_id={@portfolio_id}
              on_save="save_field_definition"
              on_cancel="cancel_field_edit"
              target={@myself} />
          </div>
        </div>
      <% end %>

      <!-- Custom Field Values Section -->
      <%= if @section && Enum.any?(@field_definitions) do %>
        <div class="border-t border-gray-200 pt-6">
          <h4 class="text-md font-medium text-gray-900 mb-4">Field Values</h4>
          <.live_component
            module={FrestylWeb.PortfolioLive.Components.CustomFieldValues}
            id="field-values"
            field_definitions={@field_definitions}
            field_values={@field_values}
            portfolio_id={@portfolio_id}
            section_id={@section.id}
            target={@myself} />
        </div>
      <% end %>

      <!-- Empty State -->
      <%= if Enum.empty?(@field_definitions) do %>
        <div class="text-center py-12 bg-gray-50 rounded-xl border-2 border-dashed border-gray-300">
          <div class="w-16 h-16 bg-gray-200 rounded-xl flex items-center justify-center mx-auto mb-4">
            <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
            </svg>
          </div>
          <h3 class="text-lg font-medium text-gray-900 mb-2">No Custom Fields</h3>
          <p class="text-gray-600 mb-6 max-w-sm mx-auto">
            Create custom fields to capture unique information that doesn't fit in standard sections.
          </p>
          <div class="space-y-3">
            <button phx-click="add_custom_field" phx-target={@myself}
                    class="px-6 py-3 bg-blue-600 text-white rounded-lg font-medium hover:bg-blue-700">
              Create First Field
            </button>
            <div class="text-sm text-gray-500">or</div>
            <button phx-click="show_template_selector" phx-target={@myself}
                    class="text-blue-600 hover:text-blue-700 font-medium">
              Start with a Template
            </button>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:show_template_selector, fn -> false end)
      |> assign_new(:editing_field, fn -> nil end)
      |> assign_new(:available_templates, fn ->
        Frestyl.Portfolios.CustomFieldDefinition.common_templates()
      end)

    {:ok, socket}
  end

  def handle_event("show_template_selector", _params, socket) do
    {:noreply, assign(socket, :show_template_selector, true)}
  end

  def handle_event("hide_template_selector", _params, socket) do
    {:noreply, assign(socket, :show_template_selector, false)}
  end

  def handle_event("add_custom_field", _params, socket) do
    new_field = %Frestyl.Portfolios.CustomFieldDefinition{
      portfolio_id: socket.assigns.portfolio_id,
      field_type: "text",
      is_public: true,
      is_required: false,
      validation_rules: %{},
      display_options: %{}
    }

    {:noreply, assign(socket, editing_field: new_field, show_template_selector: false)}
  end

  def handle_event("edit_field_definition", %{"id" => id}, socket) do
    field = Frestyl.Portfolios.get_custom_field_definition!(id)
    {:noreply, assign(socket, :editing_field, field)}
  end

  def handle_event("delete_field_definition", %{"id" => id}, socket) do
    field = Frestyl.Portfolios.get_custom_field_definition!(id)

    case Frestyl.Portfolios.delete_custom_field_definition(field) do
      {:ok, _} ->
        updated_definitions = Enum.reject(socket.assigns.field_definitions, &(&1.id == field.id))
        send(self(), {:custom_fields_updated, updated_definitions})
        {:noreply, assign(socket, :field_definitions, updated_definitions)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete field")}
    end
  end

  def handle_event("apply_template", %{"template" => template_key}, socket) do
    case Frestyl.Portfolios.apply_field_template(socket.assigns.portfolio_id, template_key) do
      {:ok, results} ->
        # Refresh field definitions
        updated_definitions = Frestyl.Portfolios.list_custom_field_definitions(socket.assigns.portfolio_id)
        send(self(), {:custom_fields_updated, updated_definitions})

        {:noreply, socket
        |> assign(:field_definitions, updated_definitions)
        |> assign(:show_template_selector, false)
        |> put_flash(:info, "Template applied successfully!")}

      {:error, message} ->
        {:noreply, put_flash(socket, :error, message)}
    end
  end

  def handle_event("save_field_definition", field_params, socket) do
    case save_or_update_field(socket.assigns.editing_field, field_params) do
      {:ok, _field} ->
        updated_definitions = Frestyl.Portfolios.list_custom_field_definitions(socket.assigns.portfolio_id)
        send(self(), {:custom_fields_updated, updated_definitions})

        {:noreply, socket
        |> assign(:field_definitions, updated_definitions)
        |> assign(:editing_field, nil)
        |> put_flash(:info, "Field saved successfully!")}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to save field: #{format_errors(changeset)}")}
    end
  end

  def handle_event("cancel_field_edit", _params, socket) do
    {:noreply, assign(socket, :editing_field, nil)}
  end

  # Helper functions
  defp save_or_update_field(%{id: nil}, params) do
    Frestyl.Portfolios.create_custom_field_definition(params)
  end

  defp save_or_update_field(field, params) do
    Frestyl.Portfolios.update_custom_field_definition(field, params)
  end

  defp template_display_name("social_metrics"), do: "Social Media Metrics"
  defp template_display_name("certifications"), do: "Certifications & Licenses"
  defp template_display_name("languages"), do: "Languages"
  defp template_display_name("awards"), do: "Awards & Recognition"
  defp template_display_name(key), do: String.replace(key, "_", " ") |> String.capitalize()

  defp template_description("social_metrics"), do: "Track follower counts, engagement rates, and platform metrics"
  defp template_description("certifications"), do: "Professional certifications, licenses, and credentials"
  defp template_description("languages"), do: "Spoken languages and proficiency levels"
  defp template_description("awards"), do: "Awards, honors, and recognition received"
  defp template_description(_), do: "A collection of related custom fields"

  defp format_validation_rules(rules) do
    rules
    |> Enum.map(fn {key, value} -> "#{key}: #{value}" end)
    |> Enum.join(", ")
  end

  defp format_errors(changeset) do
    changeset.errors
    |> Enum.map(fn {field, {message, _}} -> "#{field}: #{message}" end)
    |> Enum.join(", ")
  end
end
