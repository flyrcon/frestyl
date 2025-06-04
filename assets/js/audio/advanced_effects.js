// assets/js/audio/advanced_effects.js

// Parametric EQ with real-time visualization
export class ParametricEQEffect {
  constructor(audioContext, params = {}) {
    this.audioContext = audioContext;
    this.input = audioContext.createGain();
    this.output = audioContext.createGain();
    
    // Create 5-band parametric EQ
    this.bands = [
      { filter: audioContext.createBiquadFilter(), freq: 80, type: 'highpass' },
      { filter: audioContext.createBiquadFilter(), freq: 200, type: 'peaking' },
      { filter: audioContext.createBiquadFilter(), freq: 1000, type: 'peaking' },
      { filter: audioContext.createBiquadFilter(), freq: 5000, type: 'peaking' },
      { filter: audioContext.createBiquadFilter(), freq: 12000, type: 'lowpass' }
    ];
    
    // Configure bands
    this.bands.forEach((band, index) => {
      band.filter.type = band.type;
      band.filter.frequency.value = band.freq;
      band.filter.Q.value = params.q || 1;
      band.filter.gain.value = params[`band${index}_gain`] || 0;
    });
    
    // Chain filters
    this.input.connect(this.bands[0].filter);
    for (let i = 0; i < this.bands.length - 1; i++) {
      this.bands[i].filter.connect(this.bands[i + 1].filter);
    }
    this.bands[this.bands.length - 1].filter.connect(this.output);
    
    // Real-time parameter control
    this.parameters = {
      band0_gain: { audioParam: this.bands[0].filter.gain, minValue: -24, maxValue: 24, defaultValue: 0 },
      band1_gain: { audioParam: this.bands[1].filter.gain, minValue: -24, maxValue: 24, defaultValue: 0 },
      band2_gain: { audioParam: this.bands[2].filter.gain, minValue: -24, maxValue: 24, defaultValue: 0 },
      band3_gain: { audioParam: this.bands[3].filter.gain, minValue: -24, maxValue: 24, defaultValue: 0 },
      band4_gain: { audioParam: this.bands[4].filter.gain, minValue: -24, maxValue: 24, defaultValue: 0 },
      band1_freq: { audioParam: this.bands[1].filter.frequency, minValue: 50, maxValue: 500, defaultValue: 200 },
      band2_freq: { audioParam: this.bands[2].filter.frequency, minValue: 200, maxValue: 5000, defaultValue: 1000 },
      band3_freq: { audioParam: this.bands[3].filter.frequency, minValue: 1000, maxValue: 20000, defaultValue: 5000 }
    };
  }
  
  getFrequencyResponse(frequencyArray) {
    // Calculate combined frequency response of all bands
    const magArray = new Float32Array(frequencyArray.length);
    const phaseArray = new Float32Array(frequencyArray.length);
    
    this.bands.forEach(band => {
      const tempMag = new Float32Array(frequencyArray.length);
      const tempPhase = new Float32Array(frequencyArray.length);
      band.filter.getFrequencyResponse(frequencyArray, tempMag, tempPhase);
      
      for (let i = 0; i < frequencyArray.length; i++) {
        magArray[i] += 20 * Math.log10(tempMag[i]);
      }
    });
    
    return { magnitude: magArray, phase: phaseArray };
  }
  
  disconnect() {
    this.input.disconnect();
    this.bands.forEach(band => band.filter.disconnect());
    this.output.disconnect();
  }
}

// Multiband Compressor with sidechain support
export class MultibandCompressorEffect {
  constructor(audioContext, params = {}) {
    this.audioContext = audioContext;
    this.input = audioContext.createGain();
    this.output = audioContext.createGain();
    
    // Create frequency splits
    this.lowSplit = audioContext.createBiquadFilter();
    this.midSplit = audioContext.createBiquadFilter();
    this.highSplit = audioContext.createBiquadFilter();
    
    this.lowSplit.type = 'lowpass';
    this.lowSplit.frequency.value = params.lowSplitFreq || 250;
    
    this.midSplit.type = 'bandpass';
    this.midSplit.frequency.value = params.midFreq || 2500;
    this.midSplit.Q.value = 0.5;
    
    this.highSplit.type = 'highpass';
    this.highSplit.frequency.value = params.highSplitFreq || 5000;
    
    // Create compressors for each band
    this.lowCompressor = audioContext.createDynamicsCompressor();
    this.midCompressor = audioContext.createDynamicsCompressor();
    this.highCompressor = audioContext.createDynamicsCompressor();
    
    // Configure compressors
    this.setupCompressor(this.lowCompressor, params.low || {});
    this.setupCompressor(this.midCompressor, params.mid || {});
    this.setupCompressor(this.highCompressor, params.high || {});
    
    // Create gain controls for each band
    this.lowGain = audioContext.createGain();
    this.midGain = audioContext.createGain();
    this.highGain = audioContext.createGain();
    
    this.lowGain.gain.value = params.lowGain || 1;
    this.midGain.gain.value = params.midGain || 1;
    this.highGain.gain.value = params.highGain || 1;
    
    // Connect the multiband chain
    this.input.connect(this.lowSplit);
    this.input.connect(this.midSplit);
    this.input.connect(this.highSplit);
    
    this.lowSplit.connect(this.lowCompressor);
    this.midSplit.connect(this.midCompressor);
    this.highSplit.connect(this.highCompressor);
    
    this.lowCompressor.connect(this.lowGain);
    this.midCompressor.connect(this.midGain);
    this.highCompressor.connect(this.highGain);
    
    this.lowGain.connect(this.output);
    this.midGain.connect(this.output);
    this.highGain.connect(this.output);
    
    // Parameter mapping for real-time control
    this.parameters = {
      low_threshold: { audioParam: this.lowCompressor.threshold, minValue: -60, maxValue: 0, defaultValue: -24 },
      low_ratio: { audioParam: this.lowCompressor.ratio, minValue: 1, maxValue: 20, defaultValue: 4 },
      low_gain: { audioParam: this.lowGain.gain, minValue: 0, maxValue: 4, defaultValue: 1 },
      mid_threshold: { audioParam: this.midCompressor.threshold, minValue: -60, maxValue: 0, defaultValue: -18 },
      mid_ratio: { audioParam: this.midCompressor.ratio, minValue: 1, maxValue: 20, defaultValue: 3 },
      mid_gain: { audioParam: this.midGain.gain, minValue: 0, maxValue: 4, defaultValue: 1 },
      high_threshold: { audioParam: this.highCompressor.threshold, minValue: -60, maxValue: 0, defaultValue: -12 },
      high_ratio: { audioParam: this.highCompressor.ratio, minValue: 1, maxValue: 20, defaultValue: 2 },
      high_gain: { audioParam: this.highGain.gain, minValue: 0, maxValue: 4, defaultValue: 1 }
    };
  }
  
