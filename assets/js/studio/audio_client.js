// assets/js/studio/audio_client.js
import RtcClient from "../streaming/rtc_client"

export class StudioAudioClient {
  constructor(sessionId, userId, userToken) {
    this.sessionId = sessionId;
    this.userId = userId;
    this.rtcClient = new RtcClient(userToken, userId);
    
    // Audio engine state
    this.tracks = new Map();
    this.isRecording = false;
    this.isPlaying = false;
    this.currentPosition = 0;
    this.masterVolume = 0.8;
    
    // Web Audio API setup
    this.audioContext = null;
    this.mediaRecorder = null;
    this.recordedChunks = [];
    this.audioBuffer = null;
    
    // Beat machine integration
    this.beatMachine = null;
    this.metronome = null;
    
    // Real-time collaboration
    this.pendingOperations = [];
    this.operationCallbacks = new Map();
    
    this.initialize();
  }

  async initialize() {
    try {
      // Initialize Web Audio API
      this.audioContext = new (window.AudioContext || window.webkitAudioContext)({
        sampleRate: 48000,
        latencyHint: 'interactive'
      });

      // Initialize audio worklets for low-latency processing
      await this.loadAudioWorklets();

      // Initialize beat machine
      this.beatMachine = new BeatMachine(this.audioContext, this.sessionId);
      
      // Initialize metronome
      this.metronome = new Metronome(this.audioContext);

      // Set up real-time audio streaming
      await this.setupAudioStreaming();

      // Connect to studio session
      this.connectToSession();

      console.log('Studio Audio Client initialized successfully');
    } catch (error) {
      console.error('Failed to initialize Studio Audio Client:', error);
    }
  }

  async loadAudioWorklets() {
    if (this.audioContext.audioWorklet) {
      try {
        await this.audioContext.audioWorklet.addModule('/js/worklets/audio-processor.js');
        await this.audioContext.audioWorklet.addModule('/js/worklets/beat-machine-processor.js');
      } catch (error) {
        console.warn('AudioWorklet not supported, falling back to ScriptProcessorNode');
      }
    }
  }

  async setupAudioStreaming() {
    // Get user media with high-quality audio settings
    const stream = await navigator.mediaDevices.getUserMedia({
      audio: {
        sampleRate: 48000,
        channelCount: 2,
        echoCancellation: false,
        noiseSuppression: false,
        autoGainControl: false,
        latency: 0.01 // 10ms latency
      }
    });

    this.localStream = stream;
    
    // Set up audio input analysis
    this.setupInputAnalysis(stream);
    
    // Set up WebRTC for real-time collaboration
    await this.rtcClient.startLocalStream({ 
      audio: true, 
      video: false 
    });
  }

  setupInputAnalysis(stream) {
    const source = this.audioContext.createMediaStreamSource(stream);
    const analyser = this.audioContext.createAnalyser();
    analyser.fftSize = 2048;
    
    source.connect(analyser);
    
    this.inputAnalyser = analyser;
    this.monitorInputLevel();
  }

  monitorInputLevel() {
    const bufferLength = this.inputAnalyser.frequencyBinCount;
    const dataArray = new Uint8Array(bufferLength);
    
    const updateLevel = () => {
      this.inputAnalyser.getByteFrequencyData(dataArray);
      
      let sum = 0;
      for (let i = 0; i < bufferLength; i++) {
        sum += dataArray[i];
      }
      
      const average = sum / bufferLength;
      const level = Math.round((average / 255) * 100);
      
      // Broadcast input level for UI
      this.broadcastEvent('input_level_update', { level });
      
      if (this.isRecording) {
        requestAnimationFrame(updateLevel);
      } else {
        setTimeout(updateLevel, 100); // Lower frequency when not recording
      }
    };
    
    updateLevel();
  }

  connectToSession() {
    // Join session channel for real-time updates
    this.channel = window.liveSocket.channel(`session:${this.sessionId}`, {});
    
    this.channel.join()
      .receive('ok', resp => {
        console.log('Joined session successfully', resp);
        this.handleSessionJoined(resp);
      })
      .receive('error', resp => {
        console.error('Unable to join session', resp);
      });

    // Set up event handlers
    this.setupChannelHandlers();
  }

