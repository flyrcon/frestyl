// assets/js/audio/enhanced_effects_engine.js
import { AudioEngine } from './audio_engine.js';

export class EnhancedEffectsEngine extends AudioEngine {
  constructor(options = {}) {
    super(options);
    
    // Enhanced effects system
    this.effectsRegistry = new Map();
    this.effectPresets = new Map();
    this.realtimeEffects = new Map();
    this.effectAutomation = new Map();
    
    // Real-time processing
    this.processingNode = null;
    this.effectsProcessor = null;
    this.automationClock = null;
    
    // Effect visualization
    this.spectralAnalyzers = new Map();
    this.effectVisualizers = new Map();
    
    // Performance optimization
    this.effectsEnabled = true;
    this.maxConcurrentEffects = options.maxConcurrentEffects || 12;
    this.currentEffectCount = 0;
    
    // Initialize enhanced effects
    this.initializeEnhancedEffects();
  }

  async initializeEnhancedEffects() {
    try {
      // Register advanced effects
      this.registerAdvancedEffects();
      
      // Load effect presets
      await this.loadEffectPresets();
      
      // Initialize real-time processing
      await this.initializeRealtimeProcessing();
      
      // Setup effect automation
      this.initializeEffectAutomation();
      
      console.log('Enhanced Effects Engine initialized');
      this.emit('effects_engine_ready');
    } catch (error) {
      console.error('Failed to initialize Enhanced Effects Engine:', error);
      this.emit('effects_engine_error', { error });
    }
  }

  registerAdvancedEffects() {
    // Advanced effects with real-time parameter control
    this.registerEffect('parametric_eq', ParametricEQEffect);
    this.registerEffect('multiband_compressor', MultibandCompressorEffect);
    this.registerEffect('convolution_reverb', ConvolutionReverbEffect);
    this.registerEffect('stereo_widener', StereoWidenerEffect);
    this.registerEffect('tape_saturation', TapeSaturationEffect);
    this.registerEffect('vintage_delay', VintageDelayEffect);
    this.registerEffect('phaser', PhaserEffect);
    this.registerEffect('flanger', FlangerEffect);
    this.registerEffect('bitcrusher', BitcrusherEffect);
    this.registerEffect('vocoder', VocoderEffect);
    this.registerEffect('auto_tune', AutoTuneEffect);
    this.registerEffect('spectral_gate', SpectralGateEffect);
  }

  async loadEffectPresets() {
    const presets = {
      vocal_chain: {
        effects: [
          { type: 'parametric_eq', params: { low: 2, mid: 1.2, high: 1.5 } },
          { type: 'compressor', params: { threshold: -18, ratio: 3, attack: 0.003, release: 0.1 } },
          { type: 'convolution_reverb', params: { room: 'vocal_hall', wet: 0.2 } }
        ]
      },
      guitar_amp: {
        effects: [
          { type: 'tape_saturation', params: { drive: 0.6, warmth: 0.8 } },
          { type: 'parametric_eq', params: { low: 1.1, mid: 1.3, high: 0.9 } },
          { type: 'vintage_delay', params: { time: 0.25, feedback: 0.3, tone: 0.7 } }
        ]
      },
      drum_punch: {
        effects: [
          { type: 'multiband_compressor', params: { low_ratio: 4, mid_ratio: 2, high_ratio: 3 } },
          { type: 'parametric_eq', params: { low: 1.3, mid: 0.9, high: 1.2 } },
          { type: 'stereo_widener', params: { width: 1.2, bass_mono: true } }
        ]
      },
      creative_vocal: {
        effects: [
          { type: 'auto_tune', params: { correction: 0.8, key: 'C', scale: 'major' } },
          { type: 'vocoder', params: { bands: 16, attack: 0.01, release: 0.1 } },
          { type: 'convolution_reverb', params: { room: 'cathedral', wet: 0.4 } }
        ]
      },
      lo_fi_texture: {
        effects: [
          { type: 'bitcrusher', params: { bits: 8, sample_rate: 0.5 } },
          { type: 'tape_saturation', params: { drive: 0.8, wow_flutter: 0.3 } },
          { type: 'vintage_delay', params: { time: 0.12, feedback: 0.6, dirt: 0.4 } }
        ]
      }
    };

    for (const [name, preset] of Object.entries(presets)) {
      this.effectPresets.set(name, preset);
    }
  }

