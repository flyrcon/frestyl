// Enhanced assets/js/app.js integration
import "phoenix_html"
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import topbar from "../vendor/topbar"

// Import existing hooks
import { CipherCanvas } from "./cipher_canvas_hook"
import { AutoScrollComments } from "./hooks/comments_hooks"
import { SupremeDiscoveryInterface } from "./supreme_discovery_hook"
import { BeatMachineHook } from "./hooks/beat_machine_hook.js"
import StreamingHooks from "./streaming/streaming_hooks.js"
import StreamQualityHook from "./hooks/stream_quality.js"
import BroadcastAudioHooks from "./hooks/broadcast_audio_hooks"
import { 
  AudioTrack, 
  WaveformCanvas, 
  LiveWaveform, 
  MobileWaveform, 
  BeatMachine, 
  MobileLiveWaveform, 
  TakeWaveform 
} from "./hooks/audio_workspace_hooks"
import ToolDragDrop from "./hooks/tool_drag_drop"
import VideoCapture from "./hooks/video_capture"
import Sortable from "./hooks/sortable"
import FileUpload from "./hooks/file_upload"
import MediaSortable from "./hooks/media_sortable"
import SectionSortable from "./hooks/section_sortable"
import Sortable from 'sortablejs'

import { AudioTextHooks } from "./audio_text_hooks"

import {
  MobileChatHook,
  MobileChatScroll,
  MobileAutoResizeTextarea,
  LongPressMessage,
  ChatScrollManager,
  AutoResizeTextarea
} from "./hooks/mobile_chat_hooks"
import MobileGestures from "./hooks/mobile_gestures"


import { 
  EffectsIntegrationHook, 
  EffectVisualization 
} from "./hooks/effects_integration_hook"

import { TextEditor } from "./hooks/text_editor"

// Import new audio engine components
import AudioEngineHook from "./hooks/audio_engine_hook.js"
import AudioEngine from "./audio/audio_engine.js"
import { EnhancedEffectsEngine } from "./audio/enhanced_effects_engine"
import { StudioAudioClient } from "./studio/audio_client"
import { EnhancedAudioHooks } from "./enhanced_audio_hooks"

// Import WebRTC client
import RtcClient from "./streaming/rtc_client.js"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

// Initialize global audio engine and RTC client
window.AudioEngine = AudioEngine;
window.rtcClient = null;
window.audioEngine = null;
window.EnhancedEffectsEngine = EnhancedEffectsEngine;
window.StudioAudioClient = StudioAudioClient;

// Text editor
window.TextEditor = TextEditor;

// Enhanced timezone handling
document.addEventListener('DOMContentLoaded', updateTimezoneDisplays);
window.addEventListener('phx:page-loading-stop', updateTimezoneDisplays);

// Initialize RTC client when needed
function initializeRTC(userToken, userId) {
  if (!window.rtcClient) {
    window.rtcClient = new RtcClient(userToken, userId);
    console.log('RTC Client initialized');
  }
  return window.rtcClient;
}

window.Sortable = Sortable;

// Enhanced fullscreen with audio context resume
window.addEventListener('phx:toggle_fullscreen', async (e) => {
  const videoContainer = document.querySelector('.aspect-video');
  
  if (videoContainer) {
    if (!document.fullscreenElement) {
      // Resume audio context if suspended
      if (window.audioEngine && window.audioEngine.audioContext.state === 'suspended') {
        await window.audioEngine.audioContext.resume();
      }
      
      // Enter fullscreen
      if (videoContainer.requestFullscreen) {
        videoContainer.requestFullscreen();
      } else if (videoContainer.webkitRequestFullscreen) {
        videoContainer.webkitRequestFullscreen();
      } else if (videoContainer.msRequestFullscreen) {
        videoContainer.msRequestFullscreen();
      }
    } else {
      // Exit fullscreen
      if (document.exitFullscreen) {
        document.exitFullscreen();
      } else if (document.webkitExitFullscreen) {
        document.webkitExitFullscreen();
      } else if (document.msExitFullscreen) {
        document.msExitFullscreen();
      }
    }
  }
});

// Enhanced registration UI updates with audio feedback
window.addEventListener('phx:update-registration-ui', (e) => {
  const { broadcast_id, registered } = e.detail;
  const button = document.querySelector(`[data-broadcast-id="${broadcast_id}"]`);
  
  if (button) {
    if (registered) {
      button.textContent = 'Registered ✓';
      button.className = button.className.replace('bg-indigo-600', 'bg-green-600');
      button.disabled = true;
      
      // Play success sound if audio engine is available
      if (window.audioEngine) {
        playNotificationSound('success');
      }
    } else {
      button.textContent = 'Register';
      button.className = button.className.replace('bg-green-600', 'bg-indigo-600');
      button.disabled = false;
    }
  }
});

// Enhanced stats refresh for broadcasts with audio monitoring
window.addEventListener('phx:page-loading-stop', () => {
  if (window.location.pathname.includes('/broadcasts/') && window.location.pathname.includes('/live')) {
    // Start stats and audio monitoring refresh
    setInterval(() => {
      const liveView = window.liveSocket.getView();
      if (liveView) {
        liveView.pushEvent('refresh_stats', {});
        
        // Send audio engine stats if available
        if (window.audioEngine) {
          const audioStats = window.audioEngine.getState();
          liveView.pushEvent('refresh_audio_stats', { audioStats });
        }
      }
    }, 30000);
  }
});

// Enhanced timezone display handling
function updateTimezoneDisplays() {
  const userTimezone = Intl.DateTimeFormat().resolvedOptions().timeZone;
  
  document.querySelectorAll('[data-utc-time]').forEach(element => {
    const utcTime = element.dataset.utcTime;
    if (utcTime) {
      try {
        const date = new Date(utcTime);
        const options = {
          timeZone: userTimezone,
          year: 'numeric',
          month: 'short',
          day: 'numeric',
          hour: '2-digit',
          minute: '2-digit',
          timeZoneName: 'short'
        };
        element.textContent = date.toLocaleString('en-US', options);
      } catch (e) {
        console.warn('Failed to format timezone:', e);
      }
    }
  });
}

// Audio notification system
function playNotificationSound(type) {
  if (!window.audioEngine || !window.audioEngine.audioContext) return;
  
  const audioContext = window.audioEngine.audioContext;
  const oscillator = audioContext.createOscillator();
  const gainNode = audioContext.createGain();
  
  oscillator.connect(gainNode);
  gainNode.connect(audioContext.destination);
  
  // Configure sound based on type
  switch (type) {
    case 'success':
      oscillator.frequency.setValueAtTime(800, audioContext.currentTime);
      oscillator.frequency.setValueAtTime(1000, audioContext.currentTime + 0.1);
      break;
    case 'error':
      oscillator.frequency.setValueAtTime(300, audioContext.currentTime);
      oscillator.frequency.setValueAtTime(200, audioContext.currentTime + 0.1);
      break;
    case 'notification':
      oscillator.frequency.setValueAtTime(600, audioContext.currentTime);
      break;
    default:
      oscillator.frequency.setValueAtTime(440, audioContext.currentTime);
  }
  
  gainNode.gain.setValueAtTime(0, audioContext.currentTime);
  gainNode.gain.linearRampToValueAtTime(0.1, audioContext.currentTime + 0.01);
  gainNode.gain.exponentialRampToValueAtTime(0.001, audioContext.currentTime + 0.2);
  
  oscillator.start(audioContext.currentTime);
  oscillator.stop(audioContext.currentTime + 0.2);
}

// Ensure React is available for components
if (typeof window.React === 'undefined') {
  import('react').then(React => {
    window.React = React;
  });
}

if (typeof window.ReactDOM === 'undefined') {
  import('react-dom').then(ReactDOM => {
    window.ReactDOM = ReactDOM;
  });
}



