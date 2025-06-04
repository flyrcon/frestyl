// assets/js/hooks/audio_workspace_hooks.js

// Audio Track Component Hook
export const AudioTrack = {
  mounted() {
    this.trackId = this.el.dataset.trackId;
    this.initializeAudioControls();
  },

  updated() {
    this.updateTrackState();
  },

  initializeAudioControls() {
    // Initialize track-specific audio controls
    console.log(`Audio track ${this.trackId} initialized`);
  },

  updateTrackState() {
    // Update track state based on changes
  }
};

// Waveform Canvas Hook
export const WaveformCanvas = {
  mounted() {
    this.canvas = this.el.querySelector('canvas');
    this.ctx = this.canvas.getContext('2d');
    this.trackId = this.el.dataset.trackId;
    this.zoomLevel = parseFloat(this.el.dataset.zoomLevel) || 1.0;
    
    this.initializeCanvas();
    this.renderWaveforms();
  },

  updated() {
    this.zoomLevel = parseFloat(this.el.dataset.zoomLevel) || 1.0;
    this.renderWaveforms();
  },

  initializeCanvas() {
    // Set canvas size
    const rect = this.el.getBoundingClientRect();
    this.canvas.width = rect.width * window.devicePixelRatio;
    this.canvas.height = rect.height * window.devicePixelRatio;
    this.canvas.style.width = rect.width + 'px';
    this.canvas.style.height = rect.height + 'px';
    
    this.ctx.scale(window.devicePixelRatio, window.devicePixelRatio);
  },

  renderWaveforms() {
    this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
    
    // Render each clip's waveform
    const clips = this.el.querySelectorAll('[data-clip-id]');
    clips.forEach(clipEl => {
      const clipCanvas = clipEl.querySelector('canvas');
      if (clipCanvas) {
        this.renderClipWaveform(clipCanvas, clipEl.dataset.clipId);
      }
    });
  },

  renderClipWaveform(canvas, clipId) {
    const ctx = canvas.getContext('2d');
    const waveformData = JSON.parse(canvas.dataset.waveformData || '[]');
    
    if (waveformData.length === 0) return;
    
    const rect = canvas.getBoundingClientRect();
    canvas.width = rect.width * window.devicePixelRatio;
    canvas.height = rect.height * window.devicePixelRatio;
    canvas.style.width = rect.width + 'px';
    canvas.style.height = rect.height + 'px';
    
    ctx.scale(window.devicePixelRatio, window.devicePixelRatio);
    
    // Render waveform
    ctx.strokeStyle = 'rgba(255, 255, 255, 0.8)';
    ctx.lineWidth = 1;
    ctx.beginPath();
    
    const width = rect.width;
    const height = rect.height;
    const centerY = height / 2;
    
    waveformData.forEach((amplitude, index) => {
      const x = (index / waveformData.length) * width;
      const y = centerY + (amplitude * centerY * 0.8);
      
      if (index === 0) {
        ctx.moveTo(x, y);
      } else {
        ctx.lineTo(x, y);
      }
    });
    
    ctx.stroke();
  }
};

// Live Waveform Hook for Recording
export const LiveWaveform = {
  mounted() {
    this.canvas = this.el;
    this.ctx = this.canvas.getContext('2d');
    this.buffer = [];
    this.animationFrame = null;
    
    this.initializeCanvas();
    this.startAnimation();
  },

  beforeDestroy() {
    if (this.animationFrame) {
      cancelAnimationFrame(this.animationFrame);
    }
  },

  updated() {
    const newBuffer = JSON.parse(this.el.dataset.buffer || '[]');
    this.buffer = newBuffer;
  },

  initializeCanvas() {
    const rect = this.canvas.getBoundingClientRect();
    this.canvas.width = rect.width * window.devicePixelRatio;
    this.canvas.height = rect.height * window.devicePixelRatio;
    this.canvas.style.width = rect.width + 'px';
    this.canvas.style.height = rect.height + 'px';
    
    this.ctx.scale(window.devicePixelRatio, window.devicePixelRatio);
  },

  startAnimation() {
    const render = () => {
      this.renderWaveform();
      this.animationFrame = requestAnimationFrame(render);
    };
    render();
  },

  renderWaveform() {
    const width = this.canvas.clientWidth;
    const height = this.canvas.clientHeight;
    
    // Clear canvas
    this.ctx.fillStyle = 'rgba(0, 0, 0, 0.1)';
    this.ctx.fillRect(0, 0, width, height);
    
    if (this.buffer.length === 0) return;
    
    // Draw waveform
    this.ctx.strokeStyle = '#10b981';
    this.ctx.lineWidth = 2;
    this.ctx.beginPath();
    
    const centerY = height / 2;
    
    this.buffer.forEach((level, index) => {
      const x = (index / this.buffer.length) * width;
      const y = centerY + (level * centerY * 0.8);
      
      if (index === 0) {
        this.ctx.moveTo(x, y);
      } else {
        this.ctx.lineTo(x, y);
      }
    });
    
    this.ctx.stroke();
    
    // Draw center line
    this.ctx.strokeStyle = 'rgba(255, 255, 255, 0.2)';
    this.ctx.lineWidth = 1;
    this.ctx.beginPath();
    this.ctx.moveTo(0, centerY);
    this.ctx.lineTo(width, centerY);
    this.ctx.stroke();
  }
};

