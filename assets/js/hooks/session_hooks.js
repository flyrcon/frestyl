// assets/js/hooks/session_hooks.js
import { AudioEngine } from '../audio/audio_engine.js';
import { WebRTCClient } from '../webrtc/webrtc_client.js';
import { CollaborationEngine } from '../collaboration/collaboration_engine.js';

// Session Timer Hook
const SessionTimer = {
  mounted() {
    this.startTime = new Date(this.el.dataset.started);
    this.updateTimer();
    this.timer = setInterval(() => this.updateTimer(), 1000);
  },

  destroyed() {
    if (this.timer) {
      clearInterval(this.timer);
    }
  },

  updateTimer() {
    const now = new Date();
    const elapsed = Math.floor((now - this.startTime) / 1000);
    
    const hours = Math.floor(elapsed / 3600);
    const minutes = Math.floor((elapsed % 3600) / 60);
    const seconds = elapsed % 60;
    
    const timeString = hours > 0 
      ? `${this.padZero(hours)}:${this.padZero(minutes)}:${this.padZero(seconds)}`
      : `${this.padZero(minutes)}:${this.padZero(seconds)}`;
    
    this.el.textContent = timeString;
  },

  padZero(num) {
    return num.toString().padStart(2, '0');
  }
};

// Video Stream Hook
const VideoStream = {
  mounted() {
    this.streamId = this.el.dataset.streamId;
    this.video = this.el.querySelector('video');
    this.loadingElement = this.el.querySelector('[data-loading]');
    
    this.initializeStream();
  },

  destroyed() {
    this.cleanup();
  },

  async initializeStream() {
    try {
      // Initialize WebRTC connection for the stream
      this.webrtcClient = new WebRTCClient({
        sessionId: this.streamId,
        isHost: false,
        onStream: (stream) => this.handleIncomingStream(stream),
        onError: (error) => this.handleStreamError(error)
      });

      await this.webrtcClient.connect();
      
    } catch (error) {
      console.error('Failed to initialize stream:', error);
      this.handleStreamError(error);
    }
  },

  handleIncomingStream(stream) {
    if (this.video && stream) {
      this.video.srcObject = stream;
      this.hideLoading();
    }
  },

  handleStreamError(error) {
    console.error('Stream error:', error);
    this.showError('Failed to connect to stream');
  },

  hideLoading() {
    if (this.loadingElement) {
      this.loadingElement.style.display = 'none';
    }
  },

  showError(message) {
    if (this.loadingElement) {
      this.loadingElement.innerHTML = `
        <div class="text-center">
          <div class="w-12 h-12 text-red-400 mb-2 mx-auto">⚠️</div>
          <p class="text-red-400">${message}</p>
        </div>
      `;
    }
  },

  cleanup() {
    if (this.webrtcClient) {
      this.webrtcClient.disconnect();
    }
  }
};

// Participant Video Hook
const ParticipantVideo = {
  mounted() {
    this.userId = this.el.dataset.userId;
    this.video = this.el;
    
    // Subscribe to WebRTC events for this participant
    this.handleEvent('webrtc_stream', (payload) => {
      if (payload.userId === this.userId) {
        this.handleStream(payload.stream);
      }
    });
  },

  handleStream(streamData) {
    // Handle incoming video stream from participant
    if (streamData && this.video) {
      // Convert stream data to MediaStream if needed
      const stream = this.createMediaStream(streamData);
      this.video.srcObject = stream;
    }
  },

  createMediaStream(streamData) {
    // Implementation depends on your WebRTC setup
    // This is a placeholder for the actual stream handling
    return streamData;
  }
};

