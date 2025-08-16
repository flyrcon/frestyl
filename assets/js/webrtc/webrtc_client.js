// assets/js/webrtc/webrtc_client.js
export class WebRTCClient {
  constructor(options = {}) {
    this.sessionId = options.sessionId;
    this.userId = options.userId;
    this.isHost = options.isHost || false;
    this.onStream = options.onStream || (() => {});
    this.onError = options.onError || (() => {});
    this.onParticipantJoin = options.onParticipantJoin || (() => {});
    this.onParticipantLeave = options.onParticipantLeave || (() => {});
    
    // WebRTC configuration
    this.config = {
      iceServers: [
        { urls: 'stun:stun.l.google.com:19302' },
        { urls: 'stun:stun1.l.google.com:19302' }
      ]
    };
    
    // Connection state
    this.localStream = null;
    this.peerConnections = new Map();
    this.dataChannels = new Map();
    this.connected = false;
    
    // Phoenix channel for signaling
    this.channel = null;
    
    // Quality settings
    this.qualitySettings = {
      video: {
        width: { ideal: 1280 },
        height: { ideal: 720 },
        frameRate: { ideal: 30 }
      },
      audio: {
        echoCancellation: true,
        noiseSuppression: true,
        autoGainControl: true
      }
    };
  }

  async connect() {
    try {
      // Connect to Phoenix channel for signaling
      await this.connectSignaling();
      
      // Get user media
      await this.initializeMedia();
      
      // Set up event handlers
      this.setupSignalingHandlers();
      
      this.connected = true;
      console.log('WebRTC client connected successfully');
      
    } catch (error) {
      console.error('Failed to connect WebRTC client:', error);
      this.onError(error);
      throw error;
    }
  }

  async connectSignaling() {
    // Assuming Phoenix LiveView handles this through existing channel
    // This would integrate with your existing LiveView socket
    if (window.liveSocket) {
      this.channel = window.liveSocket.channel(`webrtc:${this.sessionId}`, {
        user_id: this.userId,
        is_host: this.isHost
      });
      
      return new Promise((resolve, reject) => {
        this.channel.join()
          .receive('ok', () => resolve())
          .receive('error', (error) => reject(error));
      });
    }
  }

  async initializeMedia() {
    try {
      const constraints = {
        video: this.qualitySettings.video,
        audio: this.qualitySettings.audio
      };
      
      this.localStream = await navigator.mediaDevices.getUserMedia(constraints);
      
      // Notify about local stream
      this.onStream(this.localStream, this.userId);
      
    } catch (error) {
      console.error('Failed to get user media:', error);
      
      // Try audio-only fallback
      try {
        this.localStream = await navigator.mediaDevices.getUserMedia({ audio: true });
        this.onStream(this.localStream, this.userId);
      } catch (audioError) {
        throw new Error('No media access available');
      }
    }
  }

  setupSignalingHandlers() {
    if (!this.channel) return;
    
    // Handle new participant joining
    this.channel.on('participant_joined', (payload) => {
      this.handleParticipantJoined(payload.participant_id);
    });
    
    // Handle participant leaving
    this.channel.on('participant_left', (payload) => {
      this.handleParticipantLeft(payload.participant_id);
    });
    
    // Handle WebRTC offer
    this.channel.on('webrtc_offer', (payload) => {
      this.handleOffer(payload);
    });
    
    // Handle WebRTC answer
    this.channel.on('webrtc_answer', (payload) => {
      this.handleAnswer(payload);
    });
    
    // Handle ICE candidate
    this.channel.on('ice_candidate', (payload) => {
      this.handleIceCandidate(payload);
    });
  }

  async handleParticipantJoined(participantId) {
    if (participantId === this.userId) return;
    
    try {
      // Create peer connection for new participant
      const peerConnection = await this.createPeerConnection(participantId);
      
      // Add local stream to peer connection
      if (this.localStream) {
        this.localStream.getTracks().forEach(track => {
          peerConnection.addTrack(track, this.localStream);
        });
      }
      
      // Create offer if we're the host or have lower user ID (deterministic)
      if (this.isHost || this.userId < participantId) {
        const offer = await peerConnection.createOffer();
        await peerConnection.setLocalDescription(offer);
        
        this.channel.push('webrtc_offer', {
          target_id: participantId,
          offer: offer
        });
      }
      
      this.onParticipantJoin(participantId);
      
    } catch (error) {
      console.error('Error handling participant joined:', error);
      this.onError(error);
    }
  }