  async initializeRealtimeProcessing() {
    if (this.audioContext.audioWorklet) {
      try {
        // Load effects worklet for low-latency processing
        await this.audioContext.audioWorklet.addModule('/js/worklets/effects-processor.js');
        
        // Create effects processor worklet
        this.effectsProcessor = new AudioWorkletNode(this.audioContext, 'effects-processor', {
          numberOfInputs: 8,
          numberOfOutputs: 8,
          processorOptions: {
            maxEffects: this.maxConcurrentEffects
          }
        });

        // Handle messages from worklet
        this.effectsProcessor.port.onmessage = (event) => {
          this.handleEffectsProcessorMessage(event.data);
        };

        console.log('Real-time effects processing initialized');
      } catch (error) {
        console.warn('AudioWorklet not available, falling back to ScriptProcessor');
        this.initializeFallbackProcessing();
      }
    } else {
      this.initializeFallbackProcessing();
    }
  }

  initializeFallbackProcessing() {
    // Fallback to ScriptProcessorNode for older browsers
    this.processingNode = this.audioContext.createScriptProcessor(512, 2, 2);
    this.processingNode.onaudioprocess = (event) => {
      this.processAudioBuffer(event);
    };
  }

  initializeEffectAutomation() {
    // Automation system for parameter changes over time
    this.automationClock = {
      isRunning: false,
      currentTime: 0,
      automationCurves: new Map(),
      scheduledEvents: []
    };
  }

  // Enhanced effect management
  addRealtimeEffect(trackId, effectType, params = {}, options = {}) {
    if (this.currentEffectCount >= this.maxConcurrentEffects) {
      console.warn('Maximum concurrent effects reached');
      return null;
    }

    const track = this.tracks.get(trackId);
    if (!track) throw new Error(`Track ${trackId} not found`);

    const EffectClass = this.effects.get(effectType);
    if (!EffectClass) throw new Error(`Effect type ${effectType} not found`);

    // Create enhanced effect instance
    const effect = new EffectClass(this.audioContext, {
      ...params,
      realtime: true,
      trackId: trackId,
      sampleRate: this.audioContext.sampleRate,
      bufferSize: this.options.bufferSize
    });

    const effectId = `${trackId}_${effectType}_${Date.now()}`;
    
    // Enhanced effect wrapper with automation and visualization
    const enhancedEffect = {
      id: effectId,
      type: effectType,
      instance: effect,
      enabled: true,
      params: { ...params },
      automation: new Map(),
      visualizer: this.createEffectVisualizer(effectType, effect),
      performance: {
        cpuUsage: 0,
        latency: 0,
        bufferUnderruns: 0
      },
      realtime: options.realtime !== false,
      bypassable: options.bypassable !== false
    };

    // Add to track
    track.effects.push(enhancedEffect);
    this.realtimeEffects.set(effectId, enhancedEffect);
    this.currentEffectCount++;

    // Setup real-time parameter control
    if (enhancedEffect.realtime) {
      this.setupRealtimeParameterControl(enhancedEffect);
    }

    // Rebuild effect chain
    this.rebuildTrackEffectChain(track);
    
    // Setup effect visualization
    this.setupEffectVisualization(enhancedEffect);
    
    this.emit('realtime_effect_added', { 
      trackId, 
      effectId, 
      effectType, 
      params,
      cpuUsage: this.calculateCPUUsage()
    });
    
    return effectId;
  }

  setupRealtimeParameterControl(effect) {
    // Create parameter automation nodes
    const paramControls = {};
    
    if (effect.instance.parameters) {
      for (const [paramName, paramInfo] of Object.entries(effect.instance.parameters)) {
        const paramNode = this.audioContext.createConstantSource();
        const gainNode = this.audioContext.createGain();
        
        paramNode.connect(gainNode);
        gainNode.gain.value = paramInfo.defaultValue;
        paramNode.start();
        
        // Connect to effect parameter
        if (paramInfo.audioParam) {
          gainNode.connect(paramInfo.audioParam);
        }
        
        paramControls[paramName] = {
          source: paramNode,
          gain: gainNode,
          range: [paramInfo.minValue, paramInfo.maxValue],
          current: paramInfo.defaultValue
        };
      }
    }
    
    effect.paramControls = paramControls;
  }

