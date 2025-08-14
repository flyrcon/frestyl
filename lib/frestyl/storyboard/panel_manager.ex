# lib/frestyl/storyboard/panel_manager.ex
defmodule Frestyl.Storyboard.PanelManager do
  @moduledoc """
  Manages storyboard panels - CRUD operations, ordering, and relationships
  with story sections and voice notes.
  """

  import Ecto.Query, warn: false
  alias Frestyl.{Repo, Stories}
  # Import the schema module properly
  alias Frestyl.Storyboard.StoryboardPanel

  @doc """
  Creates a new storyboard panel.
  """
  def create_panel(attrs) do
    %StoryboardPanel{}
    |> StoryboardPanel.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a single panel by ID.
  """
  def get_panel(panel_id) do
    Repo.get(StoryboardPanel, panel_id)
  end

  @doc """
  Gets all panels for a story, ordered by panel_order.
  """
  def get_story_panels(story_id) do
    from(p in StoryboardPanel,
      where: p.story_id == ^story_id,
      order_by: [asc: p.panel_order]
    )
    |> Repo.all()
  end

  @doc """
  Gets panels for a specific story section.
  """
  def get_section_panels(story_id, section_id) do
    from(p in StoryboardPanel,
      where: p.story_id == ^story_id and p.section_id == ^section_id,
      order_by: [asc: p.panel_order]
    )
    |> Repo.all()
  end

  @doc """
  Updates a panel.
  """
  def update_panel(panel, attrs) do
    panel
    |> StoryboardPanel.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates panel (struct version).
  """
  def update_panel(%StoryboardPanel{} = panel) do
    Repo.update(StoryboardPanel.changeset(panel, %{}))
  end

  @doc """
  Deletes a panel.
  """
  def delete_panel(panel) do
    Repo.delete(panel)
  end

  @doc """
  Reorders panels for a story.
  """
  def reorder_panels(story_id, panel_order_list) do
    Repo.transaction(fn ->
      Enum.each(panel_order_list, fn {panel_id, new_order} ->
        from(p in StoryboardPanel,
          where: p.id == ^panel_id and p.story_id == ^story_id
        )
        |> Repo.update_all(set: [panel_order: new_order, updated_at: DateTime.utc_now()])
      end)
    end)
  end

  @doc """
  Duplicates a panel.
  """
  def duplicate_panel(panel_id) do
    case get_panel(panel_id) do
      nil -> {:error, "Panel not found"}
      panel ->
        new_order = get_next_panel_order(panel.story_id)

        new_attrs = %{
          story_id: panel.story_id,
          section_id: panel.section_id,
          panel_order: new_order,
          canvas_data: panel.canvas_data,
          thumbnail_url: nil, # Generate new thumbnail
          voice_note_id: nil, # Don't duplicate voice note
          created_by: panel.created_by
        }

        create_panel(new_attrs)
    end
  end

  @doc """
  Links a panel to a voice note.
  """
  def link_voice_note(panel_id, voice_note_id) do
    case get_panel(panel_id) do
      nil -> {:error, "Panel not found"}
      panel ->
        update_panel(panel, %{voice_note_id: voice_note_id})
    end
  end

  @doc """
  Gets panels with their associated voice notes.
  """
  def get_panels_with_voice_notes(story_id) do
    # This would join with voice notes when proper schema is implemented
    panels = get_story_panels(story_id)

    Enum.map(panels, fn panel ->
      voice_note = case panel.voice_note_id do
        nil -> nil
        voice_note_id -> get_voice_note_for_panel(voice_note_id)
      end

      Map.put(panel, :voice_note, voice_note)
    end)
  end

  @doc """
  Creates multiple panels from a template sequence.
  """
  def create_panels_from_template(story_id, template_sequence, user_id) do
    Repo.transaction(fn ->
      Enum.with_index(template_sequence, 1)
      |> Enum.map(fn {panel_template, order} ->
        attrs = %{
          story_id: story_id,
          section_id: panel_template.section_id,
          panel_order: order,
          canvas_data: panel_template.canvas_data,
          created_by: user_id
        }

        case create_panel(attrs) do
          {:ok, panel} -> panel
          {:error, changeset} -> Repo.rollback(changeset)
        end
      end)
    end)
  end

  @doc """
  Gets panel statistics for a story.
  """
  def get_panel_stats(story_id) do
    query = from(p in StoryboardPanel,
      where: p.story_id == ^story_id,
      select: %{
        total_panels: count(p.id),
        panels_with_voice_notes: count(p.voice_note_id),
        last_updated: max(p.updated_at)
      }
    )

    Repo.one(query) || %{total_panels: 0, panels_with_voice_notes: 0, last_updated: nil}
  end

  @doc """
  Searches panels by content or annotations.
  """
  def search_panels(story_id, search_term) do
    # Search in canvas data annotations and text objects
    from(p in StoryboardPanel,
      where: p.story_id == ^story_id,
      where: fragment("? @> ?", p.canvas_data, ^%{"objects" => [%{"text" => search_term}]}),
      order_by: [asc: p.panel_order]
    )
    |> Repo.all()
  end

  # ============================================================================
  # Private Helper Functions
  # ============================================================================

  defp get_next_panel_order(story_id) do
    query = from(p in StoryboardPanel,
      where: p.story_id == ^story_id,
      select: max(p.panel_order)
    )

    case Repo.one(query) do
      nil -> 1
      max_order -> max_order + 1
    end
  end

  defp get_voice_note_for_panel(voice_note_id) do
    # This would be replaced with proper voice note schema lookup
    # For now, return placeholder
    %{
      id: voice_note_id,
      transcription: "Voice note transcription...",
      duration: 30
    }
  end
end