  setupChannelHandlers() {
    // Track operations
    this.channel.on('track_added', (data) => {
      this.handleTrackAdded(data.track);
    });

    this.channel.on('track_volume_changed', (data) => {
      this.updateTrackVolume(data.track_id, data.volume);
    });

    this.channel.on('track_muted', (data) => {
      this.setTrackMuted(data.track_id, data.muted);
    });

    this.channel.on('track_solo_changed', (data) => {
      this.setTrackSolo(data.track_id, data.solo);
    });

    // Playback control
    this.channel.on('playback_started', (data) => {
      this.handlePlaybackStarted(data.position);
    });

    this.channel.on('playback_stopped', (data) => {
      this.handlePlaybackStopped(data.position);
    });

    this.channel.on('playback_position', (data) => {
      this.updatePlaybackPosition(data.position);
    });

    // Beat machine events
    this.channel.on('beat_machine', (data) => {
      this.handleBeatMachineEvent(data);
    });

    // Audio clips
    this.channel.on('clip_added', (data) => {
      this.handleClipAdded(data.clip);
    });

    // WebRTC signaling
    this.channel.on('signal', (data) => {
      if (data.to === this.userId) {
        this.rtcClient.handleSignal(data.from, data.signal_data);
      }
    });
  }

  // Track Management
  async addTrack(name, inputSource = 'microphone') {
    const trackData = {
      name: name,
      input_source: inputSource,
      color: this.generateTrackColor()
    };

    try {
      const response = await this.sendChannelMessage('add_track', trackData);
      return response;
    } catch (error) {
      console.error('Failed to add track:', error);
      throw error;
    }
  }

  async startRecording(trackId) {
    if (!this.localStream) {
      throw new Error('No audio input available');
    }

    this.isRecording = true;
    this.recordedChunks = [];

    // Set up MediaRecorder for high-quality recording
    this.mediaRecorder = new MediaRecorder(this.localStream, {
      mimeType: 'audio/webm;codecs=opus',
      audioBitsPerSecond: 128000
    });

    this.mediaRecorder.ondataavailable = (event) => {
      if (event.data.size > 0) {
        this.recordedChunks.push(event.data);
      }
    };

    this.mediaRecorder.onstop = () => {
      this.processRecordedAudio(trackId);
    };

    this.mediaRecorder.start(100); // Collect data every 100ms
    this.broadcastEvent('recording_started', { track_id: trackId });
  }

  stopRecording() {
    if (this.mediaRecorder && this.isRecording) {
      this.mediaRecorder.stop();
      this.isRecording = false;
      this.broadcastEvent('recording_stopped', {});
    }
  }

  async processRecordedAudio(trackId) {
    if (this.recordedChunks.length === 0) return;

    // Create blob from recorded chunks
    const blob = new Blob(this.recordedChunks, { type: 'audio/webm' });
    
    // Convert to ArrayBuffer
    const arrayBuffer = await blob.arrayBuffer();
    
    // Decode audio data
    const audioBuffer = await this.audioContext.decodeAudioData(arrayBuffer);
    
    // Send to server for processing and storage
    this.sendAudioClip(trackId, audioBuffer);
  }

  async sendAudioClip(trackId, audioBuffer) {
    // Convert AudioBuffer to PCM data
    const pcmData = this.audioBufferToPCM(audioBuffer);
    
    // Send via WebRTC for real-time collaboration
    this.broadcastAudioData(trackId, pcmData);
    
    // Also send to server for persistence
    this.channel.push('audio_clip_recorded', {
      track_id: trackId,
      audio_data: Array.from(pcmData),
      duration: audioBuffer.duration,
      sample_rate: audioBuffer.sampleRate
    });
  }

  audioBufferToPCM(audioBuffer) {
    const numberOfChannels = audioBuffer.numberOfChannels;
    const length = audioBuffer.length;
    const pcmData = new Float32Array(length * numberOfChannels);
    
    for (let channel = 0; channel < numberOfChannels; channel++) {
      const channelData = audioBuffer.getChannelData(channel);
      for (let i = 0; i < length; i++) {
        pcmData[i * numberOfChannels + channel] = channelData[i];
      }
    }
    
    return pcmData;
  }

