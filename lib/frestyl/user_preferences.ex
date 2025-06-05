defmodule Frestyl.UserPreferences do
  @moduledoc """
  Context for managing user tool and layout preferences.
  """

  import Ecto.Query, warn: false
  alias Frestyl.Repo
  alias Frestyl.UserPreferences.ToolPreference

  def get_or_create_tool_preferences(user_id) do
    case Repo.get_by(ToolPreference, user_id: user_id) do
      nil -> create_default_preferences(user_id)
      preferences -> {:ok, preferences}
    end
  end

  def update_tool_layout(user_id, layout) do
    {:ok, preferences} = get_or_create_tool_preferences(user_id)

    preferences
    |> ToolPreference.changeset(%{tool_layout: layout})
    |> Repo.update()
  end

  defp create_default_preferences(user_id) do
    %ToolPreference{}
    |> ToolPreference.changeset(%{user_id: user_id})
    |> Repo.insert()
  end
end
