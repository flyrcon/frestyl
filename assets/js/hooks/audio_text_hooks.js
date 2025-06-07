// Add these to your app.js hooks object

// Timeline Waveform Visualization
const TimelineWaveform = {
  mounted() {
    this.canvas = this.el;
    this.ctx = this.canvas.getContext('2d');
    this.sessionId = this.el.dataset.sessionId;
    this.zoomLevel = parseFloat(this.el.dataset.zoomLevel) || 1.0;
    this.currentPosition = parseFloat(this.el.dataset.currentPosition) || 0;
    
    this.setupCanvas();
    this.drawWaveform();
    this.setupEventListeners();
  },

  updated() {
    this.zoomLevel = parseFloat(this.el.dataset.zoomLevel) || 1.0;
    this.currentPosition = parseFloat(this.el.dataset.currentPosition) || 0;
    this.drawWaveform();
  },

  setupCanvas() {
    const rect = this.canvas.getBoundingClientRect();
    const dpr = window.devicePixelRatio || 1;
    
    this.canvas.width = rect.width * dpr;
    this.canvas.height = rect.height * dpr;
    this.canvas.style.width = rect.width + 'px';
    this.canvas.style.height = rect.height + 'px';
    
    this.ctx.scale(dpr, dpr);
  },

  drawWaveform() {
    const width = this.canvas.width / (window.devicePixelRatio || 1);
    const height = this.canvas.height / (window.devicePixelRatio || 1);
    
    // Clear canvas
    this.ctx.clearRect(0, 0, width, height);
    
    // Draw background grid
    this.drawGrid(width, height);
    
    // Draw mock waveform (in production, you'd load actual audio data)
    this.drawMockWaveform(width, height);
    
    // Draw time markers
    this.drawTimeMarkers(width, height);
  },

  drawGrid(width, height) {
    this.ctx.strokeStyle = 'rgba(255, 255, 255, 0.1)';
    this.ctx.lineWidth = 1;
    
    // Vertical grid lines (time markers)
    const secondWidth = 100 * this.zoomLevel; // 100px per second at 1x zoom
    for (let x = 0; x < width; x += secondWidth) {
      this.ctx.beginPath();
      this.ctx.moveTo(x, 0);
      this.ctx.lineTo(x, height);
      this.ctx.stroke();
    }
    
    // Horizontal center line
    this.ctx.beginPath();
    this.ctx.moveTo(0, height / 2);
    this.ctx.lineTo(width, height / 2);
    this.ctx.stroke();
  },

  drawMockWaveform(width, height) {
    this.ctx.strokeStyle = '#4F46E5';
    this.ctx.lineWidth = 2;
    this.ctx.beginPath();
    
    const centerY = height / 2;
    const amplitude = height * 0.3;
    
    for (let x = 0; x < width; x++) {
      // Generate mock waveform data
      const time = x / (100 * this.zoomLevel); // Convert to seconds
      const freq1 = Math.sin(time * 2 * Math.PI * 0.5) * 0.5;
      const freq2 = Math.sin(time * 2 * Math.PI * 1.2) * 0.3;
      const noise = (Math.random() - 0.5) * 0.1;
      
      const y = centerY + (freq1 + freq2 + noise) * amplitude;
      
      if (x === 0) {
        this.ctx.moveTo(x, y);
      } else {
        this.ctx.lineTo(x, y);
      }
    }
    
    this.ctx.stroke();
  },

  drawTimeMarkers(width, height) {
    this.ctx.fillStyle = 'rgba(255, 255, 255, 0.7)';
    this.ctx.font = '12px Arial';
    
    const secondWidth = 100 * this.zoomLevel;
    
    for (let x = 0; x < width; x += secondWidth) {
      const timeInSeconds = x / (100 * this.zoomLevel);
      const minutes = Math.floor(timeInSeconds / 60);
      const seconds = Math.floor(timeInSeconds % 60);
      const timeString = `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
      
      this.ctx.fillText(timeString, x + 5, 15);
    }
  },

  setupEventListeners() {
    this.canvas.addEventListener('click', (e) => {
      const rect = this.canvas.getBoundingClientRect();
      const x = e.clientX - rect.left;
      const timeInMs = (x / (100 * this.zoomLevel)) * 1000;
      
      this.pushEvent('seek_to_position', { position: timeInMs.toString() });
    });
  }
};

// Teleprompter Auto-Scroll
const TeleprompterScroll = {
  mounted() {
    this.speed = parseFloat(this.el.dataset.speed) || 1.0;
    this.currentPosition = parseFloat(this.el.dataset.currentPosition) || 0;
    this.isScrolling = false;
    this.scrollInterval = null;
    
    this.setupAutoScroll();
  },

  updated() {
    this.speed = parseFloat(this.el.dataset.speed) || 1.0;
    this.currentPosition = parseFloat(this.el.dataset.currentPosition) || 0;
    
    if (this.isScrolling) {
      this.updateScrollPosition();
    }
  },

  setupAutoScroll() {
    // Listen for playback events
    window.addEventListener('phx:audio_text_playback_started', () => {
      this.startScrolling();
    });
    
    window.addEventListener('phx:audio_text_playback_stopped', () => {
      this.stopScrolling();
    });
  },

  startScrolling() {
    this.isScrolling = true;
    this.scrollInterval = setInterval(() => {
      this.updateScrollPosition();
    }, 100); // Update every 100ms
  },

  stopScrolling() {
    this.isScrolling = false;
    if (this.scrollInterval) {
      clearInterval(this.scrollInterval);
      this.scrollInterval = null;
    }
  },

  updateScrollPosition() {
    // Find the current block based on sync points
    const blocks = this.el.querySelectorAll('[data-block-id]');
    let currentBlock = null;
    
    blocks.forEach(block => {
      const startTime = parseFloat(block.dataset.startTime);
      if (startTime && this.currentPosition >= startTime) {
        currentBlock = block;
      }
    });
    
    if (currentBlock) {
      // Smooth scroll to center the current block
      const containerHeight = this.el.clientHeight;
      const blockTop = currentBlock.offsetTop;
      const blockHeight = currentBlock.clientHeight;
      const targetScroll = blockTop - (containerHeight / 2) + (blockHeight / 2);
      
      this.el.scrollTo({
        top: targetScroll,
        behavior: 'smooth'
      });
    }
  },

  destroyed() {
    this.stopScrolling();
  }
};

// Mobile Text Editor with Voice Input
const MobileTextEditor = {
  mounted() {
    this.textarea = this.el;
    this.recognition = null;
    this.isListening = false;
    
    this.setupVoiceRecognition();
    this.setupGestureControls();
  },

  setupVoiceRecognition() {
    if ('webkitSpeechRecognition' in window || 'SpeechRecognition' in window) {
      const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
      this.recognition = new SpeechRecognition();
      
      this.recognition.continuous = true;
      this.recognition.interimResults = true;
      
      this.recognition.onresult = (event) => {
        let finalTranscript = '';
        let interimTranscript = '';
        
        for (let i = event.resultIndex; i < event.results.length; i++) {
          if (event.results[i].isFinal) {
            finalTranscript += event.results[i][0].transcript;
          } else {
            interimTranscript += event.results[i][0].transcript;
          }
        }
        
        if (finalTranscript) {
          this.insertTextAtCursor(finalTranscript);
          this.pushEvent('text_update', {
            content: this.textarea.value,
            selection: { start: this.textarea.selectionStart, end: this.textarea.selectionEnd }
          });
        }
      };
      
      this.recognition.onerror = (event) => {
        console.error('Speech recognition error:', event.error);
        this.stopVoiceInput();
      };
    }
  },

  setupGestureControls() {
    let touchStartY = 0;
    let touchStartX = 0;
    
    this.textarea.addEventListener('touchstart', (e) => {
      touchStartY = e.touches[0].clientY;
      touchStartX = e.touches[0].clientX;
    });
    
    this.textarea.addEventListener('touchend', (e) => {
      const touchEndY = e.changedTouches[0].clientY;
      const touchEndX = e.changedTouches[0].clientX;
      const deltaY = touchEndY - touchStartY;
      const deltaX = touchEndX - touchStartX;
      
      // Two-finger swipe down to start voice input
      if (e.changedTouches.length === 2 && deltaY > 50) {
        this.startVoiceInput();
      }
      
      // Three-finger tap to create sync point
      if (e.changedTouches.length === 3 && Math.abs(deltaX) < 30 && Math.abs(deltaY) < 30) {
        this.pushEvent('create_sync_point_gesture', {});
      }
    });
  },

  startVoiceInput() {
    if (this.recognition && !this.isListening) {
      this.isListening = true;
      this.recognition.start();
      
      // Visual feedback
      this.textarea.style.borderColor = '#EF4444';
      this.textarea.placeholder = 'Listening... Speak now';
    }
  },

  stopVoiceInput() {
    if (this.recognition && this.isListening) {
      this.isListening = false;
      this.recognition.stop();
      
      // Reset visual feedback
      this.textarea.style.borderColor = '';
      this.textarea.placeholder = 'Start writing your masterpiece...';
    }
  },

  insertTextAtCursor(text) {
    const start = this.textarea.selectionStart;
    const end = this.textarea.selectionEnd;
    const value = this.textarea.value;
    
    this.textarea.value = value.substring(0, start) + text + value.substring(end);
    this.textarea.selectionStart = this.textarea.selectionEnd = start + text.length;
  }
};

// Mobile Gesture Recognition
const MobileGestures = {
  mounted() {
    this.touchStartX = 0;
    this.touchStartY = 0;
    this.touchStartTime = 0;
    this.longPressTimer = null;
    
    this.setupGestureListeners();
  },

  setupGestureListeners() {
    this.el.addEventListener('touchstart', this.handleTouchStart.bind(this));
    this.el.addEventListener('touchend', this.handleTouchEnd.bind(this));
    this.el.addEventListener('touchmove', this.handleTouchMove.bind(this));
  },

  handleTouchStart(e) {
    this.touchStartX = e.touches[0].clientX;
    this.touchStartY = e.touches[0].clientY;
    this.touchStartTime = Date.now();
    
    // Set up long press detection
    this.longPressTimer = setTimeout(() => {
      this.pushEvent('mobile_gesture', {
        gesture: 'long_press',
        direction: null,
        x: this.touchStartX,
        y: this.touchStartY
      });
    }, 800);
  },

  handleTouchMove(e) {
    // Cancel long press if finger moves
    if (this.longPressTimer) {
      clearTimeout(this.longPressTimer);
      this.longPressTimer = null;
    }
  },

  handleTouchEnd(e) {
    if (this.longPressTimer) {
      clearTimeout(this.longPressTimer);
      this.longPressTimer = null;
    }
    
    const touchEndX = e.changedTouches[0].clientX;
    const touchEndY = e.changedTouches[0].clientY;
    const touchDuration = Date.now() - this.touchStartTime;
    
    const deltaX = touchEndX - this.touchStartX;
    const deltaY = touchEndY - this.touchStartY;
    const distance = Math.sqrt(deltaX * deltaX + deltaY * deltaY);
    
    // Detect double tap
    if (touchDuration < 300 && distance < 30) {
      if (this.lastTapTime && Date.now() - this.lastTapTime < 500) {
        this.pushEvent('mobile_gesture', {
          gesture: 'double_tap',
          direction: null
        });
      }
      this.lastTapTime = Date.now();
      return;
    }
    
    // Detect swipe gestures
    if (distance > 50 && touchDuration < 500) {
      let direction;
      
      if (Math.abs(deltaX) > Math.abs(deltaY)) {
        direction = deltaX > 0 ? 'right' : 'left';
      } else {
        direction = deltaY > 0 ? 'down' : 'up';
      }
      
      this.pushEvent('mobile_gesture', {
        gesture: 'swipe',
        direction: direction,
        distance: distance
      });
    }
  },

  destroyed() {
    if (this.longPressTimer) {
      clearTimeout(this.longPressTimer);
    }
  }
};

// Beat Detection Visualizer
const BeatVisualizer = {
  mounted() {
    this.canvas = this.el;
    this.ctx = this.canvas.getContext('2d');
    this.beats = [];
    this.isPlaying = false;
    this.currentTime = 0;
    
    this.setupCanvas();
    this.startAnimation();
    
    // Listen for beat events
    window.addEventListener('phx:beats_detected', (e) => {
      this.beats = e.detail.beats || [];
      this.bpm = e.detail.bpm || 120;
    });
  },

  setupCanvas() {
    const rect = this.canvas.getBoundingClientRect();
    this.canvas.width = rect.width;
    this.canvas.height = rect.height;
  },

  startAnimation() {
    const animate = () => {
      this.draw();
      requestAnimationFrame(animate);
    };
    animate();
  },

  draw() {
    const width = this.canvas.width;
    const height = this.canvas.height;
    
    // Clear canvas
    this.ctx.clearRect(0, 0, width, height);
    
    if (this.beats.length === 0) return;
    
    // Draw beat indicators
    this.ctx.fillStyle = '#A855F7';
    
    this.beats.forEach((beatTime, index) => {
      const timeDiff = Math.abs(this.currentTime - beatTime);
      const alpha = Math.max(0, 1 - (timeDiff / 200)); // Fade over 200ms
      
      if (alpha > 0) {
        this.ctx.globalAlpha = alpha;
        const x = (index % 8) * (width / 8) + (width / 16);
        const y = Math.floor(index / 8) * (height / 4) + (height / 8);
        const radius = 10 + (1 - alpha) * 20; // Expand as it fades
        
        this.ctx.beginPath();
        this.ctx.arc(x, y, radius, 0, 2 * Math.PI);
        this.ctx.fill();
      }
    });
    
    this.ctx.globalAlpha = 1;
  }
};

// Export hooks for use in app.js
export const AudioTextHooks = {
  TimelineWaveform,
  TeleprompterScroll,
  MobileTextEditor,
  MobileGestures,
  BeatVisualizer
};