// Enhanced hooks collection
let Hooks = {
  // Existing hooks
  AutoScrollComments,
  SupremeDiscoveryInterface: SupremeDiscoveryInterface,
  BeatMachine: BeatMachineHook,
  CipherCanvas: CipherCanvas,
  MobileAudio: MobileAudioHook,
  MobileGestures: MobileGestures,
  
  // Audio engine hooks
  AudioEngine: AudioEngineHook,

  ...AudioTextHooks,
  
  // Enhanced streaming hooks
  ...StreamingHooks,
  StreamQuality: StreamQualityHook,
  ...BroadcastAudioHooks,

  ...EnhancedAudioHooks,

    // Session and general hooks
  ...SessionHooks,
  
  // Studio hooks
  ...StudioHooks,
  
  // Audio workspace hooks
  AudioTrack,
  WaveformCanvas,
  LiveWaveform,
  MobileWaveform,
  BeatMachine,
  MobileLiveWaveform,
  TakeWaveform,

  // Portfolio features 
  Sortable: Sortable,
  VideoCapture: VideoCapture,
  FileUpload: FileUpload,
  MediaSortable: MediaSortable,
  ToolDragDrop: ToolDragDrop,
  SectionSortable: SectionSortable,
  
  // Mobile audio hook
  MobileAudioHook,
  MobileChatHook,
  MobileGestures: MobileGestures,
  
  // NEW: Audio effects hooks
  EffectsIntegrationHook,
  EffectVisualization,
  
  // Enhanced broadcast modal with audio integration
  BroadcastModal: {
    mounted() {
      console.log('BroadcastModal hook mounted');
      
      // Initialize the form when modal is mounted
      if (window.BroadcastForm) {
        window.BroadcastForm.init();
      }
      
      // Initialize RTC if in broadcast context
      const userToken = this.el.dataset.userToken;
      const userId = this.el.dataset.userId;
      if (userToken && userId) {
        initializeRTC(userToken, userId);
      }
    },
    
    updated() {
      console.log('BroadcastModal hook updated');
      if (window.BroadcastForm) {
        window.BroadcastForm.init();
      }
    }
  },

  // Enhanced recording workspace with audio engine integration
  RecordingWorkspace: {
    mounted() {
      console.log('RecordingWorkspace mounted');
      
      // Get configuration
      const sessionId = this.el.dataset.sessionId;
      const userId = this.el.dataset.userId;
      const userToken = this.el.dataset.userToken;
      
      // Initialize RTC client
      if (userToken && userId) {
        this.rtcClient = initializeRTC(userToken, userId);
      }
      
      // Set up recording controls
      this.setupRecordingControls();
      
      // Listen for audio engine events
      this.setupAudioEngineIntegration();
    },
    
    setupRecordingControls() {
      // Record button
      const recordBtn = this.el.querySelector('[data-action="record"]');
      if (recordBtn) {
        recordBtn.addEventListener('click', () => {
          this.toggleRecording();
        });
      }
      
      // Track controls
      this.el.querySelectorAll('[data-track-id]').forEach(trackElement => {
        this.setupTrackControls(trackElement);
      });
    },
    
    setupTrackControls(trackElement) {
      const trackId = trackElement.dataset.trackId;
      
      // Volume control
      const volumeSlider = trackElement.querySelector('[data-control="volume"]');
      if (volumeSlider) {
        volumeSlider.addEventListener('input', (e) => {
          this.pushEvent('track_volume_change', {
            track_id: trackId,
            volume: parseFloat(e.target.value)
          });
        });
      }
      
      // Mute button
      const muteBtn = trackElement.querySelector('[data-control="mute"]');
      if (muteBtn) {
        muteBtn.addEventListener('click', () => {
          const isMuted = muteBtn.classList.contains('muted');
          this.pushEvent('track_mute', {
            track_id: trackId,
            muted: !isMuted
          });
        });
      }
    },
    
    setupAudioEngineIntegration() {
      // Listen for audio engine initialization
      window.addEventListener('audio-engine-ready', () => {
        console.log('Audio engine ready in recording workspace');
        this.syncWithAudioEngine();
      });
      
      // Handle incoming audio data
      if (this.rtcClient) {
        this.rtcClient.onTrack((peerId, stream) => {
          this.handleIncomingAudio(peerId, stream);
        });
      }
    },
    
    toggleRecording() {
      if (this.isRecording) {
        this.stopRecording();
      } else {
        this.startRecording();
      }
    },
    
    async startRecording() {
      try {
        // Request microphone access
        const stream = await navigator.mediaDevices.getUserMedia({ 
          audio: {
            echoCancellation: false,
            noiseSuppression: false,
            autoGainControl: false
          } 
        });
        
        this.isRecording = true;
        this.updateRecordingUI(true);
        
        // Notify LiveView
        this.pushEvent('recording_started', {
          timestamp: Date.now()
        });
        
        console.log('Recording started');
      } catch (error) {
        console.error('Failed to start recording:', error);
        this.pushEvent('recording_error', {
          message: error.message
        });
      }
    },
    
    stopRecording() {
      this.isRecording = false;
      this.updateRecordingUI(false);
      
      this.pushEvent('recording_stopped', {
        timestamp: Date.now()
      });
      
      console.log('Recording stopped');
    },
    
    updateRecordingUI(recording) {
      const recordBtn = this.el.querySelector('[data-action="record"]');
      if (recordBtn) {
        recordBtn.classList.toggle('recording', recording);
        recordBtn.textContent = recording ? 'Stop Recording' : 'Start Recording';
      }
      
      // Update track recording indicators
      this.el.querySelectorAll('[data-track-id]').forEach(trackElement => {
        trackElement.classList.toggle('recording', recording);
      });
    },
    
    handleIncomingAudio(peerId, stream) {
      console.log('Incoming audio from peer:', peerId);
      
      // Create audio element for monitoring
      const audioElement = document.createElement('audio');
      audioElement.srcObject = stream;
      audioElement.autoplay = true;
      audioElement.muted = false; // For monitoring
      
      // Add to DOM for debugging
      audioElement.style.display = 'none';
      document.body.appendChild(audioElement);
      
      // Store reference
      this.peerAudioElements = this.peerAudioElements || new Map();
      this.peerAudioElements.set(peerId, audioElement);
    },
    
    syncWithAudioEngine() {
      if (window.audioEngine) {
        // Sync track states
        const engineState = window.audioEngine.getState();
        this.pushEvent('sync_audio_engine_state', {
          engine_state: engineState
        });
      }
    },
    
    destroyed() {
      console.log('RecordingWorkspace destroyed');
      
      // Clean up audio elements
      if (this.peerAudioElements) {
        this.peerAudioElements.forEach(audioElement => {
          audioElement.remove();
        });
      }
      
      // Stop recording if active
      if (this.isRecording) {
        this.stopRecording();
      }
    }
  },

    // Audio Track Manager hook for effects integration
  AudioTrackManager: {
    mounted() {
      this.trackId = this.el.dataset.trackId;
      this.sessionId = this.el.dataset.sessionId;
      
      // Initialize audio engine if not already initialized
      this.initializeAudioEngine();
      
      // Setup track-specific effects management
      this.setupTrackEffects();
    },
    
    async initializeAudioEngine() {
      if (!window.audioEngine) {
        try {
          window.audioEngine = new AudioEngine({
            sampleRate: 48000,
            bufferSize: 256,
            enableEffects: true,
            enableMonitoring: true,
            maxTracks: 8
          });
          
          await window.audioEngine.initialize();
          console.log('Global audio engine initialized');
          
          // Make it available to effects hooks
          window.dispatchEvent(new CustomEvent('audio-engine-ready', {
            detail: { audioEngine: window.audioEngine }
          }));
          
        } catch (error) {
          console.error('Failed to initialize global audio engine:', error);
        }
      }
    },
    
    setupTrackEffects() {
      // Listen for effect-related events from LiveView
      this.handleEvent('effect_added', (data) => {
        this.addEffectToTrack(data);
      });
      
      this.handleEvent('effect_removed', (data) => {
        this.removeEffectFromTrack(data);
      });
      
      this.handleEvent('effect_parameter_updated', (data) => {
        this.updateEffectParameter(data);
      });
      
      this.handleEvent('effect_preset_applied', (data) => {
        this.applyEffectPreset(data);
      });
    },
    
    addEffectToTrack(data) {
      const { trackId, effectType, effectParams } = data;
      
      if (window.audioEngine && trackId === this.trackId) {
        try {
          const effectId = window.audioEngine.addEffectToTrack(trackId, effectType, effectParams);
          
          this.pushEvent('effect_added_success', {
            track_id: trackId,
            effect_id: effectId,
            effect_type: effectType
          });
          
        } catch (error) {
          console.error('Failed to add effect:', error);
          this.pushEvent('effect_added_error', {
            track_id: trackId,
            error: error.message
          });
        }
      }
    },
    
    removeEffectFromTrack(data) {
      const { trackId, effectId } = data;
      
      if (window.audioEngine && trackId === this.trackId) {
        try {
          window.audioEngine.removeEffectFromTrack(trackId, effectId);
          
          this.pushEvent('effect_removed_success', {
            track_id: trackId,
            effect_id: effectId
          });
          
        } catch (error) {
          console.error('Failed to remove effect:', error);
        }
      }
    },
    
    updateEffectParameter(data) {
      const { trackId, effectId, paramName, value } = data;
      
      if (window.audioEngine && trackId === this.trackId) {
        try {
          // Use enhanced effects engine if available
          if (window.audioEngine.updateEffectParameter) {
            window.audioEngine.updateEffectParameter(effectId, paramName, value, { smooth: true });
          }
          
        } catch (error) {
          console.error('Failed to update effect parameter:', error);
        }
      }
    },
    
    applyEffectPreset(data) {
      const { trackId, presetName } = data;
      
      if (window.audioEngine && trackId === this.trackId) {
        try {
          // Use enhanced effects engine preset system
          if (window.audioEngine.applyEffectPreset) {
            const appliedEffects = window.audioEngine.applyEffectPreset(trackId, presetName);
            
            this.pushEvent('effect_preset_applied_success', {
              track_id: trackId,
              preset_name: presetName,
              applied_effects: appliedEffects
            });
          }
          
        } catch (error) {
          console.error('Failed to apply effect preset:', error);
          this.pushEvent('effect_preset_applied_error', {
            track_id: trackId,
            error: error.message
          });
        }
      }
    }
  },
  
  // Effects Parameter Control hook for real-time sliders
  EffectParameterControl: {
    mounted() {
      this.effectId = this.el.dataset.effectId;
      this.paramName = this.el.dataset.paramName;
      this.trackId = this.el.dataset.trackId;
      
      // Setup real-time parameter updates
      this.setupParameterControl();
    },
    
    setupParameterControl() {
      let updateTimeout;
      
      // Handle input events for real-time updates
      this.el.addEventListener('input', (event) => {
        const value = this.parseValue(event.target.value);
        
        // Update audio engine immediately for real-time feel
        if (window.audioEngine?.updateEffectParameter) {
          window.audioEngine.updateEffectParameter(this.effectId, this.paramName, value, {
            smooth: true,
            transitionTime: 0.01
          });
        }
        
        // Throttle LiveView updates to avoid spam
        clearTimeout(updateTimeout);
        updateTimeout = setTimeout(() => {
          this.pushEvent('effect_parameter_changed', {
            track_id: this.trackId,
            effect_id: this.effectId,
            param_name: this.paramName,
            value: value
          });
        }, 50); // 20fps update rate to LiveView
      });
      
      // Handle change events for final value
      this.el.addEventListener('change', (event) => {
        const value = this.parseValue(event.target.value);
        
        this.pushEvent('effect_parameter_final', {
          track_id: this.trackId,
          effect_id: this.effectId,
          param_name: this.paramName,
          value: value
        });
      });
    },
    
    parseValue(stringValue) {
      // Parse value based on parameter type
      if (this.el.type === 'checkbox') {
        return this.el.checked;
      } else if (this.el.type === 'range' || this.el.type === 'number') {
        return parseFloat(stringValue);
      } else {
        return stringValue;
      }
    }
  },
  
  // CPU Usage Monitor hook
  CPUUsageMonitor: {
    mounted() {
      this.updateInterval = setInterval(() => {
        this.updateCPUUsage();
      }, 1000); // Update every second
    },
    
    updateCPUUsage() {
      if (window.audioEngine?.calculateCPUUsage) {
        const cpuUsage = window.audioEngine.calculateCPUUsage();
        
        // Update UI
        const bar = this.el.querySelector('.cpu-bar');
        const text = this.el.querySelector('.cpu-text');
        
        if (bar) {
          bar.style.width = `${cpuUsage}%`;
          bar.className = `cpu-bar transition-all duration-200 ${
            cpuUsage > 80 ? 'bg-red-500' : 
            cpuUsage > 60 ? 'bg-yellow-500' : 'bg-green-500'
          }`;
        }
        
        if (text) {
          text.textContent = `${Math.round(cpuUsage)}%`;
        }
        
        // Send to LiveView for server-side monitoring
        this.pushEvent('cpu_usage_update', {
          cpu_usage: cpuUsage,
          timestamp: Date.now()
        });
      }
    },
    
    destroyed() {
      if (this.updateInterval) {
        clearInterval(this.updateInterval);
      }
    }
  },

  // Enhanced text editor with operational transform
  TextEditorOT: {
    mounted() {
      console.log('TextEditorOT mounted');
      this.setupTextEditor();
      this.setupOperationalTransform();
    },
    
    setupTextEditor() {
      this.textarea = this.el;
      this.lastContent = this.textarea.value;
      this.version = 0;
      
      // Debounced change handler
      this.changeTimeout = null;
      this.textarea.addEventListener('input', () => {
        clearTimeout(this.changeTimeout);
        this.changeTimeout = setTimeout(() => {
          this.handleTextChange();
        }, 300);
      });
      
      // Selection change handler
      this.textarea.addEventListener('selectionchange', () => {
        this.handleSelectionChange();
      });
    },
    
    setupOperationalTransform() {
      // Handle incoming text operations
      this.handleEvent('text_operation', ({ operation, version }) => {
        this.applyOperation(operation, version);
      });
      
      // Handle cursor updates
      this.handleEvent('cursor_update', ({ userId, position }) => {
        this.updateCursor(userId, position);
      });
    },
    
    handleTextChange() {
      const currentContent = this.textarea.value;
      if (currentContent !== this.lastContent) {
        const operation = this.generateOperation(this.lastContent, currentContent);
        this.lastContent = currentContent;
        this.version++;
        
        // Send to server
        this.pushEvent('text_update', {
          content: currentContent,
          operation: operation,
          version: this.version,
          selection: {
            start: this.textarea.selectionStart,
            end: this.textarea.selectionEnd
          }
        });
      }
    },
    
    handleSelectionChange() {
      // Update cursor position for other users
      this.pushEvent('cursor_update', {
        position: {
          start: this.textarea.selectionStart,
          end: this.textarea.selectionEnd
        }
      });
    },
    
    generateOperation(oldText, newText) {
      // Simple diff operation - in production use a more sophisticated algorithm
      if (oldText === newText) return null;
      
      return {
        type: 'replace',
        oldText: oldText,
        newText: newText,
        timestamp: Date.now()
      };
    },
    
    applyOperation(operation, version) {
      if (operation && operation.type === 'replace') {
        // Apply the operation if version is newer
        if (version > this.version) {
          this.textarea.value = operation.newText;
          this.lastContent = operation.newText;
          this.version = version;
        }
      }
    },
    
    updateCursor(userId, position) {
      // Create or update cursor indicator for other users
      // This would be implemented with absolute positioning
      console.log(`Cursor update for user ${userId}:`, position);
    }
  },

  // Enhanced analytics dashboard with audio metrics
  AnalyticsDashboard: {
    mounted() {
      this.initializeAnimations();
      this.bindEvents();
      this.setupAudioMetrics();
    },

    updated() {
      this.initializeAnimations();
    },

    setupAudioMetrics() {
      // Monitor audio engine metrics if available
      if (window.audioEngine) {
        this.audioMetricsInterval = setInterval(() => {
          const audioStats = window.audioEngine.getState();
          this.updateAudioMetrics(audioStats);
        }, 1000);
      }
    },

    updateAudioMetrics(audioStats) {
      const audioMetricsContainer = this.el.querySelector('[data-audio-metrics]');
      if (audioMetricsContainer && audioStats) {
        // Update audio-specific metrics
        const activeTracksElement = audioMetricsContainer.querySelector('[data-metric="active-tracks"]');
        if (activeTracksElement) {
          activeTracksElement.textContent = audioStats.tracks.length;
        }
        
        const recordingElement = audioMetricsContainer.querySelector('[data-metric="recording"]');
        if (recordingElement) {
          recordingElement.textContent = audioStats.isRecording ? 'Yes' : 'No';
          recordingElement.className = audioStats.isRecording ? 'text-red-400' : 'text-gray-400';
        }
      }
    },

    initializeAnimations() {
      this.animateCounters();
      this.animateProgressBars();
      this.animateCharts();
    },

    animateCounters() {
      this.el.querySelectorAll('[data-counter]').forEach(counter => {
        const target = parseInt(counter.dataset.counter);
        const duration = 2000;
        const increment = target / (duration / 16);
        let current = 0;

        const updateCounter = () => {
          current += increment;
          if (current < target) {
            counter.textContent = Math.floor(current);
            requestAnimationFrame(updateCounter);
          } else {
            counter.textContent = target;
          }
        };

        updateCounter();
      });
    },

    animateProgressBars() {
      this.el.querySelectorAll('.progress-bar').forEach(bar => {
        const fill = bar.querySelector('.progress-fill');
        if (fill) {
          const percentage = fill.dataset.percentage || 0;
          setTimeout(() => {
            fill.style.width = percentage + '%';
          }, 100);
        }
      });
    },

    animateCharts() {
      this.el.querySelectorAll('.mini-chart').forEach(chart => {
        chart.style.opacity = '0';
        chart.style.transform = 'translateY(20px)';
        
        setTimeout(() => {
          chart.style.transition = 'all 0.6s ease';
          chart.style.opacity = '1';
          chart.style.transform = 'translateY(0)';
        }, 200);
      });
    },

    bindEvents() {
      const toggleBtn = this.el.querySelector('#toggleAnalytics');
      const detailsPanel = this.el.querySelector('#analyticsDetails');
      
      if (toggleBtn && detailsPanel) {
        toggleBtn.addEventListener('click', () => {
          const isExpanded = detailsPanel.style.maxHeight !== '0px';
          
          if (isExpanded) {
            detailsPanel.style.maxHeight = '0px';
            detailsPanel.style.opacity = '0';
            toggleBtn.textContent = 'Show Details ▼';
          } else {
            detailsPanel.style.maxHeight = detailsPanel.scrollHeight + 'px';
            detailsPanel.style.opacity = '1';
            toggleBtn.textContent = 'Hide Details ▲';
          }
        });
      }
    },

    destroyed() {
      if (this.audioMetricsInterval) {
        clearInterval(this.audioMetricsInterval);
      }
    }
  },

  // File upload hook enhanced for audio files
  FileUpload: {
    mounted() {
      this.uploadArea = this.el.querySelector('.upload-area');
      this.fileInput = this.el.querySelector('input[type="file"]');
      
      if (this.uploadArea && this.fileInput) {
        this.bindDragEvents();
        this.bindClickEvents();
      }
    },

    bindDragEvents() {
      ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
        this.uploadArea.addEventListener(eventName, this.preventDefaults, false);
      });

      ['dragenter', 'dragover'].forEach(eventName => {
        this.uploadArea.addEventListener(eventName, () => {
          this.uploadArea.classList.add('drag-over');
        }, false);
      });

      ['dragleave', 'drop'].forEach(eventName => {
        this.uploadArea.addEventListener(eventName, () => {
          this.uploadArea.classList.remove('drag-over');
        }, false);
      });

      this.uploadArea.addEventListener('drop', (e) => {
        const files = e.dataTransfer.files;
        this.handleFiles(files);
      }, false);
    },

    bindClickEvents() {
      this.uploadArea.addEventListener('click', () => {
        this.fileInput.click();
      });

      this.fileInput.addEventListener('change', (e) => {
        this.handleFiles(e.target.files);
      });
    },

    preventDefaults(e) {
      e.preventDefault();
      e.stopPropagation();
    },

    handleFiles(files) {
      const fileList = Array.from(files);
      const preview = this.el.querySelector('.file-preview');
      
      if (preview) {
        preview.innerHTML = '';
        fileList.forEach(file => {
          const fileItem = this.createFilePreview(file);
          preview.appendChild(fileItem);
        });
      }
    },

    createFilePreview(file) {
      const fileItem = document.createElement('div');
      fileItem.className = 'file-item p-3 border rounded mb-2';
      
      // Enhanced preview for audio files
      if (file.type.startsWith('audio/')) {
        fileItem.innerHTML = `
          <div class="flex items-center space-x-3">
            <div class="audio-icon text-blue-500">
              <svg class="w-8 h-8" fill="currentColor" viewBox="0 0 20 20">
                <path d="M18 3a1 1 0 00-1.196-.98l-10 2A1 1 0 006 5v9.114A4.369 4.369 0 005 14c-1.657 0-3 .895-3 2s1.343 2 3 2 3-.895 3-2V7.82l8-1.6v5.894A4.37 4.37 0 0015 12c-1.657 0-3 .895-3 2s1.343 2 3 2 3-.895 3-2V3z"/>
              </svg>
            </div>
            <div class="flex-1">
              <div class="font-medium">${file.name}</div>
              <div class="text-sm text-gray-500">${this.formatFileSize(file.size)} • Audio</div>
              <audio controls class="mt-2 w-full" preload="metadata">
                <source src="${URL.createObjectURL(file)}" type="${file.type}">
              </audio>
            </div>
          </div>
        `;
      } else {
        fileItem.innerHTML = `
          <div class="flex items-center space-x-3">
            <div class="file-icon text-gray-500">
              <svg class="w-8 h-8" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M4 4a2 2 0 012-2h4.586A2 2 0 0112 2.586L15.414 6A2 2 0 0116 7.414V16a2 2 0 01-2 2H6a2 2 0 01-2-2V4z"/>
              </svg>
            </div>
            <div class="flex-1">
              <div class="font-medium">${file.name}</div>
              <div class="text-sm text-gray-500">${this.formatFileSize(file.size)}</div>
            </div>
          </div>
        `;
      }
      
      return fileItem;
    },

    formatFileSize(bytes) {
      if (bytes === 0) return '0 Bytes';
      const k = 1024;
      const sizes = ['Bytes', 'KB', 'MB', 'GB'];
      const i = Math.floor(Math.log(bytes) / Math.log(k));
      return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
    }
  },

  MobileChatHook,
  MobileChatScroll,
  MobileAutoResizeTextarea,
  LongPressMessage,
  ChatScrollManager,
  AutoResizeTextarea
};

