// assets/js/audio/audio_engine.js
export class AudioEngine {
  constructor(options = {}) {
    this.options = {
      sampleRate: 44100,
      bufferSize: 256,
      enableEffects: true,
      enableMonitoring: true,
      maxTracks: 8,
      ...options
    };

    // Core Web Audio components
    this.audioContext = null;
    this.masterGain = null;
    this.analyzer = null;
    this.compressor = null;
    
    // Track management
    this.tracks = new Map();
    this.trackCounter = 0;
    
    // Effects and processing
    this.effects = new Map();
    this.effectChains = new Map();
    
    // Recording and playback
    this.isRecording = false;
    this.isPlaying = false;
    this.recordingNodes = new Map();
    this.playbackPosition = 0;
    
    // Collaboration and sync
    this.collaborators = new Map();
    this.rtcConnections = new Map();
    
    // Monitoring and analysis
    this.inputAnalyzer = null;
    this.outputAnalyzer = null;
    this.vuMeters = new Map();
    
    // Event system
    this.eventListeners = new Map();
    
    // Integration with existing WebRTC
    this.rtcClient = null;
    
    // State synchronization
    this.lastSyncTime = 0;
    this.syncInterval = null;
    
    this.initialize();
  }

  async initialize() {
    try {
      // Initialize Web Audio Context
      this.audioContext = new (window.AudioContext || window.webkitAudioContext)({
        sampleRate: this.options.sampleRate,
        latencyHint: 'interactive'
      });

      // Resume context if suspended (browser autoplay policy)
      if (this.audioContext.state === 'suspended') {
        await this.audioContext.resume();
      }

      // Create master audio graph
      await this.createMasterGraph();
      
      // Initialize effects library
      this.initializeEffects();
      
      // Set up monitoring
      if (this.options.enableMonitoring) {
        this.setupMonitoring();
      }
      
      // Emit initialization event
      this.emit('initialized', {
        sampleRate: this.audioContext.sampleRate,
        state: this.audioContext.state
      });
      
      console.log('AudioEngine initialized successfully');
    } catch (error) {
      console.error('Failed to initialize AudioEngine:', error);
      this.emit('error', { type: 'initialization', error });
    }
  }

  async createMasterGraph() {
    // Master gain control
    this.masterGain = this.audioContext.createGain();
    this.masterGain.gain.value = 0.8;

    // Master compressor for output limiting
    this.compressor = this.audioContext.createDynamicsCompressor();
    this.compressor.threshold.value = -12;
    this.compressor.knee.value = 5;
    this.compressor.ratio.value = 8;
    this.compressor.attack.value = 0.003;
    this.compressor.release.value = 0.1;

    // Master analyzer for output monitoring
    this.analyzer = this.audioContext.createAnalyser();
    this.analyzer.fftSize = 2048;
    this.analyzer.smoothingTimeConstant = 0.8;

    // Connect master chain
    this.masterGain.connect(this.compressor);
    this.compressor.connect(this.analyzer);
    this.analyzer.connect(this.audioContext.destination);
  }

  initializeEffects() {
    // Register built-in effects
    this.registerEffect('reverb', ReverbEffect);
    this.registerEffect('delay', DelayEffect);
    this.registerEffect('chorus', ChorusEffect);
    this.registerEffect('distortion', DistortionEffect);
    this.registerEffect('filter', FilterEffect);
    this.registerEffect('eq', EQEffect);
    this.registerEffect('compressor', CompressorEffect);
    this.registerEffect('gate', GateEffect);
  }

  setupMonitoring() {
    // Input monitoring for recording levels
    this.inputAnalyzer = this.audioContext.createAnalyser();
    this.inputAnalyzer.fftSize = 512;
    this.inputAnalyzer.smoothingTimeConstant = 0.3;

    // Output monitoring for master levels
    this.outputAnalyzer = this.audioContext.createAnalyser();
    this.outputAnalyzer.fftSize = 512;
    this.outputAnalyzer.smoothingTimeConstant = 0.3;
    
    // Connect output analyzer to master
    this.analyzer.connect(this.outputAnalyzer);

    // Start monitoring loop
    this.startMonitoringLoop();
  }