  // Real-time parameter updates
  updateEffectParameter(effectId, paramName, value, options = {}) {
    const effect = this.realtimeEffects.get(effectId);
    if (!effect) return;

    const paramControl = effect.paramControls?.[paramName];
    if (!paramControl) return;

    // Clamp value to valid range
    const [min, max] = paramControl.range;
    const clampedValue = Math.max(min, Math.min(max, value));
    
    // Update parameter
    const currentTime = this.audioContext.currentTime;
    const transitionTime = options.smooth ? (options.transitionTime || 0.01) : 0;
    
    if (transitionTime > 0) {
      paramControl.gain.gain.setTargetAtTime(clampedValue, currentTime, transitionTime);
    } else {
      paramControl.gain.gain.setValueAtTime(clampedValue, currentTime);
    }
    
    // Update stored parameter value
    effect.params[paramName] = clampedValue;
    paramControl.current = clampedValue;
    
    // Emit parameter change event
    this.emit('effect_parameter_changed', {
      effectId,
      paramName,
      value: clampedValue,
      smooth: !!options.smooth
    });
    
    // Update automation if active
    if (effect.automation.has(paramName)) {
      this.updateParameterAutomation(effectId, paramName, clampedValue);
    }
  }

  // Effect automation system
  automateParameter(effectId, paramName, automationCurve, options = {}) {
    const effect = this.realtimeEffects.get(effectId);
    if (!effect) return;

    const automation = {
      id: `${effectId}_${paramName}_${Date.now()}`,
      effectId,
      paramName,
      curve: automationCurve,
      startTime: options.startTime || this.audioContext.currentTime,
      duration: options.duration || automationCurve.length * 0.01, // 10ms per point default
      loop: options.loop || false,
      active: true
    };

    effect.automation.set(paramName, automation);
    this.automationClock.automationCurves.set(automation.id, automation);
    
    // Start automation if clock is running
    if (this.automationClock.isRunning) {
      this.processParameterAutomation(automation);
    }
    
    this.emit('parameter_automation_started', {
      effectId,
      paramName,
      automationId: automation.id
    });
    
    return automation.id;
  }

  processParameterAutomation(automation) {
    const currentTime = this.audioContext.currentTime;
    const elapsed = currentTime - automation.startTime;
    const progress = elapsed / automation.duration;
    
    if (progress >= 1 && !automation.loop) {
      // Animation complete
      automation.active = false;
      return;
    }
    
    const curveProgress = automation.loop ? progress % 1 : Math.min(progress, 1);
    const curveIndex = Math.floor(curveProgress * (automation.curve.length - 1));
    const value = automation.curve[curveIndex];
    
    // Update parameter
    this.updateEffectParameter(automation.effectId, automation.paramName, value);
    
    // Schedule next update
    if (automation.active) {
      setTimeout(() => {
        if (automation.active) {
          this.processParameterAutomation(automation);
        }
      }, 10); // 100Hz automation rate
    }
  }

  // Effect presets
  applyEffectPreset(trackId, presetName) {
    const preset = this.effectPresets.get(presetName);
    if (!preset) {
      console.warn(`Effect preset '${presetName}' not found`);
      return;
    }

    const appliedEffects = [];
    
    for (const effectConfig of preset.effects) {
      try {
        const effectId = this.addRealtimeEffect(
          trackId, 
          effectConfig.type, 
          effectConfig.params,
          { realtime: true }
        );
        
        if (effectId) {
          appliedEffects.push(effectId);
        }
      } catch (error) {
        console.error(`Failed to apply effect ${effectConfig.type}:`, error);
      }
    }
    
    this.emit('effect_preset_applied', {
      trackId,
      presetName,
      appliedEffects
    });
    
    return appliedEffects;
  }

  // Effect visualization
  createEffectVisualizer(effectType, effectInstance) {
    switch (effectType) {
      case 'parametric_eq':
        return new EQVisualizer(effectInstance);
      case 'convolution_reverb':
        return new ReverbVisualizer(effectInstance);
      case 'multiband_compressor':
        return new CompressorVisualizer(effectInstance);
      case 'spectral_gate':
        return new SpectralVisualizer(effectInstance);
      default:
        return new GenericEffectVisualizer(effectInstance);
    }
  }

  setupEffectVisualization(effect) {
    if (!effect.visualizer) return;
    
    // Create analyzer for effect monitoring
    const analyzer = this.audioContext.createAnalyser();
    analyzer.fftSize = 2048;
    analyzer.smoothingTimeConstant = 0.8;
    
    // Connect analyzer after effect
    if (effect.instance.output) {
      effect.instance.output.connect(analyzer);
    }
    
    effect.analyzer = analyzer;
    this.spectralAnalyzers.set(effect.id, analyzer);
    
    // Start visualization updates
    this.startEffectVisualization(effect);
  }