// Global hooks reference
window.Hooks = Hooks;

// Initialize LiveSocket with enhanced configuration
let liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: Hooks,
  dom: {
    onBeforeElUpdated(from, to) {
      if (from._x_dataStack) {
        window.Alpine.clone(from, to)
      }
    }
  },
  metadata: {
    click: (e, el) => {
      return {
        alt: e.altKey,
        shift: e.shiftKey,
        ctrl: e.ctrlKey,
        meta: e.metaKey,
        x: e.clientX,
        y: e.clientY
      }
    }
  },

  // Enhanced configuration for audio applications
  longPollFallbackMs: 2500,
  heartbeatIntervalMs: 30000,
  
  // Custom metadata for audio synchronization
  metadata: {
    click: (e, el) => {
      return {
        altKey: e.altKey,
        shiftKey: e.shiftKey,
        ctrlKey: e.ctrlKey,
        metaKey: e.metaKey,
        detail: e.detail || 1,
        // Add audio context timing for synchronization
        audioTime: window.audioEngine?.audioContext?.currentTime || 0
      }
    },
    
    keydown: (e, el) => {
      return {
        key: e.key,
        altKey: e.altKey,
        shiftKey: e.shiftKey,
        ctrlKey: e.ctrlKey,
        metaKey: e.metaKey,
        // Audio timing for keyboard shortcuts
        audioTime: window.audioEngine?.audioContext?.currentTime || 0
      }
    }
  },
  
  // DOM patching configuration optimized for audio UI
  dom: {
    onBeforeElUpdated(from, to) {
      // Preserve audio-related input states during updates
      if (from._x_dataStack) { from._x_dataStack = undefined }
      
      // Preserve audio parameter control states
      if (from.hasAttribute('data-effect-param')) {
        if (from.type === 'range' && from.value !== to.value) {
          // Don't update range inputs that are being actively dragged
          if (from === document.activeElement && from.matches(':focus')) {
            to.value = from.value;
          }
        }
      }
      
      // Preserve audio visualization canvas states
      if (from.tagName === 'CANVAS' && from.hasAttribute('data-effect-visualization')) {
        // Don't replace canvases that are actively rendering
        return false;
      }
      
      return true;
    }
  }
});

