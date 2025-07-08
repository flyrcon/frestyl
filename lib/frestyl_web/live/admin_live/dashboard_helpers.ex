# lib/frestyl_web/live/admin_live/dashboard_helpers.ex
defmodule FrestylWeb.AdminLive.DashboardHelpers do
  @moduledoc """
  Helper functions for the admin dashboard template.
  """

  def activity_color(type) do
    case type do
      "user_signup" -> "bg-green-400"
      "subscription_upgrade" -> "bg-blue-400"
      "channel_created" -> "bg-purple-400"
      "support_ticket" -> "bg-red-400"
      _ -> "bg-gray-400"
    end
  end

  def activity_description(%{type: "user_signup"}) do
    "signed up"
  end

  def activity_description(%{type: "subscription_upgrade", tier: tier}) do
    "upgraded to #{Phoenix.Naming.humanize(tier)}"
  end

  def activity_description(%{type: "channel_created", channel: channel}) do
    "created channel '#{channel}'"
  end

  def activity_description(%{type: "support_ticket", priority: priority}) do
    "submitted a #{priority} priority support ticket"
  end

  def activity_description(_), do: "performed an action"

  def status_color(status) do
    case status do
      :healthy -> "bg-green-100 text-green-800"
      "healthy" -> "bg-green-100 text-green-800"
      :warning -> "bg-yellow-100 text-yellow-800"
      "warning" -> "bg-yellow-100 text-yellow-800"
      :error -> "bg-red-100 text-red-800"
      "error" -> "bg-red-100 text-red-800"
      "public" -> "bg-green-100 text-green-800"
      "private" -> "bg-yellow-100 text-yellow-800"
      "unlisted" -> "bg-gray-100 text-gray-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end

  def tier_color(tier) do
    case tier do
      "personal" -> "bg-gray-100 text-gray-800"
      "creator" -> "bg-blue-100 text-blue-800"
      "professional" -> "bg-purple-100 text-purple-800"
      "enterprise" -> "bg-yellow-100 text-yellow-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end

  def role_color(role) do
    case role do
      "moderator" -> "bg-blue-100 text-blue-800"
      "content_admin" -> "bg-green-100 text-green-800"
      "support_admin" -> "bg-yellow-100 text-yellow-800"
      "billing_admin" -> "bg-purple-100 text-purple-800"
      "analytics_admin" -> "bg-indigo-100 text-indigo-800"
      "super_admin" -> "bg-red-100 text-red-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end

  def relative_time(datetime) when is_nil(datetime), do: "Never"

  def relative_time(datetime) do
    now = DateTime.utc_now()
    diff_seconds = DateTime.diff(now, datetime, :second)

    cond do
      diff_seconds < 60 ->
        "Just now"

      diff_seconds < 3600 ->
        minutes = div(diff_seconds, 60)
        "#{minutes} minute#{if minutes == 1, do: "", else: "s"} ago"

      diff_seconds < 86400 ->
        hours = div(diff_seconds, 3600)
        "#{hours} hour#{if hours == 1, do: "", else: "s"} ago"

      diff_seconds < 604800 ->
        days = div(diff_seconds, 86400)
        "#{days} day#{if days == 1, do: "", else: "s"} ago"

      diff_seconds < 2592000 ->
        weeks = div(diff_seconds, 604800)
        "#{weeks} week#{if weeks == 1, do: "", else: "s"} ago"

      true ->
        Calendar.strftime(datetime, "%b %d, %Y")
    end
  end

  def format_currency(amount) when is_number(amount) do
    "$#{:erlang.float_to_binary(amount, decimals: 2)}"
  end

  def format_currency(_), do: "$0.00"

  def format_percentage(percentage) when is_number(percentage) do
    "#{:erlang.float_to_binary(percentage, decimals: 1)}%"
  end

  def format_percentage(_), do: "0.0%"

  def format_number(number) when is_integer(number) do
    number
    |> Integer.to_string()
    |> String.replace(~r/(\d)(?=(\d{3})+(?!\d))/, "\\1,")
  end

  def format_number(number) when is_float(number) do
    number
    |> :erlang.float_to_binary(decimals: 1)
    |> String.replace(~r/(\d)(?=(\d{3})+(?!\d))/, "\\1,")
  end

  def format_number(_), do: "0"

  def truncate_text(text, length \\ 50) when is_binary(text) do
    if String.length(text) > length do
      String.slice(text, 0, length) <> "..."
    else
      text
    end
  end

  def truncate_text(_, _), do: ""

  # Admin permission checking helpers
  def can_assign_role?(current_user, target_role) do
    current_roles = get_user_admin_roles(current_user)

    cond do
      "super_admin" in current_roles -> true
      target_role == "super_admin" -> false
      length(current_roles) > 0 -> true
      true -> false
    end
  end

  def can_manage_users?(current_user) do
    current_roles = get_user_admin_roles(current_user)

    Enum.any?(current_roles, fn role ->
      role in ["super_admin", "user_admin", "moderator"]
    end)
  end

  def can_manage_billing?(current_user) do
    current_roles = get_user_admin_roles(current_user)

    Enum.any?(current_roles, fn role ->
      role in ["super_admin", "billing_admin"]
    end)
  end

  def can_view_analytics?(current_user) do
    current_roles = get_user_admin_roles(current_user)

    Enum.any?(current_roles, fn role ->
      role in ["super_admin", "analytics_admin", "moderator"]
    end)
  end

  defp get_user_admin_roles(user) do
    case user do
      %{admin_roles: roles} when is_list(roles) -> roles
      _ -> []
    end
  end
end