  setupCompressor(compressor, params) {
    compressor.threshold.value = params.threshold || -24;
    compressor.knee.value = params.knee || 30;
    compressor.ratio.value = params.ratio || 4;
    compressor.attack.value = params.attack || 0.003;
    compressor.release.value = params.release || 0.25;
  }
  
  getGainReduction() {
    return {
      low: this.lowCompressor.reduction,
      mid: this.midCompressor.reduction,
      high: this.highCompressor.reduction
    };
  }
  
  disconnect() {
    this.input.disconnect();
    this.lowSplit.disconnect();
    this.midSplit.disconnect();
    this.highSplit.disconnect();
    this.lowCompressor.disconnect();
    this.midCompressor.disconnect();
    this.highCompressor.disconnect();
    this.lowGain.disconnect();
    this.midGain.disconnect();
    this.highGain.disconnect();
    this.output.disconnect();
  }
}

// Convolution Reverb with impulse response loading
export class ConvolutionReverbEffect {
  constructor(audioContext, params = {}) {
    this.audioContext = audioContext;
    this.input = audioContext.createGain();
    this.output = audioContext.createGain();
    
    this.convolver = audioContext.createConvolver();
    this.wetGain = audioContext.createGain();
    this.dryGain = audioContext.createGain();
    this.preDelay = audioContext.createDelay(1);
    this.dampening = audioContext.createBiquadFilter();
    
    // Configure nodes
    this.wetGain.gain.value = params.wet || 0.3;
    this.dryGain.gain.value = params.dry || 0.7;
    this.preDelay.delayTime.value = params.preDelay || 0.03;
    
    this.dampening.type = 'lowpass';
    this.dampening.frequency.value = params.dampeningFreq || 5000;
    this.dampening.Q.value = 0.7;
    
    // Connect reverb chain
    this.input.connect(this.dryGain);
    this.input.connect(this.preDelay);
    this.preDelay.connect(this.convolver);
    this.convolver.connect(this.dampening);
    this.dampening.connect(this.wetGain);
    
    this.dryGain.connect(this.output);
    this.wetGain.connect(this.output);
    
    // Load impulse response
    this.loadImpulseResponse(params.impulseUrl || 'default');
    
    this.parameters = {
      wet: { audioParam: this.wetGain.gain, minValue: 0, maxValue: 1, defaultValue: 0.3 },
      dry: { audioParam: this.dryGain.gain, minValue: 0, maxValue: 1, defaultValue: 0.7 },
      predelay: { audioParam: this.preDelay.delayTime, minValue: 0, maxValue: 0.2, defaultValue: 0.03 },
      dampening: { audioParam: this.dampening.frequency, minValue: 1000, maxValue: 20000, defaultValue: 5000 }
    };
  }
  
  async loadImpulseResponse(type) {
    let impulseBuffer;
    
    if (type === 'default' || !type) {
      impulseBuffer = this.generateSyntheticImpulse('hall');
    } else if (typeof type === 'string') {
      try {
        const response = await fetch(`/audio/impulses/${type}.wav`);
        const arrayBuffer = await response.arrayBuffer();
        impulseBuffer = await this.audioContext.decodeAudioData(arrayBuffer);
      } catch (error) {
        console.warn(`Failed to load impulse response ${type}, using synthetic`);
        impulseBuffer = this.generateSyntheticImpulse(type);
      }
    }
    
    this.convolver.buffer = impulseBuffer;
  }
  
  generateSyntheticImpulse(type) {
    const length = this.audioContext.sampleRate * (type === 'cathedral' ? 4 : 2);
    const impulse = this.audioContext.createBuffer(2, length, this.audioContext.sampleRate);
    
    const decay = type === 'cathedral' ? 4 : type === 'hall' ? 2.5 : 1.5;
    const roomSize = type === 'cathedral' ? 0.8 : type === 'hall' ? 0.6 : 0.4;
    
    for (let channel = 0; channel < 2; channel++) {
      const channelData = impulse.getChannelData(channel);
      for (let i = 0; i < length; i++) {
        const n = length - i;
        const reverb = (Math.random() * 2 - 1) * Math.pow(n / length, decay) * roomSize;
        
        // Add early reflections
        const earlyReflections = this.generateEarlyReflections(i, length, roomSize);
        channelData[i] = reverb + earlyReflections;
      }
    }
    
    return impulse;
  }
  
  generateEarlyReflections(sampleIndex, totalLength, roomSize) {
    const reflectionTimes = [0.01, 0.02, 0.035, 0.055, 0.08]; // seconds
    let reflection = 0;
    
    reflectionTimes.forEach((time, index) => {
      const reflectionSample = Math.floor(time * this.audioContext.sampleRate);
      if (Math.abs(sampleIndex - reflectionSample) < 10) {
        const gain = roomSize * (0.8 - index * 0.15);
        reflection += (Math.random() * 2 - 1) * gain;
      }
    });
    
    return reflection;
  }
  
  disconnect() {
    this.input.disconnect();
    this.convolver.disconnect();
    this.wetGain.disconnect();
    this.dryGain.disconnect();
    this.preDelay.disconnect();
    this.dampening.disconnect();
    this.output.disconnect();
  }
}