  // Playback Control
  async startPlayback(position = 0) {
    try {
      await this.sendChannelMessage('start_playback', { position });
    } catch (error) {
      console.error('Failed to start playback:', error);
    }
  }

  async stopPlayback() {
    try {
      await this.sendChannelMessage('stop_playback', {});
    } catch (error) {
      console.error('Failed to stop playback:', error);
    }
  }

  // Track Controls
  async updateTrackVolume(trackId, volume) {
    const track = this.tracks.get(trackId);
    if (track) {
      track.volume = volume;
      if (track.gainNode) {
        track.gainNode.gain.value = volume;
      }
    }

    try {
      await this.sendChannelMessage('update_track_volume', {
        track_id: trackId,
        volume: volume
      });
    } catch (error) {
      console.error('Failed to update track volume:', error);
    }
  }

  async setTrackMuted(trackId, muted) {
    const track = this.tracks.get(trackId);
    if (track) {
      track.muted = muted;
      if (track.gainNode) {
        track.gainNode.gain.value = muted ? 0 : track.volume;
      }
    }

    try {
      await this.sendChannelMessage('mute_track', {
        track_id: trackId,
        muted: muted
      });
    } catch (error) {
      console.error('Failed to mute track:', error);
    }
  }

  async setTrackSolo(trackId, solo) {
    // Handle solo logic on client side too
    if (solo) {
      // Mute all other tracks
      this.tracks.forEach((track, id) => {
        if (id !== trackId) {
          track.soloed = false;
          if (track.gainNode) {
            track.gainNode.gain.value = 0;
          }
        }
      });
    } else {
      // Restore all track volumes
      this.tracks.forEach((track, id) => {
        if (!track.muted) {
          if (track.gainNode) {
            track.gainNode.gain.value = track.volume;
          }
        }
      });
    }

    const track = this.tracks.get(trackId);
    if (track) {
      track.soloed = solo;
    }

    try {
      await this.sendChannelMessage('solo_track', {
        track_id: trackId,
        solo: solo
      });
    } catch (error) {
      console.error('Failed to solo track:', error);
    }
  }

  // Beat Machine Integration
  async createBeatPattern(name, steps = 16) {
    return await this.beatMachine.createPattern(name, steps);
  }

  async updateBeatStep(patternId, instrument, step, velocity) {
    return await this.beatMachine.updateStep(patternId, instrument, step, velocity);
  }

  async playBeatPattern(patternId) {
    return await this.beatMachine.playPattern(patternId);
  }

  async stopBeatPattern() {
    return await this.beatMachine.stop();
  }

  // Event Handlers
  handleTrackAdded(track) {
    this.tracks.set(track.id, {
      ...track,
      audioNodes: this.createTrackAudioNodes()
    });
    this.broadcastEvent('track_added', track);
  }

  createTrackAudioNodes() {
    const gainNode = this.audioContext.createGain();
    const panNode = this.audioContext.createStereoPanner();
    
    // Connect nodes
    gainNode.connect(panNode);
    panNode.connect(this.audioContext.destination);
    
    return { gainNode, panNode };
  }

  handlePlaybackStarted(position) {
    this.isPlaying = true;
    this.currentPosition = position;
    this.broadcastEvent('playback_started', { position });
  }

  handlePlaybackStopped(position) {
    this.isPlaying = false;
    this.currentPosition = position;
    this.broadcastEvent('playback_stopped', { position });
  }

  updatePlaybackPosition(position) {
    this.currentPosition = position;
    this.broadcastEvent('playback_position_update', { position });
  }

  handleBeatMachineEvent(event) {
    if (this.beatMachine) {
      this.beatMachine.handleRemoteEvent(event);
    }
    this.broadcastEvent('beat_machine_event', event);
  }

  handleClipAdded(clip) {
    const track = this.tracks.get(clip.track_id);
    if (track) {
      track.clips = track.clips || [];
      track.clips.push(clip);
    }
    this.broadcastEvent('clip_added', clip);
  }

