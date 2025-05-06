defmodule FrestylWeb.AIAssistantLive do
  use FrestylWeb, :live_component

  alias Frestyl.AIAssistant

  @impl true
  def mount(socket) do
    {:ok, assign(socket,
      onboarding_active: false,
      interaction_id: nil,
      current_question: nil,
      step: 0,
      total_steps: 0,
      responses: %{},
      recommendations: [],
      show_recommendations: false,
      setup_assistance: nil,
      show_setup_assistance: false
    )}
  end

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    # Load recommendations if user is logged in and component is initialized
    socket =
      if connected?(socket) && assigns[:current_user] && assigns[:id] do
        case get_user_recommendations(assigns.current_user.id) do
          {:ok, recommendations} ->
            assign(socket, recommendations: recommendations)
          _ ->
            socket
        end
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("start_onboarding", _, socket) do
    case AIAssistant.start_onboarding(socket.assigns.current_user) do
      {:ok, question} ->
        {:noreply, assign(socket,
          onboarding_active: true,
          interaction_id: question.id,
          current_question: question.text,
          step: question.step,
          total_steps: question.total_steps
        )}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to start onboarding")}
    end
  end

  @impl true
  def handle_event("submit_response", %{"response" => response}, socket) do
    case AIAssistant.process_onboarding_response(socket.assigns.interaction_id, response) do
      {:ok, question} ->
        responses = Map.put(socket.assigns.responses, "step_#{socket.assigns.step}", response)

        {:noreply, assign(socket,
          responses: responses,
          current_question: question.text,
          step: question.step,
          total_steps: question.total_steps
        )}

      {:ok, :completed, _preferences} ->
        responses = Map.put(socket.assigns.responses, "step_#{socket.assigns.step}", response)

        # Fetch recommendations after onboarding completion
        {:ok, recommendations} = get_user_recommendations(socket.assigns.current_user.id)

        {:noreply, assign(socket,
          onboarding_active: false,
          responses: responses,
          recommendations: recommendations,
          show_recommendations: true
        )}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to process response")}
    end
  end

  @impl true
  def handle_event("show_recommendations", _, socket) do
    {:noreply, assign(socket, show_recommendations: true)}
  end

  @impl true
  def handle_event("hide_recommendations", _, socket) do
    {:noreply, assign(socket, show_recommendations: false)}
  end

  @impl true
  def handle_event("update_recommendation", %{"id" => id, "status" => status}, socket) do
    # Update recommendation status (e.g., mark as dismissed or completed)
    # Implementation would update the recommendation in the database

    # For now, just update the UI
    updated_recommendations =
      Enum.map(socket.assigns.recommendations, fn rec ->
        if rec.id == id, do: %{rec | status: status}, else: rec
      end)

    {:noreply, assign(socket, recommendations: updated_recommendations)}
  end

  @impl true
  def handle_event("request_setup_assistance", %{"setup_type" => setup_type, "details" => details}, socket) do
    case AIAssistant.assist_with_setup(socket.assigns.current_user.id, setup_type, details) do
      {:ok, guidance} ->
        {:noreply, assign(socket,
          setup_assistance: guidance,
          show_setup_assistance: true
        )}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to generate setup assistance")}
    end
  end

  @impl true
  def handle_event("hide_setup_assistance", _, socket) do
    {:noreply, assign(socket, show_setup_assistance: false)}
  end

  # Helper function to get user recommendations
  defp get_user_recommendations(user_id) do
    # Check if user has recommendations, generate if not
    recommendations = Frestyl.Repo.all(Frestyl.AIAssistant.Recommendation, user_id: user_id)

    if Enum.empty?(recommendations) do
      AIAssistant.generate_recommendations(user_id)
    else
      {:ok, recommendations}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="ai-assistant-container">
      <!-- AI Assistant Button -->
      <div class="fixed bottom-4 right-4">
        <button
          phx-click={if @onboarding_active or @show_recommendations or @show_setup_assistance, do: "hide_assistant", else: "show_assistant"}
          class="bg-brand hover:bg-brand-dark text-white rounded-full p-3 shadow-lg transition-all duration-300 flex items-center justify-center"
        >
          <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
          </svg>
        </button>
      </div>

      <!-- AI Assistant Panel -->
      <div class={[
        "fixed bottom-20 right-4 bg-white rounded-lg shadow-xl transition-all duration-300 w-80 md:w-96 max-h-[80vh] overflow-y-auto",
        (if @onboarding_active or @show_recommendations or @show_setup_assistance, do: "opacity-100 scale-100", else: "opacity-0 scale-95 pointer-events-none")
      ]}>
        <div class="p-4 border-b border-gray-200">
          <div class="flex justify-between items-center">
            <h3 class="text-lg font-semibold text-gray-900">AI Assistant</h3>
            <button
              phx-click={if @onboarding_active, do: "cancel_onboarding", else: "hide_assistant"}
              class="text-gray-500 hover:text-gray-700"
            >
              <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>
        </div>

        <!-- Onboarding Flow -->
        <div :if={@onboarding_active} class="p-4">
          <div class="mb-4">
            <div class="flex justify-between text-sm text-gray-600 mb-2">
              <span>Step <%= @step %> of <%= @total_steps %></span>
              <span><%= round(@step / @total_steps * 100) %>% complete</span>
            </div>
            <div class="w-full bg-gray-200 rounded-full h-2">
              <div class="bg-brand h-2 rounded-full" style={"width: #{round(@step / @total_steps * 100)}%"}></div>
            </div>
          </div>

          <div class="mb-4">
            <p class="text-gray-800 mb-2"><%= @current_question %></p>
            <form phx-submit="submit_response" phx-target={@myself}>
              <textarea
                name="response"
                class="w-full border border-gray-300 rounded-md p-2 focus:ring-brand focus:border-brand"
                rows="3"
                placeholder="Your answer..."
                required
              ></textarea>
              <button type="submit" class="mt-2 w-full bg-brand hover:bg-brand-dark text-white rounded-md py-2 transition-colors duration-300">
                <%= if @step == @total_steps, do: "Complete", else: "Next" %>
              </button>
            </form>
          </div>
        </div>

        <!-- Recommendations Panel -->
        <div :if={@show_recommendations} class="p-4">
          <h4 class="font-medium text-gray-900 mb-3">Personalized Recommendations</h4>

          <div :if={Enum.empty?(@recommendations)} class="text-center py-4">
            <p class="text-gray-600">No recommendations available.</p>
            <button
              phx-click="start_onboarding"
              phx-target={@myself}
              class="mt-2 text-brand hover:text-brand-dark font-medium transition-colors duration-300"
            >
              Complete onboarding to get recommendations
            </button>
          </div>

          <div :for={rec <- @recommendations} :if={rec.status == "active"} class="mb-3 p-3 border border-gray-200 rounded-lg">
            <div class="flex justify-between items-start">
              <h5 class="font-medium text-gray-900"><%= rec.title %></h5>
              <span class="bg-brand/10 text-brand text-xs px-2 py-1 rounded-full"><%= rec.category %></span>
            </div>
            <p class="text-sm text-gray-600 mt-1 mb-2"><%= rec.description %></p>
            <div class="flex justify-between items-center">
              <div class="flex space-x-2">
                <button
                  phx-click="update_recommendation"
                  phx-value-id={rec.id}
                  phx-value-status="completed"
                  phx-target={@myself}
                  class="text-xs text-brand hover:text-brand-dark font-medium transition-colors duration-300"
                >
                  Mark completed
                </button>
                <button
                  phx-click="update_recommendation"
                  phx-value-id={rec.id}
                  phx-value-status="dismissed"
                  phx-target={@myself}
                  class="text-xs text-gray-500 hover:text-gray-700 transition-colors duration-300"
                >
                  Dismiss
                </button>
              </div>

              <div class="text-xs text-gray-500">
                Relevance: <%= round(rec.relevance_score * 100) %>%
              </div>
            </div>
          </div>
        </div>

        <!-- Setup Assistance Panel -->
        <div :if={@show_setup_assistance} class="p-4">
          <h4 class="font-medium text-gray-900 mb-3">Setup Assistance</h4>

          <div :if={@setup_assistance} class="p-3 border border-gray-200 rounded-lg">
            <div class="prose prose-sm max-w-none">
              <%= @setup_assistance %>
            </div>
          </div>

          <div :if={!@setup_assistance} class="mb-4">
            <form phx-submit="request_setup_assistance" phx-target={@myself}>
              <div class="mb-3">
                <label class="block text-sm font-medium text-gray-700 mb-1">What do you need help with?</label>
                <select name="setup_type" class="w-full border border-gray-300 rounded-md p-2 focus:ring-brand focus:border-brand">
                  <option value="event">Setting up an event</option>
                  <option value="session">Creating a session</option>
                  <option value="channel">Configuring a channel</option>
                </select>
              </div>

              <div class="mb-3">
                <label class="block text-sm font-medium text-gray-700 mb-1">Tell us more (optional)</label>
                <textarea
                  name="details"
                  class="w-full border border-gray-300 rounded-md p-2 focus:ring-brand focus:border-brand"
                  rows="3"
                  placeholder="Provide any additional details..."
                ></textarea>
              </div>

              <button type="submit" class="w-full bg-brand hover:bg-brand-dark text-white rounded-md py-2 transition-colors duration-300">
                Get Assistance
              </button>
            </form>
          </div>
        </div>

        <!-- Main Menu (when no specific panel is active) -->
        <div :if={!@onboarding_active && !@show_recommendations && !@show_setup_assistance} class="p-4">
          <div class="space-y-3">
            <button
              phx-click="start_onboarding"
              phx-target={@myself}
              class="w-full bg-white hover:bg-gray-50 text-gray-800 border border-gray-300 rounded-md py-2 px-4 flex items-center transition-colors duration-300"
            >
              <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-2 text-brand" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M9 4v4m-4 4h14v6a2 2 0 01-2 2H7a2 2 0 01-2-2v-6z" />
              </svg>
              <span>Start personalized onboarding</span>
            </button>

            <button
              phx-click="show_recommendations"
              phx-target={@myself}
              class="w-full bg-white hover:bg-gray-50 text-gray-800 border border-gray-300 rounded-md py-2 px-4 flex items-center transition-colors duration-300"
            >
              <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-2 text-brand" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 3v4M3 5h4M6 17v4m-2-2h4m5-16l2.286 6.857L21 12l-5.714 2.143L13 21l-2.286-6.857L5 12l5.714-2.143L13 3z" />
              </svg>
              <span>View recommendations</span>
            </button>

            <button
              phx-click="show_setup_assistance"
              phx-target={@myself}
              class="w-full bg-white hover:bg-gray-50 text-gray-800 border border-gray-300 rounded-md py-2 px-4 flex items-center transition-colors duration-300"
            >
              <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-2 text-brand" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
              </svg>
              <span>Get setup assistance</span>
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
