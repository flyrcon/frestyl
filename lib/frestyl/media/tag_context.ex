# lib/frestyl/media/tag_context.ex
defmodule Frestyl.Media.TagContext do
  import Ecto.Query, warn: false
  alias Frestyl.Repo
  alias Frestyl.Media.Tag

  # Tag CRUD operations
  def get_tag!(id), do: Repo.get!(Tag, id)

  def list_user_tags(user_id) do
    from(t in Tag, where: t.user_id == ^user_id)
    |> Repo.all()
  end

  def create_tag(attrs) do
    %Tag{}
    |> Tag.changeset(attrs)
    |> Repo.insert()
  end

  def update_tag(%Tag{} = tag, attrs) do
    tag
    |> Tag.changeset(attrs)
    |> Repo.update()
  end

  def delete_tag(%Tag{} = tag) do
    Repo.delete(tag)
  end
end
