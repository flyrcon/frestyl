# lib/frestyl_web/live/media_live/reactions_component.ex

defmodule FrestylWeb.MediaLive.ReactionsComponent do
  use FrestylWeb, :live_component
  alias Frestyl.Media

  # Available reaction types with their emojis and colors
  @reaction_types %{
    "heart" => %{emoji: "❤️", color: "red", icon: :heart},
    "fire" => %{emoji: "🔥", color: "orange", icon: :fire},
    "lightbulb" => %{emoji: "💡", color: "yellow", icon: :lightbulb},
    "star" => %{emoji: "⭐", color: "purple", icon: :star},
    "thumbsup" => %{emoji: "👍", color: "blue", icon: :thumbsup},
    "laugh" => %{emoji: "😄", color: "green", icon: :laugh}
  }

  def mount(socket) do
    {:ok, assign(socket, :show_picker, false)}
  end

  def update(%{file: file, current_user: current_user} = assigns, socket) do
    # Subscribe to reactions for this file
    Media.subscribe_to_file_reactions(file.id)

    # Get reaction summary
    reaction_summary = Media.get_reaction_summary(file)

    socket =
      socket
      |> assign(assigns)
      |> assign(:reaction_summary, reaction_summary)
      |> assign(:available_reactions, @reaction_types)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="reactions-container" id={"reactions-#{@file.id}"}>
      <%= if @mode == :compact do %>
        <!-- Compact mode for cards -->
        <div class="flex items-center space-x-2">
          <!-- Top 3 reactions -->
          <%= for {reaction_type, count} <- get_top_reactions(@reaction_summary.reactions, 3) do %>
            <button
              phx-click="toggle_reaction"
              phx-value-type={reaction_type}
              phx-target={@myself}
              class={[
                "flex items-center space-x-1 px-2 py-1 rounded-full text-xs font-medium transition-all duration-200",
                reaction_button_classes(reaction_type, @current_user, @reaction_summary, :compact)
              ]}
            >
              <span class="text-sm"><%= get_reaction_emoji(reaction_type) %></span>
              <span><%= count %></span>
            </button>
          <% end %>

          <!-- Add reaction button -->
          <%= if @current_user do %>
            <button
              phx-click="toggle_picker"
              phx-target={@myself}
              class="flex items-center justify-center w-6 h-6 rounded-full bg-gray-100 hover:bg-gray-200 text-gray-500 hover:text-gray-700 transition-all duration-200"
              title="Add reaction"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
              </svg>
            </button>
          <% end %>
        </div>
      <% else %>
        <!-- Full mode for modal -->
        <div class="space-y-4">
          <h3 class="text-sm font-semibold text-gray-900">Quick Reactions</h3>

          <!-- Reaction Grid -->
          <div class="grid grid-cols-3 gap-2">
            <%= for {reaction_type, reaction_info} <- @available_reactions do %>
              <button
                phx-click="toggle_reaction"
                phx-value-type={reaction_type}
                phx-target={@myself}
                class={[
                  "flex flex-col items-center p-3 rounded-lg transition-all duration-200 group relative",
                  reaction_button_classes(reaction_type, @current_user, @reaction_summary, :full)
                ]}
                phx-hook="ReactionButton"
                id={"reaction-#{reaction_type}-#{@file.id}"}
              >
                <!-- Reaction Emoji/Icon -->
                <div class="text-2xl mb-1 group-hover:scale-110 transition-transform duration-200">
                  <%= get_reaction_emoji(reaction_type) %>
                </div>

                <!-- Count -->
                <span class="text-xs font-medium">
                  <%= Map.get(@reaction_summary.reactions, reaction_type, 0) %>
                </span>

                <!-- User indicator -->
                <%= if user_has_reacted?(@reaction_summary, reaction_type, @current_user) do %>
                  <div class="absolute -top-1 -right-1 w-3 h-3 bg-purple-500 rounded-full border-2 border-white"></div>
                <% end %>

                <!-- Floating animation container -->
                <div class="absolute inset-0 pointer-events-none" id={"floating-#{reaction_type}-#{@file.id}"}></div>
              </button>
            <% end %>
          </div>

          <!-- Reaction Summary -->
          <%= if @reaction_summary.total_reactions > 0 do %>
            <div class="border-t border-gray-200 pt-3">
              <div class="flex items-center justify-between text-xs text-gray-500">
                <span>
                  <%= @reaction_summary.total_reactions %> reaction<%= if @reaction_summary.total_reactions != 1, do: "s" %>
                </span>
                <%= if @reaction_summary.top_reaction do %>
                  <span class="flex items-center space-x-1">
                    <span>Most popular:</span>
                    <span><%= get_reaction_emoji(@reaction_summary.top_reaction) %></span>
                  </span>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>

      <!-- Reaction Picker Popup (for compact mode) -->
      <%= if @show_picker and @mode == :compact do %>
        <div class="absolute z-50 mt-2 p-2 bg-white rounded-lg shadow-lg border border-gray-200">
          <div class="grid grid-cols-3 gap-1">
            <%= for {reaction_type, _reaction_info} <- @available_reactions do %>
              <button
                phx-click="quick_react"
                phx-value-type={reaction_type}
                phx-target={@myself}
                class="p-2 rounded-md hover:bg-gray-100 transition-colors duration-200"
                title={String.capitalize(reaction_type)}
              >
                <span class="text-lg"><%= get_reaction_emoji(reaction_type) %></span>
              </button>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Event Handlers
  def handle_event("toggle_reaction", %{"type" => reaction_type}, socket) do
    if socket.assigns.current_user do
      case Media.add_reaction(socket.assigns.file, reaction_type, socket.assigns.current_user.id) do
        {:ok, updated_file} ->
          # Update local state and notify parent
          reaction_summary = Media.get_reaction_summary(updated_file)
          send(self(), {:media_file_updated, updated_file})

          {:noreply, assign(socket, :reaction_summary, reaction_summary)}
        {:error, _} ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("toggle_picker", _params, socket) do
    {:noreply, assign(socket, :show_picker, !socket.assigns.show_picker)}
  end

  def handle_event("quick_react", %{"type" => reaction_type}, socket) do
    # Same as toggle_reaction but also close picker
    socket = if socket.assigns.current_user do
      case Media.add_reaction(socket.assigns.file, reaction_type, socket.assigns.current_user.id) do
        {:ok, updated_file} ->
          reaction_summary = Media.get_reaction_summary(updated_file)
          send(self(), {:media_file_updated, updated_file})
          assign(socket, :reaction_summary, reaction_summary)
        {:error, _} ->
          socket
      end
    else
      socket
    end

    {:noreply, assign(socket, :show_picker, false)}
  end

  # Handle real-time reaction updates
  def handle_info({:reaction_added, %{file_id: file_id, reaction_type: reaction_type, user_id: user_id}}, socket) do
    if file_id == socket.assigns.file.id do
      # Update reaction summary
      updated_file = Media.get_media_file(file_id)
      if updated_file do
        reaction_summary = Media.get_reaction_summary(updated_file)
        # Trigger floating animation if it's not from current user
        current_user_id = socket.assigns.current_user && socket.assigns.current_user.id
        if user_id != current_user_id do
          send_update(self(), __MODULE__,
            id: socket.assigns.id,
            trigger_animation: reaction_type
          )
        end
        {:noreply, assign(socket, :reaction_summary, reaction_summary)}
      else
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_info({:reaction_removed, %{file_id: file_id}}, socket) do
    if file_id == socket.assigns.file.id do
      updated_file = Media.get_media_file(file_id)
      if updated_file do
        reaction_summary = Media.get_reaction_summary(updated_file)
        {:noreply, assign(socket, :reaction_summary, reaction_summary)}
      else
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_info(_, socket), do: {:noreply, socket}

  # Helper functions
  defp get_top_reactions(reactions, limit) do
    reactions
    |> Enum.sort_by(fn {_type, count} -> count end, :desc)
    |> Enum.take(limit)
  end

  defp get_reaction_emoji(reaction_type) do
    @reaction_types[reaction_type][:emoji] || "👍"
  end

  defp reaction_button_classes(reaction_type, current_user, reaction_summary, mode) do
    has_reacted = user_has_reacted?(reaction_summary, reaction_type, current_user)
    reaction_info = @reaction_types[reaction_type]
    color = reaction_info[:color]

    base_classes = case mode do
      :compact -> "hover:scale-105"
      :full -> "hover:shadow-md"
    end

    if has_reacted do
      "#{base_classes} bg-#{color}-100 text-#{color}-700 border-2 border-#{color}-300"
    else
      "#{base_classes} bg-gray-50 text-gray-600 border-2 border-transparent hover:bg-#{color}-50 hover:text-#{color}-600"
    end
  end

  defp user_has_reacted?(reaction_summary, reaction_type, nil), do: false
  defp user_has_reacted?(reaction_summary, reaction_type, current_user) do
    user_reactions = Map.get(reaction_summary.user_reactions, to_string(current_user.id), [])
    reaction_type in user_reactions
  end
end