// Stereo Widener with M/S processing
export class StereoWidenerEffect {
  constructor(audioContext, params = {}) {
    this.audioContext = audioContext;
    this.input = audioContext.createGain();
    this.output = audioContext.createGain();
    
    // Create M/S matrix
    this.msEncoder = audioContext.createChannelSplitter(2);
    this.msDecoder = audioContext.createChannelMerger(2);
    this.midGain = audioContext.createGain();
    this.sideGain = audioContext.createGain();
    
    // Bass mono filter
    this.bassMonoFilter = audioContext.createBiquadFilter();
    this.bassMonoFilter.type = 'lowpass';
    this.bassMonoFilter.frequency.value = params.bassMonoFreq || 120;
    
    // Width control
    this.width = params.width || 1.0;
    this.updateWidth();
    
    // Connect M/S processing
    this.input.connect(this.msEncoder);
    
    // Mid channel (L+R)
    this.msEncoder.connect(this.midGain, 0);
    this.msEncoder.connect(this.midGain, 1);
    
    // Side channel (L-R)
    this.msEncoder.connect(this.sideGain, 0);
    this.msEncoder.connect(this.sideGain, 1);
    
    // Apply bass mono
    this.midGain.connect(this.bassMonoFilter);
    this.bassMonoFilter.connect(this.msDecoder, 0, 0);
    this.bassMonoFilter.connect(this.msDecoder, 0, 1);
    
    // Processed side signal
    this.sideGain.connect(this.msDecoder, 0, 0);
    this.sideGain.connect(this.msDecoder, 0, 1);
    
    this.msDecoder.connect(this.output);
    
    this.parameters = {
      width: { 
        get audioParam() { return null; }, // Custom parameter
        minValue: 0, maxValue: 3, defaultValue: 1,
        setter: (value) => this.setWidth(value)
      },
      bass_mono_freq: { audioParam: this.bassMonoFilter.frequency, minValue: 60, maxValue: 300, defaultValue: 120 }
    };
  }
  
  setWidth(width) {
    this.width = Math.max(0, Math.min(3, width));
    this.updateWidth();
  }
  
  updateWidth() {
    // M/S width formula
    const midGain = 1.0;
    const sideGain = this.width - 1.0;
    
    this.midGain.gain.value = midGain;
    this.sideGain.gain.value = sideGain;
  }
  
  disconnect() {
    this.input.disconnect();
    this.msEncoder.disconnect();
    this.msDecoder.disconnect();
    this.midGain.disconnect();
    this.sideGain.disconnect();
    this.bassMonoFilter.disconnect();
    this.output.disconnect();
  }
}

// Tape Saturation with wow/flutter
export class TapeSaturationEffect {
  constructor(audioContext, params = {}) {
    this.audioContext = audioContext;
    this.input = audioContext.createGain();
    this.output = audioContext.createGain();
    
    // Saturation waveshaping
    this.inputGain = audioContext.createGain();
    this.waveshaper = audioContext.createWaveShaper();
    this.outputGain = audioContext.createGain();
    
    // Tape characteristics
    this.highCut = audioContext.createBiquadFilter();
    this.lowBoost = audioContext.createBiquadFilter();
    
    // Wow & Flutter (pitch modulation)
    this.pitchShifter = new PitchShifter(audioContext);
    this.wowLFO = audioContext.createOscillator();
    this.flutterLFO = audioContext.createOscillator();
    this.wowGain = audioContext.createGain();
    this.flutterGain = audioContext.createGain();
    
    // Configure saturation
    this.inputGain.gain.value = params.drive || 2;
    this.outputGain.gain.value = params.level || 0.5;
    this.generateTapeCurve(params.saturation || 0.6);
    
    // Configure tape EQ
    this.highCut.type = 'lowpass';
    this.highCut.frequency.value = params.highCutFreq || 8000;
    this.highCut.Q.value = 0.7;
    
    this.lowBoost.type = 'lowshelf';
    this.lowBoost.frequency.value = 200;
    this.lowBoost.gain.value = params.warmth || 2;
    
    // Configure wow & flutter
    this.wowLFO.type = 'sine';
    this.wowLFO.frequency.value = 0.5; // 0.5 Hz wow
    this.flutterLFO.type = 'triangle';
    this.flutterLFO.frequency.value = 6; // 6 Hz flutter
    
    this.wowGain.gain.value = params.wow || 0.002;
    this.flutterGain.gain.value = params.flutter || 0.001;
    
    // Connect processing chain
    this.input.connect(this.inputGain);
    this.inputGain.connect(this.waveshaper);
    this.waveshaper.connect(this.lowBoost);
    this.lowBoost.connect(this.highCut);
    this.highCut.connect(this.pitchShifter.input);
    this.pitchShifter.output.connect(this.outputGain);
    this.outputGain.connect(this.output);
    
    // Connect modulation
    this.wowLFO.connect(this.wowGain);
    this.flutterLFO.connect(this.flutterGain);
    this.wowGain.connect(this.pitchShifter.pitchBend);
    this.flutterGain.connect(this.pitchShifter.pitchBend);
    
    // Start LFOs
    this.wowLFO.start();
    this.flutterLFO.start();
    
    this.parameters = {
      drive: { audioParam: this.inputGain.gain, minValue: 1, maxValue: 5, defaultValue: 2 },
      level: { audioParam: this.outputGain.gain, minValue: 0.1, maxValue: 2, defaultValue: 0.5 },
      warmth: { audioParam: this.lowBoost.gain, minValue: 0, maxValue: 6, defaultValue: 2 },
      high_cut: { audioParam: this.highCut.frequency, minValue: 3000, maxValue: 15000, defaultValue: 8000 },
      wow: { audioParam: this.wowGain.gain, minValue: 0, maxValue: 0.01, defaultValue: 0.002 },
      flutter: { audioParam: this.flutterGain.gain, minValue: 0, maxValue: 0.005, defaultValue: 0.001 }
    };
  }
  
