# priv/repo/migrations/xxx_create_comment_reactions.exs

defmodule Frestyl.Repo.Migrations.CreateCommentReactions do
  use Ecto.Migration

  def change do
    create table(:comment_reactions) do
      add :reaction_type, :string, null: false
      add :comment_id, references(:asset_comments, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:comment_reactions, [:comment_id])
    create index(:comment_reactions, [:user_id])
    create unique_index(:comment_reactions, [:comment_id, :user_id, :reaction_type],
                       name: :comment_reactions_unique_per_user)
  end
end
