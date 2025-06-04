// assets/js/hooks/effects_integration_hook.js
import { EnhancedEffectsEngine } from '../audio/enhanced_effects_engine.js';

export const EffectsIntegrationHook = {
  mounted() {
    console.log('Effects Integration Hook mounted');
    
    this.trackId = this.el.dataset.trackId;
    this.sessionId = this.el.dataset.sessionId;
    this.effectsEngine = null;
    this.activeEffects = new Map();
    this.automationCurves = new Map();
    this.parameterHistory = new Map();
    
    // Initialize enhanced effects engine
    this.initializeEffectsEngine();
    
    // Setup real-time parameter updates
    this.setupParameterUpdates();
    
    // Setup effect visualization
    this.setupEffectVisualization();
    
    // Setup automation recording
    this.setupAutomationRecording();
  },

  async initializeEffectsEngine() {
    try {
      // Get audio context from existing audio engine or create new one
      const audioContext = window.audioEngine?.audioContext || 
                          new (window.AudioContext || window.webkitAudioContext)();
      
      this.effectsEngine = new EnhancedEffectsEngine({
        sampleRate: audioContext.sampleRate,
        bufferSize: 256,
        enableEffects: true,
        enableMonitoring: true,
        maxTracks: 8,
        maxConcurrentEffects: 16
      });
      
      await this.effectsEngine.initialize();
      
      // Integrate with existing audio engine if available
      if (window.audioEngine) {
        this.effectsEngine.integrateWithAudioEngine(window.audioEngine);
      }
      
      // Setup LiveView synchronization
      this.effectsEngine.syncWithLiveView(window.liveSocket);
      
      // Listen for effects engine events
      this.setupEffectsEngineListeners();
      
      this.pushEvent('effects_engine_ready', {
        track_id: this.trackId,
        capabilities: {
          maxEffects: this.effectsEngine.maxConcurrentEffects,
          workletSupported: !!audioContext.audioWorklet,
          sampleRate: audioContext.sampleRate
        }
      });
      
    } catch (error) {
      console.error('Failed to initialize effects engine:', error);
      this.pushEvent('effects_engine_error', {
        track_id: this.trackId,
        error: error.message
      });
    }
  },

  setupEffectsEngineListeners() {
    // Listen for effect addition/removal
    this.effectsEngine.on('realtime_effect_added', (data) => {
      this.activeEffects.set(data.effectId, data);
      this.updateEffectsUI();
      this.pushEvent('effect_added_client', data);
    });

    this.effectsEngine.on('realtime_effect_removed', (data) => {
      this.activeEffects.delete(data.effectId);
      this.updateEffectsUI();
      this.pushEvent('effect_removed_client', data);
    });

    // Listen for parameter changes
    this.effectsEngine.on('effect_parameter_changed', (data) => {
      this.updateParameterUI(data.effectId, data.paramName, data.value);
      
      // Record parameter history for automation
      if (this.automationRecording) {
        this.recordParameterChange(data);
      }
    });

    // Listen for performance updates
    this.effectsEngine.on('effects_engine_ready', () => {
      this.updateCPUUsage();
    });

    // Listen for visualization updates
    this.effectsEngine.on('effect_visualization_update', (data) => {
      this.updateEffectVisualization(data);
    });
  },

  setupParameterUpdates() {
    // Throttled parameter update function
    this.updateParameterThrottled = this.throttle((effectId, paramName, value, options) => {
      if (this.effectsEngine) {
        this.effectsEngine.updateEffectParameter(effectId, paramName, value, options);
      }
    }, 16); // ~60fps

    // Listen for slider/control changes
    this.el.addEventListener('input', (event) => {
      if (event.target.matches('[data-effect-param]')) {
        const effectId = event.target.dataset.effectId;
        const paramName = event.target.dataset.paramName;
        const value = parseFloat(event.target.value);
        
        // Update with smooth transition for real-time feel
        this.updateParameterThrottled(effectId, paramName, value, { 
          smooth: true, 
          transitionTime: 0.01 
        });
      }
    });

    // Listen for discrete changes (dropdowns, buttons)
    this.el.addEventListener('change', (event) => {
      if (event.target.matches('[data-effect-param]')) {
        const effectId = event.target.dataset.effectId;
        const paramName = event.target.dataset.paramName;
        const value = event.target.type === 'checkbox' ? 
                     event.target.checked : 
                     parseFloat(event.target.value) || event.target.value;
        
        // Immediate update for discrete parameters
        if (this.effectsEngine) {
          this.effectsEngine.updateEffectParameter(effectId, paramName, value);
        }
      }
    });
  },

  setupEffectVisualization() {
    // Find all effect visualization canvases
    this.visualizationCanvases = new Map();
    
    const updateVisualizations = () => {
      this.el.querySelectorAll('[data-effect-visualization]').forEach(canvas => {
        const effectId = canvas.dataset.effectId;
        const effectType = canvas.dataset.effectType;
        
        if (!this.visualizationCanvases.has(effectId)) {
          this.visualizationCanvases.set(effectId, {
            canvas: canvas,
            ctx: canvas.getContext('2d'),
            type: effectType,
            animationId: null
          });
          
          this.startEffectVisualization(effectId);
        }
      });
      
      // Cleanup removed canvases
      for (const [effectId, viz] of this.visualizationCanvases.entries()) {
        if (!this.el.contains(viz.canvas)) {
          this.stopEffectVisualization(effectId);
          this.visualizationCanvases.delete(effectId);
        }
      }
    };
    
    // Initial setup
    updateVisualizations();
    
    // Setup mutation observer to detect new visualizations
    this.vizObserver = new MutationObserver(updateVisualizations);
    this.vizObserver.observe(this.el, { childList: true, subtree: true });
  },

  startEffectVisualization(effectId) {
    const viz = this.visualizationCanvases.get(effectId);
    if (!viz) return;
    
    const animate = () => {
      this.renderEffectVisualization(effectId);
      viz.animationId = requestAnimationFrame(animate);
    };
    
    animate();
  },

  stopEffectVisualization(effectId) {
    const viz = this.visualizationCanvases.get(effectId);
    if (viz && viz.animationId) {
      cancelAnimationFrame(viz.animationId);
      viz.animationId = null;
    }
  },

  renderEffectVisualization(effectId) {
    const viz = this.visualizationCanvases.get(effectId);
    if (!viz) return;
    
    const { canvas, ctx, type } = viz;
    const rect = canvas.getBoundingClientRect();
    
    // Set canvas size
    canvas.width = rect.width * window.devicePixelRatio;
    canvas.height = rect.height * window.devicePixelRatio;
    canvas.style.width = rect.width + 'px';
    canvas.style.height = rect.height + 'px';
    ctx.scale(window.devicePixelRatio, window.devicePixelRatio);
    
    // Clear canvas
    ctx.fillStyle = 'rgba(0, 0, 0, 0.1)';
    ctx.fillRect(0, 0, rect.width, rect.height);
    
    // Get effect data from engine
    const effect = this.effectsEngine?.realtimeEffects.get(effectId);
    if (!effect || !effect.visualizer) return;
    
    // Render based on effect type
    switch (type) {
      case 'parametric_eq':
        this.renderEQVisualization(ctx, rect, effect);
        break;
      case 'convolution_reverb':
        this.renderReverbVisualization(ctx, rect, effect);
        break;
      case 'multiband_compressor':
        this.renderCompressorVisualization(ctx, rect, effect);
        break;
      case 'spectral_gate':
        this.renderSpectralVisualization(ctx, rect, effect);
        break;
      default:
        this.renderGenericVisualization(ctx, rect, effect);
    }
  },

  renderEQVisualization(ctx, rect, effect) {
    const vizData = effect.visualizer.getVisualizationData();
    if (vizData.type !== 'frequency_response') return;
    
    const { width, height } = rect;
    const data = vizData.data;
    
    // Draw frequency response curve
    ctx.strokeStyle = '#10b981';
    ctx.lineWidth = 2;
    ctx.beginPath();
    
    for (let i = 0; i < data.length; i++) {
      const x = (i / (data.length - 1)) * width;
      const y = height - (data[i] * height);
      
      if (i === 0) {
        ctx.moveTo(x, y);
      } else {
        ctx.lineTo(x, y);
      }
    }
    
    ctx.stroke();
    
    // Draw frequency grid
    ctx.strokeStyle = 'rgba(255, 255, 255, 0.1)';
    ctx.lineWidth = 1;
    
    // Frequency lines (100Hz, 1kHz, 10kHz)
    const freqMarkers = [0.1, 0.3, 0.7]; // Normalized positions
    freqMarkers.forEach(pos => {
      const x = pos * width;
      ctx.beginPath();
      ctx.moveTo(x, 0);
      ctx.lineTo(x, height);
      ctx.stroke();
    });
    
    // dB lines
    const dbMarkers = [0.25, 0.5, 0.75]; // +6dB, 0dB, -6dB
    dbMarkers.forEach(pos => {
      const y = pos * height;
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(width, y);
      ctx.stroke();
    });
  },

  renderReverbVisualization(ctx, rect, effect) {
    const vizData = effect.visualizer.getVisualizationData();
    if (vizData.type !== 'impulse_response') return;
    
    const { width, height } = rect;
    const data = vizData.data;
    
    // Draw impulse response
    ctx.fillStyle = 'rgba(16, 185, 129, 0.6)';
    
    for (let i = 0; i < data.length; i++) {
      const x = (i / (data.length - 1)) * width;
      const barHeight = data[i] * height * 0.8;
      const y = height - barHeight;
      
      ctx.fillRect(x - 1, y, 2, barHeight);
    }
    
    // Draw decay envelope
    ctx.strokeStyle = '#10b981';
    ctx.lineWidth = 1;
    ctx.beginPath();
    
    for (let i = 0; i < data.length; i++) {
      const x = (i / (data.length - 1)) * width;
      const y = height - (data[i] * height * 0.8);
      
      if (i === 0) {
        ctx.moveTo(x, y);
      } else {
        ctx.lineTo(x, y);
      }
    }
    
    ctx.stroke();
  },

  renderCompressorVisualization(ctx, rect, effect) {
    const vizData = effect.visualizer.getVisualizationData();
    if (vizData.type !== 'gain_reduction') return;
    
    const { width, height } = rect;
    const gainReduction = vizData.data;
    
    // Draw gain reduction meter
    const meterWidth = width * 0.8;
    const meterHeight = height * 0.3;
    const meterX = (width - meterWidth) / 2;
    const meterY = (height - meterHeight) / 2;
    
    // Background
    ctx.fillStyle = 'rgba(255, 255, 255, 0.1)';
    ctx.fillRect(meterX, meterY, meterWidth, meterHeight);
    
    // Gain reduction bar
    const reductionWidth = gainReduction * meterWidth;
    ctx.fillStyle = `hsl(${120 - gainReduction * 120}, 70%, 50%)`;
    ctx.fillRect(meterX, meterY, reductionWidth, meterHeight);
    
    // Label
    ctx.fillStyle = 'white';
    ctx.font = '12px sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText(`-${(gainReduction * 20).toFixed(1)}dB`, width / 2, meterY - 10);
  },

  renderSpectralVisualization(ctx, rect, effect) {
    const vizData = effect.visualizer.getVisualizationData();
    if (vizData.type !== 'spectrogram') return;
    
    const { width, height } = rect;
    const data = vizData.data;
    
    // Draw spectrogram
    const barWidth = width / data.length;
    
    for (let i = 0; i < data.length; i++) {
      const x = i * barWidth;
      const magnitude = data[i];
      const barHeight = magnitude * height;
      const y = height - barHeight;
      
      // Color based on frequency and magnitude
      const hue = (i / data.length) * 240; // Blue to red across spectrum
      const saturation = 70;
      const lightness = 30 + magnitude * 40;
      
      ctx.fillStyle = `hsl(${hue}, ${saturation}%, ${lightness}%)`;
      ctx.fillRect(x, y, barWidth - 1, barHeight);
    }
  },

  renderGenericVisualization(ctx, rect, effect) {
    const vizData = effect.visualizer.getVisualizationData();
    if (vizData.type !== 'levels') return;
    
    const { width, height } = rect;
    const levels = vizData.data;
    
    // Draw input/output levels
    const barHeight = height * 0.3;
    const inputY = height * 0.2;
    const outputY = height * 0.6;
    
    // Input level
    ctx.fillStyle = 'rgba(59, 130, 246, 0.7)';
    ctx.fillRect(10, inputY, levels.input * (width - 20), barHeight);
    
    // Output level
    ctx.fillStyle = 'rgba(16, 185, 129, 0.7)';
    ctx.fillRect(10, outputY, levels.output * (width - 20), barHeight);
    
    // Labels
    ctx.fillStyle = 'white';
    ctx.font = '10px sans-serif';
    ctx.textAlign = 'left';
    ctx.fillText('IN', 2, inputY + barHeight / 2);
    ctx.fillText('OUT', 2, outputY + barHeight / 2);
  },

  setupAutomationRecording() {
    this.automationRecording = false;
    this.automationStartTime = 0;
    
    // Listen for automation events from LiveView
    this.handleEvent('start_automation_recording', () => {
      this.startAutomationRecording();
    });
    
    this.handleEvent('stop_automation_recording', () => {
      this.stopAutomationRecording();
    });
    
    this.handleEvent('playback_automation', (data) => {
      this.playbackAutomation(data.effectId, data.paramName, data.curve, data.options);
    });
  },

  startAutomationRecording() {
    this.automationRecording = true;
    this.automationStartTime = Date.now();
    this.parameterHistory.clear();
    
    console.log('Started automation recording');
    
    this.pushEvent('automation_recording_started', {
      track_id: this.trackId,
      start_time: this.automationStartTime
    });
  },

  stopAutomationRecording() {
    this.automationRecording = false;
    
    // Process recorded automation curves
    const automationData = this.processParameterHistory();
    
    console.log('Stopped automation recording', automationData);
    
    this.pushEvent('automation_recording_stopped', {
      track_id: this.trackId,
      automation_data: automationData,
      duration: Date.now() - this.automationStartTime
    });
  },

  recordParameterChange(data) {
    if (!this.automationRecording) return;
    
    const { effectId, paramName, value } = data;
    const timestamp = Date.now() - this.automationStartTime;
    const key = `${effectId}_${paramName}`;
    
    if (!this.parameterHistory.has(key)) {
      this.parameterHistory.set(key, []);
    }
    
    this.parameterHistory.get(key).push({
      timestamp,
      value,
      effectId,
      paramName
    });
  },

  processParameterHistory() {
    const automationCurves = {};
    
    for (const [key, history] of this.parameterHistory.entries()) {
      if (history.length < 2) continue; // Need at least 2 points for automation
      
      const [effectId, paramName] = key.split('_');
      
      // Smooth and interpolate the curve
      const smoothedCurve = this.smoothAutomationCurve(history);
      
      if (!automationCurves[effectId]) {
        automationCurves[effectId] = {};
      }
      
      automationCurves[effectId][paramName] = {
        curve: smoothedCurve,
        duration: history[history.length - 1].timestamp,
        points: history.length
      };
    }
    
    return automationCurves;
  },

  smoothAutomationCurve(history) {
    if (history.length < 3) return history.map(h => h.value);
    
    // Apply simple smoothing filter
    const smoothed = [];
    const windowSize = 3;
    
    for (let i = 0; i < history.length; i++) {
      const start = Math.max(0, i - Math.floor(windowSize / 2));
      const end = Math.min(history.length, i + Math.ceil(windowSize / 2));
      
      let sum = 0;
      let count = 0;
      
      for (let j = start; j < end; j++) {
        sum += history[j].value;
        count++;
      }
      
      smoothed.push(sum / count);
    }
    
    return smoothed;
  },

  playbackAutomation(effectId, paramName, curve, options = {}) {
    if (!this.effectsEngine) return;
    
    const automationId = this.effectsEngine.automateParameter(
      effectId,
      paramName,
      curve,
      {
        startTime: options.startTime || this.effectsEngine.audioContext.currentTime,
        duration: options.duration || curve.length * 0.01,
        loop: options.loop || false
      }
    );
    
    console.log(`Started automation playback for ${effectId}:${paramName}`, automationId);
    
    return automationId;
  },

  // LiveView event handlers
  handleEvent(event, callback) {
    this.addEventListener(event, callback);
  },

  // Handle LiveView updates
  updated() {
    // Re-sync effects when component updates
    if (this.effectsEngine) {
      this.syncEffectsWithLiveView();
    }
  },

  syncEffectsWithLiveView() {
    // Get current effects from DOM
    const effectElements = this.el.querySelectorAll('[data-effect-id]');
    const currentEffects = new Set();
    
    effectElements.forEach(el => {
      const effectId = el.dataset.effectId;
      currentEffects.add(effectId);
      
      // Update parameter values from DOM
      const paramInputs = el.querySelectorAll('[data-effect-param]');
      paramInputs.forEach(input => {
        const paramName = input.dataset.paramName;
        const value = input.type === 'checkbox' ? input.checked : parseFloat(input.value);
        
        // Update effects engine if value changed
        const currentValue = this.effectsEngine.realtimeEffects.get(effectId)?.params[paramName];
        if (currentValue !== undefined && Math.abs(currentValue - value) > 0.001) {
          this.effectsEngine.updateEffectParameter(effectId, paramName, value);
        }
      });
    });
    
    // Remove effects that are no longer in DOM
    for (const effectId of this.activeEffects.keys()) {
      if (!currentEffects.has(effectId)) {
        this.effectsEngine.removeRealtimeEffect(effectId);
        this.activeEffects.delete(effectId);
      }
    }
  },

  updateEffectsUI() {
    // Update CPU usage display
    this.updateCPUUsage();
    
    // Update effect count
    const effectCount = this.activeEffects.size;
    this.pushEvent('effects_count_updated', {
      track_id: this.trackId,
      count: effectCount,
      max_effects: this.effectsEngine.maxConcurrentEffects
    });
  },

  updateCPUUsage() {
    if (!this.effectsEngine) return;
    
    const cpuUsage = this.effectsEngine.calculateCPUUsage();
    
    this.pushEvent('cpu_usage_updated', {
      track_id: this.trackId,
      cpu_usage: cpuUsage
    });
    
    // Update UI elements
    const cpuIndicators = this.el.querySelectorAll('[data-cpu-usage]');
    cpuIndicators.forEach(indicator => {
      const bar = indicator.querySelector('.cpu-bar');
      const text = indicator.querySelector('.cpu-text');
      
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
    });
  },

  updateParameterUI(effectId, paramName, value) {
    // Find and update parameter controls in UI
    const paramControl = this.el.querySelector(
      `[data-effect-id="${effectId}"][data-param-name="${paramName}"]`
    );
    
    if (paramControl) {
      if (paramControl.type === 'range') {
        paramControl.value = value;
      } else if (paramControl.type === 'checkbox') {
        paramControl.checked = value;
      } else if (paramControl.tagName === 'SELECT') {
        paramControl.value = value;
      }
      
      // Update display value
      const display = paramControl.parentElement.querySelector('.param-display');
      if (display) {
        display.textContent = this.formatParameterValue(paramName, value);
      }
    }
  },

  updateEffectVisualization(data) {
    const viz = this.visualizationCanvases.get(data.effectId);
    if (viz) {
      // Store visualization data for next render
      viz.lastData = data;
    }
  },

  formatParameterValue(paramName, value) {
    // Format parameter values for display
    switch (paramName) {
      case 'threshold':
      case 'gain':
        return `${value > 0 ? '+' : ''}${value.toFixed(1)}dB`;
      case 'ratio':
        return `${value.toFixed(1)}:1`;
      case 'frequency':
        return value >= 1000 ? `${(value/1000).toFixed(1)}kHz` : `${Math.round(value)}Hz`;
      case 'time':
      case 'delay':
        return `${Math.round(value * 1000)}ms`;
      case 'wet':
      case 'dry':
      case 'mix':
        return `${Math.round(value * 100)}%`;
      default:
        return typeof value === 'number' ? value.toFixed(2) : value;
    }
  },

  // Utility functions
  throttle(func, wait) {
    let timeout;
    return function executedFunction(...args) {
      const later = () => {
        clearTimeout(timeout);
        func(...args);
      };
      clearTimeout(timeout);
      timeout = setTimeout(later, wait);
    };
  },

  debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
      const later = () => {
        clearTimeout(timeout);
        func(...args);
      };
      clearTimeout(timeout);
      timeout = setTimeout(later, wait);
    };
  },

  // Cleanup
  beforeDestroy() {
    console.log('Effects Integration Hook destroying');
    
    // Stop all visualizations
    for (const effectId of this.visualizationCanvases.keys()) {
      this.stopEffectVisualization(effectId);
    }
    
    // Cleanup mutation observer
    if (this.vizObserver) {
      this.vizObserver.disconnect();
    }
    
    // Cleanup effects engine
    if (this.effectsEngine) {
      this.effectsEngine.destroy();
    }
    
    // Clear maps
    this.activeEffects.clear();
    this.automationCurves.clear();
    this.parameterHistory.clear();
    this.visualizationCanvases.clear();
  },

  destroyed() {
    this.beforeDestroy();
  }
};

