// priv/static/js/worklets/effects-processor.js

class EffectsProcessor extends AudioWorkletProcessor {
  constructor(options) {
    super();
    
    this.maxEffects = options.processorOptions.maxEffects || 12;
    this.sampleRate = globalThis.sampleRate || 44100;
    this.blockSize = 128; // Standard Web Audio block size
    
    // Effect processing state
    this.effects = new Map();
    this.effectChains = new Map();
    this.parameters = new Map();
    
    // Performance monitoring
    this.performanceMetrics = {
      processingTime: 0,
      bufferUnderruns: 0,
      effectCount: 0
    };
    
    // Setup message handling
    this.port.onmessage = this.handleMessage.bind(this);
    
    // Initialize processing buffers
    this.initializeBuffers();
    
    console.log('EffectsProcessor initialized');
  }
  
  initializeBuffers() {
    // Pre-allocate processing buffers for efficiency
    this.tempBuffers = {
      left: new Float32Array(this.blockSize),
      right: new Float32Array(this.blockSize),
      mono: new Float32Array(this.blockSize)
    };
    
    // Effect parameter smoothing buffers
    this.parameterSmoothers = new Map();
  }
  
  handleMessage(event) {
    const { type, data } = event.data;
    
    switch (type) {
      case 'add_effect':
        this.addEffect(data);
        break;
      case 'remove_effect':
        this.removeEffect(data.effectId);
        break;
      case 'update_parameter':
        this.updateParameter(data);
        break;
      case 'bypass_effect':
        this.bypassEffect(data.effectId, data.bypassed);
        break;
      case 'get_performance':
        this.sendPerformanceMetrics();
        break;
    }
  }
  
  addEffect(effectData) {
    const { effectId, type, params, trackId } = effectData;
    
    if (this.effects.size >= this.maxEffects) {
      this.port.postMessage({
        type: 'error',
        data: { message: 'Maximum effects limit reached' }
      });
      return;
    }
    
    const effect = this.createEffect(type, params);
    if (effect) {
      this.effects.set(effectId, {
        id: effectId,
        type: type,
        processor: effect,
        trackId: trackId,
        enabled: true,
        bypassed: false,
        params: { ...params }
      });
      
      this.port.postMessage({
        type: 'effect_added',
        data: { effectId, type }
      });
    }
  }
  
  createEffect(type, params) {
    switch (type) {
      case 'lowpass_filter':
        return new WorkletLowpassFilter(this.sampleRate, params);
      case 'highpass_filter':
        return new WorkletHighpassFilter(this.sampleRate, params);
      case 'bandpass_filter':
        return new WorkletBandpassFilter(this.sampleRate, params);
      case 'biquad_eq':
        return new WorkletBiquadEQ(this.sampleRate, params);
      case 'compressor':
        return new WorkletCompressor(this.sampleRate, params);
      case 'limiter':
        return new WorkletLimiter(this.sampleRate, params);
      case 'delay':
        return new WorkletDelay(this.sampleRate, params);
      case 'chorus':
        return new WorkletChorus(this.sampleRate, params);
      case 'distortion':
        return new WorkletDistortion(this.sampleRate, params);
      case 'bitcrusher':
        return new WorkletBitcrusher(this.sampleRate, params);
      case 'gate':
        return new WorkletGate(this.sampleRate, params);
      default:
        console.warn(`Unknown effect type: ${type}`);
        return null;
    }
  }
  
  removeEffect(effectId) {
    if (this.effects.has(effectId)) {
      const effect = this.effects.get(effectId);
      if (effect.processor.cleanup) {
        effect.processor.cleanup();
      }
      this.effects.delete(effectId);
      
      this.port.postMessage({
        type: 'effect_removed',
        data: { effectId }
      });
    }
  }
  
  updateParameter(data) {
    const { effectId, paramName, value, smooth } = data;
    const effect = this.effects.get(effectId);
    
    if (effect && effect.processor.setParameter) {
      if (smooth) {
        this.smoothParameter(effectId, paramName, value);
      } else {
        effect.processor.setParameter(paramName, value);
        effect.params[paramName] = value;
      }
    }
  }
  
