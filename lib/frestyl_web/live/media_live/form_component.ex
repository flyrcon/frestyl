# lib/frestyl_web/live/media_live/form_component.ex
defmodule FrestylWeb.MediaLive.FormComponent do
  use FrestylWeb, :live_component

  alias Frestyl.Media

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h2 class="text-xl font-semibold mb-4"><%= @title %></h2>

      <.form
        for={@form}
        id="asset-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
        class="space-y-6"
      >
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <.input field={@form[:name]} type="text" label="Name" />
          </div>
          <div>
            <.input
              field={@form[:type]}
              type="select"
              label="Type"
              options={[
                {"Document", "document"},
                {"Audio", "audio"},
                {"Video", "video"},
                {"Image", "image"}
              ]}
            />
          </div>
        </div>

        <.input field={@form[:description]} type="textarea" label="Description" rows="4" />

        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <.input field={@form[:mime_type]} type="text" label="MIME Type (Optional)" />
          </div>
          <div>
            <.input
              field={@form[:status]}
              type="select"
              label="Status"
              options={[
                {"Active", "active"},
                {"Archived", "archived"}
              ]}
            />
          </div>
        </div>

        <div class="flex justify-end">
          <.button type="submit" phx-disable-with="Saving...">Save Asset</.button>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{asset: asset} = assigns, socket) do
    changeset = Media.change_asset(asset)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"asset" => asset_params}, socket) do
    changeset =
      socket.assigns.asset
      |> Media.change_asset(asset_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"asset" => asset_params}, socket) do
    # Add the current user as the owner if this is a new asset
    asset_params = if socket.assigns.action == :new do
      Map.put(asset_params, "owner_id", socket.assigns.current_user.id)
    else
      asset_params
    end

    save_asset(socket, socket.assigns.action, asset_params)
  end

  defp save_asset(socket, :edit, asset_params) do
    case Media.update_asset(socket.assigns.asset, asset_params) do
      {:ok, asset} ->
        notify_parent({:saved, asset})

        {:noreply,
         socket
         |> put_flash(:info, "Asset updated successfully")
         |> push_navigate(to: socket.assigns.navigate)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_asset(socket, :new, asset_params) do
    case Media.create_asset(asset_params) do
      {:ok, asset} ->
        notify_parent({:saved, asset})

        {:noreply,
         socket
         |> put_flash(:info, "Asset created successfully")
         |> push_navigate(to: socket.assigns.navigate)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
