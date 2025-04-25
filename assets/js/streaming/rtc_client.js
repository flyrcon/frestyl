// assets/js/streaming/rtc_client.js

import { Socket } from "phoenix"

export default class RtcClient {
  constructor(userToken, userId) {
    this.userToken = userToken;
    this.userId = userId;
    this.socket = new Socket("/socket", {params: {token: userToken}});
    this.channels = {};
    this.peerConnections = {};
    this.localStream = null;
    this.remoteStreams = {};
    this.onTrackCallbacks = [];
    this.onDisconnectCallbacks = [];
    
    // WebRTC configuration
    this.rtcConfig = {
      iceServers: [
        { urls: "stun:stun.l.google.com:19302" },
        { urls: "stun:stun1.l.google.com:19302" },
        { urls: "stun:stun2.l.google.com:19302" }
        // Add TURN servers for production use
      ],
      iceCandidatePoolSize: 10
    };
    
    this.socket.connect();
  }
  
  /**
   * Join a room channel
   */
  joinRoom(roomId) {
    const channel = this.socket.channel(`room:${roomId}`, {});
    
    channel.join()
      .receive("ok", resp => {
        console.log(`Joined room ${roomId} successfully`, resp);
        this.channels[roomId] = channel;
        
        // Handle presence updates
        channel.on("presence_state", state => {
          console.log("Initial presence state:", state);
          
          // Connect to existing users
          Object.keys(state).forEach(userId => {
            if (userId !== this.userId) {
              this.connectToPeer(roomId, userId);
            }
          });
        });
        
        channel.on("presence_diff", diff => {
          console.log("Presence diff:", diff);
          
          // Connect to new users
          Object.keys(diff.joins).forEach(userId => {
            if (userId !== this.userId) {
              this.connectToPeer(roomId, userId);
            }
          });
          
          // Handle user leaves
          Object.keys(diff.leaves).forEach(userId => {
            this.disconnectFromPeer(userId);
          });
        });
      })
      .receive("error", resp => {
        console.error(`Unable to join room ${roomId}`, resp);
      });
      
    return channel;
  }
  
  /**
   * Join the signaling channel
   */
  joinSignalingChannel(roomId) {
    const channel = this.socket.channel(`signaling:${roomId}`, {});
    
    channel.join()
      .receive("ok", resp => {
        console.log(`Joined signaling channel for room ${roomId} successfully`, resp);
        this.channels[`signaling:${roomId}`] = channel;
        
        // Handle signaling messages
        channel.on("signal", payload => {
          if (payload.from !== this.userId) {
            this.handleSignal(payload.from, payload.signal);
          }
        });
        
        channel.on("ice_candidate", payload => {
          if (payload.from !== this.userId) {
            this.handleIceCandidate(payload.from, payload.candidate);
          }
        });
      })
      .receive("error", resp => {
        console.error(`Unable to join signaling channel for room ${roomId}`, resp);
      });
      
    return channel;
  }
  
  /**
   * Start local stream
   */
  async startLocalStream(constraints = { audio: true, video: true }) {
    try {
      this.localStream = await navigator.mediaDevices.getUserMedia(constraints);
      return this.localStream;
    } catch (error) {
      console.error("Error getting user media:", error);
      throw error;
    }
  }
  
  /**
   * Share screen
   */
  async shareScreen() {
    try {
      this.localStream = await navigator.mediaDevices.getDisplayMedia({
        video: true,
        audio: false
      });
      return this.localStream;
    } catch (error) {
      console.error("Error sharing screen:", error);
      throw error;
    }
  }
  
  /**
   * Connect to a peer
   */
  async connectToPeer(roomId, peerId) {
    // Don't connect to self or if already connected
    if (peerId === this.userId || this.peerConnections[peerId]) {
      return;
    }
    
    // Make sure we are connected to the signaling channel
    if (!this.channels[`signaling:${roomId}`]) {
      this.joinSignalingChannel(roomId);
    }
    
    // Create peer connection
    const peerConnection = new RTCPeerConnection(this.rtcConfig);
    this.peerConnections[peerId] = peerConnection;
    
    // Add local stream tracks to peer connection
    if (this.localStream) {
      this.localStream.getTracks().forEach(track => {
        peerConnection.addTrack(track, this.localStream);
      });
    }
    
    // Handle ICE candidates
    peerConnection.onicecandidate = event => {
      if (event.candidate) {
        this.channels[`signaling:${roomId}`].push("ice_candidate", {
          to: peerId,
          candidate: event.candidate
        });
      }
    };
    
    // Handle connection state changes
    peerConnection.onconnectionstatechange = event => {
      console.log(`Connection state change for peer ${peerId}:`, peerConnection.connectionState);
      
      if (peerConnection.connectionState === 'disconnected' || 
          peerConnection.connectionState === 'failed' || 
          peerConnection.connectionState === 'closed') {
        this.disconnectFromPeer(peerId);
      }
    };
    
    // Handle incoming tracks
    peerConnection.ontrack = event => {
      console.log(`Got remote track from peer ${peerId}:`, event.streams);
      
      if (event.streams && event.streams[0]) {
        this.remoteStreams[peerId] = event.streams[0];
        
        // Notify callbacks
        this.onTrackCallbacks.forEach(callback => {
          callback(peerId, event.streams[0]);
        });
      }
    };
    
    try {
      // Create offer (if we are the initiator)
      if (this.userId < peerId) {
        const offer = await peerConnection.createOffer({
          offerToReceiveAudio: true,
          offerToReceiveVideo: true
        });
        
        await peerConnection.setLocalDescription(offer);
        
        this.channels[`signaling:${roomId}`].push("signal", {
          to: peerId,
          signal: { type: "offer", sdp: offer.sdp }
        });
      }
    } catch (error) {
      console.error(`Error connecting to peer ${peerId}:`, error);
      this.disconnectFromPeer(peerId);
    }
  }
  
