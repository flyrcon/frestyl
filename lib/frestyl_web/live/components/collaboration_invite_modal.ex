# lib/frestyl_web/live/components/collaboration_invite_modal.ex
defmodule FrestylWeb.Components.CollaborationInviteModal do
  use FrestylWeb, :live_component
  alias Frestyl.Stories

  def render(assigns) do
    ~H"""
    <%= if @show do %>
      <div class="fixed inset-0 z-50 overflow-y-auto">
        <div class="flex items-center justify-center min-h-screen px-4">
          <div class="fixed inset-0 bg-gray-500 bg-opacity-75" phx-click="close_modal" phx-target={@myself}></div>

          <div class="relative bg-white rounded-xl shadow-xl max-w-lg w-full p-6">
            <div class="flex items-center justify-between mb-6">
              <h3 class="text-lg font-semibold text-gray-900">Invite Collaborator</h3>
              <button
                type="button"
                phx-click="close_modal"
                phx-target={@myself}
                class="text-gray-400 hover:text-gray-600"
              >
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>

            <.form for={%{}} phx-submit="send_invitation" phx-target={@myself} class="space-y-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Email Address</label>
                <input
                  type="email"
                  name="email"
                  placeholder="colleague@example.com"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  required
                />
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Role</label>
                <select
                  name="role"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                >
                  <option value="viewer">Viewer - Can view the story</option>
                  <option value="commenter">Commenter - Can view and comment</option>
                  <%= if @can_grant_edit_access do %>
                    <option value="editor">Editor - Can edit content</option>
                    <option value="co_author">Co-Author - Full collaboration access</option>
                  <% end %>
                </select>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Personal Message (Optional)</label>
                <textarea
                  name="message"
                  rows="3"
                  placeholder="Hi! I'd love to collaborate with you on this story..."
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                ></textarea>
              </div>

              <!-- Permission Details -->
              <div class="bg-gray-50 rounded-lg p-4">
                <h4 class="text-sm font-medium text-gray-900 mb-2">Access Details</h4>
                <div class="space-y-1 text-sm text-gray-600">
                  <p>• Invitation expires in 7 days</p>
                  <p>• Collaborator can access this story only</p>
                  <%= if @account_limits_collaboration do %>
                    <p>• Some features may be limited based on subscription tiers</p>
                  <% end %>
                </div>
              </div>

              <div class="flex space-x-3 pt-4">
                <button
                  type="button"
                  phx-click="close_modal"
                  phx-target={@myself}
                  class="flex-1 px-4 py-2 text-gray-700 bg-gray-100 rounded-lg hover:bg-gray-200"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  class="flex-1 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
                >
                  Send Invitation
                </button>
              </div>
            </.form>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  def handle_event("send_invitation", params, socket) do
    story = socket.assigns.story
    current_user = socket.assigns.current_user

    case Stories.invite_collaborator(
      story,
      current_user,
      params["email"],
      String.to_atom(params["role"]),
      %{custom_message: params["message"]}
    ) do
      {:ok, collaboration} ->
        send(self(), {:collaboration_invited, collaboration})
        {:noreply, socket}

      {:error, :collaborator_limit_reached} ->
        send(self(), {:show_upgrade_modal, :collaborator_limit})
        {:noreply, socket}

      {:error, reason} ->
        send(self(), {:collaboration_error, reason})
        {:noreply, socket}
    end
  end

  def handle_event("close_modal", _params, socket) do
    send(self(), :close_collaboration_modal)
    {:noreply, socket}
  end
end
