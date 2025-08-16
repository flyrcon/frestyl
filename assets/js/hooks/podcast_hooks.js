import { AudioEngine } from '../audio/audio_engine.js';
import { WebRTCClient } from '../webrtc/webrtc_client.js';

// Podcast Studio Hook
const PodcastStudio = {
  mounted() {
    this.studioMode = this.el.dataset.mode || 'overview';
    this.showId = this.el.dataset.showId;
    this.episodeId = this.el.dataset.episodeId;
    
    this.setupStudioInterface();
    this.initializeFeatures();
  },

  setupStudioInterface() {
    // Set up mode-specific interfaces
    switch (this.studioMode) {
      case 'recording':
        this.initializeRecordingInterface();
        break;
      case 'editing':
        this.initializeEditingInterface();
        break;
      case 'publishing':
        this.initializePublishingInterface();
        break;
    }
  },

  initializeRecordingInterface() {
    // Initialize podcast recording with specialized audio settings
    this.audioEngine = new AudioEngine({
      sessionId: this.episodeId,
      preset: 'podcast',
      enableNoiseReduction: true,
      enableAutoGain: true,
      maxTracks: 4 // Host, guest, intro, background
    });

    // Set up guest management
    this.setupGuestManagement();
  },

  initializeEditingInterface() {
    // Initialize timeline editor for podcast
    this.setupTimelineEditor();
    this.loadPodcastPresets();
  },

  setupGuestManagement() {
    // Handle guest invitations and connections
    this.handleEvent('guest_invited', (guest) => {
      this.addGuestToInterface(guest);
    });

    this.handleEvent('guest_joined', (guest) => {
      this.handleGuestJoined(guest);
    });
  },

  addGuestToInterface(guest) {
    // Add guest to UI
    const guestElement = this.createGuestElement(guest);
    this.el.querySelector('.guest-list').appendChild(guestElement);
  },

  handleGuestJoined(guest) {
    // Handle guest joining the recording session
    this.updateGuestStatus(guest.id, 'connected');
    
    // Add guest audio track
    if (this.audioEngine) {
      this.audioEngine.addGuestTrack(guest.id, guest.name);
    }
  },

  createGuestElement(guest) {
    const div = document.createElement('div');
    div.className = 'guest-item p-3 bg-gray-700 rounded mb-2';
    div.dataset.guestId = guest.id;
    
    div.innerHTML = `
      <div class="flex items-center justify-between">
        <div class="flex items-center space-x-2">
          <div class="w-8 h-8 bg-gray-600 rounded-full flex items-center justify-center">
            <span class="text-xs font-medium">${guest.name.charAt(0)}</span>
          </div>
          <span class="text-sm">${guest.name}</span>
        </div>
        <span class="guest-status text-xs px-2 py-1 rounded ${this.getStatusClass(guest.status)}">
          ${guest.status}
        </span>
      </div>
    `;
    
    return div;
  },

  getStatusClass(status) {
    const classes = {
      'invited': 'bg-yellow-600',
      'confirmed': 'bg-green-600',
      'connected': 'bg-blue-600',
      'declined': 'bg-red-600'
    };
    return classes[status] || 'bg-gray-600';
  },

  updateGuestStatus(guestId, status) {
    const guestElement = this.el.querySelector(`[data-guest-id="${guestId}"]`);
    if (guestElement) {
      const statusElement = guestElement.querySelector('.guest-status');
      statusElement.textContent = status;
      statusElement.className = `guest-status text-xs px-2 py-1 rounded ${this.getStatusClass(status)}`;
    }
  }
};