  smoothParameter(effectId, paramName, targetValue) {
    const key = `${effectId}_${paramName}`;
    const effect = this.effects.get(effectId);
    
    if (!effect) return;
    
    const currentValue = effect.params[paramName] || 0;
    const smoother = this.parameterSmoothers.get(key) || {
      current: currentValue,
      target: currentValue,
      rate: 0.001 // 1ms smoothing
    };
    
    smoother.target = targetValue;
    this.parameterSmoothers.set(key, smoother);
  }
  
  bypassEffect(effectId, bypassed) {
    const effect = this.effects.get(effectId);
    if (effect) {
      effect.bypassed = bypassed;
    }
  }
  
  process(inputs, outputs, parameters) {
    const startTime = performance.now();
    
    try {
      // Process each input/output pair
      for (let inputIndex = 0; inputIndex < inputs.length; inputIndex++) {
        const input = inputs[inputIndex];
        const output = outputs[inputIndex];
        
        if (input.length === 0 || output.length === 0) continue;
        
        // Process effects for this track
        this.processEffectsChain(input, output, inputIndex);
      }
      
      // Update parameter smoothers
      this.updateParameterSmoothers();
      
      // Update performance metrics
      const processingTime = performance.now() - startTime;
      this.updatePerformanceMetrics(processingTime);
      
      return true;
    } catch (error) {
      this.port.postMessage({
        type: 'processing_error',
        data: { error: error.message }
      });
      return false;
    }
  }
  
  processEffectsChain(input, output, trackIndex) {
    const numChannels = Math.min(input.length, output.length);
    
    // Copy input to temp buffers
    for (let channel = 0; channel < numChannels; channel++) {
      const channelData = channel === 0 ? this.tempBuffers.left : this.tempBuffers.right;
      channelData.set(input[channel]);
    }
    
    // Process effects for this track
    const trackEffects = Array.from(this.effects.values()).filter(
      effect => effect.trackId === trackIndex && effect.enabled && !effect.bypassed
    );
    
    for (const effect of trackEffects) {
      if (effect.processor.process) {
        effect.processor.process(this.tempBuffers, numChannels);
      }
    }
    
    // Copy processed audio to output
    for (let channel = 0; channel < numChannels; channel++) {
      const channelData = channel === 0 ? this.tempBuffers.left : this.tempBuffers.right;
      output[channel].set(channelData);
    }
  }
  
  updateParameterSmoothers() {
    for (const [key, smoother] of this.parameterSmoothers.entries()) {
      if (Math.abs(smoother.current - smoother.target) > 0.001) {
        smoother.current += (smoother.target - smoother.current) * smoother.rate;
        
        // Extract effect ID and parameter name
        const [effectId, paramName] = key.split('_');
        const effect = this.effects.get(effectId);
        
        if (effect && effect.processor.setParameter) {
          effect.processor.setParameter(paramName, smoother.current);
          effect.params[paramName] = smoother.current;
        }
      }
    }
  }
  
  updatePerformanceMetrics(processingTime) {
    this.performanceMetrics.processingTime = processingTime;
    this.performanceMetrics.effectCount = this.effects.size;
    
    // Check for buffer underruns (processing taking too long)
    const maxProcessingTime = (this.blockSize / this.sampleRate) * 1000; // ms
    if (processingTime > maxProcessingTime * 0.8) {
      this.performanceMetrics.bufferUnderruns++;
      
      this.port.postMessage({
        type: 'buffer_underrun',
        data: {
          processingTime,
          maxTime: maxProcessingTime,
          effectCount: this.effects.size
        }
      });
    }
  }
  
  sendPerformanceMetrics() {
    this.port.postMessage({
      type: 'performance_update',
      data: this.performanceMetrics
    });
  }
}

// Base effect class for worklet effects
class WorkletEffect {
  constructor(sampleRate, params = {}) {
    this.sampleRate = sampleRate;
    this.params = { ...params };
  }
  
  setParameter(name, value) {
    this.params[name] = value;
  }
  
  process(buffers, numChannels) {
    // Override in subclasses
  }
  
