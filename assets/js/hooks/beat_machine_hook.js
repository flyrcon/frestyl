// assets/js/hooks/beat_machine_hook.js

export const BeatMachineHook = {
  mounted() {
    this.audioContext = null;
    this.sampleBuffers = new Map();
    this.gainNode = null;
    
    // Initialize Web Audio API
    this.initializeAudio();
    
    // Load initial kit samples
    this.loadKit("classic_808");
    
    // Handle beat machine events from the server
    this.handleEvent("beat_pattern_created", (data) => {
      console.log("Pattern created:", data.pattern);
      this.updatePatternList();
    });
    
    this.handleEvent("beat_step_triggered", (data) => {
      this.playTriggeredInstruments(data.step, data.instruments);
    });
    
    this.handleEvent("beat_pattern_started", (data) => {
      this.onPatternStarted(data.pattern_id);
    });
    
    this.handleEvent("beat_pattern_stopped", () => {
      this.onPatternStopped();
    });
    
    this.handleEvent("beat_kit_changed", (data) => {
      this.loadKit(data.kit_name);
    });
    
    this.handleEvent("beat_step_updated", (data) => {
      this.updateStepVisual(data.pattern_id, data.instrument, data.step, data.velocity);
    });
    
    // Setup UI event listeners
    this.setupUIEventListeners();
  },
  
  destroyed() {
    if (this.audioContext) {
      this.audioContext.close();
    }
  },
  
  async initializeAudio() {
    try {
      this.audioContext = new (window.AudioContext || window.webkitAudioContext)();
      this.gainNode = this.audioContext.createGain();
      this.gainNode.connect(this.audioContext.destination);
      this.gainNode.gain.value = 0.8; // Default master volume
      
      console.log("Beat Machine audio initialized");
    } catch (error) {
      console.error("Failed to initialize audio:", error);
    }
  },
  
  async loadKit(kitName) {
    if (!this.audioContext) return;
    
    console.log(`Loading kit: ${kitName}`);
    
    // Kit configurations (matching your Elixir backend)
    const kitConfigs = {
      "classic_808": {
        "kick": "/audio/samples/classic_808/808_kick.wav",
        "snare": "/audio/samples/classic_808/808_snare.wav",
        "hihat": "/audio/samples/classic_808/808_hihat.wav",
        "openhat": "/audio/samples/classic_808/808_openhat.wav",
        "clap": "/audio/samples/classic_808/808_clap.wav",
        "crash": "/audio/samples/classic_808/808_crash.wav",
        "perc1": "/audio/samples/classic_808/808_perc1.wav",
        "perc2": "/audio/samples/classic_808/808_perc2.wav"
      },
      "acoustic": {
        "kick": "/audio/samples/acoustic/acoustic_kick.wav",
        "snare": "/audio/samples/acoustic/acoustic_snare.wav",
        "hihat": "/audio/samples/acoustic/acoustic_hihat.wav",
        "openhat": "/audio/samples/acoustic/acoustic_openhat.wav",
        "ride": "/audio/samples/acoustic/acoustic_ride.wav",
        "crash": "/audio/samples/acoustic/acoustic_crash.wav",
        "tom1": "/audio/samples/acoustic/acoustic_tom1.wav",
        "tom2": "/audio/samples/acoustic/acoustic_tom2.wav"
      },
      "trap": {
        "kick": "/audio/samples/trap/trap_kick.wav",
        "snare": "/audio/samples/trap/trap_snare.wav",
        "hihat": "/audio/samples/trap/trap_hihat.wav",
        "openhat": "/audio/samples/trap/trap_openhat.wav",
        "clap": "/audio/samples/trap/trap_clap.wav",
        "shaker": "/audio/samples/trap/trap_shaker.wav",
        "perc1": "/audio/samples/trap/trap_perc1.wav",
        "perc2": "/audio/samples/trap/trap_perc2.wav"
      }
    };
    
    const kitConfig = kitConfigs[kitName];
    if (!kitConfig) {
      console.error(`Unknown kit: ${kitName}`);
      return;
    }
    
    // Clear existing samples
    this.sampleBuffers.clear();
    
    // Load each sample
    for (const [instrument, url] of Object.entries(kitConfig)) {
      try {
        const buffer = await this.loadSample(url);
        this.sampleBuffers.set(instrument, buffer);
        console.log(`Loaded sample: ${instrument}`);
      } catch (error) {
        console.warn(`Failed to load sample ${instrument}:`, error);
        // Create a silent buffer as fallback
        this.sampleBuffers.set(instrument, this.createSilentBuffer());
      }
    }
    
    console.log(`Kit ${kitName} loaded with ${this.sampleBuffers.size} samples`);
  },
  
  async loadSample(url) {
    const response = await fetch(url);
    const arrayBuffer = await response.arrayBuffer();
    return await this.audioContext.decodeAudioData(arrayBuffer);
  },
  
  createSilentBuffer() {
    const buffer = this.audioContext.createBuffer(2, this.audioContext.sampleRate * 0.1, this.audioContext.sampleRate);
    return buffer;
  },
  
  playTriggeredInstruments(step, instruments) {
    if (!this.audioContext || !instruments) return;
    
    // Resume audio context if suspended (required by browsers)
    if (this.audioContext.state === 'suspended') {
      this.audioContext.resume();
    }
    
    instruments.forEach(([instrument, velocity]) => {
      this.playSample(instrument, velocity / 127); // Convert MIDI velocity to gain
    });
    
    // Update visual step indicator
    this.highlightCurrentStep(step);
  },
  
  playSample(instrument, gain = 1.0) {
    const buffer = this.sampleBuffers.get(instrument);
    if (!buffer) {
      console.warn(`No sample buffer for instrument: ${instrument}`);
      return;
    }
    
    const source = this.audioContext.createBufferSource();
    const gainNode = this.audioContext.createGain();
    
    source.buffer = buffer;
    gainNode.gain.value = gain;
    
    source.connect(gainNode);
    gainNode.connect(this.gainNode);
    
    source.start();
  },
  
  setupUIEventListeners() {
    // Pattern creation
    this.el.addEventListener("click", (e) => {
      if (e.target.dataset.action === "create-pattern") {
        const name = prompt("Pattern name:");
        if (name) {
          this.pushEvent("beat_create_pattern", { name, steps: "16" });
        }
      }
      
      // Step programming
      if (e.target.dataset.action === "toggle-step") {
        const patternId = e.target.dataset.patternId;
        const instrument = e.target.dataset.instrument;
        const step = parseInt(e.target.dataset.step);
        const currentVelocity = parseInt(e.target.dataset.velocity || "0");
        const newVelocity = currentVelocity > 0 ? 0 : 100; // Toggle on/off
        
        this.pushEvent("beat_update_step", {
          pattern_id: patternId,
          instrument: instrument,
          step: step.toString(),
          velocity: newVelocity.toString()
        });
      }
      
      // Pattern controls
      if (e.target.dataset.action === "play-pattern") {
        const patternId = e.target.dataset.patternId;
        this.pushEvent("beat_play_pattern", { pattern_id: patternId });
      }
      
      if (e.target.dataset.action === "stop-pattern") {
        this.pushEvent("beat_stop_pattern", {});
      }
      
      // Kit selection
      if (e.target.dataset.action === "change-kit") {
        const kitName = e.target.dataset.kitName;
        this.pushEvent("beat_change_kit", { kit_name: kitName });
      }
    });
    
    // Slider controls
    this.el.addEventListener("input", (e) => {
      if (e.target.dataset.action === "set-bpm") {
        this.pushEvent("beat_set_bpm", { bpm: e.target.value });
      }
      
      if (e.target.dataset.action === "set-swing") {
        this.pushEvent("beat_set_swing", { swing: e.target.value });
      }
      
      if (e.target.dataset.action === "set-master-volume") {
        const volume = parseFloat(e.target.value);
        this.gainNode.gain.value = volume;
        this.pushEvent("beat_set_master_volume", { volume: volume.toString() });
      }
    });
  },
  
  updateStepVisual(patternId, instrument, step, velocity) {
    const stepElement = this.el.querySelector(
      `[data-pattern-id="${patternId}"][data-instrument="${instrument}"][data-step="${step}"]`
    );
    
    if (stepElement) {
      stepElement.dataset.velocity = velocity;
      stepElement.classList.toggle("active", velocity > 0);
      
      // Update visual intensity based on velocity
      if (velocity > 0) {
        stepElement.style.opacity = Math.max(0.3, velocity / 127);
      } else {
        stepElement.style.opacity = 0.1;
      }
    }
  },
  
  highlightCurrentStep(step) {
    // Remove previous highlights
    this.el.querySelectorAll(".current-step").forEach(el => {
      el.classList.remove("current-step");
    });
    
    // Add highlight to current step
    this.el.querySelectorAll(`[data-step="${step}"]`).forEach(el => {
      el.classList.add("current-step");
    });
  },
  
  onPatternStarted(patternId) {
    console.log(`Pattern started: ${patternId}`);
    const playButton = this.el.querySelector(`[data-pattern-id="${patternId}"][data-action="play-pattern"]`);
    if (playButton) {
      playButton.textContent = "Stop";
      playButton.dataset.action = "stop-pattern";
      playButton.classList.add("playing");
    }
  },
  
  onPatternStopped() {
    console.log("Pattern stopped");
    this.el.querySelectorAll("[data-action='stop-pattern']").forEach(button => {
      button.textContent = "Play";
      button.dataset.action = "play-pattern";
      button.classList.remove("playing");
    });
    
    // Clear step highlights
    this.el.querySelectorAll(".current-step").forEach(el => {
      el.classList.remove("current-step");
    });
  },
  
  updatePatternList() {
    // Trigger a re-render or update of the pattern list
    // This depends on how your UI is structured
    console.log("Pattern list should be updated");
  }
};