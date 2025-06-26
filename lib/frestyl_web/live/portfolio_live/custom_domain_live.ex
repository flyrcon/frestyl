# lib/frestyl_web/live/portfolio_live/custom_domain_live.ex
defmodule FrestylWeb.PortfolioLive.CustomDomainLive do
  use FrestylWeb, :live_view

  alias Frestyl.Portfolios
  alias Frestyl.Portfolios.CustomDomain
  import FrestylWeb.Components.SubscriptionComponents

  @impl true
  def mount(%{"id" => portfolio_id}, _session, socket) do
    portfolio = Portfolios.get_portfolio!(portfolio_id)
    user = socket.assigns.current_user
    limits = Portfolios.get_portfolio_limits(user)

    # Check if user owns portfolio
    if portfolio.user_id != user.id do
      {:ok,
       socket
       |> put_flash(:error, "You don't have permission to access this portfolio.")
       |> push_navigate(to: "/portfolios")}
    else
      custom_domain = Portfolios.get_portfolio_custom_domain(portfolio.id)

      socket =
        socket
        |> assign(:page_title, "Custom Domain")
        |> assign(:portfolio, portfolio)
        |> assign(:custom_domain, custom_domain)
        |> assign(:limits, limits)
        |> assign(:domain_form, to_form(%{"domain" => ""}))
        |> assign(:show_setup_modal, false)
        |> assign(:checking_domain, false)

      {:ok, socket}
    end
  end

  @impl true
  def handle_event("add_domain", %{"domain" => domain_value}, socket) do
    user = socket.assigns.current_user
    portfolio = socket.assigns.portfolio
    limits = socket.assigns.limits

    # Check if user has custom domain access
    if not limits.custom_domains do
      {:noreply,
       socket
       |> put_flash(:error, "Custom domains require a Professional or Business plan.")
       |> push_event("show_upgrade_modal", %{
         title: "Custom Domains Available on Pro Plans",
         message: "Add your own domain to create a professional portfolio URL.",
         features: ["Custom domain setup", "SSL certificates", "DNS management", "Professional branding"]
       })}
    else
      case Portfolios.create_custom_domain(%{
        domain: String.trim(domain_value),
        portfolio_id: portfolio.id,
        user_id: user.id
      }) do
        {:ok, custom_domain} ->
          {:noreply,
           socket
           |> assign(:custom_domain, custom_domain)
           |> assign(:show_setup_modal, true)
           |> put_flash(:info, "Domain added! Follow the setup instructions to complete configuration.")}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply,
           socket
           |> assign(:domain_form, to_form(changeset))
           |> put_flash(:error, "Failed to add domain. Please check your input.")}
      end
    end
  end

  @impl true
  def handle_event("verify_domain", _params, socket) do
    custom_domain = socket.assigns.custom_domain

    socket = assign(socket, checking_domain: true)

    case Portfolios.verify_custom_domain(custom_domain.id) do
      {:ok, updated_domain} ->
        {:noreply,
         socket
         |> assign(:custom_domain, updated_domain)
         |> assign(:checking_domain, false)
         |> put_flash(:info, "Domain verification successful!")}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:checking_domain, false)
         |> put_flash(:error, "Domain verification failed: #{reason}")}
    end
  end

  @impl true
  def handle_event("remove_domain", _params, socket) do
    custom_domain = socket.assigns.custom_domain

    case Portfolios.delete_custom_domain(custom_domain) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:custom_domain, nil)
         |> put_flash(:info, "Custom domain removed.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to remove domain.")}
    end
  end

  @impl true
  def handle_event("hide_setup_modal", _params, socket) do
    {:noreply, assign(socket, show_setup_modal: false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto py-8 px-4">
      <div class="mb-8">
        <.link navigate={"/portfolios/#{@portfolio.id}/edit"} class="text-purple-600 hover:text-purple-700 font-medium">
          ← Back to Portfolio
        </.link>
        <h1 class="text-3xl font-bold text-gray-900 mt-2">Custom Domain</h1>
        <p class="text-gray-600 mt-2">
          Connect your own domain to create a professional portfolio URL
        </p>
      </div>

      <!-- Feature Gate for Custom Domains -->
      <.feature_gate user={@current_user} feature={:custom_domains}>
        <div class="space-y-6">
          <%= if @custom_domain do %>
            <!-- Existing Domain -->
            <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
              <div class="flex items-center justify-between mb-4">
                <div>
                  <h3 class="text-lg font-semibold text-gray-900">Current Domain</h3>
                  <p class="text-2xl font-bold text-purple-600 mt-1">
                    <%= @custom_domain.domain %>
                  </p>
                </div>
                <div class="text-right">
                  <%= render_domain_status(@custom_domain) %>
                  <button
                    phx-click="remove_domain"
                    data-confirm="Are you sure you want to remove this domain?"
                    class="text-red-600 hover:text-red-700 text-sm font-medium mt-2">
                    Remove Domain
                  </button>
                </div>
              </div>

              <!-- Domain Status Details -->
              <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
                <div class="p-4 bg-gray-50 rounded-lg">
                  <div class="flex items-center">
                    <%= if @custom_domain.dns_configured do %>
                      <svg class="w-5 h-5 text-green-500 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                      </svg>
                    <% else %>
                      <svg class="w-5 h-5 text-yellow-500 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01"/>
                      </svg>
                    <% end %>
                    <span class="font-medium text-gray-900">DNS</span>
                  </div>
                  <p class="text-sm text-gray-600 mt-1">
                    <%= if @custom_domain.dns_configured, do: "Configured", else: "Pending" %>
                  </p>
                </div>

                <div class="p-4 bg-gray-50 rounded-lg">
                  <div class="flex items-center">
                    <%= case @custom_domain.ssl_status do %>
                      <% "active" -> %>
                        <svg class="w-5 h-5 text-green-500 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                        </svg>
                      <% "pending" -> %>
                        <svg class="w-5 h-5 text-yellow-500 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01"/>
                        </svg>
                      <% _ -> %>
                        <svg class="w-5 h-5 text-red-500 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                        </svg>
                    <% end %>
                    <span class="font-medium text-gray-900">SSL</span>
                  </div>
                  <p class="text-sm text-gray-600 mt-1">
                    <%= String.capitalize(@custom_domain.ssl_status) %>
                  </p>
                </div>

                <div class="p-4 bg-gray-50 rounded-lg">
                  <div class="flex items-center">
                    <%= case @custom_domain.status do %>
                      <% "active" -> %>
                        <svg class="w-5 h-5 text-green-500 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                        </svg>
                      <% "pending" -> %>
                        <svg class="w-5 h-5 text-yellow-500 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01"/>
                        </svg>
                      <% _ -> %>
                        <svg class="w-5 h-5 text-red-500 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                        </svg>
                    <% end %>
                    <span class="font-medium text-gray-900">Status</span>
                  </div>
                  <p class="text-sm text-gray-600 mt-1">
                    <%= String.capitalize(@custom_domain.status) %>
                  </p>
                </div>
              </div>

              <!-- Verification Button -->
              <%= if @custom_domain.status != "active" do %>
                <button
                  phx-click="verify_domain"
                  disabled={@checking_domain}
                  class="w-full md:w-auto bg-purple-600 hover:bg-purple-700 disabled:bg-gray-400 text-white font-medium py-2 px-6 rounded-lg transition-colors">
                  <%= if @checking_domain do %>
                    <div class="flex items-center justify-center">
                      <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" fill="none" viewBox="0 0 24 24">
                        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                      </svg>
                      Checking...
                    </div>
                  <% else %>
                    Check Domain Status
                  <% end %>
                </button>
              <% end %>
            </div>

            <!-- DNS Instructions -->
            <%= if @custom_domain.status != "active" do %>
              <div class="bg-blue-50 border border-blue-200 rounded-xl p-6">
                <h3 class="text-lg font-semibold text-blue-900 mb-4">
                  <svg class="w-5 h-5 inline mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
                  </svg>
                  DNS Configuration Required
                </h3>

                <p class="text-blue-800 mb-4">
                  Add these DNS records to your domain provider to connect your custom domain:
                </p>

                <div class="bg-white rounded-lg p-4 font-mono text-sm">
                  <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-2 font-bold text-gray-700">
                    <div>Type</div>
                    <div>Name</div>
                    <div>Value</div>
                  </div>
                  <div class="grid grid-cols-1 md:grid-cols-3 gap-4 py-2 border-t border-gray-200">
                    <div class="text-gray-900">CNAME</div>
                    <div class="text-gray-900">@</div>
                    <div class="text-gray-900 break-all">portfolios.frestyl.com</div>
                  </div>
                  <div class="grid grid-cols-1 md:grid-cols-3 gap-4 py-2 border-t border-gray-200">
                    <div class="text-gray-900">TXT</div>
                    <div class="text-gray-900">_frestyl-verification</div>
                    <div class="text-gray-900 break-all"><%= @custom_domain.verification_code %></div>
                  </div>
                </div>

                <div class="mt-4 p-4 bg-yellow-50 border border-yellow-200 rounded-lg">
                  <p class="text-sm text-yellow-800">
                    <strong>Note:</strong> DNS changes can take up to 24 hours to propagate.
                    You can check the status using the "Check Domain Status" button above.
                  </p>
                </div>
              </div>
            <% end %>

          <% else %>
            <!-- Add Domain Form -->
            <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
              <h3 class="text-lg font-semibold text-gray-900 mb-4">Add Custom Domain</h3>

              <.form for={@domain_form} phx-submit="add_domain" class="space-y-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-2">
                    Domain Name
                  </label>
                  <input
                    type="text"
                    name="domain"
                    placeholder="yourdomain.com"
                    class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
                    required
                  />
                  <p class="text-sm text-gray-500 mt-2">
                    Enter your domain without www (e.g., yourdomain.com)
                  </p>
                </div>

                <button
                  type="submit"
                  class="w-full bg-purple-600 hover:bg-purple-700 text-white font-medium py-3 px-6 rounded-lg transition-colors">
                  Add Domain
                </button>
              </.form>

              <!-- Domain Examples -->
              <div class="mt-6 p-4 bg-gray-50 rounded-lg">
                <h4 class="font-medium text-gray-900 mb-2">Domain Examples:</h4>
                <ul class="text-sm text-gray-600 space-y-1">
                  <li>• johndoe.com</li>
                  <li>• portfolio.mycompany.com</li>
                  <li>• work.janedoe.io</li>
                </ul>
              </div>
            </div>
          <% end %>
        </div>
      </.feature_gate>

      <!-- Setup Modal -->
      <%= if @show_setup_modal do %>
        <div class="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50">
          <div class="bg-white rounded-xl shadow-2xl max-w-lg w-full mx-4">
            <div class="p-6">
              <div class="flex items-center justify-between mb-4">
                <h3 class="text-lg font-semibold text-gray-900">Domain Added Successfully!</h3>
                <button phx-click="hide_setup_modal" class="text-gray-400 hover:text-gray-600">
                  <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                  </svg>
                </button>
              </div>

              <p class="text-gray-600 mb-4">
                Your domain <strong><%= @custom_domain.domain %></strong> has been added.
                You'll need to configure DNS records to complete the setup.
              </p>

              <div class="bg-blue-50 p-4 rounded-lg mb-4">
                <p class="text-sm text-blue-800">
                  <strong>Next steps:</strong>
                </p>
                <ol class="text-sm text-blue-700 mt-2 space-y-1 list-decimal list-inside">
                  <li>Add the DNS records shown above to your domain provider</li>
                  <li>Wait for DNS propagation (up to 24 hours)</li>
                  <li>Click "Check Domain Status" to verify</li>
                </ol>
              </div>

              <button
                phx-click="hide_setup_modal"
                class="w-full bg-purple-600 hover:bg-purple-700 text-white font-medium py-2 px-4 rounded-lg transition-colors">
                Got it!
              </button>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_domain_status(domain) do
    case domain.status do
      "active" ->
        assigns = %{}
        ~H"""
        <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
          <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
          </svg>
          Active
        </span>
        """
      "pending" ->
        assigns = %{}
        ~H"""
        <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800">
          <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01"/>
          </svg>
          Pending
        </span>
        """
      _ ->
        assigns = %{}
        ~H"""
        <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">
          <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
          </svg>
          Failed
        </span>
        """
    end
  end
end