  // WebRTC Audio Streaming
  broadcastAudioData(trackId, audioData) {
    const message = {
      type: 'audio_data',
      track_id: trackId,
      data: audioData,
      timestamp: Date.now()
    };

    // Send to all connected peers
    Object.values(this.rtcClient.peerConnections).forEach(pc => {
      if (pc.connectionState === 'connected') {
        try {
          pc.sendAudioData(message);
        } catch (error) {
          console.warn('Failed to send audio data to peer:', error);
        }
      }
    });
  }

  // Utility Functions
  generateTrackColor() {
    const colors = [
      '#8B5CF6', '#06B6D4', '#10B981', '#F59E0B', 
      '#EF4444', '#EC4899', '#6366F1', '#84CC16'
    ];
    return colors[Math.floor(Math.random() * colors.length)];
  }

  async sendChannelMessage(event, payload) {
    return new Promise((resolve, reject) => {
      this.channel.push(event, payload)
        .receive('ok', resolve)
        .receive('error', reject)
        .receive('timeout', () => reject(new Error('Request timeout')));
    });
  }

  broadcastEvent(eventName, data) {
    window.dispatchEvent(new CustomEvent(`studio:${eventName}`, { 
      detail: { ...data, sessionId: this.sessionId } 
    }));
  }

  // Cleanup
  destroy() {
    if (this.mediaRecorder) {
      this.mediaRecorder.stop();
    }
    
    if (this.localStream) {
      this.localStream.getTracks().forEach(track => track.stop());
    }
    
    if (this.audioContext) {
      this.audioContext.close();
    }
    
    if (this.channel) {
      this.channel.leave();
    }
    
    if (this.rtcClient) {
      this.rtcClient.cleanup();
    }
    
    if (this.beatMachine) {
      this.beatMachine.destroy();
    }
  }
}

// Beat Machine Class
class BeatMachine {
  constructor(audioContext, sessionId) {
    this.audioContext = audioContext;
    this.sessionId = sessionId;
    this.patterns = new Map();
    this.currentPattern = null;
    this.isPlaying = false;
    this.currentStep = 0;
    this.stepTimer = null;
    this.samples = new Map();
    
    this.loadSamples();
  }

  async loadSamples() {
    const samplePaths = {
      kick: '/samples/808/kick.wav',
      snare: '/samples/808/snare.wav',
      hihat: '/samples/808/hihat.wav',
      openhat: '/samples/808/openhat.wav',
      crash: '/samples/808/crash.wav',
      clap: '/samples/808/clap.wav'
    };

    for (const [name, path] of Object.entries(samplePaths)) {
      try {
        const response = await fetch(path);
        const arrayBuffer = await response.arrayBuffer();
        const audioBuffer = await this.audioContext.decodeAudioData(arrayBuffer);
        this.samples.set(name, audioBuffer);
      } catch (error) {
        console.warn(`Failed to load sample ${name}:`, error);
      }
    }
  }

  async createPattern(name, steps = 16) {
    const pattern = {
      id: this.generateId(),
      name: name,
      steps: steps,
      tracks: this.initializeTracks(steps),
      bpm: 120
    };

    this.patterns.set(pattern.id, pattern);
    return pattern;
  }

  initializeTracks(steps) {
    const instruments = ['kick', 'snare', 'hihat', 'openhat', 'crash', 'clap'];
    const tracks = {};
    
    instruments.forEach(instrument => {
      tracks[instrument] = new Array(steps).fill(0);
    });
    
    return tracks;
  }

  async updateStep(patternId, instrument, step, velocity) {
    const pattern = this.patterns.get(patternId);
    if (pattern && pattern.tracks[instrument]) {
      pattern.tracks[instrument][step - 1] = velocity;
      
      // Broadcast to other clients
      this.broadcastBeatEvent('step_updated', {
        pattern_id: patternId,
        instrument: instrument,
        step: step,
        velocity: velocity
      });
    }
  }

  async playPattern(patternId) {
    const pattern = this.patterns.get(patternId);
    if (!pattern) return;

    this.currentPattern = pattern;
    this.isPlaying = true;
    this.currentStep = 0;
    
    this.scheduleNextStep();
  }

  stop() {
    this.isPlaying = false;
    this.currentStep = 0;
    
    if (this.stepTimer) {
      clearTimeout(this.stepTimer);
    }
  }

