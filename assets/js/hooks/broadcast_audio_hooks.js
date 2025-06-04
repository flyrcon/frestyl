// assets/js/hooks/broadcast_audio_hooks.js
import { AudioEngine } from "../audio/audio_engine.js";
import RtcClient from "../streaming/rtc_client.js";

// Audio Track Hook - manages individual track rendering and interaction
const AudioTrack = {
  mounted() {
    this.trackId = this.el.dataset.trackId;
    this.isHost = this.el.dataset.isHost === "true";
    this.audioEngine = window.broadcastAudioEngine;
    this.levelUpdateInterval = null;
    this.waveformCanvas = null;
    
    this.setupAudioLevelMonitoring();
    this.setupWaveformCanvas();
    
    // Listen for audio level updates from the audio engine
    this.handleEvent("audio_level_update", ({ trackId, inputLevel, outputLevel }) => {
      if (trackId === this.trackId) {
        this.updateLevelMeters(inputLevel, outputLevel);
      }
    });
  },

  setupAudioLevelMonitoring() {
    if (!this.audioEngine || !this.isHost) return;

    // Update level meters every 50ms for smooth animation
    this.levelUpdateInterval = setInterval(() => {
      if (this.audioEngine && this.audioEngine.tracks.has(this.trackId)) {
        const track = this.audioEngine.tracks.get(this.trackId);
        if (track && track.analyzer) {
          const level = this.audioEngine.getAudioLevel(track.analyzer);
          
          // Push level update to Phoenix
          this.pushEvent("audio_level_update", {
            track_id: this.trackId,
            level: level
          });
        }
      }
    }, 50);
  },

  setupWaveformCanvas() {
    const canvas = this.el.querySelector(`canvas[data-clip-id]`);
    if (canvas) {
      this.waveformCanvas = canvas;
      this.renderWaveform();
    }
  },

  updateLevelMeters(inputLevel, outputLevel) {
    // Update input level meter
    const inputMeter = this.el.querySelector('.input-level-meter');
    if (inputMeter) {
      inputMeter.style.width = `${inputLevel * 100}%`;
      
      // Color coding based on level
      if (inputLevel > 0.8) {
        inputMeter.className = inputMeter.className.replace(/bg-\w+-\d+/, 'bg-red-500');
      } else if (inputLevel > 0.6) {
        inputMeter.className = inputMeter.className.replace(/bg-\w+-\d+/, 'bg-yellow-500');
      } else {
        inputMeter.className = inputMeter.className.replace(/bg-\w+-\d+/, 'bg-green-500');
      }
    }

    // Update output level meter
    const outputMeter = this.el.querySelector('.output-level-meter');
    if (outputMeter) {
      outputMeter.style.width = `${outputLevel * 100}%`;
      
      // Color coding based on level
      if (outputLevel > 0.8) {
        outputMeter.className = outputMeter.className.replace(/bg-\w+-\d+/, 'bg-red-500');
      } else if (outputLevel > 0.6) {
        outputMeter.className = outputMeter.className.replace(/bg-\w+-\d+/, 'bg-yellow-500');
      } else {
        outputMeter.className = outputMeter.className.replace(/bg-\w+-\d+/, 'bg-green-500');
      }
    }

    // Update peak indicator
    const peakIndicator = this.el.querySelector('.peak-indicator');
    if (peakIndicator) {
      if (outputLevel > 0.95) {
        peakIndicator.classList.remove('hidden');
        peakIndicator.classList.add('animate-pulse');
      } else {
        peakIndicator.classList.add('hidden');
        peakIndicator.classList.remove('animate-pulse');
      }
    }
  },

  renderWaveform() {
    if (!this.waveformCanvas) return;

    const canvas = this.waveformCanvas;
    const ctx = canvas.getContext('2d');
    const rect = canvas.getBoundingClientRect();
    
    // Set canvas size
    canvas.width = rect.width * window.devicePixelRatio;
    canvas.height = rect.height * window.devicePixelRatio;
    ctx.scale(window.devicePixelRatio, window.devicePixelRatio);

    // Get waveform data from dataset
    const clipId = canvas.dataset.clipId;
    const waveformDataAttr = canvas.dataset.waveformData;
    
    if (!waveformDataAttr) return;

    try {
      const waveformData = JSON.parse(waveformDataAttr);
      this.drawWaveform(ctx, waveformData, rect.width, rect.height);
    } catch (error) {
      console.warn('Failed to parse waveform data:', error);
    }
  },

  drawWaveform(ctx, data, width, height) {
    if (!data || data.length === 0) return;

    const barWidth = width / data.length;
    const centerY = height / 2;
    
    // Set gradient for waveform
    const gradient = ctx.createLinearGradient(0, 0, 0, height);
    gradient.addColorStop(0, 'rgba(139, 92, 246, 0.8)'); // Purple top
    gradient.addColorStop(0.5, 'rgba(139, 92, 246, 1)'); // Purple middle
    gradient.addColorStop(1, 'rgba(139, 92, 246, 0.8)'); // Purple bottom

    ctx.fillStyle = gradient;
    ctx.strokeStyle = 'rgba(139, 92, 246, 0.9)';
    ctx.lineWidth = 1;

    // Draw waveform bars
    for (let i = 0; i < data.length; i++) {
      const barHeight = Math.abs(data[i]) * height * 0.8;
      const x = i * barWidth;
      const y = centerY - barHeight / 2;

      ctx.fillRect(x, y, Math.max(barWidth - 1, 1), barHeight);
    }
  },

  destroyed() {
    if (this.levelUpdateInterval) {
      clearInterval(this.levelUpdateInterval);
    }
  }
};