// Enhanced progress bar
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" })
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// Connect LiveSocket
liveSocket.connect()

// Expose for debugging
window.liveSocket = liveSocket

// Global error handling for audio contexts
window.addEventListener('error', (event) => {
  if (event.error && event.error.message.includes('AudioContext')) {
    console.warn('AudioContext error detected, attempting recovery');
    if (window.audioEngine && window.audioEngine.audioContext) {
      window.audioEngine.audioContext.resume().catch(console.error);
    }
  }
});

// Global error handling for audio engine
window.addEventListener('error', (event) => {
  if (event.error && event.error.message.includes('audio')) {
    console.error('Audio engine error:', event.error);
    
    // Notify LiveView of audio errors
    if (liveSocket.isConnected()) {
      liveSocket.pushEvent('audio_engine_error', {
        error: event.error.message,
        stack: event.error.stack,
        timestamp: Date.now()
      });
    }
  }
});

// Enhanced audio context management
window.addEventListener('click', () => {
  // Resume audio context on first user interaction (browser requirement)
  if (window.audioEngine?.audioContext?.state === 'suspended') {
    window.audioEngine.audioContext.resume().then(() => {
      console.log('Audio context resumed after user interaction');
    });
  }
}, { once: true });

// Portfolio video capture
window.Hooks = window.Hooks || {};