  startEffectVisualization(effect) {
    const updateVisualization = () => {
      if (!effect.enabled || !effect.analyzer) return;
      
      const bufferLength = effect.analyzer.frequencyBinCount;
      const dataArray = new Uint8Array(bufferLength);
      effect.analyzer.getByteFrequencyData(dataArray);
      
      // Update visualizer
      if (effect.visualizer && effect.visualizer.update) {
        effect.visualizer.update(dataArray);
      }
      
      // Emit visualization data
      this.emit('effect_visualization_update', {
        effectId: effect.id,
        type: effect.type,
        data: Array.from(dataArray),
        timestamp: this.audioContext.currentTime
      });
      
      // Continue updates
      if (effect.enabled) {
        requestAnimationFrame(updateVisualization);
      }
    };
    
    updateVisualization();
  }

  // Performance monitoring
  calculateCPUUsage() {
    // Simplified CPU usage calculation
    const activeEffects = Array.from(this.realtimeEffects.values())
      .filter(effect => effect.enabled);
    
    let totalCPU = 0;
    for (const effect of activeEffects) {
      // Estimate CPU usage based on effect type and complexity
      const baseCPU = this.getEffectBaseCPU(effect.type);
      const parameterCPU = Object.keys(effect.params).length * 0.1;
      totalCPU += baseCPU + parameterCPU;
    }
    
    return Math.min(100, totalCPU);
  }

  getEffectBaseCPU(effectType) {
    const cpuCosts = {
      'parametric_eq': 2,
      'compressor': 3,
      'convolution_reverb': 8,
      'multiband_compressor': 6,
      'vocoder': 10,
      'auto_tune': 12,
      'spectral_gate': 15,
      'delay': 1,
      'chorus': 2,
      'flanger': 2,
      'phaser': 2
    };
    
    return cpuCosts[effectType] || 1;
  }

  // Effect bypass and performance optimization
  bypassEffect(effectId, bypassed = true) {
    const effect = this.realtimeEffects.get(effectId);
    if (!effect || !effect.bypassable) return;

    if (effect.instance.bypass) {
      effect.instance.bypass(bypassed);
    } else {
      // Manual bypass by disconnecting
      if (bypassed) {
        effect.instance.input?.disconnect();
        effect.instance.output?.disconnect();
      } else {
        this.rebuildEffectChain(effect);
      }
    }
    
    effect.bypassed = bypassed;
    
    this.emit('effect_bypassed', {
      effectId,
      bypassed,
      cpuUsage: this.calculateCPUUsage()
    });
  }

  // Cleanup and optimization
  removeRealtimeEffect(effectId) {
    const effect = this.realtimeEffects.get(effectId);
    if (!effect) return;

    // Stop automation
    effect.automation.forEach((automation) => {
      automation.active = false;
      this.automationClock.automationCurves.delete(automation.id);
    });

    // Disconnect parameter controls
    if (effect.paramControls) {
      Object.values(effect.paramControls).forEach(control => {
        control.source.stop();
        control.source.disconnect();
        control.gain.disconnect();
      });
    }

    // Disconnect effect
    if (effect.instance.disconnect) {
      effect.instance.disconnect();
    }

    // Remove from collections
    this.realtimeEffects.delete(effectId);
    this.spectralAnalyzers.delete(effectId);
    this.currentEffectCount--;

    // Find and remove from track
    for (const track of this.tracks.values()) {
      const effectIndex = track.effects.findIndex(e => e.id === effectId);
      if (effectIndex > -1) {
        track.effects.splice(effectIndex, 1);
        this.rebuildTrackEffectChain(track);
        break;
      }
    }

    this.emit('realtime_effect_removed', {
      effectId,
      cpuUsage: this.calculateCPUUsage()
    });
  }

