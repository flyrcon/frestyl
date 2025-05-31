# lib/frestyl_web/live/components/enhanced_comments_component.ex

defmodule FrestylWeb.MediaLive.EnhancedCommentsComponent do
  use FrestylWeb, :live_component
  alias Frestyl.Media

  def update(%{file: file} = assigns, socket) do
    # Subscribe to real-time comments for this file
    Phoenix.PubSub.subscribe(Frestyl.PubSub, "file_comments:#{file.id}")

    # Load threaded comments
    comments = Media.list_threaded_comments_for_file(file.id)

    socket =
      socket
      |> assign(assigns)
      |> assign(:comments, comments)
      |> assign(:comment_form, %{"content" => "", "parent_id" => nil})
      |> assign(:reply_forms, %{})
      |> assign(:show_reply_form, nil)
      |> assign(:expanded_threads, MapSet.new())

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="enhanced-comments flex-1 flex flex-col" id={"comments-#{@file.id}"}>
      <!-- Comments Header -->
      <div class="px-6 py-4 border-b border-gray-200">
        <div class="flex items-center justify-between">
          <h3 class="text-sm font-semibold text-gray-900">
            Comments (<%= count_total_comments(@comments) %>)
          </h3>
          <button
            phx-click="toggle_all_threads"
            phx-target={@myself}
            class="text-xs text-purple-600 hover:text-purple-700 font-medium"
          >
            <%= if all_threads_expanded?(@comments, @expanded_threads) do %>
              Collapse All
            <% else %>
              Expand All
            <% end %>
          </button>
        </div>
      </div>

      <!-- Comments List with Threading -->
      <div class="flex-1 overflow-y-auto px-6 py-4 space-y-4" id="comments-container" phx-hook="AutoScrollComments">
        <%= if @comments == [] do %>
          <.empty_comments_state />
        <% else %>
          <%= for comment <- @comments do %>
            <.threaded_comment
              comment={comment}
              current_user={@current_user}
              myself={@myself}
              file_id={@file.id}
              reply_forms={@reply_forms}
              show_reply_form={@show_reply_form}
              expanded_threads={@expanded_threads}
              level={0}
            />
          <% end %>
        <% end %>
      </div>

      <!-- Main Comment Input -->
      <%= if @current_user do %>
        <div class="px-6 py-4 border-t border-gray-200">
          <.comment_form
            form_data={@comment_form}
            current_user={@current_user}
            myself={@myself}
            placeholder="Add a comment..."
            submit_label="Comment"
            form_id="main-comment"
          />
        </div>
      <% else %>
        <div class="px-6 py-4 border-t border-gray-200 text-center">
          <p class="text-sm text-gray-500">
            <a href="/login" class="text-purple-600 hover:text-purple-700 font-medium">Sign in</a> to join the conversation
          </p>
        </div>
      <% end %>
    </div>
    """
  end

  # Threaded Comment Component
  defp threaded_comment(assigns) do
    ~H"""
    <div class={[
      "threaded-comment",
      "ml-#{@level * 4}", # Indent based on nesting level
      if(@level > 0, do: "border-l-2 border-gray-100 pl-4", else: "")
    ]} id={"comment-#{@comment.id}"}>

      <!-- Main Comment -->
      <div class="flex space-x-3" data-comment-id={@comment.id}>
        <!-- User Avatar -->
        <div class="flex-shrink-0">
          <.user_avatar user={@comment.user} size={if @level > 2, do: :small, else: :normal} />
        </div>

        <!-- Comment Content -->
        <div class="flex-1 min-w-0">
          <div class="bg-gray-50 rounded-lg px-3 py-2 relative group">
            <!-- Comment Header -->
            <div class="flex items-center space-x-2 mb-1">
              <span class="text-sm font-medium text-gray-900">
                <%= @comment.user.name %>
              </span>
              <span class="text-xs text-gray-500">
                <%= format_comment_time(@comment.inserted_at) %>
              </span>
              <%= if @comment.edited_at do %>
                <span class="text-xs text-gray-400">(edited)</span>
              <% end %>
              <%= if @comment.parent_id do %>
                <svg class="w-3 h-3 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 10h10a8 8 0 018 8v2M3 10l6 6m-6-6l6-6"/>
                </svg>
              <% end %>
            </div>

            <!-- Comment Text -->
            <p class="text-sm text-gray-700 leading-relaxed">
              <%= @comment.content %>
            </p>

            <!-- Reaction Pills (small, inline) -->
            <%= if has_reactions?(@comment) do %>
              <div class="flex items-center space-x-1 mt-2">
                <%= for {reaction_type, count} <- @comment.reaction_summary do %>
                  <button
                    phx-click="toggle_comment_reaction"
                    phx-value-comment-id={@comment.id}
                    phx-value-reaction-type={reaction_type}
                    phx-target={@myself}
                    class={[
                      "inline-flex items-center px-2 py-1 rounded-full text-xs transition-all",
                      "border border-gray-200 hover:border-purple-300",
                      if(user_reacted_to_comment?(@comment, @current_user, reaction_type),
                        do: "bg-purple-100 text-purple-700 border-purple-300",
                        else: "bg-white text-gray-600 hover:bg-gray-50")
                    ]}
                  >
                    <span class="mr-1"><%= get_reaction_emoji(reaction_type) %></span>
                    <span><%= count %></span>
                  </button>
                <% end %>
              </div>
            <% end %>
          </div>

          <!-- Comment Actions -->
          <%= if @current_user do %>
            <div class="flex items-center space-x-3 mt-2 text-xs">
              <!-- Reply Button -->
              <button
                phx-click="show_reply_form"
                phx-value-comment-id={@comment.id}
                phx-target={@myself}
                class="text-gray-500 hover:text-purple-600 transition-colors duration-200 font-medium"
              >
                Reply
              </button>

              <!-- Quick Reactions -->
              <div class="flex items-center space-x-1">
                <%= for reaction_type <- ["heart", "fire", "thumbsup"] do %>
                  <button
                    phx-click="toggle_comment_reaction"
                    phx-value-comment-id={@comment.id}
                    phx-value-reaction-type={reaction_type}
                    phx-target={@myself}
                    class={[
                      "p-1 rounded transition-all hover:scale-110",
                      if(user_reacted_to_comment?(@comment, @current_user, reaction_type),
                        do: "text-purple-600",
                        else: "text-gray-400 hover:text-gray-600")
                    ]}
                    title={reaction_type}
                  >
                    <%= get_reaction_emoji(reaction_type) %>
                  </button>
                <% end %>
              </div>

              <!-- Delete Button (if owner) -->
              <%= if @current_user.id == @comment.user_id do %>
                <button
                  phx-click="delete_comment"
                  phx-value-comment-id={@comment.id}
                  phx-target={@myself}
                  class="text-gray-400 hover:text-red-600 transition-colors duration-200"
                  data-confirm="Delete this comment?"
                >
                  Delete
                </button>
              <% end %>
            </div>
          <% end %>

          <!-- Reply Form -->
          <%= if @show_reply_form == @comment.id do %>
            <div class="mt-3">
              <.comment_form
                form_data={Map.get(@reply_forms, @comment.id, %{"content" => "", "parent_id" => @comment.id})}
                current_user={@current_user}
                myself={@myself}
                placeholder={"Reply to #{@comment.user.name}..."}
                submit_label="Reply"
                form_id={"reply-#{@comment.id}"}
                parent_id={@comment.id}
                compact={true}
              />
            </div>
          <% end %>

          <!-- Nested Replies -->
          <%= if has_replies?(@comment) and @level < 5 do %>
            <div class="mt-4">
              <!-- Thread Toggle (if there are replies) -->
              <%= if length(@comment.replies) > 0 do %>
                <button
                  phx-click="toggle_thread"
                  phx-value-comment-id={@comment.id}
                  phx-target={@myself}
                  class="flex items-center space-x-2 text-xs text-gray-500 hover:text-purple-600 transition-colors mb-3"
                >
                  <svg class={[
                    "w-3 h-3 transition-transform",
                    if(thread_expanded?(@comment.id, @expanded_threads), do: "rotate-90", else: "")
                  ]} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
                  </svg>
                  <span>
                    <%= if thread_expanded?(@comment.id, @expanded_threads) do %>
                      Hide <%= length(@comment.replies) %> replies
                    <% else %>
                      Show <%= length(@comment.replies) %> replies
                    <% end %>
                  </span>
                </button>
              <% end %>

              <!-- Render Replies -->
              <%= if thread_expanded?(@comment.id, @expanded_threads) do %>
                <div class="space-y-3">
                  <%= for reply <- @comment.replies do %>
                    <.threaded_comment
                      comment={reply}
                      current_user={@current_user}
                      myself={@myself}
                      file_id={@file_id}
                      reply_forms={@reply_forms}
                      show_reply_form={@show_reply_form}
                      expanded_threads={@expanded_threads}
                      level={@level + 1}
                    />
                  <% end %>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Reusable Comment Form
  defp comment_form(assigns) do
    ~H"""
    <form phx-submit="submit_comment" phx-target={@myself} class="space-y-3" id={@form_id}>
      <input type="hidden" name="parent_id" value={@parent_id || ""} />

      <div class={[
        "flex space-x-3",
        if(@compact, do: "items-start", else: "")
      ]}>
        <!-- Current User Avatar -->
        <div class="flex-shrink-0">
          <.user_avatar user={@current_user} size={if @compact, do: :small, else: :normal} />
        </div>

        <!-- Comment Input -->
        <div class="flex-1">
          <textarea
            name="content"
            value={@form_data["content"]}
            placeholder={@placeholder}
            rows={if @compact, do: "2", else: "3"}
            class={[
              "w-full px-3 py-2 border border-gray-200 rounded-lg resize-none",
              "focus:ring-2 focus:ring-purple-500 focus:border-transparent text-sm",
              "transition-all duration-200"
            ]}
            phx-keydown="handle_comment_keydown"
            phx-key="Enter"
            phx-target={@myself}
          ></textarea>
        </div>
      </div>

      <div class="flex justify-end">
        <%= if @parent_id do %>
          <div class="flex items-center space-x-2">
            <button
              type="button"
              phx-click="cancel_reply"
              phx-target={@myself}
              class="px-3 py-1 text-sm text-gray-500 hover:text-gray-700 transition-colors"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={String.trim(@form_data["content"]) == ""}
              class="inline-flex items-center px-3 py-1 bg-purple-600 text-white text-sm font-medium rounded-lg hover:bg-purple-700 disabled:bg-gray-300 disabled:cursor-not-allowed transition-colors duration-200"
            >
              <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 10h10a8 8 0 018 8v2M3 10l6 6m-6-6l6-6"/>
              </svg>
              <%= @submit_label %>
            </button>
          </div>
        <% else %>
          <button
            type="submit"
            disabled={String.trim(@form_data["content"]) == ""}
            class="inline-flex items-center px-3 py-1 bg-purple-600 text-white text-sm font-medium rounded-lg hover:bg-purple-700 disabled:bg-gray-300 disabled:cursor-not-allowed transition-colors duration-200"
          >
            <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8"/>
            </svg>
            <%= @submit_label %>
          </button>
        <% end %>
      </div>
    </form>
    """
  end

  # Empty State
  defp empty_comments_state(assigns) do
    ~H"""
    <div class="text-center py-12">
      <div class="w-16 h-16 mx-auto bg-gray-100 rounded-full flex items-center justify-center mb-4">
        <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"/>
        </svg>
      </div>
      <h3 class="text-lg font-medium text-gray-900 mb-2">Start the conversation</h3>
      <p class="text-sm text-gray-500 mb-6">Be the first to share your thoughts about this media!</p>
      <div class="flex justify-center space-x-4 text-xs text-gray-400">
        <div class="flex items-center space-x-1">
          <span>💡</span>
          <span>Share insights</span>
        </div>
        <div class="flex items-center space-x-1">
          <span>🤝</span>
          <span>Ask questions</span>
        </div>
        <div class="flex items-center space-x-1">
          <span>🎯</span>
          <span>Give feedback</span>
        </div>
      </div>
    </div>
    """
  end

  # User Avatar Component
  defp user_avatar(assigns) do
    ~H"""
    <div class={[
      "rounded-full overflow-hidden flex items-center justify-center",
      case @size do
        :small -> "w-6 h-6"
        :normal -> "w-8 h-8"
        :large -> "w-10 h-10"
      end
    ]}>
      <%= if @user.avatar_url do %>
        <img src={@user.avatar_url} alt={@user.name} class="w-full h-full object-cover" />
      <% else %>
        <div class={[
          "w-full h-full bg-purple-100 flex items-center justify-center",
          case @size do
            :small -> "text-xs"
            :normal -> "text-xs"
            :large -> "text-sm"
          end
        ]}>
          <span class="font-medium text-purple-600">
            <%= get_user_initials(@user) %>
          </span>
        </div>
      <% end %>
    </div>
    """
  end

  # Event Handlers
  def handle_event("submit_comment", %{"content" => content, "parent_id" => parent_id}, socket) do
    current_user = socket.assigns.current_user

    if current_user && String.trim(content) != "" do
      attrs = %{
        "content" => String.trim(content),
        "media_file_id" => socket.assigns.file.id,  # This gets mapped to asset_id in create_threaded_comment
        "parent_id" => if(parent_id != "", do: parent_id, else: nil)
      }

      case Media.create_threaded_comment(attrs, current_user) do
        {:ok, _comment} ->
          # Reset appropriate form
          socket = if parent_id != "" do
            socket
            |> assign(:reply_forms, Map.delete(socket.assigns.reply_forms, String.to_integer(parent_id)))
            |> assign(:show_reply_form, nil)
          else
            assign(socket, :comment_form, %{"content" => "", "parent_id" => nil})
          end

          {:noreply, socket}
        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to post comment")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("show_reply_form", %{"comment-id" => comment_id}, socket) do
    comment_id_int = String.to_integer(comment_id)

    socket = socket
    |> assign(:show_reply_form, comment_id_int)
    |> assign(:reply_forms, Map.put(socket.assigns.reply_forms, comment_id_int, %{
      "content" => "",
      "parent_id" => comment_id
    }))

    {:noreply, socket}
  end

  def handle_event("cancel_reply", _params, socket) do
    socket = socket
    |> assign(:show_reply_form, nil)
    |> assign(:reply_forms, %{})

    {:noreply, socket}
  end

  def handle_event("toggle_thread", %{"comment-id" => comment_id}, socket) do
    comment_id_int = String.to_integer(comment_id)
    expanded_threads = socket.assigns.expanded_threads

    new_expanded = if MapSet.member?(expanded_threads, comment_id_int) do
      MapSet.delete(expanded_threads, comment_id_int)
    else
      MapSet.put(expanded_threads, comment_id_int)
    end

    {:noreply, assign(socket, :expanded_threads, new_expanded)}
  end

  def handle_event("toggle_all_threads", _params, socket) do
    comments = socket.assigns.comments
    all_comment_ids = get_all_comment_ids(comments)

    new_expanded = if all_threads_expanded?(comments, socket.assigns.expanded_threads) do
      MapSet.new()
    else
      MapSet.new(all_comment_ids)
    end

    {:noreply, assign(socket, :expanded_threads, new_expanded)}
  end

  def handle_event("toggle_comment_reaction", %{"comment-id" => comment_id, "reaction-type" => reaction_type}, socket) do
    current_user = socket.assigns.current_user

    if current_user do
      case Media.toggle_comment_reaction(%{
        "comment_id" => comment_id,
        "reaction_type" => reaction_type,
        "user_id" => current_user.id
      }) do
        {:ok, _} -> {:noreply, socket}  # Real-time update via PubSub
        {:error, _} -> {:noreply, put_flash(socket, :error, "Failed to react")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("delete_comment", %{"comment-id" => comment_id}, socket) do
    current_user = socket.assigns.current_user

    if current_user do
      case Media.get_comment(comment_id) do
        nil -> {:noreply, socket}
        comment ->
          case Media.delete_comment(comment, current_user) do
            {:ok, _} -> {:noreply, socket}  # Real-time update via PubSub
            {:error, :unauthorized} -> {:noreply, put_flash(socket, :error, "Unauthorized")}
            _ -> {:noreply, put_flash(socket, :error, "Failed to delete comment")}
          end
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("handle_comment_keydown", %{"key" => "Enter", "shiftKey" => false}, socket) do
    send_update(self(), __MODULE__, id: socket.assigns.id, action: :submit_comment)
    {:noreply, socket}
  end

  def handle_event("handle_comment_keydown", _params, socket) do
    {:noreply, socket}
  end

  # Real-time PubSub Updates
  def handle_info({:comment_created, comment}, socket) do
    if comment.asset_id == socket.assigns.file.id do  # Changed from media_file_id
      updated_comments = Media.list_threaded_comments_for_file(socket.assigns.file.id)
      {:noreply, assign(socket, :comments, updated_comments)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:comment_deleted, comment}, socket) do
    if comment.asset_id == socket.assigns.file.id do  # Changed from media_file_id
      updated_comments = Media.list_threaded_comments_for_file(socket.assigns.file.id)
      {:noreply, assign(socket, :comments, updated_comments)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:comment_reaction_updated, comment_id}, socket) do
    # Reload comments to get updated reaction counts
    updated_comments = Media.list_threaded_comments_for_file(socket.assigns.file.id)
    {:noreply, assign(socket, :comments, updated_comments)}
  end

  # Helper Functions
  defp count_total_comments(comments) do
    Enum.reduce(comments, 0, fn comment, acc ->
      acc + 1 + count_total_comments(comment.replies || [])
    end)
  end

  defp has_replies?(comment) do
    length(comment.replies || []) > 0
  end

  defp has_reactions?(comment) do
    map_size(comment.reaction_summary || %{}) > 0
  end

  defp thread_expanded?(comment_id, expanded_threads) do
    MapSet.member?(expanded_threads, comment_id)
  end

  defp all_threads_expanded?(comments, expanded_threads) do
    all_comment_ids = get_all_comment_ids(comments)
    MapSet.equal?(MapSet.new(all_comment_ids), expanded_threads)
  end

  defp get_all_comment_ids(comments) do
    Enum.flat_map(comments, fn comment ->
      [comment.id | get_all_comment_ids(comment.replies || [])]
    end)
  end

  defp user_reacted_to_comment?(comment, user, reaction_type) do
    user && comment.user_reactions &&
    Enum.any?(comment.user_reactions[user.id] || [], &(&1 == reaction_type))
  end

  defp get_user_initials(user) do
    name = user.name || user.username || "U"
    name
    |> String.split()
    |> Enum.take(2)
    |> Enum.map(&String.first/1)
    |> Enum.join()
    |> String.upcase()
  end

  defp get_reaction_emoji(reaction_type) do
    emoji_map = %{
      "heart" => "❤️", "fire" => "🔥", "thumbsup" => "👍", "star" => "⭐",
      "lightbulb" => "💡", "rocket" => "🚀", "gem" => "💎", "crown" => "👑"
    }
    emoji_map[reaction_type] || "👍"
  end

  defp format_comment_time(datetime) do
    now = DateTime.utc_now()

    datetime = case datetime do
      %NaiveDateTime{} -> DateTime.from_naive!(datetime, "Etc/UTC")
      %DateTime{} -> datetime
      _ -> now
    end

    diff_seconds = DateTime.diff(now, datetime, :second)

    cond do
      diff_seconds < 60 -> "now"
      diff_seconds < 3600 -> "#{div(diff_seconds, 60)}m"
      diff_seconds < 86400 -> "#{div(diff_seconds, 3600)}h"
      diff_seconds < 604800 -> "#{div(diff_seconds, 86400)}d"
      true -> Calendar.strftime(datetime, "%b %d")
    end
  end
end
