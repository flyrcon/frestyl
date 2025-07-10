// assets/js/video_player_hook.js
// Add this to your existing portfolio_editor_hooks.js or create a new file

export const VideoPlayer = {
  mounted() {
    console.log("🎥 VideoPlayer hook mounted");
    this.setupVideoPlayers();
    this.setupVideoEvents();
  },

  updated() {
    this.setupVideoPlayers();
  },

  setupVideoPlayers() {
    // Setup click handlers for video thumbnails
    const videoThumbnails = this.el.querySelectorAll('.video-thumbnail');
    
    videoThumbnails.forEach(thumbnail => {
      thumbnail.addEventListener('click', (e) => {
        e.preventDefault();
        this.playVideo(thumbnail);
      });
    });
  },

  setupVideoEvents() {
    // Listen for video events from the server
    this.handleEvent("play_video", ({ block_id, video_url }) => {
      this.playVideoById(block_id, video_url);
    });

    this.handleEvent("pause_video", ({ block_id }) => {
      this.pauseVideoById(block_id);
    });
  },

  playVideo(thumbnailElement) {
    const videoUrl = thumbnailElement.dataset.videoUrl;
    const embedUrl = thumbnailElement.dataset.embedUrl;
    const blockId = thumbnailElement.closest('[data-block-id]')?.dataset.blockId;

    if (!blockId) return;

    if (embedUrl) {
      // External video (YouTube/Vimeo)
      this.replaceWithIframe(thumbnailElement, embedUrl, blockId);
    } else if (videoUrl) {
      // Uploaded video
      this.replaceWithVideoElement(thumbnailElement, videoUrl, blockId);
    }
  },

  playVideoById(blockId, videoUrl) {
    const blockElement = this.el.querySelector(`[data-block-id="${blockId}"]`);
    if (!blockElement) return;

    const thumbnail = blockElement.querySelector('.video-thumbnail');
    if (thumbnail) {
      this.playVideo(thumbnail);
    }
  },

  pauseVideoById(blockId) {
    const blockElement = this.el.querySelector(`[data-block-id="${blockId}"]`);
    if (!blockElement) return;

    // Find and pause any active video
    const video = blockElement.querySelector('video');
    const iframe = blockElement.querySelector('iframe');

    if (video) {
      video.pause();
    } else if (iframe) {
      // For external videos, we need to reload to stop
      const thumbnailHtml = this.createThumbnailFromIframe(iframe);
      iframe.parentNode.innerHTML = thumbnailHtml;
      this.setupVideoPlayers(); // Re-setup click handlers
    }
  },

  replaceWithIframe(thumbnailElement, embedUrl, blockId) {
    const container = thumbnailElement.parentNode;
    
    // Create iframe
    const iframe = document.createElement('iframe');
    iframe.id = `video-player-${blockId}`;
    iframe.src = embedUrl;
    iframe.className = 'w-full h-full';
    iframe.setAttribute('frameborder', '0');
    iframe.setAttribute('allow', 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture');
    iframe.setAttribute('allowfullscreen', '');

    // Replace thumbnail with iframe
    container.innerHTML = '';
    container.appendChild(iframe);

    // Add close button
    this.addCloseButton(container, blockId);
  },

  replaceWithVideoElement(thumbnailElement, videoUrl, blockId) {
    const container = thumbnailElement.parentNode;
    
    // Create video element
    const video = document.createElement('video');
    video.id = `video-player-${blockId}`;
    video.className = 'w-full h-full object-cover';
    video.controls = true;
    video.autoplay = true;
    video.src = videoUrl;

    // Replace thumbnail with video
    container.innerHTML = '';
    container.appendChild(video);

    // Add close button
    this.addCloseButton(container, blockId);

    // Auto-play
    video.play().catch(e => {
      console.log("Auto-play prevented:", e);
    });
  },

  addCloseButton(container, blockId) {
    const closeButton = document.createElement('button');
    closeButton.className = 'absolute top-4 right-4 z-10 bg-black bg-opacity-75 text-white p-2 rounded-full hover:bg-opacity-100 transition-opacity';
    closeButton.innerHTML = `
      <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
      </svg>
    `;
    
    closeButton.addEventListener('click', (e) => {
      e.stopPropagation();
      this.closeVideo(container, blockId);
    });

    container.style.position = 'relative';
    container.appendChild(closeButton);
  },

  closeVideo(container, blockId) {
    // Send pause event to LiveView
    this.pushEvent("pause_video", { block_id: blockId });
  },

  createThumbnailFromIframe(iframe) {
    // This would recreate the thumbnail HTML
    // For now, just reload the page section
    return `
      <div class="video-thumbnail relative w-full h-full cursor-pointer bg-gray-900 flex items-center justify-center">
        <div class="text-center text-white">
          <svg class="w-16 h-16 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
          </svg>
          <p>Click to play video</p>
        </div>
      </div>
    `;
  }
};

// Add to your existing hooks object in app.js:
// Hooks.VideoPlayer = VideoPlayer;