// Audio Tracks Hook
const AudioTracks = {
  mounted() {
    this.sessionId = this.el.dataset.sessionId;
    this.audioEngine = null;
    
    this.initializeAudioEngine();
    this.setupEventListeners();
  },

  destroyed() {
    if (this.audioEngine) {
      this.audioEngine.destroy();
    }
  },

  async initializeAudioEngine() {
    try {
      this.audioEngine = new AudioEngine({
        sessionId: this.sessionId,
        maxTracks: 8,
        enableEffects: true
      });

      await this.audioEngine.initialize();
      
      // Set up audio engine event listeners
      this.audioEngine.on('track_added', (data) => {
        this.renderTrack(data.track);
      });

      this.audioEngine.on('track_deleted', (data) => {
        this.removeTrack(data.trackId);
      });

      this.audioEngine.on('track_updated', (data) => {
        this.updateTrack(data.trackId, data.updates);
      });

      // Load existing tracks
      this.loadExistingTracks();
      
    } catch (error) {
      console.error('Failed to initialize audio engine:', error);
    }
  },

  setupEventListeners() {
    // Handle add track button
    this.el.addEventListener('click', (e) => {
      if (e.target.matches('[phx-click="add_audio_track"]')) {
        this.addTrack();
      }
    });

    // Handle track controls
    this.el.addEventListener('click', (e) => {
      const trackId = e.target.dataset.trackId;
      
      if (e.target.matches('.track-record-btn')) {
        this.toggleRecording(trackId);
      } else if (e.target.matches('.track-mute-btn')) {
        this.toggleMute(trackId);
      } else if (e.target.matches('.track-solo-btn')) {
        this.toggleSolo(trackId);
      } else if (e.target.matches('.track-delete-btn')) {
        this.deleteTrack(trackId);
      }
    });

    // Handle volume sliders
    this.el.addEventListener('input', (e) => {
      if (e.target.matches('.track-volume-slider')) {
        const trackId = e.target.dataset.trackId;
        const volume = parseFloat(e.target.value);
        this.updateVolume(trackId, volume);
      }
    });
  },

  async addTrack() {
    if (!this.audioEngine) return;
    
    try {
      const track = await this.audioEngine.addTrack({
        name: `Track ${this.audioEngine.tracks.size + 1}`,
        inputSource: 'microphone'
      });
      
      // Track will be rendered via the 'track_added' event
      this.pushEvent('track_added', { trackId: track.id });
      
    } catch (error) {
      console.error('Failed to add track:', error);
    }
  },

  async toggleRecording(trackId) {
    if (!this.audioEngine) return;
    
    try {
      const track = this.audioEngine.tracks.get(trackId);
      if (!track) return;
      
      if (track.recording) {
        await this.audioEngine.stopRecording(trackId);
      } else {
        await this.audioEngine.startRecording(trackId);
      }
      
    } catch (error) {
      console.error('Failed to toggle recording:', error);
    }
  },

  toggleMute(trackId) {
    if (!this.audioEngine) return;
    
    const track = this.audioEngine.tracks.get(trackId);
    if (!track) return;
    
    this.audioEngine.muteTrack(trackId, !track.muted);
  },

  toggleSolo(trackId) {
    if (!this.audioEngine) return;
    
    const track = this.audioEngine.tracks.get(trackId);
    if (!track) return;
    
    this.audioEngine.soloTrack(trackId, !track.solo);
  },

  updateVolume(trackId, volume) {
    if (!this.audioEngine) return;
    
    this.audioEngine.updateTrackVolume(trackId, volume);
  },

  deleteTrack(trackId) {
    if (!this.audioEngine) return;
    
    this.audioEngine.deleteTrack(trackId);
    this.pushEvent('track_deleted', { trackId });
  },

  renderTrack(track) {
    const placeholder = this.el.querySelector('.track-placeholder');
    if (placeholder) {
      placeholder.style.display = 'none';
    }

    const trackElement = this.createTrackElement(track);
    this.el.querySelector('.tracks-container').appendChild(trackElement);
  },

  createTrackElement(track) {
    const trackDiv = document.createElement('div');
    trackDiv.className = 'audio-track bg-gray-700 rounded-lg p-4 mb-3';
    trackDiv.dataset.trackId = track.id;
    
    trackDiv.innerHTML = `
      <div class="flex items-center justify-between mb-3">
        <div class="flex items-center space-x-3">
          <input 
            type="text" 
            value="${track.name}" 
            class="track-name bg-transparent text-white font-medium focus:outline-none focus:bg-gray-600 px-2 py-1 rounded"
          />
          <div class="track-color w-4 h-4 rounded-full" style="background-color: ${track.color}"></div>
        </div>
        
        <div class="flex items-center space-x-2">
          <button class="track-record-btn p-2 rounded ${track.recording ? 'bg-red-600' : 'bg-gray-600'} hover:opacity-80 transition-opacity" data-track-id="${track.id}">
            <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
              <circle cx="10" cy="10" r="4"></circle>
            </svg>
          </button>
          
          <button class="track-mute-btn p-2 rounded ${track.muted ? 'bg-red-600' : 'bg-gray-600'} hover:opacity-80 transition-opacity" data-track-id="${track.id}">
            <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
              ${track.muted ? 
                '<path fill-rule="evenodd" d="M9.383 3.076A1 1 0 0110 4v12a1 1 0 01-1.617.776L5.464 14H2a1 1 0 01-1-1V7a1 1 0 011-1h3.464l2.919-2.776zm2.617 5.02a1 1 0 011.414 0L15 9.682l1.586-1.586a1 1 0 111.414 1.414L16.414 11.1 18 12.686a1 1 0 01-1.414 1.414L15 12.514l-1.586 1.586a1 1 0 01-1.414-1.414L13.586 11.1 12 9.514a1 1 0 010-1.414z" clip-rule="evenodd"></path>' :
                '<path fill-rule="evenodd" d="M9.383 3.076A1 1 0 0110 4v12a1 1 0 01-1.617.776L5.464 14H2a1 1 0 01-1-1V7a1 1 0 011-1h3.464l2.919-2.776zm3.293 3.338a1 1 0 011.414 0L15 7.323l.91-.909a1 1 0 111.414 1.414L16.414 8.737 17.323 9.646a1 1 0 01-1.414 1.414L15 10.151l-.909.909a1 1 0 01-1.414-1.414L13.586 8.737l-.909-.909a1 1 0 010-1.414z" clip-rule="evenodd"></path>'
              }
            </svg>
          </button>
          
          <button class="track-solo-btn p-2 rounded ${track.solo ? 'bg-yellow-600' : 'bg-gray-600'} hover:opacity-80 transition-opacity" data-track-id="${track.id}">
            <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
              <path d="M10 12a2 2 0 100-4 2 2 0 000 4z"></path>
            </svg>
          </button>
          
          <button class="track-delete-btn p-2 rounded bg-gray-600 hover:bg-red-600 transition-colors" data-track-id="${track.id}">
            <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M9 2a1 1 0 000 2h2a1 1 0 100-2H9z" clip-rule="evenodd"></path>
              <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"></path>
            </svg>
          </button>
        </div>
      </div>
      
      <div class="flex items-center space-x-4">
        <span class="text-xs text-gray-400 w-12">Volume</span>
        <input 
          type="range" 
          min="0" 
          max="1" 
          step="0.01" 
          value="${track.volume}" 
          class="track-volume-slider flex-1 h-2 bg-gray-600 rounded-lg appearance-none slider"
          data-track-id="${track.id}"
        />
        <span class="text-xs text-gray-400 w-8">${Math.round(track.volume * 100)}</span>
      </div>
      
      <div class="mt-3">
        <div class="waveform-container h-16 bg-gray-800 rounded" data-track-id="${track.id}">
          <!-- Waveform visualization will go here -->
        </div>
      </div>
    `;
    
    return trackDiv;
  },

  removeTrack(trackId) {
    const trackElement = this.el.querySelector(`[data-track-id="${trackId}"]`);
    if (trackElement) {
      trackElement.remove();
    }
    
    // Show placeholder if no tracks left
    const tracks = this.el.querySelectorAll('.audio-track');
    if (tracks.length === 0) {
      const placeholder = this.el.querySelector('.track-placeholder');
      if (placeholder) {
        placeholder.style.display = 'block';
      }
    }
  },

  updateTrack(trackId, updates) {
    const trackElement = this.el.querySelector(`[data-track-id="${trackId}"]`);
    if (!trackElement) return;
    
    // Update volume slider if changed
    if (updates.volume !== undefined) {
      const volumeSlider = trackElement.querySelector('.track-volume-slider');
      const volumeLabel = trackElement.querySelector('.text-xs.text-gray-400.w-8');
      if (volumeSlider) volumeSlider.value = updates.volume;
      if (volumeLabel) volumeLabel.textContent = Math.round(updates.volume * 100);
    }
    
    // Update button states
    if (updates.muted !== undefined) {
      const muteBtn = trackElement.querySelector('.track-mute-btn');
      muteBtn.className = `track-mute-btn p-2 rounded ${updates.muted ? 'bg-red-600' : 'bg-gray-600'} hover:opacity-80 transition-opacity`;
    }
    
    if (updates.solo !== undefined) {
      const soloBtn = trackElement.querySelector('.track-solo-btn');
      soloBtn.className = `track-solo-btn p-2 rounded ${updates.solo ? 'bg-yellow-600' : 'bg-gray-600'} hover:opacity-80 transition-opacity`;
    }
    
    if (updates.recording !== undefined) {
      const recordBtn = trackElement.querySelector('.track-record-btn');
      recordBtn.className = `track-record-btn p-2 rounded ${updates.recording ? 'bg-red-600' : 'bg-gray-600'} hover:opacity-80 transition-opacity`;
    }
  },

  loadExistingTracks() {
    // Load any existing tracks from the session
    this.pushEvent('load_audio_tracks', {});
  }
};

