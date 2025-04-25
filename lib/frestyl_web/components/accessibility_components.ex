# lib/frestyl_web/components/accessibility_components.ex
defmodule FrestylWeb.AccessibilityComponents do
  use Phoenix.Component

  def a11y_button(assigns) do
    ~H"""
    <button
      type={@type || "button"}
      class={[
        "inline-flex items-center border font-medium rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-offset-2",
        @size == "sm" && "px-2.5 py-1.5 text-xs",
        @size == "md" && "px-3 py-2 text-sm",
        @size == "lg" && "px-4 py-2 text-base",
        @variant == "primary" && "border-transparent text-white bg-indigo-600 hover:bg-indigo-700 focus:ring-indigo-500",
        @variant == "secondary" && "border-transparent text-indigo-700 bg-indigo-100 hover:bg-indigo-200 focus:ring-indigo-500",
        @variant == "outline" && "border-gray-300 text-gray-700 bg-white hover:bg-gray-50 focus:ring-indigo-500",
        @class
      ]}
      aria-label={@aria_label}
      disabled={@disabled}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  def a11y_toggle(assigns) do
    ~H"""
    <div class="flex items-center">
      <%= if @label do %>
        <span id={"#{@id}-label"} class="text-sm font-medium text-gray-700 mr-3">
          <%= @label %>
        </span>
      <% end %>
      <button
        type="button"
        id={@id}
        phx-click={@on_toggle}
        aria-pressed={@checked}
        aria-labelledby={if @label, do: "#{@id}-label"}
        aria-label={if !@label and @aria_label, do: @aria_label}
        class={[
          "relative inline-flex flex-shrink-0 h-6 w-11 border-2 border-transparent rounded-full cursor-pointer transition-colors ease-in-out duration-200 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500",
          @checked && "bg-indigo-600",
          !@checked && "bg-gray-200"
        ]}
      >
        <span
          aria-hidden="true"
          class={[
            "pointer-events-none inline-block h-5 w-5 rounded-full bg-white shadow transform ring-0 transition ease-in-out duration-200",
            @checked && "translate-x-5",
            !@checked && "translate-x-0"
          ]}
        ></span>
      </button>
    </div>
    """
  end

  def a11y_dialog(assigns) do
    ~H"""
    <div
      id={@id}
      class="fixed z-10 inset-0 overflow-y-auto"
      aria-labelledby={"#{@id}-title"}
      role="dialog"
      aria-modal="true"
      tabindex="0"
      hidden={!@show}
    >
      <div class="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
        <!-- Background overlay -->
        <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity" aria-hidden="true"></div>

        <!-- This element centers the modal contents -->
        <span class="hidden sm:inline-block sm:align-middle sm:h-screen" aria-hidden="true">&#8203;</span>

        <div
          class="inline-block align-bottom bg-white rounded-lg px-4 pt-5 pb-4 text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-lg sm:w-full sm:p-6"
          role="document"
        >
          <div class="sm:flex sm:items-start">
            <div class="mt-3 text-center sm:mt-0 sm:ml-4 sm:text-left w-full">
              <h3 class="text-lg leading-6 font-medium text-gray-900" id={"#{@id}-title"}>
                <%= @title %>
              </h3>

              <div class="mt-4">
                <%= render_slot(@inner_block) %>
              </div>
            </div>
          </div>

          <div class="mt-5 sm:mt-4 sm:flex sm:flex-row-reverse">
            <%= if @confirm_label do %>
              <button
                type="button"
                phx-click={@on_confirm}
                class="w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 bg-indigo-600 text-base font-medium text-white hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 sm:ml-3 sm:w-auto sm:text-sm"
              >
                <%= @confirm_label %>
              </button>
            <% end %>

            <button
              type="button"
              phx-click={@on_cancel}
              class="mt-3 w-full inline-flex justify-center rounded-md border border-gray-300 shadow-sm px-4 py-2 bg-white text-base font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 sm:mt-0 sm:w-auto sm:text-sm"
            >
              <%= @cancel_label || "Cancel" %>
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def a11y_tabs(assigns) do
    ~H"""
    <div>
      <div class="border-b border-gray-200">
        <nav class="-mb-px flex space-x-8" aria-label={@aria_label}>
          <%= for {tab, index} <- Enum.with_index(@tabs) do %>
            <button
              id={"tab-#{index}"}
              phx-click={@on_change}
              phx-value-index={index}
              class={[
                "whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm focus:outline-none focus:ring-inset focus:ring-indigo-500",
                @active_index == index && "border-indigo-500 text-indigo-600",
                @active_index != index && "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
              ]}
              aria-selected={@active_index == index}
              aria-controls={"tabpanel-#{index}"}
              role="tab"
            >
              <%= tab %>
            </button>
          <% end %>
        </nav>
      </div>

      <%= for {panel, index} <- Enum.with_index(@panels) do %>
        <div
          id={"tabpanel-#{index}"}
          aria-labelledby={"tab-#{index}"}
          role="tabpanel"
          tabindex="0"
          hidden={@active_index != index}
          class="py-4"
        >
          <%= render_slot(panel) %>
        </div>
      <% end %>
    </div>
    """
  end

  def a11y_alert(assigns) do
    ~H"""
    <div
      id={@id}
      class={[
        "rounded-md p-4 mb-4",
        @type == "info" && "bg-blue-50",
        @type == "success" && "bg-green-50",
        @type == "warning" && "bg-yellow-50",
        @type == "error" && "bg-red-50"
      ]}
      role="alert"
      aria-live="assertive"
    >
      <div class="flex">
        <div class="flex-shrink-0">
          <%= case @type do %>
            <% "info" -> %>
              <svg class="h-5 w-5 text-blue-400" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd" />
              </svg>
            <% "success" -> %>
              <svg class="h-5 w-5 text-green-400" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
              </svg>
            <% "warning" -> %>
              <svg class="h-5 w-5 text-yellow-400" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
              </svg>
            <% "error" -> %>
              <svg class="h-5 w-5 text-red-400" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
              </svg>
          <% end %>
        </div>
        <div class="ml-3">
          <h3 class={[
            "text-sm font-medium",
            @type == "info" && "text-blue-800",
            @type == "success" && "text-green-800",
            @type == "warning" && "text-yellow-800",
            @type == "error" && "text-red-800"
          ]}>
            <%= @title %>
          </h3>
          <div class={[
            "mt-2 text-sm",
            @type == "info" && "text-blue-700",
            @type == "success" && "text-green-700",
            @type == "warning" && "text-yellow-700",
            @type == "error" && "text-red-700"
          ]}>
            <%= render_slot(@inner_block) %>
          </div>
        </div>

        <%= if @dismissible do %>
          <div class="ml-auto pl-3">
            <div class="-mx-1.5 -my-1.5">
              <button
                type="button"
                phx-click={@on_dismiss}
                class={[
                  "inline-flex rounded-md p-1.5 focus:outline-none focus:ring-2 focus:ring-offset-2",
                  @type == "info" && "bg-blue-50 text-blue-500 hover:bg-blue-100 focus:ring-blue-600",
                  @type == "success" && "bg-green-50 text-green-500 hover:bg-green-100 focus:ring-green-600",
                  @type == "warning" && "bg-yellow-50 text-yellow-500 hover:bg-yellow-100 focus:ring-yellow-600",
                  @type == "error" && "bg-red-50 text-red-500 hover:bg-red-100 focus:ring-red-600"
                ]}
                aria-label="Dismiss"
              >
                <span class="sr-only">Dismiss</span>
                <svg class="h-5 w-5" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
                </svg>
              </button>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  def a11y_dropdown(assigns) do
    ~H"""
    <div class="relative" id={@id}>
      <button
        type="button"
        id={"#{@id}-button"}
        aria-haspopup="true"
        aria-expanded={@open}
        aria-controls={"#{@id}-menu"}
        phx-click={@on_toggle}
        class="inline-flex justify-center w-full rounded-md border border-gray-300 shadow-sm px-4 py-2 bg-white text-sm font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
      >
        <%= @label %>
        <svg class="-mr-1 ml-2 h-5 w-5" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
          <path fill-rule="evenodd" d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z" clip-rule="evenodd" />
        </svg>
      </button>

      <div
        id={"#{@id}-menu"}
        class="origin-top-right absolute right-0 mt-2 w-56 rounded-md shadow-lg bg-white ring-1 ring-black ring-opacity-5 focus:outline-none z-10"
        role="menu"
        aria-orientation="vertical"
        aria-labelledby={"#{@id}-button"}
        tabindex="-1"
        hidden={!@open}
      >
        <div class="py-1" role="none">
          <%= render_slot(@inner_block) %>
        </div>
      </div>
    </div>
    """
  end

  def a11y_dropdown_item(assigns) do
    ~H"""
    <a href={@href}
      class="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 hover:text-gray-900"
      role="menuitem"
      tabindex="-1"
      id={"menu-item-#{@id}"}
      phx-click={@on_click}
    >
      <%= render_slot(@inner_block) %>
    </a>
    """
  end

  def screen_reader_only(assigns) do
    ~H"""
    <span class="sr-only"><%= render_slot(@inner_block) %></span>
    """
  end

  def skip_to_content(assigns) do
    ~H"""
    <a
      href="#main-content"
      class="sr-only focus:not-sr-only focus:absolute focus:top-0 focus:left-0 focus:z-50 focus:p-4 focus:bg-white focus:text-indigo-600 focus:outline-none focus:ring-2 focus:ring-indigo-500"
    >
      Skip to main content
    </a>
    """
  end
end
