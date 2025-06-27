defmodule FrestylWeb.PortfolioLive.ServiceSectionComponent do
  use FrestylWeb, :live_component
  alias Frestyl.Services

  @impl true
  def update(%{portfolio: portfolio} = assigns, socket) do
    services = Services.list_portfolio_services(portfolio.id)

    socket =
      socket
      |> assign(assigns)
      |> assign(:services, services)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="portfolio-section service-booking-section">
      <div class="section-header">
        <h3 class="section-title">Book a Service</h3>
        <p class="section-description">Schedule a consultation or book my services directly</p>
      </div>

      <div class="services-grid">
        <%= for service <- @services do %>
          <div class="service-card">
            <div class="service-header">
              <h4 class="service-title"><%= service.title %></h4>
              <div class="service-type">
                <%= format_service_type(service.service_type) %>
              </div>
            </div>

            <div class="service-content">
              <p class="service-description"><%= service.description %></p>

              <div class="service-details">
                <div class="detail-item">
                  <span class="detail-label">Duration:</span>
                  <span class="detail-value"><%= format_duration(service.duration_minutes) %></span>
                </div>

                <div class="detail-item">
                  <span class="detail-label">Price:</span>
                  <span class="detail-value"><%= format_price(service.price_cents, service.currency) %></span>
                </div>

                <%= if service.location_type != :online do %>
                  <div class="detail-item">
                    <span class="detail-label">Location:</span>
                    <span class="detail-value"><%= format_location_type(service.location_type) %></span>
                  </div>
                <% end %>
              </div>
            </div>

            <div class="service-actions">
              <.link
                navigate={~p"/book/#{service.id}"}
                class="btn btn-primary btn-book-service"
              >
                Book Now
              </.link>

              <button
                type="button"
                class="btn btn-secondary btn-service-details"
                phx-click="show_service_details"
                phx-target={@myself}
                phx-value-service-id={service.id}
              >
                Learn More
              </button>
            </div>
          </div>
        <% end %>
      </div>

      <%= if Enum.empty?(@services) do %>
        <div class="no-services-message">
          <p>No services are currently available for booking.</p>
        </div>
      <% end %>
    </div>
    """
  end

  defp format_service_type(type) do
    case type do
      :consultation -> "Consultation"
      :coaching -> "Coaching Session"
      :design_work -> "Design Work"
      :lessons -> "Lesson"
      :custom -> "Custom Service"
    end
  end

  defp format_duration(minutes) do
    cond do
      minutes < 60 -> "#{minutes} min"
      minutes == 60 -> "1 hour"
      rem(minutes, 60) == 0 -> "#{div(minutes, 60)} hours"
      true -> "#{div(minutes, 60)}h #{rem(minutes, 60)}m"
    end
  end

  defp format_price(cents, currency) do
    dollars = cents / 100
    "$#{:erlang.float_to_binary(dollars, decimals: 2)}"
  end

  defp format_location_type(type) do
    case type do
      :online -> "Online"
      :in_person -> "In Person"
      :hybrid -> "Online or In Person"
    end
  end
end
