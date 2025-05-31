# lib/frestyl_web/live/components/cipher_canvas_component.ex
defmodule FrestylWeb.CipherCanvasComponent do
  use FrestylWeb, :live_component
  alias Frestyl.Media

  @impl true
  def render(assigns) do
    ~H"""
    <div class="cipher-canvas-container" phx-hook="CipherCanvas" id="cipher-canvas">
      <!-- Ethereal Background -->
      <div class="ethereal-bg"></div>

      <!-- Canvas Container -->
      <div class="cipher-canvas" id="cipherCanvas" data-files={Jason.encode!(serialize_media_files(@media_files))}>
        <!-- Media nodes will be dynamically generated -->
      </div>

      <!-- UI Overlay -->
      <div class="ui-overlay">
        <div class="control-panel">
          <div class="mode-selector">
            <button class="mode-btn active" data-mode="galaxy">🌌 Galaxy View</button>
            <button class="mode-btn" data-mode="constellation">⭐ Constellation</button>
            <button class="mode-btn" data-mode="flow">🌊 Energy Flow</button>
            <button class="mode-btn" data-mode="neural">🧠 Neural Web</button>
          </div>
          <div class="stats-display">
            <span class="file-count"><%= length(@media_files) %></span> media files •
            <span class="total-size"><%= format_total_size(@media_files) %></span>
          </div>
        </div>
      </div>

      <!-- Info Panel -->
      <div class="info-panel" id="infoPanel">
        <h3 id="fileName"></h3>
        <p id="fileDetails"></p>
        <div class="action-buttons">
          <button class="action-btn" id="downloadBtn">📥 Download</button>
          <button class="action-btn" id="shareBtn">🔗 Share</button>
          <button class="action-btn" id="editBtn">✏️ Edit</button>
        </div>
      </div>

      <!-- Audio Visualizer -->
      <div class="audio-visualizer" id="audioVisualizer">
        <!-- Visualizer bars will be generated -->
      </div>

      <!-- Upload Zone -->
      <div class="upload-zone" id="uploadZone" phx-drop-target={@upload_ref || ""}>
        <div class="upload-content">
          <div class="upload-icon">☁️</div>
          <h3>Drop files into the cosmos</h3>
          <p>Audio, images, videos, and documents</p>
          <button type="button" class="browse-btn" phx-click="open_upload_modal">
            Browse Files
          </button>
        </div>
      </div>

      <!-- Embedded Styles -->
      <style>
        .cipher-canvas-container {
          position: relative;
          width: 100%;
          height: 100vh;
          overflow: hidden;
          background: linear-gradient(135deg, #0a0a0a 0%, #1a1a2e 25%, #16213e 50%, #0f3460 75%, #533483 100%);
        }

        /* Ethereal Background */
        .ethereal-bg {
          position: absolute;
          top: 0;
          left: 0;
          width: 100%;
          height: 100%;
          background:
            radial-gradient(circle at 20% 30%, rgba(168, 85, 247, 0.2) 0%, transparent 50%),
            radial-gradient(circle at 70% 20%, rgba(59, 130, 246, 0.15) 0%, transparent 50%),
            radial-gradient(circle at 50% 80%, rgba(139, 92, 246, 0.1) 0%, transparent 50%),
            radial-gradient(circle at 80% 70%, rgba(99, 102, 241, 0.08) 0%, transparent 50%);
          animation: etherealFloat 20s ease-in-out infinite;
        }

        @keyframes etherealFloat {
          0%, 100% { transform: translateY(0px) rotate(0deg); opacity: 0.8; }
          25% { transform: translateY(-20px) rotate(1deg); opacity: 1; }
          50% { transform: translateY(0px) rotate(-1deg); opacity: 0.9; }
          75% { transform: translateY(10px) rotate(0.5deg); opacity: 1; }
        }

        /* Canvas */
        .cipher-canvas {
          position: absolute;
          top: 0;
          left: 0;
          width: 100%;
          height: 100%;
          cursor: grab;
          transition: filter 0.3s ease;
        }

        .cipher-canvas:active {
          cursor: grabbing;
        }

        /* Media Nodes */
        .media-node {
          position: absolute;
          transform-origin: center;
          cursor: pointer;
          transition: all 0.4s cubic-bezier(0.175, 0.885, 0.32, 1.275);
          z-index: 1;
        }

        .media-node:hover {
          z-index: 10;
        }

        .node-inner {
          position: relative;
          width: 100%;
          height: 100%;
          border-radius: 50%;
          overflow: hidden;
          box-shadow:
            0 0 30px rgba(168, 85, 247, 0.4),
            inset 0 0 20px rgba(255, 255, 255, 0.1);
          transition: all 0.4s ease;
          display: flex;
          align-items: center;
          justify-content: center;
        }

        .media-node:hover .node-inner {
          transform: scale(1.2);
          box-shadow:
            0 0 60px rgba(168, 85, 247, 0.8),
            0 0 100px rgba(168, 85, 247, 0.4),
            inset 0 0 30px rgba(255, 255, 255, 0.2);
        }

        /* Media Type Styles */
        .audio-node .node-inner {
          background: linear-gradient(135deg, #ff6b6b, #feca57, #48cae4);
          animation: audioPulse 2s ease-in-out infinite;
        }

        @keyframes audioPulse {
          0%, 100% { transform: scale(1); }
          50% { transform: scale(1.05); }
        }

        .image-node .node-inner {
          background: linear-gradient(135deg, #a8e6cf, #88d8c0, #78c2ad);
        }

        .video-node .node-inner {
          background: linear-gradient(135deg, #ff8a80, #ff7043, #ff5722);
          animation: videoShimmer 3s ease-in-out infinite;
        }

        @keyframes videoShimmer {
          0%, 100% { background-position: 0% 50%; }
          50% { background-position: 100% 50%; }
        }

        .document-node .node-inner {
          background: linear-gradient(135deg, #b39ddb, #9575cd, #7e57c2);
        }

        /* Audio Ring */
        .audio-ring {
          position: absolute;
          top: -10px;
          left: -10px;
          right: -10px;
          bottom: -10px;
          border: 2px solid rgba(255, 107, 107, 0.6);
          border-radius: 50%;
          opacity: 0;
          transform: scale(0.8);
          transition: all 0.3s ease;
        }

        .audio-node.playing .audio-ring {
          opacity: 1;
          transform: scale(1.2);
          animation: audioRing 1s ease-in-out infinite;
        }

        @keyframes audioRing {
          0%, 100% { transform: scale(1.2); opacity: 0.6; }
          50% { transform: scale(1.4); opacity: 0.3; }
        }

        /* Preview Images */
        .media-preview {
          position: absolute;
          width: 100%;
          height: 100%;
          object-fit: cover;
          border-radius: 50%;
        }

        /* File Type Indicator */
        .file-type-indicator {
          position: absolute;
          top: 50%;
          left: 50%;
          transform: translate(-50%, -50%);
          color: white;
          font-size: 12px;
          font-weight: bold;
          text-shadow: 0 2px 4px rgba(0,0,0,0.5);
          pointer-events: none;
          z-index: 2;
        }

        /* UI Overlay */
        .ui-overlay {
          position: absolute;
          top: 20px;
          left: 20px;
          right: 20px;
          z-index: 100;
          pointer-events: none;
        }

        .control-panel {
          background: rgba(255, 255, 255, 0.1);
          backdrop-filter: blur(20px);
          border: 1px solid rgba(255, 255, 255, 0.2);
          border-radius: 20px;
          padding: 20px;
          display: flex;
          justify-content: space-between;
          align-items: center;
          pointer-events: auto;
        }

        .mode-selector {
          display: flex;
          gap: 15px;
        }

        .mode-btn {
          padding: 10px 20px;
          background: rgba(255, 255, 255, 0.1);
          border: 1px solid rgba(255, 255, 255, 0.3);
          border-radius: 12px;
          color: white;
          cursor: pointer;
          transition: all 0.3s ease;
          backdrop-filter: blur(10px);
          font-size: 14px;
        }

        .mode-btn:hover, .mode-btn.active {
          background: rgba(168, 85, 247, 0.3);
          border-color: rgba(168, 85, 247, 0.6);
          box-shadow: 0 0 20px rgba(168, 85, 247, 0.4);
        }

        .stats-display {
          color: white;
          font-size: 14px;
          font-weight: 500;
        }

        /* Info Panel */
        .info-panel {
          position: absolute;
          bottom: 20px;
          left: 20px;
          right: 20px;
          background: rgba(0, 0, 0, 0.3);
          backdrop-filter: blur(20px);
          border: 1px solid rgba(255, 255, 255, 0.2);
          border-radius: 15px;
          padding: 20px;
          color: white;
          opacity: 0;
          transform: translateY(20px);
          transition: all 0.3s ease;
          pointer-events: none;
        }

        .info-panel.visible {
          opacity: 1;
          transform: translateY(0);
          pointer-events: auto;
        }

        .action-buttons {
          display: flex;
          gap: 10px;
          margin-top: 15px;
        }

        .action-btn {
          padding: 8px 16px;
          background: rgba(168, 85, 247, 0.2);
          border: 1px solid rgba(168, 85, 247, 0.4);
          border-radius: 8px;
          color: white;
          cursor: pointer;
          transition: all 0.3s ease;
          font-size: 12px;
        }

        .action-btn:hover {
          background: rgba(168, 85, 247, 0.4);
          box-shadow: 0 0 15px rgba(168, 85, 247, 0.3);
        }

        /* Audio Visualizer */
        .audio-visualizer {
          position: absolute;
          bottom: 20px;
          left: 50%;
          transform: translateX(-50%);
          width: 300px;
          height: 60px;
          background: rgba(0, 0, 0, 0.3);
          backdrop-filter: blur(20px);
          border-radius: 30px;
          border: 1px solid rgba(255, 255, 255, 0.2);
          display: none;
          align-items: center;
          justify-content: center;
          gap: 2px;
          padding: 10px;
        }

        .visualizer-bar {
          width: 3px;
          background: linear-gradient(to top, #ff6b6b, #feca57, #48cae4);
          border-radius: 2px;
          transition: height 0.1s ease;
        }

        /* Upload Zone */
        .upload-zone {
          position: absolute;
          top: 50%;
          left: 50%;
          transform: translate(-50%, -50%);
          width: 300px;
          height: 200px;
          background: rgba(255, 255, 255, 0.05);
          backdrop-filter: blur(20px);
          border: 2px dashed rgba(255, 255, 255, 0.3);
          border-radius: 20px;
          display: none;
          align-items: center;
          justify-content: center;
          transition: all 0.3s ease;
          z-index: 50;
        }

        .upload-zone.dragover {
          display: flex;
          border-color: rgba(168, 85, 247, 0.6);
          background: rgba(168, 85, 247, 0.1);
          box-shadow: 0 0 30px rgba(168, 85, 247, 0.3);
        }

        .upload-content {
          text-align: center;
          color: white;
        }

        .upload-icon {
          font-size: 48px;
          margin-bottom: 15px;
        }

        .browse-btn {
          margin-top: 15px;
          padding: 10px 20px;
          background: rgba(168, 85, 247, 0.3);
          border: 1px solid rgba(168, 85, 247, 0.6);
          border-radius: 10px;
          color: white;
          cursor: pointer;
          transition: all 0.3s ease;
        }

        .browse-btn:hover {
          background: rgba(168, 85, 247, 0.5);
          box-shadow: 0 0 20px rgba(168, 85, 247, 0.4);
        }

        /* Floating Particles */
        .particle {
          position: absolute;
          background: radial-gradient(circle, rgba(255,255,255,0.8) 0%, rgba(168,85,247,0.4) 100%);
          border-radius: 50%;
          pointer-events: none;
          animation: float linear infinite;
        }

        @keyframes float {
          from {
            transform: translateY(100vh) rotate(0deg);
            opacity: 0;
          }
          10% {
            opacity: 1;
          }
          90% {
            opacity: 1;
          }
          to {
            transform: translateY(-10vh) rotate(360deg);
            opacity: 0;
          }
        }

        /* Responsive */
        @media (max-width: 768px) {
          .control-panel {
            flex-direction: column;
            gap: 15px;
          }

          .mode-selector {
            flex-wrap: wrap;
            justify-content: center;
            gap: 10px;
          }

          .mode-btn {
            padding: 8px 16px;
            font-size: 12px;
          }

          .audio-visualizer {
            width: 250px;
            height: 50px;
          }

          .upload-zone {
            width: 90%;
            height: 150px;
          }
        }
      </style>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def handle_event("open_upload_modal", _params, socket) do
    send(self(), {:open_upload_modal})
    {:noreply, socket}
  end

  defp format_total_size(media_files) do
    total_bytes = Enum.reduce(media_files, 0, fn file, acc ->
      acc + (file.file_size || 0)
    end)

    cond do
      total_bytes >= 1_000_000_000 -> "#{Float.round(total_bytes / 1_000_000_000, 1)} GB"
      total_bytes >= 1_000_000 -> "#{Float.round(total_bytes / 1_000_000, 1)} MB"
      total_bytes >= 1_000 -> "#{Float.round(total_bytes / 1_000, 1)} KB"
      true -> "#{total_bytes} B"
    end
  end

  defp serialize_media_files(media_files) do
    Enum.map(media_files, fn file ->
      %{
        id: file.id,
        filename: file.filename,
        content_type: file.content_type || "application/octet-stream",
        file_size: file.file_size || 0,
        file_path: get_public_file_path(file.file_path),
        title: file.title || file.filename,
        description: file.description,
        duration: file.duration,
        width: file.width,
        height: file.height,
        thumbnail_url: file.thumbnail_url,
        inserted_at: file.inserted_at
      }
    end)
  end

  defp get_public_file_path(file_path) when is_binary(file_path) do
    cond do
      String.starts_with?(file_path, "/uploads/") -> file_path
      String.starts_with?(file_path, "priv/static/uploads/") ->
        String.replace_prefix(file_path, "priv/static", "")
      String.starts_with?(file_path, "priv/static") ->
        String.replace_prefix(file_path, "priv/static", "")
      String.contains?(file_path, "uploads/") ->
        "/uploads/" <> Path.basename(file_path)
      true ->
        "/uploads/" <> Path.basename(file_path)
    end
  end

  defp get_public_file_path(_), do: nil
end