// Podcast Timeline Editor Hook
const PodcastTimelineEditor = {
  mounted() {
    this.projectId = this.el.dataset.projectId;
    this.episodeId = this.el.dataset.episodeId;
    
    this.initializeTimeline();
    this.loadPodcastTracks();
    this.setupKeyboardShortcuts();
  },

  initializeTimeline() {
    // Set up timeline canvas
    this.canvas = this.el.querySelector('canvas');
    this.ctx = this.canvas.getContext('2d');
    
    this.timelineData = {
      duration: 0,
      tracks: [],
      playhead: 0,
      zoom: 1.0,
      selectedClips: []
    };
    
    this.setupTimelineEvents();
    this.renderTimeline();
  },

  loadPodcastTracks() {
    // Load podcast-specific tracks
    this.pushEvent('load_podcast_tracks', {
      episodeId: this.episodeId
    });
  },

  setupTimelineEvents() {
    // Mouse events for timeline interaction
    this.canvas.addEventListener('mousedown', (e) => this.handleMouseDown(e));
    this.canvas.addEventListener('mousemove', (e) => this.handleMouseMove(e));
    this.canvas.addEventListener('mouseup', (e) => this.handleMouseUp(e));
    this.canvas.addEventListener('wheel', (e) => this.handleWheel(e));
  },

  setupKeyboardShortcuts() {
    document.addEventListener('keydown', (e) => {
      if (e.target.closest('.timeline-editor')) {
        switch (e.key) {
          case ' ': // Spacebar - play/pause
            e.preventDefault();
            this.togglePlayback();
            break;
          case 'i': // Set in point
            this.setInPoint();
            break;
          case 'o': // Set out point
            this.setOutPoint();
            break;
          case 'Delete':
          case 'Backspace':
            this.deleteSelectedClips();
            break;
        }
      }
    });
  },

  handleMouseDown(e) {
    const rect = this.canvas.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    
    // Check if clicking on a clip
    const clip = this.getClipAtPosition(x, y);
    if (clip) {
      this.selectClip(clip);
      this.dragData = {
        dragging: true,
        clip: clip,
        startX: x,
        startY: y
      };
    } else {
      // Move playhead
      this.setPlayheadPosition(x);
    }
  },

  renderTimeline() {
    // Clear canvas
    this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
    
    // Draw timeline background
    this.drawTimelineBackground();
    
    // Draw tracks
    this.timelineData.tracks.forEach((track, index) => {
      this.drawTrack(track, index);
    });
    
    // Draw playhead
    this.drawPlayhead();
    
    // Draw selection
    this.drawSelection();
  },

  drawTrack(track, index) {
    const trackHeight = 60;
    const trackY = index * trackHeight;
    
    // Draw track background
    this.ctx.fillStyle = '#374151';
    this.ctx.fillRect(0, trackY, this.canvas.width, trackHeight - 1);
    
    // Draw track clips
    track.clips.forEach(clip => {
      this.drawClip(clip, trackY);
    });
    
    // Draw track label
    this.ctx.fillStyle = '#D1D5DB';
    this.ctx.font = '12px Inter';
    this.ctx.fillText(track.name, 10, trackY + 20);
  },

  drawClip(clip, trackY) {
    const clipX = this.timeToPixels(clip.startTime);
    const clipWidth = this.timeToPixels(clip.duration);
    const clipHeight = 50;
    
    // Draw clip background
    this.ctx.fillStyle = clip.selected ? '#3B82F6' : '#6B7280';
    this.ctx.fillRect(clipX, trackY + 5, clipWidth, clipHeight);
    
    // Draw clip waveform (if audio)
    if (clip.type === 'audio' && clip.waveform) {
      this.drawWaveform(clip.waveform, clipX, trackY + 5, clipWidth, clipHeight);
    }
    
    // Draw clip name
    this.ctx.fillStyle = '#FFFFFF';
    this.ctx.font = '10px Inter';
    this.ctx.fillText(clip.name, clipX + 5, trackY + 25);
  },

  timeToPixels(timeInSeconds) {
    return timeInSeconds * this.timelineData.zoom * 50; // 50 pixels per second at 1x zoom
  },

  pixelsToTime(pixels) {
    return pixels / (this.timelineData.zoom * 50);
  }
};

// Export hooks
export {
  PodcastStudio,
  PodcastTimelineEditor
}; 