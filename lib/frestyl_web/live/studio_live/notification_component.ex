# Replace the entire contents of lib/frestyl_web/live/studio_live/notification_component.ex with:

defmodule FrestylWeb.StudioLive.NotificationComponent do
  @moduledoc """
  A component for displaying notifications in the Studio interface.
  """

  use Phoenix.Component

  attr :notifications, :list, default: []

  def notification_container(assigns) do
    ~H"""
    <div class="fixed bottom-4 right-4 space-y-2 z-50">
      <%= for notification <- @notifications do %>
        <.notification_item notification={notification} />
      <% end %>
    </div>
    """
  end

  attr :notification, :map, required: true

  def notification_item(assigns) do
    ~H"""
    <div class="bg-gray-900 bg-opacity-90 border border-gray-800 text-white rounded-lg shadow-lg p-4 max-w-xs">
      <div class="flex items-start">
        <div class="flex-shrink-0 mr-3 mt-0.5">
          <.notification_icon type={@notification.type} />
        </div>
        <div>
          <p class="text-sm"><%= @notification.message %></p>
          <p class="text-xs text-gray-400 mt-1">
            <%= Calendar.strftime(@notification.timestamp, "%I:%M %p") %>
          </p>
        </div>
      </div>
    </div>
    """
  end

  attr :type, :atom, required: true

  def notification_icon(assigns) do
    ~H"""
    <%= case @type do %>
      <% :success -> %>
        <svg class="h-5 w-5 text-green-400" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
        </svg>
      <% :error -> %>
        <svg class="h-5 w-5 text-red-400" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
        </svg>
      <% :warning -> %>
        <svg class="h-5 w-5 text-yellow-400" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
        </svg>
      <% :info -> %>
        <svg class="h-5 w-5 text-blue-400" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd" />
        </svg>
      <% :user_joined -> %>
        <svg class="h-5 w-5 text-green-400" fill="currentColor" viewBox="0 0 20 20">
          <path d="M8 9a3 3 0 100-6 3 3 0 000 6zM8 11a6 6 0 016 6H2a6 6 0 016-6zM16 7a1 1 0 10-2 0v1h-1a1 1 0 100 2h1v1a1 1 0 102 0v-1h1a1 1 0 100-2h-1V7z" />
        </svg>
      <% :user_left -> %>
        <svg class="h-5 w-5 text-red-400" fill="currentColor" viewBox="0 0 20 20">
          <path d="M11 6a3 3 0 11-6 0 3 3 0 016 0zM14 17a6 6 0 00-12 0h12z" />
          <path d="M13 8a1 1 0 100 2h4a1 1 0 100-2h-4z" />
        </svg>
      <% :new_message -> %>
        <svg class="h-5 w-5 text-indigo-400" fill="currentColor" viewBox="0 0 20 20">
          <path d="M2 5a2 2 0 012-2h7a2 2 0 012 2v4a2 2 0 01-2 2H9l-3 3v-3H4a2 2 0 01-2-2V5z" />
          <path d="M15 7v2a4 4 0 01-4 4H9.828l-1.766 1.767c.28.149.599.233.938.233h2l3 3v-3h2a2 2 0 002-2V9a2 2 0 00-2-2h-1z" />
        </svg>
      <% _ -> %>
        <svg class="h-5 w-5 text-blue-400" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd" />
        </svg>
    <% end %>
    """
  end
end
