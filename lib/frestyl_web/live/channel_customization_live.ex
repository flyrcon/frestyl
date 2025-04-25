defmodule FrestylWeb.ChannelCustomizationLive do
  use FrestylWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    # For a real application, you'd fetch the current channel settings
    # from a database or context

    default_settings = %{
      name: "My Channel",
      description: "A place for collaboration and creativity",
      accent_color: "#4F46E5",
      logo: nil,
      banner: nil,
      theme: "default",
      font: "inter",
      visibility: "public"
    }

    {:ok, assign(socket,
      page_title: "Channel Settings",
      settings: default_settings,
      color_picker_open: false,
      themes: [
        %{id: "default", name: "Default", preview_url: "/images/themes/default.png"},
        %{id: "dark", name: "Dark Mode", preview_url: "/images/themes/dark.png"},
        %{id: "vibrant", name: "Vibrant", preview_url: "/images/themes/vibrant.png"},
        %{id: "minimal", name: "Minimal", preview_url: "/images/themes/minimal.png"}
      ],
      fonts: [
        %{id: "inter", name: "Inter"},
        %{id: "roboto", name: "Roboto"},
        %{id: "montserrat", name: "Montserrat"},
        %{id: "open-sans", name: "Open Sans"}
      ]
    )}
  end

  @impl true
  def handle_event("update_setting", %{"key" => key, "value" => value}, socket) do
    updated_settings = Map.put(socket.assigns.settings, String.to_atom(key), value)
    {:noreply, assign(socket, settings: updated_settings)}
  end

  @impl true
  def handle_event("toggle_color_picker", _, socket) do
    {:noreply, assign(socket, color_picker_open: !socket.assigns.color_picker_open)}
  end

  @impl true
  def handle_event("save_settings", _, socket) do
    # Here you would persist the settings to your database
    # through a context module

    {:noreply, put_flash(socket, :info, "Channel settings saved successfully!")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto">
      <div class="md:flex md:items-center md:justify-between">
        <div class="flex-1 min-w-0">
          <h2 class="text-2xl font-bold leading-7 text-gray-900 sm:text-3xl sm:truncate">
            Channel Customization
          </h2>
        </div>
      </div>

      <div class="mt-8 grid grid-cols-1 gap-6 lg:grid-cols-3">
        <!-- Settings panel -->
        <div class="lg:col-span-2">
          <div class="bg-white shadow rounded-lg">
            <div class="px-4 py-5 sm:p-6">
              <h3 class="text-lg leading-6 font-medium text-gray-900">
                Branding
              </h3>
              <div class="mt-6 grid grid-cols-1 gap-y-6 gap-x-4 sm:grid-cols-6">
                <div class="sm:col-span-6">
                  <label for="channel-name" class="block text-sm font-medium text-gray-700">
                    Channel name
                  </label>
                  <div class="mt-1">
                    <input type="text" name="channel-name" id="channel-name"
                      value={@settings.name}
                      phx-blur="update_setting" phx-value-key="name"
                      class="shadow-sm focus:ring-indigo-500 focus:border-indigo-500 block w-full sm:text-sm border-gray-300 rounded-md">
                  </div>
                </div>

                <div class="sm:col-span-6">
                  <label for="description" class="block text-sm font-medium text-gray-700">
                    Description
                  </label>
                  <div class="mt-1">
                    <textarea id="description" name="description" rows="3"
                      phx-blur="update_setting" phx-value-key="description"
                      class="shadow-sm focus:ring-indigo-500 focus:border-indigo-500 block w-full sm:text-sm border-gray-300 rounded-md"><%= @settings.description %></textarea>
                  </div>
                  <p class="mt-2 text-sm text-gray-500">
                    Brief description of your channel for attendees.
                  </p>
                </div>

                <div class="sm:col-span-6">
                  <label for="accent-color" class="block text-sm font-medium text-gray-700">
                    Accent color
                  </label>
                  <div class="mt-1 flex items-center">
                    <div
                      class="h-8 w-8 rounded-full border border-gray-300"
                      style={"background-color: #{@settings.accent_color};"}
                      phx-click="toggle_color_picker">
                    </div>
                    <span class="ml-3 block text-sm font-medium text-gray-700">
                      <%= @settings.accent_color %>
                    </span>
                  </div>

                  <%= if @color_picker_open do %>
                    <div class="mt-2 p-2 border border-gray-300 rounded-md">
                      <!-- Simplified color picker -->
                      <div class="grid grid-cols-5 gap-2">
                        <%= for color <- ["#4F46E5", "#10B981", "#F59E0B", "#EF4444", "#8B5CF6", "#EC4899", "#06B6D4", "#84CC16", "#F97316", "#6366F1"] do %>
                          <div
                            class="h-8 w-full rounded cursor-pointer border-2"
                            style={"background-color: #{color}; border-color: #{if color == @settings.accent_color, do: "black", else: "transparent"};"}
                            phx-click="update_setting" phx-value-key="accent_color" phx-value-value={color}>
                          </div>
                        <% end %>
                      </div>
                    </div>
                  <% end %>
                </div>

                <div class="sm:col-span-6">
                  <label class="block text-sm font-medium text-gray-700">
                    Channel logo
                  </label>
                  <div class="mt-1 flex justify-center px-6 pt-5 pb-6 border-2 border-gray-300 border-dashed rounded-md">
                    <div class="space-y-1 text-center">
                      <svg class="mx-auto h-12 w-12 text-gray-400" stroke="currentColor" fill="none" viewBox="0 0 48 48" aria-hidden="true">
                        <path d="M28 8H12a4 4 0 00-4 4v20m32-12v8m0 0v8a4 4 0 01-4 4H12a4 4 0 01-4-4v-4m32-4l-3.172-3.172a4 4 0 00-5.656 0L28 28M8 32l9.172-9.172a4 4 0 015.656 0L28 28m0 0l4 4m4-24h8m-4-4v8m-12 4h.02" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
                      </svg>
                      <div class="flex text-sm text-gray-600">
                        <label for="file-upload" class="relative cursor-pointer bg-white rounded-md font-medium text-indigo-600 hover:text-indigo-500 focus-within:outline-none focus-within:ring-2 focus-within:ring-offset-2 focus-within:ring-indigo-500">
                          <span>Upload a file</span>
                          <input id="file-upload" name="file-upload" type="file" class="sr-only">
                        </label>
                        <p class="pl-1">or drag and drop</p>
                      </div>
                      <p class="text-xs text-gray-500">
                        PNG, JPG, GIF up to 10MB
                      </p>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div class="mt-6 bg-white shadow rounded-lg">
            <div class="px-4 py-5 sm:p-6">
              <h3 class="text-lg leading-6 font-medium text-gray-900">
                Theme
              </h3>
              <div class="mt-6 grid grid-cols-1 gap-y-6 gap-x-4 sm:grid-cols-2">
                <%= for theme <- @themes do %>
                  <div class="relative">
                    <div class={[
                      "border rounded-lg p-2 cursor-pointer",
                      @settings.theme == theme.id && "ring-2 ring-indigo-500"
                    ]}>
                      <img src={theme.preview_url} alt={theme.name} class="w-full h-32 object-cover rounded-md">
                      <div class="mt-2 flex justify-between items-center">
                        <span class="text-sm font-medium text-gray-900"><%= theme.name %></span>
                        <input
                          type="radio"
                          name="theme"
                          value={theme.id}
                          checked={@settings.theme == theme.id}
                          phx-click="update_setting"
                          phx-value-key="theme"
                          phx-value-value={theme.id}
                          class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300"
                        >
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          </div>

          <div class="mt-6 bg-white shadow rounded-lg">
            <div class="px-4 py-5 sm:p-6">
              <h3 class="text-lg leading-6 font-medium text-gray-900">
                Typography
              </h3>
              <div class="mt-6">
                <label for="font" class="block text-sm font-medium text-gray-700">Font family</label>
                <select
                  id="font"
                  name="font"
                  phx-change="update_setting"
                  phx-value-key="font"
                  class="mt-1 block w-full pl-3 pr-10 py-2 text-base border-gray-300 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md"
                >
                  <%= for font <- @fonts do %>
                    <option value={font.id} selected={@settings.font == font.id}><%= font.name %></option>
                  <% end %>
                </select>
              </div>
            </div>
          </div>

          <div class="mt-6 bg-white shadow rounded-lg">
            <div class="px-4 py-5 sm:p-6">
              <h3 class="text-lg leading-6 font-medium text-gray-900">
                Visibility
              </h3>
              <div class="mt-6">
                <fieldset>
                  <legend class="sr-only">Channel visibility</legend>
                  <div class="space-y-4">
                    <div class="flex items-center">
                      <input
                        id="visibility-public"
                        name="visibility"
                        type="radio"
                        checked={@settings.visibility == "public"}
                        phx-click="update_setting"
                        phx-value-key="visibility"
                        phx-value-value="public"
                        class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300"
                      >
                      <label for="visibility-public" class="ml-3">
                        <span class="block text-sm font-medium text-gray-700">Public</span>
                        <span class="block text-sm text-gray-500">Anyone can find and join your channel</span>
                      </label>
                    </div>

                    <div class="flex items-center">
                      <input
                        id="visibility-unlisted"
                        name="visibility"
                        type="radio"
                        checked={@settings.visibility == "unlisted"}
                        phx-click="update_setting"
                        phx-value-key="visibility"
                        phx-value-value="unlisted"
                        class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300"
                      >
                      <label for="visibility-unlisted" class="ml-3">
                        <span class="block text-sm font-medium text-gray-700">Unlisted</span>
                        <span class="block text-sm text-gray-500">Only people with the link can join</span>
                      </label>
                    </div>

                    <div class="flex items-center">
                      <input
                        id="visibility-private"
                        name="visibility"
                        type="radio"
                        checked={@settings.visibility == "private"}
                        phx-click="update_setting"
                        phx-value-key="visibility"
                        phx-value-value="private"
                        class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300"
                      >
                      <label for="visibility-private" class="ml-3">
                        <span class="block text-sm font-medium text-gray-700">Private</span>
                        <span class="block text-sm text-gray-500">Only people you invite can join</span>
                      </label>
                    </div>
                  </div>
                </fieldset>
              </div>
            </div>
          </div>

          <div class="mt-6 flex justify-end">
            <button
              type="button"
              phx-click="save_settings"
              class="ml-3 inline-flex justify-center py-2 px-4 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
            >
              Save changes
            </button>
          </div>
        </div>

        <!-- Preview panel -->
        <div class="lg:col-span-1">
          <div class="bg-white shadow rounded-lg p-4 h-full">
            <h3 class="text-lg font-medium text-gray-900">Preview</h3>
            <div class="mt-4">
              <div class="border border-gray-200 rounded-lg overflow-hidden">
                <div class="h-24 w-full" style={"background-color: #{@settings.accent_color};"}>
                  <!-- Banner and logo would be displayed here -->
                </div>
                <div class="p-4">
                  <h4 style={"font-family: #{@settings.font};"} class="text-lg font-bold"><%= @settings.name %></h4>
                  <p class="mt-1 text-sm text-gray-500"><%= @settings.description %></p>

                  <div class="mt-4">
                    <div class="flex items-center">
                      <div class="h-8 w-8 rounded-full bg-gray-200"></div>
                      <div class="ml-3">
                        <p class="text-sm font-medium text-gray-900">Host Name</p>
                        <p class="text-xs text-gray-500">Host</p>
                      </div>
                    </div>
                  </div>

                  <div class="mt-4">
                    <button
                      type="button"
                      class="w-full inline-flex justify-center py-2 px-4 border border-transparent shadow-sm text-sm font-medium rounded-md text-white"
                      style={"background-color: #{@settings.accent_color};"}
                    >
                      Join Channel
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
