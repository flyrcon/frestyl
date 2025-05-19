// Create assets/js/hooks/stream_quality.js
const StreamQualityHook = {
  mounted() {
    this.stream = null;
    this.pc = null; // WebRTC peer connection
    this.statsInterval = null;
    
    // If rtcClient is initialized when this hook mounts, get the connection
    if (window.rtcClient && Object.keys(window.rtcClient.peerConnections).length > 0) {
      const firstPeerId = Object.keys(window.rtcClient.peerConnections)[0];
      this.setPeerConnection(window.rtcClient.peerConnections[firstPeerId]);
    }
    
    // Listen for quality change events from the server
    this.handleEvent("set_quality", ({ quality }) => {
      console.log(`Setting stream quality to: ${quality}`);
      this.setQuality(quality);
    });
    
    // Listen for audio only mode
    this.handleEvent("toggle_audio_only", ({ enabled }) => {
      console.log(`Setting audio only mode: ${enabled}`);
      this.setAudioOnly(enabled);
    });
  },
  
  destroyed() {
    // Clean up
    if (this.statsInterval) {
      clearInterval(this.statsInterval);
    }
  },
  
  setQuality(quality) {
    if (!this.pc) {
      console.warn("No peer connection available");
      return;
    }
    
    // Get all video senders
    const senders = this.pc.getSenders();
    const videoSender = senders.find(sender => sender.track && sender.track.kind === 'video');
    
    if (!videoSender) {
      console.warn("No video sender found");
      return;
    }
    
    const parameters = videoSender.getParameters();
    
    if (!parameters.encodings || parameters.encodings.length === 0) {
      parameters.encodings = [{}];
    }
    
    // Set quality parameters
    switch (quality) {
      case 'low':
        parameters.encodings[0].maxBitrate = 250000; // 250 kbps
        parameters.encodings[0].scaleResolutionDownBy = 4.0; // 240p
        break;
      case 'medium':
        parameters.encodings[0].maxBitrate = 500000; // 500 kbps
        parameters.encodings[0].scaleResolutionDownBy = 2.0; // 360p
        break;
      case 'high':
        parameters.encodings[0].maxBitrate = 1500000; // 1.5 Mbps
        parameters.encodings[0].scaleResolutionDownBy = 1.5; // 720p
        break;
      case 'hd':
        parameters.encodings[0].maxBitrate = 3000000; // 3 Mbps
        parameters.encodings[0].scaleResolutionDownBy = 1.0; // 1080p
        break;
      case 'ultra':
        parameters.encodings[0].maxBitrate = 6000000; // 6 Mbps
        parameters.encodings[0].scaleResolutionDownBy = 0.75; // 1440p
        break;
      case 'auto':
      default:
        // Auto mode - remove restrictions
        delete parameters.encodings[0].maxBitrate;
        delete parameters.encodings[0].scaleResolutionDownBy;
        break;
    }
    
    // Apply the changes
    videoSender.setParameters(parameters)
      .then(() => console.log(`Applied quality settings: ${quality}`))
      .catch(error => console.error("Error setting quality parameters:", error));
  },
  
  setAudioOnly(enabled) {
    if (!window.rtcClient) {
      console.warn("No RTC client available");
      return;
    }
    
    // Get the video element
    const videoElement = document.getElementById("broadcast-video");
    
    if (enabled) {
      // Turn off video tracks
      if (window.rtcClient.localStream) {
        const videoTracks = window.rtcClient.localStream.getVideoTracks();
        videoTracks.forEach(track => track.enabled = false);
      }
      
      // Hide video element
      if (videoElement) {
        videoElement.style.display = 'none';
      }
    } else {
      // Turn on video tracks
      if (window.rtcClient.localStream) {
        const videoTracks = window.rtcClient.localStream.getVideoTracks();
        videoTracks.forEach(track => track.enabled = true);
      }
      
      // Show video element
      if (videoElement) {
        videoElement.style.display = 'block';
      }
    }
  },
  
  // Method to set the peer connection reference (called from your WebRTC setup code)
  setPeerConnection(pc) {
    this.pc = pc;
  }
};

export default StreamQualityHook;