  // Integration with existing LiveView
  syncWithLiveView(liveSocket) {
    // Send effect updates to LiveView
    this.on('realtime_effect_added', (data) => {
      liveSocket.push('effect_added_client', data);
    });

    this.on('effect_parameter_changed', (data) => {
      liveSocket.push('effect_parameter_changed_client', data);
    });

    this.on('effect_preset_applied', (data) => {
      liveSocket.push('effect_preset_applied_client', data);
    });

    // Handle LiveView commands
    liveSocket.on('apply_effect_preset', (data) => {
      this.applyEffectPreset(data.trackId, data.presetName);
    });

    liveSocket.on('update_effect_parameter', (data) => {
      this.updateEffectParameter(
        data.effectId, 
        data.paramName, 
        data.value, 
        data.options
      );
    });

    liveSocket.on('automate_effect_parameter', (data) => {
      this.automateParameter(
        data.effectId,
        data.paramName,
        data.curve,
        data.options
      );
    });
  }

  handleEffectsProcessorMessage(data) {
    switch (data.type) {
      case 'performance_update':
        this.updateEffectPerformance(data);
        break;
      case 'buffer_underrun':
        this.handleBufferUnderrun(data);
        break;
      case 'effect_error':
        this.handleEffectError(data);
        break;
    }
  }

  updateEffectPerformance(data) {
    const effect = this.realtimeEffects.get(data.effectId);
    if (effect) {
      effect.performance = {
        ...effect.performance,
        ...data.performance
      };
    }
  }

  // Override parent destroy method
  destroy() {
    // Stop automation clock
    this.automationClock.isRunning = false;
    
    // Cleanup all real-time effects
    for (const effectId of this.realtimeEffects.keys()) {
      this.removeRealtimeEffect(effectId);
    }
    
    // Cleanup worklet
    if (this.effectsProcessor) {
      this.effectsProcessor.disconnect();
    }
    
    // Call parent cleanup
    super.destroy();
  }
}

// Effect Visualizers
class EQVisualizer {
  constructor(eqEffect) {
    this.eqEffect = eqEffect;
    this.frequencyData = new Float32Array(256);
  }
  
  update(analyzerData) {
    // Convert analyzer data to frequency response
    for (let i = 0; i < this.frequencyData.length; i++) {
      this.frequencyData[i] = analyzerData[i] / 255;
    }
  }
  
  getVisualizationData() {
    return {
      type: 'frequency_response',
      data: Array.from(this.frequencyData)
    };
  }
}

class ReverbVisualizer {
  constructor(reverbEffect) {
    this.reverbEffect = reverbEffect;
    this.impulsePlot = new Float32Array(128);
  }
  
  update(analyzerData) {
    // Show reverb tail visualization
    const decayRate = 0.95;
    for (let i = 0; i < this.impulsePlot.length; i++) {
      this.impulsePlot[i] *= decayRate;
    }
    
    // Add new energy
    const energy = analyzerData.reduce((sum, val) => sum + val, 0) / analyzerData.length / 255;
    this.impulsePlot[0] = energy;
  }
  
  getVisualizationData() {
    return {
      type: 'impulse_response',
      data: Array.from(this.impulsePlot)
    };
  }
}

class CompressorVisualizer {
  constructor(compressorEffect) {
    this.compressorEffect = compressorEffect;
    this.gainReduction = 0;
  }
  
  update(analyzerData) {
    // Calculate gain reduction visualization
    const inputLevel = analyzerData.reduce((sum, val) => sum + val, 0) / analyzerData.length / 255;
    const threshold = 0.7; // Normalized threshold
    
    if (inputLevel > threshold) {
      this.gainReduction = (inputLevel - threshold) * 0.8;
    } else {
      this.gainReduction *= 0.9; // Decay
    }
  }
  
  getVisualizationData() {
    return {
      type: 'gain_reduction',
      data: this.gainReduction
    };
  }
}

class SpectralVisualizer {
  constructor(spectralEffect) {
    this.spectralEffect = spectralEffect;
    this.spectralData = new Float32Array(512);
  }
  
  update(analyzerData) {
    // Create spectrogram-style visualization
    for (let i = 0; i < this.spectralData.length; i++) {
      this.spectralData[i] = analyzerData[i] / 255;
    }
  }
  
  getVisualizationData() {
    return {
      type: 'spectrogram',
      data: Array.from(this.spectralData)
    };
  }
}

class GenericEffectVisualizer {
  constructor(effect) {
    this.effect = effect;
    this.levels = { input: 0, output: 0 };
  }
  
  update(analyzerData) {
    // Generic level monitoring
    this.levels.output = analyzerData.reduce((sum, val) => sum + val, 0) / analyzerData.length / 255;
  }
  
  getVisualizationData() {
    return {
      type: 'levels',
      data: this.levels
    };
  }
}