  generateTapeCurve(amount) {
    const samples = 44100;
    const curve = new Float32Array(samples);
    
    for (let i = 0; i < samples; i++) {
      const x = (i * 2) / samples - 1;
      // Tape-style soft saturation
      curve[i] = Math.tanh(x * amount * 3) * (1 - amount * 0.2);
    }
    
    this.waveshaper.curve = curve;
  }
  
  disconnect() {
    this.wowLFO.stop();
    this.flutterLFO.stop();
    this.input.disconnect();
    this.inputGain.disconnect();
    this.waveshaper.disconnect();
    this.outputGain.disconnect();
    this.highCut.disconnect();
    this.lowBoost.disconnect();
    this.pitchShifter.disconnect();
    this.wowLFO.disconnect();
    this.flutterLFO.disconnect();
    this.wowGain.disconnect();
    this.flutterGain.disconnect();
    this.output.disconnect();
  }
}

// Auto-Tune Effect with pitch correction
export class AutoTuneEffect {
  constructor(audioContext, params = {}) {
    this.audioContext = audioContext;
    this.input = audioContext.createGain();
    this.output = audioContext.createGain();
    
    // Pitch detection and correction
    this.pitchDetector = new PitchDetector(audioContext);
    this.pitchCorrector = new PitchCorrector(audioContext);
    
    // Configuration
    this.key = params.key || 'C';
    this.scale = params.scale || 'major';
    this.correction = params.correction || 0.8; // 0 = no correction, 1 = full correction
    this.speed = params.speed || 0.1; // correction speed
    
    // Generate scale notes
    this.scaleNotes = this.generateScaleNotes(this.key, this.scale);
    
    // Connect processing
    this.input.connect(this.pitchDetector.input);
    this.pitchDetector.output.connect(this.pitchCorrector.input);
    this.pitchCorrector.output.connect(this.output);
    
    // Set up pitch correction callback
    this.pitchDetector.onPitchDetected = (pitch) => {
      const correctedPitch = this.correctPitch(pitch);
      this.pitchCorrector.setPitchCorrection(correctedPitch, this.speed);
    };
    
    this.parameters = {
      correction: { 
        get audioParam() { return null; },
        minValue: 0, maxValue: 1, defaultValue: 0.8,
        setter: (value) => this.correction = value
      },
      speed: { 
        get audioParam() { return null; },
        minValue: 0.01, maxValue: 1, defaultValue: 0.1,
        setter: (value) => this.speed = value
      }
    };
  }
  
  generateScaleNotes(key, scale) {
    const chromatic = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    const scalePatterns = {
      major: [0, 2, 4, 5, 7, 9, 11],
      minor: [0, 2, 3, 5, 7, 8, 10],
      pentatonic: [0, 2, 4, 7, 9]
    };
    
    const pattern = scalePatterns[scale] || scalePatterns.major;
    const keyIndex = chromatic.indexOf(key);
    const notes = [];
    
    // Generate notes across multiple octaves
    for (let octave = 1; octave < 7; octave++) {
      pattern.forEach(interval => {
        const noteIndex = (keyIndex + interval) % 12;
        const frequency = 440 * Math.pow(2, (noteIndex - 9 + (octave - 4) * 12) / 12);
        notes.push(frequency);
      });
    }
    
    return notes.sort((a, b) => a - b);
  }
  
  correctPitch(detectedPitch) {
    if (!detectedPitch || detectedPitch < 80 || detectedPitch > 2000) {
      return detectedPitch; // Outside vocal range, no correction
    }
    
    // Find closest note in scale
    let closestNote = this.scaleNotes[0];
    let minDistance = Math.abs(detectedPitch - closestNote);
    
    for (const note of this.scaleNotes) {
      const distance = Math.abs(detectedPitch - note);
      if (distance < minDistance) {
        minDistance = distance;
        closestNote = note;
      }
    }
    
    // Apply correction strength
    const correctedPitch = detectedPitch + (closestNote - detectedPitch) * this.correction;
    return correctedPitch;
  }
  
  setKey(key) {
    this.key = key;
    this.scaleNotes = this.generateScaleNotes(this.key, this.scale);
  }
  
  setScale(scale) {
    this.scale = scale;
    this.scaleNotes = this.generateScaleNotes(this.key, this.scale);
  }
  
  disconnect() {
    this.input.disconnect();
    this.pitchDetector.disconnect();
    this.pitchCorrector.disconnect();
    this.output.disconnect();
  }
}

// Vocoder Effect
export class VocoderEffect {
  constructor(audioContext, params = {}) {
    this.audioContext = audioContext;
    this.input = audioContext.createGain();
    this.output = audioContext.createGain();
    
    // Carrier and modulator inputs
    this.modulatorInput = audioContext.createGain();
    this.carrierInput = audioContext.createGain();
    
    // Number of frequency bands
    this.numBands = params.bands || 16;
    this.bands = [];
    
    // Create filter banks
    this.createFilterBanks();
    
    // Attack and release for envelope followers
    this.attack = params.attack || 0.01;
    this.release = params.release || 0.1;
    
    // Default carrier (synthesizer)
    this.createDefaultCarrier();
    
    // Connect default routing (input as modulator)
    this.input.connect(this.modulatorInput);
    
    this.parameters = {
      bands: { 
        get audioParam() { return null; },
        minValue: 8, maxValue: 32, defaultValue: 16,
        setter: (value) => this.setBandCount(value)
      },
      attack: { 
        get audioParam() { return null; },
        minValue: 0.001, maxValue: 0.1, defaultValue: 0.01,
        setter: (value) => this.attack = value
      },
      release: { 
        get audioParam() { return null; },
        minValue: 0.01, maxValue: 1, defaultValue: 0.1,
        setter: (value) => this.release = value
      }
    };
  }
  
