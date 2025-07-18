// Create or update assets/js/hooks/video_capture.js

const VideoCapture = {
  mounted() {
    console.log("🎥 VideoCapture hook mounted");
    
    // Get component ID from data attribute with fallback
    this.componentId = this.el.dataset.componentId || 
                      this.el.getAttribute('data-component-id') || 
                      this.el.id || 
                      'unknown';
    
    console.log(`🎥 VideoCapture hook mounted for component: ${this.componentId}`);
    
    // Initialize video capture state
    this.stream = null;
    this.mediaRecorder = null;
    this.recordedChunks = [];
    this.isRecording = false;
    this.recordingTimer = null;
    this.elapsedTime = 0;
    
    // Get video element - could be inside this element
    this.videoElement = this.el.querySelector('#camera-preview') || 
                       this.el.querySelector('video') ||
                       document.getElementById('camera-preview');
    
    if (!this.videoElement) {
      console.warn("⚠️ No video element found for VideoCapture hook");
      return;
    }

    console.log("📹 Video element found:", this.videoElement.id);
    
    // Set up event handlers
    this.setupEventHandlers();
    
    // Initialize camera if recording state is setup
    const recordingState = this.el.dataset.recordingState;
    if (recordingState === 'setup') {
      this.initializeCamera();
    }
  },

  updated() {
    console.log("🔄 VideoCapture hook updated");
    const recordingState = this.el.dataset.recordingState;
    console.log("📊 Recording state:", recordingState);
    
    // Handle state changes
    switch (recordingState) {
      case 'setup':
        if (!this.stream) {
          this.initializeCamera();
        }
        break;
      case 'countdown':
        this.handleCountdownState();
        break;
      case 'recording':
        this.handleRecordingState();
        break;
      case 'preview':
        this.handlePreviewState();
        break;
    }
  },

  destroyed() {
    console.log("🧹 VideoCapture hook destroyed");
    this.cleanup();
  },

  // ============================================================================
  // EVENT HANDLERS
  // ============================================================================

  setupEventHandlers() {
    // Handle events from LiveView component
    this.handleEvent("initialize_camera", (data) => {
      console.log("🎬 Initialize camera event received:", data);
      this.initializeCamera(data.constraints);
    });

    this.handleEvent("start_countdown", (data) => {
      console.log("⏰ Start countdown event received:", data);
      this.startCountdown(data.duration || 3);
    });

    this.handleEvent("start_recording", (data) => {
      console.log("🔴 Start recording event received:", data);
      this.startRecording();
    });

    this.handleEvent("stop_recording", (data) => {
      console.log("⏹️ Stop recording event received:", data);
      this.stopRecording();
    });

    this.handleEvent("reset_recording", (data) => {
      console.log("🔄 Reset recording event received:", data);
      this.resetRecording();
    });
  },

  // ============================================================================
  // CAMERA INITIALIZATION
  // ============================================================================

  async initializeCamera(constraints = null) {
    console.log("📷 Initializing camera...");
    
    try {
      // Default constraints if none provided
      const defaultConstraints = {
        video: {
          width: { ideal: 1280 },
          height: { ideal: 720 },
          frameRate: { ideal: 30 },
          facingMode: 'user'
        },
        audio: true
      };

      const mediaConstraints = constraints || defaultConstraints;
      console.log("🎛️ Using constraints:", mediaConstraints);

      // Request camera access
      this.stream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      
      // Set video source
      if (this.videoElement) {
        this.videoElement.srcObject = this.stream;
        this.videoElement.muted = true; // Prevent feedback
        
        // Wait for video to be ready
        await new Promise((resolve) => {
          this.videoElement.addEventListener('loadedmetadata', resolve, { once: true });
        });
        
        console.log("✅ Camera initialized successfully");
        
        // Notify component that camera is ready
        this.pushEvent("camera_ready", { 
          stream_active: true,
          component_id: this.componentId
        });
      }
      
    } catch (error) {
      console.error("❌ Camera initialization failed:", error);
      
      let errorType = "UnknownError";
      let errorMessage = error.message;
      
      switch (error.name) {
        case "NotAllowedError":
          errorType = "NotAllowedError";
          errorMessage = "Camera access denied by user";
          break;
        case "NotFoundError":
          errorType = "NotFoundError";
          errorMessage = "No camera device found";
          break;
        case "NotReadableError":
          errorType = "NotReadableError";
          errorMessage = "Camera is already in use";
          break;
        case "OverconstrainedError":
          errorType = "OverconstrainedError";
          errorMessage = "Camera constraints cannot be satisfied";
          break;
      }
      
      // Notify component of error
      this.pushEvent("camera_error", {
        error: errorType,
        message: errorMessage,
        component_id: this.componentId
      });
    }
  },

  // ============================================================================
  // RECORDING FUNCTIONALITY
  // ============================================================================

  async startRecording() {
    if (!this.stream) {
      console.error("❌ No stream available for recording");
      return;
    }

    try {
      console.log("🔴 Starting recording...");
      
      // Create MediaRecorder
      const options = {
        mimeType: this.getSupportedMimeType(),
        videoBitsPerSecond: 2500000, // 2.5 Mbps
        audioBitsPerSecond: 128000   // 128 kbps
      };
      
      this.mediaRecorder = new MediaRecorder(this.stream, options);
      this.recordedChunks = [];
      this.elapsedTime = 0;
      
      // Set up recording events
      this.mediaRecorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          this.recordedChunks.push(event.data);
        }
      };
      
      this.mediaRecorder.onstop = () => {
        console.log("⏹️ Recording stopped");
        this.handleRecordingComplete();
      };
      
      this.mediaRecorder.onerror = (event) => {
        console.error("❌ Recording error:", event.error);
        this.pushEvent("recording_error", {
          error: event.error.name,
          message: event.error.message,
          component_id: this.componentId
        });
      };
      
      // Start recording
      this.mediaRecorder.start(1000); // Collect data every second
      this.isRecording = true;
      
      // Start timer
      this.startRecordingTimer();
      
      console.log("✅ Recording started successfully");
      
      // Notify component
      this.pushEvent("recording_started", {
        component_id: this.componentId
      });
      
    } catch (error) {
      console.error("❌ Failed to start recording:", error);
      this.pushEvent("recording_error", {
        error: "StartRecordingError",
        message: error.message,
        component_id: this.componentId
      });
    }
  },

  stopRecording() {
    if (this.mediaRecorder && this.isRecording) {
      console.log("⏹️ Stopping recording...");
      this.mediaRecorder.stop();
      this.isRecording = false;
      this.stopRecordingTimer();
    }
  },

  handleRecordingComplete() {
    console.log("✅ Recording complete, processing video...");
    
    if (this.recordedChunks.length === 0) {
      console.error("❌ No recorded data available");
      return;
    }
    
    // Create blob from recorded chunks
    const mimeType = this.getSupportedMimeType();
    const videoBlob = new Blob(this.recordedChunks, { type: mimeType });
    
    console.log(`📹 Video blob created: ${(videoBlob.size / 1024 / 1024).toFixed(2)} MB`);
    
    // Convert to base64 for transmission
    const reader = new FileReader();
    reader.onload = () => {
      const base64Data = reader.result;
      
      // Send to component
      this.pushEvent("video_blob_ready", {
        video_data: base64Data,
        mime_type: mimeType,
        duration: this.elapsedTime,
        size: videoBlob.size,
        component_id: this.componentId
      });
    };
    
    reader.onerror = (error) => {
      console.error("❌ Failed to convert video to base64:", error);
      this.pushEvent("recording_error", {
        error: "ConversionError",
        message: "Failed to process recorded video",
        component_id: this.componentId
      });
    };
    
    reader.readAsDataURL(videoBlob);
  },

  // ============================================================================
  // COUNTDOWN FUNCTIONALITY
  // ============================================================================

  startCountdown(duration = 3) {
    console.log(`⏰ Starting countdown: ${duration} seconds`);
    
    let countdown = duration;
    
    const countdownInterval = setInterval(() => {
      countdown--;
      
      this.pushEvent("countdown_tick", {
        countdown: countdown,
        component_id: this.componentId
      });
      
      if (countdown <= 0) {
        clearInterval(countdownInterval);
        console.log("🚀 Countdown complete, starting recording");
        
        // Auto-start recording after countdown
        this.startRecording();
      }
    }, 1000);
  },

  // ============================================================================
  // TIMER FUNCTIONALITY
  // ============================================================================

  startRecordingTimer() {
    this.recordingTimer = setInterval(() => {
      this.elapsedTime++;
      
      this.pushEvent("recording_tick", {
        elapsed_time: this.elapsedTime,
        component_id: this.componentId
      });
      
      // Auto-stop at max duration (e.g., 60 seconds)
      if (this.elapsedTime >= 60) {
        console.log("⏰ Max duration reached, stopping recording");
        this.stopRecording();
      }
    }, 1000);
  },

  stopRecordingTimer() {
    if (this.recordingTimer) {
      clearInterval(this.recordingTimer);
      this.recordingTimer = null;
    }
  },

  // ============================================================================
  // STATE HANDLERS
  // ============================================================================

  handleCountdownState() {
    // Ensure camera is still active
    if (!this.stream) {
      this.initializeCamera();
    }
  },

  handleRecordingState() {
    // Recording should already be started by countdown
    // This is just a safety check
    if (!this.isRecording) {
      this.startRecording();
    }
  },

  handlePreviewState() {
    // Stop any ongoing recording
    if (this.isRecording) {
      this.stopRecording();
    }
  },

  // ============================================================================
  // UTILITY FUNCTIONS
  // ============================================================================

  getSupportedMimeType() {
    const types = [
      'video/webm;codecs=vp9,opus',
      'video/webm;codecs=vp8,opus',
      'video/webm',
      'video/mp4;codecs=h264,aac',
      'video/mp4'
    ];
    
    for (const type of types) {
      if (MediaRecorder.isTypeSupported(type)) {
        console.log(`📹 Using mime type: ${type}`);
        return type;
      }
    }
    
    console.warn("⚠️ No preferred mime type supported, using default");
    return 'video/webm';
  },

  resetRecording() {
    console.log("🔄 Resetting recording state");
    
    // Stop any ongoing recording
    if (this.isRecording) {
      this.stopRecording();
    }
    
    // Clear recorded data
    this.recordedChunks = [];
    this.elapsedTime = 0;
    
    // Reset MediaRecorder
    this.mediaRecorder = null;
    
    // Notify component
    this.pushEvent("recording_reset", {
      component_id: this.componentId
    });
  },

  cleanup() {
    console.log("🧹 Cleaning up VideoCapture resources");
    
    // Stop recording if active
    if (this.isRecording) {
      this.stopRecording();
    }
    
    // Stop timer
    this.stopRecordingTimer();
    
    // Stop camera stream
    if (this.stream) {
      this.stream.getTracks().forEach(track => {
        track.stop();
        console.log(`🛑 Stopped track: ${track.kind}`);
      });
      this.stream = null;
    }
    
    // Clear video element
    if (this.videoElement) {
      this.videoElement.srcObject = null;
    }
    
    // Reset state
    this.mediaRecorder = null;
    this.recordedChunks = [];
    this.elapsedTime = 0;
    this.isRecording = false;
  }
};

export default VideoCapture;