  cleanup() {
    // Override if cleanup needed
  }
}

// Biquad Filter implementation
class WorkletBiquadFilter extends WorkletEffect {
  constructor(sampleRate, params) {
    super(sampleRate, params);
    
    this.type = params.type || 'lowpass';
    this.frequency = params.frequency || 1000;
    this.Q = params.Q || 1;
    this.gain = params.gain || 0;
    
    // Biquad coefficients
    this.b0 = 1; this.b1 = 0; this.b2 = 0;
    this.a1 = 0; this.a2 = 0;
    
    // State variables for each channel
    this.x1 = [0, 0]; this.x2 = [0, 0];
    this.y1 = [0, 0]; this.y2 = [0, 0];
    
    this.updateCoefficients();
  }
  
  setParameter(name, value) {
    super.setParameter(name, value);
    
    switch (name) {
      case 'frequency':
        this.frequency = value;
        this.updateCoefficients();
        break;
      case 'Q':
        this.Q = value;
        this.updateCoefficients();
        break;
      case 'gain':
        this.gain = value;
        this.updateCoefficients();
        break;
    }
  }
  
  updateCoefficients() {
    const w = 2 * Math.PI * this.frequency / this.sampleRate;
    const cosw = Math.cos(w);
    const sinw = Math.sin(w);
    const alpha = sinw / (2 * this.Q);
    const A = Math.pow(10, this.gain / 40);
    
    switch (this.type) {
      case 'lowpass':
        this.b0 = (1 - cosw) / 2;
        this.b1 = 1 - cosw;
        this.b2 = (1 - cosw) / 2;
        const a0_lp = 1 + alpha;
        this.a1 = -2 * cosw / a0_lp;
        this.a2 = (1 - alpha) / a0_lp;
        this.b0 /= a0_lp; this.b1 /= a0_lp; this.b2 /= a0_lp;
        break;
        
      case 'highpass':
        this.b0 = (1 + cosw) / 2;
        this.b1 = -(1 + cosw);
        this.b2 = (1 + cosw) / 2;
        const a0_hp = 1 + alpha;
        this.a1 = -2 * cosw / a0_hp;
        this.a2 = (1 - alpha) / a0_hp;
        this.b0 /= a0_hp; this.b1 /= a0_hp; this.b2 /= a0_hp;
        break;
        
      case 'bandpass':
        this.b0 = alpha;
        this.b1 = 0;
        this.b2 = -alpha;
        const a0_bp = 1 + alpha;
        this.a1 = -2 * cosw / a0_bp;
        this.a2 = (1 - alpha) / a0_bp;
        this.b0 /= a0_bp; this.b1 /= a0_bp; this.b2 /= a0_bp;
        break;
        
      case 'peaking':
        const S = 1;
        const beta = Math.sqrt(A) / this.Q;
        this.b0 = 1 + (beta * sinw);
        this.b1 = -2 * cosw;
        this.b2 = 1 - (beta * sinw);
        const a0_pk = 1 + (beta * sinw) / A;
        this.a1 = -2 * cosw / a0_pk;
        this.a2 = (1 - (beta * sinw) / A) / a0_pk;
        this.b0 /= a0_pk; this.b1 /= a0_pk; this.b2 /= a0_pk;
        break;
    }
  }
  
  process(buffers, numChannels) {
    for (let channel = 0; channel < Math.min(numChannels, 2); channel++) {
      const buffer = channel === 0 ? buffers.left : buffers.right;
      
      for (let i = 0; i < buffer.length; i++) {
        const x0 = buffer[i];
        
        // Apply biquad difference equation
        const y0 = (this.b0 * x0) + (this.b1 * this.x1[channel]) + (this.b2 * this.x2[channel])
                  - (this.a1 * this.y1[channel]) - (this.a2 * this.y2[channel]);
        
        // Update state
        this.x2[channel] = this.x1[channel];
        this.x1[channel] = x0;
        this.y2[channel] = this.y1[channel];
        this.y1[channel] = y0;
        
        buffer[i] = y0;
      }
    }
  }
}