  createFilterBanks() {
    const nyquist = this.audioContext.sampleRate / 2;
    const minFreq = 80;
    const maxFreq = 8000;
    
    for (let i = 0; i < this.numBands; i++) {
      // Calculate band frequency (logarithmic distribution)
      const freq = minFreq * Math.pow(maxFreq / minFreq, i / (this.numBands - 1));
      const bandwidth = freq * 0.3; // 30% bandwidth
      
      // Create band
      const band = {
        frequency: freq,
        modulatorFilter: this.audioContext.createBiquadFilter(),
        carrierFilter: this.audioContext.createBiquadFilter(),
        envelopeFollower: new EnvelopeFollower(this.audioContext, this.attack, this.release),
        vca: this.audioContext.createGain()
      };
      
      // Configure filters
      band.modulatorFilter.type = 'bandpass';
      band.modulatorFilter.frequency.value = freq;
      band.modulatorFilter.Q.value = freq / bandwidth;
      
      band.carrierFilter.type = 'bandpass';
      band.carrierFilter.frequency.value = freq;
      band.carrierFilter.Q.value = freq / bandwidth;
      
      // Connect band processing
      this.modulatorInput.connect(band.modulatorFilter);
      this.carrierInput.connect(band.carrierFilter);
      
      band.modulatorFilter.connect(band.envelopeFollower.input);
      band.envelopeFollower.output.connect(band.vca.gain);
      band.carrierFilter.connect(band.vca);
      band.vca.connect(this.output);
      
      this.bands.push(band);
    }
  }
  
  createDefaultCarrier() {
    // Simple sawtooth carrier
    this.carrierOscillator = this.audioContext.createOscillator();
    this.carrierOscillator.type = 'sawtooth';
    this.carrierOscillator.frequency.value = 200;
    this.carrierOscillator.connect(this.carrierInput);
    this.carrierOscillator.start();
  }
  
  setBandCount(count) {
    // Disconnect existing bands
    this.bands.forEach(band => {
      band.modulatorFilter.disconnect();
      band.carrierFilter.disconnect();
      band.envelopeFollower.disconnect();
      band.vca.disconnect();
    });
    
    this.bands = [];
    this.numBands = count;
    this.createFilterBanks();
  }
  
  disconnect() {
    this.carrierOscillator.stop();
    this.input.disconnect();
    this.modulatorInput.disconnect();
    this.carrierInput.disconnect();
    this.bands.forEach(band => {
      band.modulatorFilter.disconnect();
      band.carrierFilter.disconnect();
      band.envelopeFollower.disconnect();
      band.vca.disconnect();
    });
    this.output.disconnect();
  }
}

// Helper Classes
class PitchShifter {
  constructor(audioContext) {
    this.audioContext = audioContext;
    this.input = audioContext.createGain();
    this.output = audioContext.createGain();
    this.pitchBend = audioContext.createGain();
    
    // Simple pitch shifting using delay modulation
    this.delay1 = audioContext.createDelay(0.1);
    this.delay2 = audioContext.createDelay(0.1);
    this.lfo = audioContext.createOscillator();
    this.lfoGain = audioContext.createGain();
    
    this.lfo.type = 'triangle';
    this.lfo.frequency.value = 5;
    this.lfoGain.gain.value = 0.005;
    
    this.input.connect(this.delay1);
    this.input.connect(this.delay2);
    this.delay1.connect(this.output);
    this.delay2.connect(this.output);
    
    this.lfo.connect(this.lfoGain);
    this.lfoGain.connect(this.delay1.delayTime);
    this.pitchBend.connect(this.delay1.delayTime);
    this.pitchBend.connect(this.delay2.delayTime);
    
    this.lfo.start();
  }
  
  disconnect() {
    this.lfo.stop();
    this.input.disconnect();
    this.delay1.disconnect();
    this.delay2.disconnect();
    this.lfo.disconnect();
    this.lfoGain.disconnect();
    this.pitchBend.disconnect();
    this.output.disconnect();
  }
}

class PitchDetector {
  constructor(audioContext) {
    this.audioContext = audioContext;
    this.input = audioContext.createGain();
    this.output = audioContext.createGain();
    this.analyzer = audioContext.createAnalyser();
    
    this.analyzer.fftSize = 4096;
    this.buffer = new Float32Array(this.analyzer.fftSize);
    this.input.connect(this.analyzer);
    this.input.connect(this.output);
    
    this.onPitchDetected = null;
    this.startPitchDetection();
  }
  
  startPitchDetection() {
    const detectPitch = () => {
      this.analyzer.getFloatTimeDomainData(this.buffer);
      const pitch = this.autocorrelate(this.buffer);
      
      if (this.onPitchDetected && pitch > 0) {
        this.onPitchDetected(pitch);
      }
      
      setTimeout(detectPitch, 50); // 20Hz detection rate
    };
    detectPitch();
  }
  
  autocorrelate(buffer) {
    const SIZE = buffer.length;
    const MAX_SAMPLES = Math.floor(SIZE / 2);
    let bestOffset = -1;
    let bestCorrelation = 0;
    let rms = 0;
    
    // Calculate RMS
    for (let i = 0; i < SIZE; i++) {
      const val = buffer[i];
      rms += val * val;
    }
    rms = Math.sqrt(rms / SIZE);
    
    if (rms < 0.01) return -1; // Too quiet
    
    let lastCorrelation = 1;
    for (let offset = 1; offset < MAX_SAMPLES; offset++) {
      let correlation = 0;
      
      for (let i = 0; i < MAX_SAMPLES; i++) {
        correlation += Math.abs((buffer[i]) - (buffer[i + offset]));
      }
      correlation = 1 - (correlation / MAX_SAMPLES);
      
      if (correlation > 0.9 && correlation > lastCorrelation) {
        bestCorrelation = correlation;
        bestOffset = offset;
      }
      
      lastCorrelation = correlation;
    }
    
    if (bestCorrelation > 0.9) {
      return this.audioContext.sampleRate / bestOffset;
    }
    return -1;
  }
  
  disconnect() {
    this.input.disconnect();
    this.analyzer.disconnect();
    this.output.disconnect();
  }
}