  /**
   * Handle incoming signals
   */
  async handleSignal(peerId, signal) {
    if (!this.peerConnections[peerId]) {
      // Create peer connection if it doesn't exist
      const roomId = Object.keys(this.channels)
        .find(key => key.startsWith('room:'))
        ?.split(':')[1];
        
      if (roomId) {
        await this.connectToPeer(roomId, peerId);
      } else {
        console.error(`Cannot handle signal from ${peerId}, not in any room`);
        return;
      }
    }
    
    const peerConnection = this.peerConnections[peerId];
    
    try {
      if (signal.type === 'offer') {
        await peerConnection.setRemoteDescription(new RTCSessionDescription({
          type: 'offer',
          sdp: signal.sdp
        }));
        
        const answer = await peerConnection.createAnswer();
        await peerConnection.setLocalDescription(answer);
        
        // Get the room ID
        const roomId = Object.keys(this.channels)
          .find(key => key.startsWith('room:'))
          ?.split(':')[1];
          
        if (roomId) {
          this.channels[`signaling:${roomId}`].push("signal", {
            to: peerId,
            signal: { type: "answer", sdp: answer.sdp }
          });
        }
      } else if (signal.type === 'answer') {
        await peerConnection.setRemoteDescription(new RTCSessionDescription({
          type: 'answer',
          sdp: signal.sdp
        }));
      }
    } catch (error) {
      console.error(`Error handling signal from peer ${peerId}:`, error);
    }
  }
  
  /**
   * Handle incoming ICE candidates
   */
  async handleIceCandidate(peerId, candidate) {
    if (!this.peerConnections[peerId]) {
      console.error(`Cannot handle ICE candidate from ${peerId}, no peer connection`);
      return;
    }
    
    try {
      await this.peerConnections[peerId].addIceCandidate(new RTCIceCandidate(candidate));
    } catch (error) {
      console.error(`Error handling ICE candidate from peer ${peerId}:`, error);
    }
  }
  
  /**
   * Disconnect from a peer
   */
  disconnectFromPeer(peerId) {
    if (!this.peerConnections[peerId]) {
      return;
    }
    
    console.log(`Disconnecting from peer ${peerId}`);
    
    const peerConnection = this.peerConnections[peerId];
    
    // Close peer connection
    try {
      peerConnection.close();
    } catch (error) {
      console.error(`Error closing connection to peer ${peerId}:`, error);
    }
    
    // Remove from peer connections
    delete this.peerConnections[peerId];
    
    // Remove remote stream
    if (this.remoteStreams[peerId]) {
      delete this.remoteStreams[peerId];
    }
    
    // Notify callbacks
    this.onDisconnectCallbacks.forEach(callback => {
      callback(peerId);
    });
  }
  
  /**
   * Leave a room
   */
  leaveRoom(roomId) {
    // Disconnect from all peers
    Object.keys(this.peerConnections).forEach(peerId => {
      this.disconnectFromPeer(peerId);
    });
    
    // Leave the room channel
    if (this.channels[roomId]) {
      this.channels[roomId].leave();
      delete this.channels[roomId];
    }
    
    // Leave the signaling channel
    if (this.channels[`signaling:${roomId}`]) {
      this.channels[`signaling:${roomId}`].leave();
      delete this.channels[`signaling:${roomId}`];
    }
  }
  
  /**
   * Stop local stream
   */
  stopLocalStream() {
    if (this.localStream) {
      this.localStream.getTracks().forEach(track => track.stop());
      this.localStream = null;
    }
  }
  
  /**
   * Clean up
   */
  cleanup() {
    // Stop local stream
    this.stopLocalStream();
    
    // Disconnect from all peers
    Object.keys(this.peerConnections).forEach(peerId => {
      this.disconnectFromPeer(peerId);
    });
    
    // Leave all channels
    Object.keys(this.channels).forEach(channelId => {
      this.channels[channelId].leave();
    });
    
    // Disconnect socket
    this.socket.disconnect();
  }
  
  /**
   * Register callback for new remote tracks
   */
  onTrack(callback) {
    this.onTrackCallbacks.push(callback);
  }
  
  /**
   * Register callback for peer disconnections
   */
  onDisconnect(callback) {
    this.onDisconnectCallbacks.push(callback);
  }
}