// Waveform Canvas Hook - handles waveform rendering and interactions
const WaveformCanvas = {
  mounted() {
    this.trackId = this.el.dataset.trackId;
    this.zoomLevel = parseFloat(this.el.dataset.zoomLevel) || 1.0;
    this.isDragging = false;
    this.lastClickTime = 0;
    
    this.setupCanvasInteractions();
    this.renderTimelineMarkers();
  },

  setupCanvasInteractions() {
    // Mouse interactions for desktop
    this.el.addEventListener('mousedown', this.handleMouseDown.bind(this));
    this.el.addEventListener('mousemove', this.handleMouseMove.bind(this));
    this.el.addEventListener('mouseup', this.handleMouseUp.bind(this));
    this.el.addEventListener('click', this.handleClick.bind(this));

    // Touch interactions for mobile
    this.el.addEventListener('touchstart', this.handleTouchStart.bind(this));
    this.el.addEventListener('touchmove', this.handleTouchMove.bind(this));
    this.el.addEventListener('touchend', this.handleTouchEnd.bind(this));

    // Scroll for zoom
    this.el.addEventListener('wheel', this.handleWheel.bind(this));
  },

  handleMouseDown(event) {
    this.isDragging = true;
    this.dragStartX = event.clientX;
    this.dragStartTime = Date.now();
  },

  handleMouseMove(event) {
    if (!this.isDragging) return;
    
    const deltaX = event.clientX - this.dragStartX;
    // Implement horizontal scrolling logic here
  },

  handleMouseUp(event) {
    this.isDragging = false;
  },

  handleClick(event) {
    const now = Date.now();
    const timeSinceLastClick = now - this.lastClickTime;
    
    if (timeSinceLastClick < 300) {
      // Double click - zoom in
      this.zoomLevel *= 1.5;
      this.updateZoom();
    } else {
      // Single click - seek to position
      const rect = this.el.getBoundingClientRect();
      const x = event.clientX - rect.left;
      const position = this.calculateTimeFromPosition(x);
      
      this.pushEvent("seek_to_position", { position: position });
    }
    
    this.lastClickTime = now;
  },

  handleTouchStart(event) {
    if (event.touches.length === 1) {
      const touch = event.touches[0];
      this.touchStartX = touch.clientX;
      this.touchStartTime = Date.now();
    } else if (event.touches.length === 2) {
      // Pinch to zoom start
      const touch1 = event.touches[0];
      const touch2 = event.touches[1];
      this.initialPinchDistance = Math.hypot(
        touch2.clientX - touch1.clientX,
        touch2.clientY - touch1.clientY
      );
      this.initialZoomLevel = this.zoomLevel;
    }
  },

  handleTouchMove(event) {
    if (event.touches.length === 2) {
      // Pinch to zoom
      const touch1 = event.touches[0];
      const touch2 = event.touches[1];
      const currentDistance = Math.hypot(
        touch2.clientX - touch1.clientX,
        touch2.clientY - touch1.clientY
      );
      
      const scale = currentDistance / this.initialPinchDistance;
      this.zoomLevel = Math.max(0.5, Math.min(5.0, this.initialZoomLevel * scale));
      this.updateZoom();
    }
  },

  handleTouchEnd(event) {
    if (event.changedTouches.length === 1 && event.touches.length === 0) {
      const touch = event.changedTouches[0];
      const timeSinceStart = Date.now() - this.touchStartTime;
      const distance = Math.abs(touch.clientX - this.touchStartX);
      
      if (timeSinceStart < 300 && distance < 10) {
        // Tap - seek to position
        const rect = this.el.getBoundingClientRect();
        const x = touch.clientX - rect.left;
        const position = this.calculateTimeFromPosition(x);
        
        this.pushEvent("seek_to_position", { position: position });
      }
    }
  },

  handleWheel(event) {
    event.preventDefault();
    
    const delta = event.deltaY > 0 ? 0.9 : 1.1;
    this.zoomLevel = Math.max(0.5, Math.min(5.0, this.zoomLevel * delta));
    this.updateZoom();
  },

  calculateTimeFromPosition(x) {
    const rect = this.el.getBoundingClientRect();
    const percentage = x / rect.width;
    // This would calculate based on track duration and zoom level
    return percentage * 60; // Assuming 60 second default duration
  },

  updateZoom() {
    this.el.dataset.zoomLevel = this.zoomLevel;
    this.pushEvent("update_zoom", { zoom_level: this.zoomLevel });
  },

  renderTimelineMarkers() {
    // Create time markers overlay
    const markersContainer = this.el.querySelector('.time-markers');
    if (markersContainer) {
      // Implementation for rendering time markers
    }
  }
};