// Collaboration Canvas Hook
const CollaborationCanvas = {
  mounted() {
    this.sessionId = this.el.dataset.sessionId;
    this.userId = this.el.dataset.userId;
    this.canvas = this.el.querySelector('canvas');
    this.ctx = this.canvas.getContext('2d');
    
    this.setupCanvas();
    this.initializeCollaboration();
    this.setupEventListeners();
  },

  destroyed() {
    if (this.collaborationEngine) {
      this.collaborationEngine.destroy();
    }
  },

  setupCanvas() {
    // Set canvas size
    this.resizeCanvas();
    window.addEventListener('resize', () => this.resizeCanvas());
    
    // Set up drawing context
    this.ctx.lineCap = 'round';
    this.ctx.lineJoin = 'round';
    this.ctx.lineWidth = 2;
    this.ctx.strokeStyle = '#3B82F6'; // Blue color
  },

  resizeCanvas() {
    const rect = this.el.getBoundingClientRect();
    this.canvas.width = rect.width;
    this.canvas.height = rect.height;
  },

  initializeCollaboration() {
    this.collaborationEngine = new CollaborationEngine({
      sessionId: this.sessionId,
      userId: this.userId,
      onOperation: (operation) => this.handleRemoteOperation(operation),
      onCursorMove: (cursor) => this.handleRemoteCursor(cursor),
      onUserJoin: (user) => this.handleUserJoin(user),
      onUserLeave: (userId) => this.handleUserLeave(userId)
    });
  },

  setupEventListeners() {
    let isDrawing = false;
    let lastX = 0;
    let lastY = 0;

    this.canvas.addEventListener('mousedown', (e) => {
      isDrawing = true;
      [lastX, lastY] = [e.offsetX, e.offsetY];
      
      // Start a new drawing operation
      this.startDrawing(lastX, lastY);
    });

    this.canvas.addEventListener('mousemove', (e) => {
      if (!isDrawing) {
        // Send cursor position for collaboration
        this.sendCursorPosition(e.offsetX, e.offsetY);
        return;
      }
      
      // Continue drawing
      this.drawLine(lastX, lastY, e.offsetX, e.offsetY);
      this.sendDrawOperation(lastX, lastY, e.offsetX, e.offsetY);
      
      [lastX, lastY] = [e.offsetX, e.offsetY];
    });

    this.canvas.addEventListener('mouseup', () => {
      if (isDrawing) {
        isDrawing = false;
        this.endDrawing();
      }
    });

    this.canvas.addEventListener('mouseleave', () => {
      if (isDrawing) {
        isDrawing = false;
        this.endDrawing();
      }
    });

    // Touch events for mobile
    this.canvas.addEventListener('touchstart', (e) => {
      e.preventDefault();
      const touch = e.touches[0];
      const rect = this.canvas.getBoundingClientRect();
      const x = touch.clientX - rect.left;
      const y = touch.clientY - rect.top;
      
      isDrawing = true;
      [lastX, lastY] = [x, y];
      this.startDrawing(lastX, lastY);
    });

    this.canvas.addEventListener('touchmove', (e) => {
      e.preventDefault();
      if (!isDrawing) return;
      
      const touch = e.touches[0];
      const rect = this.canvas.getBoundingClientRect();
      const x = touch.clientX - rect.left;
      const y = touch.clientY - rect.top;
      
      this.drawLine(lastX, lastY, x, y);
      this.sendDrawOperation(lastX, lastY, x, y);
      
      [lastX, lastY] = [x, y];
    });

    this.canvas.addEventListener('touchend', (e) => {
      e.preventDefault();
      if (isDrawing) {
        isDrawing = false;
        this.endDrawing();
      }
    });
  },

  startDrawing(x, y) {
    this.currentStroke = {
      id: this.generateStrokeId(),
      points: [{x, y}],
      color: this.ctx.strokeStyle,
      width: this.ctx.lineWidth,
      userId: this.userId
    };
  },

  drawLine(x1, y1, x2, y2) {
    this.ctx.beginPath();
    this.ctx.moveTo(x1, y1);
    this.ctx.lineTo(x2, y2);
    this.ctx.stroke();
  },

  endDrawing() {
    if (this.currentStroke) {
      // Send the complete stroke as an operation
      this.collaborationEngine.sendOperation({
        type: 'visual',
        action: 'add_stroke',
        data: this.currentStroke
      });
      
      this.currentStroke = null;
    }
  },

  sendDrawOperation(x1, y1, x2, y2) {
    if (this.currentStroke) {
      this.currentStroke.points.push({x: x2, y: y2});
      
      // Send incremental drawing update
      this.collaborationEngine.sendOperation({
        type: 'visual',
        action: 'update_stroke',
        data: {
          strokeId: this.currentStroke.id,
          point: {x: x2, y: y2}
        }
      });
    }
  },

  sendCursorPosition(x, y) {
    this.collaborationEngine.sendCursor({
      x,
      y,
      userId: this.userId
    });
  },

  handleRemoteOperation(operation) {
    switch (operation.action) {
      case 'add_stroke':
        this.drawStroke(operation.data);
        break;
      case 'update_stroke':
        this.updateStroke(operation.data);
        break;
      case 'clear_canvas':
        this.clearCanvas();
        break;
    }
  },

  drawStroke(stroke) {
    const prevStyle = this.ctx.strokeStyle;
    const prevWidth = this.ctx.lineWidth;
    
    this.ctx.strokeStyle = stroke.color;
    this.ctx.lineWidth = stroke.width;
    
    this.ctx.beginPath();
    if (stroke.points.length > 1) {
      this.ctx.moveTo(stroke.points[0].x, stroke.points[0].y);
      for (let i = 1; i < stroke.points.length; i++) {
        this.ctx.lineTo(stroke.points[i].x, stroke.points[i].y);
      }
    }
    this.ctx.stroke();
    
    this.ctx.strokeStyle = prevStyle;
    this.ctx.lineWidth = prevWidth;
  },

  updateStroke(data) {
    // For real-time stroke updates, we'd maintain stroke state
    // and redraw incrementally. For simplicity, we'll just draw the point.
    this.ctx.beginPath();
    this.ctx.arc(data.point.x, data.point.y, 1, 0, 2 * Math.PI);
    this.ctx.fill();
  },

  handleRemoteCursor(cursor) {
    // Update cursor position in the LiveView
    this.pushEvent('update_cursor', cursor);
  },

  clearCanvas() {
    this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
  },

  generateStrokeId() {
    return Date.now().toString(36) + Math.random().toString(36).substr(2);
  }
};

