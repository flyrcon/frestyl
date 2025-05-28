// assets/js/video_capture_hook.js
export const VideoCapture = {
  mounted() {
    this.mediaRecorder = null;
    this.recordedChunks = [];
    this.stream = null;
    this.recordedBlob = null;
    
    // Initialize camera
    this.initCamera();
    
    // Handle events from LiveView
    this.handleEvent("start_countdown", () => this.prepareRecording());
    this.handleEvent("start_recording", () => this.startRecording());
    this.handleEvent("stop_recording", () => this.stopRecording());
    this.handleEvent("retake_video", () => this.retakeVideo());
    this.handleEvent("upload_video", () => this.uploadVideo());
  },

  destroyed() {
    this.cleanup();
  },

  async initCamera() {
    try {
      console.log('Requesting camera access...');
      
      // Request camera access with high quality settings
      this.stream = await navigator.mediaDevices.getUserMedia({
        video: {
          width: { ideal: 1280, max: 1920 },
          height: { ideal: 720, max: 1080 },
          frameRate: { ideal: 30 },
          facingMode: 'user'
        },
        audio: {
          echoCancellation: true,
          noiseSuppression: true,
          sampleRate: 44100
        }
      });

      console.log('Camera access granted');

      // Set up camera preview
      const preview = document.getElementById('camera-preview');
      if (preview) {
        preview.srcObject = this.stream;
        preview.onloadedmetadata = () => {
          preview.play();
          console.log('Camera preview started');
        };
      }

      // Notify LiveView that camera is ready
      this.pushEvent("camera_ready", {});
      
    } catch (error) {
      console.error('Camera access failed:', error);
      this.handleCameraError(error);
    }
  },

  handleCameraError(error) {
    let errorMessage = 'Camera access failed. ';
    
    switch (error.name) {
      case 'NotAllowedError':
        errorMessage += 'Please allow camera and microphone access in your browser settings.';
        break;
      case 'NotFoundError':
        errorMessage += 'No camera or microphone found. Please connect these devices.';
        break;
      case 'NotReadableError':
        errorMessage += 'Camera is being used by another application. Please close other applications and try again.';
        break;
      case 'OverconstrainedError':
        errorMessage += 'Camera does not meet the required specifications.';
        break;
      case 'SecurityError':
        errorMessage += 'Camera access blocked due to security settings. Please use HTTPS.';
        break;
      default:
        errorMessage += `Error: ${error.message}`;
    }

    this.showError(errorMessage);
    
    // Try to notify the LiveView about the error
    this.pushEvent("camera_error", { error: error.name, message: errorMessage });
  },

  prepareRecording() {
    if (!this.stream) {
      this.showError('Camera not available');
      return;
    }

    try {
      // Set up MediaRecorder with optimal settings
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
          console.log('Selected MIME type:', selectedMimeType);
          break;
        }
      }

      if (!selectedMimeType) {
        throw new Error('No supported video format found');
      }

      const options = {
        mimeType: selectedMimeType,
        videoBitsPerSecond: 2500000, // 2.5 Mbps
        audioBitsPerSecond: 128000   // 128 kbps
      };

      this.mediaRecorder = new MediaRecorder(this.stream, options);
      this.recordedChunks = [];

      // Handle data available event
      this.mediaRecorder.ondataavailable = (event) => {
        if (event.data && event.data.size > 0) {
          this.recordedChunks.push(event.data);
          console.log('Recording chunk received:', event.data.size, 'bytes');
        }
      };

      // Handle recording stop
      this.mediaRecorder.onstop = () => {
        console.log('Recording stopped, processing...');
        this.processRecording();
      };

      // Handle errors
      this.mediaRecorder.onerror = (event) => {
        console.error('MediaRecorder error:', event);
        this.showError('Recording error occurred. Please try again.');
      };

      console.log('MediaRecorder prepared successfully');

    } catch (error) {
      console.error('MediaRecorder setup failed:', error);
      this.showError('Recording setup failed. Please try again.');
    }
  },

  startRecording() {
    if (!this.mediaRecorder) {
      this.showError('Recording not prepared');
      return;
    }

    try {
      this.recordedChunks = [];
      this.mediaRecorder.start(1000); // Collect data every second
      console.log('Recording started');
    } catch (error) {
      console.error('Recording start failed:', error);
      this.showError('Failed to start recording');
    }
  },

  stopRecording() {
    if (this.mediaRecorder && this.mediaRecorder.state === 'recording') {
      this.mediaRecorder.stop();
      console.log('Recording stop requested');
    }
  },

  async processRecording() {
    if (this.recordedChunks.length === 0) {
      this.showError('No recording data available');
      return;
    }

    try {
      // Create blob from recorded chunks
      const mimeType = this.mediaRecorder.mimeType || 'video/webm';
      this.recordedBlob = new Blob(this.recordedChunks, { type: mimeType });
      
      console.log('Recording processed:', {
        size: this.recordedBlob.size,
        type: this.recordedBlob.type,
        chunks: this.recordedChunks.length
      });
      
      // Show preview
      const playbackVideo = document.getElementById('playback-video');
      if (playbackVideo) {
        const videoURL = URL.createObjectURL(this.recordedBlob);
        playbackVideo.src = videoURL;
        playbackVideo.onloadeddata = () => {
          console.log('Preview video loaded');
        };
      }

      // Stop camera stream to save resources during preview
      this.stopCameraStream();

    } catch (error) {
      console.error('Processing recording failed:', error);
      this.showError('Failed to process recording');
    }
  },

  async uploadVideo() {
    if (!this.recordedBlob) {
      this.showError('No video to upload');
      return;
    }

    try {
      console.log('Starting video upload...', {
        size: this.recordedBlob.size,
        type: this.recordedBlob.type
      });

      // Convert to base64 for transmission to LiveView
      const base64Data = await this.blobToBase64(this.recordedBlob);
      
      // Send to LiveView component
      this.pushEvent("video_blob_ready", {
        blob_data: base64Data.split(',')[1], // Remove data:video/webm;base64, prefix
        mime_type: this.recordedBlob.type,
        file_size: this.recordedBlob.size
      });

      console.log('Video data sent to LiveView');

    } catch (error) {
      console.error('Upload failed:', error);
      this.showError('Failed to upload video. Please try again.');
    }
  },

  blobToBase64(blob) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onloadend = () => resolve(reader.result);
      reader.onerror = (error) => {
        console.error('FileReader error:', error);
        reject(error);
      };
      reader.readAsDataURL(blob);
    });
  },

  retakeVideo() {
    console.log('Retaking video...');
    
    // Clean up previous recording
    this.recordedChunks = [];
    this.recordedBlob = null;
    
    // Reset video elements
    const playbackVideo = document.getElementById('playback-video');
    if (playbackVideo) {
      URL.revokeObjectURL(playbackVideo.src);
      playbackVideo.src = '';
    }

    // Restart camera
    this.initCamera();
  },

  stopCameraStream() {
    if (this.stream) {
      this.stream.getTracks().forEach(track => {
        track.stop();
        console.log('Stopped track:', track.kind);
      });
      // Don't set stream to null here as we might need to restart it for retake
    }
  },

  cleanup() {
    console.log('Cleaning up video capture...');
    
    // Stop all tracks
    if (this.stream) {
      this.stream.getTracks().forEach(track => track.stop());
      this.stream = null;
    }

    // Clean up MediaRecorder
    if (this.mediaRecorder) {
      if (this.mediaRecorder.state === 'recording') {
        this.mediaRecorder.stop();
      }
      this.mediaRecorder = null;
    }

    // Clean up recorded data
    this.recordedChunks = [];
    this.recordedBlob = null;

    // Clean up video elements
    const preview = document.getElementById('camera-preview');
    const playback = document.getElementById('playback-video');
    
    if (preview) {
      preview.srcObject = null;
    }
    
    if (playback && playback.src) {
      URL.revokeObjectURL(playback.src);
      playback.src = '';
    }

    console.log('Video capture cleanup complete');
  },

  showError(message) {
    console.error('Video capture error:', message);
    // Show user-friendly error message
    alert(message);
  }
};

// Inject styles if in browser environment
if (typeof document !== 'undefined') {
  const styleSheet = document.createElement('style');
  styleSheet.textContent = videoCaptureStyles;
  document.head.appendChild(styleSheet);
}