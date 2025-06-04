// assets/js/hooks/mobile_audio_hook.js
export const MobileAudioHook = {
  mounted() {
    console.log('Mobile Audio Interface mounted');
    
    // Initialize mobile-specific properties
    this.currentTrackIndex = 0;
    this.isRecording = false;
    this.isPlaying = false;
    this.touchStartX = 0;
    this.touchStartY = 0;
    this.updateInterval = null;
    this.batteryOptimized = false;
    
    // Detect mobile device and capabilities
    this.detectMobileCapabilities();
    
    // Setup mobile-specific controls
    this.setupTouchControls();
    this.setupSwipeGestures();
    this.setupOrientationHandling();
    this.optimizeForMobile();
    this.setupSimplifiedUI();
    
    // Initialize audio engine with mobile settings
    this.initializeMobileAudioEngine();
    
    // Setup reduced update frequency for battery optimization
    this.setupBatteryOptimization();
  },

  detectMobileCapabilities() {
    const isMobile = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
    const isTouchDevice = 'ontouchstart' in window || navigator.maxTouchPoints > 0;
    const hasBattery = 'getBattery' in navigator;
    
    this.deviceInfo = {
      isMobile,
      isTouchDevice,
      hasBattery,
      isLandscape: window.innerWidth > window.innerHeight,
      screenSize: Math.min(window.innerWidth, window.innerHeight)
    };
    
    console.log('Mobile capabilities detected:', this.deviceInfo);
  },

  async initializeMobileAudioEngine() {
    // Mobile-optimized audio engine configuration
    const mobileConfig = {
      sampleRate: 44100,
      bufferSize: 512, // Slightly larger for mobile stability
      enableEffects: this.deviceInfo.screenSize > 375, // Only on larger screens
      enableMonitoring: true,
      maxTracks: 4, // Reduced for mobile
      updateFrequency: 30, // 30fps instead of 60fps
      batteryOptimized: true
    };

    try {
      // Initialize simplified audio engine
      this.audioEngine = new MobileAudioEngine(mobileConfig);
      await this.audioEngine.initialize();
      
      this.pushEvent('mobile_audio_initialized', {
        capabilities: this.deviceInfo,
        config: mobileConfig
      });
      
    } catch (error) {
      console.error('Mobile audio initialization failed:', error);
      this.showMobileError('Audio initialization failed. Please check microphone permissions.');
    }
  },

  setupTouchControls() {
    // Enhanced touch targets for mobile
    const buttons = this.el.querySelectorAll('.mobile-touch-btn');
    
    buttons.forEach(button => {
      // Ensure minimum 44px touch target
      const rect = button.getBoundingClientRect();
      if (rect.width < 44 || rect.height < 44) {
        button.style.minWidth = '44px';
        button.style.minHeight = '44px';
        button.style.padding = '12px';
      }
      
      // Add touch feedback
      button.addEventListener('touchstart', this.handleTouchStart.bind(this), { passive: false });
      button.addEventListener('touchend', this.handleTouchEnd.bind(this), { passive: false });
      button.addEventListener('touchcancel', this.handleTouchCancel.bind(this), { passive: false });
    });

    // Transport controls with haptic feedback
    this.setupTransportControls();
    
    // Volume/pan controls with touch optimization
    this.setupTouchSliders();
  },

  setupTransportControls() {
    const playBtn = this.el.querySelector('#mobile-play-btn');
    const stopBtn = this.el.querySelector('#mobile-stop-btn');
    const recordBtn = this.el.querySelector('#mobile-record-btn');

    if (playBtn) {
      playBtn.addEventListener('touchstart', (e) => {
        e.preventDefault();
        this.hapticFeedback('light');
        this.togglePlayback();
      });
    }

    if (stopBtn) {
      stopBtn.addEventListener('touchstart', (e) => {
        e.preventDefault();
        this.hapticFeedback('medium');
        this.stopPlayback();
      });
    }

    if (recordBtn) {
      recordBtn.addEventListener('touchstart', (e) => {
        e.preventDefault();
        this.hapticFeedback('heavy');
        this.toggleRecording();
      });
    }
  },

  setupTouchSliders() {
    const sliders = this.el.querySelectorAll('.mobile-slider');
    
    sliders.forEach(slider => {
      let isDragging = false;
      let startValue = 0;
      
      slider.addEventListener('touchstart', (e) => {
        isDragging = true;
        startValue = parseFloat(slider.value);
        e.preventDefault();
      }, { passive: false });
      
      slider.addEventListener('touchmove', (e) => {
        if (!isDragging) return;
        
        const touch = e.touches[0];
        const rect = slider.getBoundingClientRect();
        const percentage = (touch.clientX - rect.left) / rect.width;
        const value = slider.min + (percentage * (slider.max - slider.min));
        
        slider.value = Math.max(slider.min, Math.min(slider.max, value));
        this.handleSliderChange(slider);
        
        e.preventDefault();
      }, { passive: false });
      
      slider.addEventListener('touchend', () => {
        isDragging = false;
        this.hapticFeedback('light');
      });
    });
  },

  setupSwipeGestures() {
    const trackContainer = this.el.querySelector('#mobile-track-container');
    if (!trackContainer) return;

    let startX = 0;
    let startY = 0;
    let isSwipeGesture = false;

    trackContainer.addEventListener('touchstart', (e) => {
      const touch = e.touches[0];
      startX = touch.clientX;
      startY = touch.clientY;
      isSwipeGesture = false;
    }, { passive: true });

    trackContainer.addEventListener('touchmove', (e) => {
      if (!startX || !startY) return;
      
      const touch = e.touches[0];
      const diffX = touch.clientX - startX;
      const diffY = touch.clientY - startY;
      
      // Detect horizontal swipe (track switching)
      if (Math.abs(diffX) > Math.abs(diffY) && Math.abs(diffX) > 50) {
        isSwipeGesture = true;
        e.preventDefault();
      }
    }, { passive: false });

    trackContainer.addEventListener('touchend', (e) => {
      if (!isSwipeGesture || !startX) return;
      
      const touch = e.changedTouches[0];
      const diffX = touch.clientX - startX;
      
      if (Math.abs(diffX) > 100) { // Minimum swipe distance
        if (diffX > 0) {
          this.switchToPreviousTrack();
        } else {
          this.switchToNextTrack();
        }
        this.hapticFeedback('medium');
      }
      
      startX = 0;
      startY = 0;
      isSwipeGesture = false;
    });
  },

  setupOrientationHandling() {
    const handleOrientationChange = () => {
      setTimeout(() => {
        this.deviceInfo.isLandscape = window.innerWidth > window.innerHeight;
        this.adjustLayoutForOrientation();
      }, 100); // Delay to ensure dimensions are updated
    };

    window.addEventListener('orientationchange', handleOrientationChange);
    window.addEventListener('resize', handleOrientationChange);
  },

  adjustLayoutForOrientation() {
    const container = this.el.querySelector('#mobile-audio-container');
    if (!container) return;

    if (this.deviceInfo.isLandscape) {
      container.classList.add('landscape-mode');
      container.classList.remove('portrait-mode');
      this.showExpandedControls();
    } else {
      container.classList.add('portrait-mode');
      container.classList.remove('landscape-mode');
      this.showCompactControls();
    }
  },

  optimizeForMobile() {
    // Reduce visual effects for performance
    const levelMeters = this.el.querySelectorAll('.mobile-level-meter');
    levelMeters.forEach(meter => {
      meter.style.transition = 'width 0.1s linear'; // Faster transitions
    });

    // Optimize update frequency based on battery
    if (this.deviceInfo.hasBattery) {
      this.monitorBatteryLevel();
    }

    // Disable complex animations on lower-end devices
    if (this.deviceInfo.screenSize < 375) {
      this.el.classList.add('performance-mode');
    }
  },

  async monitorBatteryLevel() {
    try {
      const battery = await navigator.getBattery();
      
      const updateBatteryOptimization = () => {
        const batteryLevel = battery.level;
        const isCharging = battery.charging;
        
        if (batteryLevel < 0.2 && !isCharging) {
          this.enablePowerSaveMode();
        } else if (batteryLevel > 0.5 || isCharging) {
          this.disablePowerSaveMode();
        }
      };

      battery.addEventListener('levelchange', updateBatteryOptimization);
      battery.addEventListener('chargingchange', updateBatteryOptimization);
      
      updateBatteryOptimization();
    } catch (error) {
      console.log('Battery API not supported');
    }
  },

  setupSimplifiedUI() {
    // Initialize collapsed state for secondary controls
    this.collapseAdvancedControls();
    
    // Setup simplified effect controls
    this.setupMobileEffects();
    
    // Initialize track indicator
    this.updateTrackIndicator();
    
    // Setup quick action buttons
    this.setupQuickActions();
  },

  setupBatteryOptimization() {
    // Reduce update frequency for mobile
    this.updateInterval = setInterval(() => {
      if (this.audioEngine && !this.batteryOptimized) {
        this.updateMobileLevels();
      }
    }, 100); // 10fps instead of 60fps
  },

  setupMobileEffects() {
    const effectsContainer = this.el.querySelector('#mobile-effects');
    if (!effectsContainer) return;

    // Only show essential effects on mobile
    const mobileEffects = ['reverb', 'eq', 'compressor'];
    
    mobileEffects.forEach(effectType => {
      const button = effectsContainer.querySelector(`[data-effect="${effectType}"]`);
      if (button) {
        button.addEventListener('touchstart', (e) => {
          e.preventDefault();
          this.toggleMobileEffect(effectType);
          this.hapticFeedback('light');
        });
      }
    });
  },

  setupQuickActions() {
    const quickActions = this.el.querySelector('#mobile-quick-actions');
    if (!quickActions) return;

    // Mute all
    const muteAllBtn = quickActions.querySelector('#mute-all-btn');
    if (muteAllBtn) {
      muteAllBtn.addEventListener('touchstart', (e) => {
        e.preventDefault();
        this.muteAllTracks();
        this.hapticFeedback('medium');
      });
    }

    // Solo current track
    const soloBtn = quickActions.querySelector('#solo-current-btn');
    if (soloBtn) {
      soloBtn.addEventListener('touchstart', (e) => {
        e.preventDefault();
        this.soloCurrentTrack();
        this.hapticFeedback('medium');
      });
    }
  },

  // Audio Engine Integration
  togglePlayback() {
    if (this.isPlaying) {
      this.stopPlayback();
    } else {
      this.startPlayback();
    }
  },

  startPlayback() {
    this.isPlaying = true;
    this.updateTransportUI();
    this.pushEvent('mobile_audio_start_playback', { position: 0 });
  },

  stopPlayback() {
    this.isPlaying = false;
    this.updateTransportUI();
    this.pushEvent('mobile_audio_stop_playback', {});
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
      // Request permissions first
      await this.requestMicrophonePermission();
      
      this.isRecording = true;
      this.updateTransportUI();
      this.pushEvent('mobile_audio_start_recording', { 
        track_index: this.currentTrackIndex 
      });
      
      this.showRecordingIndicator();
    } catch (error) {
      this.showMobileError('Microphone access denied');
    }
  },

  stopRecording() {
    this.isRecording = false;
    this.updateTransportUI();
    this.pushEvent('mobile_audio_stop_recording', { 
      track_index: this.currentTrackIndex 
    });
    
    this.hideRecordingIndicator();
  },

  async requestMicrophonePermission() {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      stream.getTracks().forEach(track => track.stop()); // Stop immediately, just testing permission
      return true;
    } catch (error) {
      throw new Error('Microphone permission required');
    }
  },

  // Track Management
  switchToNextTrack() {
    const totalTracks = this.getTotalTracks();
    if (totalTracks === 0) return;
    
    this.currentTrackIndex = (this.currentTrackIndex + 1) % totalTracks;
    this.updateTrackDisplay();
  },

  switchToPreviousTrack() {
    const totalTracks = this.getTotalTracks();
    if (totalTracks === 0) return;
    
    this.currentTrackIndex = this.currentTrackIndex === 0 ? totalTracks - 1 : this.currentTrackIndex - 1;
    this.updateTrackDisplay();
  },

  updateTrackDisplay() {
    this.updateTrackIndicator();
    this.updateTrackControls();
    this.pushEvent('mobile_track_changed', { 
      track_index: this.currentTrackIndex 
    });
  },

  getTotalTracks() {
    const trackElements = this.el.querySelectorAll('[data-mobile-track]');
    return trackElements.length;
  },

  // UI Updates
  updateTransportUI() {
    const playBtn = this.el.querySelector('#mobile-play-btn');
    const recordBtn = this.el.querySelector('#mobile-record-btn');
    
    if (playBtn) {
      playBtn.classList.toggle('playing', this.isPlaying);
      playBtn.querySelector('.btn-text').textContent = this.isPlaying ? 'Stop' : 'Play';
    }
    
    if (recordBtn) {
      recordBtn.classList.toggle('recording', this.isRecording);
      recordBtn.querySelector('.btn-text').textContent = this.isRecording ? 'Stop' : 'Record';
    }
  },

  updateTrackIndicator() {
    const indicator = this.el.querySelector('#track-indicator');
    const totalTracks = this.getTotalTracks();
    
    if (indicator && totalTracks > 0) {
      indicator.textContent = `${this.currentTrackIndex + 1} / ${totalTracks}`;
      
      // Update track dots
      const dots = this.el.querySelectorAll('.track-dot');
      dots.forEach((dot, index) => {
        dot.classList.toggle('active', index === this.currentTrackIndex);
      });
    }
  },

  updateTrackControls() {
    const currentTrack = this.getCurrentTrackData();
    if (!currentTrack) return;

    // Update volume slider
    const volumeSlider = this.el.querySelector('#mobile-volume-slider');
    if (volumeSlider) {
      volumeSlider.value = currentTrack.volume || 0.8;
    }

    // Update mute button
    const muteBtn = this.el.querySelector('#mobile-mute-btn');
    if (muteBtn) {
      muteBtn.classList.toggle('muted', currentTrack.muted);
    }

    // Update track name
    const trackName = this.el.querySelector('#current-track-name');
    if (trackName) {
      trackName.textContent = currentTrack.name || `Track ${this.currentTrackIndex + 1}`;
    }
  },

  updateMobileLevels() {
    // Simplified level updates for mobile
    const levelMeter = this.el.querySelector('#mobile-level-meter .level-fill');
    if (levelMeter && this.audioEngine) {
      // Get simplified level data
      const level = this.audioEngine.getCurrentTrackLevel(this.currentTrackIndex);
      const percentage = Math.min(100, level * 100);
      levelMeter.style.width = `${percentage}%`;
      
      // Update color based on level
      if (level > 0.8) {
        levelMeter.className = 'level-fill level-red';
      } else if (level > 0.6) {
        levelMeter.className = 'level-fill level-yellow';
      } else {
        levelMeter.className = 'level-fill level-green';
      }
    }
  },

  // Mobile-specific features
  enablePowerSaveMode() {
    if (this.batteryOptimized) return;
    
    this.batteryOptimized = true;
    
    // Reduce update frequency
    if (this.updateInterval) {
      clearInterval(this.updateInterval);
      this.updateInterval = setInterval(() => {
        this.updateMobileLevels();
      }, 200); // 5fps
    }
    
    // Show power save indicator
    this.showPowerSaveIndicator();
    
    console.log('Power save mode enabled');
  },

  disablePowerSaveMode() {
    if (!this.batteryOptimized) return;
    
    this.batteryOptimized = false;
    
    // Restore normal update frequency
    if (this.updateInterval) {
      clearInterval(this.updateInterval);
      this.updateInterval = setInterval(() => {
        this.updateMobileLevels();
      }, 100); // 10fps
    }
    
    // Hide power save indicator
    this.hidePowerSaveIndicator();
    
    console.log('Power save mode disabled');
  },

  hapticFeedback(intensity = 'light') {
    if ('vibrate' in navigator) {
      switch (intensity) {
        case 'light':
          navigator.vibrate(10);
          break;
        case 'medium':
          navigator.vibrate(25);
          break;
        case 'heavy':
          navigator.vibrate([50, 10, 50]);
          break;
      }
    }
  },

  // UI State Management
  showRecordingIndicator() {
    const indicator = this.el.querySelector('#recording-indicator');
    if (indicator) {
      indicator.classList.remove('hidden');
    }
  },

  hideRecordingIndicator() {
    const indicator = this.el.querySelector('#recording-indicator');
    if (indicator) {
      indicator.classList.add('hidden');
    }
  },

  showPowerSaveIndicator() {
    const indicator = this.el.querySelector('#power-save-indicator');
    if (indicator) {
      indicator.classList.remove('hidden');
    }
  },

  hidePowerSaveIndicator() {
    const indicator = this.el.querySelector('#power-save-indicator');
    if (indicator) {
      indicator.classList.add('hidden');
    }
  },

  showCompactControls() {
    const advanced = this.el.querySelector('#advanced-controls');
    if (advanced) {
      advanced.classList.add('hidden');
    }
  },

  showExpandedControls() {
    const advanced = this.el.querySelector('#advanced-controls');
    if (advanced) {
      advanced.classList.remove('hidden');
    }
  },

  collapseAdvancedControls() {
    const collapsible = this.el.querySelectorAll('.mobile-collapsible');
    collapsible.forEach(section => {
      section.classList.add('collapsed');
    });
  },

  showMobileError(message) {
    const errorContainer = this.el.querySelector('#mobile-error');
    if (errorContainer) {
      errorContainer.textContent = message;
      errorContainer.classList.remove('hidden');
      
      setTimeout(() => {
        errorContainer.classList.add('hidden');
      }, 3000);
    }
  },

  // Event Handlers
  handleTouchStart(e) {
    e.currentTarget.classList.add('touch-active');
  },

  handleTouchEnd(e) {
    e.currentTarget.classList.remove('touch-active');
  },

  handleTouchCancel(e) {
    e.currentTarget.classList.remove('touch-active');
  },

  handleSliderChange(slider) {
    const value = parseFloat(slider.value);
    const type = slider.dataset.control;
    
    switch (type) {
      case 'volume':
        this.updateCurrentTrackVolume(value);
        break;
      case 'master':
        this.updateMasterVolume(value);
        break;
    }
  },

  // Helper Methods
  getCurrentTrackData() {
    const trackElements = this.el.querySelectorAll('[data-mobile-track]');
    return trackElements[this.currentTrackIndex]?.dataset || null;
  },

  updateCurrentTrackVolume(volume) {
    this.pushEvent('mobile_track_volume_change', {
      track_index: this.currentTrackIndex,
      volume: volume
    });
  },

  updateMasterVolume(volume) {
    this.pushEvent('mobile_master_volume_change', {
      volume: volume
    });
  },

  toggleMobileEffect(effectType) {
    this.pushEvent('mobile_toggle_effect', {
      track_index: this.currentTrackIndex,
      effect_type: effectType
    });
  },

  muteAllTracks() {
    this.pushEvent('mobile_mute_all_tracks', {});
  },

  soloCurrentTrack() {
    this.pushEvent('mobile_solo_track', {
      track_index: this.currentTrackIndex
    });
  },

  // Cleanup
  destroyed() {
    console.log('Mobile Audio Interface destroyed');
    
    if (this.updateInterval) {
      clearInterval(this.updateInterval);
    }
    
    if (this.audioEngine) {
      this.audioEngine.destroy();
    }
  }
};

// Simplified Mobile Audio Engine
class MobileAudioEngine {
  constructor(config) {
    this.config = config;
    this.tracks = [];
    this.currentLevel = 0;
    this.isInitialized = false;
  }

  async initialize() {
    // Simplified initialization for mobile
    try {
      this.audioContext = new (window.AudioContext || window.webkitAudioContext)({
        sampleRate: this.config.sampleRate,
        latencyHint: 'interactive'
      });

      if (this.audioContext.state === 'suspended') {
        await this.audioContext.resume();
      }

      this.isInitialized = true;
      console.log('Mobile Audio Engine initialized');
    } catch (error) {
      console.error('Mobile Audio Engine initialization failed:', error);
      throw error;
    }
  }

  getCurrentTrackLevel(trackIndex) {
    // Simplified level calculation
    return Math.random() * 0.8; // Mock data for now
  }

  destroy() {
    if (this.audioContext) {
      this.audioContext.close();
    }
  }
}

export default MobileAudioHook;