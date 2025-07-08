# lib/frestyl_web/live/admin_live/components.ex
defmodule FrestylWeb.AdminLive.Components do
  @moduledoc """
  Reusable components for admin interface.
  """

  use Phoenix.Component
  import FrestylWeb.CoreComponents

  attr :title, :string, required: true
  attr :value, :any, required: true
  attr :icon, :string, default: nil
  attr :color, :string, default: "blue"
  attr :trend, :string, default: nil
  attr :trend_value, :string, default: nil

  def stat_card(assigns) do
    ~H"""
    <div class="bg-white overflow-hidden shadow rounded-lg">
      <div class="p-5">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <div class={"w-8 h-8 bg-#{@color}-500 rounded-full flex items-center justify-center"}>
              <%= if @icon do %>
                <.icon name={@icon} class="w-5 h-5 text-white" />
              <% end %>
            </div>
          </div>
          <div class="ml-5 w-0 flex-1">
            <dl>
              <dt class="text-sm font-medium text-gray-500 truncate"><%= @title %></dt>
              <dd class="flex items-baseline">
                <div class="text-2xl font-semibold text-gray-900">
                  <%= @value %>
                </div>
                <%= if @trend do %>
                  <div class={"ml-2 flex items-baseline text-sm font-semibold #{if @trend == "up", do: "text-green-600", else: "text-red-600"}"}>
                    <.icon name={if @trend == "up", do: "arrow-up", else: "arrow-down"} class="w-4 h-4" />
                    <%= @trend_value %>
                  </div>
                <% end %>
              </dd>
            </dl>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :user, :map, required: true
  attr :show_actions, :boolean, default: true

  def user_row(assigns) do
    ~H"""
    <tr>
      <td class="px-6 py-4 whitespace-nowrap">
        <div class="flex items-center">
          <div class="flex-shrink-0 h-10 w-10">
            <div class="h-10 w-10 rounded-full bg-gray-300 flex items-center justify-center">
              <span class="text-sm font-medium text-gray-700">
                <%= String.first(@user.email) |> String.upcase() %>
              </span>
            </div>
          </div>
          <div class="ml-4">
            <div class="text-sm font-medium text-gray-900"><%= @user.email %></div>
            <div class="text-sm text-gray-500">ID: <%= @user.id %></div>
          </div>
        </div>
      </td>
      <td class="px-6 py-4 whitespace-nowrap">
        <span class={"inline-flex px-2 py-1 text-xs font-semibold rounded-full #{tier_color(@user.account.subscription_tier)}"}>
          <%= Phoenix.Naming.humanize(@user.account.subscription_tier) %>
        </span>
      </td>
      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
        <%= if @user.admin_roles && length(@user.admin_roles) > 0 do %>
          <%= Enum.join(@user.admin_roles, ", ") %>
        <% else %>
          None
        <% end %>
      </td>
      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
        <%= relative_time(@user.last_sign_in_at || @user.inserted_at) %>
      </td>
      <%= if @show_actions do %>
        <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
          <button
            phx-click="manage_user"
            phx-value-user_id={@user.id}
            class="text-blue-600 hover:text-blue-900"
          >
            Manage
          </button>
        </td>
      <% end %>
    </tr>
    """
  end

  defp tier_color(tier) do
    case tier do
      "personal" -> "bg-gray-100 text-gray-800"
      "creator" -> "bg-blue-100 text-blue-800"
      "professional" -> "bg-purple-100 text-purple-800"
      "enterprise" -> "bg-yellow-100 text-yellow-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end

  defp relative_time(datetime) when is_nil(datetime), do: "Never"
  defp relative_time(datetime) do
    now = DateTime.utc_now()
    diff_seconds = DateTime.diff(now, datetime, :second)

    cond do
      diff_seconds < 60 -> "Just now"
      diff_seconds < 3600 -> "#{div(diff_seconds, 60)} min ago"
      diff_seconds < 86400 -> "#{div(diff_seconds, 3600)} hours ago"
      diff_seconds < 604800 -> "#{div(diff_seconds, 86400)} days ago"
      true -> Calendar.strftime(datetime, "%b %d")
    end
  end
end
