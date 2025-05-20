// Stream Quality Hook - manages WebRTC quality settings
const StreamQuality = {
  mounted() {
    this.peerConnection = null;
    this.currentQuality = "auto";
    
    this.handleEvent("set-stream-quality", ({ quality }) => {
      this.setQuality(quality);
    });

    this.handleEvent("set-audio-only", ({ enabled }) => {
      this.setAudioOnly(enabled);
    });
  },

  setPeerConnection(peerConnection) {
    this.peerConnection = peerConnection;
    this.startStatsMonitoring();
  },

  setQuality(quality) {
    if (!this.peerConnection) return;

    this.currentQuality = quality;
    
    const sender = this.peerConnection.getSenders().find(s => 
      s.track && s.track.kind === 'video'
    );

    if (!sender) return;

    const params = sender.getParameters();
    if (!params.encodings || params.encodings.length === 0) return;

    // Set encoding parameters based on quality
    const encoding = params.encodings[0];
    
    switch (quality) {
      case "low":
        encoding.maxBitrate = 200000; // 200 kbps
        encoding.scaleResolutionDownBy = 4;
        break;
      case "medium":
        encoding.maxBitrate = 500000; // 500 kbps
        encoding.scaleResolutionDownBy = 2;
        break;
      case "high":
        encoding.maxBitrate = 1000000; // 1 Mbps
        encoding.scaleResolutionDownBy = 1.5;
        break;
      case "hd":
        encoding.maxBitrate = 2000000; // 2 Mbps
        encoding.scaleResolutionDownBy = 1;
        break;
      case "ultra":
        encoding.maxBitrate = 4000000; // 4 Mbps
        encoding.scaleResolutionDownBy = 1;
        break;
      case "auto":
      default:
        // Remove constraints for auto mode
        delete encoding.maxBitrate;
        delete encoding.scaleResolutionDownBy;
        break;
    }

    sender.setParameters(params);
  },

  setAudioOnly(enabled) {
    if (!this.peerConnection) return;

    const videoSender = this.peerConnection.getSenders().find(s => 
      s.track && s.track.kind === 'video'
    );

    if (videoSender && videoSender.track) {
      videoSender.track.enabled = !enabled;
    }

    // Hide/show video element
    const videoElement = document.getElementById("broadcast-video");
    if (videoElement) {
      videoElement.style.display = enabled ? "none" : "block";
    }
  },

  startStatsMonitoring() {
    if (!this.peerConnection) return;

    const getStats = () => {
      this.peerConnection.getStats().then(stats => {
        let upload = 0;
        let download = 0;
        let latency = 0;
        let packetLoss = 0;

        stats.forEach(report => {
          if (report.type === 'outbound-rtp' && report.kind === 'video') {
            upload = Math.round((report.bytesSent * 8) / report.timestamp * 1000) || 0;
          } else if (report.type === 'inbound-rtp' && report.kind === 'video') {
            download = Math.round((report.bytesReceived * 8) / report.timestamp * 1000) || 0;
          } else if (report.type === 'candidate-pair' && report.state === 'succeeded') {
            latency = report.currentRoundTripTime ? Math.round(report.currentRoundTripTime * 1000) : 0;
          } else if (report.type === 'transport') {
            const lost = report.packetsLost || 0;
            const sent = report.packetsSent || 1;
            packetLoss = Math.round((lost / sent) * 100) || 0;
          }
        });

        this.pushEvent("update_bandwidth_stats", {
          stats: {
            upload: upload,
            download: download,
            latency: latency,
            packet_loss: packetLoss
          }
        });
      });
    };

    // Update stats every 5 seconds
    this.statsInterval = setInterval(getStats, 5000);
  },

  destroyed() {
    if (this.statsInterval) {
      clearInterval(this.statsInterval);
    }
  }
};

