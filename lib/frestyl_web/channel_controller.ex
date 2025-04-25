# lib/frestyl_web/controllers/channel_controller.ex
defmodule FrestylWeb.ChannelController do
  use FrestylWeb, :controller

  alias Frestyl.Channels
  alias Frestyl.Channels.Channel

  def index(conn, _params) do
    # Get all public channels or all channels if user is logged in
    channels = if conn.assigns[:current_user] do
      Channels.list_channels()
    else
      Channels.list_channels(public_only: true)
    end

    render(conn, :index, channels: channels)
  end

  def new(conn, _params) do
    # Ensure user is authenticated
    if conn.assigns[:current_user] do
      changeset = Channels.change_channel(%Channel{})
      render(conn, :new, changeset: changeset, categories: FrestylWeb.ChannelHTML.form_categories())
    else
      conn
      |> put_flash(:error, "You must be logged in to create a channel")
      |> redirect(to: ~p"/login")
    end
  end

  def create(conn, %{"channel" => channel_params}) do
    # Ensure user is authenticated
    user = conn.assigns[:current_user]

    if user do
      case Channels.create_channel(user, channel_params) do
        {:ok, channel} ->
          conn
          |> put_flash(:info, "Channel created successfully.")
          |> redirect(to: ~p"/channels/#{channel.slug}")

        {:error, %Ecto.Changeset{} = changeset} ->
          render(conn, :new, changeset: changeset, categories: FrestylWeb.ChannelHTML.form_categories())
      end
    else
      conn
      |> put_flash(:error, "You must be logged in to create a channel")
      |> redirect(to: ~p"/login")
    end
  end

  def show(conn, %{"slug" => slug}) do
    channel = Channels.get_channel_by_slug(slug)

    if channel do
      # Check if channel is public or user has permission to view it
      user = conn.assigns[:current_user]

      cond do
        channel.is_public ->
          rooms = Channels.list_rooms(channel.id)
          render(conn, :show, channel: channel, rooms: rooms)

        user && Channels.has_permission?(user, channel, "view_channel") ->
          rooms = Channels.list_rooms(channel.id)
          render(conn, :show, channel: channel, rooms: rooms)

        true ->
          conn
          |> put_flash(:error, "This channel is private")
          |> redirect(to: ~p"/channels")
      end
    else
      conn
      |> put_flash(:error, "Channel not found")
      |> redirect(to: ~p"/channels")
    end
  end

  def edit(conn, %{"slug" => slug}) do
    channel = Channels.get_channel_by_slug(slug)
    user = conn.assigns[:current_user]

    if channel && user && Channels.has_permission?(user, channel, "manage_channel") do
      changeset = Channels.change_channel(channel)
      render(conn, :edit, channel: channel, changeset: changeset, categories: FrestylWeb.ChannelHTML.form_categories())
    else
      conn
      |> put_flash(:error, "You don't have permission to edit this channel")
      |> redirect(to: ~p"/channels")
    end
  end

  def update(conn, %{"slug" => slug, "channel" => channel_params}) do
    channel = Channels.get_channel_by_slug(slug)
    user = conn.assigns[:current_user]

    if channel && user && Channels.has_permission?(user, channel, "manage_channel") do
      case Channels.update_channel(channel, channel_params) do
        {:ok, channel} ->
          conn
          |> put_flash(:info, "Channel updated successfully.")
          |> redirect(to: ~p"/channels/#{channel.slug}")

        {:error, %Ecto.Changeset{} = changeset} ->
          render(conn, :edit, channel: channel, changeset: changeset, categories: FrestylWeb.ChannelHTML.form_categories())
      end
    else
      conn
      |> put_flash(:error, "You don't have permission to edit this channel")
      |> redirect(to: ~p"/channels")
    end
  end

  def delete(conn, %{"slug" => slug}) do
    channel = Channels.get_channel_by_slug(slug)
    user = conn.assigns[:current_user]

    if channel && user && Channels.has_permission?(user, channel, "delete_channel") do
      {:ok, _} = Channels.delete_channel(channel)

      conn
      |> put_flash(:info, "Channel deleted successfully.")
      |> redirect(to: ~p"/channels")
    else
      conn
      |> put_flash(:error, "You don't have permission to delete this channel")
      |> redirect(to: ~p"/channels")
    end
  end

  # AI-based categorization for onboarding
  def suggest_categories(conn, %{"name" => name, "description" => description}) do
    suggestions = Channels.suggest_categories(name, description)
    json(conn, suggestions)
  end
end
