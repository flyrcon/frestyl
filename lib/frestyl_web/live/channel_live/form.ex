defmodule FrestylWeb.ChannelLive.Form do
  use FrestylWeb, :live_view

  alias Frestyl.Channels
  alias Frestyl.Channels.Channel

  @impl true
  def mount(_params, _session, socket) do
    socket = assign(socket, :page_title, "Channel Form")
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    # Check if id is a number or a slug
    channel =
      case Integer.parse(id) do
        {channel_id, _} -> Channels.get_channel!(channel_id)
        :error -> Channels.get_channel_by_slug!(id)  # Use get_channel_by_slug! for non-numeric IDs
      end

    # Create changeset for the channel
    changeset = Channels.change_channel(channel)

    # Return socket with both channel and changeset assigned
    socket
    |> assign(:page_title, "Edit #{channel.name}")
    |> assign(:channel, channel)
    |> assign(:changeset, changeset)
    |> assign(:visibility_options, Channels.visibility_options())  # Add this line
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    # Check if id is a number or a slug
    channel =
      case Integer.parse(id) do
        {channel_id, _} -> Channels.get_channel!(channel_id)
        :error -> Channels.get_channel_by_slug!(id)  # Use get_channel_by_slug! for non-numeric IDs
      end

    # Create changeset for the channel
    changeset = Channels.change_channel(channel)

    # Return socket with both channel and changeset assigned
    socket
    |> assign(:page_title, "Edit #{channel.name}")
    |> assign(:channel, channel)
    |> assign(:changeset, changeset)  # Make sure this line is present
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 py-8">
      <div class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
        <!-- Header -->
        <div class="md:flex md:items-center md:justify-between mb-8">
          <div class="min-w-0 flex-1">
            <h2 class="text-2xl font-bold leading-7 text-gray-900 sm:truncate sm:text-3xl sm:tracking-tight">
              <%= @page_title %>
            </h2>
          </div>
          <div class="mt-4 flex md:ml-4 md:mt-0">
            <.link
              navigate={~p"/channels"}
              class="inline-flex items-center px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500"
            >
              Cancel
            </.link>
          </div>
        </div>

        <!-- Form Card -->
        <div class="shadow sm:rounded-lg">
          <div class="bg-white px-4 py-5 sm:p-6">
            <form phx-change="validate" phx-submit="save" class="space-y-6">

              <!-- Channel Name -->
              <div>
                <label for="channel_name" class="block text-sm font-medium text-gray-700">Channel Name</label>
                <input
                  type="text"
                  name="channel[name]"
                  id="channel_name"
                  value={Ecto.Changeset.get_field(@changeset, :name) || ""}
                  placeholder="My awesome channel"
                  required
                  class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                />
                <%= if error = @changeset.errors[:name] do %>
                  <p class="mt-2 text-sm text-red-600"><%= translate_error(error) %></p>
                <% end %>
              </div>

              <!-- Channel Description -->
              <div>
                <label for="channel_description" class="block text-sm font-medium text-gray-700">Description</label>
                <textarea
                  name="channel[description]"
                  id="channel_description"
                  placeholder="What's this channel about?"
                  rows="3"
                  class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                ><%= Ecto.Changeset.get_field(@changeset, :description) || "" %></textarea>
                <%= if error = @changeset.errors[:description] do %>
                  <p class="mt-2 text-sm text-red-600"><%= translate_error(error) %></p>
                <% end %>
              </div>

              <!-- Channel Visibility -->
              <div>
                <label class="block text-sm font-medium text-gray-700">
                  Visibility
                </label>
                <div class="mt-2 space-y-3">
                  <%= for visibility <- @visibility_options do %>
                    <label class="relative flex items-start">
                      <div class="flex items-center h-5">
                        <input
                          type="radio"
                          name="channel[visibility]"
                          value={visibility}
                          checked={Ecto.Changeset.get_field(@changeset, :visibility) == visibility}
                          class="focus:ring-primary-500 h-4 w-4 text-primary-600 border-gray-300"
                        />
                      </div>
                      <div class="ml-3 text-sm">
                        <span class="font-medium text-gray-700"><%= String.capitalize(String.replace(visibility, "_", " ")) %></span>
                        <p class="text-gray-500">
                          <%= case visibility do %>
                            <% "public" -> %>
                              Anyone can join this channel
                            <% "private" -> %>
                              Members need approval to join
                            <% "invite_only" -> %>
                              Members can only join through invitation
                          <% end %>
                        </p>
                      </div>
                    </label>
                  <% end %>
                </div>
                <%= if error = @changeset.errors[:visibility] do %>
                  <p class="mt-2 text-sm text-red-600"><%= translate_error(error) %></p>
                <% end %>
              </div>

              <!-- Channel Category -->
              <div>
                <label for="channel_category" class="block text-sm font-medium text-gray-700">Category</label>
                <select
                  name="channel[category]"
                  id="channel_category"
                  class="mt-1 block w-full rounded-md border-gray-300 py-2 pl-3 pr-10 text-base focus:border-indigo-500 focus:outline-none focus:ring-indigo-500 sm:text-sm"
                >
                  <option value="" selected={Ecto.Changeset.get_field(@changeset, :category) == nil}>Select a category</option>
                  <option value="education" selected={Ecto.Changeset.get_field(@changeset, :category) == "education"}>Education</option>
                  <option value="entertainment" selected={Ecto.Changeset.get_field(@changeset, :category) == "entertainment"}>Entertainment</option>
                  <option value="technology" selected={Ecto.Changeset.get_field(@changeset, :category) == "technology"}>Technology</option>
                  <option value="music" selected={Ecto.Changeset.get_field(@changeset, :category) == "music"}>Music</option>
                  <option value="gaming" selected={Ecto.Changeset.get_field(@changeset, :category) == "gaming"}>Gaming</option>
                  <option value="sports" selected={Ecto.Changeset.get_field(@changeset, :category) == "sports"}>Sports</option>
                  <option value="art" selected={Ecto.Changeset.get_field(@changeset, :category) == "art"}>Art</option>
                  <option value="food" selected={Ecto.Changeset.get_field(@changeset, :category) == "food"}>Food</option>
                  <option value="travel" selected={Ecto.Changeset.get_field(@changeset, :category) == "travel"}>Travel</option>
                  <option value="health_fitness" selected={Ecto.Changeset.get_field(@changeset, :category) == "health_fitness"}>Health & Fitness</option>
                  <option value="business" selected={Ecto.Changeset.get_field(@changeset, :category) == "business"}>Business</option>
                  <option value="science" selected={Ecto.Changeset.get_field(@changeset, :category) == "science"}>Science</option>
                  <option value="news" selected={Ecto.Changeset.get_field(@changeset, :category) == "news"}>News</option>
                  <option value="lifestyle" selected={Ecto.Changeset.get_field(@changeset, :category) == "lifestyle"}>Lifestyle</option>
                  <option value="other" selected={Ecto.Changeset.get_field(@changeset, :category) == "other"}>Other</option>
                </select>
                <%= if error = @changeset.errors[:category] do %>
                  <p class="mt-2 text-sm text-red-600"><%= translate_error(error) %></p>
                <% end %>
              </div>

              <!-- Channel Icon Upload -->
              <div>
                <label for="channel_icon_url" class="block text-sm font-medium text-gray-700">
                  Channel Icon
                </label>
                <div class="mt-1 flex items-center">
                  <%= if Ecto.Changeset.get_field(@changeset, :icon_url) do %>
                    <img src={Ecto.Changeset.get_field(@changeset, :icon_url)} alt="Channel icon" class="h-12 w-12 rounded-full">
                  <% else %>
                    <span class="h-12 w-12 rounded-full overflow-hidden bg-gray-100">
                      <svg class="h-full w-full text-gray-300" fill="currentColor" viewBox="0 0 24 24">
                        <path d="M4 3h16a1 1 0 0 1 1 1v16a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1zm1 2v14h14V5H5zm2 4h10v2H7V9zm0 4h10v2H7v-2z"/>
                      </svg>
                    </span>
                  <% end %>
                  <div class="ml-5 flex-grow">
                    <input
                      type="text"
                      id="channel_icon_url"
                      name="channel[icon_url]"
                      value={Ecto.Changeset.get_field(@changeset, :icon_url) || ""}
                      placeholder="Icon URL (optional)"
                      class="focus:ring-indigo-500 focus:border-indigo-500 block w-full shadow-sm sm:text-sm border-gray-300 rounded-md"
                    />
                  </div>
                </div>
                <%= if error = @changeset.errors[:icon_url] do %>
                  <p class="mt-2 text-sm text-red-600"><%= translate_error(error) %></p>
                <% end %>
              </div>

              <div class="flex justify-between">
                <%= if @channel.id do %>
                  <button
                    type="button"
                    phx-click="delete_channel"
                    data-confirm="Are you sure you want to delete this channel? This action cannot be undone."
                    class="inline-flex justify-center py-2 px-6 border border-red-300 shadow-sm text-sm font-medium rounded-md text-red-700 bg-white hover:bg-red-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500"
                  >
                    Delete Channel
                  </button>
                <% else %>
                  <div></div>
                <% end %>
              </div>

              <!-- Submit Button -->
              <div class="flex justify-end">
                <button
                  type="submit"
                  phx-disable-with="Saving..."
                  class="inline-flex justify-center py-2 px-6 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-[#DD1155] hover:bg-[#C4134E] focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-[#DD1155]"
                >
                  <%= if @channel.id, do: "Update Channel", else: "Create Channel" %>
                </button>
              </div>
            </form>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("validate", %{"channel" => channel_params}, socket) do
    changeset =
      socket.assigns.channel
      |> Channels.change_channel(channel_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_event("save", %{"channel" => channel_params}, socket) do
    save_channel(socket, socket.assigns.live_action, channel_params)
  end

  @impl true
  def handle_event("delete_channel", _, socket) do
    case Channels.delete_channel(socket.assigns.channel) do
      {:ok, _} ->
        {:noreply,
        socket
        |> put_flash(:info, "Channel deleted successfully")
        |> push_navigate(to: ~p"/channels")}

      {:error, _} ->
        {:noreply,
        socket
        |> put_flash(:error, "Failed to delete channel")
        |> push_navigate(to: ~p"/channels")}
    end
  end

  defp save_channel(socket, :edit, channel_params) do
    case Channels.update_channel(socket.assigns.channel, channel_params) do
      {:ok, _channel} ->
        {:noreply,
         socket
         |> put_flash(:info, "Channel updated successfully")
         |> push_navigate(to: ~p"/channels")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp save_channel(socket, :new, channel_params) do
    case Channels.create_channel(channel_params, socket.assigns.current_user) do
      {:ok, _channel} ->
        {:noreply,
         socket
         |> put_flash(:info, "Channel created successfully")
         |> push_navigate(to: ~p"/channels")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  # Remove the translate_error function that's causing the conflict
  # It's already imported via FrestylWeb.CoreComponents
end