window.Hooks.VideoCapture = {
  mounted() {
    this.mediaRecorder = null;
    this.recordedChunks = [];
    this.stream = null;
    this.recordedBlob = null;

    this.initializeCamera();
    this.setupEventListeners();
  },

  destroyed() {
    this.cleanup();
  },

  async initializeCamera() {
    try {
      const constraints = {
        video: {
          width: { ideal: 1920 },
          height: { ideal: 1080 },
          aspectRatio: { ideal: 16/9 },
          facingMode: 'user',
          frameRate: { ideal: 30 }
        },
        audio: {
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
          sampleRate: 44100
        }
      };

      this.stream = await navigator.mediaDevices.getUserMedia(constraints);
      const videoElement = document.getElementById('camera-preview');
      if (videoElement) {
        videoElement.srcObject = this.stream;
      }

      // Notify LiveView that camera is ready
      this.pushEvent('camera_ready', {});

    } catch (error) {
      console.error('Error accessing camera:', error);
      let message = 'Camera access failed';
      
      if (error.name === 'NotAllowedError') {
        message = 'Camera permission denied. Please allow camera access and refresh.';
      } else if (error.name === 'NotFoundError') {
        message = 'No camera found. Please connect a camera and try again.';
      } else if (error.name === 'NotReadableError') {
        message = 'Camera is already in use by another application.';
      }

      this.pushEvent('camera_error', { 
        error: error.name, 
        message: message 
      });
    }
  },

  setupEventListeners() {
    // Handle events from LiveView
    this.handleEvent('start_countdown', () => {
      console.log('Countdown started');
    });

    this.handleEvent('start_recording', () => {
      this.startRecording();
    });

    this.handleEvent('stop_recording', () => {
      this.stopRecording();
    });

    this.handleEvent('retake_video', () => {
      this.resetForRetake();
    });

    this.handleEvent('upload_video', () => {
      this.uploadVideo();
    });
  },

  startRecording() {
    if (!this.stream) {
      console.error('No stream available for recording');
      return;
    }

    this.recordedChunks = [];
    
    const options = {
      mimeType: 'video/webm;codecs=vp8,opus',
      videoBitsPerSecond: 2500000, // 2.5 Mbps for good quality
      audioBitsPerSecond: 128000   // 128 kbps for audio
    };

    try {
      this.mediaRecorder = new MediaRecorder(this.stream, options);
      
      this.mediaRecorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          this.recordedChunks.push(event.data);
        }
      };

      this.mediaRecorder.onstop = () => {
        this.recordedBlob = new Blob(this.recordedChunks, { type: 'video/webm' });
        this.showPreview();
      };

      this.mediaRecorder.start(1000); // Collect data every second
      console.log('Recording started');

    } catch (error) {
      console.error('Failed to start recording:', error);
      this.pushEvent('camera_error', { 
        error: 'RecordingError', 
        message: 'Failed to start recording. Please try again.' 
      });
    }
  },

  stopRecording() {
    if (this.mediaRecorder && this.mediaRecorder.state !== 'inactive') {
      this.mediaRecorder.stop();
      console.log('Recording stopped');
    }
  },

  showPreview() {
    const previewElement = document.getElementById('playback-video');
    const loadingElement = document.getElementById('video-loading');
    
    if (previewElement && this.recordedBlob) {
      const url = URL.createObjectURL(this.recordedBlob);
      previewElement.src = url;
      
      previewElement.onloadeddata = () => {
        if (loadingElement) {
          loadingElement.style.display = 'none';
        }
      };
    }
  },

  resetForRetake() {
    // Clean up previous recording
    if (this.recordedBlob) {
      URL.revokeObjectURL(this.recordedBlob);
      this.recordedBlob = null;
    }
    
    this.recordedChunks = [];
    
    // Reset video elements
    const previewElement = document.getElementById('playback-video');
    const loadingElement = document.getElementById('video-loading');
    
    if (previewElement) {
      previewElement.src = '';
    }
    
    if (loadingElement) {
      loadingElement.style.display = 'flex';
    }
  },

  async uploadVideo() {
    if (!this.recordedBlob) {
      console.error('No recorded video to upload');
      return;
    }

    try {
      // Convert blob to base64 for sending to LiveView
      const arrayBuffer = await this.recordedBlob.arrayBuffer();
      const uint8Array = new Uint8Array(arrayBuffer);
      const binaryString = uint8Array.reduce((data, byte) => data + String.fromCharCode(byte), '');
      const base64String = btoa(binaryString);

      // Send to LiveView
      this.pushEvent('video_blob_ready', {
        blob_data: base64String,
        mime_type: this.recordedBlob.type,
        file_size: this.recordedBlob.size
      });

    } catch (error) {
      console.error('Upload failed:', error);
      this.pushEvent('camera_error', { 
        error: 'UploadError', 
        message: 'Failed to upload video. Please try again.' 
      });
    }
  },

  cleanup() {
    if (this.stream) {
      this.stream.getTracks().forEach(track => track.stop());
      this.stream = null;
    }
    
    if (this.recordedBlob) {
      URL.revokeObjectURL(this.recordedBlob);
      this.recordedBlob = null;
    }
    
    this.recordedChunks = [];
  }
};


// assets/js/app.js

// Import Phoenix and LiveView
import "phoenix_html"
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import topbar from "../vendor/topbar"

// Import existing hooks
import SessionHooks from "./hooks/session_hooks"
import StudioHooks from "./hooks/studio_hooks"
import { MobileAudioHook } from "./hooks/mobile_audio_hook"
import { 
  AudioTrack, 
  WaveformCanvas, 
  LiveWaveform, 
  MobileWaveform, 
  BeatMachine, 
  MobileLiveWaveform, 
  TakeWaveform 
} from "./hooks/audio_workspace_hooks"

// Import new audio effects hooks
import { 
  EffectsIntegrationHook, 
  EffectVisualization 
} from "./hooks/effects_integration_hook"

// Import audio engines (make them globally available)
import { AudioEngine } from "./audio/audio_engine"
import { EnhancedEffectsEngine } from "./audio/enhanced_effects_engine"
import { StudioAudioClient } from "./studio/audio_client"

// Make audio engines globally available for integration
window.AudioEngine = AudioEngine;
window.EnhancedEffectsEngine = EnhancedEffectsEngine;
window.StudioAudioClient = StudioAudioClient;

// CSRF token setup
let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

