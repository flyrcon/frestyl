defmodule Frestyl.Repo.Migrations.AddFieldsToEvents do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add :title, :string
      add :description, :text
      add_if_not_exists :starts_at, :utc_datetime
      add_if_not_exists :ends_at, :utc_datetime
      add_if_not_exists :status, :string, default: "scheduled"
      add_if_not_exists :admission_type, :string
      add_if_not_exists :price_in_cents, :integer
      add_if_not_exists :max_attendees, :integer
      add_if_not_exists :waiting_room_opens_at, :utc_datetime
      add_if_not_exists :host_id, references(:users, on_delete: :nilify_all)
      add_if_not_exists :session_id, references(:sessions, on_delete: :nilify_all)

      # These might already exist if your table has timestamps()
      # If they do, you can remove these two lines
      add :inserted_at, :naive_datetime, null: false, default: fragment("NOW()")
      add :updated_at, :naive_datetime, null: false, default: fragment("NOW()")
    end
  end
end