  startMonitoringLoop() {
    const updateMeters = () => {
      if (!this.audioContext || this.audioContext.state !== 'running') {
        return;
      }

      // Update VU meters for all tracks
      this.tracks.forEach((track, trackId) => {
        if (track.analyzer) {
          const level = this.getAudioLevel(track.analyzer);
          this.emit('track_level_update', { trackId, level });
        }
      });

      // Update master level
      if (this.outputAnalyzer) {
        const masterLevel = this.getAudioLevel(this.outputAnalyzer);
        this.emit('master_level_update', { level: masterLevel });
      }

      // Continue monitoring
      requestAnimationFrame(updateMeters);
    };

    updateMeters();
  }

  getAudioLevel(analyzer) {
    const bufferLength = analyzer.frequencyBinCount;
    const dataArray = new Uint8Array(bufferLength);
    analyzer.getByteFrequencyData(dataArray);

    let sum = 0;
    for (let i = 0; i < bufferLength; i++) {
      sum += dataArray[i];
    }
    
    return (sum / bufferLength) / 255;
  }

  // Track Management
  async createTrack(options = {}) {
    const trackId = `track_${++this.trackCounter}`;
    
    const track = {
      id: trackId,
      name: options.name || `Track ${this.trackCounter}`,
      input: null,
      gain: this.audioContext.createGain(),
      pan: this.audioContext.createStereoPanner(),
      analyzer: this.audioContext.createAnalyser(),
      effects: [],
      muted: false,
      solo: false,
      armed: false,
      monitoring: false,
      volume: options.volume || 0.8,
      panValue: options.pan || 0,
      color: options.color || this.generateTrackColor(),
      clips: [],
      inputSource: options.inputSource || 'microphone'
    };

    // Set initial values
    track.gain.gain.value = track.volume;
    track.pan.pan.value = track.panValue;
    
    // Configure analyzer
    track.analyzer.fftSize = 512;
    track.analyzer.smoothingTimeConstant = 0.8;

    // Create effect chain for track
    this.createTrackEffectChain(track);

    // Store track
    this.tracks.set(trackId, track);

    // Connect to input if specified
    if (options.connectInput) {
      await this.connectTrackInput(trackId, options.inputSource);
    }

    this.emit('track_created', { track });
    return track;
  }

  createTrackEffectChain(track) {
    // Create effect chain: input → effects → gain → pan → analyzer → master
    let currentNode = track.gain;
    
    // Connect effects in series (will be populated when effects are added)
    track.effectChain = {
      input: track.gain,
      output: track.pan
    };

    // Connect pan to analyzer to master
    track.pan.connect(track.analyzer);
    track.analyzer.connect(this.masterGain);
  }

  async connectTrackInput(trackId, inputSource) {
    const track = this.tracks.get(trackId);
    if (!track) throw new Error(`Track ${trackId} not found`);

    try {
      let inputNode;

      switch (inputSource) {
        case 'microphone':
          const stream = await navigator.mediaDevices.getUserMedia({ 
            audio: {
              echoCancellation: false,
              noiseSuppression: false,
              autoGainControl: false,
              latency: 0.01,
              sampleRate: this.audioContext.sampleRate
            } 
          });
          inputNode = this.audioContext.createMediaStreamSource(stream);
          track.inputStream = stream;
          break;

        case 'system':
          const displayStream = await navigator.mediaDevices.getDisplayMedia({ 
            audio: true 
          });
          inputNode = this.audioContext.createMediaStreamSource(displayStream);
          track.inputStream = displayStream;
          break;

        case 'file':
          // Will be connected when file is loaded
          break;

        default:
          throw new Error(`Unknown input source: ${inputSource}`);
      }

      if (inputNode) {
        // Connect input to track chain
        track.input = inputNode;
        
        // Connect input monitoring if enabled
        if (this.inputAnalyzer) {
          inputNode.connect(this.inputAnalyzer);
        }

        // Connect to track processing chain
        inputNode.connect(track.effectChain.input);
        
        this.emit('track_input_connected', { trackId, inputSource });
      }
    } catch (error) {
      console.error(`Failed to connect input for track ${trackId}:`, error);
      this.emit('error', { type: 'input_connection', trackId, error });
    }
  }