  async handleParticipantLeft(participantId) {
    const peerConnection = this.peerConnections.get(participantId);
    if (peerConnection) {
      peerConnection.close();
      this.peerConnections.delete(participantId);
    }
    
    const dataChannel = this.dataChannels.get(participantId);
    if (dataChannel) {
      dataChannel.close();
      this.dataChannels.delete(participantId);
    }
    
    this.onParticipantLeave(participantId);
  }

  async createPeerConnection(participantId) {
    const peerConnection = new RTCPeerConnection(this.config);
    this.peerConnections.set(participantId, peerConnection);
    
    // Handle incoming streams
    peerConnection.ontrack = (event) => {
      const [remoteStream] = event.streams;
      this.onStream(remoteStream, participantId);
    };
    
    // Handle ICE candidates
    peerConnection.onicecandidate = (event) => {
      if (event.candidate) {
        this.channel.push('ice_candidate', {
          target_id: participantId,
          candidate: event.candidate
        });
      }
    };
    
    // Create data channel for collaboration
    const dataChannel = peerConnection.createDataChannel('collaboration', {
      ordered: true
    });
    
    dataChannel.onopen = () => {
      console.log(`Data channel opened with ${participantId}`);
    };
    
    dataChannel.onmessage = (event) => {
      this.handleDataChannelMessage(participantId, JSON.parse(event.data));
    };
    
    this.dataChannels.set(participantId, dataChannel);
    
    // Handle incoming data channels
    peerConnection.ondatachannel = (event) => {
      const channel = event.channel;
      channel.onmessage = (event) => {
        this.handleDataChannelMessage(participantId, JSON.parse(event.data));
      };
    };
    
    return peerConnection;
  }

  async handleOffer(payload) {
    const { from_id, offer } = payload;
    
    try {
      let peerConnection = this.peerConnections.get(from_id);
      if (!peerConnection) {
        peerConnection = await this.createPeerConnection(from_id);
      }
      
      await peerConnection.setRemoteDescription(offer);
      
      // Add local stream
      if (this.localStream) {
        this.localStream.getTracks().forEach(track => {
          peerConnection.addTrack(track, this.localStream);
        });
      }
      
      const answer = await peerConnection.createAnswer();
      await peerConnection.setLocalDescription(answer);
      
      this.channel.push('webrtc_answer', {
        target_id: from_id,
        answer: answer
      });
      
    } catch (error) {
      console.error('Error handling offer:', error);
      this.onError(error);
    }
  }

  async handleAnswer(payload) {
    const { from_id, answer } = payload;
    
    try {
      const peerConnection = this.peerConnections.get(from_id);
      if (peerConnection) {
        await peerConnection.setRemoteDescription(answer);
      }
    } catch (error) {
      console.error('Error handling answer:', error);
      this.onError(error);
    }
  }

  async handleIceCandidate(payload) {
    const { from_id, candidate } = payload;
    
    try {
      const peerConnection = this.peerConnections.get(from_id);
      if (peerConnection) {
        await peerConnection.addIceCandidate(candidate);
      }
    } catch (error) {
      console.error('Error handling ICE candidate:', error);
    }
  }

  handleDataChannelMessage(fromId, message) {
    // Handle collaboration messages
    if (message.type === 'collaboration') {
      window.dispatchEvent(new CustomEvent('collaboration_message', {
        detail: { fromId, message: message.data }
      }));
    }
  }

  // Public methods
  async toggleVideo() {
    if (!this.localStream) return false;
    
    const videoTrack = this.localStream.getVideoTracks()[0];
    if (videoTrack) {
      videoTrack.enabled = !videoTrack.enabled;
      return videoTrack.enabled;
    }
    return false;
  }

  async toggleAudio() {
    if (!this.localStream) return false;
    
    const audioTrack = this.localStream.getAudioTracks()[0];
    if (audioTrack) {
      audioTrack.enabled = !audioTrack.enabled;
      return audioTrack.enabled;
    }
    return false;
  }