// Specific filter implementations
class WorkletLowpassFilter extends WorkletBiquadFilter {
  constructor(sampleRate, params) {
    super(sampleRate, { ...params, type: 'lowpass' });
  }
}

class WorkletHighpassFilter extends WorkletBiquadFilter {
  constructor(sampleRate, params) {
    super(sampleRate, { ...params, type: 'highpass' });
  }
}

class WorkletBandpassFilter extends WorkletBiquadFilter {
  constructor(sampleRate, params) {
    super(sampleRate, { ...params, type: 'bandpass' });
  }
}

class WorkletBiquadEQ extends WorkletBiquadFilter {
  constructor(sampleRate, params) {
    super(sampleRate, { ...params, type: 'peaking' });
  }
}

// Compressor implementation
class WorkletCompressor extends WorkletEffect {
  constructor(sampleRate, params) {
    super(sampleRate, params);
    
    this.threshold = params.threshold || -24; // dB
    this.ratio = params.ratio || 4;
    this.attack = params.attack || 0.003; // seconds
    this.release = params.release || 0.25; // seconds
    this.knee = params.knee || 2; // dB
    this.makeupGain = params.makeupGain || 0; // dB
    
    // Convert to linear values
    this.thresholdLinear = this.dbToLinear(this.threshold);
    this.makeupGainLinear = this.dbToLinear(this.makeupGain);
    
    // Envelope follower state
    this.envelope = [0, 0]; // Left, Right
    this.gainReduction = [1, 1];
    
    // Time constants
    this.attackCoeff = Math.exp(-1 / (this.attack * sampleRate));
    this.releaseCoeff = Math.exp(-1 / (this.release * sampleRate));
  }
  
  setParameter(name, value) {
    super.setParameter(name, value);
    
    switch (name) {
      case 'threshold':
        this.threshold = value;
        this.thresholdLinear = this.dbToLinear(value);
        break;
      case 'ratio':
        this.ratio = value;
        break;
      case 'attack':
        this.attack = value;
        this.attackCoeff = Math.exp(-1 / (value * this.sampleRate));
        break;
      case 'release':
        this.release = value;
        this.releaseCoeff = Math.exp(-1 / (value * this.sampleRate));
        break;
      case 'makeupGain':
        this.makeupGain = value;
        this.makeupGainLinear = this.dbToLinear(value);
        break;
    }
  }
  
  dbToLinear(db) {
    return Math.pow(10, db / 20);
  }
  
  linearToDb(linear) {
    return 20 * Math.log10(Math.max(linear, 0.000001));
  }
  
  process(buffers, numChannels) {
    for (let channel = 0; channel < Math.min(numChannels, 2); channel++) {
      const buffer = channel === 0 ? buffers.left : buffers.right;
      
      for (let i = 0; i < buffer.length; i++) {
        const input = Math.abs(buffer[i]);
        
        // Envelope detection
        const targetEnv = input;
        const coeff = targetEnv > this.envelope[channel] ? this.attackCoeff : this.releaseCoeff;
        this.envelope[channel] = targetEnv + (this.envelope[channel] - targetEnv) * coeff;
        
        // Compression calculation
        if (this.envelope[channel] > this.thresholdLinear) {
          const overThreshold = this.linearToDb(this.envelope[channel]) - this.threshold;
          const compressedDb = this.threshold + (overThreshold / this.ratio);
          const targetGain = this.dbToLinear(compressedDb) / this.envelope[channel];
          this.gainReduction[channel] = Math.min(targetGain, 1);
        } else {
          this.gainReduction[channel] = 1;
        }
        
        // Apply compression and makeup gain
        buffer[i] *= this.gainReduction[channel] * this.makeupGainLinear;
      }
    }
  }
}

// Limiter implementation
class WorkletLimiter extends WorkletEffect {
  constructor(sampleRate, params) {
    super(sampleRate, params);
    
    this.threshold = params.threshold || -0.1; // dB
    this.lookahead = params.lookahead || 0.005; // seconds
    this.release = params.release || 0.05; // seconds
    
    this.thresholdLinear = this.dbToLinear(this.threshold);
    this.releaseCoeff = Math.exp(-1 / (this.release * sampleRate));
    
    // Lookahead delay buffer
    this.lookaheadSamples = Math.floor(this.lookahead * sampleRate);
    this.delayBuffer = [
      new Float32Array(this.lookaheadSamples),
      new Float32Array(this.lookaheadSamples)
    ];
    this.delayIndex = 0;
    
    // Gain reduction state
    this.gainReduction = 1;
  }
  