  // Audio Effects System
  registerEffect(type, effectClass) {
    this.effects.set(type, effectClass);
  }

  addEffectToTrack(trackId, effectType, params = {}) {
    const track = this.tracks.get(trackId);
    if (!track) throw new Error(`Track ${trackId} not found`);

    const EffectClass = this.effects.get(effectType);
    if (!EffectClass) throw new Error(`Effect type ${effectType} not found`);

    const effect = new EffectClass(this.audioContext, params);
    const effectId = `${trackId}_${effectType}_${Date.now()}`;

    // Add to track's effect list
    track.effects.push({
      id: effectId,
      type: effectType,
      instance: effect,
      enabled: true,
      params
    });

    // Rebuild effect chain
    this.rebuildTrackEffectChain(track);
    
    this.emit('effect_added', { trackId, effectId, effectType, params });
    return effectId;
  }

  removeEffectFromTrack(trackId, effectId) {
    const track = this.tracks.get(trackId);
    if (!track) return;

    const effectIndex = track.effects.findIndex(e => e.id === effectId);
    if (effectIndex === -1) return;

    // Disconnect and cleanup effect
    const effect = track.effects[effectIndex];
    if (effect.instance.disconnect) {
      effect.instance.disconnect();
    }

    // Remove from track
    track.effects.splice(effectIndex, 1);

    // Rebuild effect chain
    this.rebuildTrackEffectChain(track);
    
    this.emit('effect_removed', { trackId, effectId });
  }

  rebuildTrackEffectChain(track) {
    // Disconnect existing chain
    track.effectChain.input.disconnect();
    
    // Rebuild chain with current effects
    let currentNode = track.effectChain.input;
    
    for (const effect of track.effects) {
      if (effect.enabled && effect.instance.input) {
        currentNode.connect(effect.instance.input);
        currentNode = effect.instance.output;
      }
    }
    
    // Connect final node to track output
    currentNode.connect(track.effectChain.output);
  }

  // Recording System
  async startRecording(trackId) {
    const track = this.tracks.get(trackId);
    if (!track || !track.input) {
      throw new Error(`Cannot record: track ${trackId} has no input`);
    }

    // Create recorder for track
    const recorder = this.audioContext.createScriptProcessor(this.options.bufferSize, 2, 2);
    const recordedBuffers = [];
    
    recorder.onaudioprocess = (event) => {
      if (this.isRecording) {
        const inputBuffer = event.inputBuffer;
        const bufferData = {
          left: new Float32Array(inputBuffer.getChannelData(0)),
          right: inputBuffer.getChannelData(1) || inputBuffer.getChannelData(0),
          timestamp: this.audioContext.currentTime
        };
        recordedBuffers.push(bufferData);
      }
    };

    // Connect recorder to track
    track.analyzer.connect(recorder);
    recorder.connect(this.audioContext.destination);

    this.recordingNodes.set(trackId, {
      recorder,
      buffers: recordedBuffers,
      startTime: this.audioContext.currentTime
    });

    this.isRecording = true;
    track.armed = true;
    
    this.emit('recording_started', { trackId });
  }

  stopRecording(trackId) {
    const recordingData = this.recordingNodes.get(trackId);
    const track = this.tracks.get(trackId);
    
    if (!recordingData || !track) return null;

    // Stop recording
    this.isRecording = false;
    track.armed = false;

    // Disconnect recorder
    recordingData.recorder.disconnect();

    // Process recorded buffers into audio clip
    const audioClip = this.processRecordedBuffers(recordingData.buffers);
    
    // Add clip to track
    const clip = {
      id: `clip_${Date.now()}`,
      trackId,
      startTime: recordingData.startTime,
      duration: audioClip.duration,
      buffer: audioClip.buffer,
      peaks: this.generateWaveformPeaks(audioClip.buffer)
    };

    track.clips.push(clip);
    
    // Cleanup
    this.recordingNodes.delete(trackId);
    
    this.emit('recording_stopped', { trackId, clip });
    return clip;
  }