// Effect Visualization Hook (for individual effect canvases)
export const EffectVisualization = {
  mounted() {
    this.effectId = this.el.dataset.effectId;
    this.effectType = this.el.dataset.effectType;
    this.canvas = this.el;
    this.ctx = this.canvas.getContext('2d');
    
    // Set canvas size
    this.resizeCanvas();
    
    // Setup resize observer
    this.resizeObserver = new ResizeObserver(() => {
      this.resizeCanvas();
    });
    this.resizeObserver.observe(this.canvas);
    
    // Start animation loop
    this.animate();
  },

  resizeCanvas() {
    const rect = this.canvas.getBoundingClientRect();
    this.canvas.width = rect.width * window.devicePixelRatio;
    this.canvas.height = rect.height * window.devicePixelRatio;
    this.canvas.style.width = rect.width + 'px';
    this.canvas.style.height = rect.height + 'px';
    this.ctx.scale(window.devicePixelRatio, window.devicePixelRatio);
  },

  animate() {
    this.render();
    this.animationId = requestAnimationFrame(() => this.animate());
  },

  render() {
    const rect = this.canvas.getBoundingClientRect();
    
    // Clear canvas
    this.ctx.fillStyle = 'rgba(0, 0, 0, 0.8)';
    this.ctx.fillRect(0, 0, rect.width, rect.height);
    
    // Get effect data from parent hook
    const parentHook = this.el.closest('[phx-hook="EffectsIntegrationHook"]');
    if (parentHook && parentHook.__view) {
      const effectsHook = parentHook.__view.hooks.EffectsIntegrationHook;
      const viz = effectsHook?.visualizationCanvases.get(this.effectId);
      
      if (viz && viz.lastData) {
        this.renderVisualization(viz.lastData);
      }
    }
    
    // Draw placeholder if no data
    if (!this.hasData) {
      this.renderPlaceholder();
    }
  },

  renderVisualization(data) {
    this.hasData = true;
    
    // Render based on effect type and data
    switch (this.effectType) {
      case 'parametric_eq':
        this.renderEQCurve(data);
        break;
      case 'convolution_reverb':
        this.renderReverbTail(data);
        break;
      case 'multiband_compressor':
        this.renderCompressionMeters(data);
        break;
      default:
        this.renderGenericMeter(data);
    }
  },

  renderEQCurve(data) {
    const rect = this.canvas.getBoundingClientRect();
    const frequencyData = data.data || [];
    
    if (frequencyData.length === 0) return;
    
    // Draw frequency response
    this.ctx.strokeStyle = '#10b981';
    this.ctx.lineWidth = 2;
    this.ctx.beginPath();
    
    frequencyData.forEach((value, index) => {
      const x = (index / (frequencyData.length - 1)) * rect.width;
      const y = rect.height - (value * rect.height * 0.8 + rect.height * 0.1);
      
      if (index === 0) {
        this.ctx.moveTo(x, y);
      } else {
        this.ctx.lineTo(x, y);
      }
    });
    
    this.ctx.stroke();
    
    // Draw center line (0dB)
    this.ctx.strokeStyle = 'rgba(255, 255, 255, 0.3)';
    this.ctx.lineWidth = 1;
    this.ctx.beginPath();
    this.ctx.moveTo(0, rect.height / 2);
    this.ctx.lineTo(rect.width, rect.height / 2);
    this.ctx.stroke();
  },

  renderReverbTail(data) {
    const rect = this.canvas.getBoundingClientRect();
    const impulseData = data.data || [];
    
    if (impulseData.length === 0) return;
    
    // Draw impulse response decay
    this.ctx.fillStyle = 'rgba(16, 185, 129, 0.6)';
    
    impulseData.forEach((value, index) => {
      const x = (index / (impulseData.length - 1)) * rect.width;
      const height = value * rect.height * 0.8;
      const y = rect.height - height;
      
      this.ctx.fillRect(x - 1, y, 2, height);
    });
  },

  renderCompressionMeters(data) {
    const rect = this.canvas.getBoundingClientRect();
    const gainReduction = data.data || 0;
    
    // Draw gain reduction meter
    const meterHeight = rect.height * 0.6;
    const meterY = (rect.height - meterHeight) / 2;
    
    // Background
    this.ctx.fillStyle = 'rgba(255, 255, 255, 0.1)';
    this.ctx.fillRect(10, meterY, rect.width - 20, meterHeight);
    
    // Gain reduction bar
    const reductionWidth = gainReduction * (rect.width - 20);
    this.ctx.fillStyle = `hsl(${120 - gainReduction * 120}, 70%, 50%)`;
    this.ctx.fillRect(10, meterY, reductionWidth, meterHeight);
    
    // Label
    this.ctx.fillStyle = 'white';
    this.ctx.font = '10px sans-serif';
    this.ctx.textAlign = 'center';
    this.ctx.fillText(`GR: -${(gainReduction * 20).toFixed(1)}dB`, rect.width / 2, meterY - 5);
  },

  renderGenericMeter(data) {
    const rect = this.canvas.getBoundingClientRect();
    const level = data.level || 0;
    
    // Simple level meter
    const barWidth = rect.width * 0.8;
    const barHeight = rect.height * 0.3;
    const barX = (rect.width - barWidth) / 2;
    const barY = (rect.height - barHeight) / 2;
    
    // Background
    this.ctx.fillStyle = 'rgba(255, 255, 255, 0.1)';
    this.ctx.fillRect(barX, barY, barWidth, barHeight);
    
    // Level bar
    this.ctx.fillStyle = '#10b981';
    this.ctx.fillRect(barX, barY, level * barWidth, barHeight);
  },

  renderPlaceholder() {
    const rect = this.canvas.getBoundingClientRect();
    
    // Draw placeholder text
    this.ctx.fillStyle = 'rgba(255, 255, 255, 0.3)';
    this.ctx.font = '12px sans-serif';
    this.ctx.textAlign = 'center';
    this.ctx.fillText('Effect Visualization', rect.width / 2, rect.height / 2);
  },

  destroyed() {
    if (this.animationId) {
      cancelAnimationFrame(this.animationId);
    }
    
    if (this.resizeObserver) {
      this.resizeObserver.disconnect();
    }
  }
};

export default { EffectsIntegrationHook, EffectVisualization };