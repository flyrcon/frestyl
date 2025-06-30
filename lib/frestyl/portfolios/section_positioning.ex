# lib/frestyl/portfolios/section_positioning.ex
# Portfolio Section Positioning and Visibility Management System

defmodule Frestyl.Portfolios.SectionPositioning do
  @moduledoc """
  Handles portfolio section positioning, ordering, and visibility controls.
  Supports predefined positions for video intros and drag-and-drop reordering.
  """

  alias Frestyl.{Portfolios, Repo}
  import Ecto.Query

  # ============================================================================
  # PREDEFINED POSITIONS
  # ============================================================================

  @predefined_positions %{
    "hero" => %{
      name: "Hero Section",
      description: "Top of portfolio (most prominent)",
      order: 0,
      css_class: "hero-section",
      container: "header"
    },
    "about" => %{
      name: "About Section",
      description: "Within about/intro content",
      order: 100,
      css_class: "about-section",
      container: "main"
    },
    "sidebar" => %{
      name: "Sidebar",
      description: "Side panel placement",
      order: 999,
      css_class: "sidebar-section",
      container: "sidebar"
    },
    "footer" => %{
      name: "Footer",
      description: "Bottom of portfolio",
      order: 1000,
      css_class: "footer-section",
      container: "footer"
    }
  }

  def get_predefined_positions, do: @predefined_positions

  def get_position_info(position_id) do
    Map.get(@predefined_positions, position_id, @predefined_positions["hero"])
  end

  # ============================================================================
  # SECTION POSITIONING
  # ============================================================================

  @doc """
  Updates the position of a video intro section and reorders other sections accordingly.
  """
  def update_video_section_position(portfolio_id, section_id, new_position) do
    Repo.transaction(fn ->
      with {:ok, section} <- get_section_with_lock(section_id),
           :ok <- validate_section_belongs_to_portfolio(section, portfolio_id),
           {:ok, position_info} <- validate_position(new_position),
           {:ok, updated_section} <- update_section_position(section, new_position, position_info),
           :ok <- reorder_sections_in_position(portfolio_id, new_position) do
        updated_section
      else
        {:error, reason} -> Repo.rollback(reason)
        error -> Repo.rollback(error)
      end
    end)
  end

  @doc """
  Reorders sections within a portfolio, maintaining position-based grouping.
  """
  def reorder_portfolio_sections(portfolio_id, section_orders) do
    Repo.transaction(fn ->
      sections = get_portfolio_sections_with_lock(portfolio_id)

      Enum.reduce_while(section_orders, :ok, fn {section_id, new_order}, _acc ->
        case Enum.find(sections, &(&1.id == section_id)) do
          nil ->
            {:halt, {:error, "Section #{section_id} not found"}}
          section ->
            case update_section_order(section, new_order) do
              {:ok, _} -> {:cont, :ok}
              {:error, reason} -> {:halt, {:error, reason}}
            end
        end
      end)
      |> case do
        :ok -> :ok
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  # ============================================================================
  # VISIBILITY MANAGEMENT
  # ============================================================================

  @doc """
  Toggles section visibility while preserving section data for future re-enabling.
  """
  def toggle_section_visibility(section_id, visible \\ nil) do
    Repo.transaction(fn ->
      with {:ok, section} <- get_section_with_lock(section_id) do
        new_visibility = if is_nil(visible), do: !section.visible, else: visible

        updated_content = section.content
        |> Map.put("visible", new_visibility)
        |> Map.put("last_visibility_change", DateTime.utc_now() |> DateTime.to_iso8601())

        # Store hidden state metadata for analytics
        updated_content = if not new_visibility do
          Map.put(updated_content, "hidden_at", DateTime.utc_now() |> DateTime.to_iso8601())
        else
          Map.drop(updated_content, ["hidden_at"])
        end

        case Portfolios.update_section(section, %{
          visible: new_visibility,
          content: updated_content
        }) do
          {:ok, updated_section} -> updated_section
          {:error, changeset} -> Repo.rollback(changeset)
        end
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  @doc """
  Sets visibility for multiple sections at once.
  """
  def bulk_update_visibility(section_visibility_map) do
    Repo.transaction(fn ->
      Enum.reduce_while(section_visibility_map, [], fn {section_id, visible}, acc ->
        case toggle_section_visibility(section_id, visible) do
          {:ok, updated_section} -> {:cont, [updated_section | acc]}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
      |> case do
        {:error, reason} -> Repo.rollback(reason)
        updated_sections -> Enum.reverse(updated_sections)
      end
    end)
  end

  # ============================================================================
  # SECTION ORDERING HELPERS
  # ============================================================================

  @doc """
  Gets all sections for a portfolio ordered by position and order.
  """
  def get_ordered_portfolio_sections(portfolio_id, include_hidden \\ false) do
    query = from s in Frestyl.Portfolios.PortfolioSection,
      where: s.portfolio_id == ^portfolio_id,
      order_by: [asc: s.position, asc: s.order, asc: s.inserted_at]

    query = if include_hidden do
      query
    else
      where(query, [s], s.visible == true)
    end

    Repo.all(query)
  end

  @doc """
  Groups sections by their position (hero, about, sidebar, footer).
  """
  def group_sections_by_position(sections) do
    sections
    |> Enum.group_by(fn section ->
      get_section_position(section)
    end)
    |> Map.new(fn {position, sections} ->
      {position, Enum.sort_by(sections, &(&1.order || 0))}
    end)
  end

  @doc """
  Gets the next available order number for a position.
  """
  def get_next_order_for_position(portfolio_id, position) do
    position_info = get_position_info(position)
    base_order = position_info.order

    max_order = from(s in Frestyl.Portfolios.PortfolioSection,
      where: s.portfolio_id == ^portfolio_id and
             s.position >= ^base_order and
             s.position < ^(base_order + 100),
      select: max(s.position)
    )
    |> Repo.one()

    (max_order || base_order) + 1
  end

  # ============================================================================
  # THUMBNAIL GENERATION FOR VIDEO PREVIEWS
  # ============================================================================

  @doc """
  Generates a thumbnail for video intro sections to show in section management.
  """
  def generate_section_thumbnail(section) do
    case section.section_type do
      :media_showcase ->
        case get_in(section.content, ["video_type"]) do
          "introduction" ->
            video_url = get_in(section.content, ["video_url"])
            if video_url do
              %{
                type: "video",
                url: video_url,
                thumbnail: generate_video_thumbnail_url(video_url),
                duration: get_in(section.content, ["duration"]) || 0
              }
            else
              default_section_thumbnail(section)
            end
          _ ->
            default_section_thumbnail(section)
        end
      _ ->
        default_section_thumbnail(section)
    end
  end

  defp generate_video_thumbnail_url(video_url) do
    # For now, return a placeholder. In production, you'd generate actual thumbnails
    "/images/video-thumbnail-placeholder.jpg"
  end

  defp default_section_thumbnail(section) do
    %{
      type: "section",
      title: section.title,
      section_type: section.section_type,
      icon: get_section_icon(section.section_type)
    }
  end

  defp get_section_icon(:media_showcase), do: "🎥"
  defp get_section_icon(:intro), do: "👋"
  defp get_section_icon(:experience), do: "💼"
  defp get_section_icon(:education), do: "🎓"
  defp get_section_icon(:skills), do: "⚡"
  defp get_section_icon(:projects), do: "🚀"
  defp get_section_icon(:contact), do: "📧"
  defp get_section_icon(_), do: "📄"

  # ============================================================================
  # PRIVATE HELPER FUNCTIONS
  # ============================================================================

  defp get_section_with_lock(section_id) do
    case Repo.get(Frestyl.Portfolios.PortfolioSection, section_id) do
      nil -> {:error, "Section not found"}
      section -> {:ok, section}
    end
  end

  defp get_portfolio_sections_with_lock(portfolio_id) do
    from(s in Frestyl.Portfolios.PortfolioSection,
      where: s.portfolio_id == ^portfolio_id,
      lock: "FOR UPDATE"
    )
    |> Repo.all()
  end

  defp validate_section_belongs_to_portfolio(section, portfolio_id) do
    if section.portfolio_id == portfolio_id do
      :ok
    else
      {:error, "Section does not belong to this portfolio"}
    end
  end

  defp validate_position(position) do
    case Map.get(@predefined_positions, position) do
      nil -> {:error, "Invalid position: #{position}"}
      position_info -> {:ok, position_info}
    end
  end

  defp update_section_position(section, new_position, position_info) do
    new_order = get_next_order_for_position(section.portfolio_id, new_position)

    updated_content = section.content
    |> Map.put("position", new_position)
    |> Map.put("position_updated_at", DateTime.utc_now() |> DateTime.to_iso8601())

    case Portfolios.update_section(section, %{
      position: new_order,
      content: updated_content
    }) do
      {:ok, updated_section} -> {:ok, updated_section}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp update_section_order(section, new_order) do
    case Portfolios.update_section(section, %{position: new_order}) do
      {:ok, updated_section} -> {:ok, updated_section}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp reorder_sections_in_position(portfolio_id, position) do
    # Get all sections in this position and renumber them
    position_info = get_position_info(position)
    base_order = position_info.order

    sections = from(s in Frestyl.Portfolios.PortfolioSection,
      where: s.portfolio_id == ^portfolio_id and
             s.position >= ^base_order and
             s.position < ^(base_order + 100),
      order_by: [asc: s.position, asc: s.inserted_at]
    )
    |> Repo.all()

    sections
    |> Enum.with_index()
    |> Enum.reduce_while(:ok, fn {section, index}, _acc ->
      new_order = base_order + index
      case update_section_order(section, new_order) do
        {:ok, _} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp get_section_position(section) do
    # Check content for position first, then fall back to order-based detection
    content_position = get_in(section.content, ["position"])
    if content_position && Map.has_key?(@predefined_positions, content_position) do
      content_position
    else
      # Determine position from order number
      order = section.position || 0
      cond do
        order < 100 -> "hero"
        order < 500 -> "about"
        order < 1000 -> "sidebar"
        true -> "footer"
      end
    end
  end
end
