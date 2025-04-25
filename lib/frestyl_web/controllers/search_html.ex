# lib/frestyl_web/controllers/search_html.ex
defmodule FrestylWeb.SearchHTML do
  use FrestylWeb, :html
  import Phoenix.HTML.Form

  embed_templates "search_html/*"
end
