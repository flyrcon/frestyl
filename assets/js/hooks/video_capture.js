window.VideoCapture = {
  mounted() {
    console.log("📹 VideoCapture hook mounted");
    this.componentId = this.el.dataset.componentId;
    this.mediaRecorder = null;
    this.recordedChunks = [];
    this.stream = null;
    
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
      
      // Notify component that camera is ready
      this.pushEvent("camera_initialized", {});
      
    } catch (error) {
      console.error("❌ Camera initialization failed:", error);
      
      let errorMessage = "Unknown error";
      if (error.name === "NotAllowedError") {
        errorMessage = "Camera access denied by user";
      } else if (error.name === "NotFoundError") {
        errorMessage = "No camera found";
      } else if (error.name === "NotReadableError") {
        errorMessage = "Camera is being used by another application";
      }
      
      this.pushEvent("camera_error", { error: errorMessage });
    }
  },

  startRecording() {
    if (!this.stream) {
      console.error("❌ No stream available for recording");
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
      
    } catch (error) {
      console.error("❌ Failed to start recording:", error);
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
      return;
    }

    console.log("🔄 Processing recording...");
    
    // Create blob from recorded chunks
    const blob = new Blob(this.recordedChunks, { type: 'video/webm' });
    
    // Create object URL for preview/download
    const videoUrl = URL.createObjectURL(blob);
    
    // You can extend this to upload the video or save it
    console.log("✅ Recording processed, size:", blob.size, "bytes");
    
    // Notify component that recording is complete
    this.pushEvent("recording_complete", { 
      size: blob.size,
      duration: Math.floor((Date.now() - this.recordingStartTime) / 1000)
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