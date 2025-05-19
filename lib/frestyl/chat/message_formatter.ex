# Create new file lib/frestyl/chat/message_formatter.ex
defmodule Frestyl.Chat.MessageFormatter do
  @moduledoc """
  Handles formatting of message text with markdown-like syntax.
  """

  @doc """
  Formats text with basic markdown.
  Supports *bold*, _italic_, ~strikethrough~, `code`, and URLs.
  """
  def format(text) when is_binary(text) do
    text
    |> format_bold()
    |> format_italic()
    |> format_strikethrough()
    |> format_code()
    |> format_urls()
    |> format_newlines()
  end

  def format(nil), do: ""

  # Format text between *asterisks* as bold
  defp format_bold(text) do
    Regex.replace(~r/\*([^\*]+)\*/, text, "<strong>\\1</strong>")
  end

  # Format text between _underscores_ as italic
  defp format_italic(text) do
    Regex.replace(~r/\_([^\_]+)\_/, text, "<em>\\1</em>")
  end

  # Format text between ~tildes~ as strikethrough
  defp format_strikethrough(text) do
    Regex.replace(~r/\~([^\~]+)\~/, text, "<del>\\1</del>")
  end

  # Format text between `backticks` as code
  defp format_code(text) do
    Regex.replace(~r/\`([^\`]+)\`/, text, "<code class=\"bg-gray-100 px-1 py-0.5 rounded text-sm\">\\1</code>")
  end

  # Format URLs as clickable links
  defp format_urls(text) do
    url_regex = ~r/(https?:\/\/[^\s<]+[^<.,:;"')\]\s])/
    Regex.replace(url_regex, text, "<a href=\"\\1\" target=\"_blank\" class=\"text-blue-500 hover:underline\">\\1</a>")
  end

  # Convert newlines to <br> tags
  defp format_newlines(text) do
    String.replace(text, "\n", "<br>")
  end
end