  processRecordedBuffers(buffers) {
    if (buffers.length === 0) return null;

    const totalSamples = buffers.length * this.options.bufferSize;
    const audioBuffer = this.audioContext.createBuffer(
      2, 
      totalSamples, 
      this.audioContext.sampleRate
    );

    const leftChannel = audioBuffer.getChannelData(0);
    const rightChannel = audioBuffer.getChannelData(1);

    let offset = 0;
    for (const buffer of buffers) {
      leftChannel.set(buffer.left, offset);
      rightChannel.set(buffer.right, offset);
      offset += buffer.left.length;
    }

    return {
      buffer: audioBuffer,
      duration: audioBuffer.duration
    };
  }

  generateWaveformPeaks(audioBuffer, peakCount = 500) {
    const samplesPerPeak = Math.floor(audioBuffer.length / peakCount);
    const peaks = [];
    
    for (let i = 0; i < peakCount; i++) {
      const start = i * samplesPerPeak;
      const end = Math.min(start + samplesPerPeak, audioBuffer.length);
      
      let peak = 0;
      for (let j = start; j < end; j++) {
        const sample = Math.abs(audioBuffer.getChannelData(0)[j]);
        if (sample > peak) peak = sample;
      }
      
      peaks.push(peak);
    }
    
    return peaks;
  }

  // Playback System
  startPlayback(position = 0) {
    this.playbackPosition = position;
    this.isPlaying = true;
    
    // Start playback for all clips
    this.tracks.forEach((track, trackId) => {
      this.startTrackPlayback(trackId, position);
    });
    
    this.emit('playback_started', { position });
  }

  stopPlayback() {
    this.isPlaying = false;
    
    // Stop all track playback
    this.tracks.forEach((track, trackId) => {
      this.stopTrackPlayback(trackId);
    });
    
    this.emit('playback_stopped', { position: this.playbackPosition });
  }

  startTrackPlayback(trackId, position) {
    const track = this.tracks.get(trackId);
    if (!track) return;

    // Play all clips on this track that should be active at the given position
    track.clips.forEach(clip => {
      if (position >= clip.startTime && position < clip.startTime + clip.duration) {
        const source = this.audioContext.createBufferSource();
        source.buffer = clip.buffer;
        source.connect(track.effectChain.input);
        
        const offset = position - clip.startTime;
        source.start(0, offset);
        
        // Store reference for stopping
        clip.playbackSource = source;
      }
    });
  }

  stopTrackPlayback(trackId) {
    const track = this.tracks.get(trackId);
    if (!track) return;

    // Stop all playing clips
    track.clips.forEach(clip => {
      if (clip.playbackSource) {
        clip.playbackSource.stop();
        clip.playbackSource = null;
      }
    });
  }

  // Track Controls
  setTrackVolume(trackId, volume) {
    const track = this.tracks.get(trackId);
    if (!track) return;

    track.volume = Math.max(0, Math.min(1, volume));
    track.gain.gain.setValueAtTime(track.volume, this.audioContext.currentTime);
    
    this.emit('track_volume_changed', { trackId, volume: track.volume });
  }

  setTrackPan(trackId, pan) {
    const track = this.tracks.get(trackId);
    if (!track) return;

    track.panValue = Math.max(-1, Math.min(1, pan));
    track.pan.pan.setValueAtTime(track.panValue, this.audioContext.currentTime);
    
    this.emit('track_pan_changed', { trackId, pan: track.panValue });
  }

  muteTrack(trackId, muted) {
    const track = this.tracks.get(trackId);
    if (!track) return;

    track.muted = muted;
    const volume = muted ? 0 : track.volume;
    track.gain.gain.setValueAtTime(volume, this.audioContext.currentTime);
    
    this.emit('track_muted', { trackId, muted });
  }

