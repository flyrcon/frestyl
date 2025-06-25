# lib/frestyl_web/live/onboarding_live.ex
defmodule FrestylWeb.OnboardingLive do
  use FrestylWeb, :live_view

  alias Frestyl.Accounts
  alias Frestyl.Portfolios

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Welcome to Frestyl")
     |> assign(:current_step, 0)
     |> assign(:story_data, %{
       purpose: nil,
       audience: nil,
       goals: [],
       account_type: nil,
       name: "",
       industry: "",
       experience: ""
     })}
  end

  @impl true
  def handle_event("select_purpose", %{"purpose" => purpose}, socket) do
    story_data = Map.put(socket.assigns.story_data, :purpose, purpose)

    {:noreply,
     socket
     |> assign(:story_data, story_data)
     |> assign(:current_step, 1)}
  end

  @impl true
  def handle_event("select_audience", %{"audience" => audience}, socket) do
    story_data = Map.put(socket.assigns.story_data, :audience, audience)

    {:noreply,
     socket
     |> assign(:story_data, story_data)
     |> assign(:current_step, 2)}
  end

  @impl true
  def handle_event("toggle_goal", %{"goal" => goal}, socket) do
    current_goals = socket.assigns.story_data.goals || []

    updated_goals = if goal in current_goals do
      List.delete(current_goals, goal)
    else
      [goal | current_goals]
    end

    story_data = Map.put(socket.assigns.story_data, :goals, updated_goals)

    {:noreply, assign(socket, :story_data, story_data)}
  end

  @impl true
  def handle_event("next_step", _params, socket) do
    current_step = socket.assigns.current_step
    max_steps = 4

    if current_step < max_steps do
      {:noreply, assign(socket, :current_step, current_step + 1)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("prev_step", _params, socket) do
    current_step = socket.assigns.current_step

    if current_step > 0 do
      {:noreply, assign(socket, :current_step, current_step - 1)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("select_account_type", %{"type" => type}, socket) do
    story_data = Map.put(socket.assigns.story_data, :account_type, type)
    {:noreply, assign(socket, :story_data, story_data)}
  end

  @impl true
  def handle_event("update_profile", %{"field" => field, "value" => value}, socket) do
    story_data = Map.put(socket.assigns.story_data, String.to_atom(field), value)
    {:noreply, assign(socket, :story_data, story_data)}
  end

  @impl true
  def handle_event("complete_onboarding", _params, socket) do
    case create_user_account(socket.assigns.story_data, socket.assigns.current_user) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Welcome to Frestyl! Your account has been set up.")
         |> push_navigate(to: "/portfolios")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Something went wrong. Please try again.")}
    end
  end

  defp create_user_account(story_data, user) do
    # Update user with onboarding data and set appropriate subscription
    account_attrs = %{
      "industry" => story_data.industry,
      "experience_level" => story_data.experience,
      "onboarding_completed" => true,
      "subscription_tier" => story_data.account_type || "storyteller"
    }

    Accounts.update_user(user, account_attrs)
  end

  defp get_recommended_plan(story_data) do
    cond do
      story_data.purpose in ["freelance", "career-pivot"] -> "professional"
      story_data.audience == "potential-clients" -> "business"
      true -> "professional"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-purple-50 via-blue-50 to-indigo-100 flex items-center justify-center p-4">
      <div class="w-full max-w-4xl">
        <!-- Progress Bar -->
        <div class="mb-8">
          <div class="flex items-center justify-between mb-4">
            <%= for step <- 0..4 do %>
              <div class="flex items-center">
                <div class={"w-10 h-10 rounded-full flex items-center justify-center text-sm font-bold transition-all duration-300 #{
                  if step <= @current_step,
                    do: "bg-gradient-to-r from-purple-600 to-indigo-600 text-white shadow-lg",
                    else: "bg-white text-gray-400 border-2 border-gray-200"
                }"}>
                  <%= if step < @current_step do %>
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                    </svg>
                  <% else %>
                    <%= step + 1 %>
                  <% end %>
                </div>
                <%= if step < 4 do %>
                  <div class={"w-16 h-1 mx-4 rounded-full transition-all duration-500 #{
                    if step < @current_step,
                      do: "bg-gradient-to-r from-purple-600 to-indigo-600",
                      else: "bg-gray-200"
                  }"} />
                <% end %>
              </div>
            <% end %>
          </div>

          <div class="text-center">
            <h2 class="text-2xl font-bold text-gray-900 mb-2">
              <%= get_step_title(@current_step) %>
            </h2>
            <p class="text-gray-600"><%= get_step_subtitle(@current_step) %></p>
          </div>
        </div>

        <!-- Step Content -->
        <div class="bg-white rounded-2xl shadow-xl p-8 mb-8">
          <%= case @current_step do %>
            <% 0 -> %>
              <%= render_story_step(assigns) %>
            <% 1 -> %>
              <%= render_audience_step(assigns) %>
            <% 2 -> %>
              <%= render_goals_step(assigns) %>
            <% 3 -> %>
              <%= render_account_step(assigns) %>
            <% 4 -> %>
              <%= render_profile_step(assigns) %>
          <% end %>
        </div>

        <!-- Navigation -->
        <div class="flex justify-between items-center">
          <button
            phx-click="prev_step"
            disabled={@current_step == 0}
            class={"px-6 py-3 rounded-xl font-medium transition-all #{
              if @current_step == 0,
                do: "text-gray-400 cursor-not-allowed",
                else: "text-gray-600 hover:text-gray-900 hover:bg-white hover:shadow-md"
            }"}
          >
            Back
          </button>

          <div class="text-sm text-gray-500">
            Step <%= @current_step + 1 %> of 5
          </div>

          <%= if @current_step == 4 do %>
            <button
              phx-click="complete_onboarding"
              class="px-8 py-3 bg-gradient-to-r from-purple-600 to-indigo-600 text-white rounded-xl font-bold transition-all duration-300 hover:shadow-lg hover:scale-105"
            >
              Complete Setup
            </button>
          <% else %>
            <button
              phx-click="next_step"
              class="px-8 py-3 bg-gradient-to-r from-purple-600 to-indigo-600 text-white rounded-xl font-bold transition-all duration-300 hover:shadow-lg hover:scale-105 flex items-center"
            >
              Continue
              <svg class="ml-2 w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
              </svg>
            </button>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp render_story_step(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="text-center mb-8">
        <div class="w-16 h-16 bg-gradient-to-r from-purple-600 to-indigo-600 rounded-full flex items-center justify-center mx-auto mb-4">
          <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"/>
          </svg>
        </div>
        <p class="text-lg text-gray-600">Every great portfolio tells a unique story. What's yours?</p>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <%= for purpose <- get_purposes() do %>
          <button
            phx-click="select_purpose"
            phx-value-purpose={purpose.id}
            class={"p-6 rounded-xl border-2 transition-all duration-300 text-left hover:shadow-lg hover:scale-105 #{
              if @story_data.purpose == purpose.id,
                do: "border-purple-500 bg-purple-50 shadow-lg",
                else: "border-gray-200 hover:border-purple-300"
            }"}
          >
            <div class="flex items-start space-x-4">
              <div class={"p-3 rounded-lg #{
                if @story_data.purpose == purpose.id,
                  do: "bg-purple-600 text-white",
                  else: "bg-gray-100 text-gray-600"
              }"}>
                <%= raw(purpose.icon) %>
              </div>
              <div>
                <h3 class="font-bold text-gray-900 mb-2"><%= purpose.title %></h3>
                <p class="text-sm text-gray-600"><%= purpose.description %></p>
              </div>
            </div>
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_audience_step(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="text-center mb-8">
        <div class="w-16 h-16 bg-gradient-to-r from-blue-600 to-indigo-600 rounded-full flex items-center justify-center mx-auto mb-4">
          <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"/>
          </svg>
        </div>
        <p class="text-lg text-gray-600">Understanding your audience helps us tailor your portfolio for maximum impact.</p>
      </div>

      <div class="space-y-3">
        <%= for audience <- get_audiences() do %>
          <button
            phx-click="select_audience"
            phx-value-audience={audience.id}
            class={"w-full p-4 rounded-xl border-2 transition-all duration-300 text-left #{
              if @story_data.audience == audience.id,
                do: "border-blue-500 bg-blue-50",
                else: "border-gray-200 hover:border-blue-300"
            }"}
          >
            <div class="flex justify-between items-center">
              <div>
                <h3 class="font-bold text-gray-900"><%= audience.title %></h3>
                <p class="text-sm text-gray-600"><%= audience.description %></p>
              </div>
              <%= if @story_data.audience == audience.id do %>
                <svg class="w-5 h-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                </svg>
              <% end %>
            </div>
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_goals_step(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="text-center mb-8">
        <div class="w-16 h-16 bg-gradient-to-r from-green-600 to-teal-600 rounded-full flex items-center justify-center mx-auto mb-4">
          <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
          </svg>
        </div>
        <p class="text-lg text-gray-600">Select all that apply. Your goals will shape your portfolio's design and content.</p>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <%= for goal <- get_goals() do %>
          <button
            phx-click="toggle_goal"
            phx-value-goal={goal.id}
            class={"p-4 rounded-xl border-2 transition-all duration-300 text-left #{
              if goal.id in (@story_data.goals || []),
                do: "border-green-500 bg-green-50",
                else: "border-gray-200 hover:border-green-300"
            }"}
          >
            <div class="flex items-center space-x-3">
              <span class="text-2xl"><%= goal.icon %></span>
              <span class="font-medium text-gray-900"><%= goal.title %></span>
              <%= if goal.id in (@story_data.goals || []) do %>
                <svg class="w-5 h-5 text-green-600 ml-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                </svg>
              <% end %>
            </div>
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_account_step(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="text-center mb-8">
        <div class="w-16 h-16 bg-gradient-to-r from-purple-600 to-pink-600 rounded-full flex items-center justify-center mx-auto mb-4">
          <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
          </svg>
        </div>
        <p class="text-lg text-gray-600">
          Based on your story, we recommend the <strong><%= get_recommended_plan(@story_data) |> String.capitalize() %></strong> plan.
        </p>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
        <%= for account <- get_account_types() do %>
          <div
            phx-click="select_account_type"
            phx-value-type={account.id}
            class={"relative p-6 rounded-2xl border-2 transition-all duration-300 cursor-pointer #{
              if account.recommended,
                do: "border-purple-500 bg-purple-50 shadow-lg scale-105",
                else: if(@story_data.account_type == account.id,
                  do: "border-blue-500 bg-blue-50",
                  else: "border-gray-200 hover:border-purple-300"
                )
            }"}
          >
            <%= if account.badge do %>
              <div class="absolute -top-3 left-1/2 transform -translate-x-1/2">
                <span class="bg-gradient-to-r from-purple-600 to-pink-600 text-white px-3 py-1 rounded-full text-xs font-bold">
                  <%= account.badge %>
                </span>
              </div>
            <% end %>

            <div class="text-center mb-4">
              <h3 class="text-xl font-bold text-gray-900 mb-2"><%= account.name %></h3>
              <div class="text-3xl font-black text-purple-600 mb-2"><%= account.price %></div>
              <p class="text-sm text-gray-600"><%= account.description %></p>
            </div>

            <ul class="space-y-2 mb-6">
              <%= for feature <- account.features do %>
                <li class="flex items-center text-sm text-gray-700">
                  <svg class="w-4 h-4 text-green-500 mr-2 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                  </svg>
                  <%= feature %>
                </li>
              <% end %>
            </ul>

            <button class={"w-full py-3 rounded-xl font-bold transition-all #{
              if account.recommended,
                do: "bg-gradient-to-r from-purple-600 to-pink-600 text-white hover:shadow-lg",
                else: "bg-gray-100 text-gray-700 hover:bg-gray-200"
            }"}>
              <%= if account.recommended, do: "Recommended", else: "Select Plan" %>
            </button>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_profile_step(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="text-center mb-8">
        <div class="w-16 h-16 bg-gradient-to-r from-indigo-600 to-purple-600 rounded-full flex items-center justify-center mx-auto mb-4">
          <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
          </svg>
        </div>
        <p class="text-lg text-gray-600">Just a few more details to complete your professional story.</p>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div>
          <label class="block text-sm font-bold text-gray-700 mb-2">Full Name</label>
          <input
            type="text"
            value={@story_data.name}
            phx-blur="update_profile"
            phx-value-field="name"
            class="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
            placeholder="Your professional name"
          />
        </div>

        <div>
          <label class="block text-sm font-bold text-gray-700 mb-2">Industry</label>
          <select
            phx-change="update_profile"
            phx-value-field="industry"
            class="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
          >
            <option value="">Select your industry</option>
            <%= for industry <- get_industries() do %>
              <option value={industry} selected={@story_data.industry == industry}><%= String.capitalize(industry) %></option>
            <% end %>
          </select>
        </div>

        <div class="md:col-span-2">
          <label class="block text-sm font-bold text-gray-700 mb-2">Experience Level</label>
          <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
            <%= for level <- get_experience_levels() do %>
              <button
                phx-click="update_profile"
                phx-value-field="experience"
                phx-value-value={level}
                class={"p-3 rounded-xl border-2 text-sm font-medium transition-all #{
                  if @story_data.experience == level,
                    do: "border-purple-500 bg-purple-50 text-purple-700",
                    else: "border-gray-200 text-gray-600 hover:border-purple-300"
                }"}
              >
                <%= level %>
              </button>
            <% end %>
          </div>
        </div>
      </div>

      <div class="bg-gradient-to-r from-purple-50 to-indigo-50 rounded-xl p-6 mt-8">
        <h3 class="font-bold text-gray-900 mb-4 flex items-center">
          <svg class="w-5 h-5 mr-2 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"/>
          </svg>
          Your Story Summary
        </h3>
        <div class="space-y-2 text-sm text-gray-700">
          <p><strong>Purpose:</strong> <%= format_purpose(@story_data.purpose) %></p>
          <p><strong>Audience:</strong> <%= format_audience(@story_data.audience) %></p>
          <p><strong>Goals:</strong> <%= length(@story_data.goals || []) %> selected</p>
          <p><strong>Account Type:</strong> <%= format_account_type(@story_data.account_type) %></p>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions for step data
  defp get_step_title(0), do: "What story are you telling?"
  defp get_step_title(1), do: "Who needs to hear your story?"
  defp get_step_title(2), do: "What do you want to achieve?"
  defp get_step_title(3), do: "Choose your storytelling toolkit"
  defp get_step_title(4), do: "Complete your profile"

  defp get_step_subtitle(0), do: "Help us understand your professional narrative"
  defp get_step_subtitle(1), do: "Define your target audience"
  defp get_step_subtitle(2), do: "Set your professional objectives"
  defp get_step_subtitle(3), do: "Select the perfect account type for your needs"
  defp get_step_subtitle(4), do: "Add the finishing touches"

  defp get_purposes do
    [
      %{
        id: "job-search",
        title: "Finding my next role",
        description: "Showcase skills and experience to land the perfect job",
        icon: ~s(<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2-2v2m8 0V6a2 2 0 012 2v6a2 2 0 01-2 2H6a2 2 0 01-2-2V8a2 2 0 012-2h8a2 2 0 012-2z"/></svg>)
      },
      %{
        id: "freelance",
        title: "Growing my freelance business",
        description: "Attract clients and demonstrate expertise",
        icon: ~s(<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/></svg>)
      },
      %{
        id: "personal-brand",
        title: "Building my personal brand",
        description: "Establish thought leadership and professional presence",
        icon: ~s(<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/></svg>)
      },
      %{
        id: "career-pivot",
        title: "Making a career change",
        description: "Transition to a new field or role",
        icon: ~s(<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>)
      }
    ]
  end

  defp get_audiences do
    [
      %{id: "hiring-managers", title: "Hiring Managers", description: "HR professionals and recruiters"},
      %{id: "potential-clients", title: "Potential Clients", description: "Businesses looking for services"},
      %{id: "industry-peers", title: "Industry Peers", description: "Professional network and colleagues"},
      %{id: "investors", title: "Investors/Partners", description: "Business partners and investors"}
    ]
  end

  defp get_goals do
    [
      %{id: "showcase-work", title: "Showcase my best work", icon: "🎨"},
      %{id: "demonstrate-skills", title: "Demonstrate technical skills", icon: "⚡"},
      %{id: "tell-story", title: "Tell my professional story", icon: "📖"},
      %{id: "build-credibility", title: "Build credibility & trust", icon: "🏆"},
      %{id: "generate-leads", title: "Generate business leads", icon: "💼"},
      %{id: "network-connect", title: "Network & connect", icon: "🤝"}
    ]
  end

  defp get_account_types do
    [
      %{
        id: "storyteller",
        name: "Storyteller",
        price: "Free",
        description: "Perfect for getting started with your professional story",
        features: [
          "2 portfolios",
          "Basic templates",
          "Video introductions (not streaming)",
          "Public sharing",
          "Access to the Lab"
        ],
        recommended: false,
        badge: nil
      },
      %{
        id: "professional",
        name: "Professional",
        price: "$12/month",
        description: "Ideal for job seekers and freelancers",
        features: [
          "Unlimited portfolios",
          "Premium templates",
          "Custom domains",
          "Analytics & insights",
          "ATS optimization",
          "Video introductions & streaming",
          "Full access to the Lab"
        ],
        recommended: true,
        badge: "Most Popular"
      },
      %{
        id: "business",
        name: "Business",
        price: "$29/month",
        description: "For agencies and growing businesses",
        features: [
          "Everything in Professional",
          "Team collaboration",
          "Multi-account management",
          "Advanced analytics",
          "Priority support",
          "White-label options",
          "Unlimited Lab access"
        ],
        recommended: false,
        badge: "Best Value"
      }
    ]
  end

  defp get_industries do
    ["technology", "design", "marketing", "finance", "healthcare", "education", "consulting", "other"]
  end

  defp get_experience_levels do
    ["Entry Level", "Mid Level", "Senior Level", "Executive"]
  end

  defp format_purpose(nil), do: "Not selected"
  defp format_purpose(purpose), do: String.replace(purpose, "-", " ") |> String.capitalize()

  defp format_audience(nil), do: "Not selected"
  defp format_audience(audience), do: String.replace(audience, "-", " ") |> String.capitalize()

  defp format_account_type(nil), do: "Not selected"
  defp format_account_type(type), do: String.capitalize(type)
end
