# File: lib/frestyl_web/live/portfolio_live/enhanced_portfolio_editor/logo_branding_component.ex
defmodule FrestylWeb.PortfolioLive.EnhancedPortfolioEditor.LogoBrandingComponent do
  use FrestylWeb, :live_component

  @impl true
  def mount(socket) do
    socket = socket
    |> assign(:show_logo_options, false)
    |> assign(:logo_style, "initials")  # Options: "initials", "none", "custom"
    |> assign(:show_frestyl_branding, true)
    |> assign(:branding_position, "footer")  # Options: "footer", "header", "none"

    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    # Safely handle all assigns with defaults
    current_user = assigns[:current_user] || %{name: "User", email: "user@example.com"}
    portfolio = assigns[:portfolio] || %{}
    customization = assigns[:customization] || %{}

    # Get user initials from the current_user
    user_initials = get_user_initials(current_user)

    socket = socket
    |> assign(:current_user, current_user)
    |> assign(:portfolio, portfolio)
    |> assign(:customization, customization)
    |> assign(:user_initials, user_initials)
    |> assign(:show_logo_options, false)
    |> assign(:logo_style, Map.get(customization, "logo_style", "initials"))
    |> assign(:show_frestyl_branding, Map.get(customization, "show_frestyl_branding", true))
    |> assign(:branding_position, Map.get(customization, "branding_position", "footer"))
    |> assign(assigns)

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle_logo_options", _params, socket) do
    {:noreply, assign(socket, :show_logo_options, !socket.assigns.show_logo_options)}
  end

  @impl true
  def handle_event("update_logo_style", %{"style" => style}, socket) do
    socket = socket
    |> assign(:logo_style, style)
    |> assign(:show_logo_options, false)

    # Update portfolio customization
    customization_update = %{"logo_style" => style}
    send(self(), {:update_portfolio_customization, customization_update})

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_frestyl_branding", _params, socket) do
    new_value = !socket.assigns.show_frestyl_branding
    socket = assign(socket, :show_frestyl_branding, new_value)

    # Update portfolio customization
    customization_update = %{"show_frestyl_branding" => new_value}
    send(self(), {:update_portfolio_customization, customization_update})

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_branding_position", %{"position" => position}, socket) do
    socket = assign(socket, :branding_position, position)

    # Update portfolio customization
    customization_update = %{"branding_position" => position}
    send(self(), {:update_portfolio_customization, customization_update})

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="logo-branding-component">
      <!-- Logo & Branding Section in Customization Panel -->
      <div class="bg-white rounded-lg border border-gray-200 p-4 mb-4">
        <div class="flex items-center justify-between mb-3">
          <h4 class="text-sm font-semibold text-gray-900">Logo & Branding</h4>
          <button
            phx-click="toggle_logo_options"
            phx-target={@myself}
            class="text-blue-600 hover:text-blue-700 text-sm">
            <%= if @show_logo_options, do: "Done", else: "Customize" %>
          </button>
        </div>

        <!-- Current Logo Preview -->
        <div class="flex items-center space-x-3 mb-3">
          <%= case @logo_style do %>
            <% "initials" -> %>
              <div class="w-10 h-10 bg-blue-600 text-white rounded-lg flex items-center justify-center font-semibold text-sm">
                <%= @user_initials %>
              </div>
              <span class="text-sm text-gray-600">Personal initials logo</span>

            <% "none" -> %>
              <div class="w-10 h-10 bg-gray-200 rounded-lg flex items-center justify-center">
                <svg class="w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                </svg>
              </div>
              <span class="text-sm text-gray-600">No logo</span>

            <% "custom" -> %>
              <div class="w-10 h-10 bg-gradient-to-br from-purple-500 to-blue-500 rounded-lg flex items-center justify-center">
                <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
                </svg>
              </div>
              <span class="text-sm text-gray-600">Custom logo</span>
          <% end %>
        </div>

        <!-- Logo Options -->
        <%= if @show_logo_options do %>
          <div class="space-y-3 border-t border-gray-100 pt-3">
            <!-- Initials Logo -->
            <button
              phx-click="update_logo_style"
              phx-value-style="initials"
              phx-target={@myself}
              class={[
                "w-full flex items-center p-3 rounded-lg border-2 transition-colors text-left",
                if(@logo_style == "initials",
                  do: "border-blue-500 bg-blue-50",
                  else: "border-gray-200 hover:border-gray-300")
              ]}>
              <div class="w-8 h-8 bg-blue-600 text-white rounded-md flex items-center justify-center font-semibold text-xs mr-3">
                <%= @user_initials %>
              </div>
              <div>
                <p class="text-sm font-medium text-gray-900">Personal Initials</p>
                <p class="text-xs text-gray-500">Clean, professional initials logo</p>
              </div>
            </button>

            <!-- No Logo -->
            <button
              phx-click="update_logo_style"
              phx-value-style="none"
              phx-target={@myself}
              class={[
                "w-full flex items-center p-3 rounded-lg border-2 transition-colors text-left",
                if(@logo_style == "none",
                  do: "border-blue-500 bg-blue-50",
                  else: "border-gray-200 hover:border-gray-300")
              ]}>
              <div class="w-8 h-8 bg-gray-200 rounded-md flex items-center justify-center mr-3">
                <svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                </svg>
              </div>
              <div>
                <p class="text-sm font-medium text-gray-900">No Logo</p>
                <p class="text-xs text-gray-500">Minimal design without logo</p>
              </div>
            </button>

            <!-- Custom Logo (Future Feature) -->
            <button
              disabled
              class="w-full flex items-center p-3 rounded-lg border-2 border-gray-100 text-left opacity-50 cursor-not-allowed">
              <div class="w-8 h-8 bg-gradient-to-br from-purple-500 to-blue-500 rounded-md flex items-center justify-center mr-3">
                <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
                </svg>
              </div>
              <div>
                <p class="text-sm font-medium text-gray-900">Custom Logo</p>
                <p class="text-xs text-gray-500">Upload your own logo (Coming soon)</p>
              </div>
            </button>
          </div>
        <% end %>

        <!-- Frestyl Branding Options -->
        <div class="border-t border-gray-100 pt-4 mt-4">
          <div class="flex items-center justify-between">
            <div>
              <h5 class="text-sm font-medium text-gray-900">Frestyl Branding</h5>
              <p class="text-xs text-gray-500">Show "Made with Frestyl" attribution</p>
            </div>
            <button
              phx-click="toggle_frestyl_branding"
              phx-target={@myself}
              class={[
                "relative inline-flex h-6 w-11 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none",
                if(@show_frestyl_branding, do: "bg-blue-600", else: "bg-gray-200")
              ]}>
              <span class={[
                "pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out",
                if(@show_frestyl_branding, do: "translate-x-5", else: "translate-x-0")
              ]}></span>
            </button>
          </div>

          <!-- Branding Position Options -->
          <%= if @show_frestyl_branding do %>
            <div class="mt-3 space-y-2">
              <p class="text-xs text-gray-600">Branding Position:</p>
              <div class="flex space-x-2">
                <button
                  phx-click="update_branding_position"
                  phx-value-position="footer"
                  phx-target={@myself}
                  class={[
                    "px-3 py-1 text-xs rounded-full border transition-colors",
                    if(@branding_position == "footer",
                      do: "border-blue-500 bg-blue-50 text-blue-700",
                      else: "border-gray-300 hover:border-gray-400 text-gray-600")
                  ]}>
                  Footer
                </button>
                <button
                  phx-click="update_branding_position"
                  phx-value-position="header"
                  phx-target={@myself}
                  class={[
                    "px-3 py-1 text-xs rounded-full border transition-colors",
                    if(@branding_position == "header",
                      do: "border-blue-500 bg-blue-50 text-blue-700",
                      else: "border-gray-300 hover:border-gray-400 text-gray-600")
                  ]}>
                  Header
                </button>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp get_user_initials(user) when is_map(user) do
    name = Map.get(user, :name) || Map.get(user, "name") || Map.get(user, :email) || Map.get(user, "email") || "U"

    name
    |> String.split(" ")
    |> Enum.take(2)
    |> Enum.map(&String.first/1)
    |> Enum.join("")
    |> String.upcase()
  end
  defp get_user_initials(_), do: "U"

  @impl true
  def handle_event("toggle_logo_options", _params, socket) do
    {:noreply, assign(socket, :show_logo_options, !socket.assigns.show_logo_options)}
  end

  @impl true
  def handle_event("update_logo_style", %{"style" => style}, socket) do
    socket = socket
    |> assign(:logo_style, style)
    |> assign(:show_logo_options, false)

    # Update portfolio customization
    customization_update = %{"logo_style" => style}
    send(self(), {:update_portfolio_customization, customization_update})

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_frestyl_branding", _params, socket) do
    new_value = !socket.assigns.show_frestyl_branding
    socket = assign(socket, :show_frestyl_branding, new_value)

    # Update portfolio customization
    customization_update = %{"show_frestyl_branding" => new_value}
    send(self(), {:update_portfolio_customization, customization_update})

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_branding_position", %{"position" => position}, socket) do
    socket = assign(socket, :branding_position, position)

    # Update portfolio customization
    customization_update = %{"branding_position" => position}
    send(self(), {:update_portfolio_customization, customization_update})

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="logo-branding-component">
      <!-- Logo & Branding Section in Customization Panel -->
      <div class="bg-white rounded-lg border border-gray-200 p-4 mb-4">
        <div class="flex items-center justify-between mb-3">
          <h4 class="text-sm font-semibold text-gray-900">Logo & Branding</h4>
          <button
            phx-click="toggle_logo_options"
            phx-target={@myself}
            class="text-blue-600 hover:text-blue-700 text-sm">
            <%= if @show_logo_options, do: "Done", else: "Customize" %>
          </button>
        </div>

        <!-- Current Logo Preview -->
        <div class="flex items-center space-x-3 mb-3">
          <%= case @logo_style do %>
            <% "initials" -> %>
              <div class="w-10 h-10 bg-blue-600 text-white rounded-lg flex items-center justify-center font-semibold text-sm">
                <%= @user_initials %>
              </div>
              <span class="text-sm text-gray-600">Personal initials logo</span>

            <% "none" -> %>
              <div class="w-10 h-10 bg-gray-200 rounded-lg flex items-center justify-center">
                <svg class="w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                </svg>
              </div>
              <span class="text-sm text-gray-600">No logo</span>

            <% "custom" -> %>
              <div class="w-10 h-10 bg-gradient-to-br from-purple-500 to-blue-500 rounded-lg flex items-center justify-center">
                <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
                </svg>
              </div>
              <span class="text-sm text-gray-600">Custom logo</span>
          <% end %>
        </div>

        <!-- Logo Options -->
        <%= if @show_logo_options do %>
          <div class="space-y-3 border-t border-gray-100 pt-3">
            <!-- Initials Logo -->
            <button
              phx-click="update_logo_style"
              phx-value-style="initials"
              phx-target={@myself}
              class={[
                "w-full flex items-center p-3 rounded-lg border-2 transition-colors text-left",
                if(@logo_style == "initials",
                  do: "border-blue-500 bg-blue-50",
                  else: "border-gray-200 hover:border-gray-300")
              ]}>
              <div class="w-8 h-8 bg-blue-600 text-white rounded-md flex items-center justify-center font-semibold text-xs mr-3">
                <%= @user_initials %>
              </div>
              <div>
                <p class="text-sm font-medium text-gray-900">Personal Initials</p>
                <p class="text-xs text-gray-500">Clean, professional initials logo</p>
              </div>
            </button>

            <!-- No Logo -->
            <button
              phx-click="update_logo_style"
              phx-value-style="none"
              phx-target={@myself}
              class={[
                "w-full flex items-center p-3 rounded-lg border-2 transition-colors text-left",
                if(@logo_style == "none",
                  do: "border-blue-500 bg-blue-50",
                  else: "border-gray-200 hover:border-gray-300")
              ]}>
              <div class="w-8 h-8 bg-gray-200 rounded-md flex items-center justify-center mr-3">
                <svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                </svg>
              </div>
              <div>
                <p class="text-sm font-medium text-gray-900">No Logo</p>
                <p class="text-xs text-gray-500">Minimal design without logo</p>
              </div>
            </button>

            <!-- Custom Logo (Future Feature) -->
            <button
              disabled
              class="w-full flex items-center p-3 rounded-lg border-2 border-gray-100 text-left opacity-50 cursor-not-allowed">
              <div class="w-8 h-8 bg-gradient-to-br from-purple-500 to-blue-500 rounded-md flex items-center justify-center mr-3">
                <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
                </svg>
              </div>
              <div>
                <p class="text-sm font-medium text-gray-900">Custom Logo</p>
                <p class="text-xs text-gray-500">Upload your own logo (Coming soon)</p>
              </div>
            </button>
          </div>
        <% end %>

        <!-- Frestyl Branding Options -->
        <div class="border-t border-gray-100 pt-4 mt-4">
          <div class="flex items-center justify-between">
            <div>
              <h5 class="text-sm font-medium text-gray-900">Frestyl Branding</h5>
              <p class="text-xs text-gray-500">Show "Made with Frestyl" attribution</p>
            </div>
            <button
              phx-click="toggle_frestyl_branding"
              phx-target={@myself}
              class={[
                "relative inline-flex h-6 w-11 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none",
                if(@show_frestyl_branding, do: "bg-blue-600", else: "bg-gray-200")
              ]}>
              <span class={[
                "pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out",
                if(@show_frestyl_branding, do: "translate-x-5", else: "translate-x-0")
              ]}></span>
            </button>
          </div>

          <!-- Branding Position Options -->
          <%= if @show_frestyl_branding do %>
            <div class="mt-3 space-y-2">
              <p class="text-xs text-gray-600">Branding Position:</p>
              <div class="flex space-x-2">
                <button
                  phx-click="update_branding_position"
                  phx-value-position="footer"
                  phx-target={@myself}
                  class={[
                    "px-3 py-1 text-xs rounded-full border transition-colors",
                    if(@branding_position == "footer",
                      do: "border-blue-500 bg-blue-50 text-blue-700",
                      else: "border-gray-300 hover:border-gray-400 text-gray-600")
                  ]}>
                  Footer
                </button>
                <button
                  phx-click="update_branding_position"
                  phx-value-position="header"
                  phx-target={@myself}
                  class={[
                    "px-3 py-1 text-xs rounded-full border transition-colors",
                    if(@branding_position == "header",
                      do: "border-blue-500 bg-blue-50 text-blue-700",
                      else: "border-gray-300 hover:border-gray-400 text-gray-600")
                  ]}>
                  Header
                </button>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp get_user_initials(user) do
    name = user.name || user.email || "U"

    name
    |> String.split(" ")
    |> Enum.take(2)
    |> Enum.map(&String.first/1)
    |> Enum.join("")
    |> String.upcase()
  end
end