class PitchCorrector {
  constructor(audioContext) {
    this.audioContext = audioContext;
    this.input = audioContext.createGain();
    this.output = audioContext.createGain();
    
    // Simple pitch correction using granular synthesis
    this.pitchShifter = new PitchShifter(audioContext);
    this.input.connect(this.pitchShifter.input);
    this.pitchShifter.output.connect(this.output);
    
    this.targetPitch = 440;
    this.currentPitch = 440;
  }
  
  setPitchCorrection(targetPitch, speed) {
    this.targetPitch = targetPitch;
    
    // Calculate pitch shift ratio
    const ratio = targetPitch / this.currentPitch;
    const pitchShift = Math.log2(ratio) * 12; // In semitones
    
    // Apply correction gradually
    const currentTime = this.audioContext.currentTime;
    this.pitchShifter.pitchBend.gain.setTargetAtTime(
      pitchShift * 0.01, // Convert to delay modulation
      currentTime,
      speed
    );
    
    this.currentPitch = targetPitch;
  }
  
  disconnect() {
    this.input.disconnect();
    this.pitchShifter.disconnect();
    this.output.disconnect();
  }
}

class EnvelopeFollower {
  constructor(audioContext, attack = 0.01, release = 0.1) {
    this.audioContext = audioContext;
    this.input = audioContext.createGain();
    this.output = audioContext.createGain();
    
    // Rectifier (absolute value)
    this.rectifier = audioContext.createWaveShaper();
    this.rectifier.curve = new Float32Array([-1, -1, 1, 1]); // Simplified rectification
    
    // Smoothing filter (low-pass)
    this.smoother = audioContext.createBiquadFilter();
    this.smoother.type = 'lowpass';
    this.smoother.frequency.value = 1 / (attack + release); // Approximate
    this.smoother.Q.value = 0.7;
    
    this.input.connect(this.rectifier);
    this.rectifier.connect(this.smoother);
    this.smoother.connect(this.output);
  }
  
  disconnect() {
    this.input.disconnect();
    this.rectifier.disconnect();
    this.smoother.disconnect();
    this.output.disconnect();
  }
}

// Phaser Effect
export class PhaserEffect {
  constructor(audioContext, params = {}) {
    this.audioContext = audioContext;
    this.input = audioContext.createGain();
    this.output = audioContext.createGain();
    
    // Create all-pass filter stages
    this.stages = params.stages || 6;
    this.allPassFilters = [];
    
    for (let i = 0; i < this.stages; i++) {
      const allPass = audioContext.createBiquadFilter();
      allPass.type = 'allpass';
      allPass.frequency.value = 1000;
      allPass.Q.value = 10;
      this.allPassFilters.push(allPass);
    }
    
    // LFO for modulation
    this.lfo = audioContext.createOscillator();
    this.lfoGain = audioContext.createGain();
    this.dryGain = audioContext.createGain();
    this.wetGain = audioContext.createGain();
    this.feedback = audioContext.createGain();
    
    // Configure parameters
    this.lfo.type = 'sine';
    this.lfo.frequency.value = params.rate || 0.5;
    this.lfoGain.gain.value = params.depth || 1000;
    this.dryGain.gain.value = params.dry || 0.7;
    this.wetGain.gain.value = params.wet || 0.3;
    this.feedback.gain.value = params.feedback || 0.7;
    
    // Connect the phaser chain
    this.input.connect(this.dryGain);
    this.dryGain.connect(this.output);
    
    // Connect all-pass chain
    let currentNode = this.input;
    for (const filter of this.allPassFilters) {
      currentNode.connect(filter);
      currentNode = filter;
      
      // Connect LFO to filter frequency
      this.lfo.connect(this.lfoGain);
      this.lfoGain.connect(filter.frequency);
    }
    
    // Connect wet signal and feedback
    currentNode.connect(this.wetGain);
    currentNode.connect(this.feedback);
    this.feedback.connect(this.input); // Feedback loop
    this.wetGain.connect(this.output);
    
    this.lfo.start();
    
    this.parameters = {
      rate: { audioParam: this.lfo.frequency, minValue: 0.1, maxValue: 10, defaultValue: 0.5 },
      depth: { audioParam: this.lfoGain.gain, minValue: 100, maxValue: 3000, defaultValue: 1000 },
      feedback: { audioParam: this.feedback.gain, minValue: 0, maxValue: 0.95, defaultValue: 0.7 },
      wet: { audioParam: this.wetGain.gain, minValue: 0, maxValue: 1, defaultValue: 0.3 }
    };
  }
  
  disconnect() {
    this.lfo.stop();
    this.input.disconnect();
    this.allPassFilters.forEach(filter => filter.disconnect());
    this.lfo.disconnect();
    this.lfoGain.disconnect();
    this.dryGain.disconnect();
    this.wetGain.disconnect();
    this.feedback.disconnect();
    this.output.disconnect();
  }
}

// Flanger Effect
export class FlangerEffect {
  constructor(audioContext, params = {}) {
    this.audioContext = audioContext;
    this.input = audioContext.createGain();
    this.output = audioContext.createGain();
    
    // Delay line
    this.delay = audioContext.createDelay(0.02);
    this.delayGain = audioContext.createGain();
    this.dryGain = audioContext.createGain();
    this.feedback = audioContext.createGain();
    
    // LFO for delay modulation
    this.lfo = audioContext.createOscillator();
    this.lfoGain = audioContext.createGain();
    
    // Configure parameters
    this.lfo.type = 'sine';
    this.lfo.frequency.value = params.rate || 0.3;
    this.lfoGain.gain.value = params.depth || 0.005;
    this.delay.delayTime.value = params.delay || 0.01;
    this.delayGain.gain.value = params.mix || 0.5;
    this.dryGain.gain.value = 1 - (params.mix || 0.5);
    this.feedback.gain.value = params.feedback || 0.6;
    
    // Connect flanger
    this.input.connect(this.dryGain);
    this.input.connect(this.delay);
    this.delay.connect(this.delayGain);
    this.delay.connect(this.feedback);
    this.feedback.connect(this.delay); // Feedback loop
    
    this.dryGain.connect(this.output);
    this.delayGain.connect(this.output);
    
    // Connect LFO modulation
    this.lfo.connect(this.lfoGain);
    this.lfoGain.connect(this.delay.delayTime);
    
    this.lfo.start();
    
    this.parameters = {
      rate: { audioParam: this.lfo.frequency, minValue: 0.05, maxValue: 5, defaultValue: 0.3 },
      depth: { audioParam: this.lfoGain.gain, minValue: 0.001, maxValue: 0.01, defaultValue: 0.005 },
      feedback: { audioParam: this.feedback.gain, minValue: 0, maxValue: 0.95, defaultValue: 0.6 },
      mix: { audioParam: this.delayGain.gain, minValue: 0, maxValue: 1, defaultValue: 0.5 }
    };
  }
  