// Combine all hooks
let Hooks = {
  // Session and general hooks
  ...SessionHooks,
  
  // Studio hooks
  ...StudioHooks,
  
  // Audio workspace hooks
  AudioTrack,
  WaveformCanvas,
  LiveWaveform,
  MobileWaveform,
  BeatMachine,
  MobileLiveWaveform,
  TakeWaveform,
  
  // Mobile audio hook
  MobileAudioHook,
  
  // NEW: Audio effects hooks
  EffectsIntegrationHook,
  EffectVisualization,
  
  // Audio Track Manager hook for effects integration
  AudioTrackManager: {
    mounted() {
      this.trackId = this.el.dataset.trackId;
      this.sessionId = this.el.dataset.sessionId;
      
      // Initialize audio engine if not already initialized
      this.initializeAudioEngine();
      
      // Setup track-specific effects management
      this.setupTrackEffects();
    },
    
    async initializeAudioEngine() {
      if (!window.audioEngine) {
        try {
          window.audioEngine = new AudioEngine({
            sampleRate: 48000,
            bufferSize: 256,
            enableEffects: true,
            enableMonitoring: true,
            maxTracks: 8
          });
          
          await window.audioEngine.initialize();
          console.log('Global audio engine initialized');
          
          // Make it available to effects hooks
          window.dispatchEvent(new CustomEvent('audio-engine-ready', {
            detail: { audioEngine: window.audioEngine }
          }));
          
        } catch (error) {
          console.error('Failed to initialize global audio engine:', error);
        }
      }
    },
    
    setupTrackEffects() {
      // Listen for effect-related events from LiveView
      this.handleEvent('effect_added', (data) => {
        this.addEffectToTrack(data);
      });
      
      this.handleEvent('effect_removed', (data) => {
        this.removeEffectFromTrack(data);
      });
      
      this.handleEvent('effect_parameter_updated', (data) => {
        this.updateEffectParameter(data);
      });
      
      this.handleEvent('effect_preset_applied', (data) => {
        this.applyEffectPreset(data);
      });
    },
    
    addEffectToTrack(data) {
      const { trackId, effectType, effectParams } = data;
      
      if (window.audioEngine && trackId === this.trackId) {
        try {
          const effectId = window.audioEngine.addEffectToTrack(trackId, effectType, effectParams);
          
          this.pushEvent('effect_added_success', {
            track_id: trackId,
            effect_id: effectId,
            effect_type: effectType
          });
          
        } catch (error) {
          console.error('Failed to add effect:', error);
          this.pushEvent('effect_added_error', {
            track_id: trackId,
            error: error.message
          });
        }
      }
    },
    
    removeEffectFromTrack(data) {
      const { trackId, effectId } = data;
      
      if (window.audioEngine && trackId === this.trackId) {
        try {
          window.audioEngine.removeEffectFromTrack(trackId, effectId);
          
          this.pushEvent('effect_removed_success', {
            track_id: trackId,
            effect_id: effectId
          });
          
        } catch (error) {
          console.error('Failed to remove effect:', error);
        }
      }
    },
    
    updateEffectParameter(data) {
      const { trackId, effectId, paramName, value } = data;
      
      if (window.audioEngine && trackId === this.trackId) {
        try {
          // Use enhanced effects engine if available
          if (window.audioEngine.updateEffectParameter) {
            window.audioEngine.updateEffectParameter(effectId, paramName, value, { smooth: true });
          }
          
        } catch (error) {
          console.error('Failed to update effect parameter:', error);
        }
      }
    },
    
    applyEffectPreset(data) {
      const { trackId, presetName } = data;
      
      if (window.audioEngine && trackId === this.trackId) {
        try {
          // Use enhanced effects engine preset system
          if (window.audioEngine.applyEffectPreset) {
            const appliedEffects = window.audioEngine.applyEffectPreset(trackId, presetName);
            
            this.pushEvent('effect_preset_applied_success', {
              track_id: trackId,
              preset_name: presetName,
              applied_effects: appliedEffects
            });
          }
          
        } catch (error) {
          console.error('Failed to apply effect preset:', error);
          this.pushEvent('effect_preset_applied_error', {
            track_id: trackId,
            error: error.message
          });
        }
      }
    }
  },

  // ENHANCED HOOKS DEFINITION
const Hooks = {
  // Section Sortable Hook - for drag-and-drop section reordering
  SectionSortable: {
    mounted() {
      console.log('SectionSortable hook mounted', this.el);
      this.initializeSortable();
    },

    updated() {
      console.log('SectionSortable hook updated');
      this.destroySortable();
      this.initializeSortable();
    },

    destroyed() {
      console.log('SectionSortable hook destroyed');
      this.destroySortable();
    },

    initializeSortable() {
      if (typeof Sortable === 'undefined') {
        console.error('Sortable library not found. Please install SortableJS.');
        return;
      }

      this.destroySortable();

      this.sortable = new Sortable(this.el, {
        animation: 200,
        ghostClass: 'sortable-ghost',
        chosenClass: 'sortable-chosen',
        dragClass: 'sortable-drag',
        handle: '.drag-handle',
        forceFallback: true,
        
        onStart: (evt) => {
          console.log('Drag started');
          evt.item.classList.add('dragging');
          document.body.classList.add('sections-reordering');
        },

        onEnd: (evt) => {
          console.log('Drag ended');
          evt.item.classList.remove('dragging');
          document.body.classList.remove('sections-reordering');
          
          const sectionIds = Array.from(this.el.children)
            .map(child => child.getAttribute('data-section-id'))
            .filter(Boolean);

          console.log('New section order:', sectionIds);
          this.pushEvent('reorder_sections', { sections: sectionIds });
        }
      });

      console.log('SectionSortable initialized successfully');
    },

    destroySortable() {
      if (this.sortable) {
        this.sortable.destroy();
        this.sortable = null;
      }
    }
  },

  // Media Sortable Hook - for drag-and-drop media reordering
  MediaSortable: {
    mounted() {
      console.log('MediaSortable hook mounted', this.el);
      this.initializeSortable();
    },

    updated() {
      this.destroySortable();
      this.initializeSortable();
    },

    destroyed() {
      this.destroySortable();
    },

    initializeSortable() {
      if (typeof Sortable === 'undefined') return;

      this.destroySortable();

      this.sortable = new Sortable(this.el, {
        animation: 150,
        ghostClass: 'sortable-ghost',
        chosenClass: 'sortable-chosen',
        dragClass: 'sortable-drag',
        
        onEnd: (evt) => {
          const sectionId = this.el.getAttribute('data-section-id');
          const mediaIds = Array.from(this.el.children)
            .map(child => child.getAttribute('data-media-id'))
            .filter(Boolean);

          console.log('Media reordered:', mediaIds);
          this.pushEvent('reorder_media', { 
            section_id: sectionId, 
            media_order: mediaIds 
          });
        }
      });
    },

    destroySortable() {
      if (this.sortable) {
        this.sortable.destroy();
        this.sortable = null;
      }
    }
  },

  // File Upload Hook - for enhanced file upload handling
  FileUpload: {
    mounted() {
      console.log('FileUpload hook mounted');
      this.el.addEventListener('change', this.handleFileSelect.bind(this));
    },

    handleFileSelect(event) {
      const files = Array.from(event.target.files);
      console.log('Files selected:', files.length);
      
      const maxSize = 50 * 1024 * 1024; // 50MB
      const validFiles = files.filter(file => file.size <= maxSize);
      
      if (validFiles.length !== files.length) {
        alert(`Some files were too large. Maximum size is 50MB.`);
      }
    }
  },

  // File Upload Zone Hook - for drag-and-drop file uploads
  FileUploadZone: {
    mounted() {
      console.log('FileUploadZone hook mounted');
      
      this.el.addEventListener('dragover', this.handleDragOver.bind(this));
      this.el.addEventListener('dragleave', this.handleDragLeave.bind(this));
      this.el.addEventListener('drop', this.handleDrop.bind(this));
    },

    handleDragOver(event) {
      event.preventDefault();
      this.el.classList.add('drag-over');
    },

    handleDragLeave(event) {
      event.preventDefault();
      this.el.classList.remove('drag-over');
    },

    handleDrop(event) {
      event.preventDefault();
      this.el.classList.remove('drag-over');
      
      const files = Array.from(event.dataTransfer.files);
      console.log('Files dropped:', files.length);
      
      const fileInput = this.el.querySelector('input[type="file"]');
      if (fileInput) {
        fileInput.files = event.dataTransfer.files;
        fileInput.dispatchEvent(new Event('change', { bubbles: true }));
      }
    }
  },

  // Auto Focus Hook - for modal inputs
  AutoFocus: {
    mounted() {
      setTimeout(() => {
        this.el.focus();
      }, 100);
    }
  },

  // Copy to Clipboard Hook
  CopyToClipboard: {
    mounted() {
      this.handleEvent('copy_to_clipboard', (payload) => {
        navigator.clipboard.writeText(payload.text).then(() => {
          console.log('Text copied to clipboard');
        }).catch(err => {
          console.error('Failed to copy text: ', err);
        });
      });
    }
  },

  // Video Capture Hook - for video intro recording
  VideoCapture: {
    mounted() {
      console.log('VideoCapture hook mounted');
      this.componentId = this.el.getAttribute('data-component-id');
      this.stream = null;
      this.mediaRecorder = null;
      this.recordedChunks = [];
      
      this.initializeCamera();
    },

    destroyed() {
      this.cleanup();
    },

    async initializeCamera() {
      try {
        const preview = document.getElementById('camera-preview');
        if (!preview) return;

        this.stream = await navigator.mediaDevices.getUserMedia({
          video: {
            width: { ideal: 1280 },
            height: { ideal: 720 },
            frameRate: { ideal: 30 }
          },
          audio: true
        });

        preview.srcObject = this.stream;
        this.pushEventTo(`#video-capture-${this.componentId}`, 'camera_ready', {});
        
      } catch (error) {
        console.error('Camera access failed:', error);
        this.pushEventTo(`#video-capture-${this.componentId}`, 'camera_error', {
          error: error.name,
          message: error.message
        });
      }
    },

    cleanup() {
      if (this.stream) {
        this.stream.getTracks().forEach(track => track.stop());
      }
      if (this.mediaRecorder) {
        this.mediaRecorder = null;
      }
    }
  }
},

  
  // Effects Parameter Control hook for real-time sliders
  EffectParameterControl: {
    mounted() {
      this.effectId = this.el.dataset.effectId;
      this.paramName = this.el.dataset.paramName;
      this.trackId = this.el.dataset.trackId;
      
      // Setup real-time parameter updates
      this.setupParameterControl();
    },
    
    setupParameterControl() {
      let updateTimeout;
      
      // Handle input events for real-time updates
      this.el.addEventListener('input', (event) => {
        const value = this.parseValue(event.target.value);
        
        // Update audio engine immediately for real-time feel
        if (window.audioEngine?.updateEffectParameter) {
          window.audioEngine.updateEffectParameter(this.effectId, this.paramName, value, {
            smooth: true,
            transitionTime: 0.01
          });
        }
        
        // Throttle LiveView updates to avoid spam
        clearTimeout(updateTimeout);
        updateTimeout = setTimeout(() => {
          this.pushEvent('effect_parameter_changed', {
            track_id: this.trackId,
            effect_id: this.effectId,
            param_name: this.paramName,
            value: value
          });
        }, 50); // 20fps update rate to LiveView
      });
      
      // Handle change events for final value
      this.el.addEventListener('change', (event) => {
        const value = this.parseValue(event.target.value);
        
        this.pushEvent('effect_parameter_final', {
          track_id: this.trackId,
          effect_id: this.effectId,
          param_name: this.paramName,
          value: value
        });
      });
    },
    
    parseValue(stringValue) {
      // Parse value based on parameter type
      if (this.el.type === 'checkbox') {
        return this.el.checked;
      } else if (this.el.type === 'range' || this.el.type === 'number') {
        return parseFloat(stringValue);
      } else {
        return stringValue;
      }
    }
  },
  
  // CPU Usage Monitor hook
  CPUUsageMonitor: {
    mounted() {
      this.updateInterval = setInterval(() => {
        this.updateCPUUsage();
      }, 1000); // Update every second
    },
    
    updateCPUUsage() {
      if (window.audioEngine?.calculateCPUUsage) {
        const cpuUsage = window.audioEngine.calculateCPUUsage();
        
        // Update UI
        const bar = this.el.querySelector('.cpu-bar');
        const text = this.el.querySelector('.cpu-text');
        
        if (bar) {
          bar.style.width = `${cpuUsage}%`;
          bar.className = `cpu-bar transition-all duration-200 ${
            cpuUsage > 80 ? 'bg-red-500' : 
            cpuUsage > 60 ? 'bg-yellow-500' : 'bg-green-500'
          }`;
        }
        
        if (text) {
          text.textContent = `${Math.round(cpuUsage)}%`;
        }
        
        // Send to LiveView for server-side monitoring
        this.pushEvent('cpu_usage_update', {
          cpu_usage: cpuUsage,
          timestamp: Date.now()
        });
      }
    },
    
    destroyed() {
      if (this.updateInterval) {
        clearInterval(this.updateInterval);
      }
    }
  }
};

