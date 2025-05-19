# In your migrations folder, create a new migration
defmodule Frestyl.Repo.Migrations.CreateAttachments do
  use Ecto.Migration

  def change do
    create table(:attachments) do
      add :file_name, :string, null: false
      add :content_type, :string, null: false
      add :size, :integer, null: false
      add :path, :string, null: false
      add :message_id, references(:messages, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:attachments, [:message_id])
  end
end
