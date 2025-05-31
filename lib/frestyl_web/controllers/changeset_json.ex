# lib/frestyl_web/controllers/changeset_json.ex
defmodule FrestylWeb.ChangesetJSON do
  @doc """
  Renders changeset errors.
  """
  def error(%{changeset: changeset}) do
    %{
      success: false,
      error: "Validation failed",
      details: Ecto.Changeset.traverse_errors(changeset, &translate_error/1)
    }
  end

  defp translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate "is invalid" with no options
    #     dngettext("errors", "is invalid", opts)
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # Because the error messages we show in our forms and APIs
    # are defined inside Ecto, we need to translate them dynamically.
    # This requires us to call the Gettext module passing our gettext
    # backend as first argument.
    #
    # Note we use the "errors" domain as the default domain.
    if count = opts[:count] do
      Gettext.dngettext(FrestylWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(FrestylWeb.Gettext, "errors", msg, opts)
    end
  end
end
