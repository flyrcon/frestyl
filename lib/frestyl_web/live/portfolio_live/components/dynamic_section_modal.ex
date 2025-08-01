# lib/frestyl_web/live/portfolio_live/components/dynamic_section_modal.ex

defmodule FrestylWeb.PortfolioLive.Components.DynamicSectionModal do
  @moduledoc """
  Simplified, user-friendly section modal with smart field organization.
  No confusing tabs - just logical field flow that works.
  """

  use FrestylWeb, :live_component
  alias Frestyl.Portfolios.EnhancedSectionSystem

  @impl true
  def update(assigns, socket) do
    # Initialize form data from editing section or defaults
    form_data = case assigns[:editing_section] do
      %{content: content, title: title} when is_map(content) ->
        # Include the title from the section
        Map.put(content, "title", title)
      %{title: title} ->
        # If no content, at least get the title
        %{"title" => title}
      _ ->
        get_default_form_data(assigns.section_type)
    end

    IO.puts("🔧 MODAL UPDATE - Form data initialized: #{inspect(form_data)}")

    socket = socket
    |> assign(assigns)
    |> assign(:form_data, form_data)
    |> assign(:validation_errors, %{})
    |> assign(:save_status, nil)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4"
         phx-window-keydown="close_modal_on_escape"
         phx-key="Escape">

      <div class="bg-white rounded-xl shadow-2xl max-w-4xl w-full max-h-[95vh] overflow-hidden"
           phx-click={JS.exec("event.stopPropagation()")}>

        <div class="flex items-center justify-between p-6 border-b border-gray-200 bg-gradient-to-r from-blue-50 to-indigo-50">
          <div class="flex items-center">
            <div class="w-12 h-12 rounded-xl flex items-center justify-center mr-4 shadow-lg"
                 style={"background: linear-gradient(135deg, #{get_section_color(@section_type)} 0%, #{darken_color(get_section_color(@section_type))} 100%)"}>
              <span class="text-white text-xl"><%= get_section_icon(@section_type) %></span>
            </div>
            <div>
              <h3 class="text-xl font-bold text-gray-900">
                <%= if @editing_section, do: "Edit", else: "Create" %> <%= get_section_name(@section_type) %>
              </h3>
              <p class="text-sm text-gray-600 mt-1"><%= get_section_description(@section_type) %></p>
            </div>
          </div>

          <div class="flex items-center space-x-4">
            <div class="flex items-center space-x-2 min-w-[100px]">
              <%= case @save_status do %>
                <% :saving -> %>
                  <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-blue-600"></div>
                  <span class="text-sm text-blue-600 font-medium">Saving...</span>
                <% :saved -> %>
                  <svg class="w-4 h-4 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                  </svg>
                  <span class="text-sm text-green-600 font-medium">Saved!</span>
                <% :error -> %>
                  <svg class="w-4 h-4 text-red-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                  </svg>
                  <span class="text-sm text-red-600 font-medium">Error</span>
                <% _ -> %>
                  <span class="text-sm text-gray-500">Ready</span>
              <% end %>
            </div>

            <button phx-click="close_section_modal" phx-target={@myself}
                    class="p-2 text-gray-400 hover:text-gray-600 rounded-lg hover:bg-gray-100 transition-colors">
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>
        </div>

        <div class="flex-1 overflow-hidden">
          <div class="p-6 max-h-[calc(95vh-200px)] overflow-y-auto">

            <%= if @validation_errors != %{} do %>
              <div class="mb-6 p-4 bg-red-50 border border-red-200 rounded-lg">
                <div class="flex">
                  <svg class="flex-shrink-0 h-5 w-5 text-red-400" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
                  </svg>
                  <div class="ml-3">
                    <h3 class="text-sm font-medium text-red-800">Please fix these errors:</h3>
                    <ul class="mt-2 text-sm text-red-700 list-disc pl-5">
                      <%= for {field, errors} <- @validation_errors do %>
                        <%= for error <- List.wrap(errors) do %>
                          <li><%= humanize_field_name(field) %>: <%= error %></li>
                        <% end %>
                      <% end %>
                    </ul>
                  </div>
                </div>
              </div>
            <% end %>

            <form phx-submit="save_section" phx-target={@myself} id="section-form" class="space-y-8">

              <%= if @editing_section do %>
                <input type="hidden" name="section_id" value={@editing_section.id} />
                <input type="hidden" name="action" value="update" />
              <% else %>
                <input type="hidden" name="action" value="create" />
                <input type="hidden" name="section_type" value={@section_type} />
              <% end %>

              <div class="bg-blue-50 rounded-lg p-6 border border-blue-200">
                <h4 class="text-lg font-semibold text-blue-900 mb-4 flex items-center">
                  <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
                  </svg>
                  Basic Information
                </h4>

                <div class="mb-4">
                  <label class="block text-sm font-semibold text-blue-900 mb-2">
                    Section Title <span class="text-red-500">*</span>
                  </label>
                  <input type="text"
                         name="title"
                         value={Map.get(@form_data, "title", get_default_title(@section_type))}
                         placeholder={get_default_title(@section_type)}
                         required
                         class="w-full px-3 py-2 border border-blue-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 bg-white text-gray-900" />
                  <p class="text-xs text-blue-700 mt-1">This appears as the heading on your portfolio</p>
                </div>

                <%= render_core_fields(assigns) %>
              </div>

              <%= render_main_content_section(assigns) %>

              <%= render_additional_options(assigns) %>

              <div class="bg-gray-50 rounded-lg p-6 border border-gray-200">
                <h4 class="text-lg font-semibold text-gray-900 mb-4 flex items-center">
                  <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"/>
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                  </svg>
                  Settings
                </h4>

                <div class="flex items-center justify-between">
                  <div>
                    <label class="text-sm font-semibold text-gray-900">Section Visibility</label>
                    <p class="text-xs text-gray-600 mt-1">Show or hide this section on your portfolio</p>
                  </div>
                  <label class="relative inline-flex items-center cursor-pointer">
                    <input type="checkbox"
                           name="visible"
                           value="true"
                           checked={Map.get(@form_data, "visible", true)}
                           class="sr-only peer" />
                    <div class="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-blue-300 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600"></div>
                  </label>
                </div>
              </div>
            </form>
          </div>
        </div>

        <div class="px-6 py-4 bg-gray-50 border-t border-gray-200 flex items-center justify-between">
          <div class="flex items-center space-x-6 text-sm text-gray-600">
            <%= if supports_multiple_items?(@section_type) do %>
              <div class="flex items-center">
                <svg class="w-4 h-4 mr-2 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
                </svg>
                <span>Multiple items supported</span>
              </div>
            <% end %>
            <div class="flex items-center">
              <svg class="w-4 h-4 mr-2 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4"/>
              </svg>
              <span>Form validation enabled</span>
            </div>
          </div>

          <div class="flex items-center space-x-3">
            <button type="button"
                    phx-click="close_section_modal" phx-target={@myself}
                    class="px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50 transition-colors font-medium">
              Cancel
            </button>
            <button type="submit"
                    form="section-form"
                    class="px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors font-semibold shadow-sm">
              <%= if @editing_section, do: "Update Section", else: "Create Section" %>
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # SMART FIELD ORGANIZATION

  # Core Fields (Basic info that every section needs)
  defp render_core_fields(assigns) do
    section_config = EnhancedSectionSystem.get_section_config(assigns.section_type)
    fields = Map.get(section_config, :fields, %{})

    # Get core fields (non-items, non-advanced fields)
    core_fields = fields
    |> Enum.reject(fn {field_name, _config} ->
      field_name in [:items, :visible, :social_links, :contact_info, :video_type, :video_url, :background_image]
    end)

    assigns = assign(assigns, :core_fields, core_fields)

    ~H"""
    <%= if @core_fields != [] do %>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <%= for {field_name, field_config} <- @core_fields do %>
          <%= render_field(field_name, field_config, assigns) %>
        <% end %>
      </div>
    <% end %>
    """
  end

  # Main Content Section (Multi-items or rich content)
  defp render_main_content_section(assigns) do
    section_config = EnhancedSectionSystem.get_section_config(assigns.section_type)
    fields = Map.get(section_config, :fields, %{})

    case Map.get(fields, :items) do
      %{} = items_config ->
        render_items_section(assigns, items_config)
      _ ->
        # No items field, check for other main content
        ~H""
    end
  end

  # Items Section (Experience, Skills, Projects, etc.)
  defp render_items_section(assigns, items_config) do
    items = get_current_items(assigns)
    item_schema = Map.get(items_config, :item_schema, %{})
    required = Map.get(items_config, :required, false)

    assigns = Map.merge(assigns, %{
      items: items,
      item_schema: item_schema,
      required: required
    })

    ~H"""
    <div class="bg-white rounded-lg border-2 border-gray-200 p-6">
      <div class="flex items-center justify-between mb-6">
        <h4 class="text-lg font-semibold text-gray-900 flex items-center">
          <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>
          </svg>
          <%= get_items_label(@section_type) %>
          <%= if @required do %><span class="text-red-500 ml-1">*</span><% end %>
        </h4>
        <button type="button"
                phx-click="add_item" phx-target={@myself}
                class="inline-flex items-center px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white text-sm font-medium rounded-lg transition-colors shadow-sm">
          <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
          </svg>
          Add <%= get_item_name(@section_type) %>
        </button>
      </div>

      <!-- Items List -->
      <div class="space-y-4">
        <%= if @items == [] do %>
          <div class="text-center py-12 text-gray-500 border-2 border-dashed border-gray-300 rounded-lg bg-gray-50">
            <svg class="mx-auto h-16 w-16 text-gray-400 mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1" d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
            </svg>
            <h5 class="text-lg font-medium text-gray-900 mb-2">No <%= get_items_label(@section_type) %> Yet</h5>
            <p class="text-sm">Click "Add <%= get_item_name(@section_type) %>" to get started</p>
          </div>
        <% else %>
          <%= for {item, index} <- Enum.with_index(@items) do %>
            <%= render_item_card(item, index, @item_schema, assigns) %>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  # Additional Options (Media, social links, etc.)
  defp render_additional_options(assigns) do
    section_config = EnhancedSectionSystem.get_section_config(assigns.section_type)
    fields = Map.get(section_config, :fields, %{})

    # Get advanced fields
    advanced_fields = fields
    |> Enum.filter(fn {field_name, _config} ->
      field_name in [:social_links, :contact_info, :video_type, :video_url, :background_image]
    end)

    if advanced_fields != [] do
      assigns = assign(assigns, :advanced_fields, advanced_fields)

      ~H"""
      <div class="bg-purple-50 rounded-lg p-6 border border-purple-200">
        <h4 class="text-lg font-semibold text-purple-900 mb-4 flex items-center">
          <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z"/>
          </svg>
          Additional Options
        </h4>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <%= for {field_name, field_config} <- @advanced_fields do %>
            <%= render_field(field_name, field_config, assigns) %>
          <% end %>
        </div>
      </div>
      """
    else
      ~H""
    end
  end

  # Individual Item Card
  defp render_item_card(item, index, item_schema, assigns) do
    item_title = get_item_display_title(item, assigns.section_type)

    assigns = Map.merge(assigns, %{
      item: item,
      index: index,
      item_schema: item_schema,
      item_title: item_title
    })

    ~H"""
    <div class="border border-gray-200 rounded-lg p-5 bg-white shadow-sm hover:shadow-md transition-shadow">
      <div class="flex items-center justify-between mb-4">
        <h5 class="text-base font-semibold text-gray-900">
          <%= @item_title || "#{get_item_name(@section_type)} #{@index + 1}" %>
        </h5>
        <button type="button"
                phx-click="remove_item" phx-value-index={@index} phx-target={@myself}
                class="p-2 text-red-600 hover:text-red-800 hover:bg-red-50 rounded-lg transition-colors">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
          </svg>
        </button>
      </div>

      <!-- Item Fields Grid -->
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <%= for {item_field_name, item_field_config} <- @item_schema do %>
          <%= render_item_field(@item, @index, item_field_name, item_field_config) %>
        <% end %>
      </div>
    </div>
    """
  end

  # Field Renderers
  defp render_field(field_name, field_config, assigns) do
    field_type = Map.get(field_config, :type, :string)
    current_value = Map.get(assigns.form_data, to_string(field_name), "")

    case field_type do
      :string -> render_string_field(field_name, field_config, current_value)
      :text -> render_text_field(field_name, field_config, current_value)
      :select -> render_select_field(field_name, field_config, current_value)
      :array -> render_array_field(field_name, field_config, current_value)
      :map -> render_map_field(field_name, field_config, current_value)
      :file -> render_file_field(field_name, field_config, current_value)
      :date -> render_date_field(field_name, field_config, current_value)
      :integer -> render_integer_field(field_name, field_config, current_value)
      :boolean -> render_boolean_field(field_name, field_config, current_value)
      _ -> render_string_field(field_name, field_config, current_value)
    end
  end

  # Standard Field Templates
  defp render_string_field(field_name, field_config, current_value) do
    required = Map.get(field_config, :required, false)
    placeholder = Map.get(field_config, :placeholder, "")

    assigns = %{
      field_name: field_name,
      current_value: current_value || "",
      placeholder: placeholder,
      required: required
    }

    ~H"""
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-2">
        <%= humanize_field_name(@field_name) %>
        <%= if @required do %><span class="text-red-500">*</span><% end %>
      </label>
      <input type="text"
             name={@field_name}
             value={@current_value}
             placeholder={@placeholder}
             required={@required}
             class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
      <p class="text-xs text-gray-500 mt-1">Separate multiple items with commas</p>
    </div>
    """
  end

  defp render_map_field(field_name, field_config, current_value) do
    default_map = Map.get(field_config, :default, %{})
    current_map = case current_value do
      map when is_map(map) -> map
      _ -> default_map
    end

    assigns = %{
      field_name: field_name,
      current_map: current_map,
      default_map: default_map
    }

    ~H"""
    <div class="md:col-span-2">
      <label class="block text-sm font-medium text-gray-700 mb-2">
        <%= humanize_field_name(@field_name) %>
      </label>
      <div class="space-y-3 p-4 border border-gray-200 rounded-lg bg-gray-50">
        <%= for {key, _value} <- @default_map do %>
          <div class="flex items-center space-x-3">
            <label class="w-24 text-xs font-medium text-gray-600 capitalize flex-shrink-0"><%= key %>:</label>
            <input type="text"
                   name={"#{@field_name}[#{key}]"}
                   value={Map.get(@current_map, key, "")}
                   placeholder={"Enter #{key}"}
                   class="flex-1 px-3 py-2 text-sm border border-gray-300 rounded-md focus:ring-1 focus:ring-blue-500 focus:border-blue-500 bg-white" />
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_file_field(field_name, field_config, current_value) do
    required = Map.get(field_config, :required, false)
    accepts = Map.get(field_config, :accepts, "*/*")

    assigns = %{
      field_name: field_name,
      current_value: current_value || "",
      required: required,
      accepts: accepts
    }

    ~H"""
    <div class="md:col-span-2">
      <label class="block text-sm font-medium text-gray-700 mb-2">
        <%= humanize_field_name(@field_name) %>
        <%= if @required do %><span class="text-red-500">*</span><% end %>
      </label>
      <input type="file"
             name={@field_name}
             accept={@accepts}
             required={@required && @current_value == ""}
             class="w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-lg file:border-0 file:text-sm file:font-medium file:bg-blue-50 file:text-blue-700 hover:file:bg-blue-100" />
      <%= if @current_value != "" do %>
        <p class="text-xs text-green-600 mt-1">Current: <%= Path.basename(@current_value) %></p>
      <% end %>
    </div>
    """
  end

  defp render_date_field(field_name, field_config, current_value) do
    required = Map.get(field_config, :required, false)
    placeholder = Map.get(field_config, :placeholder, "MM/YYYY")

    assigns = %{
      field_name: field_name,
      current_value: current_value || "",
      placeholder: placeholder,
      required: required
    }

    ~H"""
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-2">
        <%= humanize_field_name(@field_name) %>
        <%= if @required do %><span class="text-red-500">*</span><% end %>
      </label>
      <input type="text"
             name={@field_name}
             value={@current_value}
             placeholder={@placeholder}
             required={@required}
             class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
      <p class="text-xs text-gray-500 mt-1">Format: MM/YYYY or "Present"</p>
    </div>
    """
  end

  defp render_integer_field(field_name, field_config, current_value) do
    required = Map.get(field_config, :required, false)
    placeholder = Map.get(field_config, :placeholder, "")

    assigns = %{
      field_name: field_name,
      current_value: current_value || "",
      placeholder: placeholder,
      required: required
    }

    ~H"""
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-2">
        <%= humanize_field_name(@field_name) %>
        <%= if @required do %><span class="text-red-500">*</span><% end %>
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

  defp render_boolean_field(field_name, field_config, current_value) do
    checked = case current_value do
      true -> true
      "true" -> true
      _ -> false
    end

    assigns = %{
      field_name: field_name,
      checked: checked
    }

    ~H"""
    <div class="md:col-span-2">
      <div class="flex items-center">
        <input type="checkbox"
               name={@field_name}
               value="true"
               checked={@checked}
               class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded" />
        <label class="ml-2 text-sm font-medium text-gray-700">
          <%= humanize_field_name(@field_name) %>
        </label>
      </div>
    </div>
    """
  end

  # Item Field Renderers
  defp render_item_field(item, index, field_name, field_config) do
    field_type = Map.get(field_config, :type, :string)
    current_value = Map.get(item, to_string(field_name), get_field_default(field_config))
    required = Map.get(field_config, :required, false)
    placeholder = Map.get(field_config, :placeholder, "")
    input_name = "items[#{index}][#{field_name}]"

    col_span = if field_type in [:text] or String.contains?(to_string(field_name), "description"), do: "md:col-span-2", else: ""

    case field_type do
      :string ->
        render_item_string_field(field_name, input_name, current_value, placeholder, required, col_span)
      :text ->
        render_item_text_field(field_name, input_name, current_value, placeholder, required, col_span)
      :select ->
        render_item_select_field(field_name, input_name, current_value, field_config, required, col_span)
      :array ->
        render_item_array_field(field_name, input_name, current_value, placeholder, required, col_span)
      :date ->
        render_item_date_field(field_name, input_name, current_value, placeholder, required, col_span)
      :integer ->
        render_item_integer_field(field_name, input_name, current_value, placeholder, required, col_span)
      :file ->
        render_item_file_field(field_name, input_name, current_value, field_config, required, col_span)
      _ ->
        render_item_string_field(field_name, input_name, current_value, placeholder, required, col_span)
    end
  end

  # Item Field Templates
  defp render_item_string_field(field_name, input_name, current_value, placeholder, required, col_span) do
    assigns = %{
      field_name: field_name,
      input_name: input_name,
      current_value: current_value,
      placeholder: placeholder,
      required: required,
      col_span: col_span
    }

    ~H"""
    <div class={@col_span}>
      <label class="block text-xs font-medium text-gray-700 mb-1">
        <%= humanize_field_name(@field_name) %>
        <%= if @required do %><span class="text-red-500">*</span><% end %>
      </label>
      <input type="text"
             name={@input_name}
             value={@current_value}
             placeholder={@placeholder}
             required={@required}
             class="w-full px-3 py-2 text-sm border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
    </div>
    """
  end

  defp render_item_text_field(field_name, input_name, current_value, placeholder, required, col_span) do
    assigns = %{
      field_name: field_name,
      input_name: input_name,
      current_value: current_value,
      placeholder: placeholder,
      required: required,
      col_span: col_span
    }

    ~H"""
    <div class={@col_span}>
      <label class="block text-xs font-medium text-gray-700 mb-1">
        <%= humanize_field_name(@field_name) %>
        <%= if @required do %><span class="text-red-500">*</span><% end %>
      </label>
      <textarea name={@input_name}
                rows="3"
                placeholder={@placeholder}
                required={@required}
                class="w-full px-3 py-2 text-sm border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500 resize-y"><%= @current_value %></textarea>
    </div>
    """
  end

  defp render_item_select_field(field_name, input_name, current_value, field_config, required, col_span) do
    options = Map.get(field_config, :options, [])

    assigns = %{
      field_name: field_name,
      input_name: input_name,
      current_value: current_value,
      options: options,
      required: required,
      col_span: col_span
    }

    ~H"""
    <div class={@col_span}>
      <label class="block text-xs font-medium text-gray-700 mb-1">
        <%= humanize_field_name(@field_name) %>
        <%= if @required do %><span class="text-red-500">*</span><% end %>
      </label>
      <select name={@input_name}
              required={@required}
              class="w-full px-3 py-2 text-sm border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
        <option value="">Select...</option>
        <%= for option <- @options do %>
          <option value={option} selected={@current_value == option}><%= option %></option>
        <% end %>
      </select>
    </div>
    """
  end

  defp render_item_array_field(field_name, input_name, current_value, placeholder, required, col_span) do
    display_value = case current_value do
      list when is_list(list) -> Enum.join(list, ", ")
      str when is_binary(str) -> str
      _ -> ""
    end

    assigns = %{
      field_name: field_name,
      input_name: input_name,
      display_value: display_value,
      placeholder: placeholder,
      required: required,
      col_span: col_span
    }

    ~H"""
    <div class={@col_span}>
      <label class="block text-xs font-medium text-gray-700 mb-1">
        <%= humanize_field_name(@field_name) %>
        <%= if @required do %><span class="text-red-500">*</span><% end %>
      </label>
      <input type="text"
             name={@input_name}
             value={@display_value}
             placeholder={@placeholder}
             required={@required}
             class="w-full px-3 py-2 text-sm border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
      <p class="text-xs text-gray-500 mt-1">Separate with commas</p>
    </div>
    """
  end

  defp render_item_date_field(field_name, input_name, current_value, placeholder, required, col_span) do
    assigns = %{
      field_name: field_name,
      input_name: input_name,
      current_value: current_value,
      placeholder: placeholder || "MM/YYYY",
      required: required,
      col_span: col_span
    }

    ~H"""
    <div class={@col_span}>
      <label class="block text-xs font-medium text-gray-700 mb-1">
        <%= humanize_field_name(@field_name) %>
        <%= if @required do %><span class="text-red-500">*</span><% end %>
      </label>
      <input type="text"
             name={@input_name}
             value={@current_value}
             placeholder={@placeholder}
             required={@required}
             class="w-full px-3 py-2 text-sm border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
      <p class="text-xs text-gray-500 mt-1">MM/YYYY or "Present"</p>
    </div>
    """
  end

  defp render_item_integer_field(field_name, input_name, current_value, placeholder, required, col_span) do
    assigns = %{
      field_name: field_name,
      input_name: input_name,
      current_value: current_value,
      placeholder: placeholder,
      required: required,
      col_span: col_span
    }

    ~H"""
    <div class={@col_span}>
      <label class="block text-xs font-medium text-gray-700 mb-1">
        <%= humanize_field_name(@field_name) %>
        <%= if @required do %><span class="text-red-500">*</span><% end %>
      </label>
      <input type="number"
             name={@input_name}
             value={@current_value}
             placeholder={@placeholder}
             required={@required}
             class="w-full px-3 py-2 text-sm border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
    </div>
    """
  end

  defp render_item_file_field(field_name, input_name, current_value, field_config, required, col_span) do
    accepts = Map.get(field_config, :accepts, "*/*")

    assigns = %{
      field_name: field_name,
      input_name: input_name,
      current_value: current_value,
      accepts: accepts,
      required: required,
      col_span: col_span
    }

    ~H"""
    <div class={@col_span}>
      <label class="block text-xs font-medium text-gray-700 mb-1">
        <%= humanize_field_name(@field_name) %>
        <%= if @required do %><span class="text-red-500">*</span><% end %>
      </label>
      <input type="file"
             name={@input_name}
             accept={@accepts}
             required={@required && @current_value == ""}
             class="w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-3 file:rounded file:border-0 file:text-sm file:font-medium file:bg-blue-50 file:text-blue-700 hover:file:bg-blue-100" />
    </div>
    """
  end

    defp render_text_field(field_name, field_config, current_value) do
    required = Map.get(field_config, :required, false)
    placeholder = Map.get(field_config, :placeholder, "")

    assigns = %{
      field_name: field_name,
      current_value: current_value || "",
      placeholder: placeholder,
      required: required
    }

    ~H"""
    <div class="md:col-span-2">
      <label class="block text-sm font-medium text-gray-700 mb-2">
        <%= humanize_field_name(@field_name) %>
        <%= if @required do %><span class="text-red-500">*</span><% end %>
      </label>
      <textarea name={@field_name}
                rows="4"
                placeholder={@placeholder}
                required={@required}
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 resize-y"><%= @current_value %></textarea>
    </div>
    """
  end

  defp render_select_field(field_name, field_config, current_value) do
    required = Map.get(field_config, :required, false)
    options = Map.get(field_config, :options, [])

    assigns = %{
      field_name: field_name,
      current_value: current_value || "",
      required: required,
      options: options
    }

    ~H"""
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-2">
        <%= humanize_field_name(@field_name) %>
        <%= if @required do %><span class="text-red-500">*</span><% end %>
      </label>
      <select name={@field_name}
              required={@required}
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
        <option value="">Select...</option>
        <%= for option <- @options do %>
          <option value={option} selected={@current_value == option}><%= option %></option>
        <% end %>
      </select>
    </div>
    """
  end

  defp render_array_field(field_name, field_config, current_value) do
    required = Map.get(field_config, :required, false)
    placeholder = Map.get(field_config, :placeholder, "")

    display_value = case current_value do
      list when is_list(list) -> Enum.join(list, ", ")
      str when is_binary(str) -> str
      _ -> ""
    end

    assigns = %{
      field_name: field_name,
      display_value: display_value,
      placeholder: placeholder,
      required: required
    }

    ~H"""
    <div class="md:col-span-2">
      <label class="block text-sm font-medium text-gray-700 mb-2">
        <%= humanize_field_name(@field_name) %>
        <%= if @required do %><span class="text-red-500">*</span><% end %>
      </label>
      <input type="text"
             name={@field_name}
             value={@display_value}
             placeholder={@placeholder}
             required={@required}
             class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
    </div>
    """
  end

  # EVENT HANDLERS
  @impl true
  def handle_event("add_item", _params, socket) do
    current_items = get_current_items(socket.assigns)
    new_item = create_empty_item(socket.assigns.section_type)
    updated_items = current_items ++ [new_item]

    updated_form_data = Map.put(socket.assigns.form_data, "items", updated_items)

    {:noreply, assign(socket, :form_data, updated_form_data)}
  end

  @impl true
  def handle_event("remove_item", %{"index" => index_str}, socket) do
    {index, _} = Integer.parse(index_str)
    current_items = get_current_items(socket.assigns)
    updated_items = List.delete_at(current_items, index)

    updated_form_data = Map.put(socket.assigns.form_data, "items", updated_items)

    {:noreply, assign(socket, :form_data, updated_form_data)}
  end

  @impl true
  def handle_event("save_section", params, socket) do
    IO.puts("🔧 SAVE_SECTION EVENT RECEIVED")
    IO.puts("🔧 Params: #{inspect(params, pretty: true)}")
    IO.puts("🔧 Section Type: #{socket.assigns.section_type}")
    IO.puts("🔧 Editing Section: #{inspect(socket.assigns.editing_section)}")

    socket = assign(socket, :save_status, :saving)

    {form_data, validation_errors} = process_form_params(params, socket.assigns.section_type)

    IO.puts("🔧 Processed Form Data: #{inspect(form_data, pretty: true)}")
    IO.puts("🔧 Validation Errors: #{inspect(validation_errors, pretty: true)}")

    if validation_errors == %{} do
      IO.puts("🔧 NO VALIDATION ERRORS - Sending to parent")
      send(self(), {:save_section, form_data, socket.assigns.editing_section})
      {:noreply, assign(socket, :save_status, :saved)}
    else
      IO.puts("🔧 VALIDATION ERRORS FOUND - Staying in modal")
      socket = socket
      |> assign(:form_data, form_data)
      |> assign(:validation_errors, validation_errors)
      |> assign(:save_status, :error)

      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("close_section_modal", _params, socket) do
    send(self(), :close_section_modal)
    {:noreply, socket}
  end

  # HELPER FUNCTIONS
  defp get_default_form_data(section_type) do
    EnhancedSectionSystem.get_default_content(section_type)
  end

  defp get_current_items(assigns) do
    case Map.get(assigns.form_data, "items") do
      items when is_list(items) -> items
      _ -> []
    end
  end

  defp create_empty_item(section_type) do
    section_config = EnhancedSectionSystem.get_section_config(section_type)
    fields = Map.get(section_config, :fields, %{})

    case Map.get(fields, :items) do
      %{item_schema: item_schema} ->
        Enum.reduce(item_schema, %{}, fn {field_name, field_config}, acc ->
          default_value = get_field_default(field_config)
          Map.put(acc, to_string(field_name), default_value)
        end)
      _ -> %{}
    end
  end

  defp get_field_default(field_config) do
    case field_config do
      %{default: default} -> default
      %{type: :string} -> ""
      %{type: :text} -> ""
      %{type: :array} -> []
      %{type: :integer} -> nil
      %{type: :boolean} -> false
      _ -> ""
    end
  end

  defp get_item_display_title(item, section_type) do
    case section_type do
      "skills" ->
        skill_name = Map.get(item, "skill_name", "")
        proficiency = Map.get(item, "proficiency", "")
        if skill_name != "" do
          "#{skill_name}" <> if(proficiency != "", do: " (#{proficiency})", else: "")
        else
          nil
        end
      "experience" ->
        title = Map.get(item, "title", "")
        company = Map.get(item, "company", "")
        if title != "" and company != "" do
          "#{title} at #{company}"
        else
          nil
        end
      "education" ->
        degree = Map.get(item, "degree", "")
        institution = Map.get(item, "institution", "")
        if degree != "" and institution != "" do
          "#{degree} at #{institution}"
        else
          nil
        end
      "projects" ->
        Map.get(item, "title", nil)
      _ ->
        Map.get(item, "title") || Map.get(item, "name", nil)
    end
  end

  defp process_form_params(params, section_type) do
    IO.puts("🔧 PROCESSING FORM PARAMS")
    IO.puts("🔧 Raw params: #{inspect(params, pretty: true)}")
    IO.puts("🔧 Section type: #{section_type}")

    # Extract basic fields
    form_data = %{
      "title" => Map.get(params, "title", ""),
      "visible" => Map.get(params, "visible") == "true"
    }

    IO.puts("🔧 Basic form data: #{inspect(form_data)}")

    # Process section-specific fields
    section_config = EnhancedSectionSystem.get_section_config(section_type)
    fields = Map.get(section_config, :fields, %{})

    IO.puts("🔧 Section fields: #{inspect(Map.keys(fields))}")

    {processed_data, _errors} = process_section_fields(params, fields, form_data)
    validation_errors = validate_form_data(processed_data, section_type)

    IO.puts("🔧 Final processed data: #{inspect(processed_data, pretty: true)}")
    IO.puts("🔧 Final validation errors: #{inspect(validation_errors, pretty: true)}")

    {processed_data, validation_errors}
  end

  defp process_section_fields(params, fields, form_data) do
    Enum.reduce(fields, {form_data, %{}}, fn {field_name, field_config}, {data_acc, errors_acc} ->
      field_name_str = to_string(field_name)
      field_type = Map.get(field_config, :type, :string)

      case field_type do
        :items ->
          items = extract_items_from_params(params, field_config)
          {Map.put(data_acc, "items", items), errors_acc}
        :array ->
          value = Map.get(params, field_name_str, "")
          array_value = if value != "", do: String.split(value, ",") |> Enum.map(&String.trim/1), else: []
          {Map.put(data_acc, field_name_str, array_value), errors_acc}
        :map ->
          map_data = extract_map_from_params(params, field_name_str, field_config)
          {Map.put(data_acc, field_name_str, map_data), errors_acc}
        :integer ->
          value = Map.get(params, field_name_str, "")
          integer_value = case Integer.parse(value) do
            {int, _} -> int
            :error -> nil
          end
          {Map.put(data_acc, field_name_str, integer_value), errors_acc}
        :boolean ->
          value = Map.get(params, field_name_str) == "true"
          {Map.put(data_acc, field_name_str, value), errors_acc}
        _ ->
          value = Map.get(params, field_name_str, "")
          {Map.put(data_acc, field_name_str, value), errors_acc}
      end
    end)
  end

  defp extract_items_from_params(params, field_config) do
    item_schema = Map.get(field_config, :item_schema, %{})

    # The form sends items as: "items" => %{"0" => %{...}, "1" => %{...}}
    case Map.get(params, "items") do
      items_map when is_map(items_map) ->
        # Convert the numbered map to a list of items
        items_map
        |> Enum.sort_by(fn {index_str, _item} -> String.to_integer(index_str) end)
        |> Enum.map(fn {_index, item_data} ->
          # Process each field in the item according to its schema
          Enum.reduce(item_schema, %{}, fn {item_field_name, item_field_config}, acc ->
            field_name_str = to_string(item_field_name)
            raw_value = Map.get(item_data, field_name_str, "")
            processed_value = process_item_field_value(raw_value, field_name_str, item_schema)
            Map.put(acc, field_name_str, processed_value)
          end)
        end)

      _ ->
        []
    end
  end

  defp extract_map_from_params(params, field_name, field_config) do
    default_map = Map.get(field_config, :default, %{})

    Enum.reduce(default_map, %{}, fn {key, _}, acc ->
      param_key = "#{field_name}[#{key}]"
      value = Map.get(params, param_key, "")
      Map.put(acc, key, value)
    end)
  end

  defp process_item_field_value(value, item_field, item_schema) do
    field_config = Map.get(item_schema, String.to_atom(item_field), %{})
    field_type = Map.get(field_config, :type, :string)

    case field_type do
      :array when is_binary(value) ->
        value |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
      :integer ->
        case Integer.parse(value) do
          {int, _} -> int
          :error -> nil
        end
      :boolean -> value == "true"
      _ -> value
    end
  end

  defp validate_form_data(data, section_type) do
    case EnhancedSectionSystem.validate_section_content(section_type, data) do
      %{valid: true} -> %{}
      %{valid: false, errors: errors} -> Map.new(errors)
    end
  end

  # CONFIGURATION HELPERS
  defp supports_multiple_items?(section_type) do
    EnhancedSectionSystem.supports_multiple?(section_type)
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
    section_config = EnhancedSectionSystem.get_section_config(section_type)
    case Map.get(section_config, :category) do
      "essential" -> "#3B82F6"    # Blue
      "professional" -> "#059669"  # Green
      "personal" -> "#7C3AED"     # Purple
      "flexible" -> "#DC2626"      # Red
      _ -> "#6B7280"              # Gray
    end
  end

  defp darken_color(hex_color) do
    case String.replace(hex_color, "#", "") do
      "3B82F6" -> "#1D4ED8"
      "059669" -> "#047857"
      "7C3AED" -> "#5B21B6"
      "DC2626" -> "#B91C1C"
      _ -> "#374151"
    end
  end

  defp get_items_label(section_type) do
    case section_type do
      "skills" -> "Skills"
      "experience" -> "Work Experience"
      "education" -> "Education"
      "projects" -> "Projects"
      "certifications" -> "Certifications"
      "testimonials" -> "Testimonials"
      "services" -> "Services"
      "writing" -> "Articles"
      "volunteer" -> "Volunteer Experience"
      _ -> "Items"
    end
  end

  defp get_item_name(section_type) do
    case section_type do
      "skills" -> "Skill"
      "experience" -> "Job"
      "education" -> "Education"
      "projects" -> "Project"
      "certifications" -> "Certification"
      "testimonials" -> "Testimonial"
      "services" -> "Service"
      "writing" -> "Article"
      "volunteer" -> "Experience"
      _ -> "Item"
    end
  end

  defp humanize_field_name(field_name) do
    field_name
    |> to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
end