  dbToLinear(db) {
    return Math.pow(10, db / 20);
  }
  
  setParameter(name, value) {
    super.setParameter(name, value);
    
    switch (name) {
      case 'threshold':
        this.threshold = value;
        this.thresholdLinear = this.dbToLinear(value);
        break;
      case 'release':
        this.release = value;
        this.releaseCoeff = Math.exp(-1 / (value * this.sampleRate));
        break;
    }
  }
  
  process(buffers, numChannels) {
    for (let i = 0; i < buffers.left.length; i++) {
      // Store input in delay buffer
      for (let channel = 0; channel < Math.min(numChannels, 2); channel++) {
        const buffer = channel === 0 ? buffers.left : buffers.right;
        this.delayBuffer[channel][this.delayIndex] = buffer[i];
      }
      
      // Calculate peak from current sample
      let peak = 0;
      for (let channel = 0; channel < Math.min(numChannels, 2); channel++) {
        const buffer = channel === 0 ? buffers.left : buffers.right;
        peak = Math.max(peak, Math.abs(buffer[i]));
      }
      
      // Calculate required gain reduction
      let targetGainReduction = 1;
      if (peak > this.thresholdLinear) {
        targetGainReduction = this.thresholdLinear / peak;
      }
      
      // Smooth gain reduction
      if (targetGainReduction < this.gainReduction) {
        this.gainReduction = targetGainReduction; // Instant attack
      } else {
        this.gainReduction += (targetGainReduction - this.gainReduction) * (1 - this.releaseCoeff);
      }
      
      // Apply limiting to delayed signal
      for (let channel = 0; channel < Math.min(numChannels, 2); channel++) {
        const buffer = channel === 0 ? buffers.left : buffers.right;
        const delayedSample = this.delayBuffer[channel][this.delayIndex];
        buffer[i] = delayedSample * this.gainReduction;
      }
      
      // Advance delay buffer
      this.delayIndex = (this.delayIndex + 1) % this.lookaheadSamples;
    }
  }
}

// Delay implementation
class WorkletDelay extends WorkletEffect {
  constructor(sampleRate, params) {
    super(sampleRate, params);
    
    this.delayTime = params.delayTime || 0.25; // seconds
    this.feedback = params.feedback || 0.3;
    this.wetLevel = params.wetLevel || 0.3;
    this.dryLevel = params.dryLevel || 0.7;
    
    // Delay buffer
    const maxDelay = 2; // seconds
    this.bufferSize = Math.floor(maxDelay * sampleRate);
    this.delayBuffer = [
      new Float32Array(this.bufferSize),
      new Float32Array(this.bufferSize)
    ];
    this.writeIndex = 0;
  }
  
  setParameter(name, value) {
    super.setParameter(name, value);
    
    switch (name) {
      case 'delayTime':
        this.delayTime = Math.max(0.001, Math.min(2, value));
        break;
      case 'feedback':
        this.feedback = Math.max(0, Math.min(0.95, value));
        break;
      case 'wetLevel':
        this.wetLevel = value;
        break;
      case 'dryLevel':
        this.dryLevel = value;
        break;
    }
  }
  
  process(buffers, numChannels) {
    const delaySamples = Math.floor(this.delayTime * this.sampleRate);
    
    for (let i = 0; i < buffers.left.length; i++) {
      const readIndex = (this.writeIndex - delaySamples + this.bufferSize) % this.bufferSize;
      
      for (let channel = 0; channel < Math.min(numChannels, 2); channel++) {
        const buffer = channel === 0 ? buffers.left : buffers.right;
        const input = buffer[i];
        const delayed = this.delayBuffer[channel][readIndex];
        
        // Write to delay buffer with feedback
        this.delayBuffer[channel][this.writeIndex] = input + (delayed * this.feedback);
        
        // Mix dry and wet signals
        buffer[i] = (input * this.dryLevel) + (delayed * this.wetLevel);
      }
      
      this.writeIndex = (this.writeIndex + 1) % this.bufferSize;
    }
  }
}