// Sound Check Hook - manages audio/video testing before joining
const SoundCheck = {
  mounted() {
    this.localStream = null;
    this.audioContext = null;
    this.audioAnalyser = null;
    this.networkTester = null;
    
    this.initializeSoundCheck();
  },

  async initializeSoundCheck() {
    try {
      // Request media permissions
      this.localStream = await navigator.mediaDevices.getUserMedia({ 
        video: true, 
        audio: true 
      });
      
      // Setup video preview
      const videoElement = document.getElementById("video-preview");
      if (videoElement) {
        videoElement.srcObject = this.localStream;
      }

      // Setup audio level monitoring
      this.setupAudioMonitoring();
      
      // Test network quality
      this.testNetworkQuality();

      // Notify that devices are connected
      this.pushEvent("microphone_connected", { connected: true });
      this.pushEvent("speaker_connected", { connected: true });

    } catch (error) {
      console.error("Error accessing media devices:", error);
      this.pushEvent("microphone_connected", { connected: false });
      this.pushEvent("speaker_connected", { connected: false });
    }
  },

  setupAudioMonitoring() {
    if (!this.localStream) return;

    this.audioContext = new (window.AudioContext || window.webkitAudioContext)();
    this.audioAnalyser = this.audioContext.createAnalyser();
    
    const source = this.audioContext.createMediaStreamSource(this.localStream);
    source.connect(this.audioAnalyser);
    
    this.audioAnalyser.fftSize = 256;
    const bufferLength = this.audioAnalyser.frequencyBinCount;
    const dataArray = new Uint8Array(bufferLength);

    const getMicrophoneLevel = () => {
      this.audioAnalyser.getByteFrequencyData(dataArray);
      
      let sum = 0;
      for (let i = 0; i < bufferLength; i++) {
        sum += dataArray[i];
      }
      
      const average = sum / bufferLength;
      const level = Math.round((average / 255) * 100);
      
      this.pushEvent("microphone_level", { level: level });
      
      if (this.localStream) {
        requestAnimationFrame(getMicrophoneLevel);
      }
    };

    getMicrophoneLevel();
  },

  async testNetworkQuality() {
    try {
      // Simple network speed test using a small image
      const startTime = Date.now();
      const testUrl = '/api/placeholder/100/100?' + Math.random(); // Cache buster
      
      const response = await fetch(testUrl);
      const data = await response.arrayBuffer();
      const endTime = Date.now();
      
      const duration = endTime - startTime;
      const bitsPerSecond = (data.byteLength * 8) / (duration / 1000);
      
      let quality;
      if (bitsPerSecond > 1000000) { // > 1 Mbps
        quality = "good";
      } else if (bitsPerSecond > 500000) { // > 500 Kbps
        quality = "fair";
      } else {
        quality = "poor";
      }
      
      this.pushEvent("network_quality", { quality: quality });
    } catch (error) {
      console.error("Network test failed:", error);
      this.pushEvent("network_quality", { quality: "poor" });
    }
  },

  destroyed() {
    if (this.localStream) {
      this.localStream.getTracks().forEach(track => track.stop());
    }
    if (this.audioContext) {
      this.audioContext.close();
    }
  }
};

// Waiting Room Hook - manages countdown timer and interactive features
const WaitingRoom = {
  mounted() {
    this.countdownInterval = null;
    this.startCountdown();
  },

  startCountdown() {
    const updateCountdown = () => {
      // The countdown logic is handled on the server side
      // This hook can handle client-side interactions
    };

    this.countdownInterval = setInterval(updateCountdown, 1000);
  },

  destroyed() {
    if (this.countdownInterval) {
      clearInterval(this.countdownInterval);
    }
  }
};

// Broadcast Controls Hook - manages host controls during live broadcast
const BroadcastControls = {
  mounted() {
    this.streamStarted = false;
    this.isRecording = false;
    
    // Listen for stream events
    this.handleEvent("stream-started", () => {
      this.streamStarted = true;
      this.updateControlsState();
    });

    this.handleEvent("stream-ended", () => {
      this.streamStarted = false;
      this.updateControlsState();
    });
  },

  updateControlsState() {
    // Update UI based on stream state
    const startButton = document.querySelector("[phx-click='start_stream']");
    const endButton = document.querySelector("[phx-click='end_stream']");
    
    if (startButton) {
      startButton.style.display = this.streamStarted ? "none" : "block";
    }
    
    if (endButton) {
      endButton.style.display = this.streamStarted ? "block" : "none";
    }
  }
};

// Export hooks object for use in app.js
export default {
  StreamQuality,
  SoundCheck, 
  WaitingRoom,
  BroadcastControls
};