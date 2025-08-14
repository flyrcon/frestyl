# priv/repo/migrations/20250813000002_create_storyboard_templates.exs
defmodule Frestyl.Repo.Migrations.CreateStoryboardTemplates do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS pgcrypto"

    create table(:storyboard_templates, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :name, :string, null: false, size: 100
      add :description, :text
      add :category, :string, null: false, size: 50
      add :default_width, :integer, default: 800
      add :default_height, :integer, default: 600
      add :canvas_data, :map, null: false, default: %{}
      add :thumbnail_url, :string, size: 500
      add :is_public, :boolean, default: true
      add :created_by, references(:users, type: :bigint, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:storyboard_templates, [:category])
    create index(:storyboard_templates, [:is_public])
    create index(:storyboard_templates, [:created_by])
    create index(:storyboard_templates, [:name])
    create index(:storyboard_templates, [:canvas_data], using: :gin)

    execute(&insert_default_templates/0, &remove_default_templates/0)
  end

  defp insert_default_templates do
    execute("""
    INSERT INTO storyboard_templates
      (id, name, description, category, default_width, default_height, canvas_data, is_public, inserted_at, updated_at)
    VALUES
      (
        gen_random_uuid(),
        'Blank Canvas',
        'Empty canvas for free-form drawing',
        'basic',
        800,
        600,
        '{
          "version": "1.0",
          "width": 400,
          "height": 600,
          "background": "#ffffff",
          "objects": [],
          "layers": [
            {"id": "background", "name": "Background", "visible": true, "locked": false},
            {"id": "sketch", "name": "Sketch", "visible": true, "locked": false}
          ]
        }'::jsonb,
        true,
        NOW(),
        NOW()
      ),
      (
        gen_random_uuid(),
        'Character Sheet',
        'Template for character design and development',
        'character',
        800,
        800,
        '{
          "version": "1.0",
          "width": 800,
          "height": 800,
          "background": "#ffffff",
          "objects": [
            {"type": "circle", "left": 350, "top": 100, "radius": 50, "fill": "transparent", "stroke": "#cccccc", "strokeWidth": 2},
            {"type": "rect", "left": 250, "top": 200, "width": 300, "height": 400, "fill": "transparent", "stroke": "#cccccc", "strokeWidth": 2},
            {"type": "text", "left": 350, "top": 650, "text": "Character Name", "fontSize": 16, "fill": "#666666", "textAlign": "center"}
          ],
          "layers": [
            {"id": "guides", "name": "Guides", "visible": true, "locked": true},
            {"id": "sketch", "name": "Sketch", "visible": true, "locked": false},
            {"id": "annotations", "name": "Annotations", "visible": true, "locked": false}
          ]
        }'::jsonb,
        true,
        NOW(),
        NOW()
      );
    """)
  end

  defp remove_default_templates do
    execute("DELETE FROM storyboard_templates;")
  end

end
