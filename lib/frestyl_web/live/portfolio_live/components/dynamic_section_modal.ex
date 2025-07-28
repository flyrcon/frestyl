# lib/frestyl_web/live/portfolio_live/components/dynamic_section_modal.ex

defmodule FrestylWeb.PortfolioLive.Components.DynamicSectionModal do
  @moduledoc """
  Dynamic modal component that renders appropriate forms based on section type.
  Supports all section types with smart field rendering and validation.
  """

  use FrestylWeb, :live_component
  alias Frestyl.Portfolios.EnhancedSectionSystem

  @impl true
  def update(assigns, socket) do
    # Initialize form data based on editing section or defaults
    form_data = if assigns[:editing_section] do
      assigns.editing_section.content || %{}
    else
      %{}
    end

    socket = socket
    |> assign(assigns)
    |> assign(:form_data, form_data)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4"
         phx-window-keydown="close_modal_on_escape"
         phx-key="Escape">
      <div class="bg-white rounded-xl shadow-2xl max-w-4xl w-full max-h-[90vh] overflow-hidden"
           phx-click-away="close_section_modal">

        <!-- Modal Header -->
        <div class="flex items-center justify-between p-6 border-b border-gray-200 bg-gray-50">
          <div class="flex items-center">
            <div class="w-10 h-10 rounded-lg flex items-center justify-center mr-3"
                 style={"background: linear-gradient(135deg, #{get_section_color(@section_type)} 0%, #{darken_color(get_section_color(@section_type))} 100%)"}>
              <span class="text-white text-lg"><%= get_section_icon(@section_type) %></span>
            </div>
            <div>
              <h3 class="text-xl font-bold text-gray-900">
                <%= if @editing_section, do: "Edit", else: "Create" %> <%= get_section_name(@section_type) %>
              </h3>
              <p class="text-sm text-gray-600 mt-1"><%= get_section_description(@section_type) %></p>
            </div>
          </div>
          <button phx-click="close_section_modal"
                  class="p-2 text-gray-400 hover:text-gray-600 rounded-lg hover:bg-gray-100 transition-colors">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </button>
        </div>

        <!-- Modal Content -->
        <div class="p-6 max-h-[calc(90vh-200px)] overflow-y-auto">
          <form phx-submit="save_section" class="space-y-6" id="section-form">
            <%= if @editing_section do %>
              <input type="hidden" name="section_id" value={@editing_section.id} />
              <input type="hidden" name="action" value="update" />
            <% else %>
              <input type="hidden" name="action" value="create" />
              <input type="hidden" name="section_type" value={@section_type} />
            <% end %>

            <!-- Section Title (Universal) -->
            <div class="bg-blue-50 rounded-lg p-4 border border-blue-200">
              <label class="block text-sm font-medium text-blue-900 mb-2">Section Title</label>
              <input type="text"
                     name="title"
                     value={get_current_value("title", @editing_section, @section_type)}
                     placeholder={get_default_title(@section_type)}
                     class="w-full px-3 py-2 border border-blue-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 bg-white" />
              <p class="text-xs text-blue-700 mt-1">This will be displayed as the section heading on your portfolio</p>
            </div>

            <!-- Dynamic Fields Based on Section Type -->
            <%= render_section_fields(assigns) %>

            <!-- Section Visibility -->
            <div class="bg-gray-50 rounded-lg p-4 border border-gray-200">
              <div class="flex items-center justify-between">
                <div>
                  <label class="text-sm font-medium text-gray-900">Section Visibility</label>
                  <p class="text-xs text-gray-600 mt-1">Control whether this section appears on your portfolio</p>
                </div>
                <label class="relative inline-flex items-center cursor-pointer">
                  <input type="checkbox"
                         name="visible"
                         value="true"
                         checked={get_current_value("visible", @editing_section, @section_type, true)}
                         class="sr-only peer">
                  <div class="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-blue-300 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600"></div>
                </label>
              </div>
            </div>
          </form>
        </div>

        <!-- Modal Footer -->
        <div class="px-6 py-4 bg-gray-50 border-t border-gray-200 flex items-center justify-between">
          <div class="text-sm text-gray-600 flex items-center">
            <svg class="w-4 h-4 mr-1 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
            </svg>
            Changes save automatically
          </div>
          <div class="flex items-center space-x-3">
            <button type="button"
                    phx-click="close_section_modal"
                    class="px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50 transition-colors">
              Cancel
            </button>
            <button type="submit"
                    form="section-form"
                    class="px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors font-medium">
              <%= if @editing_section, do: "Update Section", else: "Create Section" %>
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Render fields dynamically based on section type
  defp render_section_fields(assigns) do
    section_config = EnhancedSectionSystem.get_section_config(assigns.section_type)
    fields = Map.get(section_config, :fields, %{})

    assigns = assign(assigns, :fields, fields)

    ~H"""
    <div class="space-y-6" id="section-form">
      <%= for {field_name, field_config} <- @fields do %>
        <%= render_field(field_name, field_config, @editing_section, assigns) %>
      <% end %>
    </div>
    """
  end

  # Render individual fields based on their type
  defp render_field(field_name, field_config, editing_section, assigns) do
    field_type = Map.get(field_config, :type, :string)
    current_value = get_current_value(Atom.to_string(field_name), editing_section, assigns.section_type)

    case field_type do
      :string -> render_string_field(field_name, field_config, current_value, assigns)
      :text -> render_text_field(field_name, field_config, current_value, assigns)
      :select -> render_select_field(field_name, field_config, current_value, assigns)
      :boolean -> render_boolean_field(field_name, field_config, current_value, assigns)
      :integer -> render_integer_field(field_name, field_config, current_value, assigns)
      :array -> render_array_field(field_name, field_config, current_value, assigns)
      :map -> render_map_field(field_name, field_config, current_value, assigns)
      :file -> render_file_field(field_name, field_config, current_value, assigns)
      _ -> render_string_field(field_name, field_config, current_value, assigns)
    end
  end

  defp render_string_field(field_name, field_config, current_value, _assigns) do
    required = Map.get(field_config, :required, false)
    placeholder = Map.get(field_config, :placeholder, "")

    assigns = %{
      field_name: field_name,
      field_config: field_config,
      current_value: current_value,
      required: required,
      placeholder: placeholder,
      field_label: format_field_label(field_name)
    }

    ~H"""
    <div class="form-field">
      <label class="block text-sm font-medium text-gray-700 mb-2">
        <%= @field_label %>
        <%= if @required do %>
          <span class="text-red-500">*</span>
        <% end %>
      </label>
      <input type="text"
             name={@field_name}
             value={@current_value}
             placeholder={@placeholder}
             required={@required}
             class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
    </div>
    """
  end

  defp render_text_field(field_name, field_config, current_value, _assigns) do
    required = Map.get(field_config, :required, false)
    placeholder = Map.get(field_config, :placeholder, "")

    assigns = %{
      field_name: field_name,
      current_value: current_value,
      required: required,
      placeholder: placeholder,
      field_label: format_field_label(field_name)
    }

    ~H"""
    <div class="form-field">
      <label class="block text-sm font-medium text-gray-700 mb-2">
        <%= @field_label %>
        <%= if @required do %>
          <span class="text-red-500">*</span>
        <% end %>
      </label>
      <textarea name={@field_name}
                rows="4"
                placeholder={@placeholder}
                required={@required}
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 resize-y"><%= @current_value %></textarea>
    </div>
    """
  end

  defp render_select_field(field_name, field_config, current_value, _assigns) do
    required = Map.get(field_config, :required, false)
    options = Map.get(field_config, :options, [])
    default_value = Map.get(field_config, :default)

    assigns = %{
      field_name: field_name,
      current_value: current_value || default_value,
      required: required,
      options: options,
      field_label: format_field_label(field_name)
    }

    ~H"""
    <div class="form-field">
      <label class="block text-sm font-medium text-gray-700 mb-2">
        <%= @field_label %>
        <%= if @required do %>
          <span class="text-red-500">*</span>
        <% end %>
      </label>
      <select name={@field_name}
              required={@required}
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
        <%= for option <- @options do %>
          <option value={option} selected={option == @current_value}>
            <%= String.capitalize(option) %>
          </option>
        <% end %>
      </select>
    </div>
    """
  end

  defp render_boolean_field(field_name, field_config, current_value, _assigns) do
    default_value = Map.get(field_config, :default, false)
    checked = current_value || default_value

    assigns = %{
      field_name: field_name,
      checked: checked,
      field_label: format_field_label(field_name)
    }

    ~H"""
    <div class="form-field">
      <div class="flex items-center">
        <input type="checkbox"
               name={@field_name}
               value="true"
               checked={@checked}
               class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded">
        <label class="ml-2 block text-sm text-gray-900">
          <%= @field_label %>
        </label>
      </div>
    </div>
    """
  end

  defp render_array_field(field_name, field_config, current_value, assigns) do
    # Handle different array types
    item_fields = Map.get(field_config, :item_fields)

    if item_fields do
      render_complex_array_field(field_name, field_config, current_value, assigns)
    else
      render_simple_array_field(field_name, field_config, current_value, assigns)
    end
  end

  defp render_simple_array_field(field_name, field_config, current_value, assigns) do
    placeholder = Map.get(field_config, :placeholder, "")
    values = if is_list(current_value), do: current_value, else: []

    assigns = %{
      field_name: field_name,
      values: values,
      placeholder: placeholder,
      field_label: format_field_label(field_name),
      myself: assigns[:myself]  # Add this line
    }

    ~H"""
    <div class="form-field">
      <label class="block text-sm font-medium text-gray-700 mb-2">
        <%= @field_label %>
      </label>
      <div class="space-y-2" id={"#{@field_name}-array"}>
        <%= for {value, index} <- Enum.with_index(@values) do %>
          <div class="flex items-center space-x-2">
            <input type="text"
                  name={"#{@field_name}[]"}
                  value={value}
                  placeholder={@placeholder}
                  class="flex-1 px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
            <button type="button"
                    phx-click="remove_array_item"
                    phx-value-field={@field_name}
                    phx-value-index={index}
                    phx-target={@myself}
                    class="p-2 text-red-600 hover:text-red-700 hover:bg-red-50 rounded-lg">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
              </svg>
            </button>
          </div>
        <% end %>

        <!-- Add new item button -->
        <button type="button"
                phx-click="add_array_item"
                phx-value-field={@field_name}
                phx-target={@myself}
                class="w-full border-2 border-dashed border-gray-300 rounded-lg p-4 text-gray-500 hover:border-gray-400 hover:text-gray-600 transition-colors">
          <svg class="w-5 h-5 mx-auto mb-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
          </svg>
          Add Item
        </button>
      </div>
    </div>
    """
  end

  defp render_complex_array_field(field_name, field_config, current_value, assigns) do
    item_fields = Map.get(field_config, :item_fields, %{})
    items = if is_list(current_value), do: current_value, else: [%{}]

    assigns = %{
      field_name: field_name,
      items: items,
      item_fields: item_fields,
      field_label: format_field_label(field_name),
      myself: assigns[:myself]  # Add this line
    }

    ~H"""
    <div class="form-field">
      <label class="block text-sm font-medium text-gray-700 mb-3">
        <%= @field_label %>
      </label>

      <div class="space-y-4" id={"#{@field_name}-complex-array"}>
        <%= for {item, index} <- Enum.with_index(@items) do %>
          <div class="border border-gray-200 rounded-lg p-4 bg-gray-50">
            <div class="flex items-center justify-between mb-4">
              <h4 class="font-medium text-gray-900">Item <%= index + 1 %></h4>
              <button type="button"
                      phx-click="remove_complex_array_item"
                      phx-value-field={@field_name}
                      phx-value-index={index}
                      class="text-red-600 hover:text-red-700 hover:bg-red-100 p-1 rounded">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
                </svg>
              </button>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <%= for {sub_field_name, sub_field_config} <- @item_fields do %>
                <%= render_sub_field(sub_field_name, sub_field_config, item, index, @field_name) %>
              <% end %>
            </div>
          </div>
        <% end %>

        <!-- Add new complex item button -->
        <button type="button"
                phx-click="add_complex_array_item"
                phx-value-field={@field_name}
                class="w-full border-2 border-dashed border-gray-300 rounded-lg p-6 text-gray-500 hover:border-gray-400 hover:text-gray-600 transition-colors">
          <svg class="w-6 h-6 mx-auto mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
          </svg>
          Add New <%= String.capitalize(String.replace(to_string(field_name), "_", " ")) %>
        </button>
      </div>
    </div>
    """
  end

  defp render_sub_field(field_name, field_config, item, index, parent_field) do
    field_type = Map.get(field_config, :type, :string)
    current_value = Map.get(item, Atom.to_string(field_name), "")
    input_name = "#{parent_field}[#{index}][#{field_name}]"

    case field_type do
      :text ->
        render_sub_text_field(input_name, field_name, field_config, current_value)
      :select ->
        render_sub_select_field(input_name, field_name, field_config, current_value)
      :boolean ->
        render_sub_boolean_field(input_name, field_name, field_config, current_value)
      _ ->
        render_sub_string_field(input_name, field_name, field_config, current_value)
    end
  end

  defp render_sub_string_field(input_name, field_name, field_config, current_value) do
    required = Map.get(field_config, :required, false)
    placeholder = Map.get(field_config, :placeholder, "")

    assigns = %{
      input_name: input_name,
      current_value: current_value,
      required: required,
      placeholder: placeholder,
      field_label: format_field_label(field_name)
    }

    ~H"""
    <div>
      <label class="block text-xs font-medium text-gray-600 mb-1">
        <%= @field_label %>
        <%= if @required, do: raw("<span class='text-red-500'>*</span>") %>
      </label>
      <input type="text"
             name={@input_name}
             value={@current_value}
             placeholder={@placeholder}
             required={@required}
             class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500 focus:border-blue-500" />
    </div>
    """
  end

  defp render_sub_text_field(input_name, field_name, field_config, current_value) do
    placeholder = Map.get(field_config, :placeholder, "")

    assigns = %{
      input_name: input_name,
      current_value: current_value,
      placeholder: placeholder,
      field_label: format_field_label(field_name)
    }

    ~H"""
    <div class="md:col-span-2">
      <label class="block text-xs font-medium text-gray-600 mb-1">
        <%= @field_label %>
      </label>
      <textarea name={@input_name}
                rows="2"
                placeholder={@placeholder}
                class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500 focus:border-blue-500 resize-y"><%= @current_value %></textarea>
    </div>
    """
  end

  # Helper functions
  defp get_current_value(field_name, editing_section, section_type, default \\ nil) do
    if editing_section do
      content = editing_section.content || %{}
      Map.get(content, field_name, default)
    else
      # Get default from section configuration
      case EnhancedSectionSystem.get_default_content(section_type) do
        content when is_map(content) -> Map.get(content, field_name, default)
        _ -> default
      end
    end
  end

  defp get_default_title(section_type) do
    case EnhancedSectionSystem.get_section_config(section_type) do
      %{name: name} -> name
      _ -> "Section"
    end
  end

  defp get_section_name(section_type) do
    case EnhancedSectionSystem.get_section_config(section_type) do
      %{name: name} -> name
      _ -> String.capitalize(to_string(section_type))
    end
  end

  defp get_section_description(section_type) do
    case EnhancedSectionSystem.get_section_config(section_type) do
      %{description: description} -> description
      _ -> "Configure this section"
    end
  end

  defp get_section_icon(section_type) do
    case EnhancedSectionSystem.get_section_config(section_type) do
      %{icon: icon} -> icon
      _ -> "📄"
    end
  end

  defp get_section_color(section_type) do
    case EnhancedSectionSystem.get_section_config(section_type) do
      %{category: "introduction"} -> "#3B82F6"
      %{category: "professional"} -> "#059669"
      %{category: "education"} -> "#7C3AED"
      %{category: "skills"} -> "#DC2626"
      %{category: "work"} -> "#EA580C"
      %{category: "creative"} -> "#DB2777"
      %{category: "business"} -> "#1F2937"
      %{category: "recognition"} -> "#F59E0B"
      %{category: "credentials"} -> "#6366F1"
      %{category: "social_proof"} -> "#10B981"
      %{category: "content"} -> "#8B5CF6"
      %{category: "network"} -> "#06B6D4"
      %{category: "contact"} -> "#EF4444"
      %{category: "narrative"} -> "#F97316"
      _ -> "#6B7280"
    end
  end

  defp darken_color(hex_color) do
    # Simple color darkening - in production you might want a more sophisticated approach
    case hex_color do
      "#3B82F6" -> "#1D4ED8"
      "#059669" -> "#047857"
      "#7C3AED" -> "#5B21B6"
      "#DC2626" -> "#B91C1C"
      "#EA580C" -> "#C2410C"
      "#DB2777" -> "#BE185D"
      "#1F2937" -> "#111827"
      "#F59E0B" -> "#D97706"
      "#6366F1" -> "#4F46E5"
      "#10B981" -> "#059669"
      "#8B5CF6" -> "#7C3AED"
      "#06B6D4" -> "#0891B2"
      "#EF4444" -> "#DC2626"
      "#F97316" -> "#EA580C"
      _ -> "#4B5563"
    end
  end

  defp format_field_label(field_name) do
    field_name
    |> to_string()
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp render_file_field(field_name, field_config, current_value, _assigns) do
    accepts = Map.get(field_config, :accepts, "*")

    assigns = %{
      field_name: field_name,
      current_value: current_value,
      accepts: accepts,
      field_label: format_field_label(field_name)
    }

    ~H"""
    <div class="form-field">
      <label class="block text-sm font-medium text-gray-700 mb-2">
        <%= @field_label %>
      </label>
      <div class="border-2 border-dashed border-gray-300 rounded-lg p-6 text-center hover:border-gray-400 transition-colors">
        <input type="file"
               name={@field_name}
               accept={@accepts}
               class="hidden"
               id={"file-#{@field_name}"} />
        <label for={"file-#{@field_name}"} class="cursor-pointer">
          <svg class="w-8 h-8 text-gray-400 mx-auto mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/>
          </svg>
          <p class="text-sm text-gray-600">Click to upload or drag and drop</p>
          <p class="text-xs text-gray-500 mt-1">Accepts: <%= @accepts %></p>
        </label>
        <%= if @current_value && @current_value != "" do %>
          <div class="mt-3 p-2 bg-green-50 rounded-lg">
            <p class="text-sm text-green-700">Current file: <%= @current_value %></p>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_integer_field(field_name, field_config, current_value, _assigns) do
    required = Map.get(field_config, :required, false)
    placeholder = Map.get(field_config, :placeholder, "")

    assigns = %{
      field_name: field_name,
      current_value: current_value || 0,
      required: required,
      placeholder: placeholder,
      field_label: format_field_label(field_name)
    }

    ~H"""
    <div class="form-field">
      <label class="block text-sm font-medium text-gray-700 mb-2">
        <%= @field_label %>
        <%= if @required do %>
          <span class="text-red-500">*</span>
        <% end %>
      </label>
      <input type="number"
             name={@field_name}
             value={@current_value}
             placeholder={@placeholder}
             required={@required}
             class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
    </div>
    """
  end

  defp render_map_field(field_name, field_config, current_value, _assigns) do
    default_map = Map.get(field_config, :default, %{})
    current_map = if is_map(current_value), do: current_value, else: default_map

    assigns = %{
      field_name: field_name,
      current_map: current_map,
      field_label: format_field_label(field_name)
    }

    ~H"""
    <div class="form-field">
      <label class="block text-sm font-medium text-gray-700 mb-3">
        <%= @field_label %>
      </label>

      <div class="space-y-3">
        <%= for {key, value} <- @current_map do %>
          <div class="flex items-center space-x-3">
            <input type="text"
                   name={"#{@field_name}_keys[]"}
                   value={key}
                   placeholder="Key"
                   class="w-1/3 px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
            <input type="text"
                   name={"#{@field_name}_values[]"}
                   value={value}
                   placeholder="Value"
                   class="flex-1 px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
            <button type="button"
                    phx-click="remove_map_item"
                    phx-value-field={@field_name}
                    phx-value-key={key}
                    class="p-2 text-red-600 hover:text-red-700 hover:bg-red-50 rounded-lg">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
              </svg>
            </button>
          </div>
        <% end %>

        <button type="button"
                phx-click="add_map_item"
                phx-value-field={@field_name}
                class="w-full border-2 border-dashed border-gray-300 rounded-lg p-3 text-gray-500 hover:border-gray-400 hover:text-gray-600 transition-colors">
          <svg class="w-4 h-4 inline mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
          </svg>
          Add Field
        </button>
      </div>
    </div>
    """
  end

  defp render_sub_select_field(input_name, field_name, field_config, current_value) do
    options = Map.get(field_config, :options, [])
    default_value = Map.get(field_config, :default)

    assigns = %{
      input_name: input_name,
      current_value: current_value || default_value,
      options: options,
      field_label: format_field_label(field_name)
    }

    ~H"""
    <div>
      <label class="block text-xs font-medium text-gray-600 mb-1">
        <%= @field_label %>
      </label>
      <select name={@input_name}
              class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500 focus:border-blue-500">
        <%= for option <- @options do %>
          <option value={option} selected={option == @current_value}>
            <%= String.capitalize(option) %>
          </option>
        <% end %>
      </select>
    </div>
    """
  end

  defp render_sub_boolean_field(input_name, field_name, field_config, current_value) do
    default_value = Map.get(field_config, :default, false)
    checked = current_value || default_value

    assigns = %{
      input_name: input_name,
      checked: checked,
      field_label: format_field_label(field_name)
    }

    ~H"""
    <div class="flex items-center">
      <input type="checkbox"
             name={@input_name}
             value="true"
             checked={@checked}
             class="h-3 w-3 text-blue-600 focus:ring-blue-500 border-gray-300 rounded">
      <label class="ml-2 block text-xs text-gray-700">
        <%= @field_label %>
      </label>
    </div>
    """
  end

  @impl true
  def handle_event("add_array_item", %{"field" => field_name}, socket) do
    # Just acknowledge the event - don't do complex state management
    {:noreply, socket}
  end

  @impl true
  def handle_event("remove_array_item", %{"field" => field_name, "index" => index}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("add_complex_array_item", %{"field" => field_name}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("remove_complex_array_item", %{"field" => field_name, "index" => index}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("add_map_item", %{"field" => field_name}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("remove_map_item", %{"field" => field_name, "key" => key}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("save_section", params, socket) do
    # Send the event to the parent LiveView
    send(self(), {:save_section, params})
    {:noreply, socket}
  end

  @impl true
  def handle_event("close_section_modal", _params, socket) do
    send(self(), :close_section_modal)
    {:noreply, socket}
  end
end