// LiveSocket configuration with enhanced options for audio
let liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: Hooks,
  
  // Enhanced configuration for audio applications
  longPollFallbackMs: 2500,
  heartbeatIntervalMs: 30000,
  
  // Custom metadata for audio synchronization
  metadata: {
    click: (e, el) => {
      return {
        altKey: e.altKey,
        shiftKey: e.shiftKey,
        ctrlKey: e.ctrlKey,
        metaKey: e.metaKey,
        detail: e.detail || 1,
        // Add audio context timing for synchronization
        audioTime: window.audioEngine?.audioContext?.currentTime || 0
      }
    },
    
    keydown: (e, el) => {
      return {
        key: e.key,
        altKey: e.altKey,
        shiftKey: e.shiftKey,
        ctrlKey: e.ctrlKey,
        metaKey: e.metaKey,
        // Audio timing for keyboard shortcuts
        audioTime: window.audioEngine?.audioContext?.currentTime || 0
      }
    }
  },
  
  // DOM patching configuration optimized for audio UI
  dom: {
    onBeforeElUpdated(from, to) {
      // Preserve audio-related input states during updates
      if (from._x_dataStack) { from._x_dataStack = undefined }
      
      // Preserve audio parameter control states
      if (from.hasAttribute('data-effect-param')) {
        if (from.type === 'range' && from.value !== to.value) {
          // Don't update range inputs that are being actively dragged
          if (from === document.activeElement && from.matches(':focus')) {
            to.value = from.value;
          }
        }
      }
      
      // Preserve audio visualization canvas states
      if (from.tagName === 'CANVAS' && from.hasAttribute('data-effect-visualization')) {
        // Don't replace canvases that are actively rendering
        return false;
      }
      
      return true;
    }
  }
});

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" })
window.addEventListener("phx:page-loading-start", info => topbar.show())
window.addEventListener("phx:page-loading-stop", info => topbar.hide())

// Global error handling for audio engine
window.addEventListener('error', (event) => {
  if (event.error && event.error.message.includes('audio')) {
    console.error('Audio engine error:', event.error);
    
    // Notify LiveView of audio errors
    if (liveSocket.isConnected()) {
      liveSocket.pushEvent('audio_engine_error', {
        error: event.error.message,
        stack: event.error.stack,
        timestamp: Date.now()
      });
    }
  }
});

// Enhanced audio context management
window.addEventListener('click', () => {
  // Resume audio context on first user interaction (browser requirement)
  if (window.audioEngine?.audioContext?.state === 'suspended') {
    window.audioEngine.audioContext.resume().then(() => {
      console.log('Audio context resumed after user interaction');
    });
  }
}, { once: true });

// Make LiveSocket globally available for audio integration
window.liveSocket = liveSocket;

// Connect LiveSocket
liveSocket.connect()

// Expose connect/disconnect for debugging
window.liveSocket = liveSocket

// Audio context state monitoring
if ('AudioContext' in window || 'webkitAudioContext' in window) {
  document.addEventListener('click', async () => {
    // Resume audio context on first user interaction
    if (window.audioEngine && window.audioEngine.audioContext) {
      if (window.audioEngine.audioContext.state === 'suspended') {
        try {
          await window.audioEngine.audioContext.resume();
          console.log('AudioContext resumed after user interaction');
        } catch (error) {
          console.error('Failed to resume AudioContext:', error);
        }
      }
    }
  }, { once: false });
}

