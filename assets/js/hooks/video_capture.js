// assets/js/hooks/video_capture.js - BULLETPROOF CAMERA INITIALIZATION

const VideoCapture = {
  mounted() {
    console.log("🎥 VideoCapture hook mounted - BULLETPROOF VERSION");
    console.log("🎥 Hook element:", this.el);
    console.log("🎥 Hook element ID:", this.el.id);
    console.log("🎥 Parent elements:", this.el.parentElement);
    
    // Initialize state
    this.initializeState();
    
    // CRITICAL: Start camera initialization immediately with retry logic
    this.initializeCameraWithRetry();
    
    // Bind events
    this.bindEvents();
  },

  initializeState() {
    this.stream = null;
    this.mediaRecorder = null;
    this.recordedChunks = [];
    this.recording = false;
    this.countdownInterval = null;
    this.recordingInterval = null;
    this.currentCountdown = 3;
    this.retryCount = 0;
    this.maxRetries = 3;
  },

  // BULLETPROOF: Camera initialization with comprehensive error handling and retries
  async initializeCameraWithRetry() {
    console.log(`🎥 Camera initialization attempt ${this.retryCount + 1}/${this.maxRetries + 1}`);
    
    try {
      await this.initializeCamera();
    } catch (error) {
      console.error(`🎥 Camera init attempt ${this.retryCount + 1} failed:`, error);
      
      this.retryCount++;
      if (this.retryCount <= this.maxRetries) {
        console.log(`🎥 Retrying camera initialization in 2 seconds...`);
        setTimeout(() => {
          this.initializeCameraWithRetry();
        }, 2000);
      } else {
        console.error("🎥 All camera initialization attempts failed");
        this.handleCameraError(error);
      }
    }
  },

  // BULLETPROOF: Step-by-step camera initialization
  async initializeCamera() {
    console.log("🎥 Starting camera initialization...");
    
    // Step 1: Check browser support
    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
      throw new Error("getUserMedia not supported");
    }
    
    // Step 2: Check for existing cameras
    const devices = await navigator.mediaDevices.enumerateDevices();
    const videoDevices = devices.filter(d => d.kind === 'videoinput');
    
    if (videoDevices.length === 0) {
      throw new Error("No camera devices found");
    }
    
    console.log(`🎥 Found ${videoDevices.length} camera device(s)`);
    
    // Step 3: Request camera access with progressive fallback
    this.stream = await this.requestCameraWithFallback();
    
    // Step 4: Set up video preview
    await this.setupVideoPreview();
    
    // Step 5: Notify success
    this.notifyCameraReady();
    
    console.log("🎥 Camera initialization completed successfully!");
  },

  // BULLETPROOF: Progressive fallback for camera constraints
  async requestCameraWithFallback() {
    const constraints = [
      // Try high quality first
      {
        video: {
          width: { ideal: 1280, max: 1920 },
          height: { ideal: 720, max: 1080 },
          frameRate: { ideal: 30 },
          facingMode: "user"
        },
        audio: {
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
          sampleRate: 44100
        }
      },
      // Fallback to medium quality
      {
        video: {
          width: { ideal: 640 },
          height: { ideal: 480 },
          frameRate: { ideal: 24 },
          facingMode: "user"
        },
        audio: true
      },
      // Fallback to basic
      {
        video: { facingMode: "user" },
        audio: true
      },
      // Last resort - video only
      {
        video: true
      }
    ];

    for (let i = 0; i < constraints.length; i++) {
      try {
        console.log(`🎥 Trying camera constraints ${i + 1}/${constraints.length}`);
        const stream = await navigator.mediaDevices.getUserMedia(constraints[i]);
        
        console.log(`🎥 Camera access granted with constraints ${i + 1}`);
        console.log(`🎥 Video tracks: ${stream.getVideoTracks().length}`);
        console.log(`🎥 Audio tracks: ${stream.getAudioTracks().length}`);
        
        return stream;
      } catch (error) {
        console.log(`🎥 Constraints ${i + 1} failed: ${error.message}`);
        
        if (i === constraints.length - 1) {
          throw error; // Re-throw the last error
        }
      }
    }
  },

  // BULLETPROOF: Video preview setup with retry
  async setupVideoPreview() {
    return new Promise((resolve, reject) => {
      const maxAttempts = 5;
      let attempt = 0;
      
      const trySetupVideo = () => {
        attempt++;
        console.log(`🎥 Video preview setup attempt ${attempt}/${maxAttempts}`);
        
        const video = this.el.querySelector('#camera-preview');
        
        if (!video) {
          if (attempt < maxAttempts) {
            setTimeout(trySetupVideo, 500);
            return;
          }
          reject(new Error("Video element not found after multiple attempts"));
          return;
        }
        
        if (!this.stream) {
          reject(new Error("No camera stream available"));
          return;
        }
        
        video.srcObject = this.stream;
        video.muted = true;
        video.autoplay = true;
        video.playsInline = true;
        video.style.transform = 'scaleX(-1)'; // Mirror effect
        
        video.onloadedmetadata = () => {
          console.log("🎥 Video preview metadata loaded");
          video.play()
            .then(() => {
              console.log("🎥 Video preview playing successfully");
              resolve();
            })
            .catch(error => {
              console.error("🎥 Video play failed:", error);
              reject(error);
            });
        };
        
        video.onerror = (error) => {
          console.error("🎥 Video element error:", error);
          reject(error);
        };
        
        // Timeout fallback
        setTimeout(() => {
          if (video.readyState >= 2) { // HAVE_CURRENT_DATA
            console.log("🎥 Video preview setup via timeout fallback");
            resolve();
          }
        }, 3000);
      };
      
      trySetupVideo();
    });
  },

  // BULLETPROOF: Camera ready notification
  notifyCameraReady() {
    const videoTracks = this.stream.getVideoTracks().length;
    const audioTracks = this.stream.getAudioTracks().length;
    
    // Get video settings for debugging
    const videoTrack = this.stream.getVideoTracks()[0];
    const settings = videoTrack ? videoTrack.getSettings() : {};
    
    console.log("🎥 Notifying component camera is ready:", {
      videoTracks,
      audioTracks,
      settings
    });
    
    this.pushEventTo(this.el.closest('[phx-target]'), "camera_ready", {
      videoTracks,
      audioTracks,
      success: true,
      settings,
      constraints: {
        width: settings.width,
        height: settings.height,
        frameRate: settings.frameRate
      }
    });
  },

  // BULLETPROOF: Event binding
  bindEvents() {
    console.log("🎥 Binding events...");
    
    this.handleEvent("start_countdown", () => {
      console.log("🎥 start_countdown event received");
      this.startCountdown();
    });

    this.handleEvent("force_countdown_start", () => {
      console.log("🎥 force_countdown_start event received");
      setTimeout(() => this.startCountdown(), 100);
    });
    
    this.handleEvent("stop_recording", () => {
      console.log("🎥 stop_recording event received");
      this.stopRecording();
    });
    
    this.handleEvent("save_video", () => {
      console.log("🎥 save_video event received");
      this.saveVideo();
    });

    console.log("🎥 Event binding completed");
  },

  // BULLETPROOF: Countdown with solid interval management
  startCountdown() {
    console.log("🎥 Starting countdown...");
    console.log("🎥 Stream available:", !!this.stream);
    
    if (!this.stream) {
      console.error("🎥 No camera stream for countdown");
      this.pushEvent("recording_error", { message: "Camera not ready" });
      return;
    }

    // Clear any existing countdown
    this.clearCountdown();
    
    // Start countdown
    this.currentCountdown = 3;
    console.log(`🎥 Countdown starting from ${this.currentCountdown}`);
    
    // Send initial count
    this.pushEvent("countdown_update", { count: this.currentCountdown });
    
    this.countdownInterval = setInterval(() => {
      this.currentCountdown--;
      console.log(`🎥 Countdown: ${this.currentCountdown}`);
      
      this.pushEvent("countdown_update", { count: this.currentCountdown });
      
      if (this.currentCountdown <= 0) {
        console.log("🎥 Countdown finished! Starting recording...");
        this.clearCountdown();
        this.startActualRecording();
      }
    }, 1000);
  },

  clearCountdown() {
    if (this.countdownInterval) {
      clearInterval(this.countdownInterval);
      this.countdownInterval = null;
    }
  },

  // BULLETPROOF: Recording start
  async startActualRecording() {
    console.log("🎥 Starting recording...");
    
    if (!this.stream) {
      this.pushEvent("recording_error", { message: "No camera stream" });
      return;
    }

    try {
      // Find supported MIME type
      const mimeTypes = [
        'video/webm;codecs=vp9,opus',
        'video/webm;codecs=vp8,opus',
        'video/webm',
        'video/mp4'
      ];

      let selectedMimeType = null;
      for (const mimeType of mimeTypes) {
        if (MediaRecorder.isTypeSupported(mimeType)) {
          selectedMimeType = mimeType;
          console.log(`🎥 Using MIME type: ${selectedMimeType}`);
          break;
        }
      }

      if (!selectedMimeType) {
        throw new Error('No supported video format found');
      }

      // Create MediaRecorder
      this.mediaRecorder = new MediaRecorder(this.stream, {
        mimeType: selectedMimeType,
        videoBitsPerSecond: 2500000, // 2.5 Mbps
        audioBitsPerSecond: 128000   // 128 kbps
      });

      this.recordedChunks = [];

      // Set up event handlers
      this.mediaRecorder.ondataavailable = (event) => {
        if (event.data && event.data.size > 0) {
          this.recordedChunks.push(event.data);
          console.log(`🎥 Recording chunk: ${event.data.size} bytes`);
        }
      };

      this.mediaRecorder.onstop = () => {
        console.log(`🎥 Recording stopped. Total chunks: ${this.recordedChunks.length}`);
        this.processRecording();
      };

      this.mediaRecorder.onerror = (event) => {
        console.error("🎥 MediaRecorder error:", event.error);
        this.pushEvent("recording_error", { 
          message: `Recording failed: ${event.error.message}` 
        });
      };

      // Start recording
      this.mediaRecorder.start(1000); // Collect data every second
      this.recording = true;
      
      console.log("🎥 Recording started successfully");
      this.startProgressTracking();

    } catch (error) {
      console.error("🎥 Failed to start recording:", error);
      this.pushEvent("recording_error", { 
        message: `Failed to start recording: ${error.message}` 
      });
    }
  },

  // BULLETPROOF: Recording progress tracking
  startProgressTracking() {
    this.recordingStartTime = Date.now();
    
    this.recordingInterval = setInterval(() => {
      if (this.recording) {
        const elapsed = Math.floor((Date.now() - this.recordingStartTime) / 1000);
        this.pushEvent("recording_progress", { elapsed });
        
        // Auto-stop at 60 seconds
        if (elapsed >= 60) {
          console.log("🎥 Auto-stopping at 60 seconds");
          this.stopRecording();
        }
      }
    }, 1000);
  },

  stopProgressTracking() {
    if (this.recordingInterval) {
      clearInterval(this.recordingInterval);
      this.recordingInterval = null;
    }
  },

  // BULLETPROOF: Stop recording
  stopRecording() {
    console.log("🎥 Stopping recording...");
    
    this.clearCountdown();
    this.stopProgressTracking();
    
    if (this.mediaRecorder && this.recording) {
      try {
        this.mediaRecorder.stop();
        this.recording = false;
        console.log("🎥 Recording stop initiated");
      } catch (error) {
        console.error("🎥 Error stopping recording:", error);
      }
    }
  },

  // BULLETPROOF: Process recorded video
  async processRecording() {
    console.log("🎥 Processing recording...");
    
    if (this.recordedChunks.length === 0) {
      console.error("🎥 No recorded chunks");
      this.pushEvent("recording_error", { message: "No video data recorded" });
      return;
    }

    try {
      const blob = new Blob(this.recordedChunks, { type: 'video/webm' });
      const duration = Math.floor((Date.now() - this.recordingStartTime) / 1000);
      
      console.log(`🎥 Video blob created: ${blob.size} bytes, ${duration}s duration`);
      
      // Convert to base64
      const base64Data = await this.blobToBase64(blob);
      
      // Send to component
      this.pushEvent("video_blob_ready", {
        blob_data: base64Data.split(',')[1], // Remove data: prefix
        mime_type: "video/webm",
        file_size: blob.size,
        duration: duration,
        success: true
      });
      
      // Set up playback preview
      this.setupPlaybackPreview(blob);
      
    } catch (error) {
      console.error("🎥 Failed to process recording:", error);
      this.pushEvent("video_blob_ready", {
        success: false,
        error: error.message
      });
    }
  },

  // BULLETPROOF: Convert blob to base64
  blobToBase64(blob) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onloadend = () => resolve(reader.result);
      reader.onerror = (error) => {
        console.error("🎥 FileReader error:", error);
        reject(error);
      };
      reader.readAsDataURL(blob);
    });
  },

  // BULLETPROOF: Setup playback preview
  setupPlaybackPreview(blob) {
    const playbackVideo = this.el.querySelector('#playback-video');
    const loadingDiv = this.el.querySelector('#video-loading');
    
    if (!playbackVideo) {
      console.warn("🎥 Playback video element not found");
      return;
    }

    try {
      const url = URL.createObjectURL(blob);
      playbackVideo.src = url;
      playbackVideo.controls = true;
      
      playbackVideo.onloadeddata = () => {
        console.log("🎥 Playback video loaded");
        if (loadingDiv) {
          loadingDiv.style.display = 'none';
        }
      };
      
      playbackVideo.onerror = (error) => {
        console.error("🎥 Playback error:", error);
      };
      
      // Cleanup URL when done
      playbackVideo.addEventListener('ended', () => {
        URL.revokeObjectURL(url);
      }, { once: true });
      
    } catch (error) {
      console.error("🎥 Failed to setup playback:", error);
    }
  },

  // Save video (calls processRecording if needed)
  async saveVideo() {
    console.log("🎥 Save video requested");
    
    if (this.recordedChunks.length === 0) {
      console.error("🎥 No video data to save");
      this.pushEvent("recording_error", { message: "No video data to save" });
      return;
    }

    // Process recording if not already done
    await this.processRecording();
  },

  // BULLETPROOF: Camera error handling
  handleCameraError(error) {
    let errorType = "unknown";
    let errorMessage = "Camera access failed";
    
    switch (error.name) {
      case "NotAllowedError":
        errorType = "permission_denied";
        errorMessage = "Camera permission denied. Please allow camera access and refresh the page.";
        break;
      case "NotFoundError":
        errorType = "no_camera";
        errorMessage = "No camera found. Please connect a camera and try again.";
        break;
      case "NotReadableError":
        errorType = "camera_busy";
        errorMessage = "Camera is being used by another application. Please close other applications and try again.";
        break;
      case "OverconstrainedError":
        errorType = "constraints_error";
        errorMessage = "Camera doesn't support the required settings. Try with a different camera.";
        break;
      case "SecurityError":
        errorType = "security_error";
        errorMessage = "Camera access blocked due to security settings. Please use HTTPS.";
        break;
      default:
        errorType = "unknown_error";
        errorMessage = `Camera error: ${error.message || error.name || "Unknown error"}`;
    }
    
    console.error(`🎥 Camera error: ${errorType} - ${errorMessage}`);
    
    this.pushEvent("camera_error", {
      error: errorType,
      message: errorMessage,
      originalError: error.name,
      retry_count: this.retryCount
    });
  },

  // BULLETPROOF: Cleanup on destroy
  destroyed() {
    console.log("🎥 VideoCapture hook destroyed - cleaning up");
    
    // Clear all intervals
    this.clearCountdown();
    this.stopProgressTracking();
    
    // Stop recording if active
    if (this.mediaRecorder && this.recording) {
      try {
        this.mediaRecorder.stop();
      } catch (error) {
        console.warn("🎥 Error stopping recording during cleanup:", error);
      }
    }
    
    // Release camera stream
    if (this.stream) {
      this.stream.getTracks().forEach(track => {
        track.stop();
        console.log(`🎥 Stopped ${track.kind} track`);
      });
      this.stream = null;
    }
    
    console.log("🎥 Cleanup completed");
  }
};

export default VideoCapture;