// Mobile Waveform Hook - optimized for mobile interactions
const MobileWaveform = {
  mounted() {
    this.trackId = this.el.dataset.trackId;
    this.setupMobileInteractions();
  },

  setupMobileInteractions() {
    this.el.addEventListener('touchstart', this.handleTouchStart.bind(this));
    this.el.addEventListener('touchend', this.handleTouchEnd.bind(this));
  },

  handleTouchStart(event) {
    const touch = event.touches[0];
    const rect = this.el.getBoundingClientRect();
    const x = touch.clientX - rect.left;
    const timestamp = Date.now();
    
    this.pushEvent("waveform_touch_start", {
      x: x,
      timestamp: timestamp
    });
  },

  handleTouchEnd(event) {
    const touch = event.changedTouches[0];
    const rect = this.el.getBoundingClientRect();
    const x = touch.clientX - rect.left;
    const timestamp = Date.now();
    
    this.pushEvent("waveform_touch_end", {
      x: x,
      timestamp: timestamp
    });
  }
};

// Broadcast Video Hook - integrates video with audio engine
const BroadcastVideo = {
  mounted() {
    this.broadcastId = this.el.dataset.broadcastId;
    this.isHost = this.el.dataset.isHost === "true";
    this.audioEngine = window.broadcastAudioEngine;
    this.rtcClient = window.rtcClient;
    
    this.setupVideoIntegration();
  },

  setupVideoIntegration() {
    if (this.isHost && this.audioEngine) {
      // Connect audio engine output to video stream
      this.connectAudioToVideo();
    }
    
    if (this.rtcClient) {
      // Handle incoming audio from other participants
      this.rtcClient.onTrack((peerId, stream) => {
        if (this.audioEngine) {
          this.audioEngine.addCollaboratorAudio(peerId, stream);
        }
      });
      
      this.rtcClient.onDisconnect((peerId) => {
        if (this.audioEngine) {
          this.audioEngine.removeCollaboratorAudio(peerId);
        }
      });
    }
  },

  connectAudioToVideo() {
    try {
      // Create a destination that combines audio engine output with video
      const audioContext = this.audioEngine.audioContext;
      const destination = audioContext.createMediaStreamDestination();
      
      // Connect audio engine master output to stream destination
      this.audioEngine.analyzer.connect(destination);
      
      // Get audio tracks from the destination
      const audioTracks = destination.stream.getAudioTracks();
      
      // Replace audio tracks in RTC client's local stream
      if (this.rtcClient && this.rtcClient.localStream) {
        // Remove existing audio tracks
        this.rtcClient.localStream.getAudioTracks().forEach(track => {
          this.rtcClient.localStream.removeTrack(track);
          track.stop();
        });
        
        // Add new audio tracks from audio engine
        audioTracks.forEach(track => {
          this.rtcClient.localStream.addTrack(track);
        });
        
        // Update peer connections with new audio
        Object.values(this.rtcClient.peerConnections).forEach(peerConnection => {
          const sender = peerConnection.getSenders().find(s => 
            s.track && s.track.kind === 'audio'
          );
          
          if (sender && audioTracks[0]) {
            sender.replaceTrack(audioTracks[0]);
          }
        });
      }
      
      console.log('Audio engine connected to video stream successfully');
    } catch (error) {
      console.error('Failed to connect audio engine to video:', error);
    }
  }
};