// Chat Messages Hook
const ChatMessages = {
  mounted() {
    this.scrollToBottom();
    
    // Auto-scroll when new messages arrive
    this.handleEvent('new_message', () => {
      setTimeout(() => this.scrollToBottom(), 100);
    });
  },

  updated() {
    this.scrollToBottom();
  },

  scrollToBottom() {
    this.el.scrollTop = this.el.scrollHeight;
  }
};

// Shared Notes Hook (for consultation mode)
const SharedNotes = {
  mounted() {
    this.debounceTimer = null;
    
    this.el.addEventListener('input', () => {
      clearTimeout(this.debounceTimer);
      this.debounceTimer = setTimeout(() => {
        this.saveNotes();
      }, 1000); // Save after 1 second of no typing
    });
    
    // Load existing notes
    this.loadNotes();
  },

  destroyed() {
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer);
    }
  },

  saveNotes() {
    const content = this.el.value;
    this.pushEvent('save_shared_notes', { content });
  },

  loadNotes() {
    this.pushEvent('load_shared_notes', {});
  },

  handleEvent(event, payload) {
    if (event === 'notes_loaded') {
      this.el.value = payload.content || '';
    } else if (event === 'notes_updated') {
      // Update notes from other participants
      if (document.activeElement !== this.el) {
        this.el.value = payload.content || '';
      }
    }
  }
};

// Layout Selector Hook
const LayoutSelector = {
  mounted() {
    // Close dropdown when clicking outside
    document.addEventListener('click', (e) => {
      if (!this.el.contains(e.target)) {
        this.closeDropdown();
      }
    });
  },

  closeDropdown() {
    const menu = this.el.querySelector('#layout-menu');
    if (menu) {
      menu.classList.add('hidden');
      menu.classList.remove('block');
    }
  }
};

// Modal Hook
const Modal = {
  mounted() {
    // Close modal on escape key
    this.handleKeyDown = (e) => {
      if (e.key === 'Escape') {
        this.pushEvent('close_modal', {});
      }
    };
    
    document.addEventListener('keydown', this.handleKeyDown);
    
    // Prevent body scroll when modal is open
    document.body.style.overflow = 'hidden';
  },

  destroyed() {
    document.removeEventListener('keydown', this.handleKeyDown);
    document.body.style.overflow = '';
  }
};

export {
  SessionTimer,
  VideoStream,
  ParticipantVideo,
  AudioTracks,
  CollaborationCanvas,
  ChatMessages,
  SharedNotes,
  LayoutSelector,
  Modal
};