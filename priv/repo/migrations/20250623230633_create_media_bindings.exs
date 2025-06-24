# priv/repo/migrations/008_create_media_bindings.exs
defmodule Frestyl.Repo.Migrations.CreateMediaBindings do
  use Ecto.Migration

  def change do
    create table(:media_bindings) do
      add :content_block_id, references(:content_blocks, on_delete: :delete_all), null: false
      add :media_file_id, references(:portfolio_media, on_delete: :delete_all), null: false
      add :binding_type, :string, null: false  # audio_narration, hover_audio, click_video, modal_image, etc.
      add :target_selector, :string  # CSS selector or element ID within the block
      add :sync_data, :map, default: %{}  # Timestamp/position data for sync
      add :trigger_config, :map, default: %{}  # How the media is triggered
      add :display_config, :map, default: %{}  # How the media is shown

      timestamps()
    end

    create index(:media_bindings, [:content_block_id])
    create index(:media_bindings, [:media_file_id])
    create unique_index(:media_bindings, [:content_block_id, :target_selector, :binding_type])

    create constraint(:media_bindings, :valid_binding_type,
      check: "binding_type IN ('background_audio', 'narration_sync', 'hover_audio', 'click_video', 'modal_image', 'inline_video', 'code_demo', 'document_overlay', 'hotspot_trigger')")
  end
end
