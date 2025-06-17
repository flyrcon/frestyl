// assets/js/hooks/video_capture.js - FIXED VIDEO CAMERA HOOK

const VideoCapture = {
  mounted() {
    console.log("🎥 VideoCapture hook mounted");
    this.recording = false;
    this.mediaRecorder = null;
    this.recordedChunks = [];
    this.stream = null;
    this.countdown = null;
    
    // ISSUE 3 FIX: Initialize camera on mount
    this.initializeCamera();
    
    // Handle events from LiveView
    this.handleEvent("start_recording", () => this.startRecording());
    this.handleEvent("stop_recording", () => this.stopRecording());
    this.handleEvent("save_video", () => this.saveVideo());
  },

  // FIXED: Camera initialization
  async initializeCamera() {
    console.log("🎥 Initializing camera...");
    
    try {
      // Request camera and microphone access
      this.stream = await navigator.mediaDevices.getUserMedia({
        video: {
          width: { ideal: 1920 },
          height: { ideal: 1080 },
          frameRate: { ideal: 30 }
        },
        audio: {
          echoCancellation: true,
          noiseSuppression: true,
          sampleRate: 44100
        }
      });

      console.log("🎥 Camera stream obtained successfully");
      
      // Set up video preview
      const video = this.el.querySelector('#camera-preview');
      if (video) {
        video.srcObject = this.stream;
        video.play();
        console.log("🎥 Video preview started");
      }

      // Notify component that camera is ready
      this.pushEvent("camera_ready", {
        videoTracks: this.stream.getVideoTracks().length,
        audioTracks: this.stream.getAudioTracks().length,
        success: true
      });

    } catch (error) {
      console.error("🎥 Camera initialization failed:", error);
      
      // Send detailed error info to component
      let errorType = "unknown";
      let errorMessage = "Camera access failed";
      
      if (error.name === "NotAllowedError") {
        errorType = "permission_denied";
        errorMessage = "Camera permission denied. Please allow camera access and refresh.";
      } else if (error.name === "NotFoundError") {
        errorType = "no_camera";
        errorMessage = "No camera found. Please connect a camera.";
      } else if (error.name === "NotReadableError") {
        errorType = "camera_busy";
        errorMessage = "Camera is being used by another application.";
      }
      
      this.pushEvent("camera_error", {
        error: errorType,
        message: errorMessage,
        originalError: error.name
      });
    }
  },

  // FIXED: Recording functionality
  async startRecording() {
    console.log("🎥 Starting recording...");
    
    if (!this.stream) {
      console.error("🎥 No camera stream available");
      this.pushEvent("recording_error", { message: "Camera not ready" });
      return;
    }

    try {
      // Initialize MediaRecorder
      this.mediaRecorder = new MediaRecorder(this.stream, {
        mimeType: 'video/webm;codecs=vp9,opus'
      });
      
      this.recordedChunks = [];
      
      // Handle data available
      this.mediaRecorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          this.recordedChunks.push(event.data);
          console.log("🎥 Recording chunk received:", event.data.size, "bytes");
        }
      };
      
      // Handle recording stop
      this.mediaRecorder.onstop = () => {
        console.log("🎥 Recording stopped, creating blob...");
        this.createVideoBlob();
      };
      
      // Start recording
      this.mediaRecorder.start(1000); // Collect data every second
      this.recording = true;
      
      // Start progress tracking
      this.startProgressTracking();
      
      console.log("🎥 Recording started successfully");
      
    } catch (error) {
      console.error("🎥 Failed to start recording:", error);
      this.pushEvent("recording_error", { 
        message: "Failed to start recording: " + error.message 
      });
    }
  },

  stopRecording() {
    console.log("🎥 Stopping recording...");
    
    if (this.mediaRecorder && this.recording) {
      this.mediaRecorder.stop();
      this.recording = false;
      this.stopProgressTracking();
      console.log("🎥 Recording stop initiated");
    }
  },

  // FIXED: Progress tracking
  startProgressTracking() {
    this.recordingStartTime = Date.now();
    this.progressInterval = setInterval(() => {
      if (this.recording) {
        const elapsed = Math.floor((Date.now() - this.recordingStartTime) / 1000);
        this.pushEvent("recording_progress", { elapsed: elapsed });
        
        // Auto-stop at 60 seconds
        if (elapsed >= 60) {
          this.stopRecording();
        }
      }
    }, 1000);
  },

  stopProgressTracking() {
    if (this.progressInterval) {
      clearInterval(this.progressInterval);
      this.progressInterval = null;
    }
  },

  // FIXED: Video blob creation and sending
  async createVideoBlob() {
    console.log("🎥 Creating video blob from", this.recordedChunks.length, "chunks");
    
    try {
      const blob = new Blob(this.recordedChunks, { type: 'video/webm' });
      const duration = Math.floor((Date.now() - this.recordingStartTime) / 1000);
      
      console.log("🎥 Video blob created:", blob.size, "bytes, duration:", duration, "seconds");
      
      // Convert to base64 for sending to server
      const reader = new FileReader();
      reader.onload = () => {
        const base64Data = reader.result.split(',')[1]; // Remove data:video/webm;base64,
        
        console.log("🎥 Sending video blob to server...");
        this.pushEvent("video_blob_ready", {
          blob_data: base64Data,
          mime_type: "video/webm",
          file_size: blob.size,
          duration: duration,
          success: true
        });
      };
      
      reader.onerror = () => {
        console.error("🎥 Failed to read video blob");
        this.pushEvent("video_blob_ready", {
          success: false,
          error: "Failed to process video data"
        });
      };
      
      reader.readAsDataURL(blob);
      
      // Set up playback preview
      this.setupPlaybackPreview(blob);
      
    } catch (error) {
      console.error("🎥 Failed to create video blob:", error);
      this.pushEvent("video_blob_ready", {
        success: false,
        error: error.message
      });
    }
  },

  // FIXED: Playback preview
  setupPlaybackPreview(blob) {
    const playbackVideo = this.el.querySelector('#playback-video');
    const loadingDiv = this.el.querySelector('#video-loading');
    
    if (playbackVideo) {
      const url = URL.createObjectURL(blob);
      playbackVideo.src = url;
      
      playbackVideo.onloadeddata = () => {
        console.log("🎥 Playback video loaded");
        if (loadingDiv) {
          loadingDiv.style.display = 'none';
        }
      };
      
      // Clean up URL when done
      playbackVideo.onended = () => {
        URL.revokeObjectURL(url);
      };
    }
  },

  // FIXED: Countdown handling
  startCountdown() {
    console.log("🎥 Starting countdown...");
    let count = 3;
    
    const countdownInterval = setInterval(() => {
      console.log("🎥 Countdown:", count);
      this.pushEvent("countdown_update", { count: count });
      
      count--;
      if (count < 0) {
        clearInterval(countdownInterval);
        console.log("🎥 Countdown finished, auto-starting recording");
        this.startRecording();
      }
    }, 1000);
  },

  destroyed() {
    console.log("🎥 VideoCapture hook destroyed");
    
    // Clean up resources
    this.stopProgressTracking();
    
    if (this.stream) {
      this.stream.getTracks().forEach(track => {
        track.stop();
        console.log("🎥 Stopped track:", track.kind);
      });
    }
    
    if (this.mediaRecorder && this.recording) {
      this.mediaRecorder.stop();
    }
  }
};

export default VideoCapture;