  soloTrack(trackId, solo) {
    const track = this.tracks.get(trackId);
    if (!track) return;

    // Update solo state
    track.solo = solo;

    // Handle solo logic - if soloing, mute others
    if (solo) {
      this.tracks.forEach((otherTrack, otherTrackId) => {
        if (otherTrackId !== trackId) {
          otherTrack.solo = false;
          const volume = otherTrack.muted ? 0 : 0; // Muted by solo
          otherTrack.gain.gain.setValueAtTime(volume, this.audioContext.currentTime);
        }
      });
    } else {
      // If un-soloing, restore original volumes
      this.tracks.forEach((otherTrack, otherTrackId) => {
        const volume = otherTrack.muted ? 0 : otherTrack.volume;
        otherTrack.gain.gain.setValueAtTime(volume, this.audioContext.currentTime);
      });
    }
    
    this.emit('track_solo_changed', { trackId, solo });
  }

  deleteTrack(trackId) {
    const track = this.tracks.get(trackId);
    if (!track) return;

    // Stop any recording
    if (this.recordingNodes.has(trackId)) {
      this.stopRecording(trackId);
    }

    // Stop any playback
    this.stopTrackPlayback(trackId);

    // Disconnect input stream
    if (track.inputStream) {
      track.inputStream.getTracks().forEach(audioTrack => audioTrack.stop());
    }

    // Disconnect audio nodes
    if (track.input) track.input.disconnect();
    track.gain.disconnect();
    track.pan.disconnect();
    track.analyzer.disconnect();

    // Cleanup effects
    track.effects.forEach(effect => {
      if (effect.instance.disconnect) {
        effect.instance.disconnect();
      }
    });

    // Remove from tracks
    this.tracks.delete(trackId);
    
    this.emit('track_deleted', { trackId });
  }

  // Master Controls
  setMasterVolume(volume) {
    volume = Math.max(0, Math.min(1, volume));
    this.masterGain.gain.setValueAtTime(volume, this.audioContext.currentTime);
    this.emit('master_volume_changed', { volume });
  }

  // Integration with WebRTC
  integrateWithRTC(rtcClient) {
    this.rtcClient = rtcClient;

    // Connect audio engine output to RTC
    const destination = this.audioContext.createMediaStreamDestination();
    this.analyzer.connect(destination);
    
    // Add to RTC local stream
    if (rtcClient.localStream) {
      destination.stream.getAudioTracks().forEach(track => {
        rtcClient.localStream.addTrack(track);
      });
    }

    // Handle incoming audio from collaborators
    rtcClient.onTrack((peerId, stream) => {
      this.addCollaboratorAudio(peerId, stream);
    });

    rtcClient.onDisconnect((peerId) => {
      this.removeCollaboratorAudio(peerId);
    });
  }

  addCollaboratorAudio(peerId, stream) {
    const source = this.audioContext.createMediaStreamSource(stream);
    const gain = this.audioContext.createGain();
    const analyzer = this.audioContext.createAnalyser();
    
    source.connect(gain);
    gain.connect(analyzer);
    analyzer.connect(this.masterGain);
    
    this.collaborators.set(peerId, {
      source,
      gain,
      analyzer,
      volume: 0.8,
      muted: false
    });
    
    this.emit('collaborator_joined', { peerId });
  }

  removeCollaboratorAudio(peerId) {
    const collaborator = this.collaborators.get(peerId);
    if (collaborator) {
      collaborator.source.disconnect();
      collaborator.gain.disconnect();
      collaborator.analyzer.disconnect();
      this.collaborators.delete(peerId);
      
      this.emit('collaborator_left', { peerId });
    }
  }

  // Event System
  on(event, callback) {
    if (!this.eventListeners.has(event)) {
      this.eventListeners.set(event, []);
    }
    this.eventListeners.get(event).push(callback);
  }

  off(event, callback) {
    const listeners = this.eventListeners.get(event);
    if (listeners) {
      const index = listeners.indexOf(callback);
      if (index > -1) {
        listeners.splice(index, 1);
      }
    }
  }

  emit(event, data) {
    const listeners = this.eventListeners.get(event);
    if (listeners) {
      listeners.forEach(callback => {
        try {
          callback(data);
        } catch (error) {
          console.error(`Error in event listener for ${event}:`, error);
        }
      });
    }
  }

