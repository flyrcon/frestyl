# lib/frestyl/media/folder_context.ex
defmodule Frestyl.Media.FolderContext do
  import Ecto.Query, warn: false
  alias Frestyl.Repo
  alias Frestyl.Media.{Folder, MediaFile}

  # Folder CRUD operations
  def get_folder!(id), do: Repo.get!(Folder, id)

  def list_user_folders(user_id) do
    from(f in Folder, where: f.user_id == ^user_id)
    |> Repo.all()
  end

  def list_subfolders(parent_id) do
    from(f in Folder, where: f.parent_id == ^parent_id)
    |> Repo.all()
  end

  def create_folder(attrs) do
    %Folder{}
    |> Folder.changeset(attrs)
    |> Repo.insert()
  end

  def update_folder(%Folder{} = folder, attrs) do
    folder
    |> Folder.changeset(attrs)
    |> Repo.update()
  end

  def delete_folder(%Folder{} = folder) do
    # First, move all media files out of this folder
    from(m in MediaFile, where: m.folder_id == ^folder.id)
    |> Repo.update_all(set: [folder_id: nil])

    # Then delete the folder
    Repo.delete(folder)
  end

  def get_folder_path(%Folder{} = folder) do
    get_folder_path_recursive(folder, [])
    |> Enum.reverse()
  end

  defp get_folder_path_recursive(nil, acc), do: acc
  defp get_folder_path_recursive(%Folder{parent_id: nil} = folder, acc) do
    [folder | acc]
  end
  defp get_folder_path_recursive(%Folder{} = folder, acc) do
    parent = Repo.get(Folder, folder.parent_id)
    get_folder_path_recursive(parent, [folder | acc])
  end
end
