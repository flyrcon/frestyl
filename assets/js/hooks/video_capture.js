// assets/js/hooks/video_capture.js
// PATCH: Fix event names and add retry functionality

window.VideoCapture = {
  mounted() {
    console.log("📹 VideoCapture hook mounted");
    this.componentId = this.el.dataset.componentId;
    this.mediaRecorder = null;
    this.recordedChunks = [];
    this.stream = null;
    this.retryCount = 0;
    this.maxRetries = 3;
    
    // Initialize camera on mount
    this.initializeCamera();
    
    // Listen for recording events
    this.handleEvent("start-recording", (data) => {
      if (data.component_id === this.componentId) {
        this.startRecording();
      }
    });
    
    this.handleEvent("stop-recording", (data) => {
      if (data.component_id === this.componentId) {
        this.stopRecording();
      }
    });

    // FIXED: Listen for retry camera event
    this.handleEvent("retry_camera", () => {
      this.retryCamera();
    });
  },

  async initializeCamera() {
    try {
      console.log("📹 Initializing camera...");
      
      // Request camera access with proper constraints
      const constraints = {
        video: {
          width: { ideal: 1280 },
          height: { ideal: 720 },
          facingMode: "user"
        },
        audio: true
      };
      
      this.stream = await navigator.mediaDevices.getUserMedia(constraints);
      
      // Set video element source
      this.el.srcObject = this.stream;
      await this.el.play();
      
      console.log("✅ Camera initialized successfully");
      
      // FIXED: Send camera_initialized event (matches component expectations)
      this.pushEvent("camera_initialized", {});
      
      // Reset retry count on success
      this.retryCount = 0;
      
    } catch (error) {
      console.error("❌ Camera initialization failed:", error);
      
      let errorMessage = this.getErrorMessage(error);
      
      // FIXED: Send camera_error event with proper error message
      this.pushEvent("camera_error", { error: errorMessage });
    }
  },

  // FIXED: Add retry functionality
  async retryCamera() {
    if (this.retryCount >= this.maxRetries) {
      console.error("❌ Max camera retry attempts reached");
      this.pushEvent("camera_error", { 
        error: "Unable to access camera after multiple attempts. Please check your camera permissions and try refreshing the page." 
      });
      return;
    }

    this.retryCount++;
    console.log(`📹 Retrying camera initialization (attempt ${this.retryCount}/${this.maxRetries})`);
    
    // Clean up existing stream if any
    if (this.stream) {
      this.stream.getTracks().forEach(track => track.stop());
      this.stream = null;
    }
    
    // Wait a bit before retrying
    setTimeout(() => {
      this.initializeCamera();
    }, 1000);
  },

  // FIXED: Better error message handling
  getErrorMessage(error) {
    switch (error.name) {
      case "NotAllowedError":
        return "Camera access denied by user. Please allow camera access and try again.";
      case "NotFoundError":
        return "No camera found on this device.";
      case "NotReadableError":
        return "Camera is being used by another application. Please close other apps using the camera.";
      case "OverconstrainedError":
        return "Camera doesn't support the requested settings.";
      case "SecurityError":
        return "Camera access blocked due to security restrictions.";
      case "AbortError":
        return "Camera access was interrupted.";
      default:
        return `Camera error: ${error.message || "Unknown error"}`;
    }
  },

  startRecording() {
    if (!this.stream) {
      console.error("❌ No stream available for recording");
      this.pushEvent("camera_error", { error: "No camera stream available" });
      return;
    }

    try {
      console.log("🎬 Starting recording...");
      
      this.recordedChunks = [];
      
      // Create MediaRecorder with appropriate options
      const options = {
        mimeType: 'video/webm;codecs=vp9,opus'
      };
      
      // Fallback to vp8 if vp9 is not supported
      if (!MediaRecorder.isTypeSupported(options.mimeType)) {
        options.mimeType = 'video/webm;codecs=vp8,opus';
      }
      
      this.mediaRecorder = new MediaRecorder(this.stream, options);
      
      this.mediaRecorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          this.recordedChunks.push(event.data);
        }
      };
      
      this.mediaRecorder.onstop = () => {
        console.log("⏹️ Recording stopped");
        this.processRecording();
      };
      
      this.mediaRecorder.onerror = (event) => {
        console.error("❌ Recording error:", event.error);
        this.pushEvent("recording_error", { error: event.error.message });
      };
      
      // Start recording
      this.mediaRecorder.start(100); // Collect data every 100ms
      
      // Start duration tracking
      this.recordingStartTime = Date.now();
      this.durationInterval = setInterval(() => {
        if (this.mediaRecorder && this.mediaRecorder.state === 'recording') {
          const duration = Math.floor((Date.now() - this.recordingStartTime) / 1000);
          this.pushEvent("recording_update", { duration });
        }
      }, 1000);
      
      // Notify component that recording started
      this.pushEvent("recording_started", {});
      
    } catch (error) {
      console.error("❌ Failed to start recording:", error);
      this.pushEvent("recording_error", { error: error.message });
    }
  },

  stopRecording() {
    if (this.mediaRecorder && this.mediaRecorder.state === 'recording') {
      console.log("⏹️ Stopping recording...");
      this.mediaRecorder.stop();
      
      if (this.durationInterval) {
        clearInterval(this.durationInterval);
        this.durationInterval = null;
      }
    }
  },

  processRecording() {
    if (this.recordedChunks.length === 0) {
      console.error("❌ No recorded data available");
      this.pushEvent("recording_error", { error: "No recorded data available" });
      return;
    }

    console.log("🔄 Processing recording...");
    
    // Create blob from recorded chunks
    const blob = new Blob(this.recordedChunks, { type: 'video/webm' });
    
    // Create object URL for preview/download
    const videoUrl = URL.createObjectURL(blob);
    
    console.log("✅ Recording processed, size:", blob.size, "bytes");
    
    // Notify component that recording is complete
    this.pushEvent("recording_complete", { 
      size: blob.size,
      duration: Math.floor((Date.now() - this.recordingStartTime) / 1000),
      videoUrl: videoUrl
    });
    
    // Clean up
    this.recordedChunks = [];
  },

  destroyed() {
    console.log("📹 VideoCapture hook destroyed");
    
    // Clean up intervals
    if (this.durationInterval) {
      clearInterval(this.durationInterval);
    }
    
    // Stop recording if active
    if (this.mediaRecorder && this.mediaRecorder.state === 'recording') {
      this.mediaRecorder.stop();
    }
    
    // Release camera stream
    if (this.stream) {
      this.stream.getTracks().forEach(track => {
        track.stop();
      });
      this.stream = null;
    }
  }
};

// Export for use in LiveView
export default VideoCapture;