// assets/js/hooks/video_capture.js
// Enhanced VideoCapture Hook with tier-based quality and upload support

const VideoCapture = {
  mounted() {
    this.componentId = this.el.dataset.componentId;
    this.mediaRecorder = null;
    this.mediaStream = null;
    this.recordedChunks = [];
    this.countdownInterval = null;
    
    console.log("VideoCapture hook mounted for component:", this.componentId);
    
    // Listen for events from LiveView
    this.handleEvent("initialize_camera", this.initializeCamera.bind(this));
    this.handleEvent("start_countdown", this.startCountdown.bind(this));
    this.handleEvent("start_recording", this.startRecording.bind(this));
    this.handleEvent("stop_recording", this.stopRecording.bind(this));
    this.handleEvent("cleanup_recording", this.cleanup.bind(this));
  },

  destroyed() {
    this.cleanup();
  },

  async initializeCamera(data) {
    console.log("Initializing camera...", data);
    
    try {
      // Request camera permission and stream
      this.mediaStream = await navigator.mediaDevices.getUserMedia({
        video: data.constraints || {
          width: { ideal: 1280 },
          height: { ideal: 720 },
          frameRate: { ideal: 30 }
        },
        audio: true
      });

      // Set up video preview
      const video = document.getElementById("camera-preview");
      if (video) {
        video.srcObject = this.mediaStream;
        video.play();
      }

      // Notify component that camera is ready
      this.pushEvent("camera_ready", { stream_active: true });

    } catch (error) {
      console.error("Camera initialization failed:", error);
      
      let errorType = "UnknownError";
      if (error.name) {
        errorType = error.name;
      }

      this.pushEvent("camera_error", {
        error: errorType,
        message: error.message || "Camera access failed"
      });
    }
  },

  startCountdown(data) {
    console.log("Starting countdown...");
    
    let count = 3;
    this.countdownInterval = setInterval(() => {
      this.pushEvent("countdown_update", { count: count });
      count--;
      
      if (count < 0) {
        clearInterval(this.countdownInterval);
        this.countdownInterval = null;
      }
    }, 1000);
  },

  startRecording(data) {
    console.log("Starting recording...");
    
    if (!this.mediaStream) {
      console.error("No media stream available");
      return;
    }

    try {
      // Set up MediaRecorder
      const options = {
        mimeType: 'video/webm;codecs=vp9,opus',
        videoBitsPerSecond: data.quality?.videoBitsPerSecond || 2500000
      };

      this.mediaRecorder = new MediaRecorder(this.mediaStream, options);
      this.recordedChunks = [];

      this.mediaRecorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          this.recordedChunks.push(event.data);
        }
      };

      this.mediaRecorder.onstop = () => {
        this.processRecording();
      };

      this.mediaRecorder.start(1000); // Collect data every second

      // Auto-stop at max duration
      if (data.max_duration) {
        setTimeout(() => {
          if (this.mediaRecorder && this.mediaRecorder.state === "recording") {
            this.stopRecording();
          }
        }, data.max_duration * 1000);
      }

    } catch (error) {
      console.error("Recording start failed:", error);
      this.pushEvent("recording_error", { error: error.message });
    }
  },

    // ============================================================================
  // TIER-BASED QUALITY SETTINGS
  // ============================================================================
  
  getQualitySettings(tier) {
    const settings = {
      free: {
        width: 1280,
        height: 720,
        videoBitsPerSecond: 1000000, // 1 Mbps
        audioBitsPerSecond: 128000,  // 128 Kbps
        maxDuration: 60,
        mimeType: 'video/webm;codecs=vp9'
      },
      pro: {
        width: 1920,
        height: 1080,
        videoBitsPerSecond: 2500000, // 2.5 Mbps
        audioBitsPerSecond: 192000,  // 192 Kbps
        maxDuration: 120,
        mimeType: 'video/webm;codecs=vp9'
      },
      premium: {
        width: 1920,
        height: 1080,
        videoBitsPerSecond: 4000000, // 4 Mbps
        audioBitsPerSecond: 256000,  // 256 Kbps
        maxDuration: 180,
        mimeType: 'video/webm;codecs=vp9'
      }
    };
    
    return settings[tier] || settings.free;
  },

  stopRecording() {
    console.log("Stopping recording...");
    
    if (this.mediaRecorder && this.mediaRecorder.state === "recording") {
      this.mediaRecorder.stop();
    }
  },

  async processRecording() {
    console.log("Processing recording...", this.recordedChunks.length, "chunks");
    
    try {
      // Create blob from recorded chunks
      const blob = new Blob(this.recordedChunks, { type: 'video/webm' });
      
      // Convert blob to base64
      const reader = new FileReader();
      reader.onload = () => {
        const base64Data = reader.result.split(',')[1];
        
        // Set up preview video
        const previewVideo = document.getElementById("preview-video");
        if (previewVideo) {
          previewVideo.src = URL.createObjectURL(blob);
        }

        // Send to LiveView
        this.pushEvent("recording_complete", {
          blob_data: base64Data,
          mime_type: blob.type,
          file_size: blob.size,
          duration: this.getRecordingDuration()
        });
      };
      
      reader.readAsDataURL(blob);

    } catch (error) {
      console.error("Recording processing failed:", error);
      this.pushEvent("recording_error", { error: error.message });
    }
  },

  getRecordingDuration() {
    // Estimate duration based on chunks (rough approximation)
    return Math.floor(this.recordedChunks.length);
  },

  cleanup() {
    console.log("Cleaning up video capture...");
    
    // Clear intervals
    if (this.countdownInterval) {
      clearInterval(this.countdownInterval);
      this.countdownInterval = null;
    }

    // Stop recording
    if (this.mediaRecorder && this.mediaRecorder.state === "recording") {
      this.mediaRecorder.stop();
    }

    // Stop media stream
    if (this.mediaStream) {
      this.mediaStream.getTracks().forEach(track => track.stop());
      this.mediaStream = null;
    }

    // Clear recorded data
    this.recordedChunks = [];
    this.mediaRecorder = null;
  }
};

export default VideoCapture;
