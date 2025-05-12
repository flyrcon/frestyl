defmodule Frestyl.Repo.Migrations.AddMessageTypeToMessages do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add :message_type, :string, default: "text", null: false
      modify :metadata, :map, default: %{}, null: false
      modify :is_edited, :boolean, default: false, null: false
      modify :is_deleted, :boolean, default: false, null: false
    end
  end
end
