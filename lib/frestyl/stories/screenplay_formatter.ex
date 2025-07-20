# lib/frestyl/stories/screenplay_formatter.ex
defmodule Frestyl.Stories.ScreenplayFormatter do
  @moduledoc """
  Professional screenplay formatting engine
  """

  def format_screenplay_content(content, format_rules \\ nil) do
    rules = format_rules || default_format_rules()

    content
    |> parse_screenplay_elements()
    |> apply_formatting_rules(rules)
    |> generate_formatted_output()
  end

  defp parse_screenplay_elements(content) do
    lines = String.split(content, "\n")

    Enum.map(lines, fn line ->
      cond do
        scene_heading?(line) -> {:scene_heading, line}
        character_name?(line) -> {:character, line}
        parenthetical?(line) -> {:parenthetical, line}
        transition?(line) -> {:transition, line}
        true -> {:action, line}
      end
    end)
  end

  defp scene_heading?(line) do
    String.match?(line, ~r/^(INT\.|EXT\.|FADE IN:|FADE OUT:)/)
  end

  defp character_name?(line) do
    String.match?(line, ~r/^[A-Z][A-Z\s]+$/) and String.length(String.trim(line)) < 30
  end

  defp parenthetical?(line) do
    String.starts_with?(String.trim(line), "(") and String.ends_with?(String.trim(line), ")")
  end

  defp transition?(line) do
    String.match?(line, ~r/(CUT TO:|FADE TO:|DISSOLVE TO:)$/)
  end

  defp apply_formatting_rules(elements, rules) do
    Enum.map(elements, fn {type, content} ->
      format_element(type, content, rules)
    end)
  end

  defp format_element(:scene_heading, content, rules) do
    %{
      type: :scene_heading,
      content: String.upcase(content),
      margins: rules.scene_heading.margins,
      font_weight: "bold",
      spacing_before: 2,
      spacing_after: 1
    }
  end

  defp format_element(:character, content, rules) do
    %{
      type: :character,
      content: String.upcase(String.trim(content)),
      margins: rules.character_names.margins,
      alignment: "center",
      spacing_before: 1,
      spacing_after: 0
    }
  end

  defp format_element(:action, content, rules) do
    %{
      type: :action,
      content: content,
      margins: rules.action_lines.margins,
      max_lines: rules.action_lines.max_lines,
      spacing_before: 0,
      spacing_after: 1
    }
  end

  defp format_element(:parenthetical, content, rules) do
    %{
      type: :parenthetical,
      content: content,
      margins: rules.dialogue.parenthetical_margin,
      alignment: "left",
      spacing_before: 0,
      spacing_after: 0
    }
  end

  defp format_element(:transition, content, rules) do
    %{
      type: :transition,
      content: String.upcase(content),
      margins: rules.transitions.margin,
      alignment: "right",
      spacing_before: 1,
      spacing_after: 2
    }
  end

  defp generate_formatted_output(formatted_elements) do
    %{
      elements: formatted_elements,
      page_count: calculate_page_count(formatted_elements),
      word_count: calculate_word_count(formatted_elements),
      estimated_runtime: calculate_runtime(formatted_elements)
    }
  end

  defp calculate_page_count(elements) do
    # Rough calculation: 1 page = ~250 words in screenplay format
    word_count = calculate_word_count(elements)
    ceil(word_count / 250)
  end

  defp calculate_word_count(elements) do
    elements
    |> Enum.map(fn element -> String.split(element.content, " ") |> length() end)
    |> Enum.sum()
  end

  defp calculate_runtime(elements) do
    # Rough calculation: 1 page = 1 minute
    page_count = calculate_page_count(elements)
    "#{page_count} minutes"
  end

  defp default_format_rules do
    %{
      scene_heading: %{
        margins: {1.5, 7.5},
        font: "Courier New",
        size: 12
      },
      action_lines: %{
        margins: {1.5, 7.5},
        max_lines: 4,
        font: "Courier New",
        size: 12
      },
      character_names: %{
        margins: {3.7, 7.5},
        font: "Courier New",
        size: 12
      },
      dialogue: %{
        margins: {2.5, 6.5},
        parenthetical_margin: 3.1,
        font: "Courier New",
        size: 12
      },
      transitions: %{
        margin: {1.5, 7.5},
        alignment: "right",
        font: "Courier New",
        size: 12
      }
    }
  end

  # Export functions
  def export_to_pdf(formatted_screenplay, options \\ %{}) do
    # Would integrate with PDF generation library
    {:ok, "screenplay.pdf"}
  end

  def export_to_final_draft(formatted_screenplay) do
    # Would generate Final Draft XML format
    {:ok, "screenplay.fdx"}
  end

  def export_to_fountain(formatted_screenplay) do
    # Would generate Fountain markup format
    {:ok, "screenplay.fountain"}
  end
end
