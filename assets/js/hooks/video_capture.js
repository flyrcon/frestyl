// assets/js/hooks/video_capture.js - Enhanced Video Capture Hook

const VideoCapture = {
  mounted() {
    console.log('VideoCapture hook mounted');
    this.componentId = this.el.getAttribute('data-component-id');
    this.stream = null;
    this.mediaRecorder = null;
    this.recordedChunks = [];
    this.recordedBlob = null;
    
    // Initialize camera immediately
    this.initializeCamera();
    
    // Set up event listeners
    this.handleEvent("prepare_recording", () => this.prepareRecording());
    this.handleEvent("start_recording", () => this.startRecording());
    this.handleEvent("stop_recording", () => this.stopRecording());
    this.handleEvent("retake_video", () => this.retakeVideo());
    this.handleEvent("upload_video", () => this.uploadVideo());
  },

  destroyed() {
    console.log('VideoCapture hook destroyed');
    this.cleanup();
  },

  async initializeCamera() {
    console.log('Initializing camera...');
    
    try {
      // Check if getUserMedia is available
      if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
        throw new Error('Camera access not supported in this browser');
      }

      const preview = document.getElementById('camera-preview');
      if (!preview) {
        console.error('Camera preview element not found');
        return;
      }

      // Request camera and microphone access with optimal settings
      const constraints = {
        video: {
          width: { ideal: 1280, max: 1920 },
          height: { ideal: 720, max: 1080 },
          frameRate: { ideal: 30, max: 60 },
          facingMode: 'user' // Front-facing camera
        },
        audio: {
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true
        }
      };

      console.log('Requesting media access with constraints:', constraints);
      
      this.stream = await navigator.mediaDevices.getUserMedia(constraints);
      
      console.log('Media stream acquired successfully');
      console.log('Video tracks:', this.stream.getVideoTracks().length);
      console.log('Audio tracks:', this.stream.getAudioTracks().length);

      // Set up the preview
      preview.srcObject = this.stream;
      preview.muted = true; // Prevent audio feedback
      preview.playsInline = true; // Important for mobile
      
      // Wait for the video to be ready
      preview.addEventListener('loadedmetadata', () => {
        console.log('Video metadata loaded');
        preview.play().then(() => {
          console.log('Preview playing successfully');
          this.pushEventTo(`#video-capture-${this.componentId}`, 'camera_ready', {});
        }).catch(error => {
          console.error('Preview play failed:', error);
          this.handleCameraError('PlaybackError', 'Failed to start video preview');
        });
      });

      preview.addEventListener('error', (event) => {
        console.error('Video element error:', event);
        this.handleCameraError('VideoError', 'Video preview error');
      });
      
    } catch (error) {
      console.error('Camera initialization failed:', error);
      this.handleCameraError(error.name, this.getErrorMessage(error));
    }
  },

  getErrorMessage(error) {
    const errorMessages = {
      'NotAllowedError': 'Camera access was denied. Please allow camera access and refresh the page.',
      'NotFoundError': 'No camera found. Please connect a camera and try again.',
      'NotReadableError': 'Camera is already in use by another application.',
      'OverconstrainedError': 'Camera settings not supported. Trying with basic settings.',
      'SecurityError': 'Camera access blocked due to security settings.',
      'AbortError': 'Camera access was aborted.',
      'TypeError': 'Camera access not supported in this browser.',
      'default': 'Camera access failed. Please check your camera settings and try again.'
    };

    return errorMessages[error.name] || errorMessages['default'];
  },

  handleCameraError(errorName, message) {
    this.pushEventTo(`#video-capture-${this.componentId}`, 'camera_error', {
      error: errorName,
      message: message
    });
  },

  prepareRecording() {
    console.log('Preparing recording...');
    
    if (!this.stream) {
      console.error('No stream available for recording');
      return;
    }

    this.recordedChunks = [];
    
    try {
      // Try different MIME types in order of preference
      const mimeTypes = [
        'video/webm;codecs=vp9,opus',
        'video/webm;codecs=vp8,opus',
        'video/webm;codecs=h264,opus',
        'video/webm',
        'video/mp4'
      ];

      let selectedMimeType = null;
      for (const mimeType of mimeTypes) {
        if (MediaRecorder.isTypeSupported(mimeType)) {
          selectedMimeType = mimeType;
          console.log('Selected MIME type:', mimeType);
          break;
        }
      }

      if (!selectedMimeType) {
        throw new Error('No supported video format found');
      }

      this.mediaRecorder = new MediaRecorder(this.stream, {
        mimeType: selectedMimeType,
        videoBitsPerSecond: 2500000, // 2.5 Mbps
        audioBitsPerSecond: 128000   // 128 kbps
      });

      this.mediaRecorder.ondataavailable = (event) => {
        if (event.data && event.data.size > 0) {
          this.recordedChunks.push(event.data);
          console.log('Data chunk received, size:', event.data.size);
        }
      };

      this.mediaRecorder.onstop = () => {
        console.log('Recording stopped, creating blob...');
        this.createVideoBlob();
      };

      this.mediaRecorder.onerror = (event) => {
        console.error('MediaRecorder error:', event.error);
        this.handleCameraError('RecordingError', 'Recording failed: ' + event.error.message);
      };

      console.log('MediaRecorder prepared successfully');
      
    } catch (error) {
      console.error('Failed to prepare recording:', error);
      this.handleCameraError('PreparationError', error.message);
    }
  },

  startRecording() {
    console.log('Starting recording...');
    
    if (!this.mediaRecorder) {
      console.error('MediaRecorder not prepared');
      return;
    }

    if (this.mediaRecorder.state === 'inactive') {
      try {
        this.mediaRecorder.start(100); // Collect data every 100ms for smooth recording
        console.log('Recording started successfully');
      } catch (error) {
        console.error('Failed to start recording:', error);
        this.handleCameraError('StartError', 'Failed to start recording: ' + error.message);
      }
    } else {
      console.warn('MediaRecorder not in inactive state:', this.mediaRecorder.state);
    }
  },

  stopRecording() {
    console.log('Stopping recording...');
    
    if (this.mediaRecorder && this.mediaRecorder.state === 'recording') {
      try {
        this.mediaRecorder.stop();
        console.log('Recording stop initiated');
      } catch (error) {
        console.error('Failed to stop recording:', error);
        this.handleCameraError('StopError', 'Failed to stop recording: ' + error.message);
      }
    } else {
      console.warn('MediaRecorder not in recording state:', this.mediaRecorder?.state);
    }
  },

  createVideoBlob() {
    try {
      if (this.recordedChunks.length === 0) {
        throw new Error('No recorded data available');
      }

      const mimeType = this.mediaRecorder.mimeType || 'video/webm';
      this.recordedBlob = new Blob(this.recordedChunks, { type: mimeType });
      
      console.log('Video blob created:', {
        size: this.recordedBlob.size,
        type: this.recordedBlob.type,
        chunks: this.recordedChunks.length
      });

      this.showPreview();
      
    } catch (error) {
      console.error('Failed to create video blob:', error);
      this.handleCameraError('BlobError', 'Failed to process recording: ' + error.message);
    }
  },

  showPreview() {
    console.log('Showing video preview...');
    
    const playbackVideo = document.getElementById('playback-video');
    const loadingDiv = document.getElementById('video-loading');
    
    if (!playbackVideo || !loadingDiv) {
      console.error('Preview elements not found');
      return;
    }

    try {
      const videoUrl = URL.createObjectURL(this.recordedBlob);
      
      playbackVideo.src = videoUrl;
      playbackVideo.load(); // Ensure the video loads
      
      playbackVideo.addEventListener('loadeddata', () => {
        console.log('Preview video loaded successfully');
        playbackVideo.style.display = 'block';
        loadingDiv.style.display = 'none';
      });

      playbackVideo.addEventListener('error', (event) => {
        console.error('Preview video error:', event);
        this.handleCameraError('PreviewError', 'Failed to load video preview');
      });
      
    } catch (error) {
      console.error('Failed to create preview:', error);
      this.handleCameraError('PreviewError', 'Failed to create video preview: ' + error.message);
    }
  },

  retakeVideo() {
    console.log('Retaking video...');
    
    // Clear recorded data
    this.recordedChunks = [];
    this.recordedBlob = null;
    
    // Reset preview UI
    const playbackVideo = document.getElementById('playback-video');
    const loadingDiv = document.getElementById('video-loading');
    
    if (playbackVideo && loadingDiv) {
      if (playbackVideo.src) {
        URL.revokeObjectURL(playbackVideo.src); // Clean up object URL
      }
      playbackVideo.src = '';
      playbackVideo.style.display = 'none';
      loadingDiv.style.display = 'flex';
    }
    
    // Reinitialize camera if needed
    if (!this.stream || !this.stream.active) {
      this.initializeCamera();
    }
  },

  async uploadVideo() {
    console.log('Uploading video...');
    
    if (!this.recordedBlob) {
      console.error('No recorded video to upload');
      this.handleCameraError('UploadError', 'No video to upload');
      return;
    }

    try {
      // Convert blob to base64 in chunks to avoid memory issues
      const arrayBuffer = await this.recordedBlob.arrayBuffer();
      const uint8Array = new Uint8Array(arrayBuffer);
      
      // Convert to base64 in chunks to handle large files
      const chunkSize = 1024 * 1024; // 1MB chunks
      let base64String = '';
      
      for (let i = 0; i < uint8Array.length; i += chunkSize) {
        const chunk = uint8Array.slice(i, i + chunkSize);
        const chunkString = String.fromCharCode.apply(null, chunk);
        base64String += btoa(chunkString);
      }

      console.log('Video converted to base64, size:', base64String.length);

      this.pushEventTo(`#video-capture-${this.componentId}`, 'video_blob_ready', {
        blob_data: base64String,
        mime_type: this.recordedBlob.type,
        file_size: this.recordedBlob.size
      });
      
    } catch (error) {
      console.error('Video upload failed:', error);
      this.handleCameraError('UploadError', 'Failed to upload video: ' + error.message);
    }
  },

  cleanup() {
    console.log('Cleaning up video capture...');
    
    // Stop all tracks
    if (this.stream) {
      this.stream.getTracks().forEach(track => {
        console.log('Stopping track:', track.kind);
        track.stop();
      });
      this.stream = null;
    }

    // Clean up MediaRecorder
    if (this.mediaRecorder) {
      if (this.mediaRecorder.state !== 'inactive') {
        this.mediaRecorder.stop();
      }
      this.mediaRecorder = null;
    }

    // Clean up recorded data
    this.recordedChunks = [];
    this.recordedBlob = null;

    // Clean up preview video URLs
    const playbackVideo = document.getElementById('playback-video');
    if (playbackVideo && playbackVideo.src) {
      URL.revokeObjectURL(playbackVideo.src);
    }

    console.log('Video capture cleanup completed');
  }
};

export default VideoCapture;