  disconnect() {
    this.lfo.stop();
    this.input.disconnect();
    this.delay.disconnect();
    this.delayGain.disconnect();
    this.dryGain.disconnect();
    this.feedback.disconnect();
    this.lfo.disconnect();
    this.lfoGain.disconnect();
    this.output.disconnect();
  }
}

// Bitcrusher Effect
export class BitcrusherEffect {
  constructor(audioContext, params = {}) {
    this.audioContext = audioContext;
    this.input = audioContext.createGain();
    this.output = audioContext.createGain();
    
    // Sample rate reduction using delay modulation
    this.sampleRateReducer = audioContext.createDelay(0.1);
    this.sampleRateGain = audioContext.createGain();
    
    // Bit depth reduction using waveshaping
    this.bitDepthReducer = audioContext.createWaveShaper();
    
    // Parameters
    this.bits = params.bits || 8;
    this.sampleRate = params.sampleRate || 0.5; // 0-1 range
    
    this.generateBitCrushCurve();
    this.updateSampleRate();
    
    // Connect processing
    this.input.connect(this.sampleRateReducer);
    this.sampleRateReducer.connect(this.bitDepthReducer);
    this.bitDepthReducer.connect(this.output);
    
    this.parameters = {
      bits: { 
        get audioParam() { return null; },
        minValue: 1, maxValue: 16, defaultValue: 8,
        setter: (value) => this.setBits(value)
      },
      sample_rate: { 
        get audioParam() { return null; },
        minValue: 0.1, maxValue: 1, defaultValue: 0.5,
        setter: (value) => this.setSampleRate(value)
      }
    };
  }
  
  setBits(bits) {
    this.bits = Math.floor(Math.max(1, Math.min(16, bits)));
    this.generateBitCrushCurve();
  }
  
  setSampleRate(rate) {
    this.sampleRate = Math.max(0.1, Math.min(1, rate));
    this.updateSampleRate();
  }
  
  generateBitCrushCurve() {
    const samples = 65536;
    const curve = new Float32Array(samples);
    const levels = Math.pow(2, this.bits);
    const step = 2 / levels;
    
    for (let i = 0; i < samples; i++) {
      const x = (i / samples) * 2 - 1;
      const quantized = Math.floor((x + 1) / step) * step - 1;
      curve[i] = Math.max(-1, Math.min(1, quantized));
    }
    
    this.bitDepthReducer.curve = curve;
  }
  
  updateSampleRate() {
    // Simplified sample rate reduction using delay time modulation
    const delayTime = (1 - this.sampleRate) * 0.01;
    this.sampleRateReducer.delayTime.value = delayTime;
  }
  
  disconnect() {
    this.input.disconnect();
    this.sampleRateReducer.disconnect();
    this.bitDepthReducer.disconnect();
    this.output.disconnect();
  }
}

// Spectral Gate Effect
export class SpectralGateEffect {
  constructor(audioContext, params = {}) {
    this.audioContext = audioContext;
    this.input = audioContext.createGain();
    this.output = audioContext.createGain();
    
    // FFT analysis and processing (simplified implementation)
    this.analyzer = audioContext.createAnalyser();
    this.analyzer.fftSize = params.fftSize || 2048;
    this.processor = audioContext.createScriptProcessor(1024, 1, 1);
    
    // Gate parameters
    this.threshold = params.threshold || -40; // dB
    this.ratio = params.ratio || 10;
    this.attack = params.attack || 0.001;
    this.release = params.release || 0.1;
    
    // Frequency band gates
    this.numBands = 16;
    this.bandGates = [];
    
    for (let i = 0; i < this.numBands; i++) {
      const gate = audioContext.createGain();
      gate.gain.value = 1;
      this.bandGates.push(gate);
    }
    
    // Connect processing
    this.input.connect(this.analyzer);
    this.input.connect(this.processor);
    this.processor.connect(this.output);
    
    // Set up spectral processing
    this.setupSpectralProcessing();
    
    this.parameters = {
      threshold: { 
        get audioParam() { return null; },
        minValue: -60, maxValue: 0, defaultValue: -40,
        setter: (value) => this.threshold = value
      },
      ratio: { 
        get audioParam() { return null; },
        minValue: 1, maxValue: 20, defaultValue: 10,
        setter: (value) => this.ratio = value
      },
      attack: { 
        get audioParam() { return null; },
        minValue: 0.001, maxValue: 0.1, defaultValue: 0.001,
        setter: (value) => this.attack = value
      },
      release: { 
        get audioParam() { return null; },
        minValue: 0.01, maxValue: 1, defaultValue: 0.1,
        setter: (value) => this.release = value
      }
    };
  }
  