  scheduleNextStep() {
    if (!this.isPlaying || !this.currentPattern) return;

    const stepDuration = 60000 / (this.currentPattern.bpm * 4); // 16th notes
    
    this.stepTimer = setTimeout(() => {
      this.triggerStep();
      this.currentStep = (this.currentStep + 1) % this.currentPattern.steps;
      this.scheduleNextStep();
    }, stepDuration);
  }

  triggerStep() {
    if (!this.currentPattern) return;

    const pattern = this.currentPattern;
    const triggeredInstruments = [];

    // Check which instruments should trigger on this step
    Object.entries(pattern.tracks).forEach(([instrument, steps]) => {
      const velocity = steps[this.currentStep];
      if (velocity > 0) {
        this.playSample(instrument, velocity);
        triggeredInstruments.push({ instrument, velocity });
      }
    });

    // Broadcast step trigger for visualization
    this.broadcastBeatEvent('step_triggered', {
      step: this.currentStep,
      instruments: triggeredInstruments
    });
  }

  playSample(instrument, velocity) {
    const sample = this.samples.get(instrument);
    if (!sample) return;

    const source = this.audioContext.createBufferSource();
    const gainNode = this.audioContext.createGain();
    
    source.buffer = sample;
    gainNode.gain.value = velocity / 127; // Normalize velocity
    
    source.connect(gainNode);
    gainNode.connect(this.audioContext.destination);
    
    source.start();
  }

  handleRemoteEvent(event) {
    switch (event.type) {
      case 'step_updated':
        this.handleRemoteStepUpdate(event);
        break;
      case 'pattern_started':
        this.handleRemotePatternStart(event);
        break;
      case 'pattern_stopped':
        this.handleRemotePatternStop(event);
        break;
    }
  }

  handleRemoteStepUpdate(event) {
    const pattern = this.patterns.get(event.pattern_id);
    if (pattern && pattern.tracks[event.instrument]) {
      pattern.tracks[event.instrument][event.step - 1] = event.velocity;
    }
  }

  handleRemotePatternStart(event) {
    // Sync with remote playback
    const pattern = this.patterns.get(event.pattern_id);
    if (pattern && !this.isPlaying) {
      this.playPattern(event.pattern_id);
    }
  }

  handleRemotePatternStop(event) {
    this.stop();
  }

  broadcastBeatEvent(type, data) {
    window.dispatchEvent(new CustomEvent('studio:beat_machine', {
      detail: { type, ...data, sessionId: this.sessionId }
    }));
  }

  generateId() {
    return 'beat_' + Math.random().toString(36).substr(2, 9);
  }

  destroy() {
    this.stop();
    this.samples.clear();
    this.patterns.clear();
  }
}

// Metronome Class
class Metronome {
  constructor(audioContext) {
    this.audioContext = audioContext;
    this.isPlaying = false;
    this.bpm = 120;
    this.clickTimer = null;
    this.volume = 0.5;
  }

  start(bpm = 120) {
    this.bpm = bpm;
    this.isPlaying = true;
    this.scheduleClick();
  }

  stop() {
    this.isPlaying = false;
    if (this.clickTimer) {
      clearTimeout(this.clickTimer);
    }
  }

  scheduleClick() {
    if (!this.isPlaying) return;

    const interval = 60000 / this.bpm; // Quarter note interval
    
    this.clickTimer = setTimeout(() => {
      this.playClick();
      this.scheduleClick();
    }, interval);
  }

  playClick() {
    const oscillator = this.audioContext.createOscillator();
    const gainNode = this.audioContext.createGain();
    
    oscillator.frequency.value = 800;
    oscillator.type = 'square';
    
    gainNode.gain.value = this.volume;
    gainNode.gain.exponentialRampToValueAtTime(0.01, this.audioContext.currentTime + 0.1);
    
    oscillator.connect(gainNode);
    gainNode.connect(this.audioContext.destination);
    
    oscillator.start();
    oscillator.stop(this.audioContext.currentTime + 0.1);
  }

  setVolume(volume) {
    this.volume = Math.max(0, Math.min(1, volume));
  }
}

export default StudioAudioClient;