  // State Management
  getState() {
    return {
      tracks: Array.from(this.tracks.entries()).map(([id, track]) => ({
        id,
        name: track.name,
        volume: track.volume,
        pan: track.panValue,
        muted: track.muted,
        solo: track.solo,
        armed: track.armed,
        monitoring: track.monitoring,
        effects: track.effects.map(e => ({
          id: e.id,
          type: e.type,
          enabled: e.enabled,
          params: e.params
        })),
        clipCount: track.clips.length
      })),
      isRecording: this.isRecording,
      isPlaying: this.isPlaying,
      playbackPosition: this.playbackPosition,
      collaborators: Array.from(this.collaborators.keys())
    };
  }

  // Utility methods
  generateTrackColor() {
    const colors = [
      '#8B5CF6', '#06B6D4', '#10B981', '#F59E0B', 
      '#EF4444', '#EC4899', '#6366F1', '#84CC16'
    ];
    return colors[this.trackCounter % colors.length];
  }

  // Cleanup
  destroy() {
    // Stop monitoring
    if (this.syncInterval) {
      clearInterval(this.syncInterval);
    }

    // Stop all recordings and playback
    this.stopPlayback();
    this.recordingNodes.forEach((_, trackId) => {
      this.stopRecording(trackId);
    });

    // Disconnect all tracks
    this.tracks.forEach((_, trackId) => {
      this.deleteTrack(trackId);
    });

    // Disconnect collaborators
    this.collaborators.forEach((_, peerId) => {
      this.removeCollaboratorAudio(peerId);
    });

    // Close audio context
    if (this.audioContext) {
      this.audioContext.close();
    }

    // Clear event listeners
    this.eventListeners.clear();
  }
}

// Basic Effects Classes
class ReverbEffect {
  constructor(audioContext, params = {}) {
    this.audioContext = audioContext;
    this.input = audioContext.createGain();
    this.output = audioContext.createGain();
    this.convolver = audioContext.createConvolver();
    this.wetGain = audioContext.createGain();
    this.dryGain = audioContext.createGain();
    
    // Set parameters
    this.wetGain.gain.value = params.wet || 0.3;
    this.dryGain.gain.value = params.dry || 0.7;
    
    // Connect nodes
    this.input.connect(this.dryGain);
    this.input.connect(this.convolver);
    this.convolver.connect(this.wetGain);
    this.dryGain.connect(this.output);
    this.wetGain.connect(this.output);
    
    // Generate impulse response
    this.generateImpulseResponse(params.roomSize || 0.5, params.decay || 2);
  }
  
  generateImpulseResponse(roomSize, decay) {
    const length = this.audioContext.sampleRate * decay;
    const impulse = this.audioContext.createBuffer(2, length, this.audioContext.sampleRate);
    
    for (let channel = 0; channel < 2; channel++) {
      const channelData = impulse.getChannelData(channel);
      for (let i = 0; i < length; i++) {
        const n = length - i;
        channelData[i] = (Math.random() * 2 - 1) * Math.pow(n / length, decay) * roomSize;
      }
    }
    
    this.convolver.buffer = impulse;
  }
  
  disconnect() {
    this.input.disconnect();
    this.output.disconnect();
    this.convolver.disconnect();
    this.wetGain.disconnect();
    this.dryGain.disconnect();
  }
}

class DelayEffect {
  constructor(audioContext, params = {}) {
    this.audioContext = audioContext;
    this.input = audioContext.createGain();
    this.output = audioContext.createGain();
    this.delay = audioContext.createDelay(1);
    this.feedback = audioContext.createGain();
    this.wetGain = audioContext.createGain();
    this.dryGain = audioContext.createGain();
    
    // Set parameters
    this.delay.delayTime.value = params.time || 0.3;
    this.feedback.gain.value = params.feedback || 0.4;
    this.wetGain.gain.value = params.wet || 0.3;
    this.dryGain.gain.value = params.dry || 0.7;
    
    // Connect nodes
    this.input.connect(this.dryGain);
    this.input.connect(this.delay);
    this.delay.connect(this.feedback);
    this.delay.connect(this.wetGain);
    this.feedback.connect(this.delay);
    this.dryGain.connect(this.output);
    this.wetGain.connect(this.output);
  }
  
