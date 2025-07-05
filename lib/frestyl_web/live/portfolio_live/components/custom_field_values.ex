defmodule FrestylWeb.PortfolioLive.Components.CustomFieldValues do
  use Phoenix.LiveComponent
  import Phoenix.HTML.Form

  def render(assigns) do
    ~H"""
    <div class="custom-field-values">
      <%= if Enum.any?(@field_definitions) do %>
        <form phx-submit="save_field_values" phx-target={@target} class="space-y-6">
          <%= for definition <- @field_definitions do %>
            <div class="field-value-group">
              <%= render_field_input(definition, @field_values, assigns) %>
            </div>
          <% end %>

          <div class="flex justify-end pt-4 border-t border-gray-200">
            <button type="submit"
                    class="px-4 py-2 bg-blue-600 text-white rounded-md text-sm font-medium hover:bg-blue-700">
              Save Field Values
            </button>
          </div>
        </form>
      <% else %>
        <div class="text-center py-8 text-gray-500">
          <p>No custom fields defined. Add some field definitions first.</p>
        </div>
      <% end %>
    </div>
    """
  end

  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:field_values_map, fn ->
        build_field_values_map(assigns.field_values)
      end)

    {:ok, socket}
  end

  # Render different input types based on field definition
  defp render_field_input(%{field_type: "text"} = definition, field_values, assigns) do
    current_value = get_field_value(field_values, definition.field_name)

    assigns = assign(assigns, :definition, definition)
    assigns = assign(assigns, :current_value, current_value)

    ~H"""
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-2">
        <%= @definition.field_label %>
        <%= if @definition.is_required do %>
          <span class="text-red-500">*</span>
        <% end %>
      </label>

      <%= if @definition.field_description do %>
        <p class="text-xs text-gray-500 mb-2"><%= @definition.field_description %></p>
      <% end %>

      <input type="text"
             name={"field_values[#{@definition.field_name}]"}
             value={@current_value}
             required={@definition.is_required}
             class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
    </div>
    """
  end

  defp render_field_input(%{field_type: "rich_text"} = definition, field_values, assigns) do
    current_value = get_field_value(field_values, definition.field_name)

    assigns = assign(assigns, :definition, definition)
    assigns = assign(assigns, :current_value, current_value)

    ~H"""
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-2">
        <%= @definition.field_label %>
        <%= if @definition.is_required do %>
          <span class="text-red-500">*</span>
        <% end %>
      </label>

      <%= if @definition.field_description do %>
        <p class="text-xs text-gray-500 mb-2"><%= @definition.field_description %></p>
      <% end %>

      <textarea name={"field_values[#{@definition.field_name}]"}
                rows="4"
                required={@definition.is_required}
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500"><%= @current_value %></textarea>
    </div>
    """
  end

  defp render_field_input(%{field_type: "number"} = definition, field_values, assigns) do
    current_value = get_field_value(field_values, definition.field_name)
    validation_rules = definition.validation_rules || %{}

    assigns = assign(assigns, :definition, definition)
    assigns = assign(assigns, :current_value, current_value)
    assigns = assign(assigns, :validation_rules, validation_rules)

    ~H"""
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-2">
        <%= @definition.field_label %>
        <%= if @definition.is_required do %>
          <span class="text-red-500">*</span>
        <% end %>
      </label>

      <%= if @definition.field_description do %>
        <p class="text-xs text-gray-500 mb-2"><%= @definition.field_description %></p>
      <% end %>

      <input type="number"
             name={"field_values[#{@definition.field_name}]"}
             value={@current_value}
             required={@definition.is_required}
             min={@validation_rules["min_value"]}
             max={@validation_rules["max_value"]}
             step={if @validation_rules["integer_only"], do: "1", else: "any"}
             class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
    </div>
    """
  end

  defp render_field_input(%{field_type: "date"} = definition, field_values, assigns) do
    current_value = get_field_value(field_values, definition.field_name)

    assigns = assign(assigns, :definition, definition)
    assigns = assign(assigns, :current_value, current_value)

    ~H"""
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-2">
        <%= @definition.field_label %>
        <%= if @definition.is_required do %>
          <span class="text-red-500">*</span>
        <% end %>
      </label>

      <%= if @definition.field_description do %>
        <p class="text-xs text-gray-500 mb-2"><%= @definition.field_description %></p>
      <% end %>

      <input type="date"
             name={"field_values[#{@definition.field_name}]"}
             value={@current_value}
             required={@definition.is_required}
             class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
    </div>
    """
  end

  defp render_field_input(%{field_type: "url"} = definition, field_values, assigns) do
    current_value = get_field_value(field_values, definition.field_name)

    assigns = assign(assigns, :definition, definition)
    assigns = assign(assigns, :current_value, current_value)

    ~H"""
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-2">
        <%= @definition.field_label %>
        <%= if @definition.is_required do %>
          <span class="text-red-500">*</span>
        <% end %>
      </label>

      <%= if @definition.field_description do %>
        <p class="text-xs text-gray-500 mb-2"><%= @definition.field_description %></p>
      <% end %>

      <input type="url"
             name={"field_values[#{@definition.field_name}]"}
             value={@current_value}
             required={@definition.is_required}
             placeholder="https://example.com"
             class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
    </div>
    """
  end

  defp render_field_input(%{field_type: "email"} = definition, field_values, assigns) do
    current_value = get_field_value(field_values, definition.field_name)

    assigns = assign(assigns, :definition, definition)
    assigns = assign(assigns, :current_value, current_value)

    ~H"""
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-2">
        <%= @definition.field_label %>
        <%= if @definition.is_required do %>
          <span class="text-red-500">*</span>
        <% end %>
      </label>

      <%= if @definition.field_description do %>
        <p class="text-xs text-gray-500 mb-2"><%= @definition.field_description %></p>
      <% end %>

      <input type="email"
             name={"field_values[#{@definition.field_name}]"}
             value={@current_value}
             required={@definition.is_required}
             placeholder="example@domain.com"
             class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
    </div>
    """
  end

  defp render_field_input(%{field_type: "list"} = definition, field_values, assigns) do
    current_value = get_field_value(field_values, definition.field_name)
    validation_rules = definition.validation_rules || %{}
    allowed_values = validation_rules["allowed_values"]

    assigns = assign(assigns, :definition, definition)
    assigns = assign(assigns, :current_value, current_value)
    assigns = assign(assigns, :allowed_values, allowed_values)

    if allowed_values && is_list(allowed_values) do
      render_select_field(assigns)
    else
      render_tags_field(assigns)
    end
  end

  defp render_field_input(%{field_type: "boolean"} = definition, field_values, assigns) do
    current_value = get_field_value(field_values, definition.field_name)

    assigns = assign(assigns, :definition, definition)
    assigns = assign(assigns, :current_value, current_value)

    ~H"""
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-2">
        <%= @definition.field_label %>
      </label>

      <%= if @definition.field_description do %>
        <p class="text-xs text-gray-500 mb-2"><%= @definition.field_description %></p>
      <% end %>

      <div class="flex items-center space-x-6">
        <label class="flex items-center">
          <input type="radio"
                 name={"field_values[#{@definition.field_name}]"}
                 value="true"
                 checked={@current_value == "true" || @current_value == true}
                 class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300" />
          <span class="ml-2 text-sm text-gray-700">Yes</span>
        </label>
        <label class="flex items-center">
          <input type="radio"
                 name={"field_values[#{@definition.field_name}]"}
                 value="false"
                 checked={@current_value == "false" || @current_value == false}
                 class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300" />
          <span class="ml-2 text-sm text-gray-700">No</span>
        </label>
      </div>
    </div>
    """
  end

  defp render_field_input(%{field_type: "object"} = definition, field_values, assigns) do
    current_value = get_field_value(field_values, definition.field_name)
    json_value = if is_map(current_value), do: Jason.encode!(current_value, pretty: true), else: current_value || "{}"

    assigns = assign(assigns, :definition, definition)
    assigns = assign(assigns, :json_value, json_value)

    ~H"""
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-2">
        <%= @definition.field_label %>
        <%= if @definition.is_required do %>
          <span class="text-red-500">*</span>
        <% end %>
      </label>

      <%= if @definition.field_description do %>
        <p class="text-xs text-gray-500 mb-2"><%= @definition.field_description %></p>
      <% end %>

      <textarea name={"field_values[#{@definition.field_name}]"}
                rows="6"
                required={@definition.is_required}
                placeholder='{"key": "value"}'
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500 font-mono text-sm"><%= @json_value %></textarea>
      <p class="mt-1 text-xs text-gray-500">Enter valid JSON format</p>
    </div>
    """
  end

  defp render_field_input(definition, field_values, assigns) do
    # Fallback for unknown field types
    current_value = get_field_value(field_values, definition.field_name)

    assigns = assign(assigns, :definition, definition)
    assigns = assign(assigns, :current_value, current_value)

    ~H"""
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-2">
        <%= @definition.field_label %>
        <%= if @definition.is_required do %>
          <span class="text-red-500">*</span>
        <% end %>
      </label>

      <%= if @definition.field_description do %>
        <p class="text-xs text-gray-500 mb-2"><%= @definition.field_description %></p>
      <% end %>

      <input type="text"
             name={"field_values[#{@definition.field_name}]"}
             value={@current_value}
             required={@definition.is_required}
             class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
      <p class="mt-1 text-xs text-gray-400">Unknown field type: <%= @definition.field_type %></p>
    </div>
    """
  end

  # Helper for select field (list with allowed values)
  defp render_select_field(assigns) do
    ~H"""
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-2">
        <%= @definition.field_label %>
        <%= if @definition.is_required do %>
          <span class="text-red-500">*</span>
        <% end %>
      </label>

      <%= if @definition.field_description do %>
        <p class="text-xs text-gray-500 mb-2"><%= @definition.field_description %></p>
      <% end %>

      <select name={"field_values[#{@definition.field_name}]"}
              required={@definition.is_required}
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
        <option value="">Select an option...</option>
        <%= for value <- @allowed_values do %>
          <option value={value} selected={@current_value == value}><%= value %></option>
        <% end %>
      </select>
    </div>
    """
  end

  # Helper for tags field (list without allowed values)
  defp render_tags_field(assigns) do
    current_list = case assigns.current_value do
      list when is_list(list) -> Enum.join(list, ", ")
      string when is_binary(string) -> string
      _ -> ""
    end

    assigns = assign(assigns, :current_list, current_list)

    ~H"""
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-2">
        <%= @definition.field_label %>
        <%= if @definition.is_required do %>
          <span class="text-red-500">*</span>
        <% end %>
      </label>

      <%= if @definition.field_description do %>
        <p class="text-xs text-gray-500 mb-2"><%= @definition.field_description %></p>
      <% end %>

      <textarea name={"field_values[#{@definition.field_name}]"}
                rows="3"
                required={@definition.is_required}
                placeholder="Enter items separated by commas"
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500"><%= @current_list %></textarea>
      <p class="mt-1 text-xs text-gray-500">Separate multiple items with commas</p>
    </div>
    """
  end

  # Helper functions
  defp build_field_values_map(field_values) do
    Enum.reduce(field_values, %{}, fn value, acc ->
      Map.put(acc, value.field_name, value.value)
    end)
  end

  defp get_field_value(field_values, field_name) do
    case Enum.find(field_values, &(&1.field_name == field_name)) do
      nil -> ""
      %{value: %{"content" => content}} -> content
      %{value: value} when is_map(value) ->
        # Try to extract a reasonable string representation
        Map.get(value, "text") || Map.get(value, "value") || Jason.encode!(value)
      %{value: value} -> value
    end
  end
end
