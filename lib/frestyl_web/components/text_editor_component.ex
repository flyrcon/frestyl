# lib/frestyl_web/live/components/text_editor_component.ex - Mobile-First Text Editor Component
defmodule FrestylWeb.TextEditorComponent do
  use FrestylWeb, :live_component

  alias Frestyl.Content
  alias Frestyl.Media

  @impl true
  def mount(socket) do
    {:ok, socket
      |> assign(:editor_mode, "blocks")
      |> assign(:active_block, nil)
      |> assign(:toolbar_visible, false)
      |> assign(:media_picker_open, false)
      |> assign(:voice_recording, false)
      |> assign(:suggestions_visible, false)
    }
  end

  @impl true
  def update(assigns, socket) do
    document = assigns.document

    {:ok, socket
      |> assign(assigns)
      |> assign(:blocks, document.blocks || [])
      |> assign(:document_config, get_document_config(document.document_type))
      |> assign(:mobile_optimized, assigns[:is_mobile] || false)
      |> assign(:collaborative_cursors, get_collaborative_cursors(document.id))
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      class="text-editor-container h-full flex flex-col bg-white"
      id={"text-editor-#{@document.id}"}
      phx-hook="TextEditor"
      data-document-id={@document.id}
      data-mobile-optimized={@mobile_optimized}
    >
      <!-- Document Header -->
      <div class="flex items-center justify-between p-4 border-b border-gray-200 bg-white sticky top-0 z-10">
        <div class="flex-1">
          <input
            type="text"
            value={@document.title}
            phx-blur="update_document_title"
            phx-target={@myself}
            class="text-xl font-bold border-none focus:outline-none focus:ring-0 w-full bg-transparent"
            placeholder="Document title..."
          />
          <div class="flex items-center space-x-2 text-sm text-gray-500 mt-1">
            <span><%= format_document_type(@document.document_type) %></span>
            <span>•</span>
            <span><%= calculate_word_count(@blocks) %> words</span>
            <span>•</span>
            <span><%= calculate_reading_time(@blocks) %> min read</span>
          </div>
        </div>

        <!-- Mobile Toolbar Toggle -->
        <button
          :if={@mobile_optimized}
          phx-click="toggle_mobile_toolbar"
          phx-target={@myself}
          class="p-2 text-gray-600 hover:text-gray-900 lg:hidden"
        >
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" />
          </svg>
        </button>
      </div>

      <!-- Mobile Floating Toolbar -->
      <div
        :if={@mobile_optimized and @toolbar_visible}
        class="fixed bottom-4 left-4 right-4 z-50 lg:hidden"
      >
        <div class="bg-gray-900 rounded-xl shadow-2xl p-3">
          <div class="flex items-center justify-around">
            <!-- Format Tools -->
            <button
              phx-click="toggle_format"
              phx-value-format="bold"
              phx-target={@myself}
              class="p-2 text-white hover:bg-gray-700 rounded"
              title="Bold"
            >
              <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
                <path d="M15.6 10.79c.97-.67 1.65-1.77 1.65-2.79 0-2.26-1.75-4-4-4H7v14h7.04c2.09 0 3.71-1.7 3.71-3.79 0-1.52-.86-2.82-2.15-3.42zM10 6.5h3c.83 0 1.5.67 1.5 1.5s-.67 1.5-1.5 1.5h-3v-3zm3.5 9H10v-3h3.5c.83 0 1.5.67 1.5 1.5s-.67 1.5-1.5 1.5z"/>
              </svg>
            </button>

            <button
              phx-click="toggle_format"
              phx-value-format="italic"
              phx-target={@myself}
              class="p-2 text-white hover:bg-gray-700 rounded"
              title="Italic"
            >
              <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
                <path d="M10 4v3h2.21l-3.42 8H6v3h8v-3h-2.21l3.42-8H18V4z"/>
              </svg>
            </button>

            <!-- Media Tools -->
            <button
              phx-click="open_media_picker"
              phx-target={@myself}
              class="p-2 text-white hover:bg-gray-700 rounded"
              title="Add Media"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
              </svg>
            </button>

            <!-- Voice Recording -->
            <button
              phx-click="toggle_voice_recording"
              phx-target={@myself}
              class={[
                "p-2 rounded transition-colors",
                @voice_recording && "bg-red-600 text-white" || "text-white hover:bg-gray-700"
              ]}
              title="Voice Note"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z" />
              </svg>
            </button>

            <!-- AI Suggestions -->
            <button
              phx-click="toggle_ai_suggestions"
              phx-target={@myself}
              class="p-2 text-white hover:bg-gray-700 rounded"
              title="AI Assist"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z" />
              </svg>
            </button>
          </div>
        </div>
      </div>

      <!-- Document Guidance Panel (Mobile Collapsible) -->
      <div
        :if={show_guidance?(@document_config)}
        class={[
          "border-b border-gray-200 bg-blue-50",
          @mobile_optimized && "collapsible" || ""
        ]}
      >
        <div class="p-4">
          <div class="flex items-start justify-between">
            <div class="flex-1">
              <h3 class="text-sm font-medium text-blue-900">
                Writing Guide: <%= @document_config.name %>
              </h3>
              <p class="text-sm text-blue-700 mt-1">
                <%= @document_config.description %>
              </p>
            </div>
            <button
              :if={@mobile_optimized}
              phx-click="toggle_guidance_panel"
              phx-target={@myself}
              class="text-blue-600 hover:text-blue-800 lg:hidden"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
              </svg>
            </button>
          </div>

          <!-- Progress Indicator -->
          <div class="mt-3">
            <div class="flex justify-between text-xs text-blue-600 mb-1">
              <span>Progress</span>
              <span><%= calculate_completion_percentage(@blocks, @document_config) %>%</span>
            </div>
            <div class="w-full bg-blue-200 rounded-full h-2">
              <div
                class="bg-blue-600 h-2 rounded-full transition-all duration-500"
                style={"width: #{calculate_completion_percentage(@blocks, @document_config)}%"}
              ></div>
            </div>
          </div>

          <!-- Next Steps -->
          <%= if next_step = get_next_suggested_step(@blocks, @document_config) do %>
            <div class="mt-3 p-3 bg-white rounded border border-blue-200">
              <p class="text-sm font-medium text-gray-900">Next: <%= next_step.title %></p>
              <p class="text-xs text-gray-600 mt-1"><%= next_step.description %></p>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Main Editor Area -->
      <div class="flex-1 overflow-y-auto" id="editor-scroll-container">
        <div class="max-w-4xl mx-auto p-4 lg:p-8">
          <!-- Collaborative Cursors -->
          <div
            :for={{user_id, cursor} <- @collaborative_cursors}
            class="absolute pointer-events-none z-20"
            style={"top: #{cursor.y}px; left: #{cursor.x}px;"}
          >
            <div class="flex items-center">
              <div class="w-0.5 h-6 bg-indigo-500 animate-pulse"></div>
              <div class="ml-1 bg-indigo-500 text-white text-xs px-2 py-1 rounded whitespace-nowrap">
                <%= get_user_name(user_id) %>
              </div>
            </div>
          </div>

          <!-- Document Blocks -->
          <div class="space-y-4" id="document-blocks">
            <%= for {block, index} <- Enum.with_index(@blocks) do %>
              <.block_component
                block={block}
                index={index}
                active={@active_block == block.id}
                document_config={@document_config}
                mobile_optimized={@mobile_optimized}
                myself={@myself}
              />
            <% end %>

            <!-- Add Block Button -->
            <div class="flex justify-center py-8">
              <button
                phx-click="add_block"
                phx-target={@myself}
                class="flex items-center space-x-2 px-4 py-2 text-gray-600 hover:text-gray-900 hover:bg-gray-100 rounded-lg transition-colors"
              >
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
                </svg>
                <span>Add Content Block</span>
              </button>
            </div>
          </div>
        </div>
      </div>

      <!-- Media Picker Modal -->
      <%= if @media_picker_open do %>
        <.media_picker_modal
          document={@document}
          active_block={@active_block}
          myself={@myself}
        />
      <% end %>

      <!-- AI Suggestions Panel -->
      <%= if @suggestions_visible do %>
        <.ai_suggestions_panel
          document={@document}
          blocks={@blocks}
          myself={@myself}
        />
      <% end %>
    </div>
    """
  end

  # Block Component for Different Content Types
  defp block_component(assigns) do
    ~H"""
    <div
      class={[
        "block-container group relative",
        @active && "ring-2 ring-indigo-500" || "",
        @mobile_optimized && "touch-manipulation" || ""
      ]}
      id={"block-#{@block.id}"}
      phx-click="activate_block"
      phx-value-block-id={@block.id}
      phx-target={@myself}
    >
      <!-- Block Controls (Desktop) -->
      <div class="absolute left-0 top-0 -ml-10 opacity-0 group-hover:opacity-100 transition-opacity lg:block hidden">
        <div class="flex flex-col space-y-1">
          <button
            phx-click="move_block_up"
            phx-value-block-id={@block.id}
            phx-target={@myself}
            class="p-1 text-gray-400 hover:text-gray-600 hover:bg-gray-100 rounded"
            title="Move up"
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7" />
            </svg>
          </button>

          <button
            phx-click="add_media_to_block"
            phx-value-block-id={@block.id}
            phx-target={@myself}
            class="p-1 text-gray-400 hover:text-gray-600 hover:bg-gray-100 rounded"
            title="Add media"
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
            </svg>
          </button>

          <button
            phx-click="delete_block"
            phx-value-block-id={@block.id}
            phx-target={@myself}
            class="p-1 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded"
            title="Delete"
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
            </svg>
          </button>
        </div>
      </div>

      <!-- Block Content -->
      <%= case @block.block_type do %>
        <% "title" -> %>
          <input
            type="text"
            value={@block.content}
            phx-blur="update_block_content"
            phx-value-block-id={@block.id}
            phx-target={@myself}
            class="w-full text-3xl lg:text-4xl font-bold border-none focus:outline-none focus:ring-0 bg-transparent"
            placeholder={@block.metadata["placeholder"] || "Document title..."}
          />

        <% "subtitle" -> %>
          <input
            type="text"
            value={@block.content}
            phx-blur="update_block_content"
            phx-value-block-id={@block.id}
            phx-target={@myself}
            class="w-full text-xl lg:text-2xl text-gray-600 border-none focus:outline-none focus:ring-0 bg-transparent"
            placeholder={@block.metadata["placeholder"] || "Subtitle..."}
          />

        <% "heading" -> %>
          <div class="flex items-center space-x-2">
            <select
              phx-change="update_heading_level"
              phx-value-block-id={@block.id}
              phx-target={@myself}
              class="text-sm border-gray-300 rounded"
            >
              <option value="1">H1</option>
              <option value="2" selected={@block.metadata["level"] == 2}>H2</option>
              <option value="3" selected={@block.metadata["level"] == 3}>H3</option>
            </select>
            <input
              type="text"
              value={@block.content}
              phx-blur="update_block_content"
              phx-value-block-id={@block.id}
              phx-target={@myself}
              class={[
                "flex-1 font-bold border-none focus:outline-none focus:ring-0 bg-transparent",
                case @block.metadata["level"] || 2 do
                  1 -> "text-2xl lg:text-3xl"
                  2 -> "text-xl lg:text-2xl"
                  3 -> "text-lg lg:text-xl"
                  _ -> "text-lg"
                end
              ]}
              placeholder="Heading..."
            />
          </div>

        <% "paragraph" -> %>
          <div class="relative">
            <textarea
              phx-blur="update_block_content"
              phx-keyup="auto_resize_textarea"
              phx-value-block-id={@block.id}
              phx-target={@myself}
              class="w-full min-h-[60px] text-base lg:text-lg leading-relaxed border-none focus:outline-none focus:ring-0 bg-transparent resize-none"
              placeholder={@block.metadata["placeholder"] || "Start writing..."}
            ><%= @block.content %></textarea>

            <!-- Media Attachments -->
            <%= if @block.metadata["media_attachments"] do %>
              <div class="mt-4 space-y-4">
                <%= for attachment <- @block.metadata["media_attachments"] do %>
                  <.media_attachment_component attachment={attachment} block={@block} myself={@myself} />
                <% end %>
              </div>
            <% end %>
          </div>

        <% "quote" -> %>
          <blockquote class="border-l-4 border-indigo-500 pl-4 italic">
            <textarea
              phx-blur="update_block_content"
              phx-value-block-id={@block.id}
              phx-target={@myself}
              class="w-full min-h-[60px] text-lg lg:text-xl text-gray-700 border-none focus:outline-none focus:ring-0 bg-transparent resize-none"
              placeholder="Quote text..."
            ><%= @block.content %></textarea>
          </blockquote>

        <% "code" -> %>
          <div class="bg-gray-900 rounded-lg p-4">
            <div class="flex items-center justify-between mb-2">
              <select
                phx-change="update_code_language"
                phx-value-block-id={@block.id}
                phx-target={@myself}
                class="text-sm bg-gray-800 text-white border-gray-700 rounded"
              >
                <option value="javascript">JavaScript</option>
                <option value="elixir">Elixir</option>
                <option value="python">Python</option>
                <option value="css">CSS</option>
                <option value="html">HTML</option>
              </select>
              <button
                phx-click="copy_code"
                phx-value-block-id={@block.id}
                phx-target={@myself}
                class="text-gray-400 hover:text-white text-sm"
              >
                Copy
              </button>
            </div>
            <textarea
              phx-blur="update_block_content"
              phx-value-block-id={@block.id}
              phx-target={@myself}
              class="w-full min-h-[120px] bg-transparent text-green-400 font-mono text-sm border-none focus:outline-none focus:ring-0 resize-none"
              placeholder="Enter code..."
            ><%= @block.content %></textarea>
          </div>

        <% "media_placeholder" -> %>
          <div class="border-2 border-dashed border-gray-300 rounded-lg p-8 text-center">
            <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
            </svg>
            <h3 class="mt-2 text-sm font-medium text-gray-900">Add media</h3>
            <p class="mt-1 text-sm text-gray-500">Image, video, audio, or document</p>
            <div class="mt-6 flex justify-center space-x-3">
              <button
                phx-click="upload_media"
                phx-value-block-id={@block.id}
                phx-value-media-type="image"
                phx-target={@myself}
                class="inline-flex items-center px-3 py-2 border border-gray-300 rounded-md text-sm font-medium text-gray-700 bg-white hover:bg-gray-50"
              >
                Upload
              </button>
              <button
                phx-click="take_photo"
                phx-value-block-id={@block.id}
                phx-target={@myself}
                class="inline-flex items-center px-3 py-2 border border-gray-300 rounded-md text-sm font-medium text-gray-700 bg-white hover:bg-gray-50"
              >
                Camera
              </button>
            </div>
          </div>

        <% _ -> %>
          <!-- Default/Custom Block Type -->
          <div class="p-4 bg-gray-50 rounded-lg">
            <p class="text-sm text-gray-600">Block type: <%= @block.block_type %></p>
            <textarea
              phx-blur="update_block_content"
              phx-value-block-id={@block.id}
              phx-target={@myself}
              class="w-full mt-2 min-h-[60px] border-none focus:outline-none focus:ring-0 bg-transparent"
              placeholder="Content..."
            ><%= @block.content %></textarea>
          </div>
      <% end %>

      <!-- Block Guidance (if available) -->
      <%= if guidance = get_block_guidance(@block, @document_config) do %>
        <div class="mt-2 p-3 bg-blue-50 border border-blue-200 rounded text-sm text-blue-700">
          <p class="font-medium">💡 Writing tip:</p>
          <p><%= guidance %></p>
        </div>
      <% end %>

      <!-- Mobile Block Actions -->
      <%= if @mobile_optimized and @active do %>
        <div class="mt-3 flex justify-center space-x-2 lg:hidden">
          <button
            phx-click="add_media_to_block"
            phx-value-block-id={@block.id}
            phx-target={@myself}
            class="px-3 py-1 bg-gray-100 text-gray-700 rounded-full text-sm"
          >
            📷 Add Media
          </button>
          <button
            phx-click="record_voice_note"
            phx-value-block-id={@block.id}
            phx-target={@myself}
            class="px-3 py-1 bg-gray-100 text-gray-700 rounded-full text-sm"
          >
            🎙️ Voice Note
          </button>
          <button
            phx-click="get_ai_suggestions"
            phx-value-block-id={@block.id}
            phx-target={@myself}
            class="px-3 py-1 bg-gray-100 text-gray-700 rounded-full text-sm"
          >
            ✨ AI Help
          </button>
        </div>
      <% end %>
    </div>
    """
  end

  # Media Attachment Component
  defp media_attachment_component(assigns) do
    ~H"""
    <div class="media-attachment relative group">
      <%= case @attachment.attachment_type do %>
        <% "image" -> %>
          <div class="relative">
            <img
              src={get_media_url(@attachment.media_file_id)}
              alt={@attachment.metadata["alt_text"] || ""}
              class={[
                "rounded-lg shadow-sm",
                case @attachment.position["size"] do
                  "small" -> "max-w-xs"
                  "large" -> "w-full"
                  _ -> "max-w-md"
                end,
                case @attachment.position["alignment"] do
                  "center" -> "mx-auto"
                  "left" -> "mr-auto"
                  "right" -> "ml-auto"
                  _ -> ""
                end
              ]}
            />
            <%= if @attachment.metadata["caption"] do %>
              <p class="mt-2 text-sm text-gray-600 italic">
                <%= @attachment.metadata["caption"] %>
              </p>
            <% end %>

            <!-- Edit/Remove Controls -->
            <div class="absolute top-2 right-2 opacity-0 group-hover:opacity-100 transition-opacity">
              <div class="flex space-x-1">
                <button
                  phx-click="edit_media_attachment"
                  phx-value-attachment-id={@attachment.id}
                  phx-target={@myself}
                  class="p-1 bg-black bg-opacity-50 text-white rounded hover:bg-opacity-70"
                  title="Edit"
                >
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                  </svg>
                </button>
                <button
                  phx-click="remove_media_attachment"
                  phx-value-attachment-id={@attachment.id}
                  phx-target={@myself}
                  class="p-1 bg-black bg-opacity-50 text-white rounded hover:bg-opacity-70"
                  title="Remove"
                >
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </div>
            </div>
          </div>

        <% "audio" -> %>
          <div class="bg-gray-50 rounded-lg p-4">
            <div class="flex items-center space-x-3">
              <button
                phx-click="toggle_audio_playback"
                phx-value-attachment-id={@attachment.id}
                phx-target={@myself}
                class="p-2 bg-indigo-600 text-white rounded-full hover:bg-indigo-700"
              >
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.828 14.828a4 4 0 01-5.656 0M9 10h1.586a1 1 0 01.707.293l2.414 2.414a1 1 0 00.707.293H15a2 2 0 002-2V9a2 2 0 00-2-2h-1.586a1 1 0 01-.707-.293L10.293 4.293A1 1 0 009.586 4H8a2 2 0 00-2 2v8a2 2 0 002 2z" />
                </svg>
              </button>
              <div class="flex-1">
                <p class="font-medium text-gray-900">
                  <%= @attachment.metadata["title"] || "Audio Note" %>
                </p>
                <p class="text-sm text-gray-500">
                  Duration: <%= format_duration(@attachment.metadata["duration"]) %>
                </p>
                <%= if @attachment.metadata["transcript"] do %>
                  <p class="text-sm text-gray-700 mt-1 italic">
                    "<%= truncate(@attachment.metadata["transcript"], 100) %>..."
                  </p>
                <% end %>
              </div>
            </div>
          </div>

        <% "video" -> %>
          <div class="relative">
            <video
              controls
              class="w-full rounded-lg shadow-sm"
              poster={get_video_thumbnail(@attachment.media_file_id)}
            >
              <source src={get_media_url(@attachment.media_file_id)} type="video/mp4">
              Your browser does not support the video tag.
            </video>
            <%= if @attachment.metadata["caption"] do %>
              <p class="mt-2 text-sm text-gray-600 italic">
                <%= @attachment.metadata["caption"] %>
              </p>
            <% end %>
          </div>

        <% "code" -> %>
          <div class="bg-gray-900 rounded-lg overflow-hidden">
            <div class="flex items-center justify-between px-4 py-2 bg-gray-800">
              <span class="text-sm text-gray-300">
                <%= @attachment.metadata["language"] || "Code" %>
              </span>
              <button
                phx-click="copy_attachment_code"
                phx-value-attachment-id={@attachment.id}
                phx-target={@myself}
                class="text-sm text-gray-400 hover:text-white"
              >
                Copy
              </button>
            </div>
            <pre class="p-4 text-sm text-green-400 overflow-x-auto"><code><%= @attachment.metadata["content"] %></code></pre>
          </div>
      <% end %>
    </div>
    """
  end

  # Media Picker Modal
  defp media_picker_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 overflow-y-auto">
      <div class="flex min-h-screen items-center justify-center p-4">
        <!-- Backdrop -->
        <div
          class="fixed inset-0 bg-black bg-opacity-50 transition-opacity"
          phx-click="close_media_picker"
          phx-target={@myself}
        ></div>

        <!-- Modal Content -->
        <div class="relative bg-white rounded-xl shadow-2xl w-full max-w-4xl max-h-[80vh] overflow-hidden">
          <!-- Header -->
          <div class="flex items-center justify-between p-6 border-b border-gray-200">
            <h3 class="text-lg font-semibold text-gray-900">Add Media to Block</h3>
            <button
              phx-click="close_media_picker"
              phx-target={@myself}
              class="text-gray-400 hover:text-gray-600"
            >
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>

          <!-- Content -->
          <div class="p-6">
            <!-- Media Type Tabs -->
            <div class="flex space-x-1 bg-gray-100 rounded-lg p-1 mb-6">
              <button class="flex-1 py-2 px-4 bg-white text-gray-900 rounded-md font-medium">
                📷 Images
              </button>
              <button class="flex-1 py-2 px-4 text-gray-600 hover:text-gray-900 rounded-md">
                🎵 Audio
              </button>
              <button class="flex-1 py-2 px-4 text-gray-600 hover:text-gray-900 rounded-md">
                🎬 Video
              </button>
              <button class="flex-1 py-2 px-4 text-gray-600 hover:text-gray-900 rounded-md">
                📄 Files
              </button>
            </div>

            <!-- Upload Area -->
            <div class="border-2 border-dashed border-gray-300 rounded-lg p-8 text-center mb-6">
              <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
              </svg>
              <h4 class="mt-2 text-lg font-medium text-gray-900">Upload media</h4>
              <p class="mt-1 text-sm text-gray-500">Drag and drop files here, or click to browse</p>

              <div class="mt-6 flex justify-center space-x-4">
                <button
                  phx-click="browse_files"
                  phx-target={@myself}
                  class="px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700"
                >
                  Browse Files
                </button>
                <button
                  phx-click="take_photo"
                  phx-target={@myself}
                  class="px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50"
                >
                  Take Photo
                </button>
                <button
                  phx-click="record_audio"
                  phx-target={@myself}
                  class="px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50"
                >
                  Record Audio
                </button>
              </div>
            </div>

            <!-- Recent Media -->
            <div>
              <h4 class="text-sm font-medium text-gray-900 mb-3">Recent Media</h4>
              <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
                <!-- Sample media items -->
                <div class="aspect-square bg-gray-100 rounded-lg cursor-pointer hover:bg-gray-200 flex items-center justify-center">
                  <span class="text-2xl">🖼️</span>
                </div>
                <div class="aspect-square bg-gray-100 rounded-lg cursor-pointer hover:bg-gray-200 flex items-center justify-center">
                  <span class="text-2xl">🎵</span>
                </div>
                <div class="aspect-square bg-gray-100 rounded-lg cursor-pointer hover:bg-gray-200 flex items-center justify-center">
                  <span class="text-2xl">🎬</span>
                </div>
                <div class="aspect-square bg-gray-100 rounded-lg cursor-pointer hover:bg-gray-200 flex items-center justify-center">
                  <span class="text-2xl">📄</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # AI Suggestions Panel
  defp ai_suggestions_panel(assigns) do
    ~H"""
    <div class="fixed bottom-20 right-4 w-80 bg-white rounded-xl shadow-2xl border border-gray-200 lg:bottom-4">
      <div class="p-4 border-b border-gray-200">
        <div class="flex items-center justify-between">
          <h3 class="font-semibold text-gray-900">✨ AI Writing Assistant</h3>
          <button
            phx-click="close_ai_suggestions"
            phx-target={@myself}
            class="text-gray-400 hover:text-gray-600"
          >
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>
      </div>

      <div class="p-4 space-y-4 max-h-96 overflow-y-auto">
        <!-- Content Suggestions -->
        <div>
          <h4 class="text-sm font-medium text-gray-700 mb-2">Suggestions for this section:</h4>
          <div class="space-y-2">
            <button class="w-full text-left p-3 bg-blue-50 rounded-lg hover:bg-blue-100 transition-colors">
              <p class="text-sm font-medium text-blue-900">Add a compelling statistic</p>
              <p class="text-xs text-blue-600 mt-1">Numbers grab attention and add credibility</p>
            </button>

            <button class="w-full text-left p-3 bg-green-50 rounded-lg hover:bg-green-100 transition-colors">
              <p class="text-sm font-medium text-green-900">Include a real-world example</p>
              <p class="text-xs text-green-600 mt-1">Stories make your points more relatable</p>
            </button>

            <button class="w-full text-left p-3 bg-purple-50 rounded-lg hover:bg-purple-100 transition-colors">
              <p class="text-sm font-medium text-purple-900">Ask a thought-provoking question</p>
              <p class="text-xs text-purple-600 mt-1">Questions engage readers and encourage reflection</p>
            </button>
          </div>
        </div>

        <!-- Writing Tone -->
        <div>
          <h4 class="text-sm font-medium text-gray-700 mb-2">Adjust tone:</h4>
          <div class="flex flex-wrap gap-2">
            <button class="px-3 py-1 bg-gray-100 text-gray-700 rounded-full text-sm hover:bg-gray-200">
              More casual
            </button>
            <button class="px-3 py-1 bg-gray-100 text-gray-700 rounded-full text-sm hover:bg-gray-200">
              More formal
            </button>
            <button class="px-3 py-1 bg-gray-100 text-gray-700 rounded-full text-sm hover:bg-gray-200">
              More persuasive
            </button>
          </div>
        </div>

        <!-- Quick Actions -->
        <div>
          <h4 class="text-sm font-medium text-gray-700 mb-2">Quick actions:</h4>
          <div class="space-y-2">
            <button class="w-full flex items-center space-x-2 p-2 text-left hover:bg-gray-50 rounded">
              <span>🔍</span>
              <span class="text-sm">Check for grammar</span>
            </button>
            <button class="w-full flex items-center space-x-2 p-2 text-left hover:bg-gray-50 rounded">
              <span>📊</span>
              <span class="text-sm">Analyze readability</span>
            </button>
            <button class="w-full flex items-center space-x-2 p-2 text-left hover:bg-gray-50 rounded">
              <span>🎯</span>
              <span class="text-sm">SEO suggestions</span>
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Event Handlers
  @impl true
  def handle_event("update_document_title", %{"value" => title}, socket) do
    document = socket.assigns.document

    case Content.update_document(document, %{title: title}, socket.assigns.current_user) do
      {:ok, updated_document} ->
        # Broadcast title update to collaborators
        Phoenix.PubSub.broadcast(
          Frestyl.PubSub,
          "document:#{document.id}",
          {:title_updated, title, socket.assigns.current_user.id}
        )

        {:noreply, assign(socket, :document, updated_document)}

      {:error, _changeset} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("update_block_content", %{"value" => content, "block-id" => block_id}, socket) do
    document = socket.assigns.document

    operation = %{
      type: "update_content",
      block_id: block_id,
      content: content,
      user_id: socket.assigns.current_user.id,
      timestamp: System.system_time(:millisecond)
    }

    case Content.update_document_content(document.id, [operation], socket.assigns.current_user) do
      {:ok, updated_blocks} ->
        # Update local state
        updated_document = %{document | blocks: updated_blocks}

        {:noreply, assign(socket, :document, updated_document)}

      {:error, {:conflicts, conflicts}} ->
        # Handle conflicts - could show conflict resolution UI
        {:noreply, socket
          |> put_flash(:warning, "Content conflicts detected. Please review changes.")
          |> assign(:conflicts, conflicts)
        }

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to update content")}
    end
  end

  @impl true
  def handle_event("add_block", _params, socket) do
    document = socket.assigns.document
    position = length(socket.assigns.blocks)

    operation = %{
      type: "add_block",
      block_type: "paragraph",
      position: position,
      content: "",
      user_id: socket.assigns.current_user.id
    }

    case Content.update_document_content(document.id, [operation], socket.assigns.current_user) do
      {:ok, updated_blocks} ->
        updated_document = %{document | blocks: updated_blocks}

        {:noreply, socket
          |> assign(:document, updated_document)
          |> assign(:blocks, updated_blocks)
          |> assign(:active_block, List.last(updated_blocks).id)
        }

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to add block")}
    end
  end

  @impl true
  def handle_event("activate_block", %{"block-id" => block_id}, socket) do
    {:noreply, assign(socket, :active_block, block_id)}
  end

  @impl true
  def handle_event("add_media_to_block", %{"block-id" => block_id}, socket) do
    {:noreply, socket
      |> assign(:media_picker_open, true)
      |> assign(:active_block, block_id)
    }
  end

  @impl true
  def handle_event("close_media_picker", _params, socket) do
    {:noreply, assign(socket, :media_picker_open, false)}
  end

  @impl true
  def handle_event("toggle_voice_recording", _params, socket) do
    new_recording_state = !socket.assigns.voice_recording

    if new_recording_state do
      # Start voice recording
      {:noreply, socket
        |> assign(:voice_recording, true)
        |> push_event("start_voice_recording", %{})
      }
    else
      # Stop voice recording
      {:noreply, socket
        |> assign(:voice_recording, false)
        |> push_event("stop_voice_recording", %{})
      }
    end
  end

  @impl true
  def handle_event("toggle_ai_suggestions", _params, socket) do
    {:noreply, assign(socket, :suggestions_visible, !socket.assigns.suggestions_visible)}
  end

  @impl true
  def handle_event("toggle_mobile_toolbar", _params, socket) do
    {:noreply, assign(socket, :toolbar_visible, !socket.assigns.toolbar_visible)}
  end

  # Helper Functions
  defp get_document_config(document_type) do
    Content.get_document_type_config(document_type)
  end

  defp format_document_type(document_type) do
    document_type
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp calculate_word_count(blocks) do
    blocks
    |> Enum.map(& &1.content)
    |> Enum.join(" ")
    |> String.split()
    |> length()
  end

  defp calculate_reading_time(blocks) do
    word_count = calculate_word_count(blocks)
    # Average reading speed: 200 words per minute
    max(1, round(word_count / 200))
  end

  defp calculate_completion_percentage(blocks, document_config) do
    filled_blocks = Enum.count(blocks, fn block ->
      String.trim(block.content) != ""
    end)

    total_suggested = length(document_config.default_blocks || [])

    if total_suggested > 0 do
      round((filled_blocks / total_suggested) * 100)
    else
      0
    end
  end

  defp get_next_suggested_step(blocks, document_config) do
    # Find the first empty or incomplete block
    case Enum.find(document_config.default_blocks || [], fn suggested_block ->
      not Enum.any?(blocks, fn actual_block ->
        actual_block.block_type == suggested_block.type and
        String.trim(actual_block.content) != ""
      end)
    end) do
      nil -> nil
      next_block -> %{
        title: format_block_title(next_block.type),
        description: next_block[:placeholder] || "Complete this section"
      }
    end
  end

  defp show_guidance?(document_config) do
    document_config && document_config[:workflow] != :free_form
  end

  defp get_block_guidance(block, document_config) do
    # Return contextual writing guidance for specific block types
    guidance_map = document_config[:block_guidance] || %{}
    guidance_map[block.block_type]
  end

  defp format_block_title(block_type) do
    block_type
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp get_collaborative_cursors(document_id) do
    # Get real-time cursor positions from other users
    # This would integrate with Phoenix Presence
    %{}
  end

  defp get_user_name(user_id) do
    # Lookup user name from cache or database
    "User #{String.slice(user_id, 0, 8)}"
  end

  defp get_media_url(media_file_id) do
    # Generate URL for media file
    "/media/#{media_file_id}"
  end

  defp get_video_thumbnail(media_file_id) do
    # Generate thumbnail URL for video
    "/media/#{media_file_id}/thumbnail"
  end

  defp format_duration(seconds) when is_integer(seconds) do
    minutes = div(seconds, 60)
    secs = rem(seconds, 60)
    "#{minutes}:#{String.pad_leading(to_string(secs), 2, "0")}"
  end

  defp format_duration(_), do: "0:00"

  defp truncate(text, length) when is_binary(text) do
    if String.length(text) <= length do
      text
    else
      String.slice(text, 0, length)
    end
  end

  defp truncate(_, _), do: ""
end