  disconnect() {
    this.input.disconnect();
    this.output.disconnect();
    this.delay.disconnect();
    this.feedback.disconnect();
    this.wetGain.disconnect();
    this.dryGain.disconnect();
  }
}

class FilterEffect {
  constructor(audioContext, params = {}) {
    this.audioContext = audioContext;
    this.input = audioContext.createGain();
    this.output = audioContext.createGain();
    this.filter = audioContext.createBiquadFilter();
    
    // Set parameters
    this.filter.type = params.type || 'lowpass';
    this.filter.frequency.value = params.frequency || 1000;
    this.filter.Q.value = params.resonance || 1;
    this.filter.gain.value = params.gain || 0;
    
    // Connect nodes
    this.input.connect(this.filter);
    this.filter.connect(this.output);
  }
  
  disconnect() {
    this.input.disconnect();
    this.filter.disconnect();
    this.output.disconnect();
  }
}

class EQEffect {
  constructor(audioContext, params = {}) {
    this.audioContext = audioContext;
    this.input = audioContext.createGain();
    this.output = audioContext.createGain();
    
    // Create 3-band EQ
    this.lowShelf = audioContext.createBiquadFilter();
    this.midPeaking = audioContext.createBiquadFilter();
    this.highShelf = audioContext.createBiquadFilter();
    
    // Configure filters
    this.lowShelf.type = 'lowshelf';
    this.lowShelf.frequency.value = params.lowFreq || 320;
    this.lowShelf.gain.value = params.lowGain || 0;
    
    this.midPeaking.type = 'peaking';
    this.midPeaking.frequency.value = params.midFreq || 1000;
    this.midPeaking.Q.value = params.midQ || 1;
    this.midPeaking.gain.value = params.midGain || 0;
    
    this.highShelf.type = 'highshelf';
    this.highShelf.frequency.value = params.highFreq || 3200;
    this.highShelf.gain.value = params.highGain || 0;
    
    // Connect in series
    this.input.connect(this.lowShelf);
    this.lowShelf.connect(this.midPeaking);
    this.midPeaking.connect(this.highShelf);
    this.highShelf.connect(this.output);
  }
  
  disconnect() {
    this.input.disconnect();
    this.lowShelf.disconnect();
    this.midPeaking.disconnect();
    this.highShelf.disconnect();
    this.output.disconnect();
  }
}

class CompressorEffect {
  constructor(audioContext, params = {}) {
    this.audioContext = audioContext;
    this.input = audioContext.createGain();
    this.output = audioContext.createGain();
    this.compressor = audioContext.createDynamicsCompressor();
    
    // Set parameters
    this.compressor.threshold.value = params.threshold || -24;
    this.compressor.knee.value = params.knee || 30;
    this.compressor.ratio.value = params.ratio || 12;
    this.compressor.attack.value = params.attack || 0.003;
    this.compressor.release.value = params.release || 0.25;
    
    // Connect nodes
    this.input.connect(this.compressor);
    this.compressor.connect(this.output);
  }
  
  disconnect() {
    this.input.disconnect();
    this.compressor.disconnect();
    this.output.disconnect();
  }
}

class ChorusEffect {
  constructor(audioContext, params = {}) {
    this.audioContext = audioContext;
    this.input = audioContext.createGain();
    this.output = audioContext.createGain();
    
    // Create LFO for modulation
    this.lfo = audioContext.createOscillator();
    this.lfoGain = audioContext.createGain();
    this.delay = audioContext.createDelay(0.1);
    this.wetGain = audioContext.createGain();
    this.dryGain = audioContext.createGain();
    
    // Set parameters
    this.lfo.frequency.value = params.rate || 0.5;
    this.lfoGain.gain.value = params.depth || 0.005;
    this.delay.delayTime.value = params.delay || 0.02;
    this.wetGain.gain.value = params.wet || 0.5;
    this.dryGain.gain.value = params.dry || 0.5;
    
    // Connect nodes
    this.lfo.connect(this.lfoGain);
    this.lfoGain.connect(this.delay.delayTime);
    
    this.input.connect(this.dryGain);
    this.input.connect(this.delay);
    this.delay.connect(this.wetGain);
    this.dryGain.connect(this.output);
    this.wetGain.connect(this.output);
    
    this.lfo.start();
  }
  
