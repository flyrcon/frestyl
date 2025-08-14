// assets/js/hooks/video_capture_v2.js
// COMPLETE REBUILD - Clean, reliable video capture system

const VideoCapture = {
  mounted() {
    console.log("📹 VideoCapture v2 mounted");
    
    // Initialize state
    this.componentId = this.el.dataset.componentId;
    this.mediaRecorder = null;
    this.recordedChunks = [];
    this.stream = null;
    this.countdownTimer = null;
    this.recordingTimer = null;
    this.recordingStartTime = null;
    
    // Bind methods to maintain context
    this.handleCameraReady = this.handleCameraReady.bind(this);
    this.handleCameraError = this.handleCameraError.bind(this);
    
    // Set up event listeners
    this.setupEventListeners();
    
    // Initialize camera after brief delay to ensure DOM is ready
    setTimeout(() => {
      this.initializeCamera();
    }, 100);
  },

  setupEventListeners() {
    // Listen for start countdown event
    this.handleEvent("start_countdown", (data) => {
      console.log("🎬 Starting countdown from Elixir");
      this.startCountdown(data.count || 3);
    });
    
    // Listen for stop recording event
    this.handleEvent("stop_recording", () => {
      console.log("⏹️ Stop recording from Elixir");
      this.stopRecording();
    });
    
    // Listen for retry camera event
    this.handleEvent("retry_camera", () => {
      console.log("🔄 Retrying camera");
      this.retryCamera();
    });
  },

  async initializeCamera() {
    try {
      console.log("📹 Initializing camera...");
      
      // Check if browser supports required APIs
      if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
        throw new Error("Camera not supported in this browser");
      }
      
      // Request camera with optimal settings
      const constraints = {
        video: {
          width: { ideal: 1280, min: 640 },
          height: { ideal: 720, min: 480 },
          facingMode: "user",
          frameRate: { ideal: 30, min: 15 }
        },
        audio: {
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true
        }
      };
      
      this.stream = await navigator.mediaDevices.getUserMedia(constraints);
      
      // Find video element and set stream
      const videoElement = this.getVideoElement();
      if (!videoElement) {
        throw new Error("Video element not found");
      }
      
      videoElement.srcObject = this.stream;
      
      // Wait for video to be ready
      await this.waitForVideoReady(videoElement);
      
      console.log("✅ Camera initialized successfully");
      this.handleCameraReady();
      
    } catch (error) {
      console.error("❌ Camera initialization failed:", error);
      this.handleCameraError(error.message);
    }
  },

  getVideoElement() {
    // Try multiple selectors to find the video element
    const selectors = [
      `#camera-preview-${this.componentId}`,
      '#camera-preview',
      'video[data-component-id="' + this.componentId + '"]',
      'video'
    ];
    
    for (const selector of selectors) {
      const element = document.querySelector(selector);
      if (element) {
        console.log(`📹 Found video element with selector: ${selector}`);
        return element;
      }
    }
    
    console.error("❌ No video element found");
    return null;
  },

  waitForVideoReady(videoElement) {
    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        reject(new Error("Video element ready timeout"));
      }, 5000);
      
      const onReady = () => {
        clearTimeout(timeout);
        videoElement.removeEventListener('loadedmetadata', onReady);
        resolve();
      };
      
      if (videoElement.readyState >= 1) {
        clearTimeout(timeout);
        resolve();
      } else {
        videoElement.addEventListener('loadedmetadata', onReady);
      }
    });
  },

  handleCameraReady() {
    console.log("📹 Camera ready, notifying component");
    this.pushEvent("camera_ready", {});
  },

  handleCameraError(error) {
    console.error("❌ Camera error:", error);
    this.pushEvent("camera_error", { error });
  },

  startCountdown(initialCount = 3) {
    console.log(`🎬 Starting countdown from ${initialCount}`);
    
    // Clear any existing countdown
    this.clearCountdown();
    
    let count = initialCount;
    
    // Send initial count
    this.pushEvent("countdown_tick", { count });
    
    // Start countdown interval
    this.countdownTimer = setInterval(() => {
      count--;
      console.log(`🎬 Countdown: ${count}`);
      
      if (count > 0) {
        this.pushEvent("countdown_tick", { count });
      } else {
        console.log("🎬 Countdown complete, starting recording");
        this.clearCountdown();
        this.startRecording();
      }
    }, 1000);
  },

  clearCountdown() {
    if (this.countdownTimer) {
      clearInterval(this.countdownTimer);
      this.countdownTimer = null;
    }
  },

  async startRecording() {
    try {
      console.log("🎬 Starting recording...");
      
      if (!this.stream) {
        throw new Error("No camera stream available");
      }
      
      // Set up media recorder
      const options = {
        mimeType: this.getSupportedMimeType(),
        videoBitsPerSecond: 2500000 // 2.5 Mbps for good quality
      };
      
      this.mediaRecorder = new MediaRecorder(this.stream, options);
      this.recordedChunks = [];
      
      // Set up event handlers
      this.mediaRecorder.addEventListener('dataavailable', (event) => {
        if (event.data.size > 0) {
          this.recordedChunks.push(event.data);
        }
      });
      
      this.mediaRecorder.addEventListener('stop', () => {
        console.log("🎬 Recording stopped, processing...");
        this.processRecording();
      });
      
      this.mediaRecorder.addEventListener('error', (event) => {
        console.error("❌ Recording error:", event.error);
        this.pushEvent("recording_error", { error: event.error.message });
      });
      
      // Start recording
      this.mediaRecorder.start(100); // Collect data every 100ms
      this.recordingStartTime = Date.now();
      
      console.log("✅ Recording started");
      this.pushEvent("recording_started", {});
      
      // Start duration timer
      this.startRecordingTimer();
      
    } catch (error) {
      console.error("❌ Failed to start recording:", error);
      this.pushEvent("recording_error", { error: error.message });
    }
  },

  getSupportedMimeType() {
    const types = [
      'video/webm;codecs=vp9,opus',
      'video/webm;codecs=vp8,opus',
      'video/webm;codecs=h264,opus',
      'video/webm',
      'video/mp4'
    ];
    
    for (const type of types) {
      if (MediaRecorder.isTypeSupported(type)) {
        console.log(`📹 Using MIME type: ${type}`);
        return type;
      }
    }
    
    console.log("📹 Using default MIME type");
    return undefined;
  },

  startRecordingTimer() {
    this.recordingTimer = setInterval(() => {
      if (this.recordingStartTime) {
        const duration = Math.floor((Date.now() - this.recordingStartTime) / 1000);
        this.pushEvent("recording_tick", { duration });
      }
    }, 1000);
  },

  stopRecording() {
    console.log("⏹️ Stopping recording...");
    
    // Clear recording timer
    if (this.recordingTimer) {
      clearInterval(this.recordingTimer);
      this.recordingTimer = null;
    }
    
    // Stop media recorder
    if (this.mediaRecorder && this.mediaRecorder.state === 'recording') {
      this.mediaRecorder.stop();
    } else {
      console.log("⚠️ MediaRecorder not in recording state");
      this.pushEvent("recording_stopped", {});
    }
  },

  processRecording() {
    if (this.recordedChunks.length === 0) {
      console.error("❌ No recorded data available");
      this.pushEvent("recording_error", { error: "No recorded data available" });
      return;
    }

    console.log(`🔄 Processing recording... ${this.recordedChunks.length} chunks`);
    
    // Create blob from recorded chunks
    const blob = new Blob(this.recordedChunks, { 
      type: this.mediaRecorder.mimeType || 'video/webm'
    });
    
    // Create object URL for preview
    const videoUrl = URL.createObjectURL(blob);
    
    // Calculate duration
    const duration = this.recordingStartTime ? 
      Math.floor((Date.now() - this.recordingStartTime) / 1000) : 0;
    
    console.log(`✅ Recording processed: ${blob.size} bytes, ${duration}s`);
    
    // Notify component
    this.pushEvent("recording_complete", { 
      videoUrl,
      duration,
      size: blob.size,
      mimeType: this.mediaRecorder.mimeType || 'video/webm'
    });
    
    // Store blob for upload
    this.recordedBlob = blob;
    
    // Clean up chunks to save memory
    this.recordedChunks = [];
  },

  retryCamera() {
    console.log("🔄 Retrying camera initialization...");
    
    // Clean up existing stream
    this.cleanupStream();
    
    // Try to initialize again
    setTimeout(() => {
      this.initializeCamera();
    }, 500);
  },

  cleanupStream() {
    if (this.stream) {
      console.log("🧹 Cleaning up camera stream");
      this.stream.getTracks().forEach(track => {
        track.stop();
      });
      this.stream = null;
    }
  },

  destroyed() {
    console.log("📹 VideoCapture hook destroyed");
    
    // Clear all timers
    this.clearCountdown();
    
    if (this.recordingTimer) {
      clearInterval(this.recordingTimer);
      this.recordingTimer = null;
    }
    
    // Stop recording if active
    if (this.mediaRecorder && this.mediaRecorder.state === 'recording') {
      this.mediaRecorder.stop();
    }
    
    // Clean up stream
    this.cleanupStream();
    
    // Revoke object URLs to prevent memory leaks
    if (this.recordedBlob) {
      URL.revokeObjectURL(this.recordedBlob);
    }
  }
};

export default VideoCapture;