// Distortion implementation
class WorkletDistortion extends WorkletEffect {
  constructor(sampleRate, params) {
    super(sampleRate, params);
    
    this.drive = params.drive || 5;
    this.level = params.level || 0.5;
    this.type = params.type || 'soft'; // 'soft', 'hard', 'fuzz'
  }
  
  setParameter(name, value) {
    super.setParameter(name, value);
    
    switch (name) {
      case 'drive':
        this.drive = value;
        break;
      case 'level':
        this.level = value;
        break;
    }
  }
  
  process(buffers, numChannels) {
    for (let channel = 0; channel < Math.min(numChannels, 2); channel++) {
      const buffer = channel === 0 ? buffers.left : buffers.right;
      
      for (let i = 0; i < buffer.length; i++) {
        let sample = buffer[i] * this.drive;
        
        // Apply distortion based on type
        switch (this.type) {
          case 'soft':
            sample = Math.tanh(sample);
            break;
          case 'hard':
            sample = Math.max(-1, Math.min(1, sample));
            break;
          case 'fuzz':
            sample = sample > 0 ? 1 : -1;
            break;
        }
        
        buffer[i] = sample * this.level;
      }
    }
  }
}

// Bitcrusher implementation
class WorkletBitcrusher extends WorkletEffect {
  constructor(sampleRate, params) {
    super(sampleRate, params);
    
    this.bits = params.bits || 8;
    this.sampleRateReduction = params.sampleRateReduction || 0.5;
    
    this.accumulator = [0, 0];
    this.holdSample = [0, 0];
    this.holdCounter = [0, 0];
  }
  
  setParameter(name, value) {
    super.setParameter(name, value);
    
    switch (name) {
      case 'bits':
        this.bits = Math.max(1, Math.min(16, Math.floor(value)));
        break;
      case 'sampleRateReduction':
        this.sampleRateReduction = Math.max(0.1, Math.min(1, value));
        break;
    }
  }
  
  process(buffers, numChannels) {
    const levels = Math.pow(2, this.bits);
    const step = 2 / levels;
    const holdLength = Math.floor(1 / this.sampleRateReduction);
    
    for (let channel = 0; channel < Math.min(numChannels, 2); channel++) {
      const buffer = channel === 0 ? buffers.left : buffers.right;
      
      for (let i = 0; i < buffer.length; i++) {
        // Sample rate reduction
        if (this.holdCounter[channel]++ >= holdLength) {
          this.holdCounter[channel] = 0;
          
          // Bit depth reduction
          const quantized = Math.floor((buffer[i] + 1) / step) * step - 1;
          this.holdSample[channel] = Math.max(-1, Math.min(1, quantized));
        }
        
        buffer[i] = this.holdSample[channel];
      }
    }
  }
}

// Gate implementation
class WorkletGate extends WorkletEffect {
  constructor(sampleRate, params) {
    super(sampleRate, params);
    
    this.threshold = params.threshold || -40; // dB
    this.ratio = params.ratio || 10;
    this.attack = params.attack || 0.001; // seconds
    this.release = params.release || 0.1; // seconds
    
    this.thresholdLinear = this.dbToLinear(this.threshold);
    this.attackCoeff = Math.exp(-1 / (this.attack * sampleRate));
    this.releaseCoeff = Math.exp(-1 / (this.release * sampleRate));
    
    this.envelope = [0, 0];
    this.gateGain = [1, 1];
  }
  
  dbToLinear(db) {
    return Math.pow(10, db / 20);
  }
  
  setParameter(name, value) {
    super.setParameter(name, value);
    
    switch (name) {
      case 'threshold':
        this.threshold = value;
        this.thresholdLinear = this.dbToLinear(value);
        break;
      case 'ratio':
        this.ratio = value;
        break;
      case 'attack':
        this.attack = value;
        this.attackCoeff = Math.exp(-1 / (value * this.sampleRate));
        break;
      case 'release':
        this.release = value;
        this.releaseCoeff = Math.exp(-1 / (value * this.sampleRate));
        break;
    }
  }
  