  async startScreenShare() {
    try {
      const screenStream = await navigator.mediaDevices.getDisplayMedia({
        video: true,
        audio: true
      });
      
      // Replace video track in all peer connections
      const videoTrack = screenStream.getVideoTracks()[0];
      
      this.peerConnections.forEach(async (peerConnection) => {
        const sender = peerConnection.getSenders().find(s => 
          s.track && s.track.kind === 'video'
        );
        
        if (sender) {
          await sender.replaceTrack(videoTrack);
        }
      });
      
      // Handle screen share ending
      videoTrack.onended = () => {
        this.stopScreenShare();
      };
      
      return true;
      
    } catch (error) {
      console.error('Error starting screen share:', error);
      return false;
    }
  }

  async stopScreenShare() {
    if (!this.localStream) return;
    
    try {
      // Get camera stream back
      const cameraStream = await navigator.mediaDevices.getUserMedia({
        video: this.qualitySettings.video
      });
      
      const videoTrack = cameraStream.getVideoTracks()[0];
      
      // Replace screen share with camera in all connections
      this.peerConnections.forEach(async (peerConnection) => {
        const sender = peerConnection.getSenders().find(s => 
          s.track && s.track.kind === 'video'
        );
        
        if (sender) {
          await sender.replaceTrack(videoTrack);
        }
      });
      
      // Update local stream
      this.localStream.getVideoTracks().forEach(track => track.stop());
      this.localStream.removeTrack(this.localStream.getVideoTracks()[0]);
      this.localStream.addTrack(videoTrack);
      
    } catch (error) {
      console.error('Error stopping screen share:', error);
    }
  }

  sendCollaborationMessage(message) {
    const data = JSON.stringify({
      type: 'collaboration',
      data: message
    });
    
    this.dataChannels.forEach((channel) => {
      if (channel.readyState === 'open') {
        channel.send(data);
      }
    });
  }

  disconnect() {
    // Close all peer connections
    this.peerConnections.forEach((peerConnection) => {
      peerConnection.close();
    });
    this.peerConnections.clear();
    
    // Close all data channels
    this.dataChannels.forEach((channel) => {
      channel.close();
    });
    this.dataChannels.clear();
    
    // Stop local stream
    if (this.localStream) {
      this.localStream.getTracks().forEach(track => track.stop());
      this.localStream = null;
    }
    
    // Leave signaling channel
    if (this.channel) {
      this.channel.leave();
      this.channel = null;
    }
    
    this.connected = false;
  }

  // Quality management
  async setQuality(quality) {
    const qualityMap = {
      'low': { width: 640, height: 360, frameRate: 15 },
      'medium': { width: 1280, height: 720, frameRate: 24 },
      'high': { width: 1920, height: 1080, frameRate: 30 }
    };
    
    const settings = qualityMap[quality] || qualityMap['medium'];
    
    // Update quality settings
    this.qualitySettings.video = {
      width: { ideal: settings.width },
      height: { ideal: settings.height },
      frameRate: { ideal: settings.frameRate }
    };
    
    // If already connected, restart video with new quality
    if (this.localStream && this.connected) {
      await this.restartVideo();
    }
  }

  async restartVideo() {
    try {
      const newStream = await navigator.mediaDevices.getUserMedia({
        video: this.qualitySettings.video,
        audio: false
      });
      
      const newVideoTrack = newStream.getVideoTracks()[0];
      
      // Replace video track in all connections
      this.peerConnections.forEach(async (peerConnection) => {
        const sender = peerConnection.getSenders().find(s => 
          s.track && s.track.kind === 'video'
        );
        
        if (sender) {
          await sender.replaceTrack(newVideoTrack);
        }
      });
      
      // Update local stream
      const oldVideoTrack = this.localStream.getVideoTracks()[0];
      if (oldVideoTrack) {
        this.localStream.removeTrack(oldVideoTrack);
        oldVideoTrack.stop();
      }
      this.localStream.addTrack(newVideoTrack);
      
    } catch (error) {
      console.error('Error restarting video:', error);
    }
  }
}