// Audio Engine Manager Hook - manages the overall audio engine lifecycle
const AudioEngineManager = {
  mounted() {
    this.broadcastId = this.el.dataset.broadcastId;
    this.isHost = this.el.dataset.isHost === "true";
    this.audioEngine = null;
    
    if (this.isHost) {
      this.initializeAudioEngine();
    }
    
    // Listen for audio engine events from Phoenix
    this.handleEvent("audio_engine_command", this.handleAudioEngineCommand.bind(this));
  },

  async initializeAudioEngine() {
    try {
      // Initialize audio engine with broadcast-specific settings
      this.audioEngine = new AudioEngine({
        sampleRate: 44100,
        bufferSize: 256,
        enableEffects: true,
        enableMonitoring: true,
        maxTracks: 8
      });

      // Store globally for other hooks to access
      window.broadcastAudioEngine = this.audioEngine;

      // Set up event listeners
      this.setupAudioEngineEvents();

      // Initialize with WebRTC if available
      if (window.rtcClient) {
        this.audioEngine.integrateWithRTC(window.rtcClient);
      }

      console.log('Audio engine initialized for broadcast:', this.broadcastId);
      
      // Notify Phoenix that audio engine is ready
      this.pushEvent("audio_engine_ready", {
        state: this.audioEngine.getState()
      });
    } catch (error) {
      console.error('Failed to initialize audio engine:', error);
      this.pushEvent("audio_engine_error", {
        error: error.message
      });
    }
  },

  setupAudioEngineEvents() {
    if (!this.audioEngine) return;

    // Track events
    this.audioEngine.on('track_created', (data) => {
      this.pushEvent("track_created", data);
    });

    this.audioEngine.on('track_deleted', (data) => {
      this.pushEvent("track_deleted", data);
    });

    this.audioEngine.on('track_volume_changed', (data) => {
      this.pushEvent("track_volume_changed", data);
    });

    this.audioEngine.on('track_muted', (data) => {
      this.pushEvent("track_muted", data);
    });

    this.audioEngine.on('track_solo_changed', (data) => {
      this.pushEvent("track_solo_changed", data);
    });

    // Recording events
    this.audioEngine.on('recording_started', (data) => {
      this.pushEvent("recording_started", data);
    });

    this.audioEngine.on('recording_stopped', (data) => {
      this.pushEvent("recording_stopped", data);
    });

    // Master events
    this.audioEngine.on('master_volume_changed', (data) => {
      this.pushEvent("master_volume_changed", data);
    });

    // Effect events
    this.audioEngine.on('effect_added', (data) => {
      this.pushEvent("effect_added", data);
    });

    this.audioEngine.on('effect_removed', (data) => {
      this.pushEvent("effect_removed", data);
    });

    // Collaboration events
    this.audioEngine.on('collaborator_joined', (data) => {
      this.pushEvent("collaborator_joined", data);
    });

    this.audioEngine.on('collaborator_left', (data) => {
      this.pushEvent("collaborator_left", data);
    });

    // Error handling
    this.audioEngine.on('error', (data) => {
      this.pushEvent("audio_engine_error", data);
    });
  },

  handleAudioEngineCommand({ command, params }) {
    if (!this.audioEngine) return;

    try {
      switch (command) {
        case 'create_track':
          this.audioEngine.createTrack(params);
          break;
        case 'delete_track':
          this.audioEngine.deleteTrack(params.trackId);
          break;
        case 'set_track_volume':
          this.audioEngine.setTrackVolume(params.trackId, params.volume);
          break;
        case 'mute_track':
          this.audioEngine.muteTrack(params.trackId, params.muted);
          break;
        case 'solo_track':
          this.audioEngine.soloTrack(params.trackId, params.solo);
          break;
        case 'set_master_volume':
          this.audioEngine.setMasterVolume(params.volume);
          break;
        case 'start_recording':
          this.audioEngine.startRecording(params.trackId);
          break;
        case 'stop_recording':
          this.audioEngine.stopRecording(params.trackId);
          break;
        case 'start_playback':
          this.audioEngine.startPlayback(params.position);
          break;
        case 'stop_playback':
          this.audioEngine.stopPlayback();
          break;
        case 'add_effect':
          this.audioEngine.addEffectToTrack(params.trackId, params.effectType, params.effectParams);
          break;
        case 'remove_effect':
          this.audioEngine.removeEffectFromTrack(params.trackId, params.effectId);
          break;
        default:
          console.warn('Unknown audio engine command:', command);
      }
    } catch (error) {
      console.error('Error executing audio engine command:', error);
      this.pushEvent("audio_engine_error", {
        command: command,
        error: error.message
      });
    }
  },

  destroyed() {
    if (this.audioEngine) {
      this.audioEngine.destroy();
      window.broadcastAudioEngine = null;
    }
  }
};

