export default {
  mounted() {
    this.isRecording = {};
    this.mediaRecorders = {};
    this.audioContexts = {};
    this.audioChunks = {};
    this.meters = {};
    this.waveforms = {};
    
    // Initialize audio context
    this.initializeAudioSystem();
    
    // Handle recording events from server
    this.handleEvent("start-recording", (data) => {
      this.startClientRecording(data.track_id, data.quality_settings);
    });
    
    this.handleEvent("stop-recording", (data) => {
      this.stopClientRecording(data.track_id);
    });
    
    this.handleEvent("recording-activity", (data) => {
      this.updateRecordingActivity(data);
    });
    
    this.handleEvent("draft-created", (data) => {
      this.showDraftCreated(data);
    });
    
    this.handleEvent("export-completed", (data) => {
      this.showExportSuccess(data);
    });
  },
  
  async initializeAudioSystem() {
    try {
      // Check for optimal recording settings based on connection
      const settings = await this.getOptimalRecordingSettings();
      this.recordingSettings = settings;
      
      // Request microphone permission
      this.stream = await navigator.mediaDevices.getUserMedia({
        audio: {
          sampleRate: settings.sampleRate,
          channelCount: settings.channels,
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: false
        }
      });
      
      console.log("Audio system initialized", settings);
    } catch (error) {
      console.error("Failed to initialize audio:", error);
      this.pushEvent("audio-permission-denied", {error: error.message});
    }
  },
  
  async getOptimalRecordingSettings() {
    const connection = navigator.connection || navigator.mozConnection;
    
    // Detect device capabilities
    const isMobile = /Android|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
    const battery = await navigator.getBattery?.() || {level: 1};
    
    if (isobile && battery.level < 0.2) {
      return {sampleRate: 22050, channels: 1, bitrate: 64, chunkInterval: 2000};
    } else if (connection?.downlink > 10) {
      return {sampleRate: 48000, channels: 2, bitrate: 320, chunkInterval: 500};
    } else if (connection?.downlink > 2) {
      return {sampleRate: 44100, channels: 2, bitrate: 192, chunkInterval: 1000};
    } else {
      return {sampleRate: 22050, channels: 1, bitrate: 96, chunkInterval: 2000};
    }
  },
  
  async startClientRecording(trackId, qualitySettings) {
    if (this.isRecording[trackId] || !this.stream) return;
    
    try {
      // Create audio context for this track
      const audioContext = new AudioContext({
        sampleRate: qualitySettings.sample_rate || 44100
      });
      this.audioContexts[trackId] = audioContext;
      
      // Set up audio analysis
      const source = audioContext.createMediaStreamSource(this.stream);
      const analyser = audioContext.createAnalyser();
      analyser.fftSize = 2048;
      source.connect(analyser);
      
      // Set up level meter
      this.setupLevelMeter(trackId, analyser);
      
      // Set up waveform visualization
      this.setupWaveform(trackId, analyser);
      
      // Create MediaRecorder for this track
      const mimeType = this.getSupportedMimeType();
      const mediaRecorder = new MediaRecorder(this.stream, {
        mimeType: mimeType,
        audioBitsPerSecond: qualitySettings.bit_depth * qualitySettings.sample_rate * qualitySettings.channels
      });
      
      this.mediaRecorders[trackId] = mediaRecorder;
      this.audioChunks[trackId] = [];
      
      // Handle data available
      mediaRecorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          this.audioChunks[trackId].push(event.data);
          
          // Convert to base64 and send to server
          const reader = new FileReader();
          reader.onload = () => {
            const base64Audio = reader.result.split(',')[1];
            this.pushEvent("audio_chunk", {
              track_id: trackId,
              audio_data: base64Audio,
              timestamp: Date.now()
            });
          };
          reader.readAsDataURL(event.data);
        }
      };
      
      // Start recording with chunked intervals for real-time streaming
      mediaRecorder.start(this.recordingSettings.chunkInterval);
      this.isRecording[trackId] = true;
      
      console.log(`Started recording track ${trackId}`);
      
    } catch (error) {
      console.error(`Failed to start recording track ${trackId}:`, error);
      this.pushEvent("recording-error", {track_id: trackId, error: error.message});
    }
  },
  
  stopClientRecording(trackId) {
    if (!this.isRecording[trackId]) return;
    
    const mediaRecorder = this.mediaRecorders[trackId];
    if (mediaRecorder && mediaRecorder.state === 'recording') {
      mediaRecorder.stop();
    }
    
    // Clean up audio context
    if (this.audioContexts[trackId]) {
      this.audioContexts[trackId].close();
      delete this.audioContexts[trackId];
    }
    
    // Stop visualizations
    if (this.meters[trackId]) {
      cancelAnimationFrame(this.meters[trackId].animationId);
      delete this.meters[trackId];
    }
    
    if (this.waveforms[trackId]) {
      cancelAnimationFrame(this.waveforms[trackId].animationId);
      delete this.waveforms[trackId];
    }
    
    this.isRecording[trackId] = false;
    delete this.mediaRecorders[trackId];
    delete this.audioChunks[trackId];
    
    console.log(`Stopped recording track ${trackId}`);
  },
  
  setupLevelMeter(trackId, analyser) {
    const meterElement = document.querySelector(`[data-track-meter="${trackId}"]`);
    if (!meterElement) return;
    
    const bufferLength = analyser.frequencyBinCount;
    const dataArray = new Uint8Array(bufferLength);
    
    const updateMeter = () => {
      if (!this.isRecording[trackId]) return;
      
      analyser.getByteFrequencyData(dataArray);
      
      // Calculate RMS level
      let sum = 0;
      for (let i = 0; i < bufferLength; i++) {
        sum += dataArray[i] * dataArray[i];
      }
      const rms = Math.sqrt(sum / bufferLength);
      const level = (rms / 255) * 100;
      
      // Update meter display
      meterElement.style.width = `${level}%`;
      
      // Color coding for levels
      if (level > 80) {
        meterElement.className = meterElement.className.replace(/bg-\w+-\d+/, 'bg-red-500');
      } else if (level > 60) {
        meterElement.className = meterElement.className.replace(/bg-\w+-\d+/, 'bg-yellow-500');
      } else {
        meterElement.className = meterElement.className.replace(/bg-\w+-\d+/, 'bg-green-500');
      }
      
      this.meters[trackId] = {animationId: requestAnimationFrame(updateMeter)};
    };
    
    updateMeter();
  },
  
  setupWaveform(trackId, analyser) {
    const canvas = document.querySelector(`[data-waveform="${trackId}"]`);
    if (!canvas) return;
    
    const ctx = canvas.getContext('2d');
    const bufferLength = analyser.frequencyBinCount;
    const dataArray = new Uint8Array(bufferLength);
    
    // Set canvas size
    canvas.width = canvas.offsetWidth;
    canvas.height = canvas.offsetHeight;
    
    let waveformData = [];
    const maxDataPoints = canvas.width;
    
    const drawWaveform = () => {
      if (!this.isRecording[trackId]) return;
      
      analyser.getByteTimeDomainData(dataArray);
      
      // Calculate average amplitude for this frame
      let sum = 0;
      for (let i = 0; i < bufferLength; i++) {
        sum += Math.abs(dataArray[i] - 128);
      }
      const avgAmplitude = sum / bufferLength;
      
      // Add to waveform data
      waveformData.push(avgAmplitude);
      if (waveformData.length > maxDataPoints) {
        waveformData.shift();
      }
      
      // Clear canvas
      ctx.fillStyle = '#1f2937'; // gray-900
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      
      // Draw waveform
      ctx.strokeStyle = '#3b82f6'; // blue-500
      ctx.lineWidth = 2;
      ctx.beginPath();
      
      const sliceWidth = canvas.width / waveformData.length;
      let x = 0;
      
      waveformData.forEach((amplitude, i) => {
        const y = (amplitude / 128) * canvas.height;
        
        if (i === 0) {
          ctx.moveTo(x, canvas.height / 2 - y / 2);
        } else {
          ctx.lineTo(x, canvas.height / 2 - y / 2);
        }
        
        x += sliceWidth;
      });
      
      ctx.stroke();
      
      this.waveforms[trackId] = {animationId: requestAnimationFrame(drawWaveform)};
    };
    
    drawWaveform();
  },
  
  getSupportedMimeType() {
    const types = [
      'audio/webm;codecs=opus',
      'audio/webm',
      'audio/mp4',
      'audio/wav'
    ];
    
    for (const type of types) {
      if (MediaRecorder.isTypeSupported(type)) {
        return type;
      }
    }
    
    return '';
  },
  
  updateRecordingActivity(data) {
    // Visual feedback for incoming audio chunks from other users
    const trackElement = document.querySelector(`[data-track-id="${data.track_id}"]`);
    if (trackElement && data.user_id !== this.getCurrentUserId()) {
      trackElement.classList.add('border-blue-400');
      setTimeout(() => trackElement.classList.remove('border-blue-400'), 200);
    }
  },
  
  showDraftCreated(data) {
    // Add draft to the UI
    const draftList = document.getElementById('draft-list');
    const draftElement = document.createElement('div');
    draftElement.className = 'flex items-center justify-between p-3 bg-gray-800 rounded';
    draftElement.innerHTML = `
      <div>
        <h5 class="text-white font-medium">${data.title}</h5>
        <p class="text-gray-400 text-sm">Expires: ${new Date(data.expires_at).toLocaleDateString()}</p>
      </div>
      <button onclick="openExportModal('${data.draft_id}')" 
              class="bg-blue-600 hover:bg-blue-700 text-white px-3 py-1 rounded text-sm">
        Export
      </button>
    `;
    draftList.appendChild(draftElement);
  },
  
  showExportSuccess(data) {
    // Show success notification
    console.log('Export completed:', data);
    
    // Close export modal if open
    document.getElementById('export-modal').classList.add('hidden');
  },
  
  getCurrentUserId() {
    // Get current user ID from the page
    return document.querySelector('[data-user-id]')?.dataset.userId;
  },
  
  destroyed() {
    // Clean up all recording resources
    Object.keys(this.isRecording).forEach(trackId => {
      this.stopClientRecording(trackId);
    });
    
    if (this.stream) {
      this.stream.getTracks().forEach(track => track.stop());
    }
  }
};

// Global functions for modal management
window.openExportModal = function(draftId) {
  document.getElementById('export-draft-id').value = draftId;
  document.getElementById('export-modal').classList.remove('hidden');
};

window.closeExportModal = function() {
  document.getElementById('export-modal').classList.add('hidden');
};