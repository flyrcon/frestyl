defmodule Frestyl.UserPreferences.ToolPreference do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_tool_preferences" do
    belongs_to :user, Frestyl.Accounts.User
    field :tool_layout, :map, default: %{}
    field :collaboration_mode_preferences, :map, default: %{}
    field :mobile_preferences, :map, default: %{}

    timestamps()
  end

  def changeset(tool_preference, attrs) do
    tool_preference
    |> cast(attrs, [:user_id, :tool_layout, :collaboration_mode_preferences, :mobile_preferences])
    |> validate_required([:user_id])
    |> unique_constraint(:user_id)
  end
end
