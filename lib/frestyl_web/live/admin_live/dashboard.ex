# lib/frestyl_web/live/admin_live/dashboard.ex
defmodule FrestylWeb.AdminLive.Dashboard do
  use FrestylWeb, :live_view

  alias Frestyl.{Accounts, Channels, Analytics, Billing}
  alias Frestyl.Admin.{Stats, UserManagement, ChannelManagement}

  @impl true
  def mount(_params, _session, socket) do
    if authorized?(socket.assigns.current_user) do
      {:ok,
       socket
       |> assign_dashboard_data()
       |> assign(:page_title, "Admin Dashboard")
       |> assign(:active_tab, "overview")
       |> assign(:show_user_modal, false)
       |> assign(:show_role_modal, false)
       |> assign(:selected_user, nil)
       |> assign(:frestyl_official_channel, get_or_create_official_channel())}
    else
      {:ok,
       socket
       |> put_flash(:error, "Unauthorized access")
       |> redirect(to: "/")}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :show, _params) do
    assign(socket, :active_tab, "overview")
  end

  defp apply_action(socket, :users, _params) do
    socket
    |> assign(:active_tab, "users")
    |> assign(:users, load_users_with_pagination())
  end

  defp apply_action(socket, :channels, _params) do
    socket
    |> assign(:active_tab, "channels")
    |> assign(:channels, load_channels_data())
  end

  defp apply_action(socket, :analytics, _params) do
    socket
    |> assign(:active_tab, "analytics")
    |> assign(:analytics_data, load_analytics_data())
  end

  defp apply_action(socket, :roles, _params) do
    socket
    |> assign(:active_tab, "roles")
    |> assign(:admin_roles, load_admin_roles())
  end

  # ============================================================================
  # EVENT HANDLERS
  # ============================================================================

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  @impl true
  def handle_event("manage_user", %{"user_id" => user_id}, socket) do
    user = Accounts.get_user!(user_id)
    {:noreply,
     socket
     |> assign(:selected_user, user)
     |> assign(:show_user_modal, true)}
  end

  @impl true
  def handle_event("close_user_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_user_modal, false)
     |> assign(:selected_user, nil)}
  end

  @impl true
  def handle_event("update_user_tier", %{"user_id" => user_id, "tier" => tier}, socket) do
    case UserManagement.update_user_subscription_tier(user_id, tier) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "User tier updated successfully")
         |> assign(:users, load_users_with_pagination())
         |> assign(:show_user_modal, false)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update user tier")}
    end
  end

  @impl true
  def handle_event("assign_admin_role", %{"user_id" => user_id, "role" => role}, socket) do
    case UserManagement.assign_admin_role(user_id, role, socket.assigns.current_user.id) do
      {:ok, _assignment} ->
        {:noreply,
         socket
         |> put_flash(:info, "Admin role assigned successfully")
         |> assign(:users, load_users_with_pagination())
         |> assign(:admin_roles, load_admin_roles())}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to assign role: #{reason}")}
    end
  end

  @impl true
  def handle_event("revoke_admin_role", %{"user_id" => user_id, "role" => role}, socket) do
    case UserManagement.revoke_admin_role(user_id, role) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Admin role revoked successfully")
         |> assign(:users, load_users_with_pagination())
         |> assign(:admin_roles, load_admin_roles())}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to revoke role: #{reason}")}
    end
  end

  @impl true
  def handle_event("update_official_channel", %{"channel" => channel_params}, socket) do
    case ChannelManagement.update_official_channel(channel_params) do
      {:ok, channel} ->
        {:noreply,
         socket
         |> put_flash(:info, "Frestyl Official channel updated successfully")
         |> assign(:frestyl_official_channel, channel)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update official channel")}
    end
  end

  @impl true
  def handle_event("broadcast_to_all", %{"message" => message}, socket) do
    case ChannelManagement.broadcast_official_message(message, socket.assigns.current_user) do
      {:ok, _broadcast} ->
        {:noreply, put_flash(socket, :info, "Message broadcasted to all users")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to broadcast: #{reason}")}
    end
  end

  @impl true
  def handle_event("toggle_maintenance_mode", _params, socket) do
    case toggle_maintenance_mode() do
      {:ok, status} ->
        message = if status, do: "Maintenance mode enabled", else: "Maintenance mode disabled"
        {:noreply,
         socket
         |> put_flash(:info, message)
         |> assign(:maintenance_mode, status)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to toggle maintenance mode: #{reason}")}
    end
  end

  # ============================================================================
  # PRIVATE FUNCTIONS
  # ============================================================================

  defp authorized?(user) do
    case user do
      %{admin_roles: roles} when is_list(roles) ->
        Enum.any?(roles, &(&1 in ["super_admin", "admin", "moderator"]))
      %{is_admin: true} -> true
      _ -> false
    end
  end

  defp assign_dashboard_data(socket) do
    socket
    |> assign(:dashboard_stats, load_dashboard_stats())
    |> assign(:recent_activity, load_recent_activity())
    |> assign(:system_health, check_system_health())
    |> assign(:maintenance_mode, get_maintenance_status())
  end

  defp load_dashboard_stats do
    %{
      total_users: Stats.total_users(),
      active_users_today: Stats.active_users_today(),
      total_portfolios: Stats.total_portfolios(),
      total_channels: Stats.total_channels(),
      revenue_today: Stats.revenue_today(),
      revenue_this_month: Stats.revenue_this_month(),
      conversion_rate: Stats.conversion_rate_this_month(),
      churn_rate: Stats.churn_rate_this_month(),
      support_tickets_open: Stats.open_support_tickets(),
      system_uptime: Stats.system_uptime()
    }
  end

  defp load_users_with_pagination(page \\ 1, per_page \\ 50) do
    UserManagement.list_users_with_details(page: page, per_page: per_page)
  end

  defp load_channels_data do
    %{
      official_channel: get_or_create_official_channel(),
      public_channels: ChannelManagement.list_public_channels(),
      trending_channels: ChannelManagement.get_trending_channels(),
      reported_channels: ChannelManagement.get_reported_channels()
    }
  end

  defp load_analytics_data do
    %{
      user_growth: Analytics.user_growth_last_30_days(),
      engagement_metrics: Analytics.engagement_metrics(),
      feature_usage: Analytics.feature_usage_stats(),
      geographic_distribution: Analytics.geographic_distribution(),
      device_usage: Analytics.device_usage_stats(),
      subscription_metrics: Analytics.subscription_conversion_funnel()
    }
  end

  defp load_admin_roles do
    UserManagement.list_admin_role_assignments()
  end

  defp load_recent_activity do
    [
      %{type: "user_signup", user: "john@example.com", timestamp: DateTime.utc_now()},
      %{type: "subscription_upgrade", user: "jane@example.com", tier: "professional", timestamp: DateTime.add(DateTime.utc_now(), -3600)},
      %{type: "channel_created", user: "bob@example.com", channel: "Design Feedback", timestamp: DateTime.add(DateTime.utc_now(), -7200)},
      %{type: "support_ticket", user: "alice@example.com", priority: "high", timestamp: DateTime.add(DateTime.utc_now(), -10800)}
    ]
  end

  defp check_system_health do
    %{
      database: :healthy,
      redis: :healthy,
      storage: :healthy,
      external_apis: :healthy,
      memory_usage: 45.2,
      cpu_usage: 23.8,
      disk_usage: 67.1
    }
  end

  defp get_or_create_official_channel do
    case ChannelManagement.get_official_channel() do
      nil -> ChannelManagement.create_official_channel()
      channel -> channel
    end
  end

  defp get_maintenance_status do
    # Check if maintenance mode is active
    case Application.get_env(:frestyl, :maintenance_mode, false) do
      true -> true
      _ -> false
    end
  end

  defp toggle_maintenance_mode do
    current_status = get_maintenance_status()
    new_status = !current_status

    case Application.put_env(:frestyl, :maintenance_mode, new_status) do
      :ok -> {:ok, new_status}
      error -> {:error, error}
    end
  end
end
