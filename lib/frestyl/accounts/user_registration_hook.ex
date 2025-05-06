defmodule Frestyl.Accounts.UserRegistrationHook do
  @moduledoc """
  Hook to trigger actions after user registration.
  """

  alias Frestyl.AIAssistant

  @doc """
  Trigger the AI onboarding flow for a newly registered user.
  """
  def after_registration(user) do
    # Start the onboarding process asynchronously
    Task.start(fn ->
      AIAssistant.start_onboarding(user)
    end)

    :ok
  end
end
