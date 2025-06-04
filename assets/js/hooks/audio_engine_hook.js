// assets/js/hooks/audio_engine_hook.js
import AudioEngine from '../audio/audio_engine.js';

export const AudioEngineHook = {
  mounted() {
    console.log('AudioEngine hook mounted');
    
    // Initialize audio engine
    this.initializeAudioEngine();
    
    // Set up LiveView event handlers
    this.setupLiveViewEvents();
    
    // Set up audio engine event handlers
    this.setupAudioEngineEvents();
    
    // Integration with existing WebRTC if available
    this.integrateWithWebRTC();
    
    // Set up periodic state sync
    this.setupStateSync();
  },

  async initializeAudioEngine() {
    try {
      // Get configuration from LiveView assigns or data attributes
      const config = {
        sampleRate: parseInt(this.el.dataset.sampleRate) || 44100,
        bufferSize: parseInt(this.el.dataset.bufferSize) || 256,
        enableEffects: this.el.dataset.enableEffects !== 'false',
        enableMonitoring: this.el.dataset.enableMonitoring !== 'false',
        maxTracks: parseInt(this.el.dataset.maxTracks) || 8,
        sessionId: this.el.dataset.sessionId,
        userId: this.el.dataset.userId
      };

      this.audioEngine = new AudioEngine(config);
      this.sessionId = config.sessionId;
      this.userId = config.userId;
      
      // Wait for initialization
      await new Promise((resolve, reject) => {
        this.audioEngine.on('initialized', resolve);
        this.audioEngine.on('error', reject);
        
        // Timeout after 5 seconds
        setTimeout(() => reject(new Error('AudioEngine initialization timeout')), 5000);
      });

      // Notify LiveView that audio engine is ready
      this.pushEvent('audio_engine_initialized', {
        state: this.audioEngine.getState(),
        capabilities: {
          webAudio: true,
          mediaDevices: !!navigator.mediaDevices,
          getUserMedia: !!(navigator.mediaDevices && navigator.mediaDevices.getUserMedia)
        }
      });
      
      console.log('AudioEngine initialized successfully');
    } catch (error) {
      console.error('Failed to initialize AudioEngine:', error);
      this.pushEvent('audio_engine_error', {
        type: 'initialization',
        message: error.message
      });
    }
  },

  setupLiveViewEvents() {
    // Track management events from server
    this.handleEvent('audio_add_track', ({ name, inputSource, volume, pan }) => {
      this.createTrack({ name, inputSource, volume, pan });
    });

    this.handleEvent('audio_delete_track', ({ trackId }) => {
      this.deleteTrack(trackId);
    });

    this.handleEvent('audio_update_track_volume', ({ trackId, volume }) => {
      this.audioEngine.setTrackVolume(trackId, volume);
    });

    this.handleEvent('audio_update_track_pan', ({ trackId, pan }) => {
      this.audioEngine.setTrackPan(trackId, pan);
    });

    this.handleEvent('audio_mute_track', ({ trackId, muted }) => {
      this.audioEngine.muteTrack(trackId, muted);
    });

    this.handleEvent('audio_solo_track', ({ trackId, solo }) => {
      this.audioEngine.soloTrack(trackId, solo);
    });

    // Recording events
    this.handleEvent('audio_start_recording', ({ trackId }) => {
      this.startRecording(trackId);
    });

    this.handleEvent('audio_stop_recording', ({ trackId }) => {
      this.stopRecording(trackId);
    });

    // Playback events
    this.handleEvent('audio_start_playback', ({ position }) => {
      this.audioEngine.startPlayback(position || 0);
    });

    this.handleEvent('audio_stop_playback', () => {
      this.audioEngine.stopPlayback();
    });

    // Effects events
    this.handleEvent('audio_add_effect', ({ trackId, effectType, params }) => {
      const effectId = this.audioEngine.addEffectToTrack(trackId, effectType, params);
      this.pushEvent('audio_effect_added', { trackId, effectId, effectType, params });
    });

    this.handleEvent('audio_remove_effect', ({ trackId, effectId }) => {
      this.audioEngine.removeEffectFromTrack(trackId, effectId);
    });

    // Master controls
    this.handleEvent('audio_set_master_volume', ({ volume }) => {
      this.audioEngine.setMasterVolume(volume);
    });

    // Collaboration events
    this.handleEvent('audio_collaborator_joined', ({ peerId, stream }) => {
      if (stream) {
        this.audioEngine.addCollaboratorAudio(peerId, stream);
      }
    });

    this.handleEvent('audio_collaborator_left', ({ peerId }) => {
      this.audioEngine.removeCollaboratorAudio(peerId);
    });

    // State sync events
    this.handleEvent('audio_sync_state', ({ serverState }) => {
      this.syncWithServerState(serverState);
    });
  },

  setupAudioEngineEvents() {
    // Track events
    this.audioEngine.on('track_created', ({ track }) => {
      this.pushEvent('audio_track_created_client', {
        trackId: track.id,
        name: track.name,
        volume: track.volume,
        pan: track.panValue,
        color: track.color
      });
    });

    this.audioEngine.on('track_volume_changed', ({ trackId, volume }) => {
      this.pushEvent('audio_track_volume_changed_client', { trackId, volume });
    });

    this.audioEngine.on('track_pan_changed', ({ trackId, pan }) => {
      this.pushEvent('audio_track_pan_changed_client', { trackId, pan });
    });

    this.audioEngine.on('track_muted', ({ trackId, muted }) => {
      this.pushEvent('audio_track_muted_client', { trackId, muted });
    });

    this.audioEngine.on('track_solo_changed', ({ trackId, solo }) => {
      this.pushEvent('audio_track_solo_changed_client', { trackId, solo });
    });

    this.audioEngine.on('track_deleted', ({ trackId }) => {
      this.pushEvent('audio_track_deleted_client', { trackId });
    });

    // Recording events
    this.audioEngine.on('recording_started', ({ trackId }) => {
      this.pushEvent('audio_recording_started_client', { trackId });
      this.updateTrackRecordingState(trackId, true);
    });

    this.audioEngine.on('recording_stopped', ({ trackId, clip }) => {
      this.pushEvent('audio_recording_stopped_client', { 
        trackId, 
        clipId: clip.id,
        duration: clip.duration,
        peaks: clip.peaks
      });
      this.updateTrackRecordingState(trackId, false);
      this.sendAudioClipToServer(trackId, clip);
    });

    // Playback events
    this.audioEngine.on('playback_started', ({ position }) => {
      this.pushEvent('audio_playback_started_client', { position });
      this.updateTransportState('playing', position);
    });

    this.audioEngine.on('playback_stopped', ({ position }) => {
      this.pushEvent('audio_playback_stopped_client', { position });
      this.updateTransportState('stopped', position);
    });

    // Level monitoring events
    this.audioEngine.on('track_level_update', ({ trackId, level }) => {
      this.updateTrackLevel(trackId, level);
    });

    this.audioEngine.on('master_level_update', ({ level }) => {
      this.updateMasterLevel(level);
    });

    // Effects events
    this.audioEngine.on('effect_added', ({ trackId, effectId, effectType, params }) => {
      this.pushEvent('audio_effect_added_client', { trackId, effectId, effectType, params });
    });

    this.audioEngine.on('effect_removed', ({ trackId, effectId }) => {
      this.pushEvent('audio_effect_removed_client', { trackId, effectId });
    });

    // Master events
    this.audioEngine.on('master_volume_changed', ({ volume }) => {
      this.pushEvent('audio_master_volume_changed_client', { volume });
    });

    // Collaboration events
    this.audioEngine.on('collaborator_joined', ({ peerId }) => {
      this.pushEvent('audio_collaborator_joined_client', { peerId });
    });

    this.audioEngine.on('collaborator_left', ({ peerId }) => {
      this.pushEvent('audio_collaborator_left_client', { peerId });
    });

    // Error events
    this.audioEngine.on('error', ({ type, error }) => {
      console.error('AudioEngine error:', type, error);
      this.pushEvent('audio_engine_error', { type, message: error.message });
    });
  },

  integrateWithWebRTC() {
    // Check if RTC client is available globally
    if (window.rtcClient) {
      console.log('Integrating AudioEngine with existing WebRTC client');
      this.audioEngine.integrateWithRTC(window.rtcClient);
    } else {
      // Wait for RTC client to be available
      const checkRTC = () => {
        if (window.rtcClient) {
          this.audioEngine.integrateWithRTC(window.rtcClient);
        } else {
          setTimeout(checkRTC, 100);
        }
      };
      setTimeout(checkRTC, 100);
    }
  },

  setupStateSync() {
    // Sync with server every 5 seconds
    this.syncInterval = setInterval(() => {
      if (this.audioEngine) {
        const state = this.audioEngine.getState();
        this.pushEvent('audio_state_sync', { 
          clientState: state,
          timestamp: Date.now()
        });
      }
    }, 5000);
  },

  // Helper methods
  async createTrack(options = {}) {
    try {
      const track = await this.audioEngine.createTrack({
        ...options,
        connectInput: options.inputSource === 'microphone'
      });
      
      // Update UI immediately
      this.addTrackToUI(track);
      
      return track;
    } catch (error) {
      console.error('Failed to create track:', error);
      this.pushEvent('audio_engine_error', {
        type: 'track_creation',
        message: error.message
      });
    }
  },

  deleteTrack(trackId) {
    try {
      this.audioEngine.deleteTrack(trackId);
      this.removeTrackFromUI(trackId);
    } catch (error) {
      console.error('Failed to delete track:', error);
    }
  },

  async startRecording(trackId) {
    try {
      await this.audioEngine.startRecording(trackId);
    } catch (error) {
      console.error('Failed to start recording:', error);
      this.pushEvent('audio_engine_error', {
        type: 'recording_start',
        message: error.message
      });
    }
  },

  stopRecording(trackId) {
    try {
      const clip = this.audioEngine.stopRecording(trackId);
      return clip;
    } catch (error) {
      console.error('Failed to stop recording:', error);
      this.pushEvent('audio_engine_error', {
        type: 'recording_stop',
        message: error.message
      });
    }
  },

  sendAudioClipToServer(trackId, clip) {
    // Convert audio buffer to transferable format
    const channelData = [];
    for (let i = 0; i < clip.buffer.numberOfChannels; i++) {
      channelData.push(Array.from(clip.buffer.getChannelData(i)));
    }

    this.pushEvent('audio_clip_recorded', {
      trackId,
      clipId: clip.id,
      startTime: clip.startTime,
      duration: clip.duration,
      sampleRate: clip.buffer.sampleRate,
      numberOfChannels: clip.buffer.numberOfChannels,
      channelData: channelData,
      peaks: clip.peaks
    });
  },

  syncWithServerState(serverState) {
    if (!this.audioEngine) return;

    const clientState = this.audioEngine.getState();
    
    // Sync tracks
    serverState.tracks?.forEach(serverTrack => {
      const clientTrack = clientState.tracks.find(t => t.id === serverTrack.id);
      
      if (!clientTrack) {
        // Track exists on server but not client - create it
        this.createTrack({
          name: serverTrack.name,
          volume: serverTrack.volume,
          pan: serverTrack.pan
        });
      } else {
        // Track exists on both - sync properties
        if (clientTrack.volume !== serverTrack.volume) {
          this.audioEngine.setTrackVolume(serverTrack.id, serverTrack.volume);
        }
        if (clientTrack.pan !== serverTrack.pan) {
          this.audioEngine.setTrackPan(serverTrack.id, serverTrack.pan);
        }
        if (clientTrack.muted !== serverTrack.muted) {
          this.audioEngine.muteTrack(serverTrack.id, serverTrack.muted);
        }
        if (clientTrack.solo !== serverTrack.solo) {
          this.audioEngine.soloTrack(serverTrack.id, serverTrack.solo);
        }
      }
    });

    // Remove tracks that exist on client but not server
    clientState.tracks.forEach(clientTrack => {
      const serverTrack = serverState.tracks?.find(t => t.id === clientTrack.id);
      if (!serverTrack) {
        this.deleteTrack(clientTrack.id);
      }
    });
  },

  // UI update methods
  addTrackToUI(track) {
    // Find track container and add new track
    const trackContainer = document.querySelector('[data-audio-tracks]');
    if (trackContainer) {
      const trackElement = this.createTrackElement(track);
      trackContainer.appendChild(trackElement);
    }
  },

  removeTrackFromUI(trackId) {
    const trackElement = document.querySelector(`[data-track-id="${trackId}"]`);
    if (trackElement) {
      trackElement.remove();
    }
  },

  createTrackElement(track) {
    const trackElement = document.createElement('div');
    trackElement.className = 'audio-track bg-gray-800 rounded-lg p-4 mb-4';
    trackElement.dataset.trackId = track.id;
    
    trackElement.innerHTML = `
      <div class="flex items-center justify-between mb-2">
        <h4 class="text-white font-medium">${track.name}</h4>
        <div class="flex items-center space-x-2">
          <button class="track-mute-btn px-2 py-1 text-xs rounded ${track.muted ? 'bg-red-600' : 'bg-gray-600'} text-white">
            M
          </button>
          <button class="track-solo-btn px-2 py-1 text-xs rounded ${track.solo ? 'bg-yellow-600' : 'bg-gray-600'} text-white">
            S
          </button>
          <button class="track-delete-btn px-2 py-1 text-xs rounded bg-red-600 text-white">
            ×
          </button>
        </div>
      </div>
      <div class="flex items-center space-x-4">
        <div class="flex-1">
          <label class="text-xs text-gray-400">Volume</label>
          <input type="range" class="track-volume-slider w-full" min="0" max="1" step="0.01" value="${track.volume}">
        </div>
        <div class="flex-1">
          <label class="text-xs text-gray-400">Pan</label>
          <input type="range" class="track-pan-slider w-full" min="-1" max="1" step="0.01" value="${track.panValue}">
        </div>
        <div class="w-16">
          <div class="track-level-meter bg-gray-700 h-2 rounded">
            <div class="track-level-fill bg-green-400 h-full rounded transition-all duration-75" style="width: 0%"></div>
          </div>
        </div>
      </div>
    `;
    
    // Bind event listeners
    this.bindTrackElementEvents(trackElement, track);
    
    return trackElement;
  },

  bindTrackElementEvents(trackElement, track) {
    const trackId = track.id;
    
    // Volume slider
    const volumeSlider = trackElement.querySelector('.track-volume-slider');
    volumeSlider.addEventListener('input', (e) => {
      const volume = parseFloat(e.target.value);
      this.audioEngine.setTrackVolume(trackId, volume);
    });
    
    // Pan slider
    const panSlider = trackElement.querySelector('.track-pan-slider');
    panSlider.addEventListener('input', (e) => {
      const pan = parseFloat(e.target.value);
      this.audioEngine.setTrackPan(trackId, pan);
    });
    
    // Mute button
    const muteBtn = trackElement.querySelector('.track-mute-btn');
    muteBtn.addEventListener('click', () => {
      const currentlyMuted = muteBtn.classList.contains('bg-red-600');
      this.audioEngine.muteTrack(trackId, !currentlyMuted);
      muteBtn.classList.toggle('bg-red-600', !currentlyMuted);
      muteBtn.classList.toggle('bg-gray-600', currentlyMuted);
    });
    
    // Solo button
    const soloBtn = trackElement.querySelector('.track-solo-btn');
    soloBtn.addEventListener('click', () => {
      const currentlySolo = soloBtn.classList.contains('bg-yellow-600');
      this.audioEngine.soloTrack(trackId, !currentlySolo);
      soloBtn.classList.toggle('bg-yellow-600', !currentlySolo);
      soloBtn.classList.toggle('bg-gray-600', currentlySolo);
    });
    
    // Delete button
    const deleteBtn = trackElement.querySelector('.track-delete-btn');
    deleteBtn.addEventListener('click', () => {
      if (confirm(`Delete ${track.name}?`)) {
        this.deleteTrack(trackId);
      }
    });
  },

  updateTrackLevel(trackId, level) {
    const trackElement = document.querySelector(`[data-track-id="${trackId}"]`);
    if (trackElement) {
      const levelFill = trackElement.querySelector('.track-level-fill');
      if (levelFill) {
        const percentage = Math.min(100, level * 100);
        levelFill.style.width = `${percentage}%`;
        
        // Color coding for levels
        if (level > 0.8) {
          levelFill.className = 'track-level-fill bg-red-400 h-full rounded transition-all duration-75';
        } else if (level > 0.6) {
          levelFill.className = 'track-level-fill bg-yellow-400 h-full rounded transition-all duration-75';
        } else {
          levelFill.className = 'track-level-fill bg-green-400 h-full rounded transition-all duration-75';
        }
      }
    }
  },

  updateMasterLevel(level) {
    const masterLevelMeter = document.querySelector('[data-master-level]');
    if (masterLevelMeter) {
      const levelFill = masterLevelMeter.querySelector('.level-fill');
      if (levelFill) {
        const percentage = Math.min(100, level * 100);
        levelFill.style.width = `${percentage}%`;
      }
    }
  },

  updateTrackRecordingState(trackId, recording) {
    const trackElement = document.querySelector(`[data-track-id="${trackId}"]`);
    if (trackElement) {
      trackElement.classList.toggle('recording', recording);
      
      // Add/remove recording indicator
      let recordingIndicator = trackElement.querySelector('.recording-indicator');
      if (recording && !recordingIndicator) {
        recordingIndicator = document.createElement('div');
        recordingIndicator.className = 'recording-indicator absolute top-2 right-2 w-3 h-3 bg-red-500 rounded-full animate-pulse';
        trackElement.style.position = 'relative';
        trackElement.appendChild(recordingIndicator);
      } else if (!recording && recordingIndicator) {
        recordingIndicator.remove();
      }
    }
  },

  updateTransportState(state, position) {
    // Update transport controls UI
    const playBtn = document.querySelector('[data-transport="play"]');
    const stopBtn = document.querySelector('[data-transport="stop"]');
    const positionDisplay = document.querySelector('[data-transport="position"]');
    
    if (playBtn && stopBtn) {
      playBtn.classList.toggle('active', state === 'playing');
      stopBtn.classList.toggle('active', state === 'stopped');
    }
    
    if (positionDisplay) {
      positionDisplay.textContent = this.formatTime(position);
    }
  },

  formatTime(seconds) {
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  },

  // Cleanup
  destroyed() {
    console.log('AudioEngine hook destroyed');
    
    // Clear sync interval
    if (this.syncInterval) {
      clearInterval(this.syncInterval);
    }
    
    // Destroy audio engine
    if (this.audioEngine) {
      this.audioEngine.destroy();
    }
  },

  // Error handling
  handleError(error, context) {
    console.error(`AudioEngine error in ${context}:`, error);
    this.pushEvent('audio_engine_error', {
      type: context,
      message: error.message,
      stack: error.stack
    });
  }
};

export default AudioEngineHook;