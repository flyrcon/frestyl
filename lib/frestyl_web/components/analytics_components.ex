defmodule FrestylWeb.AnalyticsComponents do
  @moduledoc """
  Provides UI components for the analytics dashboard.
  """
  use Phoenix.Component

  @doc """
  Renders a metric card.

  ## Examples

      <.metric_card title="Total Views" value="1,234" change={5.2} icon="eye" />
  """
  attr :title, :string, required: true
  attr :value, :string, required: true
  attr :change, :float, default: 0.0
  attr :icon, :string, default: nil

  def metric_card(assigns) do
    ~H"""
    <div class="bg-white overflow-hidden shadow rounded-lg">
      <div class="p-5">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <%= if @icon do %>
              <.icon name={@icon} class="h-6 w-6 text-gray-400" />
            <% end %>
          </div>
          <div class="ml-5 w-0 flex-1">
            <dl>
              <dt class="text-sm font-medium text-gray-500 truncate">
                <%= @title %>
              </dt>
              <dd>
                <div class="text-lg font-medium text-gray-900">
                  <%= @value %>
                </div>
              </dd>
            </dl>
          </div>
        </div>
      </div>
      <div class="bg-gray-50 px-5 py-3">
        <div class="text-sm">
          <span class={[
            "font-medium",
            @change > 0 && "text-green-600",
            @change < 0 && "text-red-600",
            @change == 0 && "text-gray-500"
          ]}>
            <%= cond do %>
              <% @change > 0 -> %>
                <.icon name="arrow-up" class="h-4 w-4 inline" />
                <%= Float.round(abs(@change), 1) %>%
              <% @change < 0 -> %>
                <.icon name="arrow-down" class="h-4 w-4 inline" />
                <%= Float.round(abs(@change), 1) %>%
              <% true -> %>
                0%
            <% end %>
          </span>

          <span class="text-gray-500 ml-1">vs. previous period</span>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders an icon.

  ## Examples

      <.icon name="eye" class="h-6 w-6" />
  """
  attr :name, :string, required: true
  attr :class, :string, default: nil

  def icon(%{name: "eye"} = assigns) do
    ~H"""
    <svg class={@class} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
    </svg>
    """
  end

  def icon(%{name: "users"} = assigns) do
    ~H"""
    <svg class={@class} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
    </svg>
    """
  end

  def icon(%{name: "clock"} = assigns) do
    ~H"""
    <svg class={@class} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
    </svg>
    """
  end

  def icon(%{name: "currency-dollar"} = assigns) do
    ~H"""
    <svg class={@class} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
    </svg>
    """
  end

  def icon(%{name: "arrow-up"} = assigns) do
    ~H"""
    <svg class={@class} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 10l7-7m0 0l7 7m-7-7v18" />
    </svg>
    """
  end

  def icon(%{name: "arrow-down"} = assigns) do
    ~H"""
    <svg class={@class} xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 14l-7 7m0 0l-7-7m7 7V3" />
    </svg>
    """
  end
end
