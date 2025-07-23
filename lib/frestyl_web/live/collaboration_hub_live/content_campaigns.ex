# lib/frestyl_web/live/collaboration_hub_live/content_campaigns.ex
defmodule FrestylWeb.CollaborationHubLive.ContentCampaigns do
  use FrestylWeb, :live_view

  alias Frestyl.Content
  alias Frestyl.Features.FeatureGate
  alias Phoenix.PubSub

  def mount(_params, _session, socket) do
    if connected?(socket) do
      PubSub.subscribe(Frestyl.PubSub, "content_campaigns:#{socket.assigns.current_account.id}")
    end

    socket =
      socket
      |> assign(:campaigns, list_campaigns(socket.assigns.current_account))
      |> assign(:show_create_modal, false)
      |> assign(:campaign_limits, get_campaign_limits(socket.assigns.current_account))

    {:ok, socket}
  end

  def handle_event("create_campaign", params, socket) do
    account = socket.assigns.current_account

    if FeatureGate.can_access_feature?(account, :content_campaigns) do
      case Content.create_collaboration_campaign(params, account) do
        {:ok, campaign} ->
          PubSub.broadcast(
            Frestyl.PubSub,
            "content_campaigns:#{account.id}",
            {:campaign_created, campaign}
          )

          {:noreply, socket
           |> assign(:campaigns, list_campaigns(account))
           |> assign(:show_create_modal, false)
           |> put_flash(:info, "Campaign created successfully!")}

        {:error, changeset} ->
          {:noreply, socket
           |> put_flash(:error, "Failed to create campaign")
           |> assign(:changeset, changeset)}
      end
    else
      {:noreply, socket
       |> put_flash(:error, "Upgrade required for content campaigns")
       |> push_navigate(to: "/subscription")}
    end
  end

  def handle_event("join_campaign", %{"campaign_id" => campaign_id}, socket) do
    account = socket.assigns.current_account
    user = socket.assigns.current_user

    case Content.join_campaign(campaign_id, user, account) do
      {:ok, _contributor} ->
        {:noreply, socket
         |> assign(:campaigns, list_campaigns(account))
         |> put_flash(:info, "Successfully joined campaign!")}

      {:error, :campaign_full} ->
        {:noreply, socket |> put_flash(:error, "Campaign is full")}

      {:error, :already_joined} ->
        {:noreply, socket |> put_flash(:error, "Already part of this campaign")}
    end
  end

  def handle_info({:campaign_created, _campaign}, socket) do
    {:noreply, assign(socket, :campaigns, list_campaigns(socket.assigns.current_account))}
  end

  def handle_info({:campaign_updated, _campaign}, socket) do
    {:noreply, assign(socket, :campaigns, list_campaigns(socket.assigns.current_account))}
  end

  defp list_campaigns(account) do
    Content.list_collaboration_campaigns(account)
  end

  defp get_campaign_limits(account) do
    Publishers.get_syndication_limits(account)
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Header with Create Button -->
      <div class="flex justify-between items-center">
        <div>
          <h2 class="text-2xl font-bold text-gray-900">Content Campaigns</h2>
          <p class="text-gray-600">Collaborate on articles and share revenue</p>
        </div>

        <button
          phx-click="create_campaign"
          class="bg-indigo-600 text-white px-4 py-2 rounded-lg hover:bg-indigo-700 transition-colors"
        >
          <svg class="w-5 h-5 inline mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
          </svg>
          New Campaign
        </button>
      </div>

      <!-- Campaign Limits Display -->
      <div class="bg-blue-50 border border-blue-200 rounded-lg p-4">
        <div class="flex items-center justify-between">
          <div>
            <h3 class="font-medium text-blue-900">Your Limits</h3>
            <p class="text-sm text-blue-700">
              Campaigns: <%= length(@campaigns) %>/<%= if @campaign_limits.concurrent_campaigns == :unlimited, do: "∞", else: @campaign_limits.concurrent_campaigns %>
              • Platforms: <%= @campaign_limits.max_platforms %>
              • Monthly Publishes: <%= @campaign_limits.monthly_publishes %>
            </p>
          </div>
          <%= if @campaign_limits.concurrent_campaigns != :unlimited and length(@campaigns) >= @campaign_limits.concurrent_campaigns do %>
            <.link navigate={~p"/subscription"} class="text-blue-600 hover:text-blue-800 font-medium">
              Upgrade Plan
            </.link>
          <% end %>
        </div>
      </div>

      <!-- Active Campaigns -->
      <div class="grid gap-6 lg:grid-cols-2">
        <%= for campaign <- @campaigns do %>
          <div class="bg-white border border-gray-200 rounded-lg p-6 hover:shadow-md transition-shadow">
            <div class="flex justify-between items-start mb-4">
              <div>
                <h3 class="font-semibold text-lg text-gray-900"><%= campaign.title %></h3>
                <p class="text-gray-600 text-sm mt-1"><%= campaign.description %></p>
              </div>
              <span class={"px-2 py-1 text-xs rounded-full #{status_class(campaign.status)}"}>
                <%= String.capitalize(campaign.status) %>
              </span>
            </div>

            <!-- Contributors -->
            <div class="flex items-center space-x-2 mb-4">
              <svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197m13.5 0a2.5 2.5 0 11-5 0 2.5 2.5 0 015 0z"/>
              </svg>
              <span class="text-sm text-gray-600">
                <%= length(campaign.contributors) %>/<%= campaign.max_contributors %> contributors
              </span>
            </div>

            <!-- Target Platforms -->
            <%= if length(campaign.target_platforms) > 0 do %>
              <div class="flex flex-wrap gap-1 mb-4">
                <%= for platform <- campaign.target_platforms do %>
                  <span class="px-2 py-1 bg-gray-100 text-gray-700 text-xs rounded-full">
                    <%= String.capitalize(platform) %>
                  </span>
                <% end %>
              </div>
            <% end %>

            <!-- Actions -->
            <div class="flex space-x-2">
              <.link
                navigate={~p"/campaigns/#{campaign.id}"}
                class="flex-1 bg-indigo-600 text-white text-center px-4 py-2 rounded-lg hover:bg-indigo-700 transition-colors text-sm"
              >
                View Details
              </.link>

              <%= if campaign.status == "open" and not already_joined?(campaign, @current_user) do %>
                <button
                  phx-click="join_campaign"
                  phx-value-campaign_id={campaign.id}
                  class="px-4 py-2 border border-indigo-600 text-indigo-600 rounded-lg hover:bg-indigo-50 transition-colors text-sm"
                >
                  Join
                </button>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Empty State -->
      <%= if Enum.empty?(@campaigns) do %>
        <div class="text-center py-12">
          <svg class="w-16 h-16 text-gray-300 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
          </svg>
          <h3 class="text-lg font-medium text-gray-900 mb-2">No campaigns yet</h3>
          <p class="text-gray-500 mb-4">Create your first collaborative writing campaign</p>
          <button
            phx-click="create_campaign"
            class="bg-indigo-600 text-white px-6 py-3 rounded-lg hover:bg-indigo-700 transition-colors"
          >
            Create First Campaign
          </button>
        </div>
      <% end %>
    </div>
    """
  end

  defp status_class("open"), do: "bg-green-100 text-green-800"
  defp status_class("active"), do: "bg-blue-100 text-blue-800"
  defp status_class("completed"), do: "bg-gray-100 text-gray-800"
  defp status_class("cancelled"), do: "bg-red-100 text-red-800"

  defp already_joined?(campaign, user) do
    Enum.any?(campaign.contributors, &(&1.user_id == user.id))
  end
end