// Enhanced Streaming Hooks from previous implementation
const StreamQuality = {
  mounted() {
    this.peerConnection = null;
    this.currentQuality = "auto";
    
    this.handleEvent("set-stream-quality", ({ quality }) => {
      this.setQuality(quality);
    });

    this.handleEvent("set-audio-only", ({ enabled }) => {
      this.setAudioOnly(enabled);
    });
  },

  setPeerConnection(peerConnection) {
    this.peerConnection = peerConnection;
    this.startStatsMonitoring();
  },

  setQuality(quality) {
    if (!this.peerConnection) return;

    this.currentQuality = quality;
    
    const sender = this.peerConnection.getSenders().find(s => 
      s.track && s.track.kind === 'video'
    );

    if (!sender) return;

    const params = sender.getParameters();
    if (!params.encodings || params.encodings.length === 0) return;

    const encoding = params.encodings[0];
    
    switch (quality) {
      case "low":
        encoding.maxBitrate = 200000;
        encoding.scaleResolutionDownBy = 4;
        break;
      case "medium":
        encoding.maxBitrate = 500000;
        encoding.scaleResolutionDownBy = 2;
        break;
      case "high":
        encoding.maxBitrate = 1000000;
        encoding.scaleResolutionDownBy = 1.5;
        break;
      case "hd":
        encoding.maxBitrate = 2000000;
        encoding.scaleResolutionDownBy = 1;
        break;
      case "ultra":
        encoding.maxBitrate = 4000000;
        encoding.scaleResolutionDownBy = 1;
        break;
      case "auto":
      default:
        delete encoding.maxBitrate;
        delete encoding.scaleResolutionDownBy;
        break;
    }

    sender.setParameters(params);
  },

  setAudioOnly(enabled) {
    if (!this.peerConnection) return;

    const videoSender = this.peerConnection.getSenders().find(s => 
      s.track && s.track.kind === 'video'
    );

    if (videoSender && videoSender.track) {
      videoSender.track.enabled = !enabled;
    }

    const videoElement = document.getElementById("broadcast-video");
    if (videoElement) {
      videoElement.style.display = enabled ? "none" : "block";
    }
  },

  startStatsMonitoring() {
    if (!this.peerConnection) return;

    const getStats = () => {
      this.peerConnection.getStats().then(stats => {
        let upload = 0;
        let download = 0;
        let latency = 0;
        let packetLoss = 0;

        stats.forEach(report => {
          if (report.type === 'outbound-rtp' && report.kind === 'video') {
            upload = Math.round((report.bytesSent * 8) / report.timestamp * 1000) || 0;
          } else if (report.type === 'inbound-rtp' && report.kind === 'video') {
            download = Math.round((report.bytesReceived * 8) / report.timestamp * 1000) || 0;
          } else if (report.type === 'candidate-pair' && report.state === 'succeeded') {
            latency = report.currentRoundTripTime ? Math.round(report.currentRoundTripTime * 1000) : 0;
          } else if (report.type === 'transport') {
            const lost = report.packetsLost || 0;
            const sent = report.packetsSent || 1;
            packetLoss = Math.round((lost / sent) * 100) || 0;
          }
        });

        this.pushEvent("update_bandwidth_stats", {
          stats: {
            upload: upload,
            download: download,
            latency: latency,
            packet_loss: packetLoss
          }
        });
      });
    };

    this.statsInterval = setInterval(getStats, 5000);
  },

  destroyed() {
    if (this.statsInterval) {
      clearInterval(this.statsInterval);
    }
  }
};

