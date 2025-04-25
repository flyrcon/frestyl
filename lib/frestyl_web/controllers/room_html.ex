# lib/frestyl_web/controllers/room_html.ex
defmodule FrestylWeb.RoomHTML do
  use FrestylWeb, :html

  embed_templates "room_html/*"

  # Helper to get the effective color for a room (inherited or overridden)
  def get_effective_primary_color(room, channel) do
    if room.override_branding && room.primary_color do
      room.primary_color
    else
      channel.primary_color
    end
  end

  def get_effective_secondary_color(room, channel) do
    if room.override_branding && room.secondary_color do
      room.secondary_color
    else
      channel.secondary_color
    end
  end
end