  process(buffers, numChannels) {
    for (let channel = 0; channel < Math.min(numChannels, 2); channel++) {
      const buffer = channel === 0 ? buffers.left : buffers.right;
      
      for (let i = 0; i < buffer.length; i++) {
        const input = Math.abs(buffer[i]);
        
        // Envelope following
        const targetEnv = input;
        const coeff = targetEnv > this.envelope[channel] ? this.attackCoeff : this.releaseCoeff;
        this.envelope[channel] = targetEnv + (this.envelope[channel] - targetEnv) * coeff;
        
        // Gate calculation
        if (this.envelope[channel] > this.thresholdLinear) {
          this.gateGain[channel] = 1; // Gate open
        } else {
          // Calculate gate reduction
          const reduction = Math.pow(this.envelope[channel] / this.thresholdLinear, 1 / this.ratio);
          this.gateGain[channel] = Math.max(0, reduction);
        }
        
        buffer[i] *= this.gateGain[channel];
      }
    }
  }
}

// Chorus implementation
class WorkletChorus extends WorkletEffect {
  constructor(sampleRate, params) {
    super(sampleRate, params);
    
    this.rate = params.rate || 0.5; // Hz
    this.depth = params.depth || 0.005; // seconds
    this.feedback = params.feedback || 0.2;
    this.mix = params.mix || 0.5;
    
    // LFO state
    this.lfoPhase = 0;
    this.lfoIncrement = (2 * Math.PI * this.rate) / sampleRate;
    
    // Delay buffer
    const maxDelay = 0.05; // 50ms max delay
    this.bufferSize = Math.floor(maxDelay * sampleRate);
    this.delayBuffer = [
      new Float32Array(this.bufferSize),
      new Float32Array(this.bufferSize)
    ];
    this.writeIndex = 0;
  }
  
  setParameter(name, value) {
    super.setParameter(name, value);
    
    switch (name) {
      case 'rate':
        this.rate = value;
        this.lfoIncrement = (2 * Math.PI * value) / this.sampleRate;
        break;
      case 'depth':
        this.depth = value;
        break;
      case 'feedback':
        this.feedback = value;
        break;
      case 'mix':
        this.mix = value;
        break;
    }
  }
  
  process(buffers, numChannels) {
    for (let i = 0; i < buffers.left.length; i++) {
      // Calculate LFO modulation
      const lfo = Math.sin(this.lfoPhase);
      const modulation = lfo * this.depth * this.sampleRate;
      const delayTime = 0.01 * this.sampleRate + modulation; // 10ms base + modulation
      
      // Calculate read position with interpolation
      const readPos = this.writeIndex - delayTime;
      const readIndex1 = Math.floor(readPos) & (this.bufferSize - 1);
      const readIndex2 = (readIndex1 + 1) & (this.bufferSize - 1);
      const fraction = readPos - Math.floor(readPos);
      
      for (let channel = 0; channel < Math.min(numChannels, 2); channel++) {
        const buffer = channel === 0 ? buffers.left : buffers.right;
        const input = buffer[i];
        
        // Linear interpolation
        const delayed1 = this.delayBuffer[channel][readIndex1];
        const delayed2 = this.delayBuffer[channel][readIndex2];
        const delayed = delayed1 + (delayed2 - delayed1) * fraction;
        
        // Write to delay buffer with feedback
        this.delayBuffer[channel][this.writeIndex] = input + (delayed * this.feedback);
        
        // Mix dry and wet
        buffer[i] = input * (1 - this.mix) + delayed * this.mix;
      }
      
      // Update LFO phase
      this.lfoPhase += this.lfoIncrement;
      if (this.lfoPhase >= 2 * Math.PI) {
        this.lfoPhase -= 2 * Math.PI;
      }
      
      // Update write index
      this.writeIndex = (this.writeIndex + 1) % this.bufferSize;
    }
  }
}

// Register the processor
registerProcessor('effects-processor', EffectsProcessor);