  disconnect() {
    this.lfo.stop();
    this.input.disconnect();
    this.output.disconnect();
    this.delay.disconnect();
    this.wetGain.disconnect();
    this.dryGain.disconnect();
    this.lfo.disconnect();
    this.lfoGain.disconnect();
  }
}

class DistortionEffect {
  constructor(audioContext, params = {}) {
    this.audioContext = audioContext;
    this.input = audioContext.createGain();
    this.output = audioContext.createGain();
    this.waveshaper = audioContext.createWaveShaper();
    this.inputGain = audioContext.createGain();
    this.outputGain = audioContext.createGain();
    
    // Set parameters
    this.inputGain.gain.value = params.drive || 5;
    this.outputGain.gain.value = params.level || 0.5;
    
    // Create distortion curve
    this.generateDistortionCurve(params.amount || 50);
    
    // Connect nodes
    this.input.connect(this.inputGain);
    this.inputGain.connect(this.waveshaper);
    this.waveshaper.connect(this.outputGain);
    this.outputGain.connect(this.output);
  }
  
  generateDistortionCurve(amount) {
    const samples = 44100;
    const curve = new Float32Array(samples);
    const deg = Math.PI / 180;
    
    for (let i = 0; i < samples; i++) {
      const x = (i * 2) / samples - 1;
      curve[i] = ((3 + amount) * x * 20 * deg) / (Math.PI + amount * Math.abs(x));
    }
    
    this.waveshaper.curve = curve;
  }
  
  disconnect() {
    this.input.disconnect();
    this.inputGain.disconnect();
    this.waveshaper.disconnect();
    this.outputGain.disconnect();
    this.output.disconnect();
  }
}

class GateEffect {
  constructor(audioContext, params = {}) {
    this.audioContext = audioContext;
    this.input = audioContext.createGain();
    this.output = audioContext.createGain();
    this.gate = audioContext.createGain();
    
    // Gate parameters
    this.threshold = params.threshold || -40;
    this.ratio = params.ratio || 10;
    this.attack = params.attack || 0.001;
    this.release = params.release || 0.1;
    
    // Connect nodes
    this.input.connect(this.gate);
    this.gate.connect(this.output);
    
    // Start gate processing
    this.startGateProcessing();
  }
  
  startGateProcessing() {
    // Create analyzer for level detection
    this.analyzer = this.audioContext.createAnalyser();
    this.analyzer.fftSize = 512;
    this.input.connect(this.analyzer);
    
    // Process gate in real-time
    const processGate = () => {
      const bufferLength = this.analyzer.frequencyBinCount;
      const dataArray = new Uint8Array(bufferLength);
      this.analyzer.getByteFrequencyData(dataArray);
      
      // Calculate RMS level
      let sum = 0;
      for (let i = 0; i < bufferLength; i++) {
        sum += dataArray[i] * dataArray[i];
      }
      const rms = Math.sqrt(sum / bufferLength) / 255;
      const dbLevel = 20 * Math.log10(rms);
      
      // Apply gate
      const targetGain = dbLevel > this.threshold ? 1 : 0;
      const currentTime = this.audioContext.currentTime;
      const timeConstant = targetGain > this.gate.gain.value ? this.attack : this.release;
      
      this.gate.gain.setTargetAtTime(targetGain, currentTime, timeConstant);
      
      // Continue processing
      requestAnimationFrame(processGate);
    };
    
    processGate();
  }
  
  disconnect() {
    this.input.disconnect();
    this.gate.disconnect();
    this.analyzer.disconnect();
    this.output.disconnect();
  }
}

export default AudioEngine;