// assets/js/collaboration/collaboration_engine.js
export class CollaborationEngine {
  constructor(options = {}) {
    this.sessionId = options.sessionId;
    this.userId = options.userId;
    this.onOperation = options.onOperation || (() => {});
    this.onCursorMove = options.onCursorMove || (() => {});
    this.onUserJoin = options.onUserJoin || (() => {});
    this.onUserLeave = options.onUserLeave || (() => {});
    
    // Operation Transform state
    this.localOperations = [];
    this.remoteOperations = [];
    this.version = 0;
    this.pendingOperations = new Map();
    
    // Cursor tracking
    this.cursors = new Map();
    this.lastCursorSend = 0;
    this.cursorThrottle = 50; // ms
    
    // Connection state
    this.connected = false;
    this.channel = null;
    
    this.initialize();
  }

  async initialize() {
    try {
      await this.connectChannel();
      this.setupEventHandlers();
      this.connected = true;
      console.log('Collaboration engine initialized');
    } catch (error) {
      console.error('Failed to initialize collaboration engine:', error);
      throw error;
    }
  }

  async connectChannel() {
    if (window.liveSocket) {
      this.channel = window.liveSocket.channel(`collaboration:${this.sessionId}`, {
        user_id: this.userId
      });
      
      return new Promise((resolve, reject) => {
        this.channel.join()
          .receive('ok', (response) => {
            this.version = response.version || 0;
            resolve();
          })
          .receive('error', (error) => reject(error));
      });
    }
  }

  setupEventHandlers() {
    if (!this.channel) return;
    
    // Handle incoming operations
    this.channel.on('operation', (payload) => {
      this.handleRemoteOperation(payload);
    });
    
    // Handle operation acknowledgments
    this.channel.on('operation_ack', (payload) => {
      this.handleOperationAck(payload);
    });
    
    // Handle cursor updates
    this.channel.on('cursor_update', (payload) => {
      this.handleCursorUpdate(payload);
    });
    
    // Handle user join/leave
    this.channel.on('user_joined', (payload) => {
      this.onUserJoin(payload.user);
    });
    
    this.channel.on('user_left', (payload) => {
      this.cursors.delete(payload.user_id);
      this.onUserLeave(payload.user_id);
    });
    
    // Handle state sync
    this.channel.on('state_sync', (payload) => {
      this.handleStateSync(payload);
    });
  }

  // Operation handling
  sendOperation(operation) {
    if (!this.connected) return;
    
    const operationWithVersion = {
      ...operation,
      id: this.generateOperationId(),
      version: this.version,
      user_id: this.userId,
      timestamp: Date.now()
    };
    
    // Store as pending
    this.pendingOperations.set(operationWithVersion.id, operationWithVersion);
    this.localOperations.push(operationWithVersion);
    
    // Send to server
    this.channel.push('operation', operationWithVersion);
    
    // Apply locally immediately
    this.onOperation(operationWithVersion);
  }

  handleRemoteOperation(payload) {
    const operation = payload.operation;
    
    // Skip our own operations
    if (operation.user_id === this.userId) return;
    
    // Transform against pending local operations
    const transformedOperation = this.transformOperation(operation);
    
    // Apply transformed operation
    if (transformedOperation) {
      this.onOperation(transformedOperation);
      this.remoteOperations.push(transformedOperation);
    }
    
    // Update version
    this.version = Math.max(this.version, operation.version + 1);
  }

  handleOperationAck(payload) {
    const operationId = payload.operation_id;
    
    // Remove from pending operations
    this.pendingOperations.delete(operationId);
    
    // Update version if needed
    if (payload.version) {
      this.version = Math.max(this.version, payload.version);
    }
  }

  transformOperation(operation) {
    // Simple operational transform implementation
    // In a full implementation, this would use proper OT algorithms
    
    let transformedOp = { ...operation };
    
    // Transform against all pending local operations
    for (const localOp of this.pendingOperations.values()) {
      transformedOp = this.transformTwoOperations(transformedOp, localOp);
    }
    
    return transformedOp;
  }