  setupSpectralProcessing() {
    const bufferLength = this.analyzer.frequencyBinCount;
    const dataArray = new Uint8Array(bufferLength);
    const bandGains = new Float32Array(this.numBands);
    
    this.processor.onaudioprocess = (event) => {
      // Get frequency data
      this.analyzer.getByteFrequencyData(dataArray);
      
      // Calculate band levels
      const binsPerBand = Math.floor(bufferLength / this.numBands);
      
      for (let band = 0; band < this.numBands; band++) {
        let bandLevel = 0;
        const startBin = band * binsPerBand;
        const endBin = Math.min(startBin + binsPerBand, bufferLength);
        
        for (let bin = startBin; bin < endBin; bin++) {
          bandLevel += dataArray[bin];
        }
        
        bandLevel = (bandLevel / (endBin - startBin)) / 255;
        const dbLevel = 20 * Math.log10(bandLevel + 0.001); // Avoid log(0)
        
        // Apply gating
        let targetGain;
        if (dbLevel > this.threshold) {
          targetGain = 1;
        } else {
          const reduction = (this.threshold - dbLevel) / this.ratio;
          targetGain = Math.pow(10, -reduction / 20);
        }
        
        // Smooth gain changes
        const timeConstant = targetGain > bandGains[band] ? this.attack : this.release;
        bandGains[band] += (targetGain - bandGains[band]) * (1 - Math.exp(-1 / (timeConstant * this.audioContext.sampleRate)));
      }
      
      // Apply spectral gating (simplified - would need FFT implementation for real spectral gating)
      const inputBuffer = event.inputBuffer;
      const outputBuffer = event.outputBuffer;
      
      for (let channel = 0; channel < inputBuffer.numberOfChannels; channel++) {
        const inputData = inputBuffer.getChannelData(channel);
        const outputData = outputBuffer.getChannelData(channel);
        
        for (let sample = 0; sample < inputBuffer.length; sample++) {
          // Simple spectral approximation using band gains
          const band = Math.floor((sample / inputBuffer.length) * this.numBands);
          const gain = bandGains[Math.min(band, this.numBands - 1)];
          outputData[sample] = inputData[sample] * gain;
        }
      }
    };
  }
  
  disconnect() {
    this.processor.disconnect();
    this.input.disconnect();
    this.analyzer.disconnect();
    this.output.disconnect();
  }
}

// Vintage Delay Effect
export class VintageDelayEffect {
  constructor(audioContext, params = {}) {
    this.audioContext = audioContext;
    this.input = audioContext.createGain();
    this.output = audioContext.createGain();
    
    // Multiple delay taps for vintage character
    this.delay1 = audioContext.createDelay(1);
    this.delay2 = audioContext.createDelay(1);
    this.delay3 = audioContext.createDelay(1);
    
    // Feedback and mixing
    this.feedback = audioContext.createGain();
    this.wetGain = audioContext.createGain();
    this.dryGain = audioContext.createGain();
    
    // Vintage character processing
    this.toneFilter = audioContext.createBiquadFilter();
    this.saturation = audioContext.createWaveShaper();
    this.wow = audioContext.createOscillator();
    this.wowGain = audioContext.createGain();
    
    // Configure delays
    this.delay1.delayTime.value = params.time || 0.25;
    this.delay2.delayTime.value = (params.time || 0.25) * 1.618; // Golden ratio
    this.delay3.delayTime.value = (params.time || 0.25) * 0.618;
    
    // Configure character
    this.feedback.gain.value = params.feedback || 0.4;
    this.wetGain.gain.value = params.wet || 0.3;
    this.dryGain.gain.value = params.dry || 0.7;
    
    // Tone filter (vintage tape delay character)
    this.toneFilter.type = 'lowpass';
    this.toneFilter.frequency.value = params.tone || 3000;
    this.toneFilter.Q.value = 0.7;
    
    // Saturation for tape-like warmth
    this.generateVintageSaturation(params.dirt || 0.3);
    
    // Wow modulation
    this.wow.type = 'sine';
    this.wow.frequency.value = 0.6;
    this.wowGain.gain.value = params.wowFlutter || 0.002;
    
    // Connect vintage delay chain
    this.input.connect(this.dryGain);
    this.input.connect(this.delay1);
    
    this.delay1.connect(this.toneFilter);
    this.toneFilter.connect(this.saturation);
    this.saturation.connect(this.delay2);
    this.delay2.connect(this.delay3);
    
    this.delay3.connect(this.feedback);
    this.delay3.connect(this.wetGain);
    this.feedback.connect(this.delay1); // Feedback loop
    
    this.dryGain.connect(this.output);
    this.wetGain.connect(this.output);
    
    // Connect wow modulation
    this.wow.connect(this.wowGain);
    this.wowGain.connect(this.delay1.delayTime);
    this.wowGain.connect(this.delay2.delayTime);
    this.wowGain.connect(this.delay3.delayTime);
    
    this.wow.start();
    
    this.parameters = {
      time: { audioParam: this.delay1.delayTime, minValue: 0.01, maxValue: 1, defaultValue: 0.25 },
      feedback: { audioParam: this.feedback.gain, minValue: 0, maxValue: 0.95, defaultValue: 0.4 },
      tone: { audioParam: this.toneFilter.frequency, minValue: 500, maxValue: 8000, defaultValue: 3000 },
      wet: { audioParam: this.wetGain.gain, minValue: 0, maxValue: 1, defaultValue: 0.3 },
      wow_flutter: { audioParam: this.wowGain.gain, minValue: 0, maxValue: 0.01, defaultValue: 0.002 }
    };
  }
  
  generateVintageSaturation(amount) {
    const samples = 44100;
    const curve = new Float32Array(samples);
    
    for (let i = 0; i < samples; i++) {
      const x = (i * 2) / samples - 1;
      // Vintage tape-style saturation
      curve[i] = Math.tanh(x * (1 + amount * 2)) * (1 - amount * 0.1);
    }
    
    this.saturation.curve = curve;
  }
  
  disconnect() {
    this.wow.stop();
    this.input.disconnect();
    this.delay1.disconnect();
    this.delay2.disconnect();
    this.delay3.disconnect();
    this.feedback.disconnect();
    this.wetGain.disconnect();
    this.dryGain.disconnect();
    this.toneFilter.disconnect();
    this.saturation.disconnect();
    this.wow.disconnect();
    this.wowGain.disconnect();
    this.output.disconnect();
  }
}