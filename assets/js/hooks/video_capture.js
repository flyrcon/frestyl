// assets/js/hooks/video_capture.js
// Enhanced VideoCapture Hook with tier-based quality and upload support

const VideoCapture = {
  mounted() {
    console.log('🎥 VideoCapture hook mounted');
    
    // Initialize state
    this.mediaRecorder = null;
    this.recordedChunks = [];
    this.recordingInterval = null;
    this.countdownInterval = null;
    this.stream = null;
    this.currentState = 'setup';
    
    // Get user tier and quality settings
    this.userTier = this.el.dataset.userTier || 'free';
    this.qualitySettings = this.getQualitySettings(this.userTier);
    
    console.log(`📊 User tier: ${this.userTier}, Quality: ${this.qualitySettings.height}p`);
    
    // Initialize camera when component mounts
    this.initializeCamera();
    
    // Listen for LiveView events
    this.handleEvent('start_countdown', () => this.startCountdown());
    this.handleEvent('save_video', () => this.prepareVideoBlob());
    this.handleEvent('retake_video', () => this.retakeVideo());
    this.handleEvent('upload_video', () => this.showUploadDialog());
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

  // ============================================================================
  // CAMERA INITIALIZATION
  // ============================================================================
  
  async initializeCamera() {
    try {
      console.log('📷 Requesting camera access...');
      
      const constraints = {
        video: {
          width: { ideal: this.qualitySettings.width },
          height: { ideal: this.qualitySettings.height },
          facingMode: 'user'
        },
        audio: {
          echoCancellation: true,
          noiseSuppression: true,
          sampleRate: 44100
        }
      };

      this.stream = await navigator.mediaDevices.getUserMedia(constraints);
      
      // Set up video preview
      const videoElement = this.el.querySelector('#camera-preview');
      if (videoElement) {
        videoElement.srcObject = this.stream;
        console.log('✅ Camera stream connected');
      }

      // Get actual stream capabilities
      const videoTrack = this.stream.getVideoTracks()[0];
      const settings = videoTrack.getSettings();
      
      console.log('📊 Actual video settings:', {
        width: settings.width,
        height: settings.height,
        frameRate: settings.frameRate
      });

      // Notify component that camera is ready
      this.pushEventTo(this.el, 'camera_ready', {
        videoTracks: this.stream.getVideoTracks().length,
        audioTracks: this.stream.getAudioTracks().length,
        actualWidth: settings.width,
        actualHeight: settings.height
      });

    } catch (error) {
      console.error('❌ Camera initialization failed:', error);
      
      let errorMessage = 'Camera access failed';
      let errorType = 'unknown';
      
      if (error.name === 'NotAllowedError') {
        errorMessage = 'Camera access was denied. Please allow camera access and refresh the page.';
        errorType = 'NotAllowedError';
      } else if (error.name === 'NotFoundError') {
        errorMessage = 'No camera found. Please connect a camera and try again.';
        errorType = 'NotFoundError';
      } else if (error.name === 'NotReadableError') {
        errorMessage = 'Camera is already in use by another application.';
        errorType = 'NotReadableError';
      }

      this.pushEventTo(this.el, 'camera_error', {
        message: errorMessage,
        error: errorType,
        details: error.message
      });
    }
  },

  // ============================================================================
  // RECORDING CONTROLS
  // ============================================================================
  
  startCountdown() {
    console.log('⏱️ Starting countdown...');
    let count = 3;
    
    this.countdownInterval = setInterval(() => {
      console.log(`⏱️ Countdown: ${count}`);
      
      this.pushEventTo(this.el, 'countdown_update', { count });
      
      if (count <= 0) {
        clearInterval(this.countdownInterval);
        this.startRecording();
      }
      count--;
    }, 1000);
  },

  startRecording() {
    if (!this.stream) {
      console.error('❌ No stream available for recording');
      this.pushEventTo(this.el, 'recording_error', {
        message: 'Camera stream not available'
      });
      return;
    }

    try {
      console.log('🔴 Starting recording...');
      
      // Reset recorded chunks
      this.recordedChunks = [];
      
      // Create MediaRecorder with quality settings
      const options = {
        mimeType: this.qualitySettings.mimeType,
        videoBitsPerSecond: this.qualitySettings.videoBitsPerSecond,
        audioBitsPerSecond: this.qualitySettings.audioBitsPerSecond
      };
      
      // Fallback mime types if primary not supported
      if (!MediaRecorder.isTypeSupported(options.mimeType)) {
        if (MediaRecorder.isTypeSupported('video/webm')) {
          options.mimeType = 'video/webm';
        } else if (MediaRecorder.isTypeSupported('video/mp4')) {
          options.mimeType = 'video/mp4';
        } else {
          delete options.mimeType;
        }
      }

      this.mediaRecorder = new MediaRecorder(this.stream, options);
      
      console.log('📊 Recording with options:', options);

      // Set up MediaRecorder event handlers
      this.mediaRecorder.ondataavailable = (event) => {
        if (event.data && event.data.size > 0) {
          this.recordedChunks.push(event.data);
        }
      };

      this.mediaRecorder.onstop = () => {
        console.log('⏹️ Recording stopped');
        this.processRecording();
      };

      this.mediaRecorder.onerror = (event) => {
        console.error('❌ MediaRecorder error:', event.error);
        this.pushEventTo(this.el, 'recording_error', {
          message: 'Recording failed: ' + event.error.message
        });
      };

      // Start recording
      this.mediaRecorder.start(100); // Collect data every 100ms
      
      // Start progress tracking
      let elapsed = 0;
      this.recordingInterval = setInterval(() => {
        elapsed++;
        this.pushEventTo(this.el, 'recording_progress', { elapsed });
        
        // Auto-stop at max duration
        if (elapsed >= this.qualitySettings.maxDuration) {
          this.stopRecording();
        }
      }, 1000);

    } catch (error) {
      console.error('❌ Failed to start recording:', error);
      this.pushEventTo(this.el, 'recording_error', {
        message: 'Failed to start recording: ' + error.message
      });
    }
  },

  stopRecording() {
    console.log('⏹️ Stopping recording...');
    
    if (this.recordingInterval) {
      clearInterval(this.recordingInterval);
      this.recordingInterval = null;
    }
    
    if (this.mediaRecorder && this.mediaRecorder.state === 'recording') {
      this.mediaRecorder.stop();
    }
  },

  processRecording() {
    if (this.recordedChunks.length === 0) {
      console.error('❌ No recorded data available');
      this.pushEventTo(this.el, 'recording_error', {
        message: 'No recorded data available'
      });
      return;
    }

    console.log('🎬 Processing recording...');
    console.log(`📊 Recorded ${this.recordedChunks.length} chunks`);
    
    // Create blob from recorded chunks
    const mimeType = this.mediaRecorder.mimeType || 'video/webm';
    const blob = new Blob(this.recordedChunks, { type: mimeType });
    
    console.log(`📊 Final blob: ${blob.size} bytes, type: ${blob.type}`);
    
    // Create preview URL
    const previewUrl = URL.createObjectURL(blob);
    
    // Set up preview video
    const previewVideo = this.el.querySelector('#video-preview');
    if (previewVideo) {
      previewVideo.src = previewUrl;
      previewVideo.load();
    }
    
    // Store blob for later upload
    this.recordedBlob = blob;
    
    // Generate thumbnail
    this.generateThumbnail(previewUrl);
  },

  // ============================================================================
  // VIDEO UPLOAD PREPARATION
  // ============================================================================
  
  prepareVideoBlob() {
    if (!this.recordedBlob) {
      console.error('❌ No recorded video available');
      this.pushEventTo(this.el, 'recording_error', {
        message: 'No recorded video available'
      });
      return;
    }

    console.log('📤 Preparing video for upload...');
    
    // Convert blob to base64 for transmission
    const reader = new FileReader();
    reader.onload = () => {
      const base64Data = reader.result.split(',')[1]; // Remove data:video/webm;base64, prefix
      
      // Calculate video duration (estimate from recording time)
      const duration = Math.min(this.qualitySettings.maxDuration, 
                               this.recordedChunks.length * 0.1); // Rough estimate
      
      console.log(`📊 Sending video: ${this.recordedBlob.size} bytes, ~${duration}s`);
      
      this.pushEventTo(this.el, 'video_blob_ready', {
        blob_data: base64Data,
        mime_type: this.recordedBlob.type,
        file_size: this.recordedBlob.size,
        duration: duration,
        quality: `${this.qualitySettings.height}p`,
        user_tier: this.userTier
      });
    };
    
    reader.onerror = () => {
      console.error('❌ Failed to read video blob');
      this.pushEventTo(this.el, 'recording_error', {
        message: 'Failed to process video data'
      });
    };
    
    reader.readAsDataURL(this.recordedBlob);
  },

  // ============================================================================
  // VIDEO UPLOAD (PRO FEATURE)
  // ============================================================================
  
  showUploadDialog() {
    if (this.userTier === 'free') {
      alert('Video upload is available for Pro users. Please upgrade your account.');
      return;
    }
    
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = 'video/mp4,video/webm,video/mov';
    input.multiple = false;
    
    input.onchange = (event) => {
      const file = event.target.files[0];
      if (file) {
        this.handleVideoUpload(file);
      }
    };
    
    input.click();
  },

  handleVideoUpload(file) {
    console.log('📂 Processing uploaded video:', file.name);
    
    // Validate file size (max 50MB for pro, 100MB for premium)
    const maxSize = this.userTier === 'premium' ? 100 * 1024 * 1024 : 50 * 1024 * 1024;
    if (file.size > maxSize) {
      alert(`File too large. Maximum size: ${maxSize / (1024 * 1024)}MB`);
      return;
    }
    
    // Validate duration
    const video = document.createElement('video');
    video.preload = 'metadata';
    
    video.onloadedmetadata = () => {
      if (video.duration > this.qualitySettings.maxDuration) {
        alert(`Video too long. Maximum duration: ${this.qualitySettings.maxDuration} seconds`);
        return;
      }
      
      // Convert to base64 for upload
      const reader = new FileReader();
      reader.onload = () => {
        const base64Data = reader.result.split(',')[1];
        
        this.pushEventTo(this.el, 'video_blob_ready', {
          blob_data: base64Data,
          mime_type: file.type,
          file_size: file.size,
          duration: video.duration,
          filename: file.name,
          upload_type: 'file_upload',
          user_tier: this.userTier
        });
      };
      
      reader.readAsDataURL(file);
    };
    
    video.src = URL.createObjectURL(file);
  },

  // ============================================================================
  // THUMBNAIL GENERATION
  // ============================================================================
  
  generateThumbnail(videoUrl) {
    const video = document.createElement('video');
    video.crossOrigin = 'anonymous';
    video.currentTime = 1; // Capture frame at 1 second
    
    video.onloadeddata = () => {
      const canvas = document.createElement('canvas');
      const ctx = canvas.getContext('2d');
      
      canvas.width = 320;
      canvas.height = 180;
      
      ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
      
      canvas.toBlob((blob) => {
        if (blob) {
          const reader = new FileReader();
          reader.onload = () => {
            const thumbnailData = reader.result.split(',')[1];
            console.log('🖼️ Generated video thumbnail');
            
            // Store thumbnail data for later use
            this.thumbnailData = thumbnailData;
          };
          reader.readAsDataURL(blob);
        }
      }, 'image/jpeg', 0.8);
    };
    
    video.src = videoUrl;
  },

  // ============================================================================
  // CLEANUP AND UTILITY
  // ============================================================================
  
  retakeVideo() {
    console.log('🔄 Retaking video...');
    
    // Stop any active recording
    if (this.recordingInterval) {
      clearInterval(this.recordingInterval);
    }
    if (this.countdownInterval) {
      clearInterval(this.countdownInterval);
    }
    if (this.mediaRecorder && this.mediaRecorder.state === 'recording') {
      this.mediaRecorder.stop();
    }
    
    // Clean up recorded data
    this.recordedChunks = [];
    this.recordedBlob = null;
    this.thumbnailData = null;
    
    // Clean up preview
    const previewVideo = this.el.querySelector('#video-preview');
    if (previewVideo) {
      previewVideo.src = '';
    }
    
    console.log('✅ Ready for new recording');
  },

  destroyed() {
    console.log('🧹 Cleaning up VideoCapture hook...');
    
    // Stop recording if active
    if (this.recordingInterval) {
      clearInterval(this.recordingInterval);
    }
    if (this.countdownInterval) {
      clearInterval(this.countdownInterval);
    }
    if (this.mediaRecorder && this.mediaRecorder.state === 'recording') {
      this.mediaRecorder.stop();
    }
    
    // Stop camera stream
    if (this.stream) {
      this.stream.getTracks().forEach(track => {
        track.stop();
        console.log('📷 Stopped camera track');
      });
    }
    
    // Clean up object URLs
    if (this.recordedBlob) {
      URL.revokeObjectURL(this.recordedBlob);
    }
  }
};

export default VideoCapture;