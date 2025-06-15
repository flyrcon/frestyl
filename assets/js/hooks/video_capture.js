// FIXED: assets/js/hooks/video_capture.js

export default {
  mounted() {
    console.log('🎬 VideoCapture hook mounted!');
    console.log('🔍 Element:', this.el);
    console.log('🆔 Element ID:', this.el.id);
    
    this.componentId = this.el.getAttribute('data-component-id');
    console.log('🏷️ Component ID:', this.componentId);
    
    // Initialize state
    this.stream = null;
    this.mediaRecorder = null;
    this.recordedChunks = [];
    this.recordedBlob = null;
    this.isInitialized = false;
    this.countdownTimer = null;
    this.recordingTimer = null;
    this.elapsedSeconds = 0;
    
    // Initialize camera immediately when hook mounts
    this.initializeCamera();
    
    console.log('✅ VideoCapture hook setup complete');
  },

  destroyed() {
    console.log('VideoCapture hook destroyed');
    this.cleanup();
  },

  // FIXED: Robust camera initialization
  async initializeCamera() {
    console.log('🎥 Starting camera initialization...');
    
    try {
      await this.waitForElement('#camera-preview');
      
      const preview = this.el.querySelector('#camera-preview');
      if (!preview) {
        console.error('❌ Camera preview element not found');
        this.handleCameraError('ElementNotFound', 'Camera preview element not found');
        return;
      }

      if (!navigator.mediaDevices?.getUserMedia) {
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
      
      // Set up preview
      preview.srcObject = this.stream;
      preview.muted = true;
      preview.playsInline = true;
      
      const onVideoReady = () => {
        console.log('🎬 Video metadata loaded, starting playback...');
        
        if (!this.stream?.active) {
          console.error('❌ Stream became inactive during initialization');
          this.handleCameraError('StreamLost', 'Camera stream was lost during initialization');
          return;
        }
        
        const videoTracks = this.stream.getVideoTracks();
        if (!videoTracks?.length) {
          console.error('❌ No video tracks found');
          this.handleCameraError('NoVideoTracks', 'No video tracks available in camera stream');
          return;
        }
        
        preview.play().then(() => {
          console.log('▶️ Preview playing successfully');
          this.isInitialized = true;
          
          // FIXED: Send camera_ready event to the component
          this.pushEventToTarget('camera_ready', {
            success: true,
            videoTracks: videoTracks.length,
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
        
        setTimeout(() => {
          if (!this.isInitialized) {
            console.log('⏰ Video not ready after timeout, trying anyway...');
            onVideoReady();
          }
        }, 3000);
      }
      
    } catch (error) {
      console.error('❌ Camera initialization failed:', error);
      this.handleCameraError(error.name, this.getErrorMessage(error));
    }
  },

  // Helper to wait for DOM elements
  waitForElement(selector, timeout = 5000) {
    return new Promise((resolve, reject) => {
      const element = this.el.querySelector(selector);
      if (element) {
        resolve(element);
        return;
      }

      let attempts = 0;
      const maxAttempts = timeout / 100;
      
      const checkElement = () => {
        attempts++;
        const el = this.el.querySelector(selector);
        
        if (el) {
          resolve(el);
        } else if (attempts >= maxAttempts) {
          reject(new Error(`Element ${selector} not found after ${timeout}ms`));
        } else {
          setTimeout(checkElement, 100);
        }
      };
      
      checkElement();
    });
  },

  // FIXED: Start countdown when button is clicked in component
  startCountdown(duration = 3) {
    console.log(`🎬 Starting countdown: ${duration} seconds`);
    
    if (this.countdownTimer) {
      clearInterval(this.countdownTimer);
    }
    
    if (!this.stream || !this.isInitialized) {
      console.error('❌ Camera not ready for countdown');
      this.handleCameraError('CameraNotReady', 'Camera not ready. Please allow camera access and try again.');
      return;
    }
    
    let count = duration;
    
    // Update UI immediately for first count
    this.updateCountdownUI(count);
    
    this.countdownTimer = setInterval(() => {
      count--;
      console.log(`⏰ Countdown: ${count}`);
      
      if (count > 0) {
        this.updateCountdownUI(count);
      } else {
        console.log('⏰ Countdown finished, starting recording');
        clearInterval(this.countdownTimer);
        this.countdownTimer = null;
        
        // Send countdown finished event
        this.updateCountdownUI(0);
        
        // Start recording immediately after countdown
        setTimeout(() => {
          this.startRecording();
        }, 200);
      }
    }, 1000);
  },

  updateCountdownUI(count) {
    console.log(`🔢 Sending countdown update to component: ${count}`);
    this.pushEventToTarget('countdown_update', { count: count });
  },

  // FIXED: Start recording automatically after countdown
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
          break;
        }
      }
      
      if (!selectedMimeType) {
        throw new Error('No supported video format found');
      }
      
      console.log('🎬 Using MIME type:', selectedMimeType);
      
      const options = {
        mimeType: selectedMimeType,
        videoBitsPerSecond: 2500000,
        audioBitsPerSecond: 128000
      };
      
      this.mediaRecorder = new MediaRecorder(this.stream, options);
      
      this.mediaRecorder.ondataavailable = (event) => {
        if (event.data && event.data.size > 0) {
          this.recordedChunks.push(event.data);
          console.log('📦 Recording chunk:', event.data.size, 'bytes');
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
      
      // Start recording with data collection every 100ms
      this.mediaRecorder.start(100);
      console.log('🎬 MediaRecorder started successfully');
      
      // Start recording timer
      this.recordingTimer = setInterval(() => {
        this.elapsedSeconds++;
        console.log(`⏱️ Recording time: ${this.elapsedSeconds}s`);
        
        // Send progress update to component
        this.pushEventToTarget('recording_progress', {
          elapsed: this.elapsedSeconds,
          maxDuration: 60
        });
        
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

  // FIXED: Stop recording
  stopRecording() {
    console.log('⏹️ Stopping recording...');
    
    // Clear recording timer
    if (this.recordingTimer) {
      clearInterval(this.recordingTimer);
      this.recordingTimer = null;
    }
    
    // Stop media recorder
    if (this.mediaRecorder && this.mediaRecorder.state === 'recording') {
      try {
        this.mediaRecorder.stop();
        console.log('🎬 MediaRecorder stopped');
      } catch (error) {
        console.error('❌ Error stopping recorder:', error);
      }
    }
  },

  // FIXED: Create video blob and show preview
  createVideoBlob() {
    console.log('📦 Creating video blob...');
    
    if (this.recordedChunks.length === 0) {
      console.error('❌ No recorded data');
      this.handleCameraError('NoData', 'No video data was recorded. Please try again.');
      return;
    }
    
    try {
      this.recordedBlob = new Blob(this.recordedChunks, { 
        type: this.mediaRecorder.mimeType || 'video/webm' 
      });
      console.log('✅ Video blob created');
      console.log('📊 Blob size:', this.recordedBlob.size, 'bytes');
      console.log('📊 Blob type:', this.recordedBlob.type);
      
      // Show preview
      this.showVideoPreview();
      
    } catch (error) {
      console.error('❌ Failed to create blob:', error);
      this.handleCameraError('BlobError', 'Failed to process video data: ' + error.message);
    }
  },

  // FIXED: Show video preview
  showVideoPreview() {
    const playbackVideo = this.el.querySelector('#playback-video');
    const loadingDiv = this.el.querySelector('#video-loading');
    
    if (playbackVideo && this.recordedBlob) {
      const videoUrl = URL.createObjectURL(this.recordedBlob);
      
      playbackVideo.addEventListener('loadedmetadata', () => {
        console.log('📺 Playback video loaded successfully');
        if (loadingDiv) {
          loadingDiv.style.display = 'none';
        }
        playbackVideo.currentTime = 0;
      }, { once: true });
      
      playbackVideo.addEventListener('error', (e) => {
        console.error('❌ Playback error:', e);
        if (loadingDiv) {
          loadingDiv.innerHTML = '<div class="text-center"><p class="text-red-500 text-sm">Error loading video preview</p></div>';
        }
      });
      
      playbackVideo.src = videoUrl;
      playbackVideo.load();
      
      // Store URL for cleanup
      this.currentVideoUrl = videoUrl;
    }
  },

  // FIXED: Complete retake functionality
  retakeVideo() {
    console.log('🔄 Retaking video...');
    
    // Clear all timers
    if (this.countdownTimer) {
      clearInterval(this.countdownTimer);
      this.countdownTimer = null;
    }
    
    if (this.recordingTimer) {
      clearInterval(this.recordingTimer);
      this.recordingTimer = null;
    }
    
    // Reset recording state
    this.recordedChunks = [];
    this.elapsedSeconds = 0;
    
    // Clean up recorded blob
    if (this.recordedBlob) {
      if (this.currentVideoUrl) {
        URL.revokeObjectURL(this.currentVideoUrl);
        this.currentVideoUrl = null;
      }
      this.recordedBlob = null;
    }
    
    // Stop media recorder if running
    if (this.mediaRecorder) {
      if (this.mediaRecorder.state !== 'inactive') {
        this.mediaRecorder.stop();
      }
      this.mediaRecorder = null;
    }
    
    // Clear playback video
    const playbackVideo = this.el.querySelector('#playback-video');
    if (playbackVideo) {
      playbackVideo.src = '';
      playbackVideo.load();
    }
    
    // Show loading div again
    const loadingDiv = this.el.querySelector('#video-loading');
    if (loadingDiv) {
      loadingDiv.style.display = 'flex';
      loadingDiv.innerHTML = `
        <div class="text-center">
          <div class="animate-spin w-8 h-8 border-2 border-white border-t-transparent rounded-full mx-auto mb-4"></div>
          <p class="text-white">Loading preview...</p>
        </div>
      `;
    }
    
    // Camera should still be active from initial setup
    console.log('📹 Camera stream should still be active for retake');
  },

  // FIXED: Upload video with proper base64 encoding
  uploadVideo() {
    console.log('⬆️ Uploading video...');
    
    if (!this.recordedBlob) {
      console.error('❌ No video to upload');
      this.pushEventToTarget('video_blob_ready', {
        success: false,
        error: 'No video to upload'
      });
      return;
    }
    
    // Validate blob size (max 50MB)
    const maxSize = 50 * 1024 * 1024;
    if (this.recordedBlob.size > maxSize) {
      console.error('❌ Video too large:', this.recordedBlob.size);
      this.pushEventToTarget('video_blob_ready', {
        success: false,
        error: 'Video file too large. Maximum size is 50MB.'
      });
      return;
    }
    
    console.log('📤 Converting video to base64...');
    
    const reader = new FileReader();
    
    reader.onload = () => {
      try {
        const result = reader.result;
        
        if (!result || typeof result !== 'string') {
          throw new Error('Invalid file reader result');
        }
        
        // Remove data URL prefix to get pure base64
        const base64Data = result.split(',')[1];
        
        if (!base64Data) {
          throw new Error('Failed to extract base64 data');
        }
        
        console.log('✅ Video converted to base64');
        console.log('📊 Base64 length:', base64Data.length);
        
        // Send to component
        this.pushEventToTarget('video_blob_ready', {
          blob_data: base64Data,
          mime_type: this.recordedBlob.type,
          file_size: this.recordedBlob.size,
          duration: this.elapsedSeconds
        });
        
      } catch (error) {
        console.error('❌ Base64 conversion failed:', error);
        this.pushEventToTarget('video_blob_ready', {
          success: false,
          error: 'Failed to process video data: ' + error.message
        });
      }
    };
    
    reader.onerror = () => {
      console.error('❌ FileReader error');
      this.pushEventToTarget('video_blob_ready', {
        success: false,
        error: 'Failed to read video file'
      });
    };
    
    reader.readAsDataURL(this.recordedBlob);
  },

  // FIXED: Handle events from the component
  handleEvent(event, payload) {
    console.log('📡 Received event from component:', event, payload);
    
    switch (event) {
      case 'start_countdown':
        this.startCountdown(3);
        break;
      case 'start_recording':
        this.startRecording();
        break;
      case 'stop_recording':
        this.stopRecording();
        break;
      case 'retake_video':
        this.retakeVideo();
        break;
      case 'upload_video':
        this.uploadVideo();
        break;
      default:
        console.log('⚠️ Unhandled event:', event);
    }
  },

  // FIXED: Push events to the specific component target
  pushEventToTarget(event, payload) {
    console.log(`📤 Pushing event '${event}' to component:`, payload);
    this.pushEvent(event, payload, (reply, ref) => {
      console.log(`📥 Event '${event}' reply:`, reply);
    });
  },

  // FIXED: Error handling with component communication
  handleCameraError(errorName, message) {
    console.error('🚨 Camera Error:', errorName, message);
    
    this.pushEventToTarget('camera_error', {
      error: errorName,
      message: message,
      timestamp: new Date().toISOString()
    });
  },

  // Helper to get user-friendly error messages
  getErrorMessage(error) {
    const errorMessages = {
      'NotAllowedError': 'Camera access was denied. Please allow camera access and refresh the page.',
      'NotFoundError': 'No camera found. Please connect a camera and try again.',
      'NotReadableError': 'Camera is already in use by another application. Please close other apps using the camera.',
      'OverconstrainedError': 'Camera does not support the required settings. Try a different camera.',
      'SecurityError': 'Camera access blocked due to security restrictions. Please check your browser settings.',
      'AbortError': 'Camera access was aborted. Please try again.',
      'TypeError': 'Camera not supported in this browser. Please use a modern browser.',
      'default': 'Camera access failed. Please check your camera settings and try again.'
    };

    return errorMessages[error.name] || errorMessages['default'];
  },

  // FIXED: Complete cleanup
  cleanup() {
    console.log('🧹 Starting video capture cleanup...');
    
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
      try {
        if (this.mediaRecorder.state !== 'inactive') {
          this.mediaRecorder.stop();
        }
      } catch (error) {
        console.warn('⚠️ Error stopping MediaRecorder:', error);
      }
      this.mediaRecorder = null;
    }
    
    // Stop all media tracks
    if (this.stream) {
      this.stream.getTracks().forEach(track => {
        console.log('⏹️ Stopping track:', track.kind, track.label);
        track.stop();
      });
      this.stream = null;
    }

    // Clean up blob URLs
    if (this.currentVideoUrl) {
      try {
        URL.revokeObjectURL(this.currentVideoUrl);
        this.currentVideoUrl = null;
      } catch (error) {
        console.warn('⚠️ Error revoking blob URL:', error);
      }
    }

    // Clean up recorded data
    this.recordedChunks = [];
    this.recordedBlob = null;
    this.elapsedSeconds = 0;
    this.isInitialized = false;
    this.componentId = null;
    
    console.log('✅ Video capture cleanup completed');
  }
};