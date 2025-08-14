defmodule FrestylWeb.PortfolioLive.EnhancedPortfolioEditor.HelpComponent do
  use FrestylWeb, :live_component

  @impl true
  def mount(socket) do
    socket = socket
    |> assign(:show_help_modal, false)
    |> assign(:help_type, "general")
    |> assign(:collaboration_email, "")
    |> assign(:help_message, "")

    {:ok, socket}
  end

  @impl true
  def handle_event("show_help", %{"type" => type}, socket) do
    {:noreply, assign(socket, show_help_modal: true, help_type: type)}
  end

  @impl true
  def handle_event("hide_help", _params, socket) do
    {:noreply, assign(socket, show_help_modal: false)}
  end

  @impl true
  def handle_event("send_collaboration_invite", %{"email" => email}, socket) do
    case validate_email(email) do
      {:ok, valid_email} ->
        case send_collaboration_invite(socket.assigns.portfolio.id, valid_email, socket.assigns.current_user) do
          {:ok, _invite} ->
            {:noreply, socket
             |> assign(:show_help_modal, false)
             |> put_flash(:info, "Collaboration invite sent to #{valid_email}!")}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, "Failed to send invite: #{reason}")}
        end

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, reason)}
    end
  end

  @impl true
  def handle_event("request_help", %{"message" => message}, socket) do
    case send_help_request(socket.assigns.portfolio.id, message, socket.assigns.current_user) do
      {:ok, _ticket} ->
        {:noreply, socket
         |> assign(:show_help_modal, false)
         |> put_flash(:info, "Help request sent! We'll get back to you within 24 hours.")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to send help request: #{reason}")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="help-component">
      <!-- Get Help Button -->
      <div class="fixed bottom-6 left-6 z-40">
        <div class="relative group">
          <button
            phx-click="show_help"
            phx-value-type="general"
            phx-target={@myself}
            class="flex items-center space-x-2 bg-blue-600 hover:bg-blue-700 text-white px-4 py-3 rounded-full shadow-lg transition-all duration-200 hover:scale-105">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
            </svg>
            <span class="font-medium">Get Help</span>
          </button>

          <!-- Help Options Tooltip -->
          <div class="absolute bottom-full left-0 mb-2 opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none">
            <div class="bg-gray-900 text-white text-xs px-3 py-2 rounded-lg whitespace-nowrap">
              Need help building your portfolio?
            </div>
          </div>
        </div>
      </div>

      <!-- Help Modal -->
      <%= if @show_help_modal do %>
        <div class="fixed inset-0 z-50 overflow-y-auto">
          <div class="flex items-center justify-center min-h-screen px-4 pt-4 pb-20 text-center sm:p-0">
            <!-- Backdrop -->
            <div
              class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity"
              phx-click="hide_help"
              phx-target={@myself}>
            </div>

            <!-- Modal -->
            <div class="relative bg-white rounded-lg px-4 pt-5 pb-4 text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-lg sm:w-full sm:p-6">
              <div class="sm:flex sm:items-start">
                <div class="mx-auto flex-shrink-0 flex items-center justify-center h-12 w-12 rounded-full bg-blue-100 sm:mx-0 sm:h-10 sm:w-10">
                  <svg class="h-6 w-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
                  </svg>
                </div>

                <div class="mt-3 text-center sm:mt-0 sm:ml-4 sm:text-left w-full">
                  <h3 class="text-lg leading-6 font-medium text-gray-900">
                    How can we help you?
                  </h3>

                  <div class="mt-4 space-y-4">
                    <!-- Help Options -->
                    <div class="grid grid-cols-1 gap-3">
                      <!-- Invite Collaborator -->
                      <button
                        phx-click="show_help"
                        phx-value-type="collaborate"
                        phx-target={@myself}
                        class="flex items-center p-3 border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors text-left">
                        <div class="flex-shrink-0">
                          <svg class="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197m13.5-9a2.5 2.5 0 11-5 0 2.5 2.5 0 015 0z"/>
                          </svg>
                        </div>
                        <div class="ml-3">
                          <p class="text-sm font-medium text-gray-900">Invite a Collaborator</p>
                          <p class="text-xs text-gray-500">Get help from a friend or colleague</p>
                        </div>
                      </button>

                      <!-- Request Professional Help -->
                      <button
                        phx-click="show_help"
                        phx-value-type="professional"
                        phx-target={@myself}
                        class="flex items-center p-3 border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors text-left">
                        <div class="flex-shrink-0">
                          <svg class="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
                          </svg>
                        </div>
                        <div class="ml-3">
                          <p class="text-sm font-medium text-gray-900">Request Professional Help</p>
                          <p class="text-xs text-gray-500">Get assistance from our team</p>
                        </div>
                      </button>

                      <!-- Browse Help Resources -->
                      <a
                        href="/help"
                        target="_blank"
                        class="flex items-center p-3 border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors text-left">
                        <div class="flex-shrink-0">
                          <svg class="w-6 h-6 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.746 0 3.332.477 4.5 1.253v13C19.832 18.477 18.246 18 16.5 18c-1.746 0-3.332.477-4.5 1.253"/>
                          </svg>
                        </div>
                        <div class="ml-3">
                          <p class="text-sm font-medium text-gray-900">Browse Help Articles</p>
                          <p class="text-xs text-gray-500">Self-service guides and tutorials</p>
                        </div>
                      </a>
                    </div>

                    <!-- Dynamic Content Based on Help Type -->
                    <%= case @help_type do %>
                      <% "collaborate" -> %>
                        <%= render_collaboration_form(assigns) %>
                      <% "professional" -> %>
                        <%= render_help_request_form(assigns) %>
                      <% _ -> %>
                        <div></div>
                    <% end %>
                  </div>
                </div>
              </div>

              <!-- Modal Footer -->
              <div class="mt-5 sm:mt-4 sm:flex sm:flex-row-reverse">
                <button
                  type="button"
                  phx-click="hide_help"
                  phx-target={@myself}
                  class="w-full inline-flex justify-center rounded-md border border-gray-300 shadow-sm px-4 py-2 bg-white text-base font-medium text-gray-700 hover:bg-gray-50 focus:outline-none sm:ml-3 sm:w-auto sm:text-sm">
                  Close
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_collaboration_form(assigns) do
    ~H"""
    <div class="border-t border-gray-200 pt-4">
      <form phx-submit="send_collaboration_invite" phx-target={@myself}>
        <label class="block text-sm font-medium text-gray-700 mb-2">
          Collaborator Email Address
        </label>
        <input
          type="email"
          name="email"
          value={@collaboration_email}
          placeholder="colleague@example.com"
          required
          class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500">

        <p class="text-xs text-gray-500 mt-2">
          They'll receive an email invitation to help edit your portfolio.
        </p>

        <button
          type="submit"
          class="mt-3 w-full bg-green-600 text-white py-2 px-4 rounded-md hover:bg-green-700 transition-colors font-medium">
          Send Invitation
        </button>
      </form>
    </div>
    """
  end

  defp render_help_request_form(assigns) do
    ~H"""
    <div class="border-t border-gray-200 pt-4">
      <form phx-submit="request_help" phx-target={@myself}>
        <label class="block text-sm font-medium text-gray-700 mb-2">
          What do you need help with?
        </label>
        <textarea
          name="message"
          value={@help_message}
          rows="4"
          placeholder="Describe what you're trying to accomplish or what's not working..."
          required
          class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500 resize-none">
        </textarea>

        <p class="text-xs text-gray-500 mt-2">
          Our team will respond within 24 hours during business days.
        </p>

        <button
          type="submit"
          class="mt-3 w-full bg-blue-600 text-white py-2 px-4 rounded-md hover:bg-blue-700 transition-colors font-medium">
          Send Help Request
        </button>
      </form>
    </div>
    """
  end

  # Helper functions
  defp validate_email(email) do
    if String.match?(email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/) do
      {:ok, String.trim(email)}
    else
      {:error, "Please enter a valid email address"}
    end
  end

  defp send_collaboration_invite(portfolio_id, email, current_user) do
    # TODO: Implement actual collaboration invite logic
    # For now, simulate success
    {:ok, %{id: System.unique_integer(), email: email, portfolio_id: portfolio_id}}
  end

  defp send_help_request(portfolio_id, message, current_user) do
    # TODO: Implement actual help request logic (email, ticket system, etc.)
    # For now, simulate success
    {:ok, %{id: System.unique_integer(), message: message, portfolio_id: portfolio_id}}
  end
end
