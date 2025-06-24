# lib/frestyl_web/live/components/content_block_renderer.ex
defmodule FrestylWeb.Components.ContentBlockRenderer do
  use FrestylWeb, :live_component

  def render(%{block: %{block_type: :text}} = assigns) do
    ~H"""
    <div
      class="story-text-block"
      id={"block-#{@block.block_uuid}"}
      data-block-type="text"
      data-media-bindings={Jason.encode!(@block.media_bindings)}
    >
      <div class="text-content" data-sync-target="true">
        <%= render_text_with_media_bindings(@block) %>
      </div>

      <!-- Audio controls if narration is bound -->
      <%= if has_narration_binding?(@block) do %>
        <div class="audio-controls inline-player">
          <audio
            id={"audio-#{@block.block_uuid}"}
            data-sync-text={"#block-#{@block.block_uuid} .text-content"}
            data-highlight="word-level"
          >
            <source src={get_narration_audio_url(@block)} type="audio/mpeg" />
          </audio>
          <button class="play-narration" data-target={"audio-#{@block.block_uuid}"}>
            <svg class="play-icon">...</svg>
          </button>
        </div>
      <% end %>
    </div>
    """
  end

  def render(%{block: %{block_type: :card_grid}} = assigns) do
    ~H"""
    <div
      class="story-card-grid"
      id={"block-#{@block.block_uuid}"}
      data-columns={@block.layout_config["columns"] || 3}
    >
      <%= for {card, index} <- Enum.with_index(@block.content_data["cards"] || []) do %>
        <div
          id={"media-binding-card-#{@block.id}-#{index}"}
          class="story-card"
          data-card-index={index}
          phx-hook="MediaBindingCard"
          data-media-bindings={Jason.encode!(get_card_media_bindings(@block, index))}
        >
          <div class="card-content">
            <h3><%= card["title"] %></h3>
            <p><%= card["description"] %></p>

            <!-- Media trigger elements -->
            <%= if has_hover_audio?(@block, index) do %>
              <div class="hover-audio-trigger" data-audio-src={get_hover_audio_url(@block, index)}></div>
            <% end %>

            <%= if has_click_video?(@block, index) do %>
              <button class="video-trigger" data-video-src={get_click_video_url(@block, index)}>
                Watch Demo
              </button>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  def render(%{block: %{block_type: :timeline}} = assigns) do
    ~H"""
    <div
      class="story-timeline"
      id={"block-#{@block.block_uuid}"}
      data-orientation={@block.layout_config["orientation"] || "vertical"}
    >
      <%= for {event, index} <- Enum.with_index(@block.content_data["events"] || []) do %>
        <div
          id={"timeline-event-#{@block.id}-#{index}"}
          class="timeline-event"
          data-event-index={index}
          phx-hook="TimelineEvent"
        >
          <div class="event-marker"
               data-click-action={get_event_click_action(@block, index)}>
            <%= if event["date"] do %>
              <span class="event-date"><%= event["date"] %></span>
            <% end %>
          </div>

          <div class="event-content">
            <h4><%= event["title"] %></h4>
            <p><%= event["description"] %></p>

            <!-- Media triggers for this timeline point -->
            <%= render_timeline_media_triggers(@block, index) %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Helper functions for media binding detection
  defp has_narration_binding?(block) do
    Enum.any?(block.media_bindings, &(&1.binding_type == :narration_sync))
  end

  defp get_narration_audio_url(block) do
    block.media_bindings
    |> Enum.find(&(&1.binding_type == :narration_sync))
    |> case do
      nil -> nil
      binding -> binding.media_file.file_path
    end
  end

  defp has_hover_audio?(block, card_index) do
    target_selector = ".story-card[data-card-index='#{card_index}']"
    Enum.any?(block.media_bindings, fn binding ->
      binding.binding_type == :hover_audio && binding.target_selector == target_selector
    end)
  end

  defp has_click_video?(block, card_index) do
    target_selector = ".story-card[data-card-index='#{card_index}']"
    Enum.any?(block.media_bindings, fn binding ->
      binding.binding_type == :click_video && binding.target_selector == target_selector
    end)
  end

    # ============================================================================
  # Text Block Helpers
  # ============================================================================

  defp render_text_with_media_bindings(block) do
    content = get_block_content(block, "text", "")
    media_bindings = get_text_media_bindings(block)

    # Process text content with media binding markers
    processed_content = process_text_with_bindings(content, media_bindings)

    Phoenix.HTML.raw(processed_content)
  end

  defp process_text_with_bindings(text, bindings) when is_map(bindings) do
    # Replace media binding markers in text with interactive elements
    Enum.reduce(bindings, text, fn {marker, binding}, acc ->
      case binding do
        %{"type" => "audio", "url" => url} ->
          String.replace(acc, "{#{marker}}", ~s(<span class="audio-trigger" data-audio-src="#{url}">🔊</span>))

        %{"type" => "video", "url" => url} ->
          String.replace(acc, "{#{marker}}", ~s(<span class="video-trigger" data-video-src="#{url}">▶️</span>))

        %{"type" => "image", "url" => url} ->
          String.replace(acc, "{#{marker}}", ~s(<span class="image-trigger" data-image-src="#{url}">🖼️</span>))

        _ ->
          acc
      end
    end)
  end
  defp process_text_with_bindings(text, _), do: text

  defp get_text_media_bindings(block) do
    get_in(block.content_data, ["media_bindings"]) || %{}
  end

  # ============================================================================
  # Card Block Helpers
  # ============================================================================

  defp get_card_media_bindings(block, index) do
    cards = get_block_content(block, "cards", [])
    card = Enum.at(cards, index, %{})

    %{
      hover_audio: get_card_hover_audio(card),
      click_video: get_card_click_video(card),
      modal_images: get_card_modal_images(card),
      hotspots: get_card_hotspots(card)
    }
  end

  defp get_card_hover_audio(card) do
    case get_in(card, ["media", "hover_audio"]) do
      %{"url" => url} -> url
      url when is_binary(url) -> url
      _ -> nil
    end
  end

  defp get_card_click_video(card) do
    case get_in(card, ["media", "click_video"]) do
      %{"url" => url} -> url
      url when is_binary(url) -> url
      _ -> nil
    end
  end

  defp get_card_modal_images(card) do
    get_in(card, ["media", "modal_images"]) || []
  end

  defp get_card_hotspots(card) do
    get_in(card, ["media", "hotspots"]) || []
  end

  defp get_hover_audio_url(block, index) do
    cards = get_block_content(block, "cards", [])
    card = Enum.at(cards, index, %{})
    get_card_hover_audio(card)
  end

  defp get_click_video_url(block, index) do
    cards = get_block_content(block, "cards", [])
    card = Enum.at(cards, index, %{})
    get_card_click_video(card)
  end

  # ============================================================================
  # Timeline Event Helpers
  # ============================================================================

  defp get_event_click_action(block, index) do
    events = get_block_content(block, "events", [])
    event = Enum.at(events, index, %{})

    case get_in(event, ["click_action"]) do
      action when is_binary(action) -> action
      _ -> "expand"  # default action
    end
  end

  defp render_timeline_media_triggers(block, index) do
    events = get_block_content(block, "events", [])
    event = Enum.at(events, index, %{})
    media_config = get_in(event, ["media"]) || %{}

    content = []

    # Add video trigger if present
    content = if video_url = get_in(media_config, ["video", "url"]) do
      [~s(<div class="video-trigger" data-video-src="#{video_url}">▶️ Play Video</div>) | content]
    else
      content
    end

    # Add audio trigger if present
    content = if audio_url = get_in(media_config, ["audio", "url"]) do
      [~s(<div class="audio-trigger" data-audio-src="#{audio_url}">🔊 Play Audio</div>) | content]
    else
      content
    end

    # Add image gallery if present
    content = if images = get_in(media_config, ["images"]) do
      image_html = Enum.map(images, fn img ->
        ~s(<img class="timeline-image" src="#{img["url"]}" alt="#{img["caption"] || ""}" />)
      end) |> Enum.join("")

      [~s(<div class="image-gallery">#{image_html}</div>) | content]
    else
      content
    end

    content
    |> Enum.reverse()
    |> Enum.join("")
    |> Phoenix.HTML.raw()
  end

  # ============================================================================
  # General Helper Functions
  # ============================================================================

  defp get_block_content(block, key, default \\ nil) do
    case get_in(block.content_data, [key]) do
      nil -> default
      value -> value
    end
  end

  defp safe_get_in(map, keys, default \\ nil) do
    case get_in(map, keys) do
      nil -> default
      value -> value
    end
  end

  # ============================================================================
  # Media URL Helpers
  # ============================================================================

  defp get_media_url(media_item) when is_map(media_item) do
    case media_item do
      %{"url" => url} when is_binary(url) -> url
      %{url: url} when is_binary(url) -> url
      _ -> nil
    end
  end
  defp get_media_url(url) when is_binary(url), do: url
  defp get_media_url(_), do: nil

  defp format_media_binding(type, data) do
    %{
      type: type,
      data: data,
      trigger_id: "trigger_#{System.unique_integer([:positive])}"
    }
  end

  # ============================================================================
  # Content Processing Helpers
  # ============================================================================

  defp sanitize_html_content(content) when is_binary(content) do
    # Basic HTML sanitization - you might want to use a proper HTML sanitizer
    content
    |> String.replace(~r/<script[^>]*>.*?<\/script>/si, "")
    |> String.replace(~r/<iframe[^>]*>.*?<\/iframe>/si, "")
    |> Phoenix.HTML.raw()
  end
  defp sanitize_html_content(_), do: ""

  defp extract_media_markers(text) when is_binary(text) do
    # Extract media binding markers like {audio1}, {video2}, etc.
    Regex.scan(~r/\{([^}]+)\}/, text, capture: :all_but_first)
    |> List.flatten()
    |> Enum.uniq()
  end
  defp extract_media_markers(_), do: []
end