// Enhanced global styles with audio-specific animations
const globalStyles = `
  @keyframes ripple {
    to {
      transform: scale(4);
      opacity: 0;
    }
  }

  @keyframes fadeInUp {
    from {
      opacity: 0;
      transform: translateY(30px);
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }

  @keyframes slideInRight {
    from {
      opacity: 0;
      transform: translateX(30px);
    }
    to {
      opacity: 1;
      transform: translateX(0);
    }
  }

  @keyframes pulse {
    0%, 100% {
      opacity: 1;
    }
    50% {
      opacity: 0.5;
    }
  }

  @keyframes audioLevel {
    0% {
      transform: scaleY(0.1);
    }
    50% {
      transform: scaleY(1);
    }
    100% {
      transform: scaleY(0.1);
    }
  }

  @keyframes recordingPulse {
    0%, 100% {
      opacity: 1;
      transform: scale(1);
    }
    50% {
      opacity: 0.7;
      transform: scale(1.1);
    }
  }

  .searching {
    animation: pulse 1.5s ease-in-out infinite;
  }

  .drag-over {
    transform: scale(1.02);
    border-color: #3b82f6 !important;
    background-color: rgba(59, 130, 246, 0.1) !important;
  }

  .notification.show {
    animation: slideInRight 0.3s ease-out;
  }

  .notification.hide {
    animation: slideInRight 0.3s ease-out reverse;
  }

  .fade-in {
    animation: fadeInUp 0.6s ease-out;
  }

  /* Audio-specific styles */
  .audio-track {
    transition: all 0.3s cubic-bezier(0.4, 0.0, 0.2, 1);
  }

  .audio-track.recording {
    box-shadow: 0 0 20px rgba(239, 68, 68, 0.3);
    border-color: #ef4444;
  }

  .audio-track:hover {
    transform: translateY(-2px);
    box-shadow: 0 8px 25px rgba(0, 0, 0, 0.15);
  }

  .track-level-meter {
    overflow: hidden;
    background: linear-gradient(90deg, #10b981 0%, #f59e0b 70%, #ef4444 100%);
  }

  .track-level-fill {
    transition: width 0.1s ease-out;
    background: linear-gradient(90deg, #10b981 0%, #f59e0b 70%, #ef4444 100%);
  }

  .recording-indicator {
    animation: recordingPulse 1s ease-in-out infinite;
  }

  .audio-waveform {
    display: flex;
    align-items: end;
    height: 40px;
    gap: 1px;
  }

  .audio-waveform-bar {
    background: #3b82f6;
    min-height: 2px;
    width: 2px;
    transition: height 0.1s ease-out;
    animation: audioLevel 0.5s ease-in-out infinite;
  }

  .audio-effect-chain {
    display: flex;
    gap: 8px;
    padding: 8px;
    background: rgba(55, 65, 81, 0.5);
    border-radius: 6px;
    margin-top: 8px;
  }

  .audio-effect {
    background: #374151;
    padding: 4px 8px;
    border-radius: 4px;
    font-size: 12px;
    color: #d1d5db;
    border: 1px solid #4b5563;
    transition: all 0.2s ease;
  }

  .audio-effect:hover {
    background: #4b5563;
    border-color: #6b7280;
  }

  .audio-effect.active {
    background: #3b82f6;
    border-color: #2563eb;
    color: white;
  }

  /* Transport controls */
  .transport-controls {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 16px;
    background: #1f2937;
    border-radius: 8px;
    border: 1px solid #374151;
  }

  .transport-button {
    background: #374151;
    border: 1px solid #4b5563;
    color: #d1d5db;
    padding: 8px 12px;
    border-radius: 6px;
    cursor: pointer;
    transition: all 0.2s ease;
  }

  .transport-button:hover {
    background: #4b5563;
    border-color: #6b7280;
  }

  .transport-button.active {
    background: #3b82f6;
    border-color: #2563eb;
    color: white;
  }

  .transport-button.recording {
    background: #ef4444;
    border-color: #dc2626;
    color: white;
    animation: recordingPulse 1s ease-in-out infinite;
  }

  /* Master section */
  .master-section {
    background: #111827;
    border: 2px solid #374151;
    border-radius: 8px;
    padding: 16px;
  }

  .master-level-meter {
    height: 8px;
    background: #374151;
    border-radius: 4px;
    overflow: hidden;
    margin: 8px 0;
  }

  .master-level-fill {
    height: 100%;
    background: linear-gradient(90deg, #10b981 0%, #f59e0b 70%, #ef4444 100%);
    transition: width 0.1s ease-out;
  }

  /* Collaborator indicators */
  .collaborator-indicator {
    position: relative;
    display: inline-block;
    width: 32px;
    height: 32px;
    border-radius: 50%;
    background: #374151;
    border: 2px solid #4b5563;
    overflow: hidden;
  }

  .collaborator-indicator.active {
    border-color: #10b981;
    box-shadow: 0 0 8px rgba(16, 185, 129, 0.3);
  }

  .collaborator-indicator.speaking {
    border-color: #3b82f6;
    box-shadow: 0 0 12px rgba(59, 130, 246, 0.5);
    animation: pulse 1s ease-in-out infinite;
  }

  /* Search results */
  .search-results {
    max-height: 0;
    overflow: hidden;
    transition: max-height 0.3s ease-out;
  }

  .search-results.show {
    max-height: 400px;
  }

  .focused {
    box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
  }

  /* Custom scrollbar */
  ::-webkit-scrollbar {
    width: 8px;
  }

  ::-webkit-scrollbar-track {
    background: rgba(255, 255, 255, 0.1);
    border-radius: 4px;
  }

  ::-webkit-scrollbar-thumb {
    background: rgba(255, 255, 255, 0.3);
    border-radius: 4px;
  }

  ::-webkit-scrollbar-thumb:hover {
    background: rgba(255, 255, 255, 0.5);
  }

  /* Smooth transitions for all interactive elements */
  button, .btn, .card, .media-node, .audio-track {
    transition: all 0.3s cubic-bezier(0.4, 0.0, 0.2, 1);
  }

  /* Enhanced focus states for accessibility */
  button:focus-visible,
  input:focus-visible,
  select:focus-visible {
    outline: 2px solid #3b82f6;
    outline-offset: 2px;
  }

  /* Audio file upload specific styles */
  .audio-file-preview {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    border-radius: 8px;
    padding: 16px;
    color: white;
  }

  .audio-file-preview audio {
    width: 100%;
    margin-top: 8px;
    border-radius: 4px;
  }

  /* WebRTC connection status */
  .rtc-status {
    position: fixed;
    top: 20px;
    right: 20px;
    z-index: 1000;
    background: #1f2937;
    border: 1px solid #374151;
    border-radius: 6px;
    padding: 8px 12px;
    color: #d1d5db;
    font-size: 12px;
  }

  .rtc-status.connected {
    border-color: #10b981;
    color: #10b981;
  }

  .rtc-status.connecting {
    border-color: #f59e0b;
    color: #f59e0b;
  }

  .rtc-status.disconnected {
    border-color: #ef4444;
    color: #ef4444;
  }

  /* Mobile responsive adjustments */
  @media (max-width: 768px) {
    .audio-track {
      padding: 12px;
    }
    
    .transport-controls {
      flex-wrap: wrap;
      gap: 8px;
    }
    
    .transport-button {
      padding: 6px 10px;
      font-size: 14px;
    }
    
    .audio-effect-chain {
      flex-wrap: wrap;
    }
  }
`;

// Inject enhanced global styles
const styleSheet = document.createElement('style');
styleSheet.textContent = globalStyles;
document.head.appendChild(styleSheet);

// Initialize audio engine when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
  // Check if we're in an audio-enabled context
  const audioEnabledElements = document.querySelectorAll('[data-audio-engine]');
  
  if (audioEnabledElements.length > 0) {
    console.log('Audio-enabled context detected, preparing audio engine');
    
    // Set up global audio engine initialization
    window.initializeGlobalAudioEngine = async (config = {}) => {
      if (!window.audioEngine) {
        try {
          window.audioEngine = new AudioEngine(config);
          await window.audioEngine.initialize();
          
          // Dispatch global event
          window.dispatchEvent(new CustomEvent('audio-engine-ready', {
            detail: { audioEngine: window.audioEngine }
          }));
          
          console.log('Global audio engine initialized');
        } catch (error) {
          console.error('Failed to initialize global audio engine:', error);
        }
      }
      return window.audioEngine;
    };
  }
});

// Cleanup on page unload
window.addEventListener('beforeunload', () => {
  if (window.audioEngine) {
    window.audioEngine.destroy();
  }
  if (window.rtcClient) {
    window.rtcClient.cleanup();
  }
});

console.log('Enhanced Frestyl app.js loaded with audio engine integration');