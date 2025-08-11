// assets/js/hooks/voice_recorder.js
// Voice recording with transcription and mobile optimization

const VoiceRecorder = {
  mounted() {
    this.isRecording = false;
    this.mediaRecorder = null;
    this.audioChunks = [];
    this.audioContext = null;
    this.stream = null;
    this.startTime = null;
    this.timerInterval = null;
    
    // Mobile detection
    this.isMobile = /iPhone|iPad|iPod|Android/i.test(navigator.userAgent);
    
    // Initialize audio context
    this.initializeAudio();
    
    // Event listeners
    this.handleEvent("start_voice_recording", (payload) => {
      this.startRecording(payload);
    });

    this.handleEvent("stop_voice_recording", () => {
      this.stopRecording();
    });
  },

  async initializeAudio() {
    try {
      // Request microphone permission
      this.stream = await navigator.mediaDevices.getUserMedia({ 
        audio: {
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
          sampleRate: 44100
        } 
      });

      // Create audio context for visualization
      this.audioContext = new (window.AudioContext || window.webkitAudioContext)();
      this.analyser = this.audioContext.createAnalyser();
      this.microphone = this.audioContext.createMediaStreamSource(this.stream);
      this.microphone.connect(this.analyser);
      
      this.analyser.fftSize = 256;
      this.bufferLength = this.analyser.frequencyBinCount;
      this.dataArray = new Uint8Array(this.bufferLength);

      console.log("Audio initialized successfully");
      
    } catch (error) {
      console.error("Error accessing microphone:", error);
      this.pushEvent("audio_permission_denied", { error: error.message });
    }
  },

  async startRecording(payload = {}) {
    if (this.isRecording || !this.stream) return;

    try {
      // Reset audio chunks
      this.audioChunks = [];
      
      // Configure MediaRecorder based on device
      const options = this.getRecorderOptions();
      this.mediaRecorder = new MediaRecorder(this.stream, options);
      
      // Set up event handlers
      this.mediaRecorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          this.audioChunks.push(event.data);
        }
      };

      this.mediaRecorder.onstop = () => {
        this.handleRecordingComplete();
      };

      this.mediaRecorder.onerror = (event) => {
        console.error("MediaRecorder error:", event.error);
        this.pushEvent("recording_error", { error: event.error.message });
      };

      // Start recording
      this.mediaRecorder.start(100); // Collect data every 100ms
      this.isRecording = true;
      this.startTime = Date.now();
      
      // Start timer
      this.startTimer();
      
      // Start audio visualization
      this.startVisualization();
      
      // Store recording context
      this.recordingContext = payload;
      
      console.log("Recording started");
      this.pushEvent("recording_started", { timestamp: this.startTime });
      
    } catch (error) {
      console.error("Error starting recording:", error);
      this.pushEvent("recording_error", { error: error.message });
    }
  },

  stopRecording() {
    if (!this.isRecording || !this.mediaRecorder) return;

    try {
      this.mediaRecorder.stop();
      this.isRecording = false;
      
      // Stop timer
      this.stopTimer();
      
      // Stop visualization
      this.stopVisualization();
      
      console.log("Recording stopped");
      
    } catch (error) {
      console.error("Error stopping recording:", error);
      this.pushEvent("recording_error", { error: error.message });
    }
  },

  getRecorderOptions() {
    // Optimize for mobile devices
    if (this.isMobile) {
      return {
        mimeType: 'audio/webm;codecs=opus',
        audioBitsPerSecond: 64000 // Lower bitrate for mobile
      };
    } else {
      // Desktop options
      const mimeTypes = [
        'audio/webm;codecs=opus',
        'audio/mp4;codecs=mp4a.40.2',
        'audio/ogg;codecs=opus',
        'audio/wav'
      ];
      
      for (let mimeType of mimeTypes) {
        if (MediaRecorder.isTypeSupported(mimeType)) {
          return {
            mimeType: mimeType,
            audioBitsPerSecond: 128000
          };
        }
      }
      
      return {}; // Use default
    }
  },

  async handleRecordingComplete() {
    if (this.audioChunks.length === 0) {
      console.error("No audio data recorded");
      return;
    }

    try {
      // Create blob from audio chunks
      const audioBlob = new Blob(this.audioChunks, { 
        type: this.mediaRecorder.mimeType 
      });
      
      // Calculate duration
      const duration = (Date.now() - this.startTime) / 1000;
      
      // Convert to base64 for transmission
      const audioData = await this.blobToBase64(audioBlob);
      
      // Create voice note data
      const voiceNoteData = {
        audio_data: audioData,
        duration: duration,
        mime_type: this.mediaRecorder.mimeType,
        file_size: audioBlob.size,
        timestamp: this.startTime,
        context: this.recordingContext || {}
      };

      // Send to server for processing
      this.pushEvent("voice_note_recorded", voiceNoteData);
      
      // Store locally for offline support (mobile)
      if (this.isMobile) {
        this.storeOfflineVoiceNote(voiceNoteData);
      }
      
      console.log(`Recording complete: ${duration.toFixed(1)}s, ${audioBlob.size} bytes`);
      
    } catch (error) {
      console.error("Error processing recording:", error);
      this.pushEvent("recording_error", { error: error.message });
    }
  },

  startTimer() {
    const timerElement = document.getElementById('recording-timer');
    if (!timerElement) return;

    this.timerInterval = setInterval(() => {
      const elapsed = (Date.now() - this.startTime) / 1000;
      const minutes = Math.floor(elapsed / 60);
      const seconds = Math.floor(elapsed % 60);
      timerElement.textContent = `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
    }, 1000);
  },

  stopTimer() {
    if (this.timerInterval) {
      clearInterval(this.timerInterval);
      this.timerInterval = null;
    }
  },

  startVisualization() {
    if (!this.analyser) return;

    const visualizeAudio = () => {
      if (!this.isRecording) return;

      this.analyser.getByteFrequencyData(this.dataArray);
      
      // Calculate average volume
      let sum = 0;
      for (let i = 0; i < this.bufferLength; i++) {
        sum += this.dataArray[i];
      }
      const average = sum / this.bufferLength;
      const normalizedLevel = average / 255;
      
      // Update UI elements
      this.updateVolumeIndicator(normalizedLevel);
      
      // Continue animation
      requestAnimationFrame(visualizeAudio);
    };

    visualizeAudio();
  },

  stopVisualization() {
    // Reset volume indicators
    this.updateVolumeIndicator(0);
  },

  updateVolumeIndicator(level) {
    // Update volume visualization in UI
    const volumeIndicators = document.querySelectorAll('.volume-indicator');
    volumeIndicators.forEach(indicator => {
      indicator.style.transform = `scaleY(${level})`;
    });

    // Update recording button pulse intensity
    const recordButton = document.querySelector('[phx-hook="VoiceRecorder"]');
    if (recordButton && this.isRecording) {
      recordButton.style.opacity = 0.7 + (level * 0.3);
    }
  },

  async blobToBase64(blob) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => {
        const base64 = reader.result.split(',')[1]; // Remove data:mime;base64, prefix
        resolve(base64);
      };
      reader.onerror = reject;
      reader.readAsDataURL(blob);
    });
  },

  // Mobile offline support
  storeOfflineVoiceNote(voiceNoteData) {
    try {
      const offlineNotes = this.getOfflineVoiceNotes();
      offlineNotes.push({
        ...voiceNoteData,
        id: this.generateId(),
        stored_at: Date.now(),
        synced: false
      });
      
      localStorage.setItem('frestyl_offline_voice_notes', JSON.stringify(offlineNotes));
      
      // Notify about offline storage
      this.pushEvent("voice_note_stored_offline", { 
        count: offlineNotes.filter(note => !note.synced).length 
      });
      
    } catch (error) {
      console.error("Error storing offline voice note:", error);
    }
  },

  getOfflineVoiceNotes() {
    try {
      const stored = localStorage.getItem('frestyl_offline_voice_notes');
      return stored ? JSON.parse(stored) : [];
    } catch (error) {
      console.error("Error retrieving offline voice notes:", error);
      return [];
    }
  },

  syncOfflineVoiceNotes() {
    const offlineNotes = this.getOfflineVoiceNotes();
    const unsyncedNotes = offlineNotes.filter(note => !note.synced);
    
    if (unsyncedNotes.length === 0) return;

    // Send each unsynced note
    unsyncedNotes.forEach(note => {
      this.pushEvent("sync_offline_voice_note", {
        offline_id: note.id,
        voice_note_data: note
      });
    });
  },

  markOfflineNoteSynced(offlineId) {
    const offlineNotes = this.getOfflineVoiceNotes();
    const updatedNotes = offlineNotes.map(note => 
      note.id === offlineId ? { ...note, synced: true } : note
    );
    
    localStorage.setItem('frestyl_offline_voice_notes', JSON.stringify(updatedNotes));
  },

  // Voice command integration
  startVoiceCommandRecognition() {
    if (!('webkitSpeechRecognition' in window) && !('SpeechRecognition' in window)) {
      console.error("Speech recognition not supported");
      return;
    }

    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
    this.recognition = new SpeechRecognition();
    
    this.recognition.continuous = true;
    this.recognition.interimResults = true;
    this.recognition.lang = 'en-US';

    this.recognition.onresult = (event) => {
      let finalTranscript = '';
      let interimTranscript = '';

      for (let i = event.resultIndex; i < event.results.length; i++) {
        const transcript = event.results[i][0].transcript;
        if (event.results[i].isFinal) {
          finalTranscript += transcript;
        } else {
          interimTranscript += transcript;
        }
      }

      if (finalTranscript) {
        this.processVoiceCommand(finalTranscript.trim());
      }
    };

    this.recognition.onerror = (event) => {
      console.error("Speech recognition error:", event.error);
    };

    this.recognition.start();
  },

  stopVoiceCommandRecognition() {
    if (this.recognition) {
      this.recognition.stop();
      this.recognition = null;
    }
  },

  processVoiceCommand(command) {
    const lowerCommand = command.toLowerCase();
    
    // Basic voice commands
    if (lowerCommand.includes('add section') || lowerCommand.includes('new section')) {
      this.pushEvent("voice_command", { command: "add_section", text: command });
    } else if (lowerCommand.includes('save story') || lowerCommand.includes('save document')) {
      this.pushEvent("voice_command", { command: "save_story", text: command });
    } else if (lowerCommand.includes('add character')) {
      this.pushEvent("voice_command", { command: "add_character", text: command });
    } else {
      // Send as general text input
      this.pushEvent("voice_command", { command: "text_input", text: command });
    }
  },

  generateId() {
    return Date.now().toString(36) + Math.random().toString(36).substr(2, 9);
  },

  destroyed() {
    // Clean up resources
    if (this.isRecording) {
      this.stopRecording();
    }
    
    if (this.stream) {
      this.stream.getTracks().forEach(track => track.stop());
    }
    
    if (this.audioContext) {
      this.audioContext.close();
    }
    
    if (this.recognition) {
      this.stopVoiceCommandRecognition();
    }
    
    this.stopTimer();
  }
};

export default VoiceRecorder;