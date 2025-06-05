// assets/js/enhanced_audio_hooks.js
// Phase 8: Enhanced Audio Collaboration Client-Side Hooks

export const EnhancedAudioHooks = {
  // Enhanced effect parameter control with real-time updates
  EffectParameterControl: {
    mounted() {
      this.trackId = this.el.dataset.trackId;
      this.effectId = this.el.dataset.effectId;
      this.parameter = this.el.dataset.parameter;
      this.lastUpdateTime = 0;
      this.updateThrottleMs = 16; // ~60 FPS
      this.pendingValue = null;
      
      // Throttled update function
      this.throttledUpdate = this.throttle((value) => {
        this.pushEvent("audio_effect_parameter_update", {
          track_id: this.trackId,
          effect_id: this.effectId,
          parameter: this.parameter,
          value: parseFloat(value)
        });
      }, this.updateThrottleMs);
      
      // Handle real-time parameter changes
      this.el.addEventListener('input', (e) => {
        const value = e.target.value;
        this.pendingValue = value;
        
        // Update UI immediately for responsiveness
        this.updateParameterDisplay(value);
        
        // Throttled server update
        this.throttledUpdate(value);
      });
      
      // Handle parameter automation recording
      this.el.addEventListener('mousedown', (e) => {
        if (e.shiftKey) {
          this.startAutomationRecording();
        }
      });
      
      this.el.addEventListener('mouseup', () => {
        this.stopAutomationRecording();
      });
    },
    
    startAutomationRecording() {
      this.automationRecording = true;
      this.automationPoints = [];
      this.automationStartTime = Date.now();
      
      console.log('Started automation recording for', this.parameter);
    },
    
    stopAutomationRecording() {
      if (this.automationRecording) {
        this.automationRecording = false;
        
        if (this.automationPoints.length > 1) {
          this.pushEvent("audio_update_automation", {
            track_id: this.trackId,
            parameter: this.parameter,
            automation_points: this.automationPoints,
            curve_type: "linear"
          });
        }
        
        console.log('Stopped automation recording, recorded', this.automationPoints.length, 'points');
      }
    },
    
    updateParameterDisplay(value) {
      // Update visual feedback immediately
      const display = this.el.querySelector('.parameter-value');
      if (display) {
        display.textContent = this.formatParameterValue(value);
      }
      
      // Record automation point if recording
      if (this.automationRecording) {
        const time = Date.now() - this.automationStartTime;
        this.automationPoints.push({
          time: time,
          value: parseFloat(value),
          curve_type: "linear"
        });
      }
    },
    
    formatParameterValue(value) {
      return Math.round(parseFloat(value) * 100) + '%';
    },
    
    throttle(func, delay) {
      let timeoutId;
      let lastExecTime = 0;
      return function (...args) {
        const currentTime = Date.now();
        
        if (currentTime - lastExecTime > delay) {
          func.apply(this, args);
          lastExecTime = currentTime;
        } else {
          clearTimeout(timeoutId);
          timeoutId = setTimeout(() => {
            func.apply(this, args);
            lastExecTime = Date.now();
          }, delay - (currentTime - lastExecTime));
        }
      };
    },
    
    // Handle parameter updates from other users
    updated() {
      const newValue = this.el.value;
      if (newValue !== this.pendingValue) {
        this.updateParameterDisplay(newValue);
      }
    }
  },

  // Enhanced beat machine step sequencer
  BeatMachineStep: {
    mounted() {
      this.patternId = this.el.dataset.patternId;
      this.instrument = this.el.dataset.instrument;
      this.step = parseInt(this.el.dataset.step);
      this.velocity = 0;
      this.isPlaying = false;
      
      // Multi-interaction support
      this.el.addEventListener('mousedown', this.handleMouseDown.bind(this));
      this.el.addEventListener('mouseup', this.handleMouseUp.bind(this));
      this.el.addEventListener('contextmenu', this.handleRightClick.bind(this));
      
      // Touch support for mobile
      this.el.addEventListener('touchstart', this.handleTouchStart.bind(this));
      this.el.addEventListener('touchend', this.handleTouchEnd.bind(this));
      
      // Keyboard support
      this.el.addEventListener('keydown', this.handleKeyDown.bind(this));
      
      this.el.tabIndex = 0; // Make focusable
    },
    
    handleMouseDown(e) {
      e.preventDefault();
      
      const modifierKeys = {
        shift: e.shiftKey,
        ctrl: e.ctrlKey,
        alt: e.altKey
      };
      
      if (e.button === 0) { // Left click
        this.toggleStep(modifierKeys);
      }
    },
    
    handleMouseUp(e) {
      // Handle mouse up if needed
    },
    
    handleRightClick(e) {
      e.preventDefault();
      // Right click could open step settings
      this.openStepSettings();
    },
    
    handleTouchStart(e) {
      e.preventDefault();
      this.toggleStep({});
    },
    
    handleTouchEnd(e) {
      e.preventDefault();
    },
    
    handleKeyDown(e) {
      const modifierKeys = {
        shift: e.shiftKey,
        ctrl: e.ctrlKey,
        alt: e.altKey
      };
      
      switch(e.key) {
        case ' ':
        case 'Enter':
          e.preventDefault();
          this.toggleStep(modifierKeys);
          break;
        case 'Delete':
        case 'Backspace':
          e.preventDefault();
          this.clearStep();
          break;
        case '1':
        case '2':
        case '3':
        case '4':
          e.preventDefault();
          const velocity = parseInt(e.key) * 31; // 1=31, 2=62, 3=93, 4=124
          this.setStepVelocity(velocity, modifierKeys);
          break;
      }
    },
    
    toggleStep(modifierKeys = {}) {
      let newVelocity;
      
      if (this.velocity > 0) {
        // Step is active, turn it off
        newVelocity = 0;
      } else {
        // Step is inactive, turn it on
        if (modifierKeys.shift) {
          newVelocity = 63; // Medium velocity
        } else if (modifierKeys.ctrl) {
          newVelocity = 31; // Low velocity
        } else {
          newVelocity = 127; // Full velocity
        }
      }
      
      this.updateStep(newVelocity, modifierKeys);
    },
    
    setStepVelocity(velocity, modifierKeys = {}) {
      this.updateStep(velocity, modifierKeys);
    },
    
    clearStep() {
      this.updateStep(0, {});
    },
    
    updateStep(velocity, modifierKeys) {
      this.velocity = velocity;
      this.updateVisualState();
      
      // Send enhanced update with modifier keys
      this.pushEvent("beat_update_step_enhanced", {
        pattern_id: this.patternId,
        instrument: this.instrument,
        step: this.step.toString(),
        velocity: velocity.toString(),
        modifier_keys: modifierKeys
      });
    },
    
    updateVisualState() {
      this.el.classList.remove('step-off', 'step-low', 'step-medium', 'step-high');
      
      if (this.velocity === 0) {
        this.el.classList.add('step-off');
      } else if (this.velocity <= 42) {
        this.el.classList.add('step-low');
      } else if (this.velocity <= 84) {
        this.el.classList.add('step-medium');
      } else {
        this.el.classList.add('step-high');
      }
      
      // Update data attribute for CSS styling
      this.el.dataset.velocity = this.velocity;
    },
    
    openStepSettings() {
      // Could open a modal for detailed step settings
      console.log('Opening step settings for', this.instrument, 'step', this.step);
    },
    
    // Handle step sync from server
    updated() {
      const newVelocity = parseInt(this.el.dataset.velocity || '0');
      if (newVelocity !== this.velocity) {
        this.velocity = newVelocity;
        this.updateVisualState();
      }
    }
  },

  // Enhanced audio clip manipulation
  AudioClipManipulator: {
    mounted() {
      this.clipId = this.el.dataset.clipId;
      this.trackId = this.el.dataset.trackId;
      this.startTime = parseFloat(this.el.dataset.startTime || '0');
      this.duration = parseFloat(this.el.dataset.duration || '1000');
      
      this.isDragging = false;
      this.isResizing = false;
      this.dragStartX = 0;
      this.dragStartTime = 0;
      this.snapToGrid = true;
      this.gridSize = 1000; // 1 second default
      
      this.setupInteractions();
    },
    
    setupInteractions() {
      // Main clip area - dragging
      this.el.addEventListener('mousedown', this.handleMouseDown.bind(this));
      
      // Resize handles
      const leftHandle = this.el.querySelector('.resize-left');
      const rightHandle = this.el.querySelector('.resize-right');
      
      if (leftHandle) {
        leftHandle.addEventListener('mousedown', this.handleResizeStart.bind(this, 'left'));
      }
      
      if (rightHandle) {
        rightHandle.addEventListener('mousedown', this.handleResizeStart.bind(this, 'right'));
      }
      
      // Global mouse events
      document.addEventListener('mousemove', this.handleMouseMove.bind(this));
      document.addEventListener('mouseup', this.handleMouseUp.bind(this));
      
      // Keyboard shortcuts
      this.el.addEventListener('keydown', this.handleKeyDown.bind(this));
      this.el.tabIndex = 0;
    },
    
    handleMouseDown(e) {
      if (e.target === this.el || e.target.classList.contains('clip-content')) {
        e.preventDefault();
        this.startDrag(e);
      }
    },
    
    handleResizeStart(side, e) {
      e.preventDefault();
      e.stopPropagation();
      
      this.isResizing = side;
      this.dragStartX = e.clientX;
      this.dragStartTime = this.startTime;
      this.dragStartDuration = this.duration;
    },
    
    startDrag(e) {
      this.isDragging = true;
      this.dragStartX = e.clientX;
      this.dragStartTime = this.startTime;
      
      this.el.classList.add('dragging');
    },
    
    handleMouseMove(e) {
      if (this.isDragging) {
        this.handleDragMove(e);
      } else if (this.isResizing) {
        this.handleResizeMove(e);
      }
    },
    
    handleDragMove(e) {
      const deltaX = e.clientX - this.dragStartX;
      const deltaTime = this.pixelsToTime(deltaX);
      let newStartTime = this.dragStartTime + deltaTime;
      
      if (this.snapToGrid) {
        newStartTime = this.snapToGridValue(newStartTime);
      }
      
      // Prevent negative time
      newStartTime = Math.max(0, newStartTime);
      
      this.updateClipPosition(newStartTime);
    },
    
    handleResizeMove(e) {
      const deltaX = e.clientX - this.dragStartX;
      const deltaTime = this.pixelsToTime(deltaX);
      
      if (this.isResizing === 'left') {
        let newStartTime = this.dragStartTime + deltaTime;
        let newDuration = this.dragStartDuration - deltaTime;
        
        if (this.snapToGrid) {
          newStartTime = this.snapToGridValue(newStartTime);
          newDuration = this.dragStartDuration - (newStartTime - this.dragStartTime);
        }
        
        newStartTime = Math.max(0, newStartTime);
        newDuration = Math.max(100, newDuration); // Minimum duration
        
        this.updateClipBounds(newStartTime, newDuration);
      } else if (this.isResizing === 'right') {
        let newDuration = this.dragStartDuration + deltaTime;
        
        if (this.snapToGrid) {
          const newEndTime = this.snapToGridValue(this.startTime + newDuration);
          newDuration = newEndTime - this.startTime;
        }
        
        newDuration = Math.max(100, newDuration);
        
        this.updateClipBounds(this.startTime, newDuration);
      }
    },
    
    handleMouseUp(e) {
      if (this.isDragging) {
        this.finalizeDrag();
      } else if (this.isResizing) {
        this.finalizeResize();
      }
    },
    
    finalizeDrag() {
      this.isDragging = false;
      this.el.classList.remove('dragging');
      
      // Send update to server
      this.pushEvent("audio_move_clip_enhanced", {
        clip_id: this.clipId,
        new_track_id: this.trackId,
        new_start_time: this.startTime.toString(),
        snap_to_grid: this.snapToGrid
      });