// Export all hooks for use in app.js
export default {
  AudioTrack,
  WaveformCanvas,
  MobileWaveform,
  BroadcastVideo,
  AudioEngineManager,
  StreamQuality,
  // Include existing hooks from streaming_hooks.js
  SoundCheck: {
    mounted() {
      this.localStream = null;
      this.audioContext = null;
      this.audioAnalyser = null;
      
      this.initializeSoundCheck();
    },

    async initializeSoundCheck() {
      try {
        this.localStream = await navigator.mediaDevices.getUserMedia({ 
          video: true, 
          audio: true 
        });
        
        const videoElement = document.getElementById("video-preview");
        if (videoElement) {
          videoElement.srcObject = this.localStream;
        }

        this.setupAudioMonitoring();
        this.testNetworkQuality();

        this.pushEvent("permissions_granted", { 
          audio: true, 
          video: true 
        });

      } catch (error) {
        console.error("Error accessing media devices:", error);
        this.pushEvent("permissions_denied", {});
      }
    },

    setupAudioMonitoring() {
      if (!this.localStream) return;

      this.audioContext = new (window.AudioContext || window.webkitAudioContext)();
      this.audioAnalyser = this.audioContext.createAnalyser();
      
      const source = this.audioContext.createMediaStreamSource(this.localStream);
      source.connect(this.audioAnalyser);
      
      this.audioAnalyser.fftSize = 256;
      const bufferLength = this.audioAnalyser.frequencyBinCount;
      const dataArray = new Uint8Array(bufferLength);

      const getMicrophoneLevel = () => {
        this.audioAnalyser.getByteFrequencyData(dataArray);
        
        let sum = 0;
        for (let i = 0; i < bufferLength; i++) {
          sum += dataArray[i];
        }
        
        const average = sum / bufferLength;
        const level = Math.round((average / 255) * 100);
        
        this.pushEvent("microphone_level_update", { level: level });
        
        if (this.localStream) {
          requestAnimationFrame(getMicrophoneLevel);
        }
      };

      getMicrophoneLevel();
    },

    async testNetworkQuality() {
      try {
        const startTime = Date.now();
        const response = await fetch('/images/logo.svg?' + Math.random());
        const data = await response.arrayBuffer();
        const endTime = Date.now();
        
        const duration = endTime - startTime;
        const bitsPerSecond = (data.byteLength * 8) / (duration / 1000);
        
        let quality;
        if (bitsPerSecond > 1000000) {
          quality = "good";
        } else if (bitsPerSecond > 500000) {
          quality = "fair";
        } else {
          quality = "poor";
        }
        
        this.pushEvent("network_test_complete", { quality: quality });
      } catch (error) {
        console.error("Network test failed:", error);
        this.pushEvent("network_test_complete", { quality: "poor" });
      }
    },

    destroyed() {
      if (this.localStream) {
        this.localStream.getTracks().forEach(track => track.stop());
      }
      if (this.audioContext) {
        this.audioContext.close();
      }
    }
  }
};