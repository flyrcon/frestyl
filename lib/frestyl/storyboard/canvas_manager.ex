# lib/frestyl/storyboard/canvas_manager.ex
defmodule Frestyl.Storyboard.CanvasManager do
  @moduledoc """
  Manages canvas state, drawing operations, and real-time synchronization
  for the visual storyboarding tool.
  """

  require Logger
  import Ecto.Query, warn: false
  alias Frestyl.{Repo, Stories}
  alias Frestyl.Storyboard.{PanelManager, TemplateLibrary}
  alias Phoenix.PubSub

  @doc """
  Creates a new canvas for a storyboard panel.
  """
  def create_canvas(story_id, section_id, user_id, canvas_options \\ %{}) do
    panel_attrs = %{
      story_id: story_id,
      section_id: section_id,
      created_by: user_id,
      canvas_data: initialize_canvas_data(canvas_options),
      panel_order: get_next_panel_order(story_id),
      thumbnail_url: nil,
      voice_note_id: nil
    }

    case PanelManager.create_panel(panel_attrs) do
      {:ok, panel} ->
        # Broadcast panel creation
        broadcast_canvas_event(story_id, :panel_created, panel)
        {:ok, panel}

      {:error, reason} ->
        Logger.error("Failed to create canvas: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Updates canvas data with new drawing operations.
  """
  def update_canvas(panel_id, canvas_data, user_id) do
    case PanelManager.get_panel(panel_id) do
      nil -> {:error, "Panel not found"}
      panel ->
        # Validate canvas data
        case validate_canvas_data(canvas_data) do
          {:ok, validated_data} ->
            updated_panel = %{panel |
              canvas_data: validated_data,
              updated_at: DateTime.utc_now()
            }

            case PanelManager.update_panel(updated_panel) do
              {:ok, saved_panel} ->
                # Generate thumbnail
                Task.start(fn -> generate_thumbnail(saved_panel) end)

                # Broadcast update
                broadcast_canvas_event(panel.story_id, :canvas_updated, %{
                  panel_id: panel_id,
                  canvas_data: validated_data,
                  user_id: user_id
                })

                {:ok, saved_panel}

              {:error, reason} -> {:error, reason}
            end

          {:error, reason} -> {:error, reason}
        end
    end
  end

  @doc """
  Processes real-time drawing operations for collaborative editing.
  """
  def process_drawing_operation(panel_id, operation, user_id) do
    case PanelManager.get_panel(panel_id) do
      nil -> {:error, "Panel not found"}
      panel ->
        # Apply operation to canvas data
        case apply_drawing_operation(panel.canvas_data, operation) do
          {:ok, updated_canvas_data} ->
            # Broadcast operation to collaborators
            broadcast_drawing_operation(panel.story_id, panel_id, operation, user_id)

            # Update panel (debounced to avoid too frequent saves)
            schedule_canvas_save(panel_id, updated_canvas_data)

            {:ok, updated_canvas_data}

          {:error, reason} -> {:error, reason}
        end
    end
  end

  @doc """
  Resizes canvas based on screen dimensions and content.
  """
  def resize_canvas(panel_id, new_dimensions, user_id) do
    %{width: width, height: height, zoom: zoom} = new_dimensions

    case PanelManager.get_panel(panel_id) do
      nil -> {:error, "Panel not found"}
      panel ->
        current_canvas = panel.canvas_data

        # Calculate new canvas dimensions
        updated_canvas = Map.merge(current_canvas, %{
          "width" => width,
          "height" => height,
          "zoom" => zoom,
          "viewport" => %{
            "width" => width,
            "height" => height,
            "zoom" => zoom
          }
        })

        case update_canvas(panel_id, updated_canvas, user_id) do
          {:ok, updated_panel} ->
            # Broadcast resize event
            broadcast_canvas_event(panel.story_id, :canvas_resized, %{
              panel_id: panel_id,
              dimensions: new_dimensions,
              user_id: user_id
            })

            {:ok, updated_panel}

          {:error, reason} -> {:error, reason}
        end
    end
  end

  @doc """
  Gets canvas state optimized for client rendering.
  """
  def get_canvas_state(panel_id, device_type \\ "desktop") do
    case PanelManager.get_panel(panel_id) do
      nil -> {:error, "Panel not found"}
      panel ->
        canvas_data = panel.canvas_data

        # Optimize canvas data for device
        optimized_data = optimize_for_device(canvas_data, device_type)

        canvas_state = %{
          panel_id: panel_id,
          canvas_data: optimized_data,
          dimensions: get_canvas_dimensions(optimized_data),
          tools: get_available_tools(device_type),
          layers: get_canvas_layers(optimized_data),
          metadata: %{
            created_at: panel.created_at,
            updated_at: panel.updated_at,
            thumbnail_url: panel.thumbnail_url
          }
        }

        {:ok, canvas_state}
    end
  end

  @doc """
  Exports canvas to various formats.
  """
  def export_canvas(panel_id, format \\ "png") do
    case PanelManager.get_panel(panel_id) do
      nil -> {:error, "Panel not found"}
      panel ->
        case format do
          "png" -> export_to_image(panel, "png")
          "svg" -> export_to_svg(panel)
          "json" -> export_to_json(panel)
          _ -> {:error, "Unsupported format"}
        end
    end
  end

  @doc """
  Creates canvas from template.
  """
  def create_from_template(story_id, section_id, template_id, user_id) do
    case TemplateLibrary.get_template(template_id) do
      nil -> {:error, "Template not found"}
      template ->
        canvas_options = %{
          template_data: template.canvas_data,
          width: template.default_width,
          height: template.default_height
        }

        create_canvas(story_id, section_id, user_id, canvas_options)
    end
  end

  # ============================================================================
  # Private Helper Functions
  # ============================================================================

  defp initialize_canvas_data(options) do
    default_canvas = %{
      "version" => "1.0",
      "width" => Map.get(options, :width, 800),
      "height" => Map.get(options, :height, 600),
      "background" => Map.get(options, :background, "#ffffff"),
      "objects" => [],
      "layers" => [
        %{
          "id" => "background",
          "name" => "Background",
          "visible" => true,
          "locked" => false,
          "objects" => []
        },
        %{
          "id" => "sketch",
          "name" => "Sketch",
          "visible" => true,
          "locked" => false,
          "objects" => []
        },
        %{
          "id" => "annotations",
          "name" => "Annotations",
          "visible" => true,
          "locked" => false,
          "objects" => []
        }
      ],
      "viewport" => %{
        "zoom" => 1.0,
        "pan_x" => 0,
        "pan_y" => 0
      }
    }

    # Merge with template data if provided
    case Map.get(options, :template_data) do
      nil -> default_canvas
      template_data -> Map.merge(default_canvas, template_data)
    end
  end

  defp validate_canvas_data(canvas_data) do
    required_fields = ["version", "width", "height", "objects", "layers"]

    case Enum.all?(required_fields, &Map.has_key?(canvas_data, &1)) do
      true ->
        # Additional validation
        cond do
          canvas_data["width"] <= 0 or canvas_data["width"] > 5000 ->
            {:error, "Invalid canvas width"}

          canvas_data["height"] <= 0 or canvas_data["height"] > 5000 ->
            {:error, "Invalid canvas height"}

          not is_list(canvas_data["objects"]) ->
            {:error, "Objects must be a list"}

          not is_list(canvas_data["layers"]) ->
            {:error, "Layers must be a list"}

          true ->
            {:ok, canvas_data}
        end

      false ->
        {:error, "Missing required canvas fields"}
    end
  end

  defp apply_drawing_operation(canvas_data, operation) do
    case operation["type"] do
      "add_object" ->
        new_object = operation["object"]
        updated_objects = canvas_data["objects"] ++ [new_object]
        {:ok, Map.put(canvas_data, "objects", updated_objects)}

      "update_object" ->
        object_id = operation["object_id"]
        updates = operation["updates"]

        updated_objects = Enum.map(canvas_data["objects"], fn obj ->
          if obj["id"] == object_id do
            Map.merge(obj, updates)
          else
            obj
          end
        end)

        {:ok, Map.put(canvas_data, "objects", updated_objects)}

      "delete_object" ->
        object_id = operation["object_id"]
        filtered_objects = Enum.reject(canvas_data["objects"], &(&1["id"] == object_id))
        {:ok, Map.put(canvas_data, "objects", filtered_objects)}

      "add_path" ->
        new_path = operation["path"]
        updated_objects = canvas_data["objects"] ++ [new_path]
        {:ok, Map.put(canvas_data, "objects", updated_objects)}

      _ ->
        {:error, "Unknown operation type"}
    end
  end

  defp optimize_for_device(canvas_data, device_type) do
    case device_type do
      "mobile" ->
        # Reduce complexity for mobile
        canvas_data
        |> limit_objects_for_mobile()
        |> reduce_path_complexity()

      "tablet" ->
        # Medium optimization
        reduce_path_complexity(canvas_data)

      _ ->
        # Desktop - full quality
        canvas_data
    end
  end

  defp limit_objects_for_mobile(canvas_data) do
    # Limit to 100 objects for mobile performance
    limited_objects = Enum.take(canvas_data["objects"], 100)
    Map.put(canvas_data, "objects", limited_objects)
  end

  defp reduce_path_complexity(canvas_data) do
    # Simplify complex paths for better performance
    simplified_objects = Enum.map(canvas_data["objects"], fn obj ->
      case obj["type"] do
        "path" -> simplify_path_object(obj)
        _ -> obj
      end
    end)

    Map.put(canvas_data, "objects", simplified_objects)
  end

  defp simplify_path_object(path_obj) do
    # Reduce path points for performance
    case path_obj["path"] do
      path when is_list(path) and length(path) > 50 ->
        # Sample every other point for very complex paths
        simplified_path = path |> Enum.take_every(2)
        Map.put(path_obj, "path", simplified_path)

      _ ->
        path_obj
    end
  end

  defp get_canvas_dimensions(canvas_data) do
    %{
      width: canvas_data["width"],
      height: canvas_data["height"],
      zoom: get_in(canvas_data, ["viewport", "zoom"]) || 1.0,
      pan_x: get_in(canvas_data, ["viewport", "pan_x"]) || 0,
      pan_y: get_in(canvas_data, ["viewport", "pan_y"]) || 0
    }
  end

  defp get_available_tools(device_type) do
    base_tools = ["pen", "eraser", "select", "text", "rectangle", "circle", "line"]

    case device_type do
      "mobile" ->
        # Simplified toolset for mobile
        ["pen", "eraser", "text", "select"]

      "tablet" ->
        # Most tools available
        base_tools

      _ ->
        # All tools for desktop
        base_tools ++ ["brush", "polygon", "arrow", "bezier"]
    end
  end

  defp get_canvas_layers(canvas_data) do
    Map.get(canvas_data, "layers", [])
  end

  defp get_next_panel_order(story_id) do
    case PanelManager.get_story_panels(story_id) do
      [] -> 1
      panels -> (Enum.map(panels, & &1.panel_order) |> Enum.max()) + 1
    end
  end

  defp generate_thumbnail(panel) do
    # Generate thumbnail from canvas data
    # This would integrate with image processing service
    Logger.info("Generating thumbnail for panel #{panel.id}")

    # For now, just update with placeholder
    thumbnail_url = "/images/thumbnails/panel_#{panel.id}.png"
    PanelManager.update_panel(%{panel | thumbnail_url: thumbnail_url})
  end

  defp schedule_canvas_save(panel_id, canvas_data) do
    # Debounced save to avoid too frequent database writes
    Process.send_after(self(), {:save_canvas, panel_id, canvas_data}, 1000)
  end

  defp export_to_image(panel, format) do
    # Export canvas to image format
    # This would integrate with image generation service
    {:ok, "/exports/panel_#{panel.id}.#{format}"}
  end

  defp export_to_svg(panel) do
    # Export canvas to SVG format
    # Convert Fabric.js objects to SVG
    {:ok, "/exports/panel_#{panel.id}.svg"}
  end

  defp export_to_json(panel) do
    # Export raw canvas data as JSON
    {:ok, panel.canvas_data}
  end

  defp broadcast_canvas_event(story_id, event_type, data) do
    PubSub.broadcast(
      Frestyl.PubSub,
      "storyboard:#{story_id}",
      {event_type, data}
    )
  end

  defp broadcast_drawing_operation(story_id, panel_id, operation, user_id) do
    PubSub.broadcast(
      Frestyl.PubSub,
      "storyboard:#{story_id}:#{panel_id}",
      {:drawing_operation, operation, user_id}
    )
  end
end
