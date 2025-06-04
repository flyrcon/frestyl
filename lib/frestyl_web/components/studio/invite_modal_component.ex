defmodule FrestylWeb.Studio.InviteModalComponent do
  use FrestylWeb, :live_component
  alias Frestyl.Accounts
  alias Frestyl.Sessions
  alias Frestyl.Channels

  @impl true
  def mount(socket) do
    {:ok, assign(socket,
      show: false,
      email_input: "",
      search_input: "",
      selected_users: [],
      search_results: [],
      invite_link: nil,
      selected_permission: "participant",
      loading: false,
      error_message: nil,
      success_message: nil,
      show_link_options: false
    )}
  end

  @impl true
  def update(%{show: show} = assigns, socket) when is_boolean(show) do
    socket = assign(socket, assigns)

    if show and not socket.assigns.show do
      # Generate invite link when modal opens
      invite_link = generate_invite_link(socket.assigns.session.id)
      {:ok, assign(socket, show: show, invite_link: invite_link)}
    else
      {:ok, assign(socket, show: show)}
    end
  end

  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def handle_event("close_modal", _, socket) do
    send(self(), :close_invite_modal)
    {:noreply, assign(socket, show: false)}
  end

  @impl true
  def handle_event("search_users", %{"search" => search}, socket) when search != "" do
    if String.length(search) >= 2 do
      # Search for users (excluding current session participants)
      current_participants = Sessions.get_session_participant_ids(socket.assigns.session.id)

      case Accounts.search_users(search, exclude_ids: current_participants, limit: 10) do
        {:ok, users} ->
          {:noreply, assign(socket, search_results: users, search_input: search)}
        {:error, _} ->
          {:noreply, assign(socket, search_results: [], error_message: "Search failed")}
      end
    else
      {:noreply, assign(socket, search_results: [], search_input: search)}
    end
  end

  def handle_event("search_users", %{"search" => ""}, socket) do
    {:noreply, assign(socket, search_results: [], search_input: "")}
  end

  @impl true
  def handle_event("select_user", %{"user_id" => user_id}, socket) do
    user_id = String.to_integer(user_id)
    user = Enum.find(socket.assigns.search_results, &(&1.id == user_id))

    if user && not Enum.any?(socket.assigns.selected_users, &(&1.id == user_id)) do
      selected_users = [user | socket.assigns.selected_users]
      {:noreply, assign(socket, selected_users: selected_users, search_input: "", search_results: [])}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("remove_user", %{"user_id" => user_id}, socket) do
    user_id = String.to_integer(user_id)
    selected_users = Enum.reject(socket.assigns.selected_users, &(&1.id == user_id))
    {:noreply, assign(socket, selected_users: selected_users)}
  end

  @impl true
  def handle_event("update_permission", %{"permission" => permission}, socket) do
    {:noreply, assign(socket, selected_permission: permission)}
  end

  @impl true
  def handle_event("send_invites", _, socket) do
    if length(socket.assigns.selected_users) > 0 do
      session = socket.assigns.session
      current_user = socket.assigns.current_user
      permission = socket.assigns.selected_permission

      {:noreply, assign(socket, loading: true, error_message: nil)}

      # Send invites in a separate process to avoid blocking
      Task.start(fn ->
        results = invite_users_to_session(socket.assigns.selected_users, session, current_user, permission)
        send(self(), {:invite_results, results})
      end)

      {:noreply, socket}
    else
      {:noreply, assign(socket, error_message: "Please select at least one user to invite")}
    end
  end

  @impl true
  def handle_event("copy_invite_link", _, socket) do
    {:noreply,
      socket
      |> assign(success_message: "Invite link copied to clipboard!")
      |> push_event("copy_to_clipboard", %{text: socket.assigns.invite_link})}
  end

  @impl true
  def handle_event("toggle_link_options", _, socket) do
    {:noreply, assign(socket, show_link_options: !socket.assigns.show_link_options)}
  end

  @impl true
  def handle_event("regenerate_link", _, socket) do
    new_link = generate_invite_link(socket.assigns.session.id, regenerate: true)
    {:noreply, assign(socket, invite_link: new_link, success_message: "New invite link generated!")}
  end

  # Handle invite results from Task
  @impl true
  def handle_info({:invite_results, results}, socket) do
    {success_count, failed_count} = count_results(results)

    if failed_count == 0 do
      success_msg = "Successfully invited #{success_count} user#{if success_count == 1, do: "", else: "s"}!"

      {:noreply, assign(socket,
        loading: false,
        success_message: success_msg,
        selected_users: [],
        error_message: nil
      )}
    else
      error_msg = "#{success_count} invites sent, #{failed_count} failed"

      {:noreply, assign(socket,
        loading: false,
        error_message: error_msg,
        success_message: nil
      )}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%= if @show do %>
      <div class="fixed inset-0 z-50 overflow-y-auto" role="dialog" aria-modal="true" aria-labelledby="invite-modal-title">
        <!-- Backdrop -->
        <div class="fixed inset-0 bg-black/70 backdrop-blur-sm transition-opacity" phx-click="close_modal" phx-target={@myself}></div>

        <!-- Modal -->
        <div class="flex min-h-full items-center justify-center p-4">
          <div class="relative w-full max-w-lg bg-black/90 backdrop-blur-xl rounded-2xl shadow-2xl border border-white/20 overflow-hidden">
            <!-- Header -->
            <div class="flex items-center justify-between p-6 border-b border-white/10">
              <h3 id="invite-modal-title" class="text-xl font-bold text-white">Invite Collaborators</h3>
              <button
                phx-click="close_modal"
                phx-target={@myself}
                class="text-white/60 hover:text-white p-2 rounded-lg hover:bg-white/10 transition-colors"
              >
                <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>

            <!-- Content -->
            <div class="p-6 space-y-6">
              <!-- Error/Success Messages -->
              <%= if @error_message do %>
                <div class="bg-red-900/30 border border-red-500/30 rounded-lg p-3 text-red-200 text-sm">
                  <%= @error_message %>
                </div>
              <% end %>

              <%= if @success_message do %>
                <div class="bg-green-900/30 border border-green-500/30 rounded-lg p-3 text-green-200 text-sm">
                  <%= @success_message %>
                </div>
              <% end %>

              <!-- User Search -->
              <div>
                <label class="block text-sm font-medium text-white mb-2">Search Users</label>
                <div class="relative">
                  <input
                    type="text"
                    value={@search_input}
                    phx-keyup="search_users"
                    phx-debounce="300"
                    phx-target={@myself}
                    placeholder="Enter name or email..."
                    class="w-full bg-white/10 border border-white/20 rounded-lg px-4 py-3 text-white placeholder-white/50 focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-transparent"
                  />

                  <!-- Search Results Dropdown -->
                  <%= if length(@search_results) > 0 do %>
                    <div class="absolute top-full left-0 right-0 mt-1 bg-black/95 backdrop-blur-xl border border-white/20 rounded-lg shadow-xl z-10 max-h-60 overflow-y-auto">
                      <%= for user <- @search_results do %>
                        <button
                          phx-click="select_user"
                          phx-value-user_id={user.id}
                          phx-target={@myself}
                          class="w-full flex items-center gap-3 p-3 hover:bg-white/10 transition-colors text-left"
                        >
                          <%= if user.avatar_url do %>
                            <img src={user.avatar_url} class="h-8 w-8 rounded-full" alt={user.username} />
                          <% else %>
                            <div class="h-8 w-8 rounded-full bg-gradient-to-br from-purple-500 to-pink-600 flex items-center justify-center text-white font-bold text-sm">
                              <%= String.at(user.username || user.email, 0) |> String.upcase() %>
                            </div>
                          <% end %>

                          <div class="flex-1 min-w-0">
                            <p class="text-white font-medium"><%= user.username || user.email %></p>
                            <%= if user.full_name do %>
                              <p class="text-white/60 text-sm truncate"><%= user.full_name %></p>
                            <% end %>
                          </div>
                        </button>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              </div>

              <!-- Selected Users -->
              <%= if length(@selected_users) > 0 do %>
                <div>
                  <label class="block text-sm font-medium text-white mb-2">Selected Users</label>
                  <div class="space-y-2">
                    <%= for user <- @selected_users do %>
                      <div class="flex items-center justify-between bg-white/5 rounded-lg p-3 border border-white/10">
                        <div class="flex items-center gap-3">
                          <%= if user.avatar_url do %>
                            <img src={user.avatar_url} class="h-8 w-8 rounded-full" alt={user.username} />
                          <% else %>
                            <div class="h-8 w-8 rounded-full bg-gradient-to-br from-purple-500 to-pink-600 flex items-center justify-center text-white font-bold text-sm">
                              <%= String.at(user.username || user.email, 0) |> String.upcase() %>
                            </div>
                          <% end %>

                          <div>
                            <p class="text-white font-medium"><%= user.username || user.email %></p>
                            <%= if user.full_name do %>
                              <p class="text-white/60 text-sm"><%= user.full_name %></p>
                            <% end %>
                          </div>
                        </div>

                        <button
                          phx-click="remove_user"
                          phx-value-user_id={user.id}
                          phx-target={@myself}
                          class="text-white/60 hover:text-red-400 p-1 rounded transition-colors"
                        >
                          <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                          </svg>
                        </button>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %>

              <!-- Permission Level -->
              <div>
                <label class="block text-sm font-medium text-white mb-2">Permission Level</label>
                <select
                  phx-change="update_permission"
                  phx-target={@myself}
                  class="w-full bg-white/10 border border-white/20 rounded-lg px-4 py-3 text-white focus:outline-none focus:ring-2 focus:ring-purple-500"
                >
                  <option value="participant" selected={@selected_permission == "participant"}>Participant - Can edit and collaborate</option>
                  <option value="viewer" selected={@selected_permission == "viewer"}>Viewer - Can only view content</option>
                  <option value="moderator" selected={@selected_permission == "moderator"}>Moderator - Can manage session</option>
                </select>
              </div>

              <!-- Invite Link Section -->
              <div class="border-t border-white/10 pt-6">
                <div class="flex items-center justify-between mb-3">
                  <label class="text-sm font-medium text-white">Share Invite Link</label>
                  <button
                    phx-click="toggle_link_options"
                    phx-target={@myself}
                    class="text-white/60 hover:text-white text-sm"
                  >
                    Options
                  </button>
                </div>

                <div class="flex gap-2">
                  <input
                    type="text"
                    readonly
                    value={@invite_link}
                    class="flex-1 bg-white/5 border border-white/20 rounded-lg px-4 py-3 text-white/80 text-sm"
                  />
                  <button
                    phx-click="copy_invite_link"
                    phx-target={@myself}
                    class="bg-gradient-to-r from-blue-500 to-purple-600 hover:from-blue-600 hover:to-purple-700 text-white px-4 py-3 rounded-lg font-medium transition-all duration-200 shadow-lg"
                  >
                    Copy
                  </button>
                </div>

                <%= if @show_link_options do %>
                  <div class="mt-3 p-3 bg-white/5 rounded-lg border border-white/10">
                    <button
                      phx-click="regenerate_link"
                      phx-target={@myself}
                      class="text-sm text-yellow-400 hover:text-yellow-300 font-medium"
                    >
                      Generate New Link
                    </button>
                    <p class="text-xs text-white/60 mt-1">This will invalidate the current link</p>
                  </div>
                <% end %>
              </div>
            </div>

            <!-- Footer -->
            <div class="flex items-center justify-end gap-3 px-6 py-4 border-t border-white/10 bg-black/30">
              <button
                phx-click="close_modal"
                phx-target={@myself}
                class="px-4 py-2 text-white/70 hover:text-white font-medium transition-colors"
                disabled={@loading}
              >
                Cancel
              </button>

              <button
                phx-click="send_invites"
                phx-target={@myself}
                disabled={length(@selected_users) == 0 || @loading}
                class={[
                  "px-6 py-2 rounded-lg font-medium transition-all duration-200",
                  (length(@selected_users) > 0 && !@loading) && "bg-gradient-to-r from-purple-500 to-pink-600 hover:from-purple-600 hover:to-pink-700 text-white shadow-lg",
                  (length(@selected_users) == 0 || @loading) && "bg-gray-600 text-gray-400 cursor-not-allowed"
                ]}
              >
                <%= if @loading do %>
                  <svg class="animate-spin h-4 w-4 mr-2 inline" fill="none" viewBox="0 0 24 24">
                    <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                    <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                  </svg>
                  Sending...
                <% else %>
                  Send Invites (<%= length(@selected_users) %>)
                <% end %>
              </button>
            </div>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  # Helper functions
  defp generate_invite_link(session_id, opts \\ []) do
    # Generate a secure invite token
    token = if Keyword.get(opts, :regenerate, false) do
      Sessions.regenerate_invite_token(session_id)
    else
      Sessions.get_or_create_invite_token(session_id)
    end

    FrestylWeb.Router.Helpers.studio_url(FrestylWeb.Endpoint, :join_by_invite, token)
  end

  defp invite_users_to_session(users, session, inviter, permission) do
    Enum.map(users, fn user ->
      case Sessions.invite_user_to_session(user, session, inviter, permission) do
        {:ok, _invitation} -> {:ok, user}
        {:error, reason} -> {:error, user, reason}
      end
    end)
  end

  defp count_results(results) do
    Enum.reduce(results, {0, 0}, fn
      {:ok, _}, {success, failed} -> {success + 1, failed}
      {:error, _, _}, {success, failed} -> {success, failed + 1}
    end)
  end
end
