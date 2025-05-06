// assets/js/hooks/chat_hooks.js

const ChatHooks = {
    // Auto-scroll to bottom when new messages arrive
    AutoScroll: {
      mounted() {
        this.scrollToBottom()
        
        this.handleEvent("chat-message-sent", () => {
          this.scrollToBottom()
        })
        
        // Observe for new message elements
        this.observer = new MutationObserver(() => {
          this.scrollToBottom()
        })
        
        this.observer.observe(this.el, { childList: true })
      },
      
      updated() {
        this.scrollToBottom()
      },
      
      destroyed() {
        if (this.observer) {
          this.observer.disconnect()
        }
      },
      
      scrollToBottom() {
        this.el.scrollTop = this.el.scrollHeight
      }
    },
    
    // Handle typing indicators
    TypingIndicator: {
      mounted() {
        let typingTimeout
        
        this.el.addEventListener("keyup", (e) => {
          clearTimeout(typingTimeout)
          
          // Send typing event
          this.pushEvent("typing", { typing: true })
          
          // Clear typing after 3 seconds of inactivity
          typingTimeout = setTimeout(() => {
            this.pushEvent("typing", { typing: false })
          }, 3000)
        })
        
        this.el.addEventListener("blur", () => {
          this.pushEvent("typing", { typing: false })
        })
      }
    },
    
    // Channel Chat Presence
    ChannelPresence: {
      mounted() {
        this.handleEvent("presence_state", presences => {
          this.updatePresenceList(presences)
        })
        
        this.handleEvent("presence_diff", diff => {
          this.updatePresenceDiff(diff)
        })
      },
      
      updatePresenceList(presences) {
        // Handle initial presence state
        console.log("Presence list:", presences)
      },
      
      updatePresenceDiff(diff) {
        // Handle presence changes (joins/leaves)
        console.log("Presence diff:", diff)
      }
    },
    
    // Notification sound for new messages
    MessageSound: {
      mounted() {
        this.audio = new Audio("/sounds/notification.mp3")
        this.audio.volume = 0.3
        
        this.handleEvent("new_channel_message", () => {
          if (document.hidden) {
            this.audio.play()
          }
        })
      }
    }
  }
  
  export default ChatHooks
  
  // Add to existing hooks.js file:
  import ChatHooks from './hooks/chat_hooks'
  
  const Hooks = {
    ...ChatHooks,
    // ... your existing hooks ...
  }
  
  export default Hooks