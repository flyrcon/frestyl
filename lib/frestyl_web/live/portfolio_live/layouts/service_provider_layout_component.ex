# lib/frestyl_web/live/portfolio_live/layouts/service_provider_layout_component.ex

defmodule FrestylWeb.PortfolioLive.Layouts.ServiceProviderLayoutComponent do
  @moduledoc """
  Business-focused layout for service providers with pricing and testimonials
  """
  use FrestylWeb, :live_component

  def render(assigns) do
    sections = organize_sections_for_service_provider(assigns.sections)
    assigns = assign(assigns, :organized_sections, sections)

    ~H"""
    <div class="service-provider-portfolio bg-gray-50 min-h-screen">
      <!-- Value proposition hero -->
      <%= if @organized_sections[:hero] do %>
        <.render_value_prop_hero hero_section={@organized_sections[:hero]} portfolio={@portfolio} />
      <% end %>

      <!-- Services grid -->
      <%= if @organized_sections[:services] do %>
        <section class="py-16 bg-white">
          <div class="max-w-6xl mx-auto px-4">
            <.render_services_grid services_section={@organized_sections[:services]} />
          </div>
        </section>
      <% end %>

      <!-- Testimonials -->
      <%= if @organized_sections[:testimonials] do %>
        <section class="py-16 bg-gray-50">
          <div class="max-w-6xl mx-auto px-4">
            <.render_testimonials testimonials_section={@organized_sections[:testimonials]} />
          </div>
        </section>
      <% end %>

      <!-- Contact CTA -->
      <%= if @organized_sections[:contact] do %>
        <section class="py-16 bg-blue-600 text-white">
          <div class="max-w-4xl mx-auto px-4 text-center">
            <.render_contact_cta contact_section={@organized_sections[:contact]} />
          </div>
        </section>
      <% end %>
    </div>
    """
  end

  defp render_value_prop_hero(assigns) do
    content = assigns.hero_section.content || %{}

    ~H"""
    <section class="py-20 bg-gradient-to-r from-blue-600 to-blue-800 text-white">
      <div class="max-w-4xl mx-auto px-4 text-center">
        <h1 class="text-5xl font-bold mb-6">
          <%= Map.get(content, "headline", @portfolio.title) %>
        </h1>
        <p class="text-xl mb-8 text-blue-100">
          <%= Map.get(content, "tagline", "Professional services you can trust") %>
        </p>
        <div class="flex justify-center gap-4">
          <button class="bg-white text-blue-600 px-8 py-3 rounded-lg font-semibold hover:bg-gray-100">
            Get Started
          </button>
          <button class="border border-white text-white px-8 py-3 rounded-lg font-semibold hover:bg-white hover:text-blue-600">
            Learn More
          </button>
        </div>
      </div>
    </section>
    """
  end

  defp render_services_grid(assigns) do
    content = assigns.services_section.content || %{}
    services = Map.get(content, "items", [])

    ~H"""
    <div>
      <h2 class="text-3xl font-bold text-center mb-12">Our Services</h2>
      <div class="grid grid-cols-1 md:grid-cols-3 gap-8">
        <%= for service <- services do %>
          <div class="bg-white rounded-xl p-8 shadow-lg border border-gray-100 text-center">
            <div class="w-16 h-16 bg-blue-100 rounded-full mx-auto mb-6 flex items-center justify-center">
              <svg class="w-8 h-8 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"/>
              </svg>
            </div>
            <h3 class="text-xl font-semibold mb-4"><%= Map.get(service, "title", "Service") %></h3>
            <p class="text-gray-600 mb-6"><%= Map.get(service, "description", "") %></p>
            <%= if Map.get(service, "price", "") != "" do %>
              <div class="text-2xl font-bold text-blue-600 mb-4">
                <%= Map.get(service, "price") %>
              </div>
            <% end %>
            <button class="w-full bg-blue-600 text-white py-3 rounded-lg font-semibold hover:bg-blue-700">
              Learn More
            </button>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_testimonials(assigns) do
    content = assigns.testimonials_section.content || %{}
    testimonials = Map.get(content, "items", [])

    ~H"""
    <div>
      <h2 class="text-3xl font-bold text-center mb-12">What Clients Say</h2>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
        <%= for testimonial <- Enum.take(testimonials, 4) do %>
          <div class="bg-white rounded-xl p-8 shadow-lg">
            <div class="flex items-center mb-4">
              <%= for _i <- 1..5 do %>
                <svg class="w-5 h-5 text-yellow-400" fill="currentColor" viewBox="0 0 20 20">
                  <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z"/>
                </svg>
              <% end %>
            </div>
            <blockquote class="text-gray-600 mb-6 italic">
              "<%= Map.get(testimonial, "content", "Excellent service and results.") %>"
            </blockquote>
            <div class="flex items-center">
              <div class="w-12 h-12 bg-gray-200 rounded-full mr-4"></div>
              <div>
                <div class="font-semibold"><%= Map.get(testimonial, "name", "Client") %></div>
                <div class="text-gray-600 text-sm"><%= Map.get(testimonial, "company", "Company") %></div>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_contact_cta(assigns) do
    content = assigns.contact_section.content || %{}

    ~H"""
    <div>
      <h2 class="text-3xl font-bold mb-6">Ready to Get Started?</h2>
      <p class="text-xl text-blue-100 mb-8">
        Let's discuss how we can help you achieve your goals.
      </p>
      <div class="flex justify-center gap-4">
        <%= if Map.get(content, "email", "") != "" do %>
          <a href={"mailto:#{Map.get(content, "email")}"} class="bg-white text-blue-600 px-8 py-3 rounded-lg font-semibold hover:bg-gray-100">
            Contact Us Today
          </a>
        <% end %>
        <%= if Map.get(content, "phone", "") != "" do %>
          <a href={"tel:#{Map.get(content, "phone")}"} class="border border-white text-white px-8 py-3 rounded-lg font-semibold hover:bg-white hover:text-blue-600">
            <%= Map.get(content, "phone") %>
          </a>
        <% end %>
      </div>
    </div>
    """
  end

  defp organize_sections_for_service_provider(sections) do
    sections
    |> Enum.reduce(%{}, fn section, acc ->
      section_type = normalize_section_type(section.section_type)
      Map.put(acc, section_type, section)
    end)
  end

  defp normalize_section_type(section_type) when is_atom(section_type), do: section_type
  defp normalize_section_type(section_type) when is_binary(section_type), do: String.to_atom(section_type)
end
