# lib/frestyl_web/controllers/channel_html.ex
defmodule FrestylWeb.ChannelHTML do
  use FrestylWeb, :html
  import Phoenix.HTML.Form

  embed_templates "channel_html/*"

  def form_categories do
    [
      "Technology",
      "Marketing",
      "Design",
      "Business",
      "Education",
      "Entertainment",
      "Gaming",
      "Health & Wellness",
      "Finance",
      "Social",
      "Project Management",
      "Customer Support",
      "Research",
      "Other"
    ]
  end

  # Used in templates to render color styles
  def color_style(channel) do
    "background-color: #{channel.primary_color}; color: #{channel.secondary_color};"
  end
end
