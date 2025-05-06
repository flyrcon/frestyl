defmodule FrestylWeb.UserHTML do
  use FrestylWeb, :html

  # First define all component attributes
  @doc """
  Renders a user form component.
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true

  # Then define component functions
  def user_form(assigns) do
    ~H"""
    <.simple_form :let={f} for={@changeset} action={@action} method="post">
      <.error :if={@changeset.action}>
        Oops, something went wrong! Please check the errors below.
      </.error>

      <.input field={f[:name]} type="text" label="Name" />
      <.input field={f[:email]} type="email" label="Email" />
      <.input field={f[:password]} type="password" label="Password" />

      <:actions>
        <.button>Register</.button>
      </:actions>
    </.simple_form>
    """
  end

  embed_templates "user_html/*"
end
