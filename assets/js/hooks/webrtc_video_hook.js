// assets/js/hooks/webrtc_video_hook.js
export const WebRTCVideoHook = {
  mounted() {
    this.broadcastId = this.el.dataset.broadcastId;
    this.userId = this.el.dataset.userId;
    this.isHost = this.el.dataset.isHost === "true";
    
    // WebRTC configuration with STUN/TURN servers
    this.rtcConfig = {
      iceServers: [
        { urls: 'stun:stun.l.google.com:19302' },
        { urls: 'stun:stun1.l.google.com:19302' },
        // Add TURN servers for production
        // { 
        //   urls: 'turn:your-turn-server.com:3478',
        //   username: 'username',
        //   credential: 'password'
        // }
      ],
      iceCandidatePoolSize: 10
    };

    // Core WebRTC objects
    this.localPeerConnection = null;
    this.remotePeerConnections = new Map();
    this.localStream = null;
    this.remoteStreams = new Map();
    
    // Video elements
    this.localVideo = null;
    this.remoteVideoContainer = null;
    
    // State management
    this.isStreaming = false;
    this.connectionStates = new Map();
    
    // Initialize video elements
    this.initializeVideoElements();
    
    // Set up Phoenix event handlers
    this.setupPhoenixEvents();
    
    // Start as host if applicable
    if (this.isHost) {
      this.initializeHostStream();
    }

    console.log('WebRTC Video Hook initialized for broadcast:', this.broadcastId);
  },

  destroyed() {
    this.cleanup();
  },

  initializeVideoElements() {
    // Create local video element
    this.localVideo = document.createElement('video');
    this.localVideo.autoplay = true;
    this.localVideo.muted = true; // Prevent audio feedback
    this.localVideo.playsInline = true;
    this.localVideo.className = 'w-full h-full object-cover rounded-lg';
    this.localVideo.id = 'local-video';

    // Create remote video container
    this.remoteVideoContainer = document.createElement('div');
    this.remoteVideoContainer.className = 'remote-videos-grid grid grid-cols-2 gap-4';
    this.remoteVideoContainer.id = 'remote-videos';

    // Add to DOM
    const localVideoContainer = this.el.querySelector('#local-video-container');
    const remoteVideosContainer = this.el.querySelector('#remote-videos-container');
    
    if (localVideoContainer) {
      localVideoContainer.appendChild(this.localVideo);
    }
    
    if (remoteVideosContainer) {
      remoteVideosContainer.appendChild(this.remoteVideoContainer);
    }
  },

  setupPhoenixEvents() {
    // Handle Phoenix LiveView events
    this.handleEvent("start_video_stream", this.startVideoStream.bind(this));
    this.handleEvent("stop_video_stream", this.stopVideoStream.bind(this));
    this.handleEvent("join_as_viewer", this.joinAsViewer.bind(this));
    this.handleEvent("viewer_joined", this.handleViewerJoined.bind(this));
    this.handleEvent("viewer_left", this.handleViewerLeft.bind(this));
    this.handleEvent("webrtc_offer", this.handleOffer.bind(this));
    this.handleEvent("webrtc_answer", this.handleAnswer.bind(this));
    this.handleEvent("webrtc_ice_candidate", this.handleIceCandidate.bind(this));
    this.handleEvent("stream_quality_change", this.handleQualityChange.bind(this));
  },

  async initializeHostStream() {
    try {
      // Request user media with video constraints
      const constraints = {
        video: {
          width: { ideal: 1920, max: 1920 },
          height: { ideal: 1080, max: 1080 },
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

      this.localStream = await navigator.mediaDevices.getUserMedia(constraints);
      this.localVideo.srcObject = this.localStream;

      // Notify Phoenix that local stream is ready
      this.pushEvent("local_stream_ready", {
        hasVideo: this.localStream.getVideoTracks().length > 0,
        hasAudio: this.localStream.getAudioTracks().length > 0
      });

      console.log('Host stream initialized');
    } catch (error) {
      console.error('Failed to initialize host stream:', error);
      this.pushEvent("stream_error", { 
        error: "Failed to access camera/microphone",
        details: error.message 
      });
    }
  },

  async startVideoStream() {
    if (!this.isHost || !this.localStream) {
      console.error('Cannot start stream: not host or no local stream');
      return;
    }

    try {
      this.isStreaming = true;
      
      // Start local peer connection for host
      await this.createLocalPeerConnection();
      
      // Notify Phoenix that streaming has started
      this.pushEvent("video_stream_started", {
        broadcastId: this.broadcastId,
        streamConfig: this.getStreamConfig()
      });

      console.log('Video streaming started');
    } catch (error) {
      console.error('Failed to start video stream:', error);
      this.pushEvent("stream_error", { error: error.message });
    }
  },

  async stopVideoStream() {
    try {
      this.isStreaming = false;
      
      // Close all peer connections
      if (this.localPeerConnection) {
        this.localPeerConnection.close();
        this.localPeerConnection = null;
      }

      this.remotePeerConnections.forEach(pc => pc.close());
      this.remotePeerConnections.clear();

      // Stop local stream
      if (this.localStream) {
        this.localStream.getTracks().forEach(track => track.stop());
        this.localStream = null;
        this.localVideo.srcObject = null;
      }

      // Clear remote videos
      this.clearRemoteVideos();

      // Notify Phoenix
      this.pushEvent("video_stream_stopped", {
        broadcastId: this.broadcastId
      });

      console.log('Video streaming stopped');
    } catch (error) {
      console.error('Error stopping video stream:', error);
    }
  },

  async joinAsViewer() {
    try {
      // Create peer connection to receive host stream
      const peerConnection = new RTCPeerConnection(this.rtcConfig);
      this.remotePeerConnections.set('host', peerConnection);

      // Set up event handlers for this connection
      this.setupPeerConnectionHandlers(peerConnection, 'host');

      // Request to join the broadcast
      this.pushEvent("request_to_join_broadcast", {
        broadcastId: this.broadcastId,
        userId: this.userId
      });

      console.log('Joining as viewer');
    } catch (error) {
      console.error('Failed to join as viewer:', error);
      this.pushEvent("join_error", { error: error.message });
    }
  },

  async handleViewerJoined({ viewer_id }) {
    if (!this.isHost || !this.localStream) return;

    try {
      // Create peer connection for this viewer
      const peerConnection = new RTCPeerConnection(this.rtcConfig);
      this.remotePeerConnections.set(viewer_id, peerConnection);

      // Add local stream tracks to this connection
      this.localStream.getTracks().forEach(track => {
        peerConnection.addTrack(track, this.localStream);
      });

      // Set up event handlers
      this.setupPeerConnectionHandlers(peerConnection, viewer_id);

      // Create and send offer
      const offer = await peerConnection.createOffer();
      await peerConnection.setLocalDescription(offer);

      this.pushEvent("send_webrtc_offer", {
        target_user_id: viewer_id,
        offer: offer
      });

      console.log('Created offer for viewer:', viewer_id);
    } catch (error) {
      console.error('Failed to handle viewer joined:', error);
    }
  },

  async handleOffer({ from_user_id, offer }) {
    try {
      const peerConnection = this.remotePeerConnections.get(from_user_id) || 
                            new RTCPeerConnection(this.rtcConfig);
      
      if (!this.remotePeerConnections.has(from_user_id)) {
        this.remotePeerConnections.set(from_user_id, peerConnection);
        this.setupPeerConnectionHandlers(peerConnection, from_user_id);
      }

      await peerConnection.setRemoteDescription(new RTCSessionDescription(offer));

      // Create answer
      const answer = await peerConnection.createAnswer();
      await peerConnection.setLocalDescription(answer);

      this.pushEvent("send_webrtc_answer", {
        target_user_id: from_user_id,
        answer: answer
      });

      console.log('Sent answer to:', from_user_id);
    } catch (error) {
      console.error('Failed to handle offer:', error);
    }
  },

  async handleAnswer({ from_user_id, answer }) {
    try {
      const peerConnection = this.remotePeerConnections.get(from_user_id);
      if (peerConnection) {
        await peerConnection.setRemoteDescription(new RTCSessionDescription(answer));
        console.log('Received answer from:', from_user_id);
      }
    } catch (error) {
      console.error('Failed to handle answer:', error);
    }
  },

  async handleIceCandidate({ from_user_id, candidate }) {
    try {
      const peerConnection = this.remotePeerConnections.get(from_user_id);
      if (peerConnection && candidate) {
        await peerConnection.addIceCandidate(new RTCIceCandidate(candidate));
      }
    } catch (error) {
      console.error('Failed to handle ICE candidate:', error);
    }
  },

  setupPeerConnectionHandlers(peerConnection, peerId) {
    // ICE candidate handling
    peerConnection.onicecandidate = (event) => {
      if (event.candidate) {
        this.pushEvent("send_ice_candidate", {
          target_user_id: peerId,
          candidate: event.candidate
        });
      }
    };

    // Connection state monitoring
    peerConnection.onconnectionstatechange = () => {
      const state = peerConnection.connectionState;
      this.connectionStates.set(peerId, state);
      
      console.log(`Connection with ${peerId}: ${state}`);
      
      if (state === 'failed' || state === 'disconnected') {
        this.handleConnectionFailure(peerId);
      }
    };

    // Remote stream handling (for viewers)
    peerConnection.ontrack = (event) => {
      const [remoteStream] = event.streams;
      this.handleRemoteStream(peerId, remoteStream);
    };

    // Data channel for chat/controls (optional)
    if (this.isHost) {
      const dataChannel = peerConnection.createDataChannel('controls');
      this.setupDataChannel(dataChannel, peerId);
    }
  },

  handleRemoteStream(peerId, stream) {
    // Store the remote stream
    this.remoteStreams.set(peerId, stream);

    // Create video element for remote stream
    const remoteVideo = document.createElement('video');
    remoteVideo.autoplay = true;
    remoteVideo.playsInline = true;
    remoteVideo.className = 'w-full h-full object-cover rounded-lg';
    remoteVideo.id = `remote-video-${peerId}`;
    remoteVideo.srcObject = stream;

    // Create container with controls
    const videoContainer = document.createElement('div');
    videoContainer.className = 'relative bg-gray-900 rounded-lg overflow-hidden';
    videoContainer.id = `remote-container-${peerId}`;

    // Add peer info overlay
    const peerInfo = document.createElement('div');
    peerInfo.className = 'absolute top-2 left-2 bg-black bg-opacity-50 text-white px-2 py-1 rounded text-sm';
    peerInfo.textContent = `Viewer ${peerId.substring(0, 8)}`;

    videoContainer.appendChild(remoteVideo);
    videoContainer.appendChild(peerInfo);
    this.remoteVideoContainer.appendChild(videoContainer);

    console.log('Added remote video for peer:', peerId);
  },

  handleViewerLeft({ viewer_id }) {
    // Close peer connection
    const peerConnection = this.remotePeerConnections.get(viewer_id);
    if (peerConnection) {
      peerConnection.close();
      this.remotePeerConnections.delete(viewer_id);
    }

    // Remove remote stream and video element
    this.remoteStreams.delete(viewer_id);
    const videoContainer = document.getElementById(`remote-container-${viewer_id}`);
    if (videoContainer) {
      videoContainer.remove();
    }

    console.log('Viewer left:', viewer_id);
  },

  handleConnectionFailure(peerId) {
    console.log('Connection failed with peer:', peerId);
    
    // Attempt reconnection after delay
    setTimeout(() => {
      if (this.isStreaming) {
        this.attemptReconnection(peerId);
      }
    }, 2000);
  },

  async attemptReconnection(peerId) {
    try {
      // Close existing connection
      const oldConnection = this.remotePeerConnections.get(peerId);
      if (oldConnection) {
        oldConnection.close();
      }

      // Create new peer connection
      const newConnection = new RTCPeerConnection(this.rtcConfig);
      this.remotePeerConnections.set(peerId, newConnection);
      this.setupPeerConnectionHandlers(newConnection, peerId);

      // Notify Phoenix about reconnection attempt
      this.pushEvent("reconnect_peer", {
        peer_id: peerId,
        broadcast_id: this.broadcastId
      });

      console.log('Attempting reconnection with:', peerId);
    } catch (error) {
      console.error('Reconnection failed:', error);
    }
  },

  handleQualityChange({ quality }) {
    if (!this.localStream) return;

    const videoTrack = this.localStream.getVideoTracks()[0];
    if (!videoTrack) return;

    // Adjust video constraints based on quality
    const constraints = this.getVideoConstraints(quality);
    
    videoTrack.applyConstraints(constraints.video)
      .then(() => {
        console.log('Video quality changed to:', quality);
        this.pushEvent("quality_change_applied", { quality });
      })
      .catch(error => {
        console.error('Failed to change video quality:', error);
        this.pushEvent("quality_change_failed", { error: error.message });
      });
  },

  getVideoConstraints(quality) {
    const constraints = {
      video: {
        frameRate: { ideal: 30 }
      }
    };

    switch (quality) {
      case '4K':
        constraints.video.width = { ideal: 3840 };
        constraints.video.height = { ideal: 2160 };
        break;
      case '1080p':
        constraints.video.width = { ideal: 1920 };
        constraints.video.height = { ideal: 1080 };
        break;
      case '720p':
        constraints.video.width = { ideal: 1280 };
        constraints.video.height = { ideal: 720 };
        break;
      case '480p':
        constraints.video.width = { ideal: 854 };
        constraints.video.height = { ideal: 480 };
        break;
      default:
        constraints.video.width = { ideal: 1280 };
        constraints.video.height = { ideal: 720 };
    }

    return constraints;
  },

  getStreamConfig() {
    if (!this.localStream) return {};

    const videoTrack = this.localStream.getVideoTracks()[0];
    const audioTrack = this.localStream.getAudioTracks()[0];

    return {
      video: videoTrack ? {
        width: videoTrack.getSettings().width,
        height: videoTrack.getSettings().height,
        frameRate: videoTrack.getSettings().frameRate
      } : null,
      audio: audioTrack ? {
        sampleRate: audioTrack.getSettings().sampleRate,
        channelCount: audioTrack.getSettings().channelCount
      } : null
    };
  },

  clearRemoteVideos() {
    this.remoteStreams.clear();
    while (this.remoteVideoContainer.firstChild) {
      this.remoteVideoContainer.removeChild(this.remoteVideoContainer.firstChild);
    }
  },

  setupDataChannel(dataChannel, peerId) {
    dataChannel.onopen = () => {
      console.log(`Data channel opened with ${peerId}`);
    };

    dataChannel.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data);
        this.handleDataChannelMessage(peerId, data);
      } catch (error) {
        console.error('Failed to parse data channel message:', error);
      }
    };
  },

  handleDataChannelMessage(peerId, data) {
    // Handle various control messages
    switch (data.type) {
      case 'chat':
        this.pushEvent("chat_message_received", {
          from: peerId,
          message: data.message
        });
        break;
      case 'reaction':
        this.pushEvent("reaction_received", {
          from: peerId,
          reaction: data.reaction
        });
        break;
      default:
        console.log('Unknown data channel message:', data);
    }
  },

  cleanup() {
    // Stop all streams
    if (this.localStream) {
      this.localStream.getTracks().forEach(track => track.stop());
    }

    // Close all peer connections
    this.remotePeerConnections.forEach(pc => pc.close());
    this.remotePeerConnections.clear();

    // Clear streams
    this.remoteStreams.clear();
    this.connectionStates.clear();

    console.log('WebRTC Video Hook cleaned up');
  }
};