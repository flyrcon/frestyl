// assets/js/hooks/video_capture.js
// FIXED: Proper timing and state management for camera initialization

const VideoCapture = {
  mounted() {
    console.log("📹 VideoCapture hook mounted");
    this.componentId = this.el.dataset.componentId;
    this.mediaRecorder = null;
    this.recordedChunks = [];
    this.stream = null;
    this.retryCount = 0;
    this.maxRetries = 3;
    this.initializationTimer = null;

    // Listen for countdown start event
    this.handleEvent("start_countdown", (data) => {
      console.log("🎬 JS: Starting countdown", data);
      this.startCountdown(data.initial_count);
    });
    
    // FIXED: Wait for DOM and LiveView to be fully ready
    this.waitForLiveViewReady(() => {
      this.initializeCamera();
    });
    
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

    // Listen for retry camera event
    this.handleEvent("retry_camera", () => {
      this.retryCamera();
    });
  },

  // FIXED: Better timing for LiveView readiness
  waitForLiveViewReady(callback) {
    // Check if the element is properly connected and LiveView is ready
    const checkReady = () => {
      if (this.el && this.el.isConnected && this.pushEvent) {
        console.log("📹 LiveView ready, initializing camera");
        callback();
      } else {
        console.log("📹 Waiting for LiveView to be ready...");
        setTimeout(checkReady, 100);
      }
    };
    
    // Start checking after a brief delay
    setTimeout(checkReady, 200);
  },

  async initializeCamera() {
    // Clear any existing timer
    if (this.initializationTimer) {
      clearTimeout(this.initializationTimer);
      this.initializationTimer = null;
    }

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
      
      // FIXED: Ensure video element is ready before setting stream
      if (!this.el) {
        throw new Error("Video element not available");
      }

      // Set video element source
      this.el.srcObject = this.stream;
      
      // FIXED: Wait for video to be ready before notifying component
      await new Promise((resolve, reject) => {
        const timeout = setTimeout(() => {
          reject(new Error("Video loading timeout"));
        }, 5000);

        this.el.onloadedmetadata = () => {
          clearTimeout(timeout);
          resolve();
        };

        this.el.onerror = (error) => {
          clearTimeout(timeout);
          reject(error);
        };
      });

      // Start video playback
      await this.el.play();
      
      console.log("✅ Camera initialized successfully");
      
      // FIXED: Send camera_initialized event (matches component expectations)
      this.pushEventTo(this.el, "camera_initialized", {});
      
      // Reset retry count on success
      this.retryCount = 0;
      
    } catch (error) {
      console.error("❌ Camera initialization failed:", error);
      
      let errorMessage = this.getErrorMessage(error);
      
      // FIXED: Send camera_error event with proper error message
      this.pushEventTo(this.el, "camera_error", { error: errorMessage });
    }
  },

  // FIXED: Improved retry functionality
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
    this.cleanupStream();
    
    // Wait before retrying
    setTimeout(() => {
      this.initializeCamera();
    }, 1000 * this.retryCount); // Exponential backoff
  },

  // FIXED: Better cleanup method
  cleanupStream() {
    if (this.stream) {
      this.stream.getTracks().forEach(track => {
        track.stop();
        console.log("📹 Stopped track:", track.kind);
      });
      this.stream = null;
    }

    if (this.el && this.el.srcObject) {
      this.el.srcObject = null;
    }
  },

  // FIXED: Better error message handling
  getErrorMessage(error) {
    switch (error.name) {
      case "NotAllowedError":
        return "Camera access denied. Please allow camera access and try again.";
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

  startCountdown(count) {
    console.log(`🎬 JS: Countdown starting at ${count}`);
    
    // Clear any existing countdown
    if (this.countdownInterval) {
      clearInterval(this.countdownInterval);
    }
    
    let currentCount = count;
    
    // Send initial count
    this.pushEvent("countdown_update", { count: currentCount });
    
    // Start interval
    this.countdownInterval = setInterval(() => {
      currentCount--;
      console.log(`🎬 JS: Countdown tick: ${currentCount}`);
      
      if (currentCount > 0) {
        // Send countdown update
        this.pushEvent("countdown_update", { count: currentCount });
      } else {
        // Countdown finished
        console.log("🎬 JS: Countdown complete!");
        clearInterval(this.countdownInterval);
        this.countdownInterval = null;
        
        // Notify component that countdown is done
        this.pushEvent("countdown_complete", {});
      }
    }, 1000);
  },

  destroyed() {
    console.log("📹 VideoCapture hook destroyed");
    
    // Clear timers
    if (this.initializationTimer) {
      clearTimeout(this.initializationTimer);
    }

    if (this.countdownInterval) {
      clearInterval(this.countdownInterval);
    }
    
    if (this.durationInterval) {
      clearInterval(this.durationInterval);
    }
    
    // Stop recording if active
    if (this.mediaRecorder && this.mediaRecorder.state === 'recording') {
      this.mediaRecorder.stop();
    }
    
    // Release camera stream
    this.cleanupStream();
  }
};

// Export for use in LiveView
export default VideoCapture;