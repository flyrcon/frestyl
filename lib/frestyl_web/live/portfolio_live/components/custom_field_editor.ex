defmodule FrestylWeb.PortfolioLive.Components.CustomFieldEditor do
  use Phoenix.LiveComponent
  import Phoenix.HTML.Form

  def render(assigns) do
    ~H"""
    <div class="field-editor">
      <div class="p-6 border-b border-gray-200">
        <h3 class="text-lg font-semibold text-gray-900">
          <%= if @field_definition.id, do: "Edit Field", else: "Create New Field" %>
        </h3>
      </div>

      <form phx-submit="save" phx-target={@target} class="p-6 space-y-6">
        <!-- Field Basic Info -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Field Name*</label>
            <input type="text"
                   name="field_name"
                   value={@field_definition.field_name}
                   phx-debounce="300"
                   phx-change="validate_field_name"
                   phx-target={@myself}
                   placeholder="e.g., certification_name"
                   class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
            <p class="mt-1 text-xs text-gray-500">Used internally (lowercase, underscores only)</p>
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Display Label*</label>
            <input type="text"
                   name="field_label"
                   value={@field_definition.field_label}
                   placeholder="e.g., Certification Name"
                   class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
            <p class="mt-1 text-xs text-gray-500">What users see</p>
          </div>
        </div>

        <!-- Field Type -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Field Type*</label>
          <select name="field_type"
                  phx-change="field_type_changed"
                  phx-target={@myself}
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
            <%= for {value, label} <- field_type_options() do %>
              <option value={value} selected={@field_definition.field_type == value}><%= label %></option>
            <% end %>
          </select>
        </div>

        <!-- Field Description -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Description</label>
          <textarea name="field_description"
                    rows="2"
                    placeholder="Optional help text for users"
                    class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500"><%= @field_definition.field_description %></textarea>
        </div>

        <!-- Field Options -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div class="flex items-center">
            <input type="checkbox"
                   name="is_required"
                   checked={@field_definition.is_required}
                   class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded" />
            <label class="ml-2 text-sm text-gray-700">Required field</label>
          </div>

          <div class="flex items-center">
            <input type="checkbox"
                   name="is_public"
                   checked={@field_definition.is_public}
                   class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded" />
            <label class="ml-2 text-sm text-gray-700">Show in public portfolio</label>
          </div>
        </div>

        <!-- Validation Rules (Dynamic based on field type) -->
        <div class="border-t border-gray-200 pt-6">
          <h4 class="text-md font-medium text-gray-900 mb-4">Validation Rules</h4>

          <!-- Text Field Validation Rules -->
          <%= if @field_definition.field_type == "text" do %>
            <div class="space-y-4">
              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-2">Minimum Length</label>
                  <input type="number"
                         name="validation_rules[min_length]"
                         value={@validation_rules["min_length"]}
                         min="0"
                         class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-2">Maximum Length</label>
                  <input type="number"
                         name="validation_rules[max_length]"
                         value={@validation_rules["max_length"]}
                         min="1"
                         class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
                </div>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Pattern (Regex)</label>
                <input type="text"
                       name="validation_rules[pattern]"
                       value={@validation_rules["pattern"]}
                       placeholder="e.g., ^[A-Z].*"
                       class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
                <p class="mt-1 text-xs text-gray-500">Regular expression pattern (optional)</p>
              </div>
            </div>
          <% end %>

          <!-- Number Field Validation Rules -->
          <%= if @field_definition.field_type == "number" do %>
            <div class="space-y-4">
              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-2">Minimum Value</label>
                  <input type="number"
                         name="validation_rules[min_value]"
                         value={@validation_rules["min_value"]}
                         step="any"
                         class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-2">Maximum Value</label>
                  <input type="number"
                         name="validation_rules[max_value]"
                         value={@validation_rules["max_value"]}
                         step="any"
                         class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
                </div>
              </div>
              <div class="flex items-center">
                <input type="checkbox"
                       name="validation_rules[integer_only]"
                       checked={@validation_rules["integer_only"]}
                       class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded" />
                <label class="ml-2 text-sm text-gray-700">Integer values only</label>
              </div>
            </div>
          <% end %>

          <!-- List Field Validation Rules -->
          <%= if @field_definition.field_type == "list" do %>
            <div class="space-y-4">
              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-2">Minimum Items</label>
                  <input type="number"
                         name="validation_rules[min_items]"
                         value={@validation_rules["min_items"]}
                         min="0"
                         class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-2">Maximum Items</label>
                  <input type="number"
                         name="validation_rules[max_items]"
                         value={@validation_rules["max_items"]}
                         min="1"
                         class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
                </div>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Allowed Values</label>
                <textarea name="validation_rules[allowed_values]"
                          rows="3"
                          placeholder="One value per line"
                          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500"><%= format_allowed_values(@validation_rules["allowed_values"]) %></textarea>
                <p class="mt-1 text-xs text-gray-500">Enter one allowed value per line (optional)</p>
              </div>
            </div>
          <% end %>

          <!-- Default message for other field types -->
          <%= if @field_definition.field_type not in ["text", "number", "list"] do %>
            <p class="text-sm text-gray-500">No additional validation options for this field type.</p>
          <% end %>
        </div>

        <!-- Form Actions -->
        <div class="flex justify-end space-x-3 pt-6 border-t border-gray-200">
          <button type="button"
                  phx-click={@on_cancel}
                  phx-target={@target}
                  class="px-4 py-2 border border-gray-300 rounded-md text-sm font-medium text-gray-700 hover:bg-gray-50">
            Cancel
          </button>
          <button type="submit"
                  class="px-4 py-2 bg-blue-600 text-white rounded-md text-sm font-medium hover:bg-blue-700">
            <%= if @field_definition.id, do: "Update Field", else: "Create Field" %>
          </button>
        </div>

        <!-- Hidden fields -->
        <input type="hidden" name="portfolio_id" value={@portfolio_id} />
        <%= if @field_definition.id do %>
          <input type="hidden" name="id" value={@field_definition.id} />
        <% end %>
      </form>
    </div>
    """
  end

  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:validation_rules, fn -> assigns.field_definition.validation_rules || %{} end)
      |> assign_new(:field_name_error, fn -> nil end)

    {:ok, socket}
  end

  def handle_event("validate_field_name", %{"value" => field_name}, socket) do
    error = case validate_field_name_format(field_name) do
      :ok -> nil
      {:error, message} -> message
    end

    {:noreply, assign(socket, :field_name_error, error)}
  end

  def handle_event("field_type_changed", %{"value" => field_type}, socket) do
    # Reset validation rules when field type changes
    default_rules = default_validation_rules_for_type(field_type)

    field_definition = %{socket.assigns.field_definition |
      field_type: field_type,
      validation_rules: default_rules
    }

    {:noreply, socket
    |> assign(:field_definition, field_definition)
    |> assign(:validation_rules, default_rules)}
  end

  def handle_event("update_validation_rule", %{"rule" => rule, "value" => value}, socket) do
    current_rules = socket.assigns.validation_rules
    updated_rules = Map.put(current_rules, rule, parse_rule_value(rule, value))

    {:noreply, assign(socket, :validation_rules, updated_rules)}
  end

  # Helper functions
  defp field_type_options do
    [
      {"text", "Text"},
      {"rich_text", "Rich Text"},
      {"number", "Number"},
      {"date", "Date"},
      {"url", "URL"},
      {"email", "Email"},
      {"list", "List"},
      {"boolean", "Yes/No"},
      {"object", "Structured Data"}
    ]
  end

  defp validate_field_name_format(field_name) do
    cond do
      String.length(field_name) < 2 ->
        {:error, "Field name must be at least 2 characters"}

      String.length(field_name) > 50 ->
        {:error, "Field name must be less than 50 characters"}

      !Regex.match?(~r/^[a-z][a-z0-9_]*$/, field_name) ->
        {:error, "Field name must start with a letter and contain only lowercase letters, numbers, and underscores"}

      true -> :ok
    end
  end

  defp default_validation_rules_for_type("text"), do: %{"min_length" => 1, "max_length" => 500}
  defp default_validation_rules_for_type("number"), do: %{"min_value" => 0}
  defp default_validation_rules_for_type("list"), do: %{"min_items" => 1, "max_items" => 10}
  defp default_validation_rules_for_type(_), do: %{}

  # Fixed parse_rule_value functions with proper syntax
  defp parse_rule_value("min_length", value) when is_binary(value) do
    case Integer.parse(value) do
      {num, _} -> num
      :error -> 0
    end
  end

  defp parse_rule_value("max_length", value) when is_binary(value) do
    case Integer.parse(value) do
      {num, _} -> num
      :error -> 500
    end
  end

  defp parse_rule_value("min_value", value) when is_binary(value) do
    case Float.parse(value) do
      {num, _} -> num
      :error -> 0.0
    end
  end

  defp parse_rule_value("max_value", value) when is_binary(value) do
    case Float.parse(value) do
      {num, _} -> num
      :error -> 1000.0
    end
  end

  defp parse_rule_value("min_items", value) when is_binary(value) do
    case Integer.parse(value) do
      {num, _} -> num
      :error -> 0
    end
  end

  defp parse_rule_value("max_items", value) when is_binary(value) do
    case Integer.parse(value) do
      {num, _} -> num
      :error -> 10
    end
  end

  defp parse_rule_value("integer_only", "true"), do: true
  defp parse_rule_value("integer_only", _), do: false

  defp parse_rule_value("allowed_values", value) when is_binary(value) do
    value
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  # Fallback for any other rule type
  defp parse_rule_value(_, value), do: value

  defp format_allowed_values(nil), do: ""
  defp format_allowed_values(values) when is_list(values), do: Enum.join(values, "\n")
  defp format_allowed_values(_), do: ""
end
