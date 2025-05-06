defmodule FrestylWeb.UserRegistrationHTML do
  use FrestylWeb, :html

  import FrestylWeb.UserHTML # Assuming user_form is defined here

  embed_templates "user_registration_html/*"
end