  transformTwoOperations(op1, op2) {
    // Basic transformation logic - this should be expanded based on operation types
    if (op1.type === op2.type) {
      switch (op1.type) {
        case 'text':
          return this.transformTextOperations(op1, op2);
        case 'visual':
          return this.transformVisualOperations(op1, op2);
        case 'audio':
          return this.transformAudioOperations(op1, op2);
        default:
          return op1;
      }
    }
    
    return op1; // Different types don't conflict
  }

  transformTextOperations(op1, op2) {
    // Simplified text operation transform
    if (op1.action === 'insert' && op2.action === 'insert') {
      if (op1.data.position <= op2.data.position) {
        return {
          ...op1,
          data: {
            ...op1.data,
            position: op1.data.position + op2.data.text.length
          }
        };
      }
    }
    
    return op1;
  }

  transformVisualOperations(op1, op2) {
    // Visual operations typically don't conflict unless on same element
    if (op1.data.elementId === op2.data.elementId) {
      // Handle same element conflicts
      if (op1.action === 'update' && op2.action === 'delete') {
        // Deletion wins over update
        return null; // Operation becomes no-op
      }
    }
    
    return op1;
  }

  transformAudioOperations(op1, op2) {
    // Audio operations on same track need transformation
    if (op1.data.trackId === op2.data.trackId) {
      if (op1.action === 'add_clip' && op2.action === 'add_clip') {
        // Adjust timing if clips overlap
        const overlap = this.calculateOverlap(op1.data, op2.data);
        if (overlap > 0) {
          return {
            ...op1,
            data: {
              ...op1.data,
              startTime: op1.data.startTime + overlap
            }
          };
        }
      }
    }
    
    return op1;
  }

  calculateOverlap(clip1, clip2) {
    const start1 = clip1.startTime;
    const end1 = start1 + clip1.duration;
    const start2 = clip2.startTime;
    const end2 = start2 + clip2.duration;
    
    const overlapStart = Math.max(start1, start2);
    const overlapEnd = Math.min(end1, end2);
    
    return Math.max(0, overlapEnd - overlapStart);
  }

  // Cursor management
  sendCursor(cursor) {
    const now = Date.now();
    if (now - this.lastCursorSend < this.cursorThrottle) return;
    
    this.lastCursorSend = now;
    
    if (this.channel) {
      this.channel.push('cursor_update', {
        cursor: {
          ...cursor,
          user_id: this.userId,
          timestamp: now
        }
      });
    }
  }

  handleCursorUpdate(payload) {
    const cursor = payload.cursor;
    
    if (cursor.user_id !== this.userId) {
      this.cursors.set(cursor.user_id, cursor);
      this.onCursorMove(cursor);
    }
  }

  // State synchronization
  requestStateSync() {
    if (this.channel) {
      this.channel.push('request_state_sync', {});
    }
  }

  handleStateSync(payload) {
    // Handle full state synchronization
    this.version = payload.version;
    this.localOperations = [];
    this.pendingOperations.clear();
    
    // Apply all operations from server
    if (payload.operations) {
      payload.operations.forEach(op => this.onOperation(op));
    }
  }

  // Utility methods
  generateOperationId() {
    return `${this.userId}_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  // Conflict resolution strategies
  resolveConflict(op1, op2, strategy = 'timestamp') {
    switch (strategy) {
      case 'timestamp':
        return op1.timestamp < op2.timestamp ? op1 : op2;
      case 'user_priority':
        // Could implement user-based priority
        return op1.user_id < op2.user_id ? op1 : op2;
      case 'operation_type':
        // Some operations might have higher priority
        const priorities = { delete: 3, update: 2, insert: 1 };
        const p1 = priorities[op1.action] || 0;
        const p2 = priorities[op2.action] || 0;
        return p1 >= p2 ? op1 : op2;
      default:
        return op1;
    }
  }

  // Cleanup
  destroy() {
    if (this.channel) {
      this.channel.leave();
      this.channel = null;
    }
    
    this.localOperations = [];
    this.remoteOperations = [];
    this.pendingOperations.clear();
    this.cursors.clear();
    this.connected = false;
  }

  // Analytics and debugging
  getStats() {
    return {
      version: this.version,
      localOperations: this.localOperations.length,
      remoteOperations: this.remoteOperations.length,
      pendingOperations: this.pendingOperations.size,
      activeCursors: this.cursors.size,
      connected: this.connected
    };
  }
}