// Mobile Waveform Hook
export const MobileWaveform = {
  mounted() {
    this.trackId = this.el.dataset.trackId;
    this.setupTouchEvents();
  },

  setupTouchEvents() {
    this.el.addEventListener('touchstart', (e) => {
      const touch = e.touches[0];
      const rect = this.el.getBoundingClientRect();
      const x = touch.clientX - rect.left;
      
      this.pushEvent('waveform_touch_start', {
        x: x,
        timestamp: Date.now()
      });
    });

    this.el.addEventListener('touchend', (e) => {
      const touch = e.changedTouches[0];
      const rect = this.el.getBoundingClientRect();
      const x = touch.clientX - rect.left;
      
      this.pushEvent('waveform_touch_end', {
        x: x,
        timestamp: Date.now()
      });
    });
  }
};

// Beat Machine Step Sequencer Hook
export const BeatMachine = {
  mounted() {
    this.initializeBeatMachine();
  },

  initializeBeatMachine() {
    // Initialize beat machine specific functionality
    console.log('Beat machine initialized');
    
    // Setup step highlighting
    this.setupStepHighlighting();
  },

  setupStepHighlighting() {
    // Listen for step trigger events
    this.handleEvent('beat_step_triggered', ({ step, instruments }) => {
      this.highlightStep(step);
    });
  },

  highlightStep(step) {
    // Remove previous highlights
    this.el.querySelectorAll('.step-highlight').forEach(el => {
      el.classList.remove('step-highlight');
    });
    
    // Add highlight to current step
    const stepButtons = this.el.querySelectorAll(`[phx-value-step="${step}"]`);
    stepButtons.forEach(button => {
      button.classList.add('step-highlight');
      setTimeout(() => {
        button.classList.remove('step-highlight');
      }, 100);
    });
  }
};

// Mobile Live Waveform Hook
export const MobileLiveWaveform = {
  mounted() {
    this.canvas = this.el;
    this.ctx = this.canvas.getContext('2d');
    this.buffer = [];
    this.animationFrame = null;
    
    this.initializeCanvas();
    this.startAnimation();
  },

  beforeDestroy() {
    if (this.animationFrame) {
      cancelAnimationFrame(this.animationFrame);
    }
  },

  updated() {
    const newBuffer = JSON.parse(this.el.dataset.buffer || '[]');
    this.buffer = newBuffer;
  },

  initializeCanvas() {
    const rect = this.canvas.getBoundingClientRect();
    this.canvas.width = rect.width * window.devicePixelRatio;
    this.canvas.height = rect.height * window.devicePixelRatio;
    this.canvas.style.width = rect.width + 'px';
    this.canvas.style.height = rect.height + 'px';
    
    this.ctx.scale(window.devicePixelRatio, window.devicePixelRatio);
  },

  startAnimation() {
    const render = () => {
      this.renderMobileWaveform();
      this.animationFrame = requestAnimationFrame(render);
    };
    render();
  },

  renderMobileWaveform() {
    const width = this.canvas.clientWidth;
    const height = this.canvas.clientHeight;
    
    // Clear with fade effect
    this.ctx.fillStyle = 'rgba(0, 0, 0, 0.2)';
    this.ctx.fillRect(0, 0, width, height);
    
    if (this.buffer.length === 0) return;
    
    // Draw simplified mobile waveform
    this.ctx.strokeStyle = '#3b82f6';
    this.ctx.lineWidth = 1.5;
    this.ctx.beginPath();
    
    const centerY = height / 2;
    const barWidth = width / this.buffer.length;
    
    this.buffer.forEach((level, index) => {
      const x = index * barWidth;
      const barHeight = level * height * 0.8;
      
      this.ctx.fillStyle = `rgba(59, 130, 246, ${level})`;
      this.ctx.fillRect(x, centerY - barHeight/2, barWidth - 1, barHeight);
    });
  }
};

// Take Waveform Hook for playback visualization
export const TakeWaveform = {
  mounted() {
    this.canvas = this.el;
    this.ctx = this.canvas.getContext('2d');
    this.takeId = this.el.dataset.takeId;
    this.waveformData = JSON.parse(this.el.dataset.waveform || '[]');
    
    this.initializeCanvas();
    this.renderTakeWaveform();
  },

  initializeCanvas() {
    const rect = this.canvas.getBoundingClientRect();
    this.canvas.width = rect.width * window.devicePixelRatio;
    this.canvas.height = rect.height * window.devicePixelRatio;
    this.canvas.style.width = rect.width + 'px';
    this.canvas.style.height = rect.height + 'px';
    
    this.ctx.scale(window.devicePixelRatio, window.devicePixelRatio);
  },

  renderTakeWaveform() {
    const width = this.canvas.clientWidth;
    const height = this.canvas.clientHeight;
    
    // Clear canvas
    this.ctx.clearRect(0, 0, width, height);
    
    if (this.waveformData.length === 0) return;
    
    // Draw take waveform
    this.ctx.strokeStyle = '#10b981';
    this.ctx.fillStyle = 'rgba(16, 185, 129, 0.3)';
    this.ctx.lineWidth = 1;
    
    const centerY = height / 2;
    
    this.ctx.beginPath();
    this.ctx.moveTo(0, centerY);
    
    this.waveformData.forEach((amplitude, index) => {
      const x = (index / this.waveformData.length) * width;
      const y = centerY + (amplitude * centerY * 0.8);
      this.ctx.lineTo(x, y);
    });
    
    this.ctx.lineTo(width, centerY);
    this.ctx.closePath();
    this.ctx.fill();
    this.ctx.stroke();
  }
};