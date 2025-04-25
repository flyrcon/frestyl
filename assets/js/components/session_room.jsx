// assets/js/components/SessionRoom.jsx
import React, { useState, useEffect, useRef } from 'react';
import { socket } from '../socket';

const SessionRoom = ({ sessionId, currentUser }) => {
  const [channel, setChannel] = useState(null);
  const [participants, setParticipants] = useState({});
  const [messages, setMessages] = useState([]);
  const [messageInput, setMessageInput] = useState('');
  const [mediaItems, setMediaItems] = useState([]);
  const [isConnected, setIsConnected] = useState(false);
  
  // WebRTC connections
  const peerConnections = useRef({});
  const localStreamRef = useRef(null);
  const localVideoRef = useRef(null);
  
  // Initialize channel and WebRTC
  useEffect(() => {
    if (!sessionId) return;
    
    // Join the session channel
    const sessionChannel = socket.channel(`session:${sessionId}`, {});
    
    sessionChannel.join()
      .receive("ok", resp => {
        console.log("Joined session successfully", resp);
        setChannel(sessionChannel);
        setIsConnected(true);
      })
      .receive("error", resp => {
        console.error("Unable to join session", resp);
      });
    
    // Set up channel event listeners
    sessionChannel.on("presence_state", state => {
      setParticipants(state);
    });
    
    sessionChannel.on("presence_diff", diff => {
      setParticipants(prev => {
        const newParticipants = {...prev};
        
        // Remove users who left
        Object.keys(diff.leaves).forEach(id => {
          delete newParticipants[id];
        });
        
        // Add users who joined
        Object.keys(diff.joins).forEach(id => {
          newParticipants[id] = diff.joins[id];
        });
        
        return newParticipants;
      });
    });
    
    sessionChannel.on("new_message", payload => {
      setMessages(prev => [...prev, payload]);
    });
    
    sessionChannel.on("media_shared", payload => {
      setMediaItems(prev => [...prev, payload]);
    });
    
    // WebRTC signaling
    sessionChannel.on("signal", payload => {
      handleSignalMessage(payload);
    });
    
    // Initialize WebRTC
    setupWebRTC();
    
    return () => {
      // Clean up
      Object.values(peerConnections.current).forEach(pc => pc.close());
      if (localStreamRef.current) {
        localStreamRef.current.getTracks().forEach(track => track.stop());
      }
      sessionChannel.leave();
    };
  }, [sessionId]);
  
  // Setup WebRTC
  const setupWebRTC = async () => {
    try {
      // Get user media (camera and microphone)
      const stream = await navigator.mediaDevices.getUserMedia({ 
        video: true, 
        audio: true 
      });
      
      localStreamRef.current = stream;
      
      // Display local video
      if (localVideoRef.current) {
        localVideoRef.current.srcObject = stream;
      }
      
      // Create peer connections for each participant
      Object.keys(participants).forEach(participantId => {
        if (participantId !== currentUser.id.toString()) {
          createPeerConnection(participantId, true);
        }
      });
    } catch (error) {
      console.error("Error accessing media devices:", error);
    }
  };
  
  // Create a peer connection to a participant
  const createPeerConnection = (participantId, isInitiator) => {
    if (peerConnections.current[participantId]) return;
    
    const configuration = { 
      iceServers: [
        { urls: 'stun:stun.l.google.com:19302' },
        { urls: 'stun:stun1.l.google.com:19302' }
      ] 
    };
    
    const pc = new RTCPeerConnection(configuration);
    peerConnections.current[participantId] = pc;
    
    // Add local tracks to the connection
    if (localStreamRef.current) {
      localStreamRef.current.getTracks().forEach(track => {
        pc.addTrack(track, localStreamRef.current);
      });
    }
    
    // Listen for ICE candidates
    pc.onicecandidate = event => {
      if (event.candidate) {
        channel.push("signal", {
          to: participantId,
          signal_data: {
            type: "ice-candidate",
            candidate: event.candidate
          }
        });
      }
    };
    
    // Handle incoming tracks
    pc.ontrack = event => {
      const remoteVideo = document.getElementById(`remote-video-${participantId}`);
      if (remoteVideo) {
        remoteVideo.srcObject = event.streams[0];
      } else {
        // Create a new video element if it doesn't exist
        const newVideo = document.createElement('video');
        newVideo.id = `remote-video-${participantId}`;
        newVideo.autoplay = true;
        newVideo.playsInline = true;
        newVideo.srcObject = event.streams[0];
        document.getElementById('remote-videos').appendChild(newVideo);
      }
    };
    
    // Start the offer/answer process if we're the initiator
    if (isInitiator) {
      pc.createOffer()
        .then(offer => pc.setLocalDescription(offer))
        .then(() => {
          channel.push("signal", {
            to: participantId,
            signal_data: {
              type: "offer",
              sdp: pc.localDescription
            }
          });
        })
        .catch(error => console.error("Error creating offer:", error));
    }
    
    return pc;
  };
  
  // Handle incoming WebRTC signaling messages
  const handleSignalMessage = async (payload) => {
    const { from, signal_data } = payload;
    
    if (!peerConnections.current[from]) {
      createPeerConnection(from, false);
    }
    
    const pc = peerConnections.current[from];
    
    switch (signal_data.type) {
      case "offer":
        await pc.setRemoteDescription(new RTCSessionDescription(signal_data.sdp));
        const answer = await pc.createAnswer();
        await pc.setLocalDescription(answer);
        channel.push("signal", {
          to: from,
          signal_data: {
            type: "answer",
            sdp: pc.localDescription
          }
        });
        break;
        
      case "answer":
        await pc.setRemoteDescription(new RTCSessionDescription(signal_data.sdp));
        break;
        
      case "ice-candidate":
        if (pc.remoteDescription) {
          await pc.addIceCandidate(new RTCIceCandidate(signal_data.candidate));
        }
        break;
        
      default:
        console.error("Unknown signal type:", signal_data.type);
    }
  };
  
  // Send a chat message
  const sendMessage = (e) => {
    e.preventDefault();
    if (messageInput.trim() === "" || !channel) return;
    
    channel.push("new_message", { content: messageInput })
      .receive("ok", () => {
        setMessageInput("");
      })
      .receive("error", resp => {
        console.error("Error sending message:", resp);
      });
  };
  
  // Share a media file
  const shareMedia = (e) => {
    const file = e.target.files[0];
    if (!file || !channel) return;
    
    const reader = new FileReader();
    reader.onload = (event) => {
      const mediaData = {
        name: file.name,
        content_type: file.type,
        data: event.target.result,
        size: file.size,
        timestamp: Date.now()
      };
      
      channel.push("share_media", mediaData)
        .receive("error", resp => {
          console.error("Error sharing media:", resp);
        });
    };
    reader.readAsDataURL(file);
  };
  
  if (!isConnected) {
    return <div>Connecting to session...</div>;
  }
  
  return (
    <div className="session-room">
      <div className="video-container">
        <div className="local-video-wrapper">
          <video 
            ref={localVideoRef} 
            autoPlay 
            playsInline 
            muted 
            className="local-video"
          />
          <div className="video-controls">
            {/* Video controls (mute, camera toggle) */}
          </div>
        </div>
        
        <div id="remote-videos" className="remote-videos">
          {/* Remote videos will be added here dynamically */}
        </div>
      </div>
      
      <div className="participants-panel">
        <h3>Participants</h3>
        <ul>
          {Object.entries(participants).map(([id, data]) => (
            <li key={id}>
              {data.metas[0].username} {id === currentUser.id.toString() ? '(You)' : ''}
            </li>
          ))}
        </ul>
      </div>
      
      <div className="chat-panel">
        <div className="messages">
          {messages.map((msg, i) => (
            <div key={i} className={`message ${msg.user_id === currentUser.id ? 'own' : ''}`}>
              <div className="message-sender">{msg.username}</div>
              <div className="message-content">{msg.content}</div>
              <div className="message-time">
                {new Date(msg.timestamp).toLocaleTimeString()}
              </div>
            </div>
          ))}
        </div>
        
        <form onSubmit={sendMessage} className="message-form">
          <input
            type="text"
            value={messageInput}
            onChange={e => setMessageInput(e.target.value)}
            placeholder="Type a message..."
          />
          <button type="submit">Send</button>
        </form>
      </div>
      
      <div className="media-panel">
        <h3>Shared Media</h3>
        <div className="media-list">
          {mediaItems.map((item, i) => (
            <div key={i} className="media-item">
              {/* Render different types of media based on content_type */}
              {item.content_type.startsWith('image/') && (
                <img src={item.data} alt={item.name} />
              )}
              {item.content_type.startsWith('audio/') && (
                <audio controls src={item.data} />
              )}
              {item.content_type.startsWith('video/') && (
                <video controls src={item.data} />
              )}
              <div className="media-info">
                <span className="media-name">{item.name}</span>
                <span className="media-size">{Math.round(item.size / 1024)} KB</span>
              </div>
            </div>
          ))}
        </div>
        
        <div className="media-upload">
          <input
            type="file"
            onChange={shareMedia}
            id="media-upload"
            className="media-upload-input"
          />
          <label htmlFor="media-upload" className="media-upload-label">
            Share Media
          </label>
        </div>
      </div>
    </div>
  );
};

export default SessionRoom;