// assets/js/hooks/video_capture.js - COMPLETELY FIXED VERSION

const VideoCapture = {
  mounted() {
    console.log('🎬 VideoCapture hook mounted!');
    console.log('🔍 Element:', this.el);
    console.log('🆔 Element ID:', this.el.id);
    console.log('🏷️ Component ID:', this.el.getAttribute('data-component-id'));
    
    this.componentId = this.el.getAttribute('data-component-id');
    this.stream = null;
    this.mediaRecorder = null;
    this.recordedChunks = [];
    this.recordedBlob = null;
    this.isInitialized = false;
    this.countdownTimer = null;
    this.recordingTimer = null;
    this.elapsedSeconds = 0;
    
    // Initialize camera immediately
    this.initializeCamera();
    
    console.log('✅ VideoCapture hook setup complete for:', this.el.id);
  },

  destroyed() {
    console.log('VideoCapture hook destroyed');
    this.cleanup();
  },

  // FIXED: Proper camera initialization with better error handling
  async initializeCamera() {
    console.log('🎥 Initializing camera...');
    
    try {
      const preview = document.getElementById('camera-preview');
      if (!preview) {
        console.error('❌ Camera preview element not found');
        setTimeout(() => this.initializeCamera(), 500);
        return;
      }

      if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
        throw new Error('Camera access not supported in this browser');
      }

      console.log('📹 Requesting camera access...');

      const constraints = {
        video: {
          width: { ideal: 1280, max: 1920 },
          height: { ideal: 720, max: 1080 },
          frameRate: { ideal: 30, max: 60 },
          facingMode: 'user'
        },
        audio: {
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
          sampleRate: 44100
        }
      };

      this.stream = await navigator.mediaDevices.getUserMedia(constraints);
      
      console.log('✅ Media stream acquired successfully');
      preview.srcObject = this.stream;
      preview.muted = true;
      preview.playsInline = true;
      
      const onVideoReady = () => {
        console.log('🎬 Video metadata loaded, starting playback...');
        preview.play().then(() => {
          console.log('▶️ Preview playing successfully');
          this.isInitialized = true;
          
          // FIXED: Send camera_ready event to component
          this.pushEvent('camera_ready', {
            videoTracks: this.stream.getVideoTracks().length,
            audioTracks: this.stream.getAudioTracks().length
          });
          
        }).catch(error => {
          console.error('❌ Preview play failed:', error);
          this.handleCameraError('PlaybackError', 'Failed to start video preview: ' + error.message);
        });
      };

      if (preview.readyState >= 2) {
        onVideoReady();
      } else {
        preview.addEventListener('loadedmetadata', onVideoReady, { once: true });
      }
      
    } catch (error) {
      console.error('❌ Camera initialization failed:', error);
      this.handleCameraError(error.name, this.getErrorMessage(error));
    }
  },

  // FIXED: Proper countdown implementation
  startCountdown(duration = 3) {
    console.log(`🎬 Starting countdown with duration: ${duration} seconds`);
    
    if (this.countdownTimer) {
      clearInterval(this.countdownTimer);
    }
    
    let count = duration;
    
    // Send countdown updates to component
    this.countdownTimer = setInterval(() => {
      count--;
      console.log(`⏰ Countdown tick: ${count}`);
      
      if (count <= 0) {
        console.log('⏰ Countdown finished, starting recording');
        clearInterval(this.countdownTimer);
        this.countdownTimer = null;
        
        // Auto-start recording after countdown
        setTimeout(() => {
          console.log('🔴 Auto-starting recording after countdown');
          this.startRecording();
        }, 500);
      }
    }, 1000);
  },

  // FIXED: Proper recording implementation
  startRecording() {
    console.log('🔴 Starting recording...');
    
    if (!this.stream) {
      console.error('❌ No stream available');
      this.handleCameraError('NoStream', 'Camera stream not available. Please refresh and try again.');
      return;
    }
    
    try {
      this.recordedChunks = [];
      this.elapsedSeconds = 0;
      
      const options = {
        mimeType: 'video/webm;codecs=vp9,opus'
      };
      
      if (!MediaRecorder.isTypeSupported(options.mimeType)) {
        options.mimeType = 'video/webm';
      }
      
      this.mediaRecorder = new MediaRecorder(this.stream, options);
      
      this.mediaRecorder.ondataavailable = (event) => {
        if (event.data && event.data.size > 0) {
          this.recordedChunks.push(event.data);
          console.log('📦 Recording chunk received:', event.data.size, 'bytes');
        }
      };
      
      this.mediaRecorder.onstop = () => {
        console.log('⏹️ Recording stopped, creating blob...');
        this.createVideoBlob();
      };

      this.mediaRecorder.onerror = (event) => {
        console.error('❌ MediaRecorder error:', event.error);
        this.handleCameraError('RecordingError', 'Recording failed: ' + event.error.message);
      };
      
      this.mediaRecorder.start(100); // Collect data every 100ms
      console.log('🎬 MediaRecorder started');
      
      // Start recording timer
      this.recordingTimer = setInterval(() => {
        this.elapsedSeconds++;
        console.log(`⏱️ Recording time: ${this.elapsedSeconds}s`);
        
        // Auto-stop at 60 seconds
        if (this.elapsedSeconds >= 60) {
          console.log('⏰ Auto-stopping at 60 seconds');
          this.stopRecording();
        }
      }, 1000);
      
    } catch (error) {
      console.error('❌ Failed to start recording:', error);
      this.handleCameraError('RecordingError', 'Failed to start recording: ' + error.message);
    }
  },

  // FIXED: Proper stop recording
  stopRecording() {
    console.log('⏹️ Stopping recording...');
    
    if (this.recordingTimer) {
      clearInterval(this.recordingTimer);
      this.recordingTimer = null;
    }
    
    if (this.mediaRecorder && this.mediaRecorder.state === 'recording') {
      this.mediaRecorder.stop();
      console.log('🎬 MediaRecorder stopped');
    }
  },

  // FIXED: Create video blob with proper preview
  createVideoBlob() {
    console.log('📦 Creating video blob...');
    
    if (this.recordedChunks.length === 0) {
      console.error('❌ No recorded data');
      this.handleCameraError('NoData', 'No video data was recorded. Please try again.');
      return;
    }
    
    this.recordedBlob = new Blob(this.recordedChunks, { type: 'video/webm' });
    console.log('✅ Video blob created, size:', this.recordedBlob.size);
    
    // Show preview
    const playbackVideo = document.getElementById('playback-video');
    const loadingDiv = document.getElementById('video-loading');
    
    if (playbackVideo) {
      const videoUrl = URL.createObjectURL(this.recordedBlob);
      playbackVideo.src = videoUrl;
      
      playbackVideo.addEventListener('loadedmetadata', () => {
        console.log('📺 Playback video loaded');
        if (loadingDiv) {
          loadingDiv.style.display = 'none';
        }
      }, { once: true });
      
      playbackVideo.addEventListener('error', (e) => {
        console.error('❌ Playback error:', e);
        if (loadingDiv) {
          loadingDiv.innerHTML = '<p class="text-red-500">Error loading video preview</p>';
        }
      });
      
      playbackVideo.load();
    }
  },

  // FIXED: Retake video functionality
  retakeVideo() {
    console.log('🔄 Retaking video...');
    
    // Clear timers
    if (this.countdownTimer) {
      clearInterval(this.countdownTimer);
      this.countdownTimer = null;
    }
    
    if (this.recordingTimer) {
      clearInterval(this.recordingTimer);
      this.recordingTimer = null;
    }
    
    // Clear recorded data
    this.recordedChunks = [];
    this.elapsedSeconds = 0;
    
    if (this.recordedBlob) {
      URL.revokeObjectURL(this.recordedBlob);
      this.recordedBlob = null;
    }
    
    // Clear playback video
    const playbackVideo = document.getElementById('playback-video');
    if (playbackVideo) {
      playbackVideo.src = '';
      playbackVideo.load();
    }
    
    // Show loading div again
    const loadingDiv = document.getElementById('video-loading');
    if (loadingDiv) {
      loadingDiv.style.display = 'flex';
    }
    
    // Reinitialize camera if needed
    if (!this.stream || !this.stream.active) {
      this.initializeCamera();
    }
  },

  // FIXED: Upload video with proper base64 encoding
  uploadVideo() {
    console.log('⬆️ Uploading video...');
    
    if (!this.recordedBlob) {
      console.error('❌ No video to upload');
      this.pushEvent("video_blob_ready", {
        success: false,
        error: "No video to upload"
      });
      return;
    }
    
    // Convert blob to base64
    const reader = new FileReader();
    reader.onload = () => {
      const base64Data = reader.result.split(',')[1]; // Remove data:video/webm;base64, prefix
      
      console.log('📤 Sending video data to server...');
      this.pushEvent("video_blob_ready", {
        blob_data: base64Data,
        mime_type: this.recordedBlob.type,
        file_size: this.recordedBlob.size
      });
    };
    
    reader.onerror = () => {
      console.error('❌ Failed to read video blob');
      this.pushEvent("video_blob_ready", {
        success: false,
        error: "Failed to process video data"
      });
    };
    
    reader.readAsDataURL(this.recordedBlob);
  },

  // Error handling
  getErrorMessage(error) {
    const errorMessages = {
      'NotAllowedError': 'Camera access was denied. Please allow camera access and refresh the page.',
      'NotFoundError': 'No camera found. Please connect a camera and try again.',
      'NotReadableError': 'Camera is already in use by another application.',
      'OverconstrainedError': 'Camera does not support the required settings.',
      'SecurityError': 'Camera access blocked due to security restrictions.',
      'AbortError': 'Camera access was aborted.',
      'default': 'Camera access failed. Please check your camera settings and try again.'
    };

    return errorMessages[error.name] || errorMessages['default'];
  },

  handleCameraError(errorName, message) {
    console.error('🚨 Camera Error:', errorName, message);
    this.pushEvent('camera_error', {
      error: errorName,
      message: message
    });
  },

  // FIXED: Cleanup function
  cleanup() {
    console.log('🧹 Cleaning up video capture...');
    
    // Clear all timers
    if (this.countdownTimer) {
      clearInterval(this.countdownTimer);
      this.countdownTimer = null;
    }
    
    if (this.recordingTimer) {
      clearInterval(this.recordingTimer);
      this.recordingTimer = null;
    }
    
    // Stop media recorder
    if (this.mediaRecorder) {
      if (this.mediaRecorder.state !== 'inactive') {
        this.mediaRecorder.stop();
      }
      this.mediaRecorder = null;
    }
    
    // Stop all media tracks
    if (this.stream) {
      this.stream.getTracks().forEach(track => {
        console.log('⏹️ Stopping track:', track.kind);
        track.stop();
      });
      this.stream = null;
    }

    // Clean up recorded data
    this.recordedChunks = [];
    this.elapsedSeconds = 0;
    
    if (this.recordedBlob) {
      URL.revokeObjectURL(this.recordedBlob);
      this.recordedBlob = null;
    }

    this.isInitialized = false;
    console.log('✅ Video capture cleanup completed');